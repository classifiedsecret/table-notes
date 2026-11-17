extends Node2D
## M1 feel prototype: Boar-vhal against waves of goblins in one test room.

enum Phase { TITLE, PLAY, OVER }

static var skip_title := false

var dice: Dice
var sfx: Sfx
var room: Room
var player: Player
var camera: Camera2D
var hud: Hud
var phase := Phase.TITLE
var wave := 0
var enemies: Array[Enemy] = []
var stats := {"swings": 0, "rolls": 0, "hits": 0, "crits": 0, "fumbles": 0, "glances": 0, "self": 0, "taken": 0, "kills": 0}
var _wave_timer := -1.0
var _door_toggle := 0


func _ready() -> void:
	Art.setup_fonts()
	_setup_input()
	var seed_value := randi() % 900000 + 100000
	dice = Dice.new(seed_value)
	RenderingServer.set_default_clear_color(Color(0.05, 0.04, 0.07))

	sfx = Sfx.new()
	add_child(sfx)
	room = Room.new()
	add_child(room)
	room.build(FileAccess.get_file_as_string("res://rooms/test_room.txt"))

	player = Player.new()
	player.game = self
	player.position = room.player_spawn
	add_child(player)
	player.died.connect(_on_player_died)
	player.downed.connect(func(): hud.death_saves(true, player.death_saves); hud.banner("DOWN!", Color(1, 0.4, 0.35)))

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(room.size_px().x)
	camera.limit_bottom = int(room.size_px().y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)
	camera.global_position = player.global_position

	hud = Hud.new()
	add_child(hud)
	hud.build(self)
	log_line("Seed %d. Boar-vhal: AC 14, 15 HP, Greataxe +5 (1d12+3)." % seed_value)

	if _test("crowd") or _test("ds"):
		phase = Phase.PLAY
		hud.hide_center()
		player.global_position = Vector2(300, 208)
		if _test("crowd"):
			player.max_hp = 999
			player.hp = 999
			for i in 4:
				var e := Enemy.new()
				e.setup(self, Creatures.monster("minion" if i % 2 else "warrior"))
				e.position = room.doors[0] + Vector2(i * 2, 0)
				e.facing = 1
				add_child(e)
				enemies.append(e)
		var tm := Timer.new()
		tm.wait_time = 0.5
		tm.autostart = true
		tm.timeout.connect(func():
			var xs: Array = living_enemies().map(func(x): return roundi(x.global_position.x))
			xs.sort()
			print("[t] enemies x=%s  player hp=%d state=%s  ds_panel=%s" % [str(xs), player.hp, Player.State.keys()[player.state], hud.ds_panel.visible]))
		add_child(tm)
		if _test("ds"):
			player.force_down()
		return
	if _test("pit"):
		phase = Phase.PLAY
		hud.hide_center()
		player.global_position = Vector2(24 * 16 + 24, 150)
		var tm := Timer.new()
		tm.wait_time = 0.25
		tm.autostart = true
		tm.timeout.connect(func(): print("[pit] p=%s hp=%d state=%s" % [str(player.global_position.round()), player.hp, Player.State.keys()[player.state]]))
		add_child(tm)
		return
	if skip_title:
		_start()
	else:
		hud.show_center("VANGUARD'S DESCENT", "Milestone 1 feel test.\n" +
			"Each swing that connects rolls d20 + 5 against the goblin's hidden Armor Class. Goblins roll against your AC 14.\n" +
			"Advantage: strike from behind (dodge through a goblin as it winds up) or while dropping onto it.\n" +
			"Table rules: a roll under the AC still lands a glancing blow for 1d4. A natural 1 misses and you take 1d4.\n" +
			"Keys: A/D move, Space jump, J attack, K dodge, L Rage, Tab log.  Pad: A jump, X attack, B dodge, Y Rage.\n" +
			"Press attack or jump to begin.",
			"Art: 0x72 Dungeon Tileset II (CC0). Fonts and sounds: Kenney (CC0). Includes material from SRD 5.1 and 5.2 by Wizards of the Coast LLC, CC-BY-4.0.")


## Test modes: "--crowdtest" on the command line, or "?test=crowd" in the page address.
func _test(name: String) -> bool:
	if OS.get_cmdline_user_args().has("--%stest" % name):
		return true
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		return q is String and (q as String).contains("test=" + name)
	return false


