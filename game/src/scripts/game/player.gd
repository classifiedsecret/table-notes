class_name Player
extends CharacterBody2D
## The hero in real time. Movement is platformer-tuned; every hit is a 5e roll.
## Class spells and features live in HeroKit (kit); this owns movement, attacks and damage.

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
var echo_target := Vector2.INF   # where the echo is gliding to (free movement)
var _echo_round := 2.0           # end-of-turn check for the echo, once a "round"
const ECHO_RANGE_PX := 96.0      # 30 feet
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
var weapon_sprite: Sprite2D
var kit: HeroKit
var form_data: Dictionary = {}    # Wild Shape beast, or empty
var _look_key := ""
var _climbing := false
var _shot_done := false


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
	sprite.material = Art.flash_material()
	visual.add_child(sprite)
	weapon_pivot = Node2D.new()
	weapon_pivot.position = Vector2(3, -9)
	weapon_pivot.rotation = -0.55
	visual.add_child(weapon_pivot)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.offset = Vector2(0, -9)
	weapon_pivot.add_child(weapon_sprite)
	slash = Node2D.new()
	slash.set_script(preload("res://scripts/game/slash.gd"))
	visual.add_child(slash)
	_apply_look()
	kit = HeroKit.new()
	add_child(kit)
	kit.setup(self, game)


## The hero's sprite sheet and weapon (or the Wild Shape beast's).
func _apply_look() -> void:
	var key: String = hero.key if hero else "boarvhal"
	var info := Kits.info(key)
	if not form_data.is_empty():
		var fr: Array = form_data.frame
		sprite.sprite_frames = Art.strip_frames(load("res://assets/sprites/%s.png" % form_data.sprite), fr[0], fr[1], {
			"idle": [0, 4, 5, true], "run": [4, 4, 12, true], "hit": [8, 1, 1, false]})
		sprite.offset = Vector2(0, -fr[1] / 2.0)
		weapon_pivot.visible = false
	else:
		sprite.sprite_frames = Art.strip_frames(load("res://assets/sprites/%s.png" % info.sprite), 16, 28, {
			"idle": [0, 4, 6, true], "run": [4, 4, 11, true], "hit": [8, 1, 1, false]})
		sprite.offset = Vector2(0, -14)
		weapon_sprite.texture = Art.region(info.weapon_sprite)
		weapon_pivot.visible = not is_down()
	sprite.play("idle")
	_look_key = key


## Wild Shape in or out. An empty dictionary returns to the hero's own shape.
func set_form(f: Dictionary) -> void:
	form_data = f
	ac = int(f.ac) if not f.is_empty() else int(stats.ac)
	_climbing = false
	_apply_look()
	hp_changed.emit()


## Spells auto-aim: the nearest living foe within `range_px` (any direction), or null.
func nearest_enemy(range_px: float) -> Enemy:
	var best: Enemy = null
	var bd := range_px
	for e: Enemy in game.living_enemies():
		var d := e.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = e
	return best


func current_weapon() -> Dictionary:
	return form_data.weapon if not form_data.is_empty() else stats.weapon


func run_speed() -> float:
	var ft: float = form_data.get("speed_ft", stats.get("speed_ft", 30))
	return RUN_SPEED * ft / 30.0


func short_name() -> String:
	return hero.short() if hero else "Boar-vhal"


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)
	hp_changed.emit()


## A quick raise of the staff or hand for spells.
func cast_pose() -> void:
	if not form_data.is_empty():
		return
	var tw := create_tween()
	tw.tween_property(weapon_pivot, "rotation", -1.6, 0.1)
	tw.tween_property(weapon_pivot, "rotation", -0.55, 0.3)


## Re-reads stats after a level-up. Keeps current damage taken.
func apply_hero(h: Hero) -> void:
	hero = h
	var lost := max_hp - hp
	stats = h.combat_stats()
	max_hp = stats.hp
	hp = clampi(max_hp - lost, 1, max_hp) if hp > 0 else 0
	ac = stats.ac if form_data.is_empty() else int(form_data.ac)
	recovery = RECOVERY * (0.5 if h.has_extra_attack() else 1.0)
	if is_inside_tree():
		if _look_key != h.key:
			form_data = {}
			ac = stats.ac
			_apply_look()
		kit.refresh()
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
	_update_echo(delta)
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
				kit.press("L")
			if Input.is_action_just_pressed("potion"):
				_try_potion()
			if Input.is_action_just_pressed("reckless"):
				kit.press("R")
			if Input.is_action_just_pressed("echo"):
				kit.press("U")
			if Input.is_action_just_pressed("form"):
				kit.press("Y")
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
			if _attack_queued and not kit.busy():
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

	# Giant wolf spider: push into a wall to climb it.
	_climbing = form_data.get("climb", false) and is_on_wall() and input_x != 0.0 and signf(get_wall_normal().x) == -signf(input_x)
	if _climbing:
		velocity.y = -70.0
	else:
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
	var target := input_x * run_speed() * control
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

