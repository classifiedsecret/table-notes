class_name Player
extends CharacterBody2D
## Boar-vhal in real time. Movement is platformer-tuned; every hit is a 5e roll.

signal hp_changed
signal downed
signal died(reason: String)

enum State { NORMAL, ATTACK, DODGE, HURT, DOWN, DEAD }

const RUN_SPEED := 108.0          # 30 ft speed
const ACCEL_GROUND := 1100.0
const ACCEL_AIR := 700.0
const FRICTION := 1300.0
const JUMP_VELOCITY := -322.0     # about 3.6 tiles; Strength-based jump
const FALL_GRAVITY_MULT := 1.45
const MAX_FALL := 420.0
const COYOTE := 0.09
const JUMP_BUFFER := 0.12
const DODGE_SPEED := 210.0
const DODGE_TIME := 0.32
const DODGE_IFRAMES := 0.28
const DODGE_COOLDOWN := 0.75
const WINDUP := 0.15
const ACTIVE := 0.11
const RECOVERY := 0.27
const BONUS_ACTION_COOLDOWN := 6.0
const DEATH_SAVE_INTERVAL := 2.0

var game: Node   # Main
var stats: Dictionary = Hero.new().combat_stats()
var hero: Hero
var reckless := false
var echo: Node2D
var _echo_cd := 0.0
var _potion_t := 0.0
var recovery := RECOVERY
var _mouse_aim := false
var _mouse_screen := Vector2.ZERO
var max_hp := 15
var hp := 15
var ac := 14
var facing := 1
var state := State.NORMAL
var rage_uses := 2
var rage_time := 0.0
var bonus_cd := 0.0
var used_second_wind := false   # "rise once per run" after three successes
var death_saves := Rules.DeathSaves.new()

var _coyote := 0.0
var _buffer := 0.0
var _state_time := 0.0
var _attack_phase := 0
var _attack_queued := false
var _hit_this_swing: Array = []
var _iframes := 0.0
var _dodge_cd := 0.0
var _drop_time := 0.0
var _step_time := 0.0
var _death_timer := 0.0
var _flash := 0.0
var _spike_cd := 0.0

var visual: Node2D
var sprite: AnimatedSprite2D
var weapon_pivot: Node2D
var slash: Node2D
var rage_glow: Node2D


func _ready() -> void:
	max_hp = stats.hp
	hp = max_hp
	ac = stats.ac
	rage_uses = stats.rage_uses
	recovery = RECOVERY * (0.5 if hero and hero.has_extra_attack() else 1.0)
	collision_layer = 0
	collision_mask = Room.LAYER_SOLID | Room.LAYER_PLATFORM
	floor_snap_length = 6.0
	floor_max_angle = deg_to_rad(50.0)   # the inn's stairs are 45 degrees
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 22)
	shape.shape = rect
	shape.position = Vector2(0, -11)
	add_child(shape)

	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	z_index = 5   # in front of the inn's counters, couches and patrons
	visual = Node2D.new()
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(visual)
	rage_glow = Node2D.new()
	rage_glow.set_script(preload("res://scripts/game/glow.gd"))
	visual.add_child(rage_glow)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.strip_frames(preload("res://assets/sprites/boarvhal.png"), 16, 28, {
		"idle": [0, 4, 6, true], "run": [4, 4, 11, true], "hit": [8, 1, 1, false]})
	sprite.offset = Vector2(0, -14)
	sprite.material = Art.flash_material()
	(sprite.material as ShaderMaterial).set_shader_parameter("frame_w", 16.0)
	(sprite.material as ShaderMaterial).set_shader_parameter("outline_color", Color(1.0, 0.93, 0.75, 0.55))
	sprite.play("idle")
	visual.add_child(sprite)
	weapon_pivot = Node2D.new()
	weapon_pivot.position = Vector2(3, -9)
	weapon_pivot.rotation = -0.55
	visual.add_child(weapon_pivot)
	var axe := Sprite2D.new()
	axe.texture = Art.region("weapon_double_axe")
	axe.offset = Vector2(0, -9)
	weapon_pivot.add_child(axe)
	slash = Node2D.new()
	slash.set_script(preload("res://scripts/game/slash.gd"))
	visual.add_child(slash)