func _setup_input() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_down": [KEY_S, KEY_DOWN],
		"jump": [KEY_SPACE, KEY_W, KEY_UP], "attack": [KEY_J, KEY_Z], "dodge": [KEY_K, KEY_SHIFT, KEY_C],
		"rage": [KEY_L, KEY_Q], "toggle_log": [KEY_TAB, KEY_I], "confirm": [KEY_ENTER, KEY_KP_ENTER],
		"test_down": [KEY_F2, KEY_2],
	}
	var pads := {"jump": [JOY_BUTTON_A], "attack": [JOY_BUTTON_X], "dodge": [JOY_BUTTON_B, JOY_BUTTON_RIGHT_SHOULDER],
		"rage": [JOY_BUTTON_Y], "toggle_log": [JOY_BUTTON_BACK], "confirm": [JOY_BUTTON_START],
		"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT], "move_down": [JOY_BUTTON_DPAD_DOWN]}
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
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action: String in axes:
		var m := InputEventJoypadMotion.new()
		m.axis = axes[action][0]
		m.axis_value = axes[action][1]
		InputMap.action_add_event(action, m)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", click)


func accepting_input() -> bool:
	return phase == Phase.PLAY


func _start() -> void:
	phase = Phase.PLAY
	hud.hide_center()
	_wave_timer = 1.0


var bot := OS.get_cmdline_user_args().has("--bot")
var _bot_t := 0.0
var _stat_t := 0.0


func _bot(delta: float) -> void:
	_bot_t += delta
	for a in ["move_left", "move_right", "attack", "dodge", "jump", "rage"]:
		Input.action_release(a)
	if phase == Phase.TITLE:
		Input.action_press("attack")
		return
	var es := living_enemies()
	if es.is_empty() or player.is_down():
		return
	var e: Enemy = es[0]
	var dx := e.global_position.x - player.global_position.x
	if absf(dx) > 18.0:
		Input.action_press("move_right" if dx > 0 else "move_left")
		if absf(player.velocity.x) < 5.0 or int(_bot_t * 2) % 5 == 0:
			Input.action_press("jump")
	elif e.global_position.y < player.global_position.y - 20.0 and player.is_on_floor():
		Input.action_press("jump")
	elif int(_bot_t * 10) % 4 == 0:
		Input.action_press("attack")
	if e.state == Enemy.State.WINDUP and randf() < 0.05:
		Input.action_press("dodge")
	if wave == 2 and player.rage_uses == 2:
		Input.action_press("rage")


func _process(delta: float) -> void:
	if bot:
		_bot(delta)
		_stat_t += delta
		if _stat_t > 3.0:
			_stat_t = 0.0
			print("[bot] wave %d hp %d p=%s e=%s stats %s" % [wave, player.hp, str(player.global_position.round()), str(living_enemies().map(func(x): return [x.data.name.substr(7), x.global_position.round(), Enemy.State.keys()[x.state]])), str(stats)])
	match phase:
		Phase.TITLE:
			if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("confirm"):
				_start()
		Phase.OVER:
			if Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("attack"):
				skip_title = true
				get_tree().reload_current_scene()
				return
	if Input.is_action_just_pressed("toggle_log"):
		hud.toggle_log()
	if Input.is_action_just_pressed("test_down") and phase == Phase.PLAY:
		player.force_down()

	if phase == Phase.PLAY and _wave_timer > 0.0:
		_wave_timer -= delta
		if _wave_timer <= 0.0:
			_spawn_wave()

	camera.global_position = player.global_position + Vector2(player.facing * 24.0, -20.0)
	hud.refresh(player, stats, wave, living_enemies().size())
	_layout_name_tags()


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
		e.bar.position.y = -22.0 - 9.0 * row


func _spawn_wave() -> void:
	wave += 1
	var list: Array = Creatures.WAVES[mini(wave - 1, Creatures.WAVES.size() - 1)].duplicate()
	if wave > Creatures.WAVES.size():
		for i in wave - Creatures.WAVES.size():
			list.append("warrior")
	hud.banner("WAVE %d" % wave, Color(1, 0.88, 0.55))
	for i in list.size():
		var key: String = list[i]
		var e := Enemy.new()
		e.setup(self, Creatures.monster(key))
		var door: Vector2 = room.doors[_door_toggle % room.doors.size()]
		_door_toggle += 1
		e.position = door + Vector2(randf_range(-6, 6), 0)
		e.facing = 1 if door.x < room.size_px().x / 2.0 else -1
		e._cd = 0.15 + i * 0.35
		add_child(e)
		enemies.append(e)


func living_enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for e in enemies:
		if is_instance_valid(e) and not e.is_dead():
			out.append(e)
	return out


func on_enemy_killed(e: Enemy) -> void:
	stats.kills += 1
	log_line("%s is slain." % e.data.name)
	sfx.play("thud", -6.0)
	if living_enemies().is_empty() and phase == Phase.PLAY:
		_wave_timer = 2.5
		toast("Wave cleared. Next wave in a moment.")


func note_swing(connected: bool) -> void:
	stats.swings += 1


# ---------------- presentation of rolls ----------------

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

	var who_a: String = "Boar-vhal" if by_player else attacker.data.name
	var who_t: String = target.data.name if by_player else "Boar-vhal"
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


func show_fumble(p: Node2D, dmg: Dictionary) -> void:
	stats.self += dmg.total
	var t := get_tree().create_timer(0.25)
	t.timeout.connect(func():
		FloatText.fling(self, p.global_position + Vector2(0, -14), Vector2(-p.facing * 1.4, -0.7), str(dmg.total), "", Color(1, 0.4, 0.3), 0, 1.1))
	log_line("Natural 1: the greataxe swing goes wrong. Boar-vhal takes %d (1d4)." % dmg.total)


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


func _on_player_died(reason: String) -> void:
	phase = Phase.OVER
	hud.death_saves(false, player.death_saves)
	var rolls: int = stats.rolls
	var pct := 0 if rolls == 0 else roundi(100.0 * stats.hits / rolls)
	get_tree().create_timer(1.2).timeout.connect(func():
		hud.show_center("RUN OVER", "%s\n\nReached wave %d.  Goblins slain: %d.\nYour attack rolls: %d, hits %d (%d%%), glancing %d, crits %d, natural 1s %d.\nDamage taken: %d (%d from your own fumbles).\n\nPress Enter, Start or attack to try again." % [
			reason, wave, stats.kills, rolls, stats.hits, pct, stats.glances, stats.crits, stats.fumbles, stats.taken + stats.self, stats.self]))
