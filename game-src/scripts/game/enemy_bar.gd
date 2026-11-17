extends Node2D
## Name tag and small HP bar above a monster. Armor Class stays hidden, as at the table.

var _hp := 1
var _max := 1
var _name := ""
var _show := false


func label_width() -> float:
	return Art.FONT.get_string_size(_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x


func set_values(hp: int, max_hp: int, display_name: String, show_bar: bool) -> void:
	if hp != _hp or max_hp != _max or display_name != _name or show_bar != _show:
		_hp = hp
		_max = max_hp
		_name = display_name
		_show = show_bar
		queue_redraw()


func _draw() -> void:
	var font := Art.FONT
	var text := _name.to_upper()
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var p := Vector2(-w / 2.0, -1).round()
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 2, Color(0.05, 0.04, 0.07))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.9, 0.82, 0.7))
	if _show:
		draw_rect(Rect2(-9, 1, 18, 3), Color(0.05, 0.04, 0.07))
		draw_rect(Rect2(-8, 2, 16.0 * _hp / maxf(1.0, _max), 1), Color(0.85, 0.2, 0.2))
