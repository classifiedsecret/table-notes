extends Node2D
## Turn-based boss encounter on a side-view grid of 5-foot squares (one tile = one square).
## Initiative, action / bonus action / movement, telegraphed boss intents, death saves.

enum Mode { IDLE, MENU, MOVE, TARGET, BUSY }

const T := 16
const REACH_HERO := 1

var game: Node
var active := false
var mode := Mode.IDLE
var floor_y := 208.0
var min_col := 1
var max_col := 30
var combatants: Array = []    # each: {node, name, side, col, init, dex}
var turn_index := 0
var round_no := 1
var boss: Enemy
var boss_intent := "smash"
var boss_fury_used := false

# hero turn state
var h_action := 1
var h_bonus := 1
var h_move := 6
var h_attacks := 0
var h_dodging := false
var h_prone := false
var reckless_on := false
var rage_rounds := 0
var echo_col := -1
var echo_node: Node2D

var menu_items: Array = []    # [label, id, enabled]
var menu_pick := 0
var cursor_col := 0
var target_list: Array = []
var target_pick := 0

var ui: CanvasLayer
var order_label: Label
var menu_label: Label
var menu_panel: Control
var menu_lines: Array[Label] = []
var info_label: Label
var intent_label: Label
var _hint := ""


func start(g: Node) -> void:
	game = g
	active = true
	visible = true
	z_index = 3
	var room: Room = game.room
	max_col = room.w - 2
	floor_y = room.player_spawn.y
	round_no = 1
	boss_fury_used = false
	echo_col = -1
	reckless_on = false
	rage_rounds = 0
	h_prone = false
	h_dodging = false
	_build_ui()

	var p: Player = game.player
	p.set_physics_process(false)
	p.velocity = Vector2.ZERO
	if p.raging():
		rage_rounds = ceili(p.rage_time / 6.0)
	combatants.clear()
	_add(p, p.hero.name.split(" ")[0], "hero", 1)
	for s in room.spawns:
		if s[0] == "B":
			boss = game.spawn_monster("boss", s[1])
	for e: Enemy in game.living_enemies():
		e.set_physics_process(false)
		e.velocity = Vector2.ZERO
		e.facing = -1
		e.visual.scale.x = -1
		e.sprite.play("idle")
		var dex := 2
		_add(e, e.data.display, "foe", dex)
	if boss:
		boss.sprite.offset = Vector2(0, -18)
		boss.weapon_pivot.position = Vector2(8, -14)
		(boss.weapon_pivot.get_child(0) as Sprite2D).texture = Art.region("weapon_big_hammer")

	# Roll initiative.
	var lines: Array[String] = []
	for c in combatants:
		var r: int = game.dice.die(20)
		c.init = r + c.dex
		lines.append("%s %d (%d%+d)" % [c.name, c.init, r, c.dex])
	combatants.sort_custom(func(a, b): return a.init > b.init or (a.init == b.init and a.side == "hero"))
	game.log_line("Initiative: " + ", ".join(lines) + ".")
	game.banner("ROLL INITIATIVE", Color(1, 0.85, 0.4))
	game.sfx.play("die", -2.0)
	_pick_intent()
	turn_index = -1
	await get_tree().create_timer(1.2).timeout
	_next_turn()


func _add(node: Node2D, nm: String, side: String, dex: int) -> void:
	var col := clampi(floori(node.global_position.x / T), min_col, max_col)
	while _occupied(col, null):
		col += 1 if side == "foe" else -1
	var c := {"node": node, "name": nm, "side": side, "col": col, "init": 0, "dex": dex}
	combatants.append(c)
	node.global_position = Vector2(col * T + 8, floor_y)


func _occupied(col: int, except: Variant) -> bool:
	for c in combatants:
		if c != except and c.col == col and _alive(c):
			return true
	return false


func _alive(c: Dictionary) -> bool:
	if c.side == "hero":
		return true
	return is_instance_valid(c.node) and not (c.node as Enemy).is_dead()


func _hero() -> Dictionary:
	for c in combatants:
		if c.side == "hero":
			return c
	return {}


func _boss_c() -> Dictionary:
	for c in combatants:
		if c.node == boss:
			return c
	return {}


# ---------------- turn flow ----------------