## Re-reads stats after a level-up. Keeps current damage taken.
func apply_hero(h: Hero) -> void:
	hero = h
	var lost := max_hp - hp
	stats = h.combat_stats()
	max_hp = stats.hp
	hp = clampi(max_hp - lost, 1, max_hp) if hp > 0 else 0
	ac = stats.ac
	recovery = RECOVERY * (0.5 if h.has_extra_attack() else 1.0)
	hp_changed.emit()


func is_down() -> bool:
	return state == State.DOWN or state == State.DEAD


func is_invulnerable() -> bool:
	return _iframes > 0.0 or is_down()


func raging() -> bool:
	return rage_time > 0.0


func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-5, -22), Vector2(10, 22))


func _physics_process(delta: float) -> void:
	_state_time += delta
	_iframes = maxf(0.0, _iframes - delta)
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	bonus_cd = maxf(0.0, bonus_cd - delta)
	_echo_cd = maxf(0.0, _echo_cd - delta)
	_spike_cd = maxf(0.0, _spike_cd - delta)
	if rage_time > 0.0:
		rage_time = maxf(0.0, rage_time - delta)
		if rage_time == 0.0:
			game.log_line("Rage ends.")
	_flash = maxf(0.0, _flash - delta * 5.0)
	(sprite.material as ShaderMaterial).set_shader_parameter("flash", _flash)
	rage_glow.visible = raging() and not is_down()

	if _drop_time > 0.0:
		_drop_time -= delta
		if _drop_time <= 0.0:
			collision_mask |= Room.LAYER_PLATFORM

	if state == State.DEAD:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		_apply_gravity(delta)
		move_and_slide()
		return
	if state == State.DOWN:
		_process_down(delta)
		return

	var input_x := 0.0
	if game.accepting_input():
		input_x = Input.get_axis("move_left", "move_right")
		if Input.is_action_just_pressed("jump"):
			_buffer = JUMP_BUFFER
		if Input.is_action_just_pressed("interact"):
			game.try_interact()
		if game.peaceful():
			if Input.is_action_just_pressed("attack") and not Input.is_action_just_pressed("interact"):
				pass   # no axe-swinging in the taproom
		else:
			if Input.is_action_just_pressed("attack"):
				_attack_queued = true
			if Input.is_action_just_pressed("dodge"):
				_try_dodge(input_x)
			if Input.is_action_just_pressed("rage"):
				_try_rage()
			if Input.is_action_just_pressed("potion"):
				_try_potion()
			if Input.is_action_just_pressed("reckless"):
				_toggle_reckless()
			if Input.is_action_just_pressed("echo"):
				_try_echo()
	_buffer = maxf(0.0, _buffer - delta)
	if is_on_floor():
		_coyote = COYOTE
	else:
		_coyote = maxf(0.0, _coyote - delta)

	if _potion_t > 0.0:
		_potion_t -= delta
		input_x *= 0.3
	match state:
		State.NORMAL:
			_move(input_x, delta, 1.0)
			if _attack_queued:
				_start_attack()
		State.ATTACK:
			_move(input_x, delta, 0.35 if is_on_floor() else 0.8)
			_process_attack()
		State.DODGE:
			velocity.x = DODGE_SPEED * facing * (1.0 - 0.5 * (_state_time / DODGE_TIME))
			if _state_time >= DODGE_TIME:
				_set_state(State.NORMAL)
		State.HURT:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0, FRICTION * 0.5 * delta)
			if _state_time >= 0.22 and (is_on_floor() or _state_time >= 0.45):
				_set_state(State.NORMAL)

	if state != State.DODGE and state != State.HURT and _buffer > 0.0 and _coyote > 0.0:
		if Input.is_action_pressed("move_down") and _on_platform():
			collision_mask &= ~Room.LAYER_PLATFORM
			_drop_time = 0.22
			position.y += 2
		else:
			velocity.y = JUMP_VELOCITY
			game.sfx.play("jump", -10.0)
		_buffer = 0.0
		_coyote = 0.0
	if velocity.y < 0.0 and not Input.is_action_pressed("jump") and state != State.HURT:
		velocity.y *= 0.55 if velocity.y < -120.0 else 1.0

	_apply_gravity(delta)
	var was_air := not is_on_floor()
	move_and_slide()
	if was_air and is_on_floor():
		game.sfx.play("step", -12.0)
	_check_spikes()
	_animate(delta)


