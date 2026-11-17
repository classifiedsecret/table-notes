class_name SpellFx
extends Node2D
## Short-lived spell visuals and the hero's spell missiles (Fire Bolt, Magic Missile darts),
## plus lines (Scorching Ray, Thorn Whip) and bursts (healing, Dread Aura, smites).

enum Kind { BOLT, DART, LINE, WHIP, BURST, RISE }

var game: Node
var kind := Kind.BURST
var vel := Vector2.ZERO
var target: Node2D
var color := Color.WHITE
var life := 0.5
var _t := 0.0
var a := Vector2.ZERO
var b := Vector2.ZERO
var radius := 20.0
var on_hit: Callable
var _trail: Array[Vector2] = []


static func _make(g: Node, k: int, col: Color, secs: float) -> SpellFx:
	var f := SpellFx.new()
	f.game = g
	f.kind = k
	f.color = col
	f.life = secs
	f.z_index = 6
	g.add_child(f)
	return f


## A missile that flies straight and calls on_hit(enemy) on the first enemy it touches.
static func bolt(g: Node, from: Vector2, velocity: Vector2, col: Color, hit: Callable) -> SpellFx:
	var f := _make(g, Kind.BOLT, col, 1.6)
	f.global_position = from
	f.vel = velocity
	f.on_hit = hit
	return f


## A homing dart (Magic Missile): always reaches its target.
static func dart(g: Node, from: Vector2, enemy: Node2D, col: Color, hit: Callable, delay := 0.0) -> SpellFx:
	var f := _make(g, Kind.DART, col, 2.0 + delay)
	f.global_position = from
	f.target = enemy
	f.on_hit = hit
	f._t = -delay
	f.vel = Vector2(randf_range(-60, 60), -110)
	return f


## A beam or whip drawn from a to b that fades out.
static func line(g: Node, from: Vector2, to: Vector2, col: Color, secs := 0.25, thorny := false) -> SpellFx:
	var f := _make(g, Kind.WHIP if thorny else Kind.LINE, col, secs)
	f.a = from
	f.b = to
	return f


static func burst(g: Node, at: Vector2, col: Color, r := 20.0, secs := 0.45) -> SpellFx:
	var f := _make(g, Kind.BURST, col, secs)
	f.global_position = at
	f.radius = r
	return f


## Little motes rising (healing).
static func rise(g: Node, at: Vector2, col: Color) -> SpellFx:
	var f := _make(g, Kind.RISE, col, 0.9)
	f.global_position = at
	return f


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > life:
		queue_free()
		return
	match kind:
		Kind.BOLT:
			_trail.push_front(global_position)
			if _trail.size() > 6:
				_trail.pop_back()
			global_position += vel * delta
			var room: Room = game.room
			if room.is_solid_cell(floori(global_position.x / Room.T), floori(global_position.y / Room.T)):
				SpellFx.burst(game, global_position, color, 8.0, 0.25)
				queue_free()
				return
			for e: Enemy in game.living_enemies():
				if e.hurt_rect().grow(2.0).has_point(global_position):
					SpellFx.burst(game, global_position, color, 10.0, 0.3)
					if on_hit.is_valid():
						on_hit.call(e)
					queue_free()
					return
		Kind.DART:
			if _t < 0.0:
				visible = false
				return
			visible = true
			_trail.push_front(global_position)
			if _trail.size() > 5:
				_trail.pop_back()
			if not is_instance_valid(target) or (target is Enemy and (target as Enemy).is_dead()):
				queue_free()
				return
			var aim: Vector2 = target.global_position + Vector2(0, -8) - global_position
			if aim.length() < 7.0:
				SpellFx.burst(game, global_position, color, 7.0, 0.25)
				if on_hit.is_valid():
					on_hit.call(target)
				queue_free()
				return
			vel = vel.lerp(aim.normalized() * 300.0, minf(1.0, delta * 9.0))
			global_position += vel * delta
	queue_redraw()


func _process(_delta: float) -> void:
	if kind in [Kind.LINE, Kind.WHIP, Kind.BURST, Kind.RISE]:
		_t += _delta
		if _t > life:
			queue_free()
			return
		queue_redraw()


func _draw() -> void:
	var fade := clampf(1.0 - _t / life, 0.0, 1.0)
	match kind:
		Kind.BOLT, Kind.DART:
			for i in _trail.size():
				var q := to_local(_trail[i])
				draw_circle(q, 2.5 - i * 0.35, Color(color.r, color.g, color.b, 0.5 - i * 0.08))
			draw_circle(Vector2.ZERO, 3.5 if kind == Kind.BOLT else 2.5, color)
			draw_circle(Vector2.ZERO, 1.5, Color(1, 1, 0.9))
		Kind.LINE:
			var la := to_local(a)
			var lb := to_local(b)
			draw_line(la, lb, Color(color.r, color.g, color.b, 0.35 * fade), 5.0)
			draw_line(la, lb, Color(1, 0.95, 0.8, fade), 1.5)
		Kind.WHIP:
			var la := to_local(a)
			var lb := to_local(b)
			var n := 10
			var prev := la
			for i in range(1, n + 1):
				var q := la.lerp(lb, i / float(n)) + Vector2(0, sin(i * 1.3 + _t * 20.0) * 1.5)
				draw_line(prev, q, Color(0.32, 0.6, 0.25, fade), 2.0)
				if i % 2 == 0:
					draw_line(q, q + Vector2(1, -2), Color(0.6, 0.85, 0.4, fade), 1.0)
				prev = q
		Kind.BURST:
			var r := radius * (0.4 + 0.6 * _t / life)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(color.r, color.g, color.b, fade), 2.0)
			draw_circle(Vector2.ZERO, r * 0.6, Color(color.r, color.g, color.b, 0.18 * fade))
		Kind.RISE:
			for i in 6:
				var x := -8.0 + i * 3.2
				var y := -4.0 - _t * (22.0 + i * 5.0) - (i % 3) * 4.0
				draw_rect(Rect2(x, y, 1.5, 1.5), Color(color.r, color.g, color.b, fade))
