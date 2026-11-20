class_name TouchControls
extends CanvasLayer
## On-screen controls for phones and tablets: a thumb stick on the left, action buttons on
## the right (attack, the hero's three abilities, roll, hop, talk/use, potion), and a pause
## button. Shown only on touch devices (or with ?touch=1 for testing).
##
## Taps elsewhere still work as clicks, so cards, door choices and the turn-based grid are
## played by tapping them directly; the stick and buttons hide while those are open.

const STICK_R := 26.0          # how far the thumb can push the stick
const STICK_CENTER := Vector2(58, 206)

var game: Node
var stick_base: Sprite2D
var stick_knob: Sprite2D
var _stick_finger := -1
var _stick_origin := STICK_CENTER
var _buttons := {}              # action -> {"node": TouchScreenButton, "label": Label}
var _last_key := ""


## Phones, tablets, or any browser whose main pointer is a finger.
static func wanted() -> bool:
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		return true
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if q is String and ((q as String).contains("touch=1") or (q as String).contains("test=touch")):
			return true
		var coarse = JavaScriptBridge.eval("(('ontouchstart' in window) || navigator.maxTouchPoints > 0) && window.matchMedia('(pointer: coarse)').matches", true)
		return bool(coarse)
	return OS.get_cmdline_user_args().has("--touch")


func _ready() -> void:
	layer = 15
	stick_base = Sprite2D.new()
	stick_base.texture = _circle(30, Color(1, 1, 1, 0.10), Color(1, 0.9, 0.7, 0.45))
	add_child(stick_base)
	stick_knob = Sprite2D.new()
	stick_knob.texture = _circle(13, Color(1, 0.9, 0.7, 0.45), Color(1, 1, 1, 0.7))
	add_child(stick_knob)
	_reset_stick()
	# Right-hand cluster: attack is the big one; abilities arc around it.
	_button("attack", Vector2(430, 214), 21, "ATK")
	_button("rage", Vector2(388, 232), 14, "K")
	_button("reckless", Vector2(392, 192), 14, "L")
	_button("echo", Vector2(424, 172), 14, "I")
	_button("form", Vector2(458, 168), 12, "Y")
	_button("dodge", Vector2(350, 246), 12, "ROLL")
	_button("hop", Vector2(462, 250), 11, "HOP")
	_button("interact", Vector2(458, 132), 13, "TALK")
	_button("potion", Vector2(350, 212), 11, "POT")
	_button("back", Vector2(14, 64), 9, "II")
	_button("toggle_log", Vector2(468, 104), 9, "LOG")


func _circle(r: int, fill: Color, rim: Color) -> Texture2D:
	var img := Image.create(r * 2 + 2, r * 2 + 2, false, Image.FORMAT_RGBA8)
	var c := Vector2(r + 1, r + 1)
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r - 1.5:
				img.set_pixel(x, y, fill)
			elif d <= r:
				img.set_pixel(x, y, rim)
	return ImageTexture.create_from_image(img)


