class_name Enemy
extends CharacterBody2D
## Goblin in real time, top-down: paths around walls to the hero (or the nearest companion),
## telegraphs its strike, rolls against AC. Archers keep their distance and need a clear line.

enum State { CHASE, WINDUP, STRIKE, RECOVER, STAGGER, RETREAT, DEAD }

var game: Node
var data: Dictionary
var max_hp := 7
var hp := 7
var ac := 12
var facing := -1                 # sprite flip
var look := Vector2.LEFT          # which way it is facing (for "behind" and its strike arc)
var _path := PackedVector2Array()
var _repath := 0.0
var _alert := false
var _knock := Vector2.ZERO
var _walk := Vector2.ZERO
var state := State.CHASE
var speed := 80.0
var _t := 0.0
var _cd := 0.6
var _flash := 0.0
var _struck := false
var _show_bar := 0.0
var _jump_cd := 0.5
var _drop_t := 0.0
var restrained_t := 0.0    # Entangle: can't move; attacks against it have advantage
var frightened_t := 0.0    # Dread Aura: flees from the hero and won't attack

## Saving throw bonuses (SRD 5.2 goblins, bugbear).
const SAVES := {
	"Goblin": {"str": -1, "dex": 2, "con": 0, "wis": -1},
	"Bugbear": {"str": 2, "dex": 2, "con": 1, "wis": 0},
}

var visual: Node2D
var sprite: AnimatedSprite2D
var weapon_pivot: Node2D
var warn: Label
var bar: Node2D


func setup(g: Node, d: Dictionary) -> void:
	game = g
	data = d
	ac = d.ac
	var hp_roll: Array[int] = game.dice.roll(d.hp_count, d.hp_sides)
	max_hp = int(d.get("hp_bonus", 0))
	for v in hp_roll:
		max_hp += v
	max_hp = maxi(1, roundi(max_hp * float(d.get("hp_scale", 1.0))))
	hp = max_hp
	speed = 74.0 if d.name == "Goblin Minion" else (58.0 if d.get("ranged", false) else 64.0)
	game.log_line("A %s appears." % d.name)


func _ready() -> void:
	collision_layer = 0
	collision_mask = World.LAYER_SOLID
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 6)
	shape.shape = rect
	shape.position = Vector2(0, -3)
	add_child(shape)
	var shadow := Sprite2D.new()
	shadow.texture = Player.shadow_tex()
	shadow.modulate = Color(0, 0, 0, 0.35)
	add_child(shadow)
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	visual = Node2D.new()
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(visual)
	sprite = AnimatedSprite2D.new()
	var fr: Array = data.get("frame", [16, 16])
	sprite.sprite_frames = Art.strip_frames(load("res://assets/sprites/%s.png" % data.sprite), fr[0], fr[1], {
		"idle": [0, 4, 6, true], "run": [4, 4, 10, true]})
	sprite.offset = Vector2(0, -fr[1] / 2.0)
	sprite.material = Art.flash_material()
	sprite.play("idle")
	visual.add_child(sprite)
	weapon_pivot = Node2D.new()
	weapon_pivot.position = Vector2(0, -6)
	add_child(weapon_pivot)
	var w := Sprite2D.new()
	w.texture = Art.region(data.weapon_sprite) if str(data.weapon_sprite) != "" else null   # rats bite
	if w.texture:
		w.offset = Vector2(0, -w.texture.get_height() / 2.0 + 2.0)
	w.rotation = PI / 2.0
	weapon_pivot.add_child(w)
	warn = Label.new()
	warn.label_settings = Art.label_settings(16, Color(1, 0.85, 0.2), 3, true)
	warn.text = "!"
	warn.position = Vector2(-3, -float(fr[1]) - 18.0)
	warn.visible = false
	add_child(warn)
	bar = Node2D.new()
	bar.set_script(preload("res://scripts/game/enemy_bar.gd"))
	bar.position = Vector2(0, -float(fr[1]) - 6.0)
	bar.z_index = 60
	add_child(bar)


func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-7, -15), Vector2(14, 17))


func save_bonus(ability: String) -> int:
	var fam := "Bugbear" if str(data.get("name", "")).contains("Bugbear") else "Goblin"
	return int(data.get("saves", {}).get(ability, SAVES[fam].get(ability, 0)))