func _attack_kind() -> String:
	return str(current_weapon().get("kind", "melee"))


func _recovery() -> float:
	match _attack_kind():
		"bolt": return 0.42
		"whip": return 0.36
	return recovery * float(current_weapon().get("swing", 1.0))


func _start_attack() -> void:
	_attack_queued = false
	_set_state(State.ATTACK)
	_attack_phase = 0
	_shot_done = false
	_hit_this_swing.clear()
	if not form_data.is_empty():
		var bite := create_tween()
		bite.tween_property(visual, "position:x", 4.0 * facing, WINDUP + ACTIVE)
		bite.tween_property(visual, "position:x", 0.0, _recovery())
		return
	var tw := create_tween()
	tw.tween_property(weapon_pivot, "rotation", -2.3, WINDUP).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(weapon_pivot, "rotation", 1.95, ACTIVE).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(weapon_pivot, "rotation", -0.55, _recovery()).set_trans(Tween.TRANS_SINE)


func _process_attack() -> void:
	var kind := _attack_kind()
	if _attack_phase == 0 and _state_time >= WINDUP:
		_attack_phase = 1
		if kind == "melee":
			game.sfx.play("swing", -4.0)
			if form_data.is_empty():
				slash.call("play")
	if _attack_phase == 1:
		if kind == "melee":
			_resolve_hits()
		elif not _shot_done:
			_shot_done = true
			_fire_primary(kind)
		if _state_time >= WINDUP + ACTIVE:
			_attack_phase = 2
			game.note_swing(_hit_this_swing.size() > 0)
	var rec := _recovery()
	if _attack_phase == 2 and _state_time >= WINDUP + ACTIVE + rec * 0.55 and _attack_queued:
		_start_attack()
		return
	if _attack_phase == 2 and _state_time >= WINDUP + ACTIVE + rec:
		_set_state(State.NORMAL)


## Fire Bolt (a missile) or Thorn Whip (a 30-foot lash that pulls).
func _fire_primary(kind: String) -> void:
	var wpn := current_weapon()
	if kind == "bolt":
		# Fire Bolt locks onto the nearest foe in sight and curves after it.
		var tgt := nearest_enemy(260.0)
		if tgt:
			facing = 1 if tgt.global_position.x >= global_position.x else -1
			visual.scale.x = facing
		var hand := global_position + Vector2(facing * 9.0, -16.0)
		var aim := Vector2(facing, 0.0)
		if tgt:
			aim = (tgt.global_position + Vector2(0, -10) - hand).normalized()
		game.sfx.play("swing", -8.0, 0.3)
		var b := SpellFx.bolt(game, hand, aim * 300.0, HeroKit.SPELL_COLORS.fire, func(e): roll_attack(e, wpn))
		b.target = tgt
		return
	# Thorn whip lashes at the nearest foe within 30 feet, on either side.
	var reach: float = wpn.get("reach", 72.0)
	var near := nearest_enemy(reach + 8.0)
	if near:
		facing = 1 if near.global_position.x >= global_position.x else -1
		visual.scale.x = facing
		var h2 := global_position + Vector2(facing * 9.0, -16.0)
		SpellFx.line(game, h2, near.global_position + Vector2(0, -10), HeroKit.SPELL_COLORS.nature, 0.22, true)
		game.sfx.play("swing", -6.0, 0.3)
		_hit_this_swing.append(near)
		var hit := roll_attack(near, wpn)
		if hit.get("hit", false) and not near.is_dead():
			near.velocity = Vector2(signf(global_position.x - near.global_position.x) * 230.0, -60.0)
		return
	var hand := global_position + Vector2(facing * 9.0, -16.0)
	var lash := Rect2(global_position + Vector2(0 if facing > 0 else -reach, -24), Vector2(reach, 20))
	var best: Enemy = null
	var bd := 9999.0
	for e: Enemy in game.living_enemies():
		if lash.intersects(e.hurt_rect()):
			var d := absf(e.global_position.x - global_position.x)
			if d < bd:
				bd = d
				best = e
	var tip := hand + Vector2(facing * (bd if best else reach), 2.0)
	SpellFx.line(game, hand, tip, HeroKit.SPELL_COLORS.nature, 0.22, true)
	game.sfx.play("swing", -6.0, 0.3)
	if best:
		_hit_this_swing.append(best)
		var atk := roll_attack(best, wpn)
		if atk.get("hit", false) and not best.is_dead():
			# Pulled up to 10 feet toward Suilean.
			best.velocity = Vector2(signf(global_position.x - best.global_position.x) * 230.0, -60.0)


