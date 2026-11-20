class_name PauseMenu
extends CanvasLayer
## ESC pauses the game: the world freezes and this menu takes the keys.

var game: Node
var items: Array = []
var pick := 0
var panel: PanelContainer
var title: Label
var lines: Array[Label] = []
var note: Label
var _opened := 0
var _rmb_held := true
var _last_m := Vector2.ZERO


func setup(g: Node) -> void:
	game = g
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.size = Vector2(480, 270)
	add_child(shade)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.09, 0.96)
	sb.border_color = Color(0.55, 0.44, 0.3)
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(150, 70)
	panel.size = Vector2(180, 110)
	add_child(panel)
	var holder := Control.new()
	panel.add_child(holder)
	title = Label.new()
	title.label_settings = Art.label_settings(16, Color(1, 0.88, 0.55), 3, true)
	title.text = "PAUSED"
	title.size = Vector2(180, 18)
	title.position = Vector2(0, 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(title)
	for i in 4:
		var l := Label.new()
		l.label_settings = Art.label_settings(8, Color.WHITE, 2)
		l.position = Vector2(16, 32 + i * 12)
		holder.add_child(l)
		lines.append(l)
	note = Label.new()
	note.label_settings = Art.label_settings(8, Color(0.6, 0.58, 0.66), 2)
	note.position = Vector2(10, 84)
	note.size = Vector2(160, 20)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	holder.add_child(note)


func open() -> void:
	items = [["Resume", "resume"], ["Music: " + ("off" if game.music.muted else "on"), "music"],
		[_fs_text(), "fullscreen"], ["Exit to Session Scribe", "exit"]]
	pick = 0
	_opened = Engine.get_process_frames()
	visible = true
	game.get_tree().paused = true
	game.sfx.play("step", -8.0)
	_render()


## Taps arrive as emulated mouse clicks; catch them here since the game is paused.
var _tap_frame := -1
func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_tap_frame = Engine.get_process_frames()


static func is_fullscreen() -> bool:
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("(document.fullscreenElement || document.webkitFullscreenElement) ? 1 : 0", true)
		return r != null and int(r) == 1
	return DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]


func _fs_text() -> String:
	return "Full screen: " + ("on" if is_fullscreen() else "off")


## The browser allows this right after a tap or key press. On phones it also turns to landscape.
func toggle_fullscreen() -> void:
	if OS.has_feature("web"):
		if is_fullscreen():
			JavaScriptBridge.eval("(document.exitFullscreen || document.webkitExitFullscreen).call(document)", true)
		else:
			JavaScriptBridge.eval("""(function(){var e=document.documentElement;
				var r=e.requestFullscreen||e.webkitRequestFullscreen; if(!r) return;
				var p=r.call(e,{navigationUI:'hide'});
				var lock=function(){ try{ if(screen.orientation&&screen.orientation.lock) screen.orientation.lock('landscape').catch(function(){}); }catch(x){} };
				if(p&&p.then) p.then(lock).catch(function(){}); else lock();})()""", true)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_fullscreen() else DisplayServer.WINDOW_MODE_FULLSCREEN)


func close() -> void:
	visible = false
	game.get_tree().paused = false


func _render() -> void:
	for i in lines.size():
		var l := lines[i]
		l.visible = i < items.size()
		if i < items.size():
			l.text = ("> " if i == pick else "  ") + str(items[i][0]).to_upper()
			l.label_settings.font_color = Color(0.45, 1.0, 0.45) if i == pick else Color(0.92, 0.92, 0.9)
	note.text = "LEAVING MID-DELVE LOSES THIS DELVE'S GOLD." if game.phase in [1, 2, 3] and items[pick][1] == "exit" else ("TAP II TO GO BACK" if game.touch_mode else "ESC: BACK TO THE GAME")


func _hovered() -> int:
	var m := get_viewport().get_mouse_position()
	for i in items.size():
		if lines[i].get_global_rect().grow(2.0).has_point(m):
			return i
	return -1


func _process(_delta: float) -> void:
	if not visible or Engine.get_process_frames() == _opened:
		_last_m = get_viewport().get_mouse_position()
		return
	if Engine.get_process_frames() % 15 == 0:
		for it in items:
			if it[1] == "fullscreen" and it[0] != _fs_text():
				it[0] = _fs_text()
				_render()
	var m := get_viewport().get_mouse_position()
	var hov := _hovered()
	if hov >= 0 and hov != pick and m.distance_to(_last_m) > 0.5:
		pick = hov
		_render()
	_last_m = m
	var lmb := _tap_frame == Engine.get_process_frames() - 1 or _tap_frame == Engine.get_process_frames()
	if lmb:
		_tap_frame = -1
	var rmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var right_click := rmb and not _rmb_held
	_rmb_held = rmb
	if Input.is_action_just_pressed("back") or right_click:
		close()
	elif Input.is_action_just_pressed("move_down"):
		pick = (pick + 1) % items.size()
		_render()
	elif Input.is_action_just_pressed("move_up"):
		pick = (pick - 1 + items.size()) % items.size()
		_render()
	elif Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("interact") or \
			(Input.is_action_just_pressed("attack") and not lmb) or (lmb and hov >= 0):
		if lmb and hov < 0:
			return
		if lmb:
			pick = hov
		match items[pick][1]:
			"resume":
				close()
			"music":
				game.music.toggle_mute()
				items[1][0] = "Music: " + ("off" if game.music.muted else "on")
				_render()
			"fullscreen":
				toggle_fullscreen()
			"exit":
				close()
				game._leave_to_site()