func restrain(secs: float) -> void:
	restrained_t = maxf(restrained_t, secs)
	velocity = Vector2.ZERO
	FloatText.fling(game, global_position + Vector2(0, -22), Vector2(0, -1), "RESTRAINED", "", Color(0.55, 0.9, 0.45), 0, 0.9)


func frighten(secs: float) -> void:
	frightened_t = maxf(frightened_t, secs)
	if state == State.WINDUP:
		warn.visible = false
		_go(State.CHASE)
	FloatText.fling(game, global_position + Vector2(0, -22), Vector2(0, -1), "FRIGHTENED", "", Color(0.8, 0.55, 1.0), 0, 0.9)


func is_dead() -> bool:
	return state == State.DEAD


func is_staggered() -> bool:
	return state == State.STAGGER


func _go(s: int) -> void:
	state = s
	_t = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_cd = maxf(0.0, _cd - delta)
	var p: Node2D = game.enemy_target(self)
	var to_p := p.global_position - global_position
	var dist := to_p.length()
	var dir := to_p.normalized() if dist > 0.5 else look
	restrained_t = maxf(0.0, restrained_t - delta)
	frightened_t = maxf(0.0, frightened_t - delta)
	visual.modulate = Color(0.75, 1.0, 0.7) if restrained_t > 0.0 else (Color(0.85, 0.7, 1.0) if frightened_t > 0.0 else Color.WHITE)
	# Goblins notice you when they can see you (they have darkvision), or once hurt.
	if not _alert and dist < 170.0 and game.room.line_clear(global_position + Vector2(0, -6), p.global_position + Vector2(0, -6)):
		_alert = true
	var want := Vector2.ZERO
	var spd := speed
	match state:
		State.DEAD:
			pass
		State.CHASE:
			if frightened_t > 0.0:
				# Flee from the hero; no attacks while terrified.
				want = -dir
				look = -dir
				spd = speed * 0.9
			elif not _alert or not game.accepting_input():
				want = Vector2.ZERO
			elif p.is_down():
				_go(State.RETREAT)
			elif data.get("ranged", false):
				want = _archer_chase(p, to_p, dist)
			else:
				look = dir
				if dist <= 18.0 and _cd <= 0.0:
					_go(State.WINDUP)
				elif dist > 14.0:
					want = _follow_path(p.global_position)
		State.WINDUP:
			# Facing is locked during the wind-up: get behind it, or out of its reach.
			weapon_pivot.rotation = look.angle() + (0.0 if data.get("ranged", false) else -1.6 * minf(1.0, _t / (data.windup * 0.6)))
			warn.visible = true
			_flash = 0.35 + 0.25 * sin(_t * 40.0)
			(sprite.material as ShaderMaterial).set_shader_parameter("flash_color", Color(1, 0.85, 0.3))
			if _t >= data.windup:
				_go(State.STRIKE)
				_struck = false
				(sprite.material as ShaderMaterial).set_shader_parameter("flash_color", Color.WHITE)
				warn.visible = false
		State.STRIKE:
			if data.get("ranged", false):
				if not _struck:
					_struck = true
					var from := global_position + Vector2(0, -8)
					var aim_at := (p.global_position + Vector2(0, -8) - from).normalized()
					Projectile.fire(game, from, aim_at * 190.0, data.name, data.weapon, Color(0.85, 0.75, 0.55))
					game.sfx.play("swing", -14.0, 0.3)
			else:
				weapon_pivot.rotation = look.angle() + lerpf(-1.6, 1.3, minf(1.0, _t / 0.08))
				if _t < 0.06:
					want = look * 0.8
				if not _struck and _t >= 0.04:
					_struck = true
					game.sfx.play("swing", -10.0, 0.2)
					# It lands if the target is still in reach and in front: a roll or a step away beats it.
					for t in _strike_targets():
						var d: Vector2 = t.global_position - global_position
						if d.length() <= 24.0 and look.dot(d.normalized()) > 0.1 and not t.is_invulnerable():
							t.receive_attack(self, data.weapon)
			if _t >= 0.12:
				_go(State.RECOVER)
				_cd = data.cooldown
		State.RECOVER:
			if not data.get("ranged", false):
				weapon_pivot.rotation = look.angle() + lerpf(1.3, 0.0, minf(1.0, _t / 0.3))
			if data.name == "Goblin Minion" and _t < 0.25:
				# Nimble Escape: hop back out of reach after stabbing.
				want = -look * 1.2
			if _t >= 0.4:
				_go(State.CHASE)
		State.STAGGER:
			if _t >= 0.3:
				_go(State.CHASE)
		State.RETREAT:
			# The hero is down: goblins back off and jeer instead of finishing them.
			want = -dir * 0.5 if dist < 60.0 else Vector2.ZERO
			if not p.is_down():
				_go(State.CHASE)
	if state == State.CHASE and not data.get("ranged", false) and state != State.WINDUP:
		weapon_pivot.rotation = lerp_angle(weapon_pivot.rotation, look.angle(), 0.3)
	# Keep personal space from other goblins so a pack reads as separate bodies.
	if state != State.DEAD and state != State.STRIKE:
		for o: Enemy in game.living_enemies():
			if o == self:
				continue
			var off := global_position - o.global_position
			if off.length() < 14.0:
				want += (off.normalized() if off.length() > 0.1 else Vector2.RIGHT.rotated(get_instance_id())) * (14.0 - off.length()) / 14.0
	if restrained_t > 0.0 and state != State.DEAD:
		want = Vector2.ZERO
	# Walking speed and a hit's shove are kept apart, so a shove happens once and fades.
	_walk = _walk.move_toward(want * spd, 700.0 * delta)
	velocity = _walk + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 700.0 * delta)
	move_and_slide()
	if absf(look.x) > 0.1:
		facing = 1 if look.x > 0.0 else -1
	visual.scale.x = facing
	weapon_pivot.z_index = -1 if look.y < -0.3 else 1
	if state != State.DEAD:
		sprite.play("run" if velocity.length() > 10.0 else "idle")


