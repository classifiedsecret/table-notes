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
var log_title: Label
var log_open := false
const TOAST_X := 124.0       # clear of the key hints panel
const TOAST_W := 196.0       # ends before the roll log (which starts at x 324 when scaled)
const UI_SCALE := 0.8         # corner readouts drawn at 80% so they cover less of the room
const LOG_Y := 255.0          # bottom edge of the screen, minus the collapsed bar
const LOG_SHUT_H := 14.0
const LOG_OPEN_H := 86.0
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
var door_close: Label         # the X in the door choice's corner
var door_labels: Array[Label] = []
var door_hints: Array[Label] = []
var door_boxes: Array[ColorRect] = []
var tavern_panel: PanelContainer
var tavern_sheet: Label
var tavern_opts: Label
var tavern_lines: Array[Label] = []
var tavern_help: Label
var tavern_foot: Label
var hints: PanelContainer      # key hints, stacked in the bottom-left corner
var _hint_keys: Label
var _hint_acts: Label
var _inn_mode := false
var _hero_key := "boarvhal"
var _game: Node
var hero_panel: Control
var tavern_title: Label
var tavern_sub: Label
var stats_panel: Control
var dlg_panel: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_yes: Label
var dlg_no: Label
const HINTS_INN := [["WASD", "MOVE"], ["SPACE", "HOP"], ["SHIFT", "DODGE ROLL"], ["E", "TALK / DOORS"], ["M", "MUSIC ON/OFF"], ["WHEEL", "MUSIC VOL"],
	["ESC", "PAUSE"], ["", "CELLAR: TRAPDOOR BY THE BAR"]]

var _log: Array[String] = []
var _banner_t := 0.0
var _toast_t := 0.0
var _note_t := 0.0
var _ds_tumble := 0.0
var _ds_final := ""