func attack_rect() -> Rect2:
	var reach: float = current_weapon().get("reach", 24.0)
	var r := Rect2(Vector2(2, -30), Vector2(reach, 34))
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
		roll_attack(e, current_weapon())


## One attack roll by the hero (weapon, cantrip or spell) against an enemy, with every
## real-time source of advantage, the table's glancing rule and the class riders.
func roll_attack(e: Enemy, wpn: Dictionary) -> Dictionary:
	var adv := 0
	var dis := 0
	var reasons: Array[String] = []
	var ranged: bool = wpn.get("kind", "melee") == "bolt" or (wpn.get("spell", false) and wpn.get("kind", "") == "")
	if not ranged:
		# Behind: the goblin faces away from the hero.
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
	if e.restrained_t > 0.0:
		adv += 1
		reasons.append("target restrained")
	if ranged and _foe_adjacent():
		dis += 1
		reasons.append("casting in melee")
	var forced := kit.take_foresight()
	var atk := Rules.attack(game.dice, wpn.attack, e.ac, Dice.combine(adv, dis), forced)
	if not atk.hit:
		kit.try_blessing(atk, e.ac)
	var dmg := {}
	var glancing: bool = not atk.hit and not atk.fumble
	if atk.hit:
		var bonus: int = int(wpn.bonus) + (int(stats.rage_damage) if raging() and form_data.is_empty() else 0)
		dmg = Rules.damage(game.dice, wpn.count, wpn.sides, bonus, atk.crit)
		if atk.crit and stats.get("savage", false) and form_data.is_empty() and not wpn.get("spell", false):
			var extra: int = game.dice.die(wpn.sides)
			dmg.faces.append(extra)
			dmg.total += extra
			dmg.raw += extra
		if wpn.get("kind", "") == "melee" and not wpn.get("spell", false):
			var sm := kit.smite_damage(atk.crit)
			if not sm.is_empty():
				dmg.total += int(sm.total)
				reasons.append("Divine Smite +%d" % sm.total)
		if wpn.has("poison_dc"):
			var sv := Rules.save(game.dice, e.save_bonus("con"), int(wpn.poison_dc))
			var pd := Rules.damage(game.dice, 2, 6, 0)
			var pt: int = pd.total if not sv.success else floori(pd.total / 2.0)
			dmg.total += pt
			game.log_line("Poison bite: %s CON save %d vs DC %d, %d poison." % [e.data.name, sv.total, sv.dc, pt])
	elif glancing:
		var gl: Dictionary = Creatures.GLANCING
		dmg = Rules.damage(game.dice, gl.count, gl.sides, gl.bonus)
	game.show_attack(self, e, wpn.name, atk, dmg, reasons, glancing)
	if atk.kept == 20 and hero:
		hero.nat20s += 1
	if not dmg.is_empty() and hero:
		hero.biggest_hit = maxi(hero.biggest_hit, int(dmg.total))
	if atk.hit or glancing:
		e.take_hit(dmg.total, atk.crit, facing, glancing)
	elif atk.fumble:
		_fumble_self(wpn.name)
	return atk


func _foe_adjacent() -> bool:
	for e: Enemy in game.living_enemies():
		if absf(e.global_position.x - global_position.x) < 20.0 and absf(e.global_position.y - global_position.y) < 18.0:
			return true
	return false


## Natural 1: the attack goes wrong and the hero takes 1d4.
func _fumble_self(what := "attack") -> void:
	var f: Dictionary = Creatures.FUMBLE_SELF
	var d := Rules.damage(game.dice, f.count, f.sides, f.bonus)
	game.show_fumble(self, d, what)
	take_damage(d.total, false, -facing)


# ---------------- defence ----------------