func _next_turn() -> void:
	if not active:
		return
	if _check_end():
		return
	turn_index += 1
	if turn_index >= combatants.size():
		turn_index = 0
		round_no += 1
		if rage_rounds > 0:
			rage_rounds -= 1
			if rage_rounds == 0:
				game.player.rage_time = 0.0
				game.log_line("Rage ends.")
	var c: Dictionary = combatants[turn_index]
	if not _alive(c):
		_next_turn()
		return
	_refresh_order()
	if c.side == "hero":
		_hero_turn_start()
	else:
		mode = Mode.BUSY
		await get_tree().create_timer(0.5).timeout
		await _foe_turn(c)
		await get_tree().create_timer(0.35).timeout
		_next_turn()


func _check_end() -> bool:
	if boss == null or not is_instance_valid(boss) or boss.is_dead():
		_finish(true)
		return true
	var p: Player = game.player
	if p.state == Player.State.DEAD:
		_finish(false)
		return true
	return false


func _finish(victory: bool) -> void:
	active = false
	mode = Mode.IDLE
	queue_redraw()
	if is_instance_valid(echo_node):
		echo_node.queue_free()
	if ui:
		ui.queue_free()
		ui = null
	game.hud.hints.visible = true
	if victory:
		for e: Enemy in game.living_enemies():
			var tw := e.create_tween()
			tw.tween_property(e, "modulate:a", 0.0, 0.6)
			tw.tween_callback(e.queue_free)
		game.log_line("The Bugbear Chief falls in round %d. The goblins scatter into the dark. (Boar-vhal at %d HP)" % [round_no, game.player.hp])
		game.banner("VICTORY", Color(1, 0.85, 0.3))
		game.on_battle_end(true)


func _hero_turn_start() -> void:
	var p: Player = game.player
	h_action = 1
	h_bonus = 1
	h_attacks = 0
	h_dodging = false
	h_move = int(p.stats.speed_ft / 5)
	if p.is_down():
		mode = Mode.BUSY
		_info("Boar-vhal is down. Rolling a death saving throw...")
		await get_tree().create_timer(0.7).timeout
		var r := Rules.death_save(game.dice)
		var outcome := p.death_saves.apply(r)
		game.show_death_save(r, outcome)
		if outcome == "revive":
			p._rise("Natural 20! Boar-vhal surges back up with 1 HP.")
		elif outcome == "stable":
			if not p.used_second_wind:
				p.used_second_wind = true
				p._rise("Three successes. Boar-vhal grits his teeth and rises with 1 HP (once per run).")
			else:
				p._die("Stable, but out cold. The party drags Boar-vhal back to the tavern.")
		elif outcome == "dead":
			p._die("Three failures. Boar-vhal has fallen.")
		await get_tree().create_timer(1.0).timeout
		if p.state == Player.State.DEAD:
			_finish(false)
			return
		if p.is_down():
			_next_turn()
			return
		h_prone = true
	if h_prone:
		h_prone = false
		h_move = maxi(0, h_move - h_move / 2)
		game.log_line("Boar-vhal stands up (half his movement).")
	_open_menu()


func _open_menu() -> void:
	mode = Mode.MENU
	var p: Player = game.player
	menu_items.clear()
	var in_reach := _targets_in_reach().size() > 0
	menu_items.append(["Attack with greataxe" + (" (%d left)" % h_attacks if h_attacks > 0 else ""), "attack", (h_action > 0 or h_attacks > 0) and in_reach])
	menu_items.append(["Move (%d ft left)" % (h_move * 5), "move", h_move > 0])
	menu_items.append(["Dash (action: double move)", "dash", h_action > 0 and h_attacks == 0])
	menu_items.append(["Dodge (action)", "dodge", h_action > 0 and h_attacks == 0])
	if p.hero.has_reckless():
		menu_items.append(["Reckless Attack: " + ("ON" if reckless_on else "OFF"), "reckless", true])
	menu_items.append(["Rage (bonus action, %d left)" % p.rage_uses, "rage", h_bonus > 0 and p.rage_uses > 0 and rage_rounds == 0])
	if p.hero.has_echo():
		menu_items.append(["Echo (bonus action)", "echo", h_bonus > 0])
	menu_items.append(["Drink potion (action, %d)" % game.run_potions, "potion", h_action > 0 and game.run_potions > 0 and h_attacks == 0])
	menu_items.append(["End turn", "end", true])
	menu_pick = clampi(menu_pick, 0, menu_items.size() - 1)
	if not menu_items[menu_pick][2]:
		menu_pick = 0
		while menu_pick < menu_items.size() - 1 and not menu_items[menu_pick][2]:
			menu_pick += 1
	_render_menu()
	queue_redraw()