func build(g: Node) -> void:
	_game = g
	game = g
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var hero := _panel(Vector2(4, 4), Vector2(158, 68))
	hero_panel = hero
	hero.scale = Vector2.ONE * UI_SCALE
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

	# Where you are: top middle, between the hero panel and the roll stats.
	room_label = _label(root, Vector2(166, 4), "", 8, Color(1, 0.9, 0.65))
	room_label.size = Vector2(116, 20)
	room_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	room_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var sp := _panel(Vector2(286, 4), Vector2(190, 24))
	stats_panel = sp
	sp.pivot_offset = Vector2(190, 0)      # shrinks toward the top-right corner
	sp.scale = Vector2.ONE * UI_SCALE
	stats_label = _label(sp, Vector2(5, 2), "", 8, Color(0.9, 0.9, 0.85))
	rule_label = _label(sp, Vector2(5, 11), "", 8, Color(0.7, 0.75, 0.85))

	# The roll log sits in the bottom-right corner. Collapsed (the default) it shows one line;
	# Tab or a click opens it upward.
	log_panel = _panel(Vector2(286, LOG_Y), Vector2(190, LOG_SHUT_H))
	log_title = _label(log_panel, Vector2(5, 2), "", 8, Color(1, 0.9, 0.65))
	log_label = _label(log_panel, Vector2(5, 12), "", 8, Color(0.88, 0.88, 0.84))
	log_label.size = Vector2(181, 70)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.clip_text = true
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_set_log_open(false)

	_build_creator()

	banner_label = _label(root, Vector2(0, 70), "", 24, Color.WHITE, true)
	banner_label.size = Vector2(480, 24)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Toasts and prompts sit right of the key hints (bottom-left) and left of the roll log, and
	# wrap onto a second line rather than spill over either.
	toast_label = _label(root, Vector2(TOAST_X, 234), "", 8, Color(1, 0.95, 0.8))
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.custom_minimum_size = Vector2(TOAST_W, 10)
	toast_label.size = Vector2(TOAST_W, 10)
	prompt_label = _label(root, Vector2(TOAST_X, 206), "", 8, Color(0.6, 1.0, 0.7))
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.custom_minimum_size = Vector2(TOAST_W, 10)
	prompt_label.size = Vector2(TOAST_W, 10)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	note_panel = _panel(Vector2(120, 186), Vector2(352, 44), 0.92)
	note_label = _label(note_panel, Vector2(6, 4), "", 8, Color(1, 0.9, 0.6))
	note_label.size = Vector2(340, 38)
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_panel.visible = false

	# Death saves sit on their own top layer so nothing (battle UI, banners) draws over them.
	ds_panel = _panel(Vector2(120, 88), Vector2(240, 66), 0.98)
	var top := CanvasLayer.new()
	top.layer = 25
	add_child(top)
	ds_panel.get_parent().remove_child(ds_panel)
	top.add_child(ds_panel)
	var t := _label(ds_panel, Vector2(0, 4), "DEATH SAVES", 8, Color(1, 0.6, 0.55))
	t.size = Vector2(240, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds_roll = _label(ds_panel, Vector2(0, 13), "", 24, Color.WHITE, true)
	ds_roll.size = Vector2(240, 24)
	ds_roll.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ds_marks = _label(ds_panel, Vector2(0, 40), "", 8, Color.WHITE)
	ds_marks.size = Vector2(240, 10)
	ds_marks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var dt := _label(ds_panel, Vector2(0, 52), "D20: %d+ SUCCEEDS, 1 COUNTS TWICE, 20 REVIVES" % Rules.DEATH_SAVE_DC, 8, Color(0.7, 0.7, 0.75))
	dt.size = Vector2(240, 10)
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
	var dfoot := _label(doors_panel, Vector2(0, 96), "CLICK A DOOR, OR LEFT / RIGHT AND ENTER    X / ESC: BACK", 8, Color(0.6, 0.6, 0.66))
	door_close = _label(doors_panel, Vector2(340, 2), "X", 16, Color(1, 0.75, 0.6), true)
	door_close.size = Vector2(16, 16)
	dfoot.size = Vector2(360, 10)
	dfoot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	doors_panel.visible = false

	tavern_panel = _panel(Vector2(40, 5), Vector2(400, 260), 0.97)
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
	tavern_help = _label(tavern_panel, Vector2(18, 150), "CLICK AN OPTION, OR UP / DOWN AND ENTER", 8, Color(0.7, 0.7, 0.76))
	tavern_foot = _label(tavern_panel, Vector2(18, 166), "", 8, Color(0.6, 0.6, 0.68))
	tavern_foot.size = Vector2(364, 50)
	tavern_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tavern_panel.visible = false

	dlg_panel = _panel(Vector2(134, 196), Vector2(340, 40), 0.95)
	dlg_name = _label(dlg_panel, Vector2(8, 3), "", 8, Color(1, 0.85, 0.45))
	dlg_text = _label(dlg_panel, Vector2(8, 13), "", 8, Color(0.94, 0.94, 0.9))
	dlg_text.size = Vector2(324, 24)
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_yes = _label(dlg_panel, Vector2(262, 3), "[ YES ]", 8, Color(0.45, 1.0, 0.45))
	dlg_no = _label(dlg_panel, Vector2(304, 3), "[ NO ]", 8, Color(1.0, 0.55, 0.5))
	for l in [dlg_yes, dlg_no]:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.visible = false
	dlg_panel.visible = false

	hints = _panel(Vector2(4, 180), Vector2(96, 86), 0.45)
	_hint_keys = _label(hints, Vector2(5, 3), "", 8, Color(1, 0.85, 0.45))
	_hint_acts = _label(hints, Vector2(45, 3), "", 8, Color(0.82, 0.8, 0.86))
	for l in [_hint_keys, _hint_acts]:
		l.label_settings.line_spacing = -1.0
	_show_hints(Kits.hints("boarvhal"))
	# Drawn first, so every other panel (level-ups, dialogue, toasts) sits on top of it.
	hints.get_parent().move_child(hints, 0)


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
	if h.key != "boarvhal":
		r = p.kit.status_line()
	rage_label.text = r
	bonus_label.text = "BONUS ACTION READY" if p.bonus_cd <= 0.0 else "BONUS ACTION IN %dS" % ceili(p.bonus_cd)
	bonus_label.label_settings.font_color = Color(0.7, 0.95, 0.7) if p.bonus_cd <= 0.0 else Color(0.6, 0.6, 0.65)
	var in_run: bool = g.phase in [1, 2, 3, 4]
	purse_label.text = "GOLD %d  POTIONS %d  HIT DICE %d" % [h.gold + (g.run_gold if in_run else 0), g.run_potions if in_run else h.potions, g.hit_dice]
	var rolls: int = stats.get("rolls", 0)
	var pct := 0 if rolls == 0 else roundi(100.0 * stats.get("hits", 0) / rolls)
	stats_label.text = "YOUR ATTACKS %d  HITS %d (%d%%)  CRITS %d" % [rolls, stats.get("hits", 0), pct, stats.get("crits", 0)]
	rule_label.text = "GLANCING %d   FUMBLES %d (TOOK %d)" % [stats.get("glances", 0), stats.get("fumbles", 0), stats.get("self", 0)]


## Key hints as a stacked list: keys in gold on the left, what they do on the right.
# ---------------- character creation ----------------

var creator: PanelContainer
var cr_name: LineEdit
var cr_rows: Array[Label] = []        # name, class, look, begin
var cr_arrows: Array[Label] = []      # class <, class >, look <, look >
var cr_blurb: Label
var cr_preview: AnimatedSprite2D
var cr_begin: Label

const CLASS_BLURBS := {
	"boarvhal": "BARBARIAN: RAGE, RECKLESS ATTACK AND AN ECHO OF YOURSELF (ECHO KNIGHT). TOUGH AND HARD-HITTING.",
	"ceridwen": "WIZARD: FIRE BOLT, MAGIC MISSILE, SCORCHING RAY AND FORESIGHT. LATER, FIREBALL.",
	"erwar": "CLERIC: MACE AND SHIELD, HEALING WORD, SPIRITUAL WEAPON, WAR BLESSING. LATER, SPIRIT GUARDIANS.",
	"lyburnum": "PALADIN: LONGSWORD, LAY ON HANDS, DIVINE SMITE AND DREAD AURA. HEAVY ARMOUR.",
	"suilean": "DRUID: THORN WHIP, ENTANGLE, MOONBEAM, AND WILD SHAPE INTO A BEAR OR A GIANT SPIDER.",
}


func _build_creator() -> void:
	creator = _panel(Vector2(70, 34), Vector2(340, 200), 0.97)
	creator.z_index = 5
	var t := _label(creator, Vector2(0, 6), "CREATE YOUR CHARACTER", 16, Color(1, 0.88, 0.55), true)
	t.size = Vector2(340, 16)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var holder: Control = creator.get_meta("holder")
	cr_rows.clear()
	cr_arrows.clear()
	cr_rows.append(_label(creator, Vector2(16, 34), "NAME", 8, Color.WHITE))
	cr_name = LineEdit.new()
	cr_name.position = Vector2(80, 30)
	cr_name.size = Vector2(150, 16)
	cr_name.max_length = 18
	cr_name.placeholder_text = "Type a name"
	cr_name.add_theme_font_override("font", Art.label_settings(8, Color.WHITE, 0).font)
	cr_name.add_theme_font_size_override("font_size", 8)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.1, 0.14)
	sb.border_color = Color(0.6, 0.5, 0.35)
	sb.set_border_width_all(1)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	for st in ["normal", "focus", "read_only"]:
		cr_name.add_theme_stylebox_override(st, sb)
	cr_name.custom_minimum_size = Vector2(150, 12)
	cr_name.size = Vector2(150, 12)
	holder.add_child(cr_name)
	cr_rows.append(_label(creator, Vector2(16, 62), "CLASS", 8, Color.WHITE))
	cr_arrows.append(_label(creator, Vector2(80, 62), "<", 8, Color(1, 0.85, 0.5)))
	cr_arrows.append(_label(creator, Vector2(222, 62), ">", 8, Color(1, 0.85, 0.5)))
	cr_blurb = _label(creator, Vector2(16, 76), "", 8, Color(0.8, 0.8, 0.85))
	cr_blurb.size = Vector2(308, 30)
	cr_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cr_rows.append(_label(creator, Vector2(16, 112), "LOOK", 8, Color.WHITE))
	cr_arrows.append(_label(creator, Vector2(80, 112), "<", 8, Color(1, 0.85, 0.5)))
	cr_arrows.append(_label(creator, Vector2(132, 112), ">", 8, Color(1, 0.85, 0.5)))
	cr_preview = AnimatedSprite2D.new()
	cr_preview.position = Vector2(112, 128)
	cr_preview.scale = Vector2(1.5, 1.5)
	holder.add_child(cr_preview)
	cr_begin = _label(creator, Vector2(0, 160), "BEGIN", 16, Color(1, 0.9, 0.5), true)
	cr_begin.size = Vector2(340, 16)
	cr_begin.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr_rows.append(cr_begin)
	var foot_text := "TAP < > TO CHANGE   TAP BEGIN WHEN READY" if TouchControls.wanted() else "UP/DOWN: CHOOSE A LINE   LEFT/RIGHT: CHANGE   ENTER OR CLICK: BEGIN"
	var foot := _label(creator, Vector2(0, 184), foot_text, 8, Color(0.6, 0.6, 0.66))
	foot.size = Vector2(340, 10)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	creator.visible = false