func _apply_gravity(delta: float) -> void:
	var g: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	velocity.y = minf(MAX_FALL, velocity.y + g * (FALL_GRAVITY_MULT if velocity.y > 0.0 else 1.0) * delta)


func _move(input_x: float, delta: float, control: float) -> void:
	_update_facing(input_x)
	var target := input_x * RUN_SPEED * control
	var accel := (ACCEL_GROUND if is_on_floor() else ACCEL_AIR)
	if input_x == 0.0 and is_on_floor():
		accel = FRICTION
	velocity.x = move_toward(velocity.x, target, accel * delta)


## Facing: toward the mouse cursor once the mouse has been used (even while running the other way),
## the right stick on a gamepad, otherwise the direction you are moving.
## You can turn while attacking, except during the instant the axe lands.
func _update_facing(input_x: float) -> void:
	if state != State.NORMAL and state != State.ATTACK:
		return
	if state == State.ATTACK and _attack_phase == 1:
		return
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X) if Input.get_connected_joypads().size() > 0 else 0.0
	if absf(stick) > 0.5:
		_mouse_aim = false
		facing = 1 if stick > 0.0 else -1
	elif _mouse_aim:
		var dx := get_global_mouse_position().x - global_position.x
		if absf(dx) > 3.0:
			facing = 1 if dx > 0.0 else -1
	elif input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_aim = true
		_mouse_screen = (event as InputEventMouse).position
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		_mouse_aim = false


func _on_platform() -> bool:
	var room: Room = game.room
	var y := floori((global_position.y + 2.0) / Room.T)
	if y < 0 or y >= room.h:
		return false
	var on_plat := false
	for ox in [-5.0, 0.0, 5.0]:
		var x := floori((global_position.x + ox) / Room.T)
		if x < 0 or x >= room.w:
			continue
		var ch := room.rows[y][x]
		if ch == "#":
			return false
		if ch == "=":
			on_plat = true
	return on_plat


func _set_state(s: int) -> void:
	state = s
	_state_time = 0.0


# ---------------- attack ----------------

