class_name Hud
extends CanvasLayer
## On-screen readouts: hero panel, roll stats, roll log, banners, prompts, doors, tavern and death saves.

var game: Node
var root: Control
var name_label: Label
var title_label: Label
var hp_label: Label
var hp_fill: ColorRect
var xp_fill: ColorRect
var xp_label: Label
var rage_label: Label
var bonus_label: Label
var purse_label: Label
var room_label: Label
var stats_label: Label
var rule_label: Label
var log_panel: PanelContainer
var log_label: Label
var banner_label: Label
var toast_label: Label
var prompt_label: Label
var note_panel: PanelContainer
var note_label: Label
var ds_panel: PanelContainer
var ds_marks: Label
var ds_roll: Label
var center_panel: PanelContainer
var center_title: Label
var center_body: Label
var center_foot: Label
var doors_panel: PanelContainer
var door_labels: Array[Label] = []
var door_hints: Array[Label] = []
var door_boxes: Array[ColorRect] = []
var tavern_panel: PanelContainer
var tavern_sheet: Label
var tavern_opts: Label
var tavern_lines: Array[Label] = []
var tavern_help: Label
var tavern_foot: Label
var hints: Label
var tavern_title: Label
var tavern_sub: Label
var stats_panel: Control
var dlg_panel: PanelContainer
var dlg_name: Label
var dlg_text: Label
const HINTS_RUN := "MOVE A/D  JUMP SPACE  ATTACK J  DODGE K  RAGE L  RECKLESS R  ECHO U  USE E  POTION H  LOG TAB"
const HINTS_INN := "MOVE A/D  JUMP SPACE  TALK E  CLIMB STAIRS W  DROP S+SPACE  CELLAR: FAR RIGHT  MUSIC M"

var _log: Array[String] = []
var _banner_t := 0.0
var _toast_t := 0.0
var _note_t := 0.0
var _ds_tumble := 0.0
var _ds_final := ""