func show_creator(kit_key: String, look: String, row: int) -> void:
	creator.visible = true
	hero_panel.visible = false
	cr_rows[1].text = "CLASS"
	var cls: String = Hero.CLASS_NAMES[kit_key].to_upper()
	var cl := cr_rows[1].get_parent().get_node_or_null("cls_name") as Label
	if cl == null:
		cl = _label(creator, Vector2(94, 62), "", 8, Color(1, 0.95, 0.8))
		cl.name = "cls_name"
		cl.size = Vector2(124, 10)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cl.text = cls
	cr_blurb.text = CLASS_BLURBS.get(kit_key, "")
	cr_preview.sprite_frames = Art.strip_frames(load("res://assets/sprites/%s.png" % look), 16, 28, {
		"idle": [0, 4, 6, true], "run": [4, 4, 11, true], "hit": [8, 1, 1, false]})
	cr_preview.play("idle")
	for i in cr_rows.size():
		cr_rows[i].label_settings.font_color = Color(1, 0.85, 0.4) if i == row else (Color(0.75, 0.72, 0.7) if i == 3 else Color.WHITE)
	cr_begin.text = "> BEGIN <" if row == 3 else "BEGIN"


func hide_creator() -> void:
	creator.visible = false
	hero_panel.visible = true
	cr_name.release_focus()


