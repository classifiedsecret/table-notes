extends Node2D
## Vanguard's Descent: tavern hub, Goblin Warren runs, door choices, the turn-based boss, saves.

enum Phase { TAVERN, RUN, DOORS, BATTLE, OVER, CARD }   # TAVERN = walking around the inn

const BIOME := "Goblin Warren"
const ROOMS_BEFORE_BOSS := 5
const ROOM_POOL := {
	"combat": ["warren_combat_1", "warren_combat_2", "warren_combat_3"],
	"gauntlet": ["warren_gauntlet_1", "warren_gauntlet_2"],
	"treasure": ["warren_treasure_1"],
	"campfire": ["warren_campfire_1"],
	"elite": ["warren_elite_1"],
}
const ROOM_LABEL := {"combat": "COMBAT", "gauntlet": "GAUNTLET", "treasure": "TREASURE", "campfire": "CAMPFIRE", "elite": "ELITE", "boss": "BOSS"}
const ROOM_HINT := {"combat": "Goblins. The door bars until they fall.", "gauntlet": "Traps and spikes. Few foes.",
	"treasure": "A locked chest, lightly guarded.", "campfire": "A safe fire for a short rest.",
	"elite": "A tougher pack. Bigger rewards.", "boss": "The Bugbear Chief's hall."}
const POTION_PRICE := 50

var dice: Dice
var sfx: Sfx
var room: Room
var player: Player
var camera: Camera2D
var hud: Hud
var battle: Node
var inn: Inn
var music: Music
var pause_menu: PauseMenu
var _talking: InnNPC
var _confirm_exit := false
var _confirm_join: InnNPC        # asking a party member to come along
var party: Array[String] = []    # companions for the next delve (hero keys)
var companions: Array[Companion] = []
const MAX_COMPANIONS := 4
var _quest_i := -1      # >= 0 while the Hooded Stranger is giving the quest
var _barred_t := 0.0
var hero := Hero.new()
var phase := Phase.TAVERN
var enemies: Array[Enemy] = []
var props: Array[Node2D] = []
var stats := {"swings": 0, "rolls": 0, "hits": 0, "crits": 0, "fumbles": 0, "glances": 0, "self": 0, "taken": 0, "kills": 0, "nat20s": 0, "xp": 0}
var run_gold := 0
var run_potions := 0
var hit_dice := 1
var depth := 0
var room_type := ""
var _used_rooms: Array[String] = []
var _door_options: Array[String] = []
var _door_pick := 0
var _menu_pick := 0
var _campfire_taken := false
var _bridge: JavaScriptObject
var _cb_load: JavaScriptObject
var _cb_save: JavaScriptObject
var _cb_who: JavaScriptObject
var _cb_staff: JavaScriptObject
var _cb_biz: JavaScriptObject
var save_mode := "local"
var _loaded := false
var _me_key := ""          # the hero matching Session Scribe's "You are", if any
var _switching := false    # loading another hero's save
var bot := OS.get_cmdline_user_args().has("--bot")
var _face_log := false
var _bot_t := 0.0
var _stat_t := 0.0


func _ready() -> void:
	Art.setup_fonts()
	_setup_input()
	if _arg("topdown"):
		# The top-down test room is its own little scene; hand over to it.
		RenderingServer.set_default_clear_color(Color(0.05, 0.04, 0.07))
		var td := TDMain.new()
		get_parent().add_child.call_deferred(td)
		queue_free()
		return
	# Physics interpolation smooths only bodies moved in physics steps (hero, goblins, arrows, camera).
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	dice = Dice.new(randi() % 900000 + 100000)
	RenderingServer.set_default_clear_color(Color(0.05, 0.04, 0.07))
	sfx = Sfx.new()
	add_child(sfx)
	camera = Camera2D.new()
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	hud = Hud.new()
	add_child(hud)
	hud.build(self)
	battle = preload("res://scripts/game/battle.gd").new()
	add_child(battle)
	music = Music.new()
	music.game = self
	add_child(music)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(self)
	music.play("tavern", 2.0)
	inn = Inn.new()
	add_child(inn)
	move_child(inn, 0)
	inn.build(self)
	room = inn.room
	_set_camera_limits()
	_spawn_player()
	hud.set_inn_mode(true)
	_load_hero()


# ---------------- input ----------------

func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_down": [KEY_S, KEY_DOWN],
		"move_up": [KEY_W, KEY_UP],
		"jump": [KEY_SPACE, KEY_W, KEY_UP], "attack": [KEY_J, KEY_Z], "dodge": [KEY_K, KEY_SHIFT, KEY_C],
		"rage": [KEY_L, KEY_Q], "toggle_log": [KEY_TAB, KEY_I], "confirm": [KEY_ENTER, KEY_KP_ENTER],
		"interact": [KEY_E, KEY_F], "potion": [KEY_H], "reckless": [KEY_R], "echo": [KEY_U],
		"back": [KEY_ESCAPE, KEY_BACKSPACE], "test_down": [KEY_F2], "music": [KEY_M], "form": [KEY_Y],
	}
	var pads := {"jump": [JOY_BUTTON_A], "attack": [JOY_BUTTON_X], "dodge": [JOY_BUTTON_B],
		"rage": [JOY_BUTTON_Y], "toggle_log": [JOY_BUTTON_BACK], "confirm": [JOY_BUTTON_START, JOY_BUTTON_A],
		"interact": [JOY_BUTTON_LEFT_SHOULDER], "echo": [JOY_BUTTON_RIGHT_SHOULDER], "potion": [JOY_BUTTON_DPAD_UP],
		"back": [JOY_BUTTON_B],
		"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT], "move_down": [JOY_BUTTON_DPAD_DOWN],
		"move_up": [JOY_BUTTON_DPAD_UP], "form": [JOY_BUTTON_LEFT_STICK]}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.35)
		for k: int in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
		for b: int in pads.get(action, []):
			var j := InputEventJoypadButton.new()
			j.button_index = b
			InputMap.action_add_event(action, j)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_down": [JOY_AXIS_LEFT_Y, 1.0], "move_up": [JOY_AXIS_LEFT_Y, -1.0], "reckless": [JOY_AXIS_TRIGGER_RIGHT, 1.0]}
	for action: String in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = axes[action][0]
		m.axis_value = axes[action][1]
		InputMap.action_add_event(action, m)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", click)


# ---------------- mouse ----------------
# Menus, doors and the battle can be clicked: hover highlights, left click chooses,
# right click goes back. A left click outside a menu is ignored (it no longer confirms
# whatever happens to be highlighted).

var _click_frame := -10
var _rclick_frame := -10
var _last_mouse := Vector2(-1, -1)
var _mouse_moved := false


func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_click_frame = Engine.get_process_frames()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_rclick_frame = Engine.get_process_frames()


func clicked() -> bool:
	return _click_frame == Engine.get_process_frames()


func right_clicked() -> bool:
	return _rclick_frame == Engine.get_process_frames()


func mouse_moved() -> bool:
	return _mouse_moved


## Keyboard/gamepad confirm (attack only counts when it didn't come from the mouse).
func ui_confirm() -> bool:
	return Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("interact") or \
		(Input.is_action_just_pressed("attack") and not clicked())


func ui_back() -> bool:
	return Input.is_action_just_pressed("back") or right_clicked()


