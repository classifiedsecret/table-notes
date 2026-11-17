extends Node2D
## Brief white arc drawn in front of the attacker during the active frames of a swing.

var _t := 1.0
var radius := 20.0
var color := Color(1, 0.97, 0.88)


func play() -> void:
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _t < 1.0:
		_t = minf(1.0, _t + delta / 0.16)
		queue_redraw()


func _draw() -> void:
	if _t >= 1.0:
		return
	var c := color
	c.a = 1.0 - _t
	var center := Vector2(2, -12)
	draw_arc(center, radius, -1.9, -1.9 + 3.3 * minf(1.0, _t * 3.0), 14, c, 3.0 * (1.0 - _t) + 1.0)
	draw_arc(center, radius - 4.0, -1.6, -1.6 + 2.9 * minf(1.0, _t * 3.0), 12, Color(c, c.a * 0.5), 1.0)
