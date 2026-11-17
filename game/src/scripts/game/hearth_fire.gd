extends Node2D
## Animated fire for the inn's fireplace: logs, layered flickering flames, embers and glow.
## Drawn with its origin at the bottom-centre of the firebox (about 26 px wide).

var _t := randf() * 10.0
var _embers: Array = []


func _process(delta: float) -> void:
	_t += delta
	if randf() < delta * 6.0:
		_embers.append({"p": Vector2(randf_range(-8, 8), -6), "v": Vector2(randf_range(-6, 6), randf_range(-26, -16)), "life": randf_range(0.6, 1.2)})
	for e in _embers:
		e.p += e.v * delta
		e.life -= delta
	_embers = _embers.filter(func(e): return e.life > 0.0 and e.p.y > -30.0)
	queue_redraw()


func _flame(x: float, base_h: float, w: float, phase: float, col: Color) -> void:
	var h := base_h + sin(_t * 9.0 + phase) * 2.5 + sin(_t * 13.0 + phase * 2.0) * 1.5
	var sway := sin(_t * 6.0 + phase) * 1.5
	var pts := PackedVector2Array([Vector2(x - w, -3), Vector2(x - w * 0.6, -3 - h * 0.45),
		Vector2(x + sway, -3 - h), Vector2(x + w * 0.6, -3 - h * 0.45), Vector2(x + w, -3)])
	draw_colored_polygon(pts, col)


func _draw() -> void:
	# soft light spilling out of the hearth
	draw_circle(Vector2(0, -10), 26.0, Color(1.0, 0.55, 0.2, 0.07 + 0.025 * sin(_t * 5.0)))
	draw_circle(Vector2(0, -8), 15.0, Color(1.0, 0.6, 0.25, 0.10 + 0.03 * sin(_t * 7.0)))
	# outer, middle and inner flames
	for i in 4:
		_flame(-7.0 + i * 4.7, 13.0 + (i % 2) * 3.0, 4.5, i * 1.9, Color(0.86, 0.27, 0.10))
	for i in 3:
		_flame(-4.5 + i * 4.5, 9.0 + (i % 2) * 2.0, 3.2, i * 2.7 + 1.0, Color(1.0, 0.55, 0.12))
	for i in 2:
		_flame(-2.0 + i * 4.0, 5.5, 2.0, i * 3.3 + 2.0, Color(1.0, 0.88, 0.45))
	# logs over the flame bases, with glowing coals
	draw_line(Vector2(-11, -1), Vector2(10, -4), Color(0.33, 0.2, 0.11), 3.0)
	draw_line(Vector2(-10, -4), Vector2(11, -1), Color(0.42, 0.26, 0.14), 3.0)
	for i in 5:
		var c := 0.6 + 0.4 * sin(_t * 4.0 + i * 1.3)
		draw_rect(Rect2(-8 + i * 4, -2, 2, 1), Color(1.0, 0.45 * c + 0.2, 0.1, 0.9))
	for e in _embers:
		draw_rect(Rect2(e.p.round(), Vector2(1, 1)), Color(1.0, 0.7, 0.3, clampf(e.life, 0.0, 1.0)))