func build(g: Node) -> void:
	game = g
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var hero := _panel(Vector2(4, 4), Vector2(158, 64))
	name_label = _label(hero, Vector2(6, 3), "", 8, Color(1, 0.9, 0.65))
	title_label = _label(hero, Vector2(6, 12), "", 8, Color(0.75, 0.8, 0.9))
	_rect(hero, Vector2(6, 23), Vector2(92, 7), Color(0.15, 0.05, 0.06))
	hp_fill = _rect(hero, Vector2(7, 24), Vector2(90, 5), Color(0.8, 0.18, 0.2))
	hp_label = _label(hero, Vector2(102, 22), "", 8, Color.WHITE)
	_rect(hero, Vector2(6, 31), Vector2(92, 3), Color(0.12, 0.1, 0.05))
	xp_fill = _rect(hero, Vector2(7, 32), Vector2(90, 1), Color(0.95, 0.75, 0.25))
	xp_label = _label(hero, Vector2(102, 29), "", 8, Color(0.95, 0.8, 0.4))
	rage_label = _label(hero, Vector2(6, 36), "", 8, Color(1, 0.55, 0.45))
	bonus_label = _label(hero, Vector2(6, 45), "", 8, Color(0.7, 0.9, 0.7))
	purse_label = _label(hero, Vector2(6, 54), "", 8, Color(0.95, 0.85, 0.55))

	room_label = _label(root, Vector2(0, 248), "", 8, Color(1, 0.9, 0.65))
	room_label.size = Vector2(480, 10)
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sp := _panel(Vector2(286, 4), Vector2(190, 22))
	stats_panel = sp
	stats_label = _label(sp, Vector2(5, 2), "", 8, Color(0.9, 0.9, 0.85))
	rule_label = _label(sp, Vector2(5, 11), "", 8, Color(0.7, 0.75, 0.85))

	log_panel = _panel(Vector2(286, 29), Vector2(190, 74))
	_label(log_panel, Vector2(5, 2), "ROLL LOG  (TAB TO HIDE)", 8, Color(1, 0.9, 0.65))
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
	prompt_label = _label(root, Vector2(0, 224), "", 8, Color(0.6, 1.0, 0.7))
	prompt_label.size = Vector2(480, 10)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	note_panel = _panel(Vector2(90, 186), Vector2(300, 34), 0.92)
	note_label = _label(note_panel, Vector2(6, 3), "", 8, Color(1, 0.9, 0.6))
	note_label.size = Vector2(288, 30)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_panel.visible = false

	ds_panel = _panel(Vector2(165, 92), Vector2(150, 62), 0.96)
	var t := _label(ds_panel, Vector2(0, 3), "DEATH SAVES", 8, Color(1, 0.6, 0.55))
	t.size = Vector2(150, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds_roll = _label(ds_panel, Vector2(0, 11), "", 24, Color.WHITE, true)
	ds_roll.size = Vector2(150, 24)
	ds_roll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds_marks = _label(ds_panel, Vector2(0, 37), "", 8, Color.WHITE)
	ds_marks.size = Vector2(150, 10)
	ds_marks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dt := _label(ds_panel, Vector2(0, 48), "D20: 10+ SUCCEEDS, 1 COUNTS TWICE, 20 REVIVES", 8, Color(0.7, 0.7, 0.75))
	dt.size = Vector2(150, 10)
	dt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds_panel.visible = false

	center_panel = _panel(Vector2(50, 30), Vector2(380, 206), 0.96)
	center_title = _label(center_panel, Vector2(0, 8), "", 24, Color(1, 0.88, 0.55), true)
	center_title.size = Vector2(380, 24)
	center_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center_body = _label(center_panel, Vector2(16, 40), "", 8, Color(0.92, 0.92, 0.88))
	center_body.size = Vector2(348, 136)
	center_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_foot = _label(center_panel, Vector2(16, 180), "", 8, Color(0.6, 0.58, 0.66))
	center_foot.size = Vector2(348, 26)
	center_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center_panel.visible = false

	doors_panel = _panel(Vector2(60, 70), Vector2(360, 110), 0.96)
	var dtitle := _label(doors_panel, Vector2(0, 6), "CHOOSE A DOOR", 16, Color(1, 0.88, 0.55), true)
	dtitle.size = Vector2(360, 16)
	dtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in 2:
		door_boxes.append(_rect(doors_panel, Vector2(14 + i * 172, 30), Vector2(160, 62), Color(0.2, 0.16, 0.12, 0.9)))
		var l := _label(doors_panel, Vector2(14 + i * 172, 36), "", 16, Color.WHITE, true)
		l.size = Vector2(160, 16)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		door_labels.append(l)
		var h := _label(doors_panel, Vector2(20 + i * 172, 58), "", 8, Color(0.85, 0.85, 0.8))
		h.size = Vector2(148, 30)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		door_hints.append(h)
	var dfoot := _label(doors_panel, Vector2(0, 96), "LEFT / RIGHT TO PICK, ATTACK OR ENTER TO GO", 8, Color(0.6, 0.6, 0.66))
	dfoot.size = Vector2(360, 10)
	dfoot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	doors_panel.visible = false

	tavern_panel = _panel(Vector2(40, 12), Vector2(400, 240), 0.97)
	tavern_title = _label(tavern_panel, Vector2(0, 6), "THE CELLAR STAIR", 24, Color(1, 0.88, 0.55), true)
	tavern_title.size = Vector2(400, 24)
	tavern_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tavern_sub = _label(tavern_panel, Vector2(10, 30), "", 8, Color(0.7, 0.68, 0.75))
	tavern_sub.size = Vector2(380, 10)
	tavern_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tavern_sheet = _label(tavern_panel, Vector2(18, 46), "", 8, Color(0.92, 0.92, 0.88))
	tavern_sheet.size = Vector2(364, 50)
	tavern_opts = _label(tavern_panel, Vector2(18, 102), "", 8, Color(1, 1, 1))
	for i in 8:
		var tl := _label(tavern_panel, Vector2(18, 100 + i * 12), "", 8, Color.WHITE)
		tl.visible = false
		tavern_lines.append(tl)
	tavern_help = _label(tavern_panel, Vector2(18, 150), "UP / DOWN TO CHOOSE, ATTACK OR ENTER TO SELECT", 8, Color(0.7, 0.7, 0.76))
	tavern_foot = _label(tavern_panel, Vector2(18, 166), "", 8, Color(0.6, 0.6, 0.68))
	tavern_foot.size = Vector2(364, 50)
	tavern_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tavern_panel.visible = false

	dlg_panel = _panel(Vector2(70, 196), Vector2(340, 40), 0.95)
	dlg_name = _label(dlg_panel, Vector2(8, 3), "", 8, Color(1, 0.85, 0.45))
	dlg_text = _label(dlg_panel, Vector2(8, 13), "", 8, Color(0.94, 0.94, 0.9))
	dlg_text.size = Vector2(324, 24)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_panel.visible = false

	hints = _label(root, Vector2(0, 259), HINTS_RUN, 8, Color(0.7, 0.68, 0.75))
	hints.size = Vector2(480, 10)
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _panel(pos: Vector2, size: Vector2, alpha := 0.78) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.09, alpha)
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