func _start_attack() -> void:
	_attack_queued = false
	_set_state(State.ATTACK)
	_attack_phase = 0
	_hit_this_swing.clear()
	var tw := create_tween()
	tw.tween_property(weapon_pivot, "rotation", -2.3, WINDUP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(weapon_pivot, "rotation", 1.95, ACTIVE).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(weapon_pivot, "rotation", -0.55, recovery).set_trans(Tween.TRANS_SINE)


func _process_attack() -> void:
	if _attack_phase == 0 and _state_time >= WINDUP:
		_attack_phase = 1
		game.sfx.play("swing", -4.0)
		slash.call("play")
	if _attack_phase == 1:
		_resolve_hits()
		if _state_time >= WINDUP + ACTIVE:
			_attack_phase = 2
			game.note_swing(_hit_this_swing.size() > 0)
	if _attack_phase == 2 and _state_time >= WINDUP + ACTIVE + recovery * 0.55 and _attack_queued:
		_start_attack()
		return
	if _attack_phase == 2 and _state_time >= WINDUP + ACTIVE + recovery:
		_set_state(State.NORMAL)


func attack_rect() -> Rect2:
	var r := Rect2(Vector2(2, -30), Vector2(24, 34))
	if facing < 0:
		r.position.x = -2 - r.size.x
	r.position += global_position
	return r


func _resolve_hits() -> void:
	var area := attack_rect()
	for e: Enemy in game.living_enemies():
		if e in _hit_this_swing or not area.intersects(e.hurt_rect()):
			continue
		_hit_this_swing.append(e)
		_roll_attack_against(e)


func _roll_attack_against(e: Enemy) -> void:
	var adv := 0
	var reasons: Array[String] = []
	# Behind: the goblin faces away from Boar-vhal.
	var side_of_me := signf(global_position.x - e.global_position.x)
	if side_of_me != 0.0 and int(side_of_me) != e.facing:
		adv += 1
		reasons.append("behind")
	# From above: airborne and attacking down onto it.
	if not is_on_floor() and global_position.y < e.global_position.y - 6.0:
		adv += 1
		reasons.append("from above")
	if reckless:
		adv += 1
		reasons.append("reckless")
	if is_instance_valid(echo) and echo.global_position.distance_to(e.global_position) < 26.0:
		adv += 1
		reasons.append("flanked by your echo")
	var mode := Dice.combine(adv, 0)
	var wpn: Dictionary = stats.weapon
	var atk := Rules.attack(game.dice, wpn.attack, e.ac, mode)
	var dmg := {}
	var glancing: bool = not atk.hit and not atk.fumble
	if atk.hit:
		var bonus: int = wpn.bonus + (stats.rage_damage if raging() else 0)
		dmg = Rules.damage(game.dice, wpn.count, wpn.sides, bonus, atk.crit)
	elif glancing:
		var gl: Dictionary = Creatures.GLANCING
		dmg = Rules.damage(game.dice, gl.count, gl.sides, gl.bonus)
	game.show_attack(self, e, "Greataxe", atk, dmg, reasons, glancing)
	if atk.kept == 20 and hero:
		hero.nat20s += 1
	if not dmg.is_empty() and hero:
		hero.biggest_hit = maxi(hero.biggest_hit, int(dmg.total))
	if atk.hit or glancing:
		e.take_hit(dmg.total, atk.crit, facing, glancing)
	elif atk.fumble:
		_fumble_self()


## Natural 1: the swing goes wrong and Boar-vhal takes 1d4.
func _fumble_self() -> void:
	var f: Dictionary = Creatures.FUMBLE_SELF
	var d := Rules.damage(game.dice, f.count, f.sides, f.bonus)
	game.show_fumble(self, d)
	take_damage(d.total, false, -facing)


# ---------------- defence ----------------

## Called by an enemy whose strike connected. Rolls against Boar-vhal's AC.
func receive_attack(enemy: Node2D, wpn: Dictionary) -> void:
	if is_invulnerable():
		return
	var atk := Rules.attack(game.dice, wpn.attack, ac, Dice.Mode.ADVANTAGE if reckless else Dice.Mode.NORMAL)
	var dmg := {}
	if atk.hit:
		var resisted: bool = raging() and wpn.type in ["bludgeoning", "piercing", "slashing"]
		dmg = Rules.damage(game.dice, wpn.count, wpn.sides, wpn.bonus, atk.crit, resisted)
	game.show_attack(enemy, self, wpn.name, atk, dmg, ["you attacked recklessly"] if reckless else [], false)
	if atk.hit:
		take_damage(dmg.total, atk.crit, signf(global_position.x - enemy.global_position.x))
	else:
		game.sfx.play("deflect", -4.0)


func take_damage(amount: int, crit: bool, from_dir: float) -> void:
	if state == State.DEAD:
		return
	if state == State.DOWN:
		var r := death_saves.take_damage(crit)
		game.log_line("Hit while down: %s." % ("two death save failures" if crit else "one death save failure"))
		game.death_saves_changed()
		if r == "dead":
			_die("Boar-vhal has fallen.")
		return
	hp = maxi(0, hp - amount)
	_flash = 1.0
	hp_changed.emit()
	game.sfx.play("hit", -2.0)
	if hp <= 0:
		_go_down()
		return
	if state != State.ATTACK:
		_set_state(State.HURT)
	velocity = Vector2(from_dir * 110.0, -110.0)


func _go_down() -> void:
	_set_state(State.DOWN)
	death_saves.reset()
	rage_time = 0.0
	_death_timer = 1.2
	velocity.y = -80.0
	weapon_pivot.visible = false
	sprite.play("hit")
	var tw := create_tween()
	tw.tween_property(visual, "rotation", -PI / 2 * facing, 0.25)
	tw.parallel().tween_property(visual, "position", Vector2(0, -5), 0.25)
	game.sfx.play("thud")
	game.log_line("Boar-vhal drops to 0 HP. Death saves begin.")
	downed.emit()


func _process_down(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
	_apply_gravity(delta)
	move_and_slide()
	_death_timer -= delta
	if _death_timer <= 0.0:
		_death_timer = DEATH_SAVE_INTERVAL
		var r := Rules.death_save(game.dice)
		var outcome := death_saves.apply(r)
		game.show_death_save(r, outcome)
		if outcome == "revive":
			_rise("Natural 20! Boar-vhal surges back up with 1 HP.")
		elif outcome == "stable":
			if not used_second_wind:
				used_second_wind = true
				_rise("Three successes. Boar-vhal grits his teeth and rises with 1 HP (once per run).")
			else:
				_die("Stable, but out cold. The party drags Boar-vhal back to the tavern.")
		elif outcome == "dead":
			_die("Three failures. Boar-vhal has fallen.")


func _rise(msg: String) -> void:
	hp = 1
	hp_changed.emit()
	death_saves.reset()
	game.log_line(msg)
	game.banner(msg.split(".")[0] + ".", Color(0.6, 1.0, 0.6))
	weapon_pivot.visible = true
	sprite.play("idle")
	var tw := create_tween()
	tw.tween_property(visual, "rotation", 0.0, 0.25)
	tw.parallel().tween_property(visual, "position", Vector2.ZERO, 0.25)
	_iframes = 1.2
	_set_state(State.NORMAL)
	game.death_saves_changed()


func _die(reason: String) -> void:
	_set_state(State.DEAD)
	game.log_line(reason)
	died.emit(reason)


## Full reset between runs (long rest at the tavern).
func revive_full() -> void:
	_set_state(State.NORMAL)
	death_saves.reset()
	hp = max_hp
	rage_time = 0.0
	rage_uses = stats.rage_uses
	reckless = false
	used_second_wind = false
	_iframes = 0.0
	visual.rotation = 0.0
	visual.position = Vector2.ZERO
	weapon_pivot.visible = true
	weapon_pivot.rotation = -0.55
	sprite.play("idle")
	if is_instance_valid(echo):
		echo.queue_free()
	hp_changed.emit()


func force_down() -> void:
	if not is_down():
		hp = 0
		hp_changed.emit()
		_go_down()


# ---------------- abilities ----------------

func _try_dodge(input_x: float) -> void:
	if _dodge_cd > 0.0 or state == State.HURT or state == State.DODGE:
		return
	if state == State.ATTACK and _attack_phase == 1:
		return
	if input_x != 0.0:
		facing = 1 if input_x > 0.0 else -1
	weapon_pivot.rotation = -0.55
	_set_state(State.DODGE)
	_iframes = DODGE_IFRAMES
	_dodge_cd = DODGE_COOLDOWN
	game.sfx.play("dodge", -6.0)
	var tw := create_tween()
	tw.tween_property(visual, "rotation", TAU * facing, DODGE_TIME)
	tw.tween_callback(func(): visual.rotation = 0.0)


func _try_rage() -> void:
	if bonus_cd > 0.0:
		game.toast("Bonus action recharging (%.0fs)" % ceilf(bonus_cd))
		return
	if raging():
		game.toast("Already raging")
		return
	if rage_uses <= 0:
		game.toast("No Rage left. It returns on a long rest.")
		return
	rage_uses -= 1
	rage_time = stats.rage_seconds
	bonus_cd = BONUS_ACTION_COOLDOWN
	_flash = 0.8
	(sprite.material as ShaderMaterial).set_shader_parameter("flash_color", Color(1, 0.3, 0.2))
	get_tree().create_timer(0.3).timeout.connect(func():
		(sprite.material as ShaderMaterial).set_shader_parameter("flash_color", Color.WHITE))
	game.banner("RAGE!", Color(1.0, 0.45, 0.35))
	game.log_line("Bonus action: Rage (%d left). +2 damage, resistance to bludgeoning, piercing and slashing for 1 minute." % rage_uses)
	game.sfx.play("thud", -4.0)


func _toggle_reckless() -> void:
	if not hero or not hero.has_reckless():
		game.toast("Reckless Attack unlocks at level 2.")
		return
	reckless = not reckless
	game.toast("Reckless Attack ON: advantage for you, and for them." if reckless else "Reckless Attack off.")


func _try_potion() -> void:
	if _potion_t > 0.0 or is_down():
		return
	if game.run_potions <= 0:
		game.toast("No potions. Buy them at the tavern.")
		return
	if hp >= max_hp:
		game.toast("Already at full health.")
		return
	game.run_potions -= 1
	_potion_t = 0.6
	var faces: Array[int] = game.dice.roll(2, 4)
	var heal: int = faces[0] + faces[1] + 2
	hp = mini(max_hp, hp + heal)
	hp_changed.emit()
	game.toast("Potion of Healing: +%d HP (2d4+2)" % heal)
	game.log_line("Potion of Healing: 2d4 %s +2 = %d HP regained." % [str(faces), heal])
	game.sfx.play("dodge", -4.0)


func _try_echo() -> void:
	if not hero or not hero.has_echo():
		game.toast("Echo unlocks at level 3.")
		return
	if _echo_cd > 0.0:
		return
	if not is_instance_valid(echo):
		if bonus_cd > 0.0:
			game.toast("Bonus action recharging (%.0fs)" % ceilf(bonus_cd))
			return
		bonus_cd = BONUS_ACTION_COOLDOWN
		echo = Node2D.new()
		var ghost := AnimatedSprite2D.new()
		ghost.sprite_frames = sprite.sprite_frames
		ghost.offset = sprite.offset
		ghost.play("idle")
		ghost.modulate = Color(0.55, 0.75, 1.0, 0.55)
		ghost.scale.x = facing
		echo.add_child(ghost)
		echo.global_position = global_position
		echo.z_index = -1
		game.add_child(echo)
		game.log_line("Bonus action: Boar-vhal leaves an Echo. Goblins beside it are flanked.")
		game.sfx.play("dodge", -8.0)
	else:
		# Swap places with the echo.
		var here := global_position
		global_position = echo.global_position
		echo.global_position = here
		reset_physics_interpolation()
		velocity = Vector2.ZERO
		_echo_cd = 1.5
		_iframes = maxf(_iframes, 0.2)
		game.sfx.play("dodge", -6.0)


# ---------------- hazards and animation ----------------

func _check_spikes() -> void:
	if _spike_cd > 0.0:
		return
	var feet := Rect2(global_position + Vector2(-4, -6), Vector2(8, 6))
	for r: Rect2 in game.room.spike_rects:
		if feet.intersects(r):
			_spike_cd = 1.4
			var ds_mode := Dice.Mode.ADVANTAGE if hero and hero.level >= 2 else Dice.Mode.NORMAL
			var sv := Rules.save(game.dice, stats.dex_save, Creatures.SPIKES.dc, ds_mode)
			var dmg := Rules.damage(game.dice, Creatures.SPIKES.count, Creatures.SPIKES.sides, 0, false,
				raging())
			var total: int = dmg.total if not sv.success else floori(dmg.total / 2.0)
			game.show_save(self, "DEX save", sv, total, dmg)
			if total > 0:
				take_damage(total, false, 0.0)
			if not is_down():
				# Throw Boar-vhal up and toward the nearer edge so the pit can't chain-kill him.
				var cx := r.position.x + r.size.x / 2.0
				var left_edge := r.position.x
				var right_edge := r.position.x + r.size.x
				for o: Rect2 in game.room.spike_rects:
					left_edge = minf(left_edge, o.position.x) if absf(o.position.y - r.position.y) < 1.0 and o.position.x + o.size.x >= left_edge - 1.0 else left_edge
					right_edge = maxf(right_edge, o.position.x + o.size.x) if absf(o.position.y - r.position.y) < 1.0 and o.position.x <= right_edge + 1.0 else right_edge
				var mid := (left_edge + right_edge) / 2.0
				var dir := -1.0 if global_position.x < mid else 1.0
				facing = int(dir)
				_set_state(State.HURT)
				velocity = Vector2(dir * 130.0, -330.0)
				_iframes = maxf(_iframes, 0.5)
			return


func _animate(_delta: float) -> void:
	if game.has_method("_arg") and visual.scale.x != facing and game.get("_face_log"):
		print("[facing] %d state=%s moving=%s" % [facing, State.keys()[state], Input.is_action_pressed("move_right") or Input.is_action_pressed("move_left")])
	visual.scale.x = facing
	if state == State.DODGE:
		return
	if state == State.HURT:
		sprite.play("hit")
		return
	if absf(velocity.x) > 12.0 and is_on_floor():
		sprite.play("run")
		_step_time -= _delta
		if _step_time <= 0.0:
			_step_time = 0.28
			game.sfx.play("step", -16.0)
	else:
		sprite.play("idle")
	if not is_on_floor():
		sprite.play("run")
		sprite.frame = 1 if velocity.y < 0 else 3
	var blink := _iframes > 0.0 and state != State.DODGE and fmod(_iframes, 0.12) < 0.06
	sprite.modulate.a = 0.45 if blink else 1.0