func _button(action: String, at: Vector2, r: int, text: String) -> void:
	var b := TouchScreenButton.new()
	b.texture_normal = _circle(r, Color(0.1, 0.08, 0.12, 0.55), Color(1, 0.88, 0.6, 0.6))
	b.texture_pressed = _circle(r, Color(1, 0.85, 0.5, 0.45), Color(1, 1, 1, 0.9))
	var shape := CircleShape2D.new()
	shape.radius = r + 3
	b.shape = shape
	b.shape_centered = true
	b.action = action
	b.passby_press = false
	b.position = at - Vector2(r + 1, r + 1)
	add_child(b)
	var l := Label.new()
	l.label_settings = Art.label_settings(8, Color(1, 0.95, 0.85), 2)
	l.text = text
	l.size = Vector2(r * 2 + 2, 10)
	l.position = Vector2(0, r - 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	b.add_child(l)
	_buttons[action] = {"node": b, "label": l}


func _reset_stick() -> void:
	_stick_finger = -1
	_stick_origin = STICK_CENTER
	stick_base.position = STICK_CENTER
	stick_knob.position = STICK_CENTER
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


## The stick follows the thumb: touch anywhere in the lower left and it centres there.
func _input(event: InputEvent) -> void:
	# The end-of-run screen: any tap goes back to the tavern.
	if game and game.phase == game.Phase.OVER and event is InputEventScreenTouch and event.pressed:
		Input.action_press("confirm")
		_release_confirm.call_deferred()
		return
	if not visible or not stick_base.visible:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and _stick_finger == -1 and t.position.x < 200.0 and t.position.y > 110.0:
			_stick_finger = t.index
			_stick_origin = t.position
			stick_base.position = t.position
			_move_stick(t.position)
			get_viewport().set_input_as_handled()
		elif not t.pressed and t.index == _stick_finger:
			_reset_stick()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		if dr.index == _stick_finger:
			_move_stick(dr.position)
			get_viewport().set_input_as_handled()


func _move_stick(at: Vector2) -> void:
	var off := at - _stick_origin
	if off.length() > STICK_R:
		off = off.normalized() * STICK_R
	stick_knob.position = _stick_origin + off
	var v := off / STICK_R
	if v.length() < 0.2:
		v = Vector2.ZERO
	for pair in [["move_left", -v.x], ["move_right", v.x], ["move_up", -v.y], ["move_down", v.y]]:
		if pair[1] > 0.0:
			Input.action_press(pair[0], clampf(pair[1], 0.0, 1.0))
		else:
			Input.action_release(pair[0])


func _process(_delta: float) -> void:
	if not game or not is_instance_valid(game.player):
		return
	# Moving and acting only while walking around; menus, cards and the grid are tapped.
	var walking: bool = game.phase == game.Phase.TAVERN or game.phase == game.Phase.RUN
	stick_base.visible = walking
	stick_knob.visible = walking
	if not walking and _stick_finger != -1:
		_reset_stick()
	var calm: bool = game.peaceful() or game.phase == game.Phase.TAVERN
	var abil: Dictionary = game.player.kit.s.get("abilities", {}) if game.player.kit else {}
	for action in _buttons:
		var b: TouchScreenButton = _buttons[action].node
		var show := walking
		match action:
			"attack", "potion":
				show = walking and not calm
			"rage":
				show = walking and not calm and abil.has("L")
			"reckless":
				show = walking and not calm and abil.has("R")
			"echo":
				show = walking and not calm and abil.has("U")
			"form":
				show = walking and not calm and abil.has("Y")
			"toggle_log":
				show = walking and not calm
			"back":
				show = game.phase != game.Phase.CREATE
				_buttons[action].label.text = "II" if walking else "ESC"
				b.position = (Vector2(14, 64) if walking else Vector2(462, 62)) - Vector2(10, 10)
		b.visible = show
	_relabel()


## Button names follow the hero (Fire Bolt, Rage, Healing Word...), from the key hints.
func _relabel() -> void:
	var key := "%s_%d" % [game.hero.key, game.hero.level]
	if key == _last_key:
		return
	_last_key = key
	var names := {}
	for h in Kits.hints(game.hero.key, game.hero.level):
		names[str(h[0])] = str(h[1])
	var map := {"attack": "J/CLICK", "rage": "K", "reckless": "L", "echo": "I", "form": "Y"}
	for action in map:
		var n: String = names.get(map[action], "")
		if n != "":
			var t := _short(n)
			_buttons[action].label.text = t
			if t.length() > 5:
				_buttons[action].label.label_settings = Art.label_settings(6, Color(1, 0.95, 0.85), 1)


static func _short(n: String) -> String:
	var words := n.split(" ")
	var w: String = words[0]
	for x in words:
		if x.length() > w.length() and x != "FORM":
			w = x
	return w.substr(0, 9)


func _release_confirm() -> void:
	await get_tree().process_frame
	Input.action_release("confirm")