func _rect(parent: Node, pos: Vector2, size: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.position = pos
	r.size = size
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent.get_meta("holder") if parent.has_meta("holder") else parent).add_child(r)
	return r


func _label(parent: Node, pos: Vector2, text: String, size: int, color: Color, big := false) -> Label:
	var l := Label.new()
	l.label_settings = Art.label_settings(size, color, 2 if size <= 8 else 3, big)
	l.text = text
	l.position = pos
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target: Node = parent.get_meta("holder") if parent.has_meta("holder") else parent
	target.add_child(l)
	return l


func refresh(p: Player, stats: Dictionary, g: Node) -> void:
	var h: Hero = g.hero
	name_label.text = h.name.to_upper()
	title_label.text = "%s %d   AC %d" % [h.title.to_upper(), h.level, p.ac]
	hp_fill.size.x = 90.0 * p.hp / float(maxi(1, p.max_hp))
	hp_label.text = "HP %d/%d" % [p.hp, p.max_hp]
	var next := h.next_level_xp()
	var prev: int = Hero.XP_THRESHOLDS[h.level - 1]
	xp_fill.size.x = 90.0 if next < 0 else 90.0 * clampf(float(h.xp - prev) / float(next - prev), 0.0, 1.0)
	xp_label.text = "XP MAX" if next < 0 else "XP %d" % h.xp
	var pips := ""
	for i in int(p.stats.rage_uses):
		pips += "O" if i < p.rage_uses else "-"
	var r := ("RAGE %dS" % ceili(p.rage_time)) if p.raging() else "RAGE [%s]" % pips
	if p.reckless:
		r += "  RECKLESS"
	if is_instance_valid(p.echo):
		r += "  ECHO"
	rage_label.text = r
	bonus_label.text = "BONUS ACTION READY" if p.bonus_cd <= 0.0 else "BONUS ACTION IN %dS" % ceili(p.bonus_cd)
	bonus_label.label_settings.font_color = Color(0.7, 0.95, 0.7) if p.bonus_cd <= 0.0 else Color(0.6, 0.6, 0.65)
	var in_run: bool = g.phase in [1, 2, 3, 4]
	purse_label.text = "GOLD %d  POTIONS %d  HIT DICE %d" % [h.gold + (g.run_gold if in_run else 0), g.run_potions if in_run else h.potions, g.hit_dice]
	var rolls: int = stats.get("rolls", 0)
	var pct := 0 if rolls == 0 else roundi(100.0 * stats.get("hits", 0) / rolls)
	stats_label.text = "YOUR ATTACKS %d  HITS %d (%d%%)  CRITS %d" % [rolls, stats.get("hits", 0), pct, stats.get("crits", 0)]
	rule_label.text = "GLANCING %d   FUMBLES %d (TOOK %d)" % [stats.get("glances", 0), stats.get("fumbles", 0), stats.get("self", 0)]


