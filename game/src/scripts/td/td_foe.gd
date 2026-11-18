class_name TDFoe
extends CharacterBody2D
## A goblin in the top-down prototype: paths to the hero around walls (A* on the room grid),
## telegraphs its strike, then rolls against the hero's AC. Archers keep their distance and
## shoot when they have a clear line.

enum State { CHASE, WINDUP, RECOVER, DEAD }

var game: TDMain
var data: Dictionary
var hp := 7
var ac := 13
var dead := false
var state := State.CHASE
var facing := Vector2.LEFT
var visual: Node2D
var sprite: AnimatedSprite2D
var weapon_pivot: Node2D
var warn: Label
var _t := 0.0
var _path: PackedVector2Array
var _repath := 0.0
var _flash := 0.0
var _knock := Vector2.ZERO
var _alert := false


func _ready() -> void:
	# Hit points rolled from the SRD hit dice (e.g. 2d6 for a goblin minion).
	var faces: Array[int] = game.dice.roll(int(data.hp_count), int(data.hp_sides))
	hp = maxi(1, faces.reduce(func(a, b): return a + b, 0))
	ac = int(data.ac)
	collision_layer = 4
	collision_mask = 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 6)
	shape.shape = r
	shape.position = Vector2(0, -3)
	add_child(shape)
	var shadow := Sprite2D.new()
	shadow.texture = TDHero._shadow_tex()
	shadow.modulate = Color(0, 0, 0, 0.35)
	add_child(shadow)
	visual = Node2D.new()
	add_child(visual)
	var fr: Array = data.get("frame", [16, 16])
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.strip_frames(load("res://assets/sprites/%s.png" % data.sprite), fr[0], fr[1], {
		"idle": [0, 4, 6, true], "run": [4, 4, 11, true], "hit": [8, 1, 1, false]})
	sprite.offset = Vector2(0, -fr[1] / 2.0)
	sprite.play("idle")
	visual.add_child(sprite)
	weapon_pivot = Node2D.new()
	weapon_pivot.position = Vector2(0, -6)
	add_child(weapon_pivot)
	var w := Sprite2D.new()
	w.texture = Art.region(data.weapon_sprite)
	w.offset = Vector2(0, -7)
	w.rotation = PI / 2.0
	weapon_pivot.add_child(w)
	warn = Label.new()
	warn.label_settings = Art.label_settings(16, Color(1, 0.3, 0.25), 3, true)
	warn.text = "!"
	warn.position = Vector2(-3, -fr[1] - 18)
	warn.visible = false
	add_child(warn)
	_t = randf_range(0.0, 0.6)


func _archer() -> bool:
	return data.get("ranged", false)


func _physics_process(delta: float) -> void:
	if dead or sprite == null:
		return
	_flash = maxf(0.0, _flash - delta * 4.0)
	sprite.modulate = Color(1, 1 - _flash * 0.7, 1 - _flash * 0.7)
	var p: TDHero = game.player
	var to_p := p.global_position - global_position
	var dist := to_p.length()
	if not _alert and dist < 150.0 and game.line_clear(global_position + Vector2(0, -6), p.global_position + Vector2(0, -6)):
		_alert = true
	_t -= delta
	var want := Vector2.ZERO
	var speed := float(data.get("speed_ft", 30)) * 2.0
	match state:
		State.CHASE:
			if not _alert or p.down:
				want = Vector2.ZERO
			elif _archer():
				var sees := game.line_clear(global_position + Vector2(0, -8), p.global_position + Vector2(0, -10))
				if dist < 56.0:
					want = -to_p.normalized()      # back off
				elif dist > 130.0 or not sees:
					want = _follow_path(p.global_position)
				if sees and dist < 170.0 and _t <= 0.0:
					_begin_windup(0.6)
			else:
				if dist > 16.0:
					want = _follow_path(p.global_position)
				elif _t <= 0.0:
					_begin_windup(0.45)
			if to_p.length() > 1.0:
				facing = to_p.normalized()
		State.WINDUP:
			want = Vector2.ZERO
			if _t <= 0.0:
				_strike()
		State.RECOVER:
			if _t <= 0.0:
				state = State.CHASE
				_t = randf_range(0.5, 1.0)
	velocity = velocity.move_toward(want * speed, 600.0 * delta) + _knock
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	visual.scale.x = -1.0 if facing.x < 0.0 else 1.0
	weapon_pivot.rotation = lerp_angle(weapon_pivot.rotation, facing.angle(), 0.3)
	sprite.play("run" if velocity.length() > 8.0 else "idle")


func _follow_path(target: Vector2) -> Vector2:
	_repath -= get_physics_process_delta_time()
	if _repath <= 0.0 or _path.is_empty():
		_repath = 0.35
		_path = game.path_to(global_position + Vector2(0, -3), target + Vector2(0, -3))
		if _path.size() > 0:
			_path.remove_at(0)
	while _path.size() > 0 and global_position.distance_to(_path[0] + Vector2(0, 3)) < 5.0:
		_path.remove_at(0)
	if _path.is_empty():
		return (target - global_position).normalized()
	return (_path[0] + Vector2(0, 3) - global_position).normalized()


func _begin_windup(secs: float) -> void:
	state = State.WINDUP
	_t = secs
	warn.visible = true
	var tw := create_tween()
	tw.tween_property(weapon_pivot, "rotation", facing.angle() - 1.6, secs * 0.8)


func _strike() -> void:
	warn.visible = false
	state = State.RECOVER
	_t = 0.6
	var p: TDHero = game.player
	if _archer():
		var a := TDArrow.new()
		a.game = game
		a.weapon = data.weapon
		a.shooter = data.name
		a.velocity = (p.global_position + Vector2(0, -10) - (global_position + Vector2(0, -8))).normalized() * 170.0
		a.max_dist = 220.0
		game.world.add_child(a)
		a.global_position = global_position + Vector2(0, -8)
		game.sfx.play("swing", -8.0, 0.4)
		return
	var tw := create_tween()
	tw.tween_property(weapon_pivot, "rotation", facing.angle() + 1.2, 0.1)
	game.sfx.play("swing", -6.0)
	# The strike lands if the hero is still in reach and in front (a dodge or a step away beats it).
	var to := p.global_position - global_position
	if to.length() <= 22.0 and facing.dot(to.normalized()) > 0.2:
		p.receive_attack(data.name, data.weapon)


func hurt(amount: int, from_dir: Vector2, crit: bool) -> void:
	if dead:
		return
	_alert = true
	hp -= amount
	_flash = 1.0
	_knock = from_dir * (140.0 if crit else 90.0)
	if state == State.WINDUP and amount >= 4:
		warn.visible = false
		state = State.RECOVER
		_t = 0.4
	if hp <= 0:
		dead = true
		state = State.DEAD
		warn.visible = false
		collision_layer = 0
		game.log_line("%s is slain." % data.name)
		var tw := create_tween()
		tw.tween_property(visual, "rotation", PI / 2.0 * signf(from_dir.x if from_dir.x != 0.0 else 1.0), 0.2)
		tw.tween_property(self, "modulate:a", 0.0, 0.8)
		tw.tween_callback(queue_free)
