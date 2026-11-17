class_name Hud
extends CanvasLayer
## On-screen readouts: hero panel, roll stats, roll log, banners and the death save tracker.

var game: Node
var root: Control
var hp_label: Label
var hp_fill: ColorRect
var hp_back: ColorRect
var rage_label: Label
var bonus_label: Label
var wave_label: Label
var stats_label: Label
var rule_label: Label
var log_panel: PanelContainer
var log_label: Label
var banner_label: Label
var toast_label: Label
var ds_panel: PanelContainer
var ds_marks: Label
var ds_roll: Label
var ds_text: Label
var center_panel: PanelContainer
var center_title: Label
var center_body: Label
var center_foot: Label
var hints: Label

var _log: Array[String] = []
var _banner_t := 0.0
var _toast_t := 0.0
var _ds_tumble := 0.0
var _ds_final := ""


func build(g: Node) -> void:
	game = g
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Hero panel
	var hero := _panel(Vector2(4, 4), Vector2(150, 48))
	_label(hero, Vector2(6, 3), "BOAR-VHAL ROCKHAULER", 8, Color(1, 0.9, 0.65))
	_label(hero, Vector2(6, 12), "Goliath Barbarian 1   AC 14", 8, Color(0.75, 0.8, 0.9))
	hp_back = ColorRect.new()
	hp_back.color = Color(0.15, 0.05, 0.06)
	hp_back.position = Vector2(6, 23)
	hp_back.size = Vector2(90, 7)
	hero.get_meta("holder").add_child(hp_back)
	hp_fill = ColorRect.new()
	hp_fill.color = Color(0.8, 0.18, 0.2)
	hp_fill.position = Vector2(7, 24)
	hp_fill.size = Vector2(88, 5)
	hero.get_meta("holder").add_child(hp_fill)
	hp_label = _label(hero, Vector2(100, 22), "15/15", 8, Color.WHITE)
	rage_label = _label(hero, Vector2(6, 32), "", 8, Color(1, 0.55, 0.45))
	bonus_label = _label(hero, Vector2(6, 40), "", 8, Color(0.7, 0.9, 0.7))

	wave_label = _label(root, Vector2(190, 4), "", 8, Color(1, 0.9, 0.65))
	wave_label.size = Vector2(100, 10)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sp := _panel(Vector2(286, 4), Vector2(190, 22))
	stats_label = _label(sp, Vector2(5, 2), "", 8, Color(0.9, 0.9, 0.85))
	rule_label = _label(sp, Vector2(5, 11), "", 8, Color(0.7, 0.75, 0.85))

	log_panel = _panel(Vector2(286, 29), Vector2(190, 74))
	_label(log_panel, Vector2(5, 2), "ROLL LOG  (Tab to hide)", 8, Color(1, 0.9, 0.65))
	log_label = _label(log_panel, Vector2(5, 12), "", 8, Color(0.88, 0.88, 0.84))
	log_label.size = Vector2(181, 60)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.clip_text = true
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM

	banner_label = _label(root, Vector2(0, 70), "", 24, Color.WHITE, true)
	banner_label.size = Vector2(480, 24)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label = _label(root, Vector2(0, 236), "", 8, Color(1, 0.95, 0.8))
	toast_label.size = Vector2(480, 10)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	ds_panel = _panel(Vector2(165, 92), Vector2(150, 62))
	var t := _label(ds_panel, Vector2(0, 3), "DEATH SAVES", 8, Color(1, 0.6, 0.55))
	t.size = Vector2(150, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds_roll = _label(ds_panel, Vector2(0, 11), "", 24, Color.WHITE, true)
	ds_roll.size = Vector2(150, 24)
	ds_roll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds_marks = _label(ds_panel, Vector2(0, 37), "", 8, Color.WHITE)
	ds_marks.size = Vector2(150, 10)
	ds_marks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds_text = _label(ds_panel, Vector2(0, 48), "d20: 10+ succeeds, 1 counts twice, 20 revives", 8, Color(0.7, 0.7, 0.75))
	ds_text.size = Vector2(150, 10)
	ds_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds_panel.visible = false

	center_panel = _panel(Vector2(50, 30), Vector2(380, 206))
	center_title = _label(center_panel, Vector2(0, 8), "", 24, Color(1, 0.88, 0.55), true)
	center_title.size = Vector2(380, 24)
	center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_body = _label(center_panel, Vector2(16, 40), "", 8, Color(0.92, 0.92, 0.88))
	center_body.size = Vector2(348, 166)
	center_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_foot = _label(center_panel, Vector2(16, 176), "", 8, Color(0.6, 0.58, 0.66))
	center_foot.size = Vector2(348, 26)
	center_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	(center_panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(0.07, 0.06, 0.09, 0.96)

	hints = _label(root, Vector2(0, 259), "Move A/D or arrows   Jump Space   Attack J   Dodge K   Rage L   Drop S+Space   F1 miss rule   F2 test death saves", 8, Color(0.7, 0.68, 0.75))
	hints.size = Vector2(480, 10)
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _panel(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.09, 0.78)
	sb.border_color = Color(0.45, 0.36, 0.28, 0.9)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = size
	p.custom_minimum_size = size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(holder)
	root.add_child(p)
	p.set_meta("holder", holder)
	return p


func _label(parent: Node, pos: Vector2, text: String, size: int, color: Color, big := false) -> Label:
	var l := Label.new()
	l.label_settings = Art.label_settings(size, color, 2 if size <= 8 else 3, big)
	l.text = text
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target: Node = parent.get_meta("holder") if parent.has_meta("holder") else parent
	target.add_child(l)
	return l


func refresh(p: Player, stats: Dictionary, wave: int, enemies_left: int) -> void:
	hp_fill.size.x = 88.0 * p.hp / float(p.max_hp)
	hp_label.text = "HP %d/%d" % [p.hp, p.max_hp]
	var pips := ""
	for i in p.stats.rage_uses:
		pips += "o" if i < p.rage_uses else "-"
	rage_label.text = ("RAGE %ds  +2 dmg, resist" % ceili(p.rage_time)) if p.raging() else "Rage [%s]  L / Y" % pips
	bonus_label.text = "Bonus action ready" if p.bonus_cd <= 0.0 else "Bonus action in %ds" % ceili(p.bonus_cd)
	bonus_label.label_settings.font_color = Color(0.7, 0.95, 0.7) if p.bonus_cd <= 0.0 else Color(0.6, 0.6, 0.65)
	wave_label.text = "WAVE %d   %d left" % [wave, enemies_left] if wave > 0 else ""
	var rolls: int = stats.rolls
	var pct := 0 if rolls == 0 else roundi(100.0 * stats.hits / rolls)
	stats_label.text = "Your attacks %d  hits %d (%d%%)  crits %d" % [rolls, stats.hits, pct, stats.crits]
	rule_label.text = "Miss rule (F1): %s" % ("minimum damage" if game.miss_min_damage else "no damage (5e)")


func add_log(line: String) -> void:
	_log.append(line)
	while _log.size() > 8:
		_log.pop_front()
	log_label.text = "\n".join(_log)


func toggle_log() -> void:
	log_panel.visible = not log_panel.visible


func banner(text: String, color: Color) -> void:
	banner_label.text = text
	banner_label.label_settings.font_color = color
	_banner_t = 1.6


func toast(text: String) -> void:
	toast_label.text = text
	_toast_t = 1.8


func show_center(title: String, body: String, foot := "") -> void:
	center_title.text = title
	center_body.text = body
	center_foot.text = foot
	center_panel.visible = true


func hide_center() -> void:
	center_panel.visible = false


func death_saves(visible_now: bool, ds: Rules.DeathSaves, last: Dictionary = {}) -> void:
	ds_panel.visible = visible_now
	if not visible_now:
		return
	var s := ""
	for i in 3:
		s += "O " if i < ds.successes else ". "
	s += "   "
	for i in 3:
		s += "X " if i < ds.failures else ". "
	ds_marks.text = "Successes %s Failures" % s
	if last.has("roll"):
		_ds_final = str(last.roll)
		_ds_tumble = 0.35
		var col := Color(0.6, 1, 0.6) if last.roll >= 10 else Color(1, 0.45, 0.4)
		if last.roll == 20:
			col = Color(1, 0.85, 0.3)
		ds_roll.label_settings.font_color = col
	elif ds.successes == 0 and ds.failures == 0:
		ds_roll.text = "..."


func _process(delta: float) -> void:
	if _banner_t > 0.0:
		_banner_t -= delta
		banner_label.modulate.a = clampf(_banner_t / 0.4, 0.0, 1.0)
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_label.modulate.a = clampf(_toast_t / 0.4, 0.0, 1.0)
	if _ds_tumble > 0.0:
		_ds_tumble -= delta
		ds_roll.text = str(randi_range(1, 20)) if _ds_tumble > 0.0 else _ds_final