## Index of the visible control under the mouse, or -1.
func under_mouse(controls: Array) -> int:
	var m := get_viewport().get_mouse_position()
	for i in controls.size():
		var c: Control = controls[i]
		if is_instance_valid(c) and c.is_visible_in_tree() and c.get_global_rect().grow(1.0).has_point(m):
			return i
	return -1


func accepting_input() -> bool:
	return phase == Phase.RUN or phase == Phase.TAVERN


# ---------------- hero saves ----------------

func _hero_id(key: String) -> String:
	var me := ""
	if _bridge:
		me = str(_bridge.me())
	var slug := me.to_lower().strip_edges().replace(" ", "-")
	return (slug if slug != "" else "guest") + "_" + key


## Who "You are" on Session Scribe decides the starting hero; then that hero's save loads.
func _on_whoami(args: Array) -> void:
	var member := ""
	if args.size() > 0 and args[0] != null:
		var d = JSON.parse_string(str(args[0]))
		if typeof(d) == TYPE_DICTIONARY:
			hero.owner = str(d.get("player", d.get("name", "")))
			member = str(d.get("name", ""))
	_me_key = Kits.key_for_name(member)
	_load_hero_key(_me_key if _me_key != "" else "boarvhal")


func _hero_arg() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hero="):
			return a.substr(7)
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if q is String and (q as String).contains("hero="):
			return (q as String).get_slice("hero=", 1).get_slice("&", 0)
	return ""


func _load_hero() -> void:
	if OS.has_feature("web"):
		_bridge = JavaScriptBridge.get_interface("VDSave")
	if _bridge:
		_cb_load = JavaScriptBridge.create_callback(_on_hero_loaded)
		_cb_save = JavaScriptBridge.create_callback(_on_hero_saved)
		_cb_who = JavaScriptBridge.create_callback(_on_whoami)
		if _hero_arg() != "":
			_load_hero_key(_hero_arg())
		else:
			_bridge.whoami(_cb_who)
	else:
		_load_hero_key(_hero_arg() if Kits.has(_hero_arg()) else "boarvhal")


## Loads one hero's save (or starts them fresh) and makes them the hero being played.
func _load_hero_key(key: String) -> void:
	if party.has(key):
		party.erase(key)
		inn.return_home("npc_" + key)
		for i in party.size():
			inn.send_to_cellar("npc_" + party[i], i)
	var owner := hero.owner
	var heard := hero.quest_given
	hero = Hero.new()
	hero.set_key(key)
	hero.owner = owner
	hero.quest_given = heard
	player.hero = hero
	_switching = true
	if _bridge:
		hero.id = _hero_id(key)
		_bridge.loadDoc("vd_heroes", hero.id, _cb_load)
	else:
		hero.id = "local_" + key
		var path := "user://hero.json" if key == "boarvhal" else "user://hero_%s.json" % key
		var txt := FileAccess.get_file_as_string(path) if not bot else ""
		_on_hero_loaded([txt if txt != "" else null])


func _on_hero_loaded(args: Array) -> void:
	var heard := hero.quest_given
	if args.size() > 0 and args[0] != null:
		var d = JSON.parse_string(str(args[0]))
		if typeof(d) == TYPE_DICTIONARY:
			hero.load_dict(d)
	hero.quest_given = hero.quest_given or heard   # you, the player, already heard the Stranger
	save_mode = str(_bridge.mode()) if _bridge else "local"
	var first := not _loaded
	_loaded = true
	_switching = false
	player.apply_hero(hero)
	player.hp = player.max_hp
	player.hp_changed.emit()
	inn.set_playing(hero.key)
	hud.set_hero_hints(hero.key)
	if first and phase == Phase.TAVERN:
		# Every hero starts the day in their own room.
		player.global_position = inn.room_spawn(hero.key)
		player.facing = -1
		_set_camera_limits()
		_snap_view()
	if not first:
		if phase == Phase.CARD:
			_refresh_tavern()
		return
	_load_party_data()
	if _arg("lv5"):
		hero.level = 5
		hero.xp = 6500
		player.apply_hero(hero)
	if _arg("t3"):
		hero.tier_unlocked = 3
		hero.tier = 3
	var party_args := OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if q is String and (q as String).contains("party="):
			party_args.append("--party=" + (q as String).get_slice("party=", 1).get_slice("&", 0))
	for a in party_args:
		if a.begins_with("--party="):
			for k in a.substr(8).split(","):
				if Kits.has(k):
					party.append(k)
	if _arg("boss"):
		if not _arg("lv5"):
			hero.level = 2
			hero.xp = 300
		_start_run()
		depth = ROOMS_BEFORE_BOSS
		_enter_room("boss")
		return
	if _arg("face"):
		_face_log = true
		_start_run()
		for e in enemies:
			e.queue_free()
		enemies.clear()
		return
	if _arg("jump"):
		_start_run()
		for e in enemies:
			e.queue_free()
		enemies.clear()
		var start_y := player.global_position.y
		var tt := [0]
		var tm := Timer.new()
		tm.wait_time = 0.02
		tm.autostart = true
		tm.timeout.connect(func():
			tt[0] += 1
			var t: int = tt[0]
			if OS.get_cmdline_user_args().has("--facetest"):
				var mm := InputEventMouseMotion.new()
				mm.position = Vector2(10, 135) if t < 60 else Vector2(470, 135)
				Input.parse_input_event(mm)
				if t == 20: Input.action_press("move_right")
				if t == 45: Input.action_release("move_right")
				if t == 58: Input.action_press("attack")
				if t == 59: Input.action_release("attack")
				if t % 4 == 0: print("[face] t=%d moving=%s st=%s facing=%d aim=%s mw=%s px=%.0f" % [t, Input.is_action_pressed("move_right"), Player.State.keys()[player.state], player.facing, player._mouse_aim, str((player.get_canvas_transform().affine_inverse() * player._mouse_screen).round()), player.global_position.x])
				return
			if t == 20: Input.action_press("jump")
			if t == 70: Input.action_release("jump")
			if t > 18 and t % 3 == 0 and t < 60: print("[jump] t=%d y=%.1f vy=%.0f floor=%s state=%s" % [t, start_y - player.global_position.y, player.velocity.y, player.is_on_floor(), Player.State.keys()[player.state]]))
		add_child(tm)
		return
	if _arg("card"):
		party.append_array(["lyburnum", "ceridwen"])
		_open_tavern()
		get_tree().create_timer(1.5).timeout.connect(_open_card)
		return
	if _arg("note"):
		get_tree().create_timer(1.0).timeout.connect(func(): hud.level_note(Kits.level_features(hero.key, 2)))
	if _arg("doors"):
		_start_run()
		for e in enemies:
			e.queue_free()
		enemies.clear()
		_offer_doors()
		return
	_open_tavern()


## Test switches: "--boss" on the command line or "?test=boss" in the page address.
func _arg(name: String) -> bool:
	if OS.get_cmdline_user_args().has("--" + name) or OS.get_cmdline_user_args().has("--%stest" % name):
		return true
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		return q is String and (q as String).contains("test=" + name)
	return false