## In the inn the combat readouts are hidden and the key hints change.
func set_inn_mode(on: bool) -> void:
	stats_panel.visible = not on
	log_panel.visible = not on
	hints.text = HINTS_INN if on else HINTS_RUN
	if not on:
		hide_dialogue()


func set_tavern_title(title: String, sub: String) -> void:
	tavern_title.text = title
	tavern_sub.text = sub


func show_dialogue(who: String, text: String) -> void:
	dlg_panel.visible = true
	dlg_name.text = who.to_upper() + "   (E: MORE)"
	dlg_text.text = text.to_upper()


func hide_dialogue() -> void:
	dlg_panel.visible = false


func set_room(text: String) -> void:
	room_label.text = text


func prompt(text: String) -> void:
	prompt_label.text = text


func level_note(text: String) -> void:
	note_label.text = text.to_upper()
	note_panel.visible = text != ""
	_note_t = 9.0


func add_log(line: String) -> void:
	_log.append(line)
	while _log.size() > 8:
		_log.pop_front()
	log_label.text = "\n".join(_log)


func toggle_log() -> void:
	if hints.text == HINTS_INN:
		return
	log_panel.visible = not log_panel.visible


func banner(text: String, color: Color) -> void:
	banner_label.text = text
	banner_label.label_settings.font_color = color
	_banner_t = 1.6


func toast(text: String) -> void:
	toast_label.text = text.to_upper()
	_toast_t = 2.6


func show_center(title: String, body: String, foot := "") -> void:
	center_title.text = title
	center_body.text = body.to_upper()
	center_foot.text = foot.to_upper()
	center_panel.visible = true


func hide_center() -> void:
	center_panel.visible = false


func show_doors(labels: Array, hint_texts: Array, pick: int) -> void:
	doors_panel.visible = true
	var single := labels.size() == 1
	for i in 2:
		var on := i < labels.size()
		door_labels[i].visible = on
		door_hints[i].visible = on
		door_boxes[i].visible = on
		if not on:
			continue
		var x := 100.0 if single else 14.0 + i * 172.0
		door_boxes[i].position.x = x
		door_labels[i].position.x = x
		door_hints[i].position.x = x + 6.0
		door_labels[i].text = labels[i]
		door_hints[i].text = str(hint_texts[i]).to_upper()
		door_boxes[i].color = Color(0.45, 0.33, 0.15, 0.95) if i == pick else Color(0.18, 0.15, 0.12, 0.9)
		door_labels[i].label_settings.font_color = Color(1, 0.9, 0.5) if i == pick else Color(0.75, 0.72, 0.7)


func hide_doors() -> void:
	doors_panel.visible = false


func show_tavern(sheet: String, options: Array, pick: int, foot: String) -> void:
	tavern_panel.visible = true
	tavern_sheet.text = sheet.to_upper()
	tavern_opts.text = ""
	# One line per option, laid out from the option count so nothing overlaps.
	var y := 100.0
	for i in tavern_lines.size():
		var l := tavern_lines[i]
		l.visible = i < options.size()
		if not l.visible:
			continue
		l.position.y = y
		l.text = ("> " if i == pick else "  ") + str(options[i]).to_upper()
		l.label_settings.font_color = Color(0.45, 1.0, 0.45) if i == pick else Color(0.92, 0.92, 0.9)
		y += 12.0
	tavern_help.position.y = y + 4.0
	tavern_foot.position.y = y + 20.0
	tavern_foot.text = (foot + "\nArt: 0x72 (CC0). Fonts and sounds: Kenney (CC0). Includes material from SRD 5.1 and 5.2 by Wizards of the Coast LLC, CC-BY-4.0.").to_upper()


func hide_tavern() -> void:
	tavern_panel.visible = false


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
	ds_marks.text = "SUCCESSES %s FAILURES" % s
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
	if _note_t > 0.0:
		_note_t -= delta
		if _note_t <= 0.0:
			note_panel.visible = false
	if _ds_tumble > 0.0:
		_ds_tumble -= delta
		ds_roll.text = str(randi_range(1, 20)) if _ds_tumble > 0.0 else _ds_final