## Selected action in green, actions you can't take this turn greyed out (and skipped by the cursor).
func _render_menu() -> void:
	menu_label.text = ""
	for i in menu_lines.size():
		var l := menu_lines[i]
		if i >= menu_items.size():
			l.visible = false
			continue
		var it: Array = menu_items[i]
		l.visible = true
		var selected := i == menu_pick
		l.text = ("> " if selected else "  ") + str(it[0]).to_upper()
		if not it[2]:
			l.label_settings.font_color = Color(0.42, 0.41, 0.46)
		elif selected:
			l.label_settings.font_color = Color(0.45, 1.0, 0.45)
		else:
			l.label_settings.font_color = Color(0.92, 0.92, 0.9)
	menu_panel.size.y = 10.0 + 12.0 * menu_items.size()
	var res := "ACTION %s   BONUS %s   MOVE %d FT" % ["READY" if h_action > 0 else "USED", "READY" if h_bonus > 0 else "USED", h_move * 5]
	_info(res + "\nUP/DOWN, ATTACK TO CONFIRM, ESC BACK")


## Moves the cursor to the next action that can be taken, wrapping around.
func _step_menu(dir: int) -> void:
	var n := menu_items.size()
	for k in range(1, n + 1):
		var i := (menu_pick + dir * k + n * 2) % n
		if menu_items[i][2]:
			menu_pick = i
			break
	game.sfx.play("step", -10.0)
	_render_menu()


func _process(_delta: float) -> void:
	if not active:
		return
	match mode:
		Mode.MENU:
			if Input.is_action_just_pressed("move_down"):
				_step_menu(1)
			elif Input.is_action_just_pressed("move_up"):
				_step_menu(-1)
			elif _confirm():
				_choose(menu_items[menu_pick])
		Mode.MOVE:
			var hc := _hero()
			if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
				var d := -1 if Input.is_action_just_pressed("move_left") else 1
				var nc: int = cursor_col + d
				if absi(nc - hc.col) <= h_move and nc >= min_col and nc <= max_col:
					cursor_col = nc
				queue_redraw()
			elif _confirm():
				_do_move(cursor_col)
			elif Input.is_action_just_pressed("back") or Input.is_action_just_pressed("dodge"):
				_open_menu()
		Mode.TARGET:
			if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
				target_pick = (target_pick + 1) % target_list.size()
				queue_redraw()
			elif _confirm():
				_do_attack(target_list[target_pick])
			elif Input.is_action_just_pressed("back") or Input.is_action_just_pressed("dodge"):
				_open_menu()
	_camera()


func _confirm() -> bool:
	return Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("confirm") or Input.is_action_just_pressed("interact")


func _camera() -> void:
	var hc := _hero()
	var bc := _boss_c()
	var x: float = hc.col * T if bc.is_empty() else (hc.col + bc.col) * T / 2.0
	game.camera.global_position = Vector2(x, floor_y - 60.0)


func _choose(item: Array) -> void:
	if not item[2]:
		game.sfx.play("deflect", -12.0)
		return
	var p: Player = game.player
	match item[1]:
		"attack":
			target_list = _targets_in_reach()
			target_pick = 0
			mode = Mode.TARGET
			_info("LEFT/RIGHT: CHOOSE TARGET   ATTACK: SWING   ESC: BACK")
			queue_redraw()
		"move":
			cursor_col = _hero().col
			mode = Mode.MOVE
			_info("LEFT/RIGHT: CHOOSE A SQUARE   ATTACK: MOVE THERE   ESC: BACK")
			queue_redraw()
		"dash":
			h_action = 0
			h_move += int(p.stats.speed_ft / 5)
			game.log_line("Action: Dash.")
			_open_menu()
		"dodge":
			h_action = 0
			h_dodging = true
			game.log_line("Action: Dodge. Attacks against Boar-vhal have disadvantage until his next turn.")
			_open_menu()
		"reckless":
			reckless_on = not reckless_on
			game.log_line("Reckless Attack %s." % ("on: advantage on your attacks, enemies have advantage against you" if reckless_on else "off"))
			_open_menu()
		"rage":
			h_bonus = 0
			p.rage_uses -= 1
			rage_rounds = 10
			p.rage_time = 60.0
			game.banner("RAGE!", Color(1, 0.45, 0.35))
			game.log_line("Bonus action: Rage (%d left)." % p.rage_uses)
			_open_menu()
		"echo":
			h_bonus = 0
			_place_echo()
			_open_menu()
		"potion":
			h_action = 0
			game.run_potions -= 1
			var faces: Array[int] = game.dice.roll(2, 4)
			var heal: int = faces[0] + faces[1] + 2
			p.hp = mini(p.max_hp, p.hp + heal)
			p.hp_changed.emit()
			game.toast("Potion of Healing: +%d HP" % heal)
			game.log_line("Action: Potion of Healing, 2d4 %s +2 = %d." % [str(faces), heal])
			_open_menu()
		"end":
			mode = Mode.BUSY
			menu_label.text = ""
			for l in menu_lines:
				l.visible = false
			_next_turn()


