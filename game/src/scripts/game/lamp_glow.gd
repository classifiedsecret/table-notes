extends Node2D
## Soft warm glow behind a lantern.

var _t := randf() * 10.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var a := 0.07 + 0.015 * sin(_t * 3.1)
	draw_circle(Vector2.ZERO, 30.0, Color(1.0, 0.7, 0.3, a))
	draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.75, 0.35, a * 1.2))
