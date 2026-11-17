extends Node2D
## Flickering red aura shown while raging.

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	for i in 6:
		var a := _t * 3.0 + i * TAU / 6.0
		var p := Vector2(cos(a) * 7.0, -13.0 + sin(a * 1.3) * 11.0)
		var r := 1.5 + sin(_t * 9.0 + i) * 0.8
		draw_circle(p, r, Color(1.0, 0.25, 0.15, 0.55))
	draw_rect(Rect2(-9, -29, 18, 30), Color(1.0, 0.2, 0.1, 0.10 + 0.05 * sin(_t * 8.0)))
