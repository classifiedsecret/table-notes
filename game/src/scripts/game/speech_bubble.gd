extends Node2D
## A small speech bubble that wraps its text and fades after a few seconds.

var _text := ""
var _t := 0.0
var _lines: PackedStringArray = []
const MAX_W := 120.0


func show_text(text: String, secs := 3.2) -> void:
	_text = text.to_upper()
	_t = secs
	_lines = _wrap(_text)
	visible = true
	modulate.a = 1.0
	queue_redraw()


func _wrap(t: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var cur := ""
	for w in t.split(" "):
		var trial := w if cur == "" else cur + " " + w
		if Art.FONT.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x > MAX_W and cur != "":
			out.append(cur)
			cur = w
		else:
			cur = trial
	if cur != "":
		out.append(cur)
	return out


func _process(delta: float) -> void:
	if _t > 0.0:
		_t -= delta
		if _t < 0.4:
			modulate.a = maxf(0.0, _t / 0.4)
		if _t <= 0.0:
			visible = false


func _draw() -> void:
	if _lines.is_empty():
		return
	var w := 0.0
	for l in _lines:
		w = maxf(w, Art.FONT.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x)
	var h := 9.0 * _lines.size() + 4.0
	var r := Rect2(Vector2(-w / 2.0 - 4.0, -h), Vector2(w + 8.0, h))
	draw_rect(r, Color(0.96, 0.94, 0.88))
	draw_rect(r, Color(0.13, 0.12, 0.14), false, 1.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 0), Vector2(3, 0), Vector2(0, 4)]), Color(0.96, 0.94, 0.88))
	for i in _lines.size():
		var lw := Art.FONT.get_string_size(_lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		draw_string(Art.FONT, Vector2(-lw / 2.0, -h + 9.0 + 9.0 * i).round(), _lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.13, 0.12, 0.14))
