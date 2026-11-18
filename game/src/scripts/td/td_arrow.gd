class_name TDArrow
extends Node2D
## A missile in the top-down prototype: a goblin's arrow (rolls against the hero) or the
## hero's Fire Bolt / Thorn Whip (rolls against the first goblin it touches).

var game: TDMain
var velocity := Vector2.ZERO
var weapon: Dictionary
var shooter := "Goblin Archer"
var friendly := false
var color := Color(0.85, 0.8, 0.7)
var max_dist := 200.0
var _travel := 0.0


func _physics_process(delta: float) -> void:
	var step := velocity * delta
	global_position += step
	_travel += step.length()
	rotation = velocity.angle()
	if _travel > max_dist or game.is_wall(game.to_cell(global_position + Vector2(0, 8))):
		queue_free()
		return
	if friendly:
		for f in game.living_foes():
			if global_position.distance_to(f.global_position + Vector2(0, -6)) < 9.0:
				game.player._roll_against(f, weapon)
				queue_free()
				return
	else:
		var p: TDHero = game.player
		if global_position.distance_to(p.global_position + Vector2(0, -10)) < 8.0:
			p.receive_attack(shooter, weapon)
			queue_free()
			return
	queue_redraw()


func _draw() -> void:
	if friendly:
		draw_circle(Vector2.ZERO, 3.5, color)
		draw_circle(Vector2(-5, 0), 2.0, Color(color.r, color.g, color.b, 0.5))
		draw_circle(Vector2.ZERO, 1.5, Color(1, 1, 0.9))
	else:
		draw_line(Vector2(-6, 0), Vector2(4, 0), Color(0.55, 0.4, 0.25), 1.0)
		draw_line(Vector2(4, 0), Vector2(6, 0), Color(0.85, 0.85, 0.9), 1.0)