## Live data from Session Scribe: Business staff and prices, and who "You are" is.
func _load_party_data() -> void:
	if not _bridge:
		return
	_cb_staff = JavaScriptBridge.create_callback(func(args: Array):
		var d = JSON.parse_string(str(args[0])) if args.size() > 0 and args[0] != null else null
		if typeof(d) == TYPE_ARRAY:
			inn.apply_staff(d))
	_bridge.readColl("bizstaff", _cb_staff)
	_cb_biz = JavaScriptBridge.create_callback(func(args: Array):
		var d = JSON.parse_string(str(args[0])) if args.size() > 0 and args[0] != null else null
		if typeof(d) == TYPE_ARRAY:
			for doc in d:
				if typeof(doc) == TYPE_DICTIONARY:
					for v in doc.values():
						if typeof(v) == TYPE_STRING and (v as String).contains("--"):
							inn.set_prices(v))
	_bridge.readColl("biz", _cb_biz)


func save_hero() -> void:
	var json := JSON.stringify(hero.to_dict())
	if _bridge:
		_bridge.saveDoc("vd_heroes", hero.id, json, _cb_save)
	elif not bot:
		var f := FileAccess.open("user://hero.json" if hero.key == "boarvhal" else "user://hero_%s.json" % hero.key, FileAccess.WRITE)
		if f:
			f.store_string(json)


func _on_hero_saved(args: Array) -> void:
	if args.size() > 0 and not bool(args[0]):
		toast("Saved in this browser only: the party records could not be reached.")


func _save_run_record(result: String) -> void:
	if not _bridge:
		return
	var rec := {"hero": hero.name, "owner": hero.owner, "level": hero.level, "result": result, "depth": depth,
		"biome": BIOME, "kills": stats.get("kills", 0), "gold": run_gold, "nat20s": stats.get("nat20s", 0),
		"time": Time.get_unix_time_from_system()}
	_bridge.saveDoc("vd_runs", "%s_%d" % [hero.id, Time.get_unix_time_from_system()], JSON.stringify(rec), _cb_save)


# ---------------- tavern ----------------

func _tavern_options() -> Array:
	return [
		["Descend into the %s" % BIOME, "start"],
		["Hero: %s  - press to change" % hero.short(), "hero"],
		["Difficulty: %s (%s)%s" % [Creatures.TIERS[hero.tier].name, Creatures.TIERS[hero.tier].levels, "  - press to change" if hero.tier_unlocked > 1 else "  - clear it to unlock Tier II"], "tier"],
		["Buy a Potion of Healing (%d gp)" % POTION_PRICE, "potion"],
		["Back to the taproom", "back"],
		["Try the top-down inn and test dungeon (prototype)", "topdown"],
		["Return to Session Scribe", "leave"],
	]


func _open_tavern() -> void:
	_enter_inn(false)


func _refresh_tavern() -> void:
	var opts: Array = _tavern_options()
	var next := hero.next_level_xp()
	var w: Dictionary = hero.combat_stats().weapon
	var wtxt := "%s +%d (%dd%d%s)" % [w.name, w.attack, w.count, w.sides, ("%+d" % w.bonus) if int(w.bonus) != 0 else " " + str(w.type)]
	var sheet := "%s, level %d %s\nHP %d   AC %d   %s\nXP %d%s   Gold %d   Potions %d\nRuns %d   Boss kills %d   Deaths %d   Goblins slain %d" % [
		hero.name, hero.level, hero.title, hero.max_hp(), hero.ac(), wtxt,
		hero.xp, (" / %d" % next) if next > 0 else " (max level)", hero.gold, hero.potions,
		hero.runs, hero.clears, hero.deaths, hero.kills]
	if not party.is_empty():
		sheet += "\nParty: %s   (gold split %d ways)" % [", ".join(party.map(func(k): return Kits.info(k).short)), party_size()]
	var who := ("Playing as %s. " % hero.owner) if hero.owner != "" else ""
	if _switching:
		who = "Fetching %s's records... " % hero.short()
	var saves := "Progress saves to your party's records." if save_mode == "shared" else "Progress saves in this browser. Open Session Scribe and enter the campaign passphrase to share it with the party."
	hud.show_tavern(sheet, opts.map(func(o): return o[0]), _menu_pick, who + saves)
	hud.set_tavern_title("THE CELLAR STAIR", "A SINKHOLE HAS OPENED UNDER THE GRYPHON'S ROOST. GOBLINS ARE CLIMBING OUT OF THE DARK.")


func _tavern_input() -> void:
	var opts: Array = _tavern_options()
	var hov := under_mouse(hud.tavern_lines)
	if hov >= 0 and hov < opts.size() and hov != _menu_pick and mouse_moved():
		_menu_pick = hov
		sfx.play("step", -10.0)
		_refresh_tavern()
	var click_pick := clicked() and hov >= 0 and hov < opts.size()
	if click_pick:
		_menu_pick = hov
	if ui_back():
		hud.hide_tavern()
		phase = Phase.TAVERN
		player.global_position.x = Inn.CELLAR_X - 40.0
		player.reset_physics_interpolation()
		return
	if Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("move_right"):
		_menu_pick = (_menu_pick + 1) % opts.size()
		sfx.play("step", -8.0)
		_refresh_tavern()
	elif Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_left"):
		_menu_pick = (_menu_pick - 1 + opts.size()) % opts.size()
		sfx.play("step", -8.0)
		_refresh_tavern()
	elif ui_confirm() or click_pick:
		if _switching:
			return
		match opts[_menu_pick][1]:
			"start":
				_start_run()
			"hero":
				save_hero()
				var i := Kits.ORDER.find(hero.key)
				_load_hero_key(Kits.ORDER[(i + 1) % Kits.ORDER.size()])
				sfx.play("step", -6.0)
				_refresh_tavern()
			"tier":
				if hero.tier_unlocked > 1:
					hero.tier = hero.tier % hero.tier_unlocked + 1
					save_hero()
					sfx.play("step", -6.0)
				else:
					toast("Defeat the Bugbear Chief to unlock Tier II.")
				_refresh_tavern()
			"back":
				hud.hide_tavern()
				phase = Phase.TAVERN
				player.global_position.x = Inn.CELLAR_X - 40.0
				player.facing = -1
				player.reset_physics_interpolation()
			"topdown":
				save_hero()
				if OS.has_feature("web"):
					JavaScriptBridge.eval("window.location.search = '?test=topdown&hero=%s'" % hero.key)
			"leave":
				_leave_to_site()
			"potion":
				if hero.gold >= POTION_PRICE:
					hero.gold -= POTION_PRICE
					hero.potions += 1
					save_hero()
					sfx.play("die", -6.0)
					toast("Bought a Potion of Healing.")
				else:
					toast("Not enough gold. Potions cost %d gp." % POTION_PRICE)
				_refresh_tavern()


# ---------------- runs ----------------

func _start_run() -> void:
	hud.hide_tavern()
	hud.hide_center()
	hero.runs += 1
	stats = {"swings": 0, "rolls": 0, "hits": 0, "crits": 0, "fumbles": 0, "glances": 0, "self": 0, "taken": 0, "kills": 0, "nat20s": 0, "xp": 0}
	run_gold = 0
	run_potions = hero.potions
	hit_dice = hero.level
	depth = 0
	_used_rooms.clear()
	_campfire_taken = false
	player.apply_hero(hero)
	player.hp = player.max_hp
	player.rage_uses = player.stats.rage_uses
	player.used_second_wind = false
	player.kit.long_rest()
	player.hp_changed.emit()
	hud.set_hero_hints(hero.key)
	_clear_companions()
	party.erase(hero.key)
	for i in party.size():
		var c := Companion.make(self, party[i], hero.level, i)
		add_child(c)
		companions.append(c)
	if not party.is_empty():
		log_line("The party: %s and %s. Gold is split %d ways." % [hero.short(), ", ".join(party.map(func(k): return Kits.info(k).short)), party_size()])
	log_line("Delve %d begins with %s." % [hero.runs, hero.short()])
	_enter_room("combat")


