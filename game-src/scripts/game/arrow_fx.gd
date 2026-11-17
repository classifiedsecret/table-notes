extends Node2D
## Visual-only arrow used in turn-based combat (the roll is resolved separately).


func _draw() -> void:
	draw_line(Vector2(-6, 0), Vector2(4, 0), Color(0.85, 0.75, 0.55), 1.0)
	draw_line(Vector2(4, 0), Vector2(1, -2), Color(0.9, 0.9, 0.95), 1.0)
	draw_line(Vector2(4, 0), Vector2(1, 2), Color(0.9, 0.9, 0.95), 1.0)