func _targets_in_reach() -> Array:
	var hc := _hero()
	var out := []
	for c in combatants:
		if c.side == "foe" and _alive(c) and absi(c.col - hc.col) <= REACH_HERO:
			out.append(c)
	return out


func _do_move(col: int) -> void:
	var hc := _hero()
	if col == hc.col:
		_open_menu()
		return
	if _occupied(col, hc):
		game.toast("That square is taken.")
		return
	# Can't pass through enemies.
	var step := 1 if col > hc.col else -1
	var x: int = hc.col + step
	while x != col + step:
		if _occupied(x, hc):
			game.toast("A foe blocks the way.")
			return
		x += step
	var dist := absi(col - hc.col)
	h_move -= dist
	mode = Mode.BUSY
	var p: Player = game.player
	p.facing = step
	p.visual.scale.x = step
	p.sprite.play("run")
	var tw := create_tween()
	tw.tween_property(p, "global_position:x", col * T + 8.0, 0.09 * dist)
	await tw.finished
	p.sprite.play("idle")
	hc.col = col
	_face_nearest(p, hc)
	_open_menu()


func _face_nearest(node: Node2D, me: Dictionary) -> void:
	var best := 999
	var dir := 1
	for c in combatants:
		if c.side != me.side and _alive(c) and absi(c.col - me.col) < best:
			best = absi(c.col - me.col)
			dir = 1 if c.col >= me.col else -1
	if node is Player:
		(node as Player).facing = dir
		(node as Player).visual.scale.x = dir
	elif node is Enemy:
		(node as Enemy).facing = dir
		(node as Enemy).visual.scale.x = dir


func _do_attack(t: Dictionary) -> void:
	mode = Mode.BUSY
	var p: Player = game.player
	var hc := _hero()
	if h_attacks == 0:
		h_action = 0
		h_attacks = 2 if p.hero.has_extra_attack() else 1
	h_attacks -= 1
	var e: Enemy = t.node
	_face_nearest(p, hc)
	p.facing = 1 if t.col > hc.col else -1
	p.visual.scale.x = p.facing
	var tw := create_tween()
	tw.tween_property(p.weapon_pivot, "rotation", -2.3, 0.12)
	tw.tween_property(p.weapon_pivot, "rotation", 1.95, 0.08)
	tw.tween_property(p.weapon_pivot, "rotation", -0.55, 0.25)
	game.sfx.play("swing", -4.0)
	await get_tree().create_timer(0.2).timeout
	var adv := 0
	var reasons: Array[String] = []
	if reckless_on:
		adv += 1
		reasons.append("reckless")
	if echo_col >= 0 and absi(echo_col - t.col) <= 1:
		adv += 1
		reasons.append("flanked by your echo")
	var atk := Rules.attack(game.dice, p.stats.weapon.attack, e.ac, Dice.combine(adv, 0))
	var glancing: bool = not atk.hit and not atk.fumble
	var dmg := {}
	if atk.hit:
		dmg = Rules.damage(game.dice, 1, 12, int(p.stats.weapon.bonus) + (2 if rage_rounds > 0 else 0), atk.crit)
	elif glancing:
		dmg = Rules.damage(game.dice, 1, 4, 0)
	game.show_attack(p, e, "Greataxe", atk, dmg, reasons, glancing)
	if not dmg.is_empty():
		e.hp = maxi(0, e.hp - int(dmg.total))
		e._flash = 1.0
		e._show_bar = 99.0
		if e.hp <= 0:
			e._die(p.facing)
			if e == boss:
				await get_tree().create_timer(0.8).timeout
				_check_end()
				return
		elif e == boss and not boss_fury_used and e.hp <= e.max_hp / 2:
			boss_fury_used = true
			boss_intent = "fury"
			game.log_line("The Bugbear Chief roars, bloodied and furious.")
			game.banner("THE CHIEF IS ENRAGED", Color(1, 0.5, 0.35))
			_show_intent()
	elif atk.fumble:
		var f := Rules.damage(game.dice, 1, 4, 0)
		game.show_fumble(p, f)
		p.hp = maxi(0, p.hp - int(f.total))
		p.hp_changed.emit()
		if p.hp <= 0:
			p._go_down()
	await get_tree().create_timer(0.45).timeout
	if p.is_down():
		mode = Mode.BUSY
		_next_turn()
		return
	_open_menu()