func _enter_room(kind: String) -> void:
	depth += 1
	room_type = kind
	music.play("boss" if kind == "boss" else "delve", 1.0 if kind == "boss" else 2.0)
	var file := ""
	if kind == "boss":
		file = "warren_boss"
	else:
		var pool: Array = ROOM_POOL[kind].filter(func(f): return not _used_rooms.has(f))
		if pool.is_empty():
			pool = ROOM_POOL[kind]
		file = pool[dice.die(pool.size()) - 1]
		_used_rooms.append(file)
	if kind == "campfire":
		_campfire_taken = true
	_load_room(file)
	player.global_position = room.player_spawn
	player.velocity = Vector2.ZERO
	for c in companions:
		if is_instance_valid(c):
			c.arrive(player.global_position, player.facing)
	if is_instance_valid(player.echo):
		player.echo.queue_free()
	_snap_view()
	phase = Phase.RUN
	var label := "%s  %s  ROOM %d / %d  %s" % [BIOME.to_upper(), Creatures.TIERS[hero.tier].name.to_upper(), mini(depth, ROOMS_BEFORE_BOSS + 1), ROOMS_BEFORE_BOSS + 1, ROOM_LABEL[kind]]
	hud.set_room(label)
	hud.banner(ROOM_LABEL[kind], Color(1, 0.88, 0.55))
	log_line("Room %d: %s." % [depth, ROOM_LABEL[kind].capitalize()])
	if kind == "boss":
		phase = Phase.BATTLE
		get_tree().create_timer(1.0).timeout.connect(func(): battle.start(self))


func _load_room(file: String, quiet := false) -> void:
	if room and room != inn.room:
		room.queue_free()
	room = null
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	for p in props:
		if is_instance_valid(p):
			p.queue_free()
	props.clear()
	for c in get_children():
		if c is Projectile:
			c.queue_free()
	if file == "":
		return
	if inn.is_inside_tree():
		remove_child(inn)
	hud.set_inn_mode(false)
	room = Room.new()
	add_child(room)
	move_child(room, 0)
	room.build(FileAccess.get_file_as_string("res://rooms/%s.txt" % file))
	_set_camera_limits()
	if quiet:
		return
	for s in room.spawns:
		var key: String = s[0]
		if key == "B":
			continue
		spawn_monster(key, s[1])
	for c in room.chests:
		var ch := Chest.new()
		ch.game = self
		ch.position = c
		add_child(ch)
		props.append(ch)
	for f in room.fires:
		var cf := Campfire.new()
		cf.game = self
		cf.position = f
		add_child(cf)
		props.append(cf)
	for d in room.darts:
		var dt := DartTrap.new()
		dt.game = self
		dt.position = d[0]
		dt.dir = d[1]
		add_child(dt)
		props.append(dt)


func _set_camera_limits() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(room.size_px().x)
	camera.limit_bottom = int(room.size_px().y)
	if inn and room == inn.room and player:
		# In the inn the camera shows either the inn or the private room you are in.
		var v := Inn.view_limits(player.global_position)
		camera.limit_left = int(v.position.x)
		camera.limit_right = int(v.end.x)
		camera.limit_bottom = int(v.end.y)


## Through a door in the inn: hallway to private room, or back out.
func _use_inn_door(d: Dictionary) -> void:
	_close_talk()
	sfx.play("chop", -10.0)
	player.global_position = d.to
	player.velocity = Vector2.ZERO
	_set_camera_limits()
	_snap_view()


## Back in the Gryphon's Roost: at the front door on first arrival, at the cellar door after a delve.
func _enter_inn(at_cellar := false) -> void:
	music.play("tavern", 2.0)
	_clear_companions()
	_load_room("", true)
	if not inn.is_inside_tree():
		add_child(inn)
		move_child(inn, 0)
	room = inn.room
	_set_camera_limits()
	phase = Phase.TAVERN
	hud.hide_tavern()
	hud.hide_doors()
	hud.set_inn_mode(true)
	hud.set_room("THE GRYPHON'S ROOST INN - WATERDEEP")
	player.global_position = Vector2(Inn.CELLAR_X - 40.0, Inn.FLOOR_Y) if at_cellar else inn.room_spawn(hero.key)
	_set_camera_limits()
	player.facing = -1 if at_cellar else 1
	player.velocity = Vector2.ZERO
	_snap_view()


func _open_card() -> void:
	phase = Phase.CARD
	player.velocity = Vector2.ZERO
	_menu_pick = 0
	_refresh_tavern()


