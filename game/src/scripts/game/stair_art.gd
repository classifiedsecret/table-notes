extends Node2D
## Wooden steps drawn along the staircase slope, with a banister.

var a := Vector2.ZERO
var b := Vector2.ZERO


func _draw() -> void:
	var n := int(absf(b.x - a.x) / 8.0)
	var wood := Color(0.71, 0.5, 0.34)
	var dark := Color(0.42, 0.24, 0.18)
	for i in n:
		var x := a.x - i * 8.0
		var y := a.y - i * 8.0
		draw_rect(Rect2(x - 8.0, y - 8.0, 8.0, 8.0 + i * 8.0 * 0.0 + 8.0), dark)
		draw_rect(Rect2(x - 8.0, y - 8.0, 8.0, 3.0), wood)
		draw_line(Vector2(x - 8.0, y - 8.0), Vector2(x, y - 8.0), Color(0.83, 0.63, 0.43), 1.0)
	draw_line(a + Vector2(0, -22), b + Vector2(0, -22), dark, 2.0)
	for i in range(0, n, 2):
		var p := a + (b - a) * (float(i) / n)
		draw_line(p + Vector2(-4, -8), p + Vector2(-4, -22), dark, 1.0)