func _place_echo() -> void:
	var hc := _hero()
	var bc := _boss_c()
	var want := -1
	if not bc.is_empty():
		var beyond: int = bc.col + (1 if bc.col > hc.col else -1)
		if beyond >= min_col and beyond <= max_col and not _occupied(beyond, null) and absi(beyond - hc.col) <= 6:
			want = beyond
	if want < 0:
		for d in [1, -1]:
			if not _occupied(hc.col + d, null):
				want = hc.col + d
				break
	if want < 0:
		game.toast("No room for an echo.")
		h_bonus = 1
		return
	echo_col = want
	if is_instance_valid(echo_node):
		echo_node.queue_free()
	var p: Player = game.player
	echo_node = Node2D.new()
	var ghost := AnimatedSprite2D.new()
	ghost.sprite_frames = p.sprite.sprite_frames
	ghost.offset = p.sprite.offset
	ghost.play("idle")
	ghost.modulate = Color(0.55, 0.75, 1.0, 0.55)
	echo_node.add_child(ghost)
	echo_node.global_position = Vector2(echo_col * T + 8, floor_y)
	game.add_child(echo_node)
	game.log_line("Bonus action: Echo appears %s the chief. Foes next to it are flanked." % ("behind" if want == bc.get("col", -99) + (1 if bc.get("col", 0) > hc.col else -1) else "beside"))


# ---------------- foes ----------------

func _pick_intent() -> void:
	if boss_intent == "fury":
		return
	boss_intent = "shove" if round_no % 3 == 2 else "smash"
	_show_intent()


func _show_intent() -> void:
	if not intent_label:
		return
	var txt := {"smash": "CHIEF'S NEXT MOVE: MORNINGSTAR SMASH (REACH 10 FT)",
		"shove": "CHIEF'S NEXT MOVE: SHOVE (STR SAVE OR PUSHED 10 FT AND PRONE)",
		"fury": "CHIEF'S NEXT MOVE: FURY (TWO MORNINGSTAR SWINGS)"}
	intent_label.text = txt.get(boss_intent, "")


func _foe_turn(c: Dictionary) -> void:
	var e: Enemy = c.node
	var hc := _hero()
	var p: Player = game.player
	if p.is_down():
		game.log_line("%s jeers at the fallen Goliath." % c.name)
		return
	var dist := absi(hc.col - c.col)
	if e == boss:
		var reach: int = boss.data.reach
		if dist > reach:
			await _foe_move_toward(c, hc, reach)
			dist = absi(hc.col - c.col)
		if dist <= reach:
			match boss_intent:
				"shove":
					await _boss_shove(c, hc)
				"fury":
					await _foe_attack(c, e.data.weapon)
					if not p.is_down():
						await get_tree().create_timer(0.35).timeout
						await _foe_attack(c, e.data.weapon)
					boss_intent = "smash"
				_:
					await _foe_attack(c, e.data.weapon)
		_pick_intent()
	else:
		# Goblin archer: step away if cornered, then shoot.
		if dist <= 1:
			var away := 1 if c.col >= hc.col else -1
			var target: int = c.col
			for i in 6:
				var nc: int = target + away
				if nc < min_col or nc > max_col or _occupied(nc, c):
					break
				target = nc
			if target != c.col:
				game.log_line("%s disengages (Nimble Escape)." % c.name)
				await _foe_slide(c, target)
		await _foe_shoot(c)


