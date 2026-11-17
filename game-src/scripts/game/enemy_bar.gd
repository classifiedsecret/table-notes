extends Node2D
## Tiny HP bar and AC tag above a monster.

var _hp := 1
var _max := 1
var _ac := 10
var _show := false


func set_values(hp: int, max_hp: int, ac: int, show_bar: bool) -> void:
	if hp != _hp or max_hp != _max or ac != _ac or show_bar != _show:
		_hp = hp
		_max = max_hp
		_ac = ac
		_show = show_bar
		queue_redraw()


func _draw() -> void:
	var font := Art.FONT
	draw_string_outline(font, Vector2(-8, -1), "AC%d" % _ac, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0.05, 0.04, 0.07))
	draw_string(font, Vector2(-8, -1), "AC%d" % _ac, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.75, 0.85, 1.0))
	if _show:
		draw_rect(Rect2(-9, 1, 18, 3), Color(0.05, 0.04, 0.07))
		draw_rect(Rect2(-8, 2, 16.0 * _hp / maxf(1.0, _max), 1), Color(0.85, 0.2, 0.2))