var touch_mode := false

## On touch devices the key hints give way to the thumb stick, and the roll log moves up
## out of the way of the buttons.
func set_touch_mode(on: bool) -> void:
	touch_mode = on
	if hints:
		hints.visible = not on
	_set_log_open(log_open)


func _show_hints(list: Array) -> void:
	var ks: Array[String] = []
	var acts: Array[String] = []
	for h in list:
		ks.append(str(h[0]))
		acts.append(str(h[1]))
	_hint_keys.text = "\n".join(ks)
	_hint_acts.text = "\n".join(acts)
	var h := 8.0 + 9.0 * list.size()
	var w := 45.0 + _hint_acts.label_settings.font.get_multiline_string_size(_hint_acts.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 6.0
	hints.position = Vector2(4, 266.0 - h)
	hints.size = Vector2(w, h)
	hints.reset_size()
	hints.size = Vector2(w, h)
	# The panel may grow to fit its text: anchor its real bottom edge just above the screen's.
	hints.position.y = 266.0 - hints.size.y
	hints.pivot_offset = Vector2(0, hints.size.y)   # shrinks toward the bottom-left corner
	hints.scale = Vector2.ONE * UI_SCALE
	if touch_mode:
		hints.visible = false


## The hint list fades when the hero walks behind it.
func _fade_hints() -> void:
	if hints == null or _game == null or not is_instance_valid(_game.player):
		return
	var sp: Vector2 = _game.player.get_global_transform_with_canvas().origin
	var behind := Rect2(hints.position - Vector2(6, 0), hints.size + Vector2(12, 30)).has_point(sp)
	hints.modulate.a = lerpf(hints.modulate.a, 0.22 if behind else 1.0, 0.25)
	# The hero's panel fades too (Boar-vhal's room sits right under it).
	var hb := Rect2(hero_panel.position - Vector2(6, 0), hero_panel.size + Vector2(12, 34)).has_point(sp)
	hero_panel.modulate.a = lerpf(hero_panel.modulate.a, 0.25 if hb else 1.0, 0.25)


func _hero_level() -> int:
	return game.hero.level if game and game.hero else 1


func set_hero_hints(key: String) -> void:
	_hero_key = key
	if not _inn_mode:
		_show_hints(Kits.hints(key, _hero_level()))


## In the inn the combat readouts are hidden and the key hints change.
func set_inn_mode(on: bool) -> void:
	_inn_mode = on
	stats_panel.visible = not on
	log_panel.visible = not on
	_show_hints(HINTS_INN if on else Kits.hints(_hero_key, _hero_level()))
	if not on:
		hide_dialogue()


func set_tavern_title(title: String, sub: String) -> void:
	tavern_title.text = title
	tavern_sub.text = sub


func show_dialogue(who: String, text: String) -> void:
	dlg_panel.visible = true
	dlg_yes.visible = false
	dlg_no.visible = false
	dlg_name.text = who.to_upper() + "   (E: MORE)"
	dlg_text.text = text.to_upper()


## A yes/no question in the dialogue box.
func show_confirm(title: String, text: String) -> void:
	dlg_panel.visible = true
	dlg_yes.visible = true
	dlg_no.visible = true
	dlg_name.text = title.to_upper() + "   E: YES  ESC: NO"
	dlg_text.text = text.to_upper()


func hide_dialogue() -> void:
	dlg_panel.visible = false


func set_room(text: String) -> void:
	room_label.text = text


func prompt(text: String) -> void:
	if touch_mode and text.begins_with("E: "):
		text = "TALK: " + text.substr(3)
	prompt_label.text = text
	var w := 350.0 if _inn_mode else TOAST_W
	prompt_label.custom_minimum_size = Vector2(w, 10)
	prompt_label.size = Vector2(w, 10)


func level_note(text: String) -> void:
	note_label.text = text.to_upper()
	note_panel.visible = text != ""
	# Grow the box to fit the wrapped text, keeping its bottom edge in place.
	var ls := note_label.label_settings
	var h: float = ls.font.get_multiline_string_size(note_label.text, HORIZONTAL_ALIGNMENT_LEFT, 340.0, ls.font_size).y
	note_label.size = Vector2(340, h)
	note_panel.size = Vector2(352, h + 8)
	note_panel.position = Vector2(120, 232 - (h + 8))
	_note_t = 9.0


func add_log(line: String) -> void:
	_log.append(line)
	while _log.size() > 8:
		_log.pop_front()
	log_label.text = "\n".join(_log)
	if not log_open:
		log_title.text = "LOG: " + line.to_upper()


func toggle_log() -> void:
	if _inn_mode:
		return
	_set_log_open(not log_open)


func _set_log_open(on: bool) -> void:
	log_open = on
	var h := LOG_OPEN_H if on else LOG_SHUT_H
	log_panel.custom_minimum_size = Vector2(190, h)
	log_panel.size = Vector2(190, h)
	log_panel.position = Vector2(286, LOG_Y + LOG_SHUT_H - h)
	log_panel.pivot_offset = Vector2(190, h)   # shrinks toward the bottom-right corner
	if touch_mode:
		log_panel.position = Vector2(286, 26)      # under the roll stats, clear of the buttons
		log_panel.pivot_offset = Vector2(190, 0)
	log_panel.scale = Vector2.ONE * UI_SCALE
	log_label.visible = on
	log_title.clip_text = true
	log_title.size = Vector2(181, 10)
	if on:
		log_title.text = "ROLL LOG  (TAB OR CLICK TO CLOSE)"
	else:
		log_title.text = ("LOG: " + _log[-1].to_upper()) if not _log.is_empty() else "ROLL LOG  (TAB OR CLICK TO OPEN)"


## The mouse is over the roll log (a click there opens or closes it, and doesn't swing).
func mouse_over_log() -> bool:
	return log_panel.visible and log_panel.get_global_rect().has_point(get_viewport().get_mouse_position())


func banner(text: String, color: Color) -> void:
	banner_label.text = text
	banner_label.label_settings.font_color = color
	_banner_t = 1.6


func toast(text: String) -> void:
	toast_label.text = text.to_upper()
	# In the inn the roll log is hidden, so a toast may use the whole width right of the hints.
	var w := 350.0 if _inn_mode else TOAST_W
	toast_label.custom_minimum_size = Vector2(w, 10)
	toast_label.size = Vector2(w, 10)
	# Two lines grow upward, so the toast never reaches the bottom edge.
	toast_label.position.y = 244.0 - toast_label.get_minimum_size().y
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
	# Options start below however many lines the hero sheet takes (a party adds one),
	# then one line per option, so nothing overlaps.
	var sheet_lines := sheet.count("\n") + 1
	var y := 46.0 + sheet_lines * 13.0 + 4.0
	for i in tavern_lines.size():
		var l := tavern_lines[i]
		l.visible = i < options.size()
		if not l.visible:
			continue
		l.position.y = y
		l.text = ("> " if i == pick else "  ") + str(options[i]).to_upper()
		l.label_settings.font_color = Color(0.45, 1.0, 0.45) if i == pick else Color(0.92, 0.92, 0.9)
		y += 11.0
	tavern_help.position.y = y + 3.0
	tavern_foot.position.y = y + 17.0
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
		var col := Color(0.6, 1, 0.6) if last.roll >= Rules.DEATH_SAVE_DC else Color(1, 0.45, 0.4)
		if last.roll == 20:
			col = Color(1, 0.85, 0.3)
		ds_roll.label_settings.font_color = col
	elif ds.successes == 0 and ds.failures == 0:
		ds_roll.text = "..."


func _process(delta: float) -> void:
	_fade_hints()
	if hints and hints.position.y != 266.0 - hints.size.y:
		hints.position.y = 266.0 - hints.size.y   # its text can resize it a frame later
		hints.pivot_offset = Vector2(0, hints.size.y)
	if game and game.clicked() and mouse_over_log():
		_set_log_open(not log_open)
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