func _foe_move_toward(c: Dictionary, hc: Dictionary, reach: int) -> void:
	var step := 1 if hc.col > c.col else -1
	var target: int = c.col
	for i in 6:
		if absi(hc.col - target) <= reach:
			break
		var nc: int = target + step
		if _occupied(nc, c) or nc < min_col or nc > max_col:
			break
		target = nc
	if target != c.col:
		await _foe_slide(c, target)


func _foe_slide(c: Dictionary, col: int) -> void:
	var e: Enemy = c.node
	var d := absi(col - c.col)
	e.sprite.play("run")
	e.facing = 1 if col > c.col else -1
	e.visual.scale.x = e.facing
	var tw := create_tween()
	tw.tween_property(e, "global_position:x", col * T + 8.0, 0.1 * d)
	await tw.finished
	c.col = col
	e.sprite.play("idle")
	_face_nearest(e, c)


func _foe_attack(c: Dictionary, wpn: Dictionary) -> void:
	var e: Enemy = c.node
	var p: Player = game.player
	_face_nearest(e, c)
	var tw := create_tween()
	tw.tween_property(e.weapon_pivot, "rotation", -2.0, 0.25)
	tw.tween_property(e.weapon_pivot, "rotation", 1.9, 0.08)
	tw.tween_property(e.weapon_pivot, "rotation", 0.5, 0.25)
	await get_tree().create_timer(0.33).timeout
	game.sfx.play("swing", -6.0)
	await _resolve_foe_attack(e, wpn, false)


func _foe_shoot(c: Dictionary) -> void:
	var e: Enemy = c.node
	var p: Player = game.player
	_face_nearest(e, c)
	var arrow := Node2D.new()
	arrow.set_script(preload("res://scripts/game/arrow_fx.gd"))
	arrow.global_position = e.global_position + Vector2(e.facing * 6, -8)
	game.add_child(arrow)
	var tw := create_tween()
	tw.tween_property(arrow, "global_position", p.global_position + Vector2(0, -12), 0.3)
	await tw.finished
	arrow.queue_free()
	var adjacent := absi(_hero().col - c.col) <= 1
	await _resolve_foe_attack(e, e.data.weapon, adjacent)


func _resolve_foe_attack(e: Enemy, wpn: Dictionary, disadvantage: bool) -> void:
	var p: Player = game.player
	var adv := 0
	var dis := 0
	var reasons: Array[String] = []
	if reckless_on:
		adv += 1
		reasons.append("you attacked recklessly")
	if h_prone:
		if wpn.name == "Shortbow":
			dis += 1
			reasons.append("you are prone (ranged)")
		else:
			adv += 1
			reasons.append("you are prone")
	if h_dodging:
		dis += 1
		reasons.append("you are dodging")
	if disadvantage:
		dis += 1
		reasons.append("shooting in melee")
	var atk := Rules.attack(game.dice, wpn.attack, p.ac, Dice.combine(adv, dis))
	var dmg := {}
	if atk.hit:
		var resisted: bool = rage_rounds > 0 and wpn.type in ["bludgeoning", "piercing", "slashing"]
		dmg = Rules.damage(game.dice, wpn.count, wpn.sides, wpn.bonus, atk.crit, resisted)
	game.show_attack(e, p, wpn.name, atk, dmg, reasons, false)
	if atk.hit:
		p.take_damage(int(dmg.total), atk.crit, 0.0)
	else:
		game.sfx.play("deflect", -4.0)
	await get_tree().create_timer(0.4).timeout


func _boss_shove(c: Dictionary, hc: Dictionary) -> void:
	var p: Player = game.player
	var dc: int = boss.data.shove_dc
	var mode_s := Dice.Mode.ADVANTAGE if rage_rounds > 0 else Dice.Mode.NORMAL
	var sv := Rules.save(game.dice, p.hero.str_mod(), dc, mode_s)
	game.sfx.play("thud", -2.0)
	game.log_line("Bugbear Chief shoves: Strength save d20 %s %+d = %d vs DC %d, %s." % [
		("%d|%d" % [sv.rolls[0], sv.rolls[1]]) if sv.rolls.size() > 1 else str(sv.kept), sv.bonus, sv.total, dc, "resisted" if sv.success else "failed"])
	if sv.success:
		FloatText.fling(game, p.global_position + Vector2(0, -24), Vector2(0, -1), "RESISTED", "", Color(0.7, 0.85, 1.0), 0, 1.0)
		return
	var away := 1 if hc.col > c.col else -1
	var target: int = hc.col
	for i in 2:
		var nc: int = target + away
		if nc < min_col or nc > max_col or _occupied(nc, hc):
			break
		target = nc
	var tw := create_tween()
	tw.tween_property(p, "global_position:x", target * T + 8.0, 0.18)
	await tw.finished
	hc.col = target
	h_prone = true
	p.sprite.play("hit")
	FloatText.fling(game, p.global_position + Vector2(0, -24), Vector2(0, -1), "PRONE", "", Color(1.0, 0.6, 0.4), 0, 1.0)
	game.log_line("Boar-vhal is knocked prone (melee attacks against him have advantage until he stands).")