## Called by an enemy whose strike connected. Rolls against the hero's AC.
func receive_attack(enemy: Node2D, wpn: Dictionary) -> void:
	if is_invulnerable():
		return
	var adv := 1 if reckless else 0
	var dis := 0
	var reasons: Array[String] = []
	if reckless:
		reasons.append("you attacked recklessly")
	if enemy is Enemy and (enemy as Enemy).restrained_t > 0.0:
		dis += 1
		reasons.append("it is restrained")
	var forced := kit.take_foresight()
	var atk := Rules.attack(game.dice, wpn.attack, ac, Dice.combine(adv, dis), forced)
	var dmg := {}
	if atk.hit:
		var resisted: bool = raging() and wpn.type in ["bludgeoning", "piercing", "slashing"]
		dmg = Rules.damage(game.dice, wpn.count, wpn.sides, wpn.bonus, atk.crit, resisted)
	game.show_attack(enemy, self, wpn.name, atk, dmg, reasons, false)
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
			_die("%s has fallen." % short_name())
		return
	amount = kit.absorb(amount)
	if amount <= 0:
		_flash = 1.0
		hp_changed.emit()
		game.sfx.play("hit", -4.0)
		return
	kit.concentration_check(amount)
	if hp - amount <= 0 and kit.try_relentless():
		amount = hp - 1
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
	kit.end_form(false)
	game.log_line("%s drops to 0 HP. Death saves begin." % short_name())
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
		resolve_death_save(outcome)


## Shared with the boss battle.
func resolve_death_save(outcome: String) -> void:
	var n := short_name()
	if outcome == "revive":
		_rise("Natural 20! %s surges back up with 1 HP." % n)
	elif outcome == "stable":
		if not used_second_wind:
			used_second_wind = true
			_rise("Three successes. %s grits %s teeth and rises with 1 HP (once per run)." % [n, hero.pronoun("his") if hero else "his"])
		else:
			_die("Stable, but out cold. The party drags %s back to the tavern." % n)
	elif outcome == "dead":
		_die("Three failures. %s has fallen." % n)


func _rise(msg: String) -> void:
	hp = 1
	hp_changed.emit()
	death_saves.reset()
	game.log_line(msg)
	game.banner(msg.split(".")[0] + ".", Color(0.6, 1.0, 0.6))
	weapon_pivot.visible = form_data.is_empty()
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
	kit.long_rest()
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


## Free movement: command the echo anywhere; it glides there (it can float up, too).
func command_echo(to: Vector2) -> void:
	if not is_instance_valid(echo):
		game.toast("No echo to command. Press U to make one.")
		return
	echo_target = to
	game.sfx.play("dodge", -12.0, 0.4)


func _update_echo(delta: float) -> void:
	if not is_instance_valid(echo):
		echo_target = Vector2.INF
		return
	if echo_target != Vector2.INF:
		var dv := echo_target - echo.global_position
		var step := 150.0 * delta
		if dv.length() <= step:
			echo.global_position = echo_target
			echo_target = Vector2.INF
		else:
			echo.global_position += dv.normalized() * step
	var far := echo.global_position.distance_to(global_position) > ECHO_RANGE_PX
	echo.modulate.a = (0.45 + 0.4 * absf(sin(Time.get_ticks_msec() / 90.0))) if far else 1.0
	# End of a "turn" (a round every 2 seconds): more than 30 feet away and it fades.
	_echo_round -= delta
	if _echo_round <= 0.0:
		_echo_round = 2.0
		if far:
			echo.queue_free()
			echo = null
			echo_target = Vector2.INF
			game.log_line("The echo is more than 30 ft from Boar-vhal and fades away.")
			game.toast("Your echo fades (more than 30 ft away).")


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
		_echo_round = 2.0
		echo_target = Vector2.INF
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
			var ds_mode := Dice.Mode.ADVANTAGE if hero and hero.key == "boarvhal" and hero.level >= 2 else Dice.Mode.NORMAL
			var sv := Rules.save(game.dice, stats.dex_save, Creatures.SPIKES.dc, ds_mode)
			var dmg := Rules.damage(game.dice, Creatures.SPIKES.count, Creatures.SPIKES.sides, 0, false,
				raging())
			var total: int = dmg.total if not sv.success else floori(dmg.total / 2.0)
			game.show_save(self, "DEX save", sv, total, dmg)
			if total > 0:
				take_damage(total, false, 0.0)
			if not is_down():
				# Throw the hero up and toward the nearer edge so the pit can't chain-kill them.
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
	if not is_on_floor() and not _climbing:
		sprite.play("run")
		sprite.frame = 1 if velocity.y < 0 else 3
	var blink := _iframes > 0.0 and state != State.DODGE and fmod(_iframes, 0.12) < 0.06
	sprite.modulate.a = 0.45 if blink else 1.0
