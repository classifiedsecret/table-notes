class_name Enemy
extends CharacterBody2D
## Goblin in real time: chase, telegraphed wind-up, strike rolled against Boar-vhal's AC.

enum State { CHASE, WINDUP, STRIKE, RECOVER, STAGGER, RETREAT, DEAD }

var game: Node
var data: Dictionary
var max_hp := 7
var hp := 7
var ac := 12
var facing := -1
var state := State.CHASE
var speed := 80.0
var _t := 0.0
var _cd := 0.6
var _flash := 0.0
var _struck := false
var _show_bar := 0.0
var _jump_cd := 0.5

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
	max_hp = 0
	for v in hp_roll:
		max_hp += v
	hp = max_hp
	speed = 86.0 if d.name == "Goblin Minion" else 74.0
	game.log_line("%s appears (AC %d, HP %d from %dd%d %s)." % [d.name, ac, hp, d.hp_count, d.hp_sides, str(hp_roll)])


func _ready() -> void:
	collision_layer = 0
	collision_mask = Room.LAYER_SOLID | Room.LAYER_PLATFORM
	floor_snap_length = 4.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 12)
	shape.shape = rect
	shape.position = Vector2(0, -6)
	add_child(shape)
	visual = Node2D.new()
	add_child(visual)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.strip_frames(load("res://assets/sprites/%s.png" % data.sprite), 16, 16, {
		"idle": [0, 4, 6, true], "run": [4, 4, 10, true]})
	sprite.offset = Vector2(0, -8)
	sprite.material = Art.flash_material()
	sprite.play("idle")
	visual.add_child(sprite)
	weapon_pivot = Node2D.new()
	weapon_pivot.position = Vector2(4, -6)
	weapon_pivot.rotation = 0.5
	visual.add_child(weapon_pivot)
	var w := Sprite2D.new()
	w.texture = Art.region(data.weapon_sprite)
	w.offset = Vector2(0, -w.texture.get_height() / 2.0 + 2.0)
	weapon_pivot.add_child(w)
	warn = Label.new()
	warn.label_settings = Art.label_settings(16, Color(1, 0.85, 0.2), 3, true)
	warn.text = "!"
	warn.position = Vector2(-3, -34)
	warn.visible = false
	add_child(warn)
	bar = Node2D.new()
	bar.set_script(preload("res://scripts/game/enemy_bar.gd"))
	bar.position = Vector2(0, -22)
	add_child(bar)


func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-6, -14), Vector2(12, 14))


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
	_jump_cd = maxf(0.0, _jump_cd - delta)
	_flash = maxf(0.0, _flash - delta * 6.0)
	_show_bar = maxf(0.0, _show_bar - delta)
	(sprite.material as ShaderMaterial).set_shader_parameter("flash", _flash)
	var p: Player = game.player
	var dx := p.global_position.x - global_position.x
	var dy := p.global_position.y - global_position.y
	var dir := signf(dx)

	match state:
		State.DEAD:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		State.CHASE:
			if p.is_down():
				_go(State.RETREAT)
			elif not game.accepting_input():
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			else:
				if dir != 0.0:
					facing = int(dir)
				var close := absf(dx) < 20.0 and absf(dy) < 18.0
				if close and _cd <= 0.0 and is_on_floor():
					_go(State.WINDUP)
					velocity.x = 0.0
				elif absf(dx) > 14.0 and (_ground_ahead() or dy > 8.0):
					velocity.x = move_toward(velocity.x, facing * speed, 700.0 * delta)
				else:
					velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)
				# Goblins are nimble: hop up ledges, out of pits and onto platforms after the hero.
				if is_on_floor() and _jump_cd <= 0.0 and (is_on_wall() or (dy < -20.0 and absf(dx) < 56.0)):
					velocity.y = -300.0
					velocity.x = facing * speed
					_jump_cd = 1.2
		State.WINDUP:
			# Facing is locked during the wind-up: dodge behind it for advantage.
			velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
			weapon_pivot.rotation = lerpf(0.5, -2.0, minf(1.0, _t / (data.windup * 0.6)))
			warn.visible = true
			_flash = 0.35 + 0.25 * sin(_t * 40.0)
			(sprite.material as ShaderMaterial).set_shader_parameter("flash_color", Color(1, 0.85, 0.3))
			if _t >= data.windup:
				_go(State.STRIKE)
				_struck = false
				(sprite.material as ShaderMaterial).set_shader_parameter("flash_color", Color.WHITE)
				warn.visible = false
		State.STRIKE:
			weapon_pivot.rotation = lerpf(-2.0, 1.9, minf(1.0, _t / 0.08))
			velocity.x = facing * 60.0 if _t < 0.06 else 0.0
			if not _struck and _t >= 0.04:
				_struck = true
				game.sfx.play("swing", -10.0, 0.2)
				if _strike_rect().intersects(p.hurt_rect()):
					p.receive_attack(self, data.weapon)
			if _t >= 0.12:
				_go(State.RECOVER)
				_cd = data.cooldown
		State.RECOVER:
			weapon_pivot.rotation = lerpf(1.9, 0.5, minf(1.0, _t / 0.3))
			if data.name == "Goblin Minion" and _t < 0.25:
				# Nimble Escape: hop back out of reach after stabbing.
				velocity.x = -facing * 90.0
			else:
				velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			if _t >= 0.4:
				_go(State.CHASE)
		State.STAGGER:
			velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
			if _t >= 0.3:
				_go(State.CHASE)
		State.RETREAT:
			# Boar-vhal is down: goblins back off and jeer instead of finishing him.
			velocity.x = move_toward(velocity.x, -signf(dx) * 40.0 if absf(dx) < 60.0 else 0.0, 300.0 * delta)
			if not p.is_down():
				_go(State.CHASE)

	var g: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	velocity.y = minf(420.0, velocity.y + g * delta)
	move_and_slide()
	visual.scale.x = facing
	if state != State.DEAD:
		sprite.play("run" if absf(velocity.x) > 10.0 else "idle")
	bar.call("set_values", hp, max_hp, ac, _show_bar > 0.0 or hp < max_hp)


func _ground_ahead() -> bool:
	var probe := global_position + Vector2(facing * 9.0, 4.0)
	return game.room.is_ground_at(probe)


func _strike_rect() -> Rect2:
	var r := Rect2(Vector2(0, -16), Vector2(20, 18))
	if facing < 0:
		r.position.x = -r.size.x
	r.position += global_position
	return r


func take_hit(amount: int, crit: bool, from_facing: int, glancing: bool) -> void:
	if state == State.DEAD:
		return
	hp = maxi(0, hp - amount)
	_flash = 1.0
	_show_bar = 3.0
	if hp <= 0:
		_die(from_facing)
		return
	if not glancing:
		warn.visible = false
		(sprite.material as ShaderMaterial).set_shader_parameter("flash_color", Color.WHITE)
		_go(State.STAGGER)
		velocity = Vector2(from_facing * (150.0 if crit else 90.0), -70.0)


func _die(from_facing: int) -> void:
	_go(State.DEAD)
	warn.visible = false
	bar.visible = false
	game.on_enemy_killed(self)
	velocity = Vector2(from_facing * 120.0, -140.0)
	var tw := create_tween()
	tw.tween_property(visual, "rotation", PI / 2 * from_facing, 0.25)
	tw.tween_interval(0.5)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