func spawn_monster(key: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup(self, Creatures.scaled(Creatures.monster(key), hero.tier))
	e.position = pos
	e.facing = -1 if pos.x > player.global_position.x else 1
	e._cd = 0.6 + randf() * 0.6
	add_child(e)
	enemies.append(e)
	return e


func _spawn_player() -> void:
	player = Player.new()
	player.game = self
	player.hero = hero
	player.stats = hero.combat_stats()
	player.position = room.player_spawn
	add_child(player)
	player.died.connect(_on_player_died)
	player.downed.connect(func(): hud.death_saves(true, player.death_saves); hud.banner("DOWN!", Color(1, 0.4, 0.35)))
	camera.global_position = player.global_position


func room_cleared() -> bool:
	if room_type in ["combat", "elite"]:
		return living_enemies().is_empty()
	return true


func try_interact() -> void:
	if phase == Phase.TAVERN:
		if _confirm_exit:
			_leave_to_site()
			return
		if _confirm_join:
			_answer_join(true)
			return
		if inn.at_exit(player.global_position):
			_ask_exit()
			return
		var door := inn.door_at(player.global_position)
		if not door.is_empty():
			_use_inn_door(door)
			return
		var n := inn.nearest(player.global_position)
		if n:
			_talk(n)
		return
	for p in props:
		if is_instance_valid(p) and p.has_method("interact") and p.global_position.distance_to(player.global_position) < 24.0:
			p.interact(player)
			return


func _check_exit() -> void:
	if room.exit_pos.x < 0.0:
		return
	var near := absf(player.global_position.x - room.exit_pos.x) < 10.0 and absf(player.global_position.y - room.exit_pos.y) < 20.0
	if not near:
		return
	if not room_cleared():
		toast("The door is barred. Clear the room first.")
		return
	_offer_doors()


func _offer_doors() -> void:
	phase = Phase.DOORS
	player.velocity = Vector2.ZERO
	if depth >= ROOMS_BEFORE_BOSS:
		_door_options = ["boss"]
	else:
		var weights := {"combat": 4, "gauntlet": 2, "treasure": 2, "elite": 1}
		if depth >= 2 and not _campfire_taken:
			weights["campfire"] = 3
		var a := _weighted(weights)
		var b := a
		var guard := 0
		while b == a and guard < 20:
			b = _weighted(weights)
			guard += 1
		if depth == 3 and not _campfire_taken and a != "campfire" and b != "campfire":
			b = "campfire"
		_door_options = [a, b]
	_door_pick = 0
	_show_doors()


func _weighted(w: Dictionary) -> String:
	var total := 0
	for k in w:
		total += w[k]
	var r := dice.die(total)
	for k in w:
		r -= w[k]
		if r <= 0:
			return k
	return w.keys()[0]


func _show_doors() -> void:
	var labels: Array = _door_options.map(func(k): return ROOM_LABEL[k])
	var hints: Array = _door_options.map(func(k): return ROOM_HINT[k])
	hud.show_doors(labels, hints, _door_pick)


func _doors_input() -> void:
	var hov := under_mouse(hud.door_boxes)
	if hov >= 0 and hov < _door_options.size() and hov != _door_pick and mouse_moved():
		_door_pick = hov
		sfx.play("step", -10.0)
		_show_doors()
	var click_pick := clicked() and hov >= 0 and hov < _door_options.size()
	if click_pick:
		_door_pick = hov
	if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
		_door_pick = (_door_pick + 1) % _door_options.size()
		sfx.play("step", -8.0)
		_show_doors()
	elif ui_confirm() or click_pick:
		hud.hide_doors()
		sfx.play("chop", -8.0)
		_enter_room(_door_options[_door_pick])


func living_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead():
			out.append(e)
	return out


func on_enemy_killed(e: Enemy) -> void:
	stats.kills = stats.get("kills", 0) + 1
	hero.kills += 1
	log_line("%s is slain. +%d XP." % [e.data.name, e.data.xp])
	sfx.play("thud", -6.0)
	gain_xp(int(e.data.xp))
	if room_cleared() and phase == Phase.RUN and room_type in ["combat", "elite"]:
		room.open_exit()
		toast("The way on is open.")


func gain_xp(amount: int) -> void:
	stats.xp = stats.get("xp", 0) + amount
	var before := hero.level
	var gained := hero.add_xp(amount)
	if gained > 0:
		hit_dice += gained
		player.apply_hero(hero)
		player.hp = mini(player.max_hp, player.hp + 10 * gained)
		player.rage_uses = mini(player.stats.rage_uses, player.rage_uses + (1 if hero.level >= 3 and before < 3 else 0))
		player.hp_changed.emit()
		banner("LEVEL %d!" % hero.level, Color(1.0, 0.85, 0.3))
		sfx.play("crit", -4.0)
		for lv in range(before + 1, hero.level + 1):
			log_line("Level %d: %s" % [lv, hero.level_features(lv)])
		hud.level_note(hero.level_features(hero.level))
		save_hero()


func note_swing(_connected: bool) -> void:
	stats.swings = stats.get("swings", 0) + 1


# ---------------- frame ----------------

func _process(delta: float) -> void:
	var mpos := get_viewport().get_mouse_position()
	_mouse_moved = mpos.distance_to(_last_mouse) > 0.5
	_last_mouse = mpos
	# Right-click in a room commands Boar-vhal's echo to that spot.
	if phase == Phase.RUN and right_clicked() and is_instance_valid(player.echo):
		player.command_echo(get_global_mouse_position())
	if Input.is_action_just_pressed("back") and not get_tree().paused and _loaded:
		if phase == Phase.TAVERN and _confirm_join:
			_answer_join(false)
			_close_talk()
		elif phase == Phase.TAVERN and _talking:
			_close_talk()
		elif (phase == Phase.TAVERN and not _confirm_exit) or phase == Phase.RUN or (phase == Phase.BATTLE and int(battle.mode) == 1):
			pause_menu.open()
			return
	if bot:
		_bot(delta)
	match phase:
		Phase.TAVERN:
			if (_confirm_join or _confirm_exit) and clicked():
				var yn := under_mouse([hud.dlg_yes, hud.dlg_no])
				if yn == 0:
					if _confirm_join:
						_answer_join(true)
					else:
						_leave_to_site()
				elif yn == 1:
					if _confirm_join:
						_answer_join(false)
						_close_talk()
					else:
						_cancel_exit()
			elif _talking and clicked() and under_mouse([hud.dlg_panel]) == 0:
				_talk(_talking)
			if _confirm_join and Input.is_action_just_pressed("confirm"):
				_answer_join(true)
			if _confirm_exit:
				if Input.is_action_just_pressed("confirm"):
					_leave_to_site()
				elif Input.is_action_just_pressed("back") or not inn.at_exit(player.global_position):
					_cancel_exit()
			if inn.dm:
				inn.dm.set_marker(_loaded and not hero.quest_given)
			_barred_t = maxf(0.0, _barred_t - delta)
			if _loaded and not hero.quest_given and player.global_position.x > Inn.CELLAR_X - 30.0 and player.global_position.x < 1024.0 and absf(player.global_position.y - Inn.FLOOR_Y) < 4.0:
				# The way down stays shut until the stranger has had his word.
				player.global_position.x = Inn.CELLAR_X - 30.0
				player.velocity.x = minf(player.velocity.x, 0.0)
				if _barred_t <= 0.0:
					toast("THE CELLAR DOOR IS BARRED. THE HOODED STRANGER WANTS A WORD FIRST.")
					if bot: print("[bot] cellar barred at x %d" % player.global_position.x)
					_barred_t = 3.0
			elif _loaded and not _switching and inn.at_cellar(player.global_position):
				_close_talk()
				_open_card()
			_update_talk()
		Phase.CARD:
			_tavern_input()
		Phase.DOORS:
			_doors_input()
		Phase.RUN:
			_check_exit()
		Phase.OVER:
			if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("attack"):
				hud.hide_center()
				_reset_after_run()
	if Input.is_action_just_pressed("music"):
		toast("MUSIC OFF" if music.toggle_mute() else "MUSIC ON")
	if Input.is_action_just_pressed("toggle_log"):
		hud.toggle_log()
	if Input.is_action_just_pressed("test_down") and phase == Phase.RUN:
		player.force_down()
	hud.refresh(player, stats, self)
	hud.prompt(_current_prompt())
	_layout_name_tags()


func _physics_process(_delta: float) -> void:
	if phase != Phase.BATTLE and player:
		camera.global_position = player.global_position + Vector2(player.facing * 24.0, -20.0)


## After moving the hero instantly (new room, new run), stop the camera gliding across.
func _snap_view() -> void:
	player.reset_physics_interpolation()
	camera.global_position = player.global_position + Vector2(player.facing * 24.0, -20.0)
	camera.reset_smoothing()
	camera.reset_physics_interpolation()


## Talking in the inn: E shows the next line from the nearest person; walking away closes it.
func _talk(n: InnNPC) -> void:
	if n == inn.dm and _loaded and not hero.quest_given:
		_talking = n
		n.face_toward(player.global_position.x)
		_quest_i += 1
		hud.show_dialogue(n.display_name, Inn.QUEST_LINES[_quest_i])
		sfx.play("step", -8.0)
		if _quest_i >= Inn.QUEST_LINES.size() - 1:
			hero.quest_given = true
			_quest_i = -1
			n.set_marker(false)
			save_hero()
			toast("QUEST ACCEPTED: CLEAR THE CELLAR")
			sfx.play("crit", -6.0)
		return
	if _member_key(n) != "" and _loaded:
		_ask_join(n)
		return
	if n != _talking:
		n.line_i = n.line_i % maxi(1, n.lines.size())
	_talking = n
	n.face_toward(player.global_position.x)
	hud.show_dialogue(n.display_name, n.next_line())
	sfx.play("step", -8.0)


func _update_talk() -> void:
	if _talking and (not is_instance_valid(_talking) or absf(_talking.global_position.x - player.global_position.x) > 40.0 or absf(_talking.global_position.y - player.global_position.y) > 30.0):
		_close_talk()


func _close_talk() -> void:
	if _confirm_join:
		_confirm_join = null
	if _quest_i >= 0:
		_quest_i = -1   # walked off mid-briefing: he starts again next time
	_talking = null
	hud.hide_dialogue()


func peaceful() -> bool:
	return phase == Phase.TAVERN


# ---------------- the party ----------------

func party_size() -> int:
	return 1 + party.size()


## Gold found on a delve is split evenly; the hero banks their share.
func add_gold(total: int) -> int:
	var share := maxi(1, floori(total / float(party_size())))
	run_gold += share
	return share


## Goblins go for whoever is nearest and still standing.
func enemy_target(from: Node2D) -> Node2D:
	var best: Node2D = player
	var bd := INF if player.is_down() else from.global_position.distance_to(player.global_position)
	for c in companions:
		if is_instance_valid(c) and not c.down:
			var d := from.global_position.distance_to(c.global_position)
			if d < bd:
				bd = d
				best = c
	return best


func _member_key(n: InnNPC) -> String:
	var k := n.key.trim_prefix("npc_")
	return k if Kits.has(k) and k != hero.key else ""


func _ask_join(n: InnNPC) -> void:
	_talking = n
	_confirm_join = n
	n.face_toward(player.global_position.x)
	var k := _member_key(n)
	var line := n.next_line()
	if party.has(k):
		hud.show_confirm(n.display_name, "\"%s\"  Leave %s at the inn this time?" % [line, n.display_name])
	elif party.size() >= MAX_COMPANIONS:
		_confirm_join = null
		hud.show_dialogue(n.display_name, line + "  (The whole party is already going.)")
	else:
		var n2 := party_size() + 1
		hud.show_confirm(n.display_name, "\"%s\"  Invite %s on the delve? Gold will be split %d ways." % [line, n.display_name, n2])
	sfx.play("step", -8.0)


func _answer_join(yes: bool) -> void:
	var n := _confirm_join
	_confirm_join = null
	hud.hide_dialogue()
	if not yes or not is_instance_valid(n):
		return
	var k := _member_key(n)
	if party.has(k):
		party.erase(k)
		inn.return_home(n.key)
		toast("%s stays at the inn." % n.display_name)
	else:
		party.append(k)
		inn.send_to_cellar(n.key, party.size() - 1)
		toast("%s joins the delve! Gold is split %d ways." % [n.display_name, party_size()])
	for i in party.size():
		inn.send_to_cellar("npc_" + party[i], i)


func _clear_companions() -> void:
	for c in companions:
		if is_instance_valid(c):
			c.queue_free()
	companions.clear()


func _ask_exit() -> void:
	_close_talk()
	_confirm_exit = true
	player.velocity.x = 0.0
	hud.show_confirm("Exit", "Leave the Gryphon's Roost and return to Session Scribe? Your hero is saved.")


func _cancel_exit() -> void:
	if _confirm_exit:
		_confirm_exit = false
		hud.hide_dialogue()


func _leave_to_site() -> void:
	_confirm_exit = false
	hud.hide_dialogue()
	save_hero()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.href = 'https://session-scribe.com/'")
	else:
		toast("Session Scribe opens here in the web version.")


func _current_prompt() -> String:
	if phase == Phase.TAVERN:
		if _confirm_exit:
			return ""
		if inn.at_exit(player.global_position):
			return "E: EXIT TO SESSION SCRIBE"
		var door := inn.door_at(player.global_position)
		if not door.is_empty():
			return "E: " + str(door.label)
		var n := inn.nearest(player.global_position)
		return ("E: TALK TO %s" % n.display_name.to_upper()) if n else ""
	if phase != Phase.RUN:
		return ""
	for p in props:
		if is_instance_valid(p) and p.has_method("prompt") and p.global_position.distance_to(player.global_position) < 24.0:
			return p.prompt()
	return ""


func _reset_after_run() -> void:
	player.set_physics_process(true)
	player.revive_full()
	_enter_inn(true)


## Stack monster name tags on extra rows when neighbours' names would overlap.
func _layout_name_tags() -> void:
	var es := living_enemies()
	es.sort_custom(func(a, b): return a.global_position.x < b.global_position.x)
	var row_end: Array[float] = []
	for e in es:
		var w: float = e.bar.call("label_width") + 4.0
		var left := e.global_position.x - w / 2.0
		var row := 0
		while row < row_end.size() and row_end[row] > left:
			row += 1
		if row == row_end.size():
			row_end.append(0.0)
		row_end[row] = e.global_position.x + w / 2.0
		var view_c := camera.get_screen_center_position().x
		var lo := maxf(0.0, view_c - 240.0) + w / 2.0 + 2.0
		var hi := minf(room.size_px().x, view_c + 240.0) - w / 2.0 - 2.0
		var cx := e.global_position.x
		e.bar.position.x = clampf(cx, lo, maxf(lo, hi)) - cx
		e.bar.position.y = -22.0 - 9.0 * row - (22.0 if e.data.name == "Bugbear Chief" else 0.0)


# ---------------- run end ----------------

func end_run(result: String) -> void:
	if phase == Phase.OVER:
		return
	phase = Phase.OVER
	music.stop(3.0)
	hud.death_saves(false, player.death_saves)
	hero.best_depth = maxi(hero.best_depth, depth)
	var body := ""
	if result == "cleared":
		hero.clears += 1
		if hero.tier == hero.tier_unlocked and hero.tier_unlocked < 3:
			hero.tier_unlocked += 1
			toast("%s unlocked at the tavern." % Creatures.TIERS[hero.tier_unlocked].name)
		hero.gold += run_gold
		hero.potions = run_potions
		body = "The Bugbear Chief is dead and the Goblin Warren is broken.\n\nYou bank %d gp and carry %d potion%s home." % [run_gold, run_potions, "" if run_potions == 1 else "s"]
	else:
		hero.deaths += 1
		hero.potions = mini(hero.potions, run_potions)
		body = "%s\n\nThe party carries %s back to the tavern. Gold found this run is lost (%d gp). XP is kept." % [result, hero.short(), run_gold]
	var rolls: int = stats.get("rolls", 0)
	var pct := 0 if rolls == 0 else roundi(100.0 * stats.hits / rolls)
	body += "\n\nRooms: %d   Goblins slain: %d   XP earned: %d\nAttack rolls %d, hits %d (%d%%), glancing %d, crits %d, natural 1s %d" % [
		depth, stats.get("kills", 0), stats.get("xp", 0), rolls, stats.hits, pct, stats.glances, stats.crits, stats.fumbles]
	save_hero()
	_save_run_record(result if result == "cleared" else "died")
	get_tree().create_timer(1.0).timeout.connect(func():
		hud.show_center("VICTORY" if result == "cleared" else "RUN OVER", body + "\n\nPress Enter, Start or attack to return to the tavern."))


func _on_player_died(reason: String) -> void:
	end_run(reason)


func on_battle_end(victory: bool) -> void:
	if victory:
		var hoard := roundi((40 + dice.roll(4, 6).reduce(func(a, b): return a + b, 0) * 5) * float(Creatures.TIERS[hero.tier].gold))
		var share := add_gold(hoard)
		if party_size() > 1:
			log_line("The chief's hoard: %d gp, split %d ways (%d each)." % [hoard, party_size(), share])
		end_run("cleared")


# ---------------- presentation ----------------

func show_attack(attacker: Node2D, target: Node2D, weapon: String, atk: Dictionary, dmg: Dictionary,
		reasons: Array, glancing: bool) -> void:
	# Floating text shows only damage and misses. The full roll goes to the roll log.
	var by_player := attacker == player
	var verdict := "HIT" if atk.hit else "MISS"
	if atk.crit:
		verdict = "CRIT"
	elif atk.fumble:
		verdict = "NAT 1"
	elif glancing:
		verdict = "GLANCE"
	var dice_txt := str(atk.rolls[0]) if atk.rolls.size() == 1 else "%d|%d" % [atk.rolls[0], atk.rolls[1]]
	var mode_txt := ""
	if atk.mode == Dice.Mode.ADVANTAGE:
		mode_txt = "ADV"
	elif atk.mode == Dice.Mode.DISADVANTAGE:
		mode_txt = "DIS"
	sfx.play("die", -12.0, 0.15)

	var who_a: String = hero.short() if by_player else attacker.data.name
	var who_t: String = target.data.name if by_player else hero.short()
	var line := ""
	if by_player:
		line = "%s %s vs %s: d20 %s +%d = %d, %s" % [who_a, weapon, who_t, dice_txt, atk.bonus, atk.total, verdict]
	else:
		line = "%s %s vs %s: d20 %s +%d = %d vs AC %d, %s" % [who_a, weapon, who_t, dice_txt, atk.bonus, atk.total, atk.ac, verdict]
	if mode_txt != "":
		line += " (%s: %s)" % [mode_txt, ", ".join(reasons)]
	if by_player:
		stats.rolls += 1
		if atk.hit:
			stats.hits += 1
		if atk.crit:
			stats.crits += 1
		if atk.fumble:
			stats.fumbles += 1
		if glancing:
			stats.glances += 1

	if not dmg.is_empty():
		var faces := ",".join(dmg.faces.map(func(v): return str(v)))
		line += ", %d damage (%dd%d[%s]%+d%s)" % [dmg.total, dmg.faces.size(), dmg.sides, faces, dmg.bonus, " halved" if dmg.resisted else ""]
		var col := Color(1, 1, 1)
		if by_player:
			if atk.crit:
				col = Color(1.0, 0.85, 0.25)
			elif glancing:
				col = Color(0.78, 0.76, 0.66)
		else:
			col = Color(1.0, 0.38, 0.32)
		FloatText.fling(self, target.global_position + Vector2(0, -16), _away_dir(target, attacker), str(dmg.total), "", col, 0, 1.1)
		if by_player:
			sfx.play("crit" if atk.crit else ("hit_light" if glancing else "hit"), -4.0 if atk.crit else -3.0)
			if not glancing:
				hitstop(0.09 if atk.crit else 0.05)
		else:
			stats.taken += dmg.total
	else:
		FloatText.fling(self, target.global_position + Vector2(0, -24), _roll_dir(), "MISS", "", Color(0.72, 0.74, 0.8), 0, 0.9)
		if by_player:
			sfx.play("deflect", -5.0)
	log_line(line + ".")


var _pop_n := 0


## Attack rolls rise from the target's head, leaning alternately left and right.
func _roll_dir() -> Vector2:
	_pop_n += 1
	return Vector2(-0.8 if _pop_n % 2 == 0 else 0.8, -1.0)


## Damage flies away from whoever dealt it, at a varied angle so numbers fan out.
func _away_dir(target: Node2D, source: Node2D) -> Vector2:
	_pop_n += 1
	var side := signf(target.global_position.x - source.global_position.x)
	if side == 0.0:
		side = 1.0
	var lift: float = [-0.35, -0.9, -0.6][_pop_n % 3]
	return Vector2(side * 1.4, lift)


func show_fumble(p: Node2D, dmg: Dictionary, what := "greataxe swing") -> void:
	stats.self += dmg.total
	var t := get_tree().create_timer(0.25)
	t.timeout.connect(func():
		FloatText.fling(self, p.global_position + Vector2(0, -14), Vector2(-p.facing * 1.4, -0.7), str(dmg.total), "", Color(1, 0.4, 0.3), 0, 1.1))
	log_line("Natural 1: the %s goes wrong. %s takes %d (1d4)." % [str(what).to_lower(), hero.short(), dmg.total])


func show_save(target: Node2D, label: String, sv: Dictionary, total: int, dmg: Dictionary) -> void:
	FloatText.fling(self, target.global_position + Vector2(0, -16), Vector2(0, -1), str(total), "", Color(1.0, 0.38, 0.32), 0, 1.1)
	log_line("Spike pit: %s d20 %d %+d = %d vs DC %d, %s. %d piercing%s." % [label, sv.kept, sv.bonus, sv.total, sv.dc,
		"half damage" if sv.success else "full damage", total, " (Rage halves it)" if dmg.resisted else ""])


func show_death_save(r: Dictionary, outcome: String) -> void:
	sfx.play("die", -4.0)
	hud.death_saves(true, player.death_saves, r)
	var words := {"revive": "natural 20, revive", "success": "success", "fail": "failure", "fail2": "natural 1, two failures"}
	log_line("Death save: d20 %d, %s (%d successes, %d failures)." % [r.roll, words[r.effect], player.death_saves.successes, player.death_saves.failures])


func death_saves_changed() -> void:
	hud.death_saves(player.is_down(), player.death_saves)


func log_line(text: String) -> void:
	if hud:
		hud.add_log(text)
	print(text)


func banner(text: String, color: Color) -> void:
	hud.banner(text, color)


func toast(text: String) -> void:
	hud.toast(text)


func hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


# ---------------- test bot ----------------

func _bot_battle() -> void:
	if int(_bot_t * 6) % 2 == 1:
		return
	var b = battle
	match b.mode:
		1:  # MENU
			if _arg("echobattle") and not has_meta("eb"):
				set_meta("eb", true)
				var hc0: Dictionary = b._hero()
				b._choose(["", "echo", true])
				print("[eb] echo at col %d (hero %d)" % [b.echo_col, hc0.col])
				await b._move_echo(clampi(hc0.col - 6, b.min_col, b.max_col) if b.echo_col > hc0.col else clampi(hc0.col + 6, b.min_col, b.max_col))
				print("[eb] moved echo to col %d, %d ft of echo movement left" % [b.echo_col, b.echo_move * 5])
				var far: int = b.min_col if hc0.col - b.min_col > b.max_col - hc0.col else b.max_col
				b.echo_move = 99
				await b._move_echo(far)
				print("[eb] pushed echo to col %d (%d squares away); ending turn" % [b.echo_col, absi(b.echo_col - hc0.col)])
				b._choose(["", "end", true])
				print("[eb] after end of turn: echo col %d" % b.echo_col)
				return
			var want := "end"
			var adjacent: bool = absi(b._hero().col - b._boss_c().get("col", -99)) <= 1
			var prefs := ["heal", "hands", "rage", "reckless", "summon", "spirit", "bless", "smite", "aura", "entangle", "moonbeam", "bear",
				"missile", "ray", "foresight", "attack", "move"]
			if player.hp > player.max_hp / 2:
				prefs.erase("heal")
				prefs.erase("hands")
			if b.conc == "moonbeam":
				prefs.erase("moonbeam")
			if b.conc == "entangle" or player.kit.form != "":
				prefs.erase("entangle")
			if player.kit.smite_on:
				prefs.erase("smite")
			if player.kit.foresight_armed >= 0:
				prefs.erase("foresight")
			for id in prefs:
				if id == "move" and adjacent:
					continue
				for i in b.menu_items.size():
					if b.menu_items[i][1] == id and b.menu_items[i][2]:
						if id == "reckless" and b.reckless_on:
							continue
						want = id
						break
				if want != "end":
					break
			for i in b.menu_items.size():
				if b.menu_items[i][1] == want:
					b.menu_pick = i
			Input.action_press("confirm")
		2:  # MOVE
			var hc: Dictionary = b._hero()
			if _arg("oatest") and not has_meta("oa_done"):
				# Opportunity-attack test: put the chief next to the hero, then walk away through an ally.
				set_meta("oa_done", true)
				var bc0: Dictionary = b._boss_c()
				bc0.col = hc.col + 1
				bc0.node.global_position.x = bc0.col * 16 + 8
				print("[oa] hero col %d, chief col %d, moving to %d" % [hc.col, bc0.col, hc.col - 3])
				b._do_move(hc.col - 3)
				return
			var bc: Dictionary = b._boss_c()
			var dir := 1 if bc.get("col", hc.col + 1) > hc.col else -1
			var target: int = hc.col
			for i in range(1, b.h_move + 1):
				var nc: int = hc.col + dir * i
				if bc.has("col") and (nc - bc.col) * dir >= 0:
					break
				if not b._occupied(nc, hc):
					target = nc
			if target == hc.col:
				b._choose(["End turn", "end", true])
				return
			b.cursor_col = target
			Input.action_press("confirm")
		3:  # TARGET
			Input.action_press("confirm")


func _bot(delta: float) -> void:
	_bot_t += delta
	_stat_t += delta
	if _stat_t > 3.0 and phase == Phase.BATTLE:
		_stat_t = 0.0
		print("[battle] music %s mode %s turn %d round %d hp %d" % [music.current, battle.mode, battle.turn_index, battle.round_no, player.hp])
	if _stat_t > 3.0:
		_stat_t = 0.0
		print("[bot] exit %s music %s phase %s depth %d room %s lvl %d xp %d hp %d/%d enemies %d p=%s" % [str(room.exit_pos), music.current, Phase.keys()[phase], depth, room_type, hero.level, hero.xp, player.hp, player.max_hp, living_enemies().size(), str(player.global_position.round())])
	for a in ["move_left", "move_right", "attack", "dodge", "rage", "confirm", "interact", "potion", "form"]:
		Input.action_release(a)
	if player.velocity.y >= 0.0 or phase != Phase.RUN:
		Input.action_release("jump")
	match phase:
		Phase.CARD, Phase.DOORS, Phase.OVER:
			if int(_bot_t * 4) % 2 == 0:
				Input.action_press("confirm")
			return
		Phase.TAVERN:
			if Inn.chamber_at(player.global_position) >= 0:
				var dr := inn.door_at(player.global_position)
				if not dr.is_empty():
					if int(_bot_t * 4) % 2 == 0:
						Input.action_press("interact")
				else:
					Input.action_press("move_left")
				return
			if player.global_position.y < 100.0 or (player.global_position.y < 204.0 and player.global_position.x > 770.0):
				Input.action_press("move_right")   # upstairs: head for the stairs down
				return
			if not hero.quest_given and inn.dm and not OS.get_cmdline_user_args().has("--rush"):
				var dx := inn.dm.global_position.x - player.global_position.x
				if absf(dx) > 14.0:
					Input.action_press("move_right" if dx > 0 else "move_left")
				elif int(_bot_t * 4) % 2 == 0:
					Input.action_press("interact")
				return
			Input.action_press("move_right")
			return
		Phase.BATTLE:
			_bot_battle()
			return
	if player.is_down():
		return
	if _arg("echotest") and phase == Phase.RUN and is_instance_valid(player.echo) and not has_meta("echo_sent"):
		set_meta("echo_sent", true)
		print("[echo] sending the echo 220 px away at t=%.1f" % _bot_t)
		player.command_echo(player.global_position + Vector2(220, -60))
		get_tree().create_timer(1.0).timeout.connect(func(): print("[echo] after 1s: valid=%s dist=%.0f" % [is_instance_valid(player.echo), player.echo.global_position.distance_to(player.global_position) if is_instance_valid(player.echo) else -1.0]))
		get_tree().create_timer(4.5).timeout.connect(func(): print("[echo] after 4.5s: valid=%s" % is_instance_valid(player.echo)))
	if _arg("abtest") and phase == Phase.RUN:
		# Ability test: press L, R, U, Y in turn near the first goblins.
		var acts := ["rage", "reckless", "echo", "form"]
		var i := int(_bot_t / 1.5) % 4
		if fmod(_bot_t, 1.5) < 0.05:
			player.hp = mini(player.hp, player.max_hp - 5)
			Input.action_press(acts[i])
	if player.hp < player.max_hp / 3 and run_potions > 0:
		Input.action_press("potion")
	var es := living_enemies()
	var tx := room.exit_pos.x
	var e: Enemy = null
	if not es.is_empty():
		es.sort_custom(func(a, b): return absf(a.global_position.x - player.global_position.x) < absf(b.global_position.x - player.global_position.x))
		e = es[0]
		tx = e.global_position.x
	for p in props:
		if is_instance_valid(p) and p.has_method("prompt") and p.prompt() != "":
			tx = p.global_position.x
			if absf(tx - player.global_position.x) < 12.0:
				Input.action_press("interact")
			break
	var dx := tx - player.global_position.x
	var kind := str(player.current_weapon().get("kind", "melee"))
	var reach := 20.0 if kind == "melee" else (60.0 if kind == "whip" else 170.0)
	if e and absf(dx) < reach and absf(e.global_position.y - player.global_position.y) < 20.0:
		player.facing = 1 if dx > 0 else -1
		if int(_bot_t * 10) % 4 == 0:
			Input.action_press("attack")
		if hero.key != "boarvhal" and int(_bot_t * 2) % 9 == 0:
			Input.action_press(["rage", "reckless", "echo", "form"][int(_bot_t) % 4])
	else:
		Input.action_press("move_right" if dx > 0 else "move_left")
		var ahead := player.global_position + Vector2(signf(dx) * 20.0, 4.0)
		var blocked := absf(player.velocity.x) < 5.0
		if blocked or not room.is_ground_at(ahead) or (e and e.global_position.y < player.global_position.y - 20.0 and absf(dx) < 40.0):
			Input.action_press("jump")
	if player.rage_uses > 0 and not player.raging() and e and absf(dx) < 60.0 and room_type in ["elite", "combat"]:
		Input.action_press("rage")
	Input.action_release("echo")
	Input.action_release("reckless")
	if e and absf(dx) < 40.0 and hero.has_echo() and int(_bot_t * 3) % 7 == 0:
		Input.action_press("echo")
	if hero.has_reckless() and not player.reckless and int(_bot_t) % 9 == 0:
		Input.action_press("reckless")