func _strike_targets() -> Array:
	var out: Array = [game.player]
	for c in game.companions:
		if is_instance_valid(c) and not c.is_down():
			out.append(c)
	if is_instance_valid(game.player.echo):
		out.append(game.player.echo)
	return out


func _follow_path(target: Vector2) -> Vector2:
	_repath -= get_physics_process_delta_time()
	if _repath <= 0.0 or _path.is_empty():
		_repath = 0.35
		_path = game.room.path_to(global_position + Vector2(0, -3), target + Vector2(0, -3))
		if _path.size() > 0:
			_path.remove_at(0)
	while _path.size() > 0 and global_position.distance_to(_path[0] + Vector2(0, 3)) < 5.0:
		_path.remove_at(0)
	if _path.is_empty():
		return (target - global_position).normalized()
	return (_path[0] + Vector2(0, 3) - global_position).normalized()


## Archers keep their distance and shoot when they have a clear line on the target.
func _archer_chase(p: Node2D, to_p: Vector2, dist: float) -> Vector2:
	look = to_p.normalized() if dist > 0.5 else look
	var sees: bool = game.room.line_clear(global_position + Vector2(0, -8), p.global_position + Vector2(0, -8))
	var want := Vector2.ZERO
	if dist < 56.0:
		want = -look
	elif dist > 140.0 or not sees:
		want = _follow_path(p.global_position)
	if _cd <= 0.0 and sees and dist < 200.0:
		_go(State.WINDUP)
		want = Vector2.ZERO
	return want


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta * 6.0)
	_show_bar = maxf(0.0, _show_bar - delta)
	(sprite.material as ShaderMaterial).set_shader_parameter("flash", _flash)
	if state != State.DEAD:
		bar.call("set_values", hp, max_hp, data.display, _show_bar > 0.0 or hp < max_hp)


func take_hit(amount: int, crit: bool, from_dir: Variant, glancing: bool) -> void:
	if state == State.DEAD:
		return
	_alert = true
	var dir: Vector2 = from_dir if from_dir is Vector2 else Vector2(float(from_dir), 0.0)
	hp = maxi(0, hp - amount)
	_flash = 1.0
	_show_bar = 3.0
	if hp <= 0:
		_die(dir)
		return
	if not glancing:
		warn.visible = false
		(sprite.material as ShaderMaterial).set_shader_parameter("flash_color", Color.WHITE)
		_go(State.STAGGER)
		_knock = dir * (150.0 if crit else 105.0)   # shoved back about 8 px (16 px on a crit)


func _die(dir: Vector2) -> void:
	_go(State.DEAD)
	warn.visible = false
	bar.visible = false
	collision_mask = 0
	game.on_enemy_killed(self)
	_knock = dir * 120.0
	var tw := create_tween()
	tw.tween_property(visual, "rotation", PI / 2 * (1.0 if dir.x >= 0.0 else -1.0), 0.25)
	tw.tween_interval(0.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
