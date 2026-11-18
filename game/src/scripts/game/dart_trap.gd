class_name DartTrap
extends Node2D
## A hole in the wall that spits darts on a timer.

var game: Node
var dir := Vector2.LEFT
var _t := 0.0
var interval := 2.6


func _ready() -> void:
	_t = fmod(position.x * 0.013 + position.y * 0.007, interval)


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= interval:
		_t = 0.0
		if game.player and game.player.global_position.distance_to(global_position) < 320.0:
			Projectile.fire(game, global_position + dir * 6.0 + Vector2(0, -8), dir * 170.0, "Dart trap", Creatures.DART, Color(0.6, 0.6, 0.65))
			game.sfx.play("swing", -16.0, 0.3)


func _draw() -> void:
	var warn := _t > interval - 0.5
	var at := Vector2(0, -8)
	draw_rect(Rect2(at - Vector2(4, 3), Vector2(8, 6)), Color(0.08, 0.06, 0.08))
	draw_rect(Rect2(at - Vector2(2, 1), Vector2(4, 2)), Color(1, 0.4, 0.3) if warn else Color(0.3, 0.25, 0.25))