# ---------------- presentation ----------------

func _build_ui() -> void:
	if ui:
		ui.queue_free()
	ui = CanvasLayer.new()
	ui.layer = 11
	add_child(ui)
	var top := _panel(Vector2(166, 4), Vector2(116, 52))
	order_label = _label(top, Vector2(5, 3), 8, Color(0.92, 0.9, 0.85))
	menu_panel = _panel(Vector2(4, 72), Vector2(186, 100))
	menu_label = _label(menu_panel, Vector2(6, 4), 8, Color.WHITE)
	menu_lines.clear()
	for i in 12:
		var l := _label(menu_panel, Vector2(6, 4 + i * 12), 8, Color.WHITE)
		l.visible = false
		menu_lines.append(l)
	intent_label = _label(ui, Vector2(196, 60), 8, Color(1, 0.6, 0.45))
	intent_label.size = Vector2(280, 10)
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label = _label(ui, Vector2(196, 110), 8, Color(0.85, 0.88, 0.95))
	info_label.size = Vector2(280, 30)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.hud.hints.visible = false
	_show_intent()


func _panel(pos: Vector2, size: Vector2) -> Control:
	var p := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.09, 0.92)
	sb.border_color = Color(0.45, 0.36, 0.28, 0.9)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = size
	ui.add_child(p)
	return p


func _label(parent: Node, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.label_settings = Art.label_settings(size, color, 2)
	l.position = pos
	parent.add_child(l)
	return l


func _info(t: String) -> void:
	if info_label:
		info_label.text = t.to_upper()


func _refresh_order() -> void:
	var lines: Array[String] = ["ROUND %d  INITIATIVE" % round_no]
	for i in combatants.size():
		var c: Dictionary = combatants[i]
		if not _alive(c):
			continue
		var tag := ""
		if c.side == "foe":
			var e: Enemy = c.node
			tag = "UNHURT" if e.hp == e.max_hp else ("BLOODIED" if e.hp <= e.max_hp / 2 else "HURT")
		else:
			tag = "%d HP" % game.player.hp
		lines.append(("> " if i == turn_index else "  ") + "%s  %s" % [str(c.name).to_upper(), tag])
	order_label.text = "\n".join(lines)
	if combatants[turn_index].side != "hero":
		for l in menu_lines:
			l.visible = false
		menu_panel.size.y = 22.0
		menu_label.text = ("%s'S TURN" % str(combatants[turn_index].name).to_upper())
		_info("")


func _draw() -> void:
	if not active:
		return
	var hc := _hero()
	if hc.is_empty():
		return
	if mode == Mode.MOVE:
		for col in range(hc.col - h_move, hc.col + h_move + 1):
			if col < min_col or col > max_col:
				continue
			var free := not _occupied(col, hc)
			draw_rect(Rect2(col * T + 1, floor_y - 2, T - 2, 3), Color(0.4, 0.8, 1.0, 0.55) if free else Color(1, 0.3, 0.3, 0.4))
		draw_rect(Rect2(cursor_col * T, floor_y - 30, T, 30), Color(0.4, 0.8, 1.0, 0.9), false, 1.0)
	elif mode == Mode.TARGET and not target_list.is_empty():
		var t: Dictionary = target_list[target_pick]
		var h := 40.0 if t.node == boss else 20.0
		draw_rect(Rect2(t.col * T - 2, floor_y - h, T + 4, h), Color(1, 0.4, 0.3, 0.95), false, 1.0)
	if mode != Mode.IDLE:
		draw_rect(Rect2(hc.col * T + 2, floor_y + 1, T - 4, 2), Color(1, 0.9, 0.4, 0.9))
