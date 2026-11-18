class_name SpellZone
extends Node2D
## A lasting spell in a room: Entangle (vines on the ground), Moonbeam (a column of light)
## or Spiritual Weapon (a spectral mace that fights beside the hero).
## Every TICK seconds (about one 5e round compressed) it acts on the enemies it touches.

enum Kind { ENTANGLE, MOONBEAM, SPIRIT }

const TICK := 2.0

var game: Node
var kit: Node          # HeroKit
var kind := Kind.ENTANGLE
var life := 30.0
var half_w := 32.0
var _t := 0.0
var _tick := 0.0
var _saved: Array = []   # enemies that already resisted the vines
var _spirit_target: Node2D
var _spirit_home := Vector2.ZERO
var sprite: Sprite2D


static func make(g: Node, k: Node, which: int, at: Vector2, secs: float) -> SpellZone:
	var z := SpellZone.new()
	z.game = g
	z.kit = k
	z.kind = which
	z.life = secs
	z.global_position = at
	z.z_index = 4 if which == Kind.SPIRIT else -2
	if which == Kind.SPIRIT:
		g.add_child(z)
	else:
		g.room.floor_layer.add_child(z)   # lies on the ground, under everyone
		z.z_index = 2
	if which == Kind.SPIRIT:
		z.sprite = Sprite2D.new()
		z.sprite.texture = Art.region("weapon_mace")
		z.sprite.modulate = Color(0.6, 0.85, 1.0, 0.85)
		z.add_child(z.sprite)
		z._tick = 0.6
	elif which == Kind.ENTANGLE:
		z._tick = 0.0   # creatures in the area save straight away
	else:
		z._tick = 0.4
	return z


func move_to(at: Vector2) -> void:
	global_position = at
	_tick = minf(_tick, 0.3)


func ends_in() -> float:
	return maxf(0.0, life - _t)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= life or not is_instance_valid(game.room):
		_end()
		return
	_tick -= delta
	match kind:
		Kind.SPIRIT:
			_spirit_step(delta)
		_:
			if _tick <= 0.0:
				_tick = TICK
				for e: Enemy in game.living_enemies():
					if _touches(e):
						if kind == Kind.ENTANGLE:
							if e.restrained_t <= 0.0 and not _saved.has(e):
								if not kit.entangle_save(e):
									e.restrain(life - _t)
								else:
									_saved.append(e)
						else:
							kit.moonbeam_hit(e)
	queue_redraw()


## Seen from above: the area is a patch on the floor, squashed a little for the 3/4 view.
func _touches(e: Enemy) -> bool:
	var d := e.global_position - global_position
	return Vector2(d.x, d.y / 0.75).length() <= half_w


func _spirit_step(delta: float) -> void:
	var p: Node2D = game.player
	_spirit_home = p.global_position + Vector2(-14.0 * p.facing, -26.0 + sin(_t * 3.0) * 2.0)
	if is_instance_valid(_spirit_target) and not (_spirit_target as Enemy).is_dead():
		var at := _spirit_target.global_position + Vector2(-10.0 * signf(_spirit_target.global_position.x - p.global_position.x), -16.0)
		global_position = global_position.lerp(at, minf(1.0, delta * 8.0))
		sprite.rotation = lerpf(sprite.rotation, -1.2, delta * 6.0)
		if global_position.distance_to(at) < 5.0 and _tick <= 0.0:
			_tick = TICK
			sprite.rotation = 1.6
			kit.spirit_attack(_spirit_target)
			_spirit_target = null
	else:
		_spirit_target = null
		global_position = global_position.lerp(_spirit_home, minf(1.0, delta * 6.0))
		sprite.rotation = lerpf(sprite.rotation, 0.3, delta * 6.0)
		if _tick <= 0.0:
			var best: Enemy = null
			var bd := 110.0
			for e: Enemy in game.living_enemies():
				var d := e.global_position.distance_to(p.global_position)
				if d < bd:
					bd = d
					best = e
			if best:
				_spirit_target = best
			else:
				_tick = 0.3


func _end() -> void:
	if kit and is_instance_valid(kit):
		kit.zone_ended(self)
	queue_free()


func _draw() -> void:
	var fade := clampf((life - _t) / 1.0, 0.0, 1.0)
	match kind:
		Kind.ENTANGLE:
			_ellipse(half_w, Color(0.2, 0.4, 0.15, 0.35 * fade))
			for i in 26:
				var a := i * 2.4
				var r := half_w * (0.2 + 0.78 * fmod(i * 0.37, 1.0))
				var at := Vector2(cos(a) * r, sin(a) * r * 0.75)
				var hgt := 4.0 + fmod(i * 1.7, 4.0) + sin(_t * 2.0 + i) * 1.0
				draw_line(at, at + Vector2(2.0 * sin(i + _t), -hgt), Color(0.3, 0.55, 0.22, 0.9 * fade), 2.0)
				draw_line(at + Vector2(1, -hgt * 0.6), at + Vector2(3, -hgt * 0.6 - 2.0), Color(0.55, 0.8, 0.35, 0.9 * fade), 1.0)
		Kind.MOONBEAM:
			var pulse := 0.2 + 0.06 * sin(_t * 6.0)
			_ellipse(half_w, Color(0.8, 0.9, 1.0, (pulse + 0.15) * fade))
			draw_rect(Rect2(-half_w, -120, half_w * 2.0, 120), Color(0.75, 0.85, 1.0, pulse * 0.7 * fade))
			draw_rect(Rect2(-half_w * 0.4, -120, half_w * 0.8, 120), Color(0.9, 0.95, 1.0, pulse * fade))
		Kind.SPIRIT:
			draw_circle(Vector2.ZERO, 9.0, Color(0.5, 0.75, 1.0, 0.14 * fade))


func _ellipse(r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.75))
	draw_colored_polygon(pts, col)
