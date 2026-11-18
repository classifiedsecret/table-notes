extends Node2D
## The swoosh of a melee swing in the top-down prototype (drawn along the aim direction).

var _t := 1.0


func play(_strength := 1.0) -> void:
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if _t < 1.0:
		_t += delta * 5.0
		queue_redraw()


func _draw() -> void:
	if _t >= 1.0:
		return
	var a := 1.0 - _t
	draw_arc(Vector2.ZERO, 20.0, -1.2, 1.2, 14, Color(1, 1, 0.9, 0.6 * a), 3.0)
	draw_arc(Vector2.ZERO, 16.0, -0.9, 0.9, 10, Color(1, 1, 1, 0.3 * a), 2.0)
