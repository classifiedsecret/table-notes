class_name Campfire
extends Node2D
## A short rest: spend Hit Dice (d12 + CON) to heal. One rest per campfire.

var game: Node
var used := false
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func prompt() -> String:
	return "" if used else "E: SHORT REST"


func interact(p: Player) -> void:
	if used:
		return
	used = true
	var healed := 0
	var spent := 0
	while p.hp < p.max_hp and game.hit_dice > 0:
		game.hit_dice -= 1
		spent += 1
		var r: int = game.dice.die(12) + int(p.stats.con_mod)
		healed += maxi(1, r)
		p.hp = mini(p.max_hp, p.hp + maxi(1, r))
	p.hp_changed.emit()
	if spent == 0:
		game.toast("You rest a moment, but have no Hit Dice left to spend.")
	else:
		game.toast("Short rest: spent %d Hit %s, healed %d. (%d Hit Dice left)" % [spent, "Die" if spent == 1 else "Dice", healed, game.hit_dice])
	game.log_line("Short rest at the campfire: %d Hit %s spent, %d HP regained." % [spent, "Die" if spent == 1 else "Dice", healed])
	game.sfx.play("dodge", -6.0)


func _draw() -> void:
	draw_line(Vector2(-7, -1), Vector2(7, -3), Color(0.4, 0.25, 0.15), 3.0)
	draw_line(Vector2(-7, -3), Vector2(7, -1), Color(0.35, 0.22, 0.12), 3.0)
	if used:
		draw_circle(Vector2(0, -4), 2.0, Color(0.5, 0.2, 0.1, 0.8))
		return
	for i in 5:
		var ph := _t * 7.0 + i * 1.7
		var hgt := 6.0 + sin(ph) * 2.5 + i % 2 * 2.0
		var x := -4.0 + i * 2.0
		draw_line(Vector2(x, -3), Vector2(x + sin(ph * 0.7), -3 - hgt), Color(1.0, 0.55 + 0.1 * sin(ph), 0.15), 2.0)
	draw_circle(Vector2(0, -5), 2.5, Color(1.0, 0.9, 0.5, 0.9))
	draw_circle(Vector2(0, -6), 14.0, Color(1.0, 0.6, 0.2, 0.06 + 0.02 * sin(_t * 5.0)))
