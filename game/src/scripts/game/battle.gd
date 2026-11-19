extends Node2D
## Turn-based boss encounter on the top-down grid of 5-foot squares (one tile = one square).
## Initiative, action / bonus action / movement, telegraphed boss intents, death saves.

enum Mode { IDLE, MENU, MOVE, TARGET, BUSY, ECHO }

const T := 16
const REACH_HERO := 1
const NO_CELL := Vector2i(-99, -99)
const MENU_TOP := 64.0     # just below the (scaled) hero panel

var game: Node
var active := false
var mode := Mode.IDLE
var floor_y := 208.0
var combatants: Array = []    # each: {node, name, side, col (its square, Vector2i), init, dex}
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
var h_held := false     # Hold Person: lose the next turn
var reckless_on := false
var rage_rounds := 0
var echo_col := NO_CELL
var echo_node: Node2D
const ECHO_RANGE := 6       # 30 feet: how far the echo may move per turn
var echo_leash := 6         # how far it may end from you (60 ft from 10th level)
var echo_move := 0          # squares the echo can still move this turn (free, no action)
var conc := ""            # "entangle" or "moonbeam" while Suilean concentrates
var beam_col := NO_CELL
var sw_rounds := 0        # Spiritual Weapon rounds left
var sw_node: Node2D
var pending := ""
var order_panel: Control
var h_disengaged := false   # Disengage: no opportunity attacks this turn         # an action waiting for a target ("attack", "ray", "spirit", "moonbeam", "entangle")

var menu_items: Array = []    # [label, id, enabled]
var menu_pick := 0
var cursor_col := Vector2i.ZERO
var _move_opts := {}      # square -> previous square, for the hero's move
var _echo_opts := {}
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
	var room: World = game.room
	z_index = 45   # the move and target markers show above the warren's darkness
	round_no = 1
	echo_leash = 12 if game.hero.level >= 10 else 6
	boss_fury_used = false
	echo_col = NO_CELL
	reckless_on = false
	rage_rounds = 0
	conc = ""
	beam_col = NO_CELL
	sw_rounds = 0
	pending = ""
	h_prone = false
	h_held = false
	h_dodging = false
	_build_ui()

	var p: Player = game.player
	p.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	game.camera.process_callback = Camera2D.CAMERA2D_PROCESS_IDLE
	p.set_physics_process(false)
	p.velocity = Vector2.ZERO
	if p.raging():
		rage_rounds = ceili(p.rage_time / 6.0)
	combatants.clear()
	_add(p, p.short_name(), "hero", 1 if p.hero.key != "ceridwen" and p.hero.key != "suilean" else 2)
	for comp in game.companions:
		if is_instance_valid(comp) and not comp.down:
			comp.velocity = Vector2.ZERO
			_add(comp, comp.short_name(), "ally", 1)
			comp.reset_physics_interpolation()
	p.kit.end_zone(p.kit.concentration)
	if is_instance_valid(p.kit.spirit):
		sw_rounds = 10
		p.kit.end_zone(p.kit.spirit)
		_make_spirit_node()
	for s in room.spawns:
		if s[0] == "B" or s[0] == "F":
			boss = game.spawn_monster(s[0], s[1])
	for e: Enemy in game.living_enemies():
		e.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		e.set_physics_process(false)
		e.velocity = Vector2.ZERO
		e.look = (p.global_position - e.global_position).normalized()
		e.facing = 1 if e.look.x >= 0.0 else -1
		e.visual.scale.x = e.facing
		e.sprite.play("idle")
		var dex := 2
		_add(e, e.data.display, "foe", dex)
	if boss and boss.data.name == "Bugbear Chief":
		boss.sprite.offset = Vector2(0, -18)
		boss.weapon_pivot.position = Vector2(0, -14)
		(boss.weapon_pivot.get_child(0) as Sprite2D).texture = Art.region("weapon_big_hammer")

	# Roll initiative.
	var lines: Array[String] = []
	for c in combatants:
		var r: int = game.dice.die(20)
		if c.side == "hero" and game.player.stats.get("feral", false):
			r = maxi(r, game.dice.die(20))   # Feral Instinct: advantage on initiative
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
	var cell := _free_cell_near(game.room.to_cell(node.global_position + Vector2(0, -3)))
	var c := {"node": node, "name": nm, "side": side, "col": cell, "init": 0, "dex": dex, "restrained": false, "frightened": false, "reaction": true}
	combatants.append(c)
	node.global_position = _pos(cell)


## Squares are 5 feet; diagonals count as 5 feet too (the 2024 rules).
static func _d(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## Where someone stands in a square (feet near the bottom middle).
func _pos(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * T + 8.0, cell.y * T + 13.0)


func _walkable(cell: Vector2i) -> bool:
	var r: World = game.room
	return r.astar.is_in_boundsv(cell) and not r.astar.is_point_solid(cell)


func _free_cell_near(cell: Vector2i) -> Vector2i:
	if _walkable(cell) and not _occupied(cell, null):
		return cell
	for rad in range(1, 6):
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				var cc := cell + Vector2i(dx, dy)
				if _d(cc, cell) == rad and _walkable(cc) and not _occupied(cc, null):
					return cc
	return cell






## Every square reachable within `steps` squares of movement (walls and furniture block;
## people can be passed through). Returns {cell: previous cell} for walking the path back.
func _reach_map(from: Vector2i, steps: int) -> Dictionary:
	var prev := {from: from}
	var dist := {from: 0}
	var todo: Array[Vector2i] = [from]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_front()
		if dist[c] >= steps:
			continue
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var n := c + Vector2i(dx, dy)
				if dist.has(n) or not _walkable(n):
					continue
				# No cutting a corner past a wall.
				if dx != 0 and dy != 0 and (not _walkable(c + Vector2i(dx, 0)) or not _walkable(c + Vector2i(0, dy))):
					continue
				dist[n] = dist[c] + 1
				prev[n] = c
				todo.append(n)
	return prev


func _path(prev: Dictionary, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var c := to
	while prev.has(c) and prev[c] != c:
		out.push_front(c)
		c = prev[c]
	return out


func _mouse_cell() -> Vector2i:
	return game.room.to_cell(get_global_mouse_position() + Vector2(0, 4))


## WASD / arrows nudge a square cursor (diagonals with two keys).
func _key_step() -> Vector2i:
	var d := Vector2i.ZERO
	if Input.is_action_just_pressed("move_left"): d.x -= 1
	if Input.is_action_just_pressed("move_right"): d.x += 1
	if Input.is_action_just_pressed("move_up"): d.y -= 1
	if Input.is_action_just_pressed("move_down"): d.y += 1
	return d



func _occupied(col: Vector2i, except: Variant) -> bool:
	for c in combatants:
		if c != except and c.col == col and _alive(c):
			return true
	return false


func _alive(c: Dictionary) -> bool:
	if c.side == "hero":
		return true
	if c.side == "ally":
		return is_instance_valid(c.node) and not (c.node as Companion).down
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
	elif c.side == "ally":
		mode = Mode.BUSY
		await get_tree().create_timer(0.4).timeout
		await _ally_turn(c)
		await get_tree().create_timer(0.3).timeout
		_next_turn()
	else:
		mode = Mode.BUSY
		c.reaction = true
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
	if is_instance_valid(sw_node):
		sw_node.queue_free()
	if ui:
		ui.queue_free()
		ui = null
	game.hud.hints.visible = true
	game.hud.room_label.visible = true
	var hp_node: Player = game.player
	hp_node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	hp_node.reset_physics_interpolation()
	game.camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	game.camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	game.camera.reset_physics_interpolation()
	if victory:
		for e: Enemy in game.living_enemies():
			var tw := e.create_tween()
			tw.tween_property(e, "modulate:a", 0.0, 0.6)
			tw.tween_callback(e.queue_free)
		var line: String = boss.data.get("defeat_line", "The boss falls in round %d.") if boss else "The fight is won in round %d."
		game.log_line((line % round_no) + " (%s at %d HP)" % [game.player.short_name(), game.player.hp])
		game.banner("VICTORY", Color(1, 0.85, 0.3))
		game.on_battle_end(true)


func _hero_turn_start() -> void:
	var p: Player = game.player
	h_action = 1
	h_bonus = 1
	h_attacks = 0
	h_dodging = false
	h_disengaged = false
	echo_move = ECHO_RANGE
	h_move = int(p.form_data.get("speed_ft", p.stats.speed_ft)) / 5
	if sw_rounds > 0:
		sw_rounds -= 1
		if sw_rounds == 0:
			game.log_line("The spectral mace fades.")
			if is_instance_valid(sw_node):
				sw_node.queue_free()
	if p.is_down():
		mode = Mode.BUSY
		_info("Down! Rolling a death save...")
		await get_tree().create_timer(0.7).timeout
		var r := Rules.death_save(game.dice)
		var outcome := p.death_saves.apply(r)
		game.show_death_save(r, outcome)
		p.resolve_death_save(outcome)
		await get_tree().create_timer(1.0).timeout
		if p.state == Player.State.DEAD:
			_finish(false)
			return
		if p.is_down():
			_next_turn()
			return
		h_prone = true
	if h_held:
		h_held = false
		game.log_line("%s is held fast by the spell and loses the turn, then breaks free." % p.short_name())
		_info("HELD! You can't move or act this turn.")
		mode = Mode.BUSY
		await get_tree().create_timer(1.2).timeout
		_next_turn()
		return
	if h_prone:
		h_prone = false
		h_move = maxi(0, h_move - h_move / 2)
		game.log_line("%s stands up (half %s movement)." % [p.short_name(), p.hero.pronoun("his")])
	_open_menu()


func _weapon() -> Dictionary:
	return game.player.current_weapon()


## How far the current attack reaches, in 5-foot squares.
func _reach_cols(wpn: Dictionary) -> int:
	match str(wpn.get("kind", "melee")):
		"bolt": return 24
		"whip": return 6
	return REACH_HERO


func _open_menu() -> void:
	if not active:
		return
	mode = Mode.MENU
	pending = ""
	var p: Player = game.player
	var k: HeroKit = p.kit
	var key: String = p.hero.key
	var wpn := _weapon()
	menu_items.clear()
	var in_reach := _targets_in_reach(_reach_cols(wpn)).size() > 0
	var can_act := h_action > 0 and h_attacks == 0
	var spell_ok := k.form == ""
	menu_items.append(["%s" % wpn.name + (" (%d left)" % h_attacks if h_attacks > 0 else ""), "attack", (h_action > 0 or h_attacks > 0) and in_reach])
	menu_items.append(["Move (%d ft left)" % (h_move * 5), "move", h_move > 0])
	match key:
		"ceridwen":
			menu_items.append(["Magic Missile (%d slots)" % (k.slots[0] + k.slots[1]), "missile", can_act and k.slots[0] + k.slots[1] > 0])
			if k.s.abilities.get("R", "") == "fireball":
				menu_items.append(["Fireball (%d 3rd+ slots)" % k.slots[1], "fireball", can_act and k.slots[1] > 0])
			elif k.s.abilities.has("R"):
				menu_items.append(["Scorching Ray (%d 2nd)" % k.slots[1], "ray", can_act and k.slots[1] > 0])
			if not k.foresight.is_empty():
				menu_items.append(["Foresight: " + ("ready %d" % k.foresight[k.foresight_armed] if k.foresight_armed >= 0 else "%s" % " / ".join(k.foresight.map(func(v): return str(v)))), "foresight", true])
		"erwar":
			menu_items.append(["Healing Word (bonus)", "heal", h_bonus > 0 and k.slots[0] + k.slots[1] > 0 and p.hp < p.max_hp])
			if k.s.abilities.get("R", "") == "spirit_guardians":
				menu_items.append(["Spirit Guardians: ACTIVE" if conc == "guardians" else "Spirit Guardians (3rd+ slot)", "guardians", can_act and conc != "guardians" and k.slots[1] > 0])
			elif k.s.abilities.has("R"):
				if sw_rounds > 0:
					menu_items.append(["Spectral mace attack (bonus)", "spirit", h_bonus > 0 and _targets_in_reach(5).size() > 0])
				else:
					menu_items.append(["Spiritual Weapon (bonus)", "summon", h_bonus > 0 and k.slots[1] > 0])
			if int(k.s.channel) > 0:
				menu_items.append(["War Blessing: " + ("READY" if k.blessing_armed else "%d left" % k.channel), "bless", not k.blessing_armed and k.channel > 0])
		"lyburnum":
			menu_items.append(["Lay on Hands (%d HP pool)" % k.lay_pool, "hands", can_act and k.lay_pool > 0 and p.hp < p.max_hp])
			if k.s.abilities.has("R"):
				menu_items.append(["Divine Smite: " + ("ON" if k.smite_on else "OFF"), "smite", k.smite_on or k.slots[0] + k.slots[1] > 0])
			if k.s.abilities.has("U"):
				menu_items.append(["Dread Aura (%d left)" % k.channel, "aura", can_act and k.channel > 0])
		"suilean":
			if spell_ok:
				menu_items.append(["Entangle (slot)", "entangle", can_act and k.slots[0] + k.slots[1] > 0])
				if k.s.abilities.has("R"):
					menu_items.append(["Moonbeam: move it" if conc == "moonbeam" else "Moonbeam (2nd slot)", "moonbeam", can_act and (conc == "moonbeam" or k.slots[1] > 0)])
			if k.s.abilities.has("U"):
				if k.form == "":
					menu_items.append(["Wild Shape: Bear (%d)" % k.wild_uses, "bear", can_act and k.wild_uses > 0])
					menu_items.append(["Wild Shape: Spider (%d)" % k.wild_uses, "spider", can_act and k.wild_uses > 0])
				else:
					menu_items.append(["Return to elf form (bonus)", "revert", h_bonus > 0])
		_:
			if p.hero.has_reckless():
				menu_items.append(["Reckless Attack: " + ("ON" if reckless_on else "OFF"), "reckless", true])
			menu_items.append(["Rage (bonus action, %d left)" % p.rage_uses, "rage", h_bonus > 0 and p.rage_uses > 0 and rage_rounds == 0])
			if p.hero.has_echo():
				menu_items.append(["Echo (bonus action)" if echo_col == NO_CELL else "New echo (bonus action)", "echo", h_bonus > 0])
				if echo_col != NO_CELL:
					menu_items.append(["Move echo (%d ft, free)" % (echo_move * 5), "echomove", echo_move > 0])
					menu_items.append(["Swap with echo (15 ft of move)", "echoswap", h_move >= 3 and not _occupied(echo_col, _hero())])
	menu_items.append(["Dash / Dodge (action)", "dashdodge", can_act])
	menu_items.append(["Disengage (action)" + (": ON" if h_disengaged else ""), "disengage", can_act and not h_disengaged])
	menu_items.append(["Drink potion (action, %d)" % game.run_potions, "potion", can_act and game.run_potions > 0])
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
	menu_panel.size.y = 10.0 + 10.0 * menu_items.size()
	var res := "ACTION %s  BONUS %s  MOVE %d FT" % ["OK" if h_action > 0 else "USED", "OK" if h_bonus > 0 else "USED", h_move * 5]
	_info(res + "    CLICK OR UP/DOWN + ENTER TO ACT")


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
			var hov: int = game.under_mouse(menu_lines.slice(0, menu_items.size()))
			if hov >= 0 and hov != menu_pick and game.mouse_moved() and menu_items[hov][2]:
				menu_pick = hov
				_render_menu()
			if game.clicked() and hov >= 0:
				menu_pick = hov
				_choose(menu_items[hov])
			elif Input.is_action_just_pressed("move_down"):
				_step_menu(1)
			elif Input.is_action_just_pressed("move_up"):
				_step_menu(-1)
			elif _confirm():
				_choose(menu_items[menu_pick])
		Mode.MOVE:
			var hc := _hero()
			var mc := _mouse_cell()
			var ok_m: bool = _move_opts.has(mc) and not _occupied(mc, hc)
			if ok_m and mc != cursor_col and game.mouse_moved():
				cursor_col = mc
				queue_redraw()
			var step := _key_step()
			if game.clicked() and ok_m:
				cursor_col = mc
				_do_move(mc)
			elif game.right_clicked():
				_open_menu()
			elif step != Vector2i.ZERO:
				if _move_opts.has(cursor_col + step):
					cursor_col += step
				queue_redraw()
			elif _confirm():
				_do_move(cursor_col)
			elif Input.is_action_just_pressed("back") or Input.is_action_just_pressed("dodge"):
				_open_menu()
		Mode.ECHO:
			var emc := _mouse_cell()
			var e_ok: bool = _echo_opts.has(emc)
			if e_ok and emc != cursor_col and game.mouse_moved():
				cursor_col = emc
				queue_redraw()
			var estep := _key_step()
			if game.clicked() and e_ok:
				_move_echo(emc)
			elif game.right_clicked() or Input.is_action_just_pressed("back"):
				_open_menu()
			elif estep != Vector2i.ZERO:
				if _echo_opts.has(cursor_col + estep):
					cursor_col += estep
				queue_redraw()
			elif _confirm():
				_move_echo(cursor_col)
		Mode.TARGET:
			var tm := get_global_mouse_position()
			var thov := -1
			for i in target_list.size():
				var t: Dictionary = target_list[i]
				var h := 34.0 if t.node == boss else 18.0
				if Rect2(t.node.global_position + Vector2(-9, -h), Vector2(18, h + 4)).has_point(tm):
					thov = i
			if thov >= 0 and thov != target_pick and game.mouse_moved():
				target_pick = thov
				queue_redraw()
			if game.clicked() and thov >= 0:
				target_pick = thov
				_target_chosen(target_list[thov])
			elif game.right_clicked():
				_open_menu()
			elif _key_step() != Vector2i.ZERO:
				target_pick = (target_pick + 1) % target_list.size()
				queue_redraw()
			elif _confirm():
				_target_chosen(target_list[target_pick])
			elif Input.is_action_just_pressed("back") or Input.is_action_just_pressed("dodge"):
				_open_menu()
	_camera()


func _confirm() -> bool:
	return game.ui_confirm()


func _camera() -> void:
	var hc := _hero()
	var bc := _boss_c()
	var at: Vector2 = _pos(hc.col) if bc.is_empty() else (_pos(hc.col) + _pos(bc.col)) / 2.0
	game.camera.global_position = at + Vector2(0, -10)



func _ask_target(action: String, reach: int, hint: String) -> void:
	target_list = _targets_in_reach(reach)
	if target_list.is_empty():
		game.toast("No foe in range.")
		return
	pending = action
	target_pick = 0
	mode = Mode.TARGET
	_info("CLICK A FOE, OR WASD + ENTER: %s    RIGHT-CLICK / ESC: BACK" % hint)
	queue_redraw()


func _choose(item: Array) -> void:
	if not item[2]:
		game.sfx.play("deflect", -12.0)
		return
	var p: Player = game.player
	var k: HeroKit = p.kit
	match item[1]:
		"attack":
			_ask_target("attack", _reach_cols(_weapon()), "STRIKE")
		"move":
			cursor_col = _hero().col
			_move_opts = _reach_map(_hero().col, h_move)
			mode = Mode.MOVE
			_info("CLICK A SQUARE, OR WASD + ENTER: MOVE    RIGHT-CLICK / ESC: BACK")
			queue_redraw()
		"dashdodge":
			# Dash if there is ground to cover, otherwise Dodge.
			h_action = 0
			if _targets_in_reach(1).is_empty():
				h_move += int(p.form_data.get("speed_ft", p.stats.speed_ft)) / 5
				game.log_line("Action: Dash.")
			else:
				h_dodging = true
				game.log_line("Action: Dodge. Attacks against %s have disadvantage until the next turn." % p.short_name())
			_open_menu()
		"disengage":
			h_action = 0
			h_disengaged = true
			game.log_line("Action: Disengage. Moving won't provoke opportunity attacks this turn.")
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
			p.heal(heal)
			game.toast("Potion of Healing: +%d HP" % heal)
			game.log_line("Action: Potion of Healing, 2d4 %s +2 = %d." % [str(faces), heal])
			_open_menu()
		"missile":
			await _magic_missile()
		"ray":
			_ask_target("ray", 24, "SCORCHING RAY")
		"fireball":
			_ask_target("fireball", 30, "AIM THE FIREBALL")
		"guardians":
			h_action = 0
			k._spend_slot(2)
			conc = "guardians"
			p.cast_pose()
			game.banner("SPIRIT GUARDIANS", Color(1.0, 0.92, 0.6))
			game.log_line("Action: Spirit Guardians. Foes that start their turn within 15 ft take 3d8 radiant (Wisdom save DC %d for half)." % int(k.s.spell_dc))
			_open_menu()
		"foresight":
			k._cycle_foresight()
			_open_menu()
		"heal":
			h_bonus = 0
			var lvl := k._spend_slot(1)
			var d := Rules.damage(game.dice, lvl, 4, int(k.s.spell_mod))
			p.heal(int(d.total))
			SpellFx.rise(game, p.global_position + Vector2(0, -6), Color(1.0, 0.95, 0.6))
			game.log_line("Bonus action: Healing Word, %dd4 %s %+d = %d HP." % [lvl, str(d.faces), d.bonus, d.total])
			game.toast("Healing Word: +%d HP" % d.total)
			_open_menu()
		"summon":
			h_bonus = 0
			k._spend_slot(2)
			sw_rounds = 10
			_make_spirit_node()
			game.banner("SPIRITUAL WEAPON", Color(0.6, 0.85, 1.0))
			game.log_line("Bonus action: Spiritual Weapon. A spectral mace appears (bonus action to attack each turn).")
			var near := _targets_in_reach(5)
			if not near.is_empty():
				await _spirit_strike(near[0])
			_open_menu()
		"spirit":
			_ask_target("spirit", 5, "SPECTRAL MACE")
		"bless":
			k._war_blessing()
			_open_menu()
		"hands":
			h_action = 0
			var amt := mini(k.lay_pool, p.max_hp - p.hp)
			k.lay_pool -= amt
			p.heal(amt)
			SpellFx.rise(game, p.global_position + Vector2(0, -6), Color(1.0, 0.95, 0.6))
			game.log_line("Action: Lay on Hands, %d HP (%d left in the pool)." % [amt, k.lay_pool])
			_open_menu()
		"smite":
			k._toggle_smite()
			_open_menu()
		"aura":
			await _dread_aura()
		"entangle":
			_ask_target("entangle", 18, "CENTRE THE VINES")
		"moonbeam":
			_ask_target("moonbeam", 24, "PLACE THE BEAM")
		"bear", "spider":
			h_action = 0
			k._wild_shape(item[1])
			conc = ""
			beam_col = NO_CELL
			_clear_restraints()
			h_move = mini(h_move, int(p.form_data.speed_ft) / 5)
			_open_menu()
		"revert":
			h_bonus = 0
			k.end_form(true)
			_open_menu()
		"echomove":
			cursor_col = echo_col
			_echo_opts = _reach_map(echo_col, echo_move)
			mode = Mode.ECHO
			_info("CLICK A SQUARE, OR WASD + ENTER: MOVE THE ECHO    RIGHT-CLICK / ESC: BACK")
			queue_redraw()
		"echoswap":
			await _echo_swap()
		"end":
			_echo_range_check()
			mode = Mode.BUSY
			menu_label.text = ""
			for l in menu_lines:
				l.visible = false
			_next_turn()


func _target_chosen(t: Dictionary) -> void:
	match pending:
		"attack": await _do_attack(t)
		"ray": await _scorching_ray(t)
		"fireball": await _fireball(t)
		"spirit":
			h_bonus = 0
			mode = Mode.BUSY
			await _spirit_strike(t)
			_open_menu()
		"entangle": await _entangle(t)
		"moonbeam": await _moonbeam(t)
		_: _open_menu()


func _targets_in_reach(reach := REACH_HERO) -> Array:
	var hc := _hero()
	var out := []
	for c in combatants:
		if c.side == "foe" and _alive(c) and _d(c.col, hc.col) <= reach and (reach <= 1 or _sees(hc.col, c.col)):
			out.append(c)
	out.sort_custom(func(x, y): return _d(x.col, hc.col) < _d(y.col, hc.col))
	return out


## A clear line between two squares (spells and arrows need one).
func _sees(a: Vector2i, b: Vector2i) -> bool:
	return game.room.line_clear(_pos(a) + Vector2(0, -6), _pos(b) + Vector2(0, -6))



func _foe_adjacent() -> bool:
	return not _targets_in_reach(1).is_empty()


func _foe_reach(c: Dictionary) -> int:
	if c.node == boss:
		return int(boss.data.reach)
	return 0 if str(c.node.data.weapon.name) == "Shortbow" else 1


## Moving: you may pass through anyone's square but must stop on a free one. Stepping out
## of a foe's reach provokes an opportunity attack (its reaction, once per round), unless
## you took the Disengage action.
## Moving: you may pass through anyone's square but must stop on a free one. Stepping out
## of a foe's reach provokes an opportunity attack (its reaction, once per round), unless
## you took the Disengage action.
func _do_move(col: Vector2i) -> void:
	var hc := _hero()
	if col == hc.col:
		_open_menu()
		return
	if _occupied(col, hc):
		game.toast("You can pass through, but not stop on, an occupied square.")
		return
	if not _move_opts.has(col):
		return
	var steps := _path(_move_opts, col)
	h_move -= steps.size()
	mode = Mode.BUSY
	var p: Player = game.player
	p.sprite.play("run")
	var x: Vector2i = hc.col
	for nx in steps:
		if not h_disengaged:
			for c in combatants:
				if c.side == "foe" and _alive(c) and c.reaction and not c.restrained:
					var r := _foe_reach(c)
					if r > 0 and _d(c.col, x) <= r and _d(c.col, nx) > r:
						p.sprite.play("idle")
						await _opportunity_attack(c, hc)
						if p.is_down() or not active:
							hc.col = x
							_next_turn_after_down()
							return
						p.sprite.play("run")
		if nx.x != x.x:
			p.facing = 1 if nx.x > x.x else -1
			p.visual.scale.x = p.facing
		var tw := create_tween()
		tw.tween_property(p, "global_position", _pos(nx), 0.09)
		await tw.finished
		x = nx
	p.sprite.play("idle")
	hc.col = col
	_face_nearest(p, hc)
	_open_menu()



func _next_turn_after_down() -> void:
	mode = Mode.BUSY
	await get_tree().create_timer(0.5).timeout
	_next_turn()


func _opportunity_attack(c: Dictionary, target: Dictionary) -> void:
	c.reaction = false
	var e: Enemy = c.node
	game.log_line("%s takes an opportunity attack as %s leaves its reach!" % [c.name, target.name])
	FloatText.fling(game, e.global_position + Vector2(0, -30), Vector2(0, -1), "OPPORTUNITY ATTACK", "", Color(1, 0.6, 0.4), 0, 1.0)
	_face_nearest(e, c)
	var a0 := e.look.angle()
	var tw := create_tween()
	tw.tween_property(e.weapon_pivot, "rotation", a0 - 1.6, 0.18)
	tw.tween_property(e.weapon_pivot, "rotation", a0 + 1.3, 0.08)
	tw.tween_property(e.weapon_pivot, "rotation", a0, 0.2)
	await get_tree().create_timer(0.26).timeout
	game.sfx.play("swing", -6.0)
	await _resolve_foe_attack(e, e.data.weapon, false, c, target)


func _face_nearest(node: Node2D, me: Dictionary) -> void:
	var best := 999
	var at: Vector2i = me.col
	for c in combatants:
		if (c.side == "foe") != (me.side == "foe") and _alive(c) and _d(c.col, me.col) < best:
			best = _d(c.col, me.col)
			at = c.col
	var dirv := Vector2(at - me.col).normalized() if at != me.col else Vector2.RIGHT
	var dir := 1 if dirv.x >= 0.0 else -1
	if node is Player:
		(node as Player).facing = dir
		(node as Player).aim = dirv
		(node as Player).visual.scale.x = dir
	elif node is Enemy:
		(node as Enemy).facing = dir
		(node as Enemy).look = dirv
		(node as Enemy).visual.scale.x = dir
	elif node is Companion:
		(node as Companion).facing = dir
		(node as Companion).visual.scale.x = dir



func _do_attack(t: Dictionary) -> void:
	mode = Mode.BUSY
	var p: Player = game.player
	var hc := _hero()
	var wpn := _weapon()
	if h_attacks == 0:
		h_action = 0
		h_attacks = 2 if (p.hero.has_extra_attack() and p.kit.form == "") or p.kit.form == "bear" else 1
	h_attacks -= 1
	p.aim = (t.node.global_position - p.global_position).normalized()
	p.facing = 1 if p.aim.x >= 0.0 else -1
	p.visual.scale.x = p.facing
	var kind := str(wpn.get("kind", "melee"))
	if kind == "bolt":
		var bolt := Node2D.new()
		bolt.set_script(preload("res://scripts/game/arrow_fx.gd"))
		bolt.modulate = Color(1.0, 0.55, 0.2)
		bolt.global_position = p.global_position + Vector2(p.facing * 8, -14)
		game.add_child(bolt)
		var tw := create_tween()
		tw.tween_property(bolt, "global_position", t.node.global_position + Vector2(0, -10), 0.25)
		game.sfx.play("swing", -8.0, 0.3)
		await tw.finished
		bolt.queue_free()
	elif kind == "whip":
		SpellFx.line(game, p.global_position + Vector2(p.facing * 8, -14), t.node.global_position + Vector2(0, -10), HeroKit.SPELL_COLORS.nature, 0.3, true)
		game.sfx.play("swing", -6.0, 0.3)
		await get_tree().create_timer(0.15).timeout
	else:
		if p.kit.form == "":
			var a0 := p.aim.angle()
			var tw := create_tween()
			tw.tween_property(p.weapon_pivot, "rotation", a0 - 1.5, 0.12)
			tw.tween_property(p.weapon_pivot, "rotation", a0 + 1.4, 0.08)
			tw.tween_property(p.weapon_pivot, "rotation", a0, 0.25)
			p.slash.call("play", 1.0)
		game.sfx.play("swing", -4.0)
		await get_tree().create_timer(0.2).timeout
	var atk := await _hero_roll(t, wpn, wpn.name)
	# Thorn Whip pulls the foe up to 10 feet closer.
	if kind == "whip" and atk.get("hit", false) and _alive(t) and t.node != boss:
		var nc: Vector2i = t.col
		for i in 2:
			var step := Vector2i(signi(hc.col.x - nc.x), signi(hc.col.y - nc.y))
			var nn := nc + step
			if _d(hc.col, nn) >= 1 and _walkable(nn) and not _occupied(nn, t):
				nc = nn
		if nc != t.col:
			await _foe_slide(t, nc)
	await get_tree().create_timer(0.45).timeout
	if p.is_down():
		mode = Mode.BUSY
		_next_turn()
		return
	_open_menu()


## One attack roll by the hero at a foe, with every turn-based modifier and class rider.
func _hero_roll(t: Dictionary, wpn: Dictionary, label: String) -> Dictionary:
	var p: Player = game.player
	var k: HeroKit = p.kit
	var e: Enemy = t.node
	var adv := 0
	var dis := 0
	var reasons: Array[String] = []
	var ranged := str(wpn.get("kind", "")) == "bolt" or bool(wpn.get("ray", false))
	if reckless_on and not ranged:
		adv += 1
		reasons.append("reckless")
	if echo_col != NO_CELL and _d(echo_col, t.col) <= 1 and not ranged:
		adv += 1
		reasons.append("flanked by your echo")
	if t.restrained:
		adv += 1
		reasons.append("target restrained")
	if ranged and _foe_adjacent():
		dis += 1
		reasons.append("casting in melee")
	var forced := k.take_foresight()
	var atk := Rules.attack(game.dice, wpn.attack, e.ac, Dice.combine(adv, dis), forced)
	if not atk.hit:
		k.try_blessing(atk, e.ac)
	var glancing: bool = not atk.hit and not atk.fumble
	var dmg := {}
	if atk.hit:
		var bonus: int = int(wpn.bonus) + (2 if rage_rounds > 0 and k.form == "" and not wpn.get("spell", false) else 0)
		dmg = Rules.damage(game.dice, wpn.count, wpn.sides, bonus, atk.crit)
		if atk.crit and k.s.get("savage", false) and k.form == "" and not wpn.get("spell", false):
			var extra: int = game.dice.die(wpn.sides)
			dmg.faces.append(extra)
			dmg.total += extra
		if str(wpn.get("kind", "")) == "melee" and not wpn.get("spell", false):
			var sm := k.smite_damage(atk.crit)
			if not sm.is_empty():
				dmg.total += int(sm.total)
				reasons.append("Divine Smite +%d" % sm.total)
		if wpn.has("poison_dc"):
			var sv := Rules.save(game.dice, e.save_bonus("con"), int(wpn.poison_dc))
			var pd := Rules.damage(game.dice, 2, 6, 0)
			var pt: int = pd.total if not sv.success else floori(pd.total / 2.0)
			dmg.total += pt
			game.log_line("Poison bite: %s CON save %d vs DC %d, %d poison." % [e.data.name, sv.total, sv.dc, pt])
	elif glancing:
		dmg = Rules.damage(game.dice, 1, 4, 0)
	game.show_attack(p, e, label, atk, dmg, reasons, glancing)
	if not dmg.is_empty():
		await _hurt_foe(t, int(dmg.total))
	elif atk.fumble:
		var f := Rules.damage(game.dice, 1, 4, 0)
		game.show_fumble(p, f, label)
		p.take_damage(int(f.total), false, 0.0)
	return atk


## Damage to a foe in the battle; handles the chief's fury and death.
func _hurt_foe(t: Dictionary, amount: int) -> void:
	var e: Enemy = t.node
	if amount <= 0 or not _alive(t):
		return
	e.hp = maxi(0, e.hp - amount)
	e._flash = 1.0
	e._show_bar = 99.0
	if e.hp <= 0:
		e._die(Vector2(game.player.facing, 0))
		if e == boss:
			await get_tree().create_timer(0.8).timeout
			_check_end()
	elif e == boss and not boss_fury_used and e.hp <= e.max_hp / 2:
		boss_fury_used = true
		boss_intent = "fury"
		game.log_line(str(boss.data.get("fury_line", "The boss is bloodied and furious.")))
		game.banner("THE CHIEF IS ENRAGED", Color(1, 0.5, 0.35))
		_show_intent()


func _foe_damage_text(t: Dictionary, amount: int, col: Color) -> void:
	FloatText.fling(game, t.node.global_position + Vector2(0, -18), Vector2(randf_range(-1.2, 1.2), -0.8), str(amount), "", col, 0, 1.1)


# ---------------- class actions in the battle ----------------

func _magic_missile() -> void:
	var p: Player = game.player
	var k: HeroKit = p.kit
	mode = Mode.BUSY
	h_action = 0
	var lvl := k._spend_slot(1)
	var targets := _targets_in_reach(24)
	var darts := 3 + (lvl - 1)
	game.log_line("Action: Magic Missile, %d darts of force (1d4+1 each, never miss)." % darts)
	p.cast_pose()
	for i in darts:
		var t: Dictionary = targets[0] if targets.size() > 0 else {}
		for c in targets:
			if c.node == boss:
				t = c
		if t.is_empty() or not _alive(t):
			break
		SpellFx.line(game, p.global_position + Vector2(p.facing * 8, -14), t.node.global_position + Vector2(0, -10), HeroKit.SPELL_COLORS.force, 0.2)
		var d := Rules.damage(game.dice, 1, 4, 1)
		_foe_damage_text(t, int(d.total), Color(0.8, 0.7, 1.0))
		game.sfx.play("hit", -6.0)
		game.log_line("Magic Missile dart: %d force to %s." % [d.total, t.name])
		await _hurt_foe(t, int(d.total))
		await get_tree().create_timer(0.18).timeout
	if active:
		_open_menu()


func _scorching_ray(t: Dictionary) -> void:
	var p: Player = game.player
	mode = Mode.BUSY
	h_action = 0
	p.kit._spend_slot(2)
	p.cast_pose()
	game.log_line("Action: Scorching Ray, three rays of fire.")
	var wpn := {"name": "Scorching Ray", "attack": int(p.kit.s.spell_attack), "count": 2, "sides": 6, "bonus": 0, "type": "fire", "spell": true, "ray": true}
	for i in 3:
		if not _alive(t) or not active:
			break
		SpellFx.line(game, p.global_position + Vector2(p.facing * 8, -14), t.node.global_position + Vector2(0, -10), HeroKit.SPELL_COLORS.fire, 0.22)
		await _hero_roll(t, wpn, "Scorching Ray")
		await get_tree().create_timer(0.3).timeout
	if active:
		_open_menu()


## Fireball: everyone within 20 ft (4 squares) of the target makes a Dexterity save.
func _fireball(t: Dictionary) -> void:
	var p: Player = game.player
	mode = Mode.BUSY
	h_action = 0
	p.kit._spend_slot(2)
	p.cast_pose()
	var dice := 8 + (1 if game.hero.level >= 9 else 0)
	var center: Vector2i = t.col
	SpellFx.line(game, p.global_position + Vector2(0, -12), t.node.global_position + Vector2(0, -10), HeroKit.SPELL_COLORS.fire, 0.2)
	await get_tree().create_timer(0.2).timeout
	SpellFx.burst(game, _pos(center) + Vector2(0, -8), HeroKit.SPELL_COLORS.fire, 64.0, 0.5)
	game.sfx.play("thud", -2.0)
	var dmg := Rules.damage(game.dice, dice, 6, 0)
	game.log_line("Action: Fireball, %dd6 %s = %d fire in a 20-ft radius (Dexterity save DC %d for half)." % [dice, str(dmg.faces), dmg.total, int(p.kit.s.spell_dc)])
	for c in combatants.duplicate():
		if c.side == "foe" and _alive(c) and _d(c.col, center) <= 4:
			var sv: Dictionary = p.kit.enemy_save(c.node, "dex", "half the blast")
			var total: int = dmg.total if not sv.success else floori(dmg.total / 2.0)
			_foe_damage_text(c, total, HeroKit.SPELL_COLORS.fire)
			await _hurt_foe(c, total)
	await get_tree().create_timer(0.4).timeout
	if active:
		_open_menu()


func _make_spirit_node() -> void:
	if is_instance_valid(sw_node):
		sw_node.queue_free()
	sw_node = Sprite2D.new()
	(sw_node as Sprite2D).texture = Art.region("weapon_mace")
	sw_node.modulate = Color(0.6, 0.85, 1.0, 0.85)
	sw_node.z_index = 6
	var hc := _hero()
	sw_node.global_position = _pos(hc.col) + Vector2(-14, -28)
	game.add_child(sw_node)


func _spirit_strike(t: Dictionary) -> void:
	var p: Player = game.player
	if is_instance_valid(sw_node):
		var tw := create_tween()
		tw.tween_property(sw_node, "global_position", t.node.global_position + Vector2(-8 * signf(t.node.global_position.x - p.global_position.x), -18), 0.2)
		tw.tween_property(sw_node, "rotation", 1.6, 0.08)
		tw.tween_property(sw_node, "rotation", 0.0, 0.2)
		await tw.finished
	var wpn := {"name": "Spiritual Weapon", "attack": int(p.kit.s.spell_attack), "count": 1, "sides": 8, "bonus": int(p.kit.s.spell_mod), "type": "force", "spell": true, "kind": "spirit"}
	await _hero_roll(t, wpn, "Spiritual Weapon")
	await get_tree().create_timer(0.3).timeout


func _dread_aura() -> void:
	var p: Player = game.player
	var k: HeroKit = p.kit
	mode = Mode.BUSY
	h_action = 0
	k.channel -= 1
	SpellFx.burst(game, p.global_position + Vector2(0, -12), Color(0.75, 0.4, 0.9), 96.0, 0.7)
	game.banner("DREAD AURA", Color(0.8, 0.5, 1.0))
	game.sfx.play("thud", -2.0)
	for c in _targets_in_reach(6):
		var sv := k.enemy_save(c.node, "wis", "the fear")
		if not sv.success:
			c.frightened = true
			FloatText.fling(game, c.node.global_position + Vector2(0, -26), Vector2(0, -1), "FRIGHTENED", "", Color(0.8, 0.55, 1.0), 0, 0.9)
	await get_tree().create_timer(0.6).timeout
	_open_menu()


func _entangle(t: Dictionary) -> void:
	var p: Player = game.player
	var k: HeroKit = p.kit
	mode = Mode.BUSY
	h_action = 0
	k._spend_slot(1)
	conc = "entangle"
	beam_col = NO_CELL
	p.cast_pose()
	game.log_line("Action: Entangle around %s (Strength save DC %d or restrained; concentration)." % [t.name, k.s.spell_dc])
	for c in combatants:
		if c.side == "foe" and _alive(c) and _d(c.col, t.col) <= 2:
			SpellFx.burst(game, c.node.global_position + Vector2(0, -4), HeroKit.SPELL_COLORS.nature, 12.0, 0.5)
			if not k.enemy_save(c.node, "str", "the vines").success:
				c.restrained = true
				FloatText.fling(game, c.node.global_position + Vector2(0, -26), Vector2(0, -1), "RESTRAINED", "", Color(0.55, 0.9, 0.45), 0, 0.9)
	await get_tree().create_timer(0.6).timeout
	_open_menu()


func _moonbeam(t: Dictionary) -> void:
	var p: Player = game.player
	var k: HeroKit = p.kit
	mode = Mode.BUSY
	h_action = 0
	if conc != "moonbeam":
		k._spend_slot(2)
		_clear_restraints()
	conc = "moonbeam"
	beam_col = t.col
	p.cast_pose()
	game.log_line("Action: Moonbeam on %s's square. Foes starting a turn in it take 2d10 radiant (CON save DC %d for half)." % [t.name, k.s.spell_dc])
	await get_tree().create_timer(0.4).timeout
	_open_menu()


func _clear_restraints() -> void:
	for c in combatants:
		c.restrained = false


## Damage to the hero during the battle may break concentration.
func _hero_hit(amount: int) -> void:
	if conc == "" or amount <= 0:
		return
	var p: Player = game.player
	var dc := maxi(10, floori(amount / 2.0))
	var sv := Rules.save(game.dice, int(p.kit.s.con_save), dc)
	game.log_line("Concentration: CON save %d vs DC %d, %s." % [sv.total, dc, "held" if sv.success else "lost"])
	if not sv.success:
		game.toast("Concentration broken!")
		conc = ""
		beam_col = NO_CELL
		_clear_restraints()


## The echo moves where you command it, free, up to 30 feet a turn. It can pass anyone but
## must stop on an empty square.
## The echo moves where you command it, free, up to 30 feet a turn. It can pass anyone but
## must stop on an empty square.
func _move_echo(col: Vector2i) -> void:
	if col == echo_col:
		_open_menu()
		return
	if _occupied(col, null):
		game.toast("The echo can pass through, but not stop on, an occupied square.")
		return
	if not _echo_opts.has(col):
		return
	echo_move -= _path(_echo_opts, col).size()
	echo_col = col
	mode = Mode.BUSY
	if is_instance_valid(echo_node):
		var tw := create_tween()
		tw.tween_property(echo_node, "global_position", _pos(col), 0.2)
		await tw.finished
	game.log_line("Boar-vhal sends his echo across the field (free movement).")
	if _d(echo_col, _hero().col) > echo_leash:
		game.toast("The echo is more than 30 ft away: it fades at the end of your turn.")
	_open_menu()



## Swap places with the echo for 15 feet of movement.
func _echo_swap() -> void:
	var hc := _hero()
	var p: Player = game.player
	h_move -= 3
	var mine: Vector2i = hc.col
	hc.col = echo_col
	echo_col = mine
	mode = Mode.BUSY
	p.global_position = _pos(hc.col)
	p.reset_physics_interpolation()
	if is_instance_valid(echo_node):
		echo_node.global_position = _pos(echo_col)
	game.sfx.play("dodge", -6.0)
	game.log_line("Boar-vhal swaps places with his echo (15 ft of movement).")
	await get_tree().create_timer(0.25).timeout
	_face_nearest(p, hc)
	_open_menu()


## End of the hero's turn: an echo more than 30 feet away is destroyed.
func _echo_range_check() -> void:
	if echo_col != NO_CELL and _d(echo_col, _hero().col) > echo_leash:
		echo_col = NO_CELL
		if is_instance_valid(echo_node):
			echo_node.queue_free()
		game.log_line("The echo is more than 30 ft from Boar-vhal and fades away.")
		game.toast("Your echo fades (more than 30 ft away).")


func _place_echo() -> void:
	var hc := _hero()
	var bc := _boss_c()
	var want := NO_CELL
	var behind := false
	if not bc.is_empty():
		# Behind the chief, on the far side from Boar-vhal, to flank him.
		var away := Vector2i(signi(bc.col.x - hc.col.x), signi(bc.col.y - hc.col.y))
		var beyond: Vector2i = bc.col + away
		if _walkable(beyond) and not _occupied(beyond, null) and _d(beyond, hc.col) <= 6:
			want = beyond
			behind = true
	if want == NO_CELL:
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			if _walkable(hc.col + d) and not _occupied(hc.col + d, null):
				want = hc.col + d
				break
	if want == NO_CELL:
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
	game.room.ysort.add_child(echo_node)
	echo_node.global_position = _pos(echo_col)
	game.log_line("Bonus action: Echo appears %s the chief. Foes next to it are flanked." % ("behind" if behind else "beside"))



# ---------------- foes ----------------

func _pick_intent() -> void:
	if boss_intent == "fury":
		return
	boss_intent = "special" if round_no % 3 == 2 else "smash"
	_show_intent()


func _show_intent() -> void:
	if not intent_label:
		return
	var txt: Dictionary = boss.data.get("intents", {}) if boss else {}
	intent_label.text = str(txt.get(boss_intent, ""))


## Goblins and the chief go for the nearest of the hero and the allies.
## Goblins and the chief go for the nearest of the hero, the allies and Boar-vhal's echo.
func _foe_target(c: Dictionary) -> Dictionary:
	var best := _hero()
	var bd := 999 if game.player.is_down() else _d(best.col, c.col)
	for o in combatants:
		if o.side == "ally" and _alive(o) and _d(o.col, c.col) < bd:
			bd = _d(o.col, c.col)
			best = o
	if echo_col != NO_CELL and _d(echo_col, c.col) < bd:
		best = {"node": echo_node, "name": "Boar-vhal's echo", "side": "echo", "col": echo_col}
	return best



func _foe_turn(c: Dictionary) -> void:
	var e: Enemy = c.node
	var hc := _foe_target(c)
	var p: Player = game.player
	var k: HeroKit = p.kit
	# Moonbeam burns whoever starts a turn in the light.
	if conc == "moonbeam" and _d(c.col, beam_col) <= 0:
		var sv := k.enemy_save(e, "con", "half the light")
		var d := Rules.damage(game.dice, 2, 10, 0)
		var total: int = d.total if not sv.success else floori(d.total / 2.0)
		_foe_damage_text(c, total, Color(0.85, 0.92, 1.0))
		game.log_line("Moonbeam: %d radiant to %s." % [total, c.name])
		await _hurt_foe(c, total)
		await get_tree().create_timer(0.4).timeout
		if not _alive(c):
			return
	# Spirit Guardians: radiant spirits strike any foe that starts its turn within 15 ft of Erwar.
	if conc == "guardians" and _d(c.col, _hero().col) <= 3 and not p.is_down():
		var gsv := k.enemy_save(e, "wis", "half")
		var gd := Rules.damage(game.dice, 3 + (1 if game.hero.level >= 10 else 0), 8, 0)
		var gtotal: int = gd.total if not gsv.success else floori(gd.total / 2.0)
		_foe_damage_text(c, gtotal, HeroKit.SPELL_COLORS.radiant)
		game.log_line("Spirit Guardians: %d radiant to %s." % [gtotal, c.name])
		await _hurt_foe(c, gtotal)
		await get_tree().create_timer(0.4).timeout
		if not _alive(c):
			return
	if p.is_down() and hc.side == "hero":
		game.log_line("%s jeers at the fallen %s." % [c.name, p.short_name()])
		return
	# Restrained: the chief spends his action tearing free; goblins stay put.
	if c.restrained and e == boss:
		var chk := Rules.save(game.dice, e.save_bonus("str"), int(k.s.spell_dc))
		game.log_line("%s strains against the vines: STR %d vs DC %d, %s." % [e.data.name, chk.total, chk.dc, "breaks free" if chk.success else "still held"])
		if chk.success:
			c.restrained = false
		await _end_foe_turn(c)
		return
	var dist := _d(hc.col, c.col)
	if e == boss:
		var reach: int = boss.data.reach
		if dist > reach and not c.frightened:
			await _foe_move_toward(c, hc, reach)
			dist = _d(hc.col, c.col)
		if dist <= reach:
			match boss_intent if hc.side == "hero" or boss_intent != "special" else "smash":
				"special":
					if str(boss.data.get("special", "shove")) == "hold":
						await _boss_hold(c, hc)
					else:
						await _boss_shove(c, hc)
				"fury":
					await _foe_attack(c, e.data.weapon, hc)
					if _alive(hc) and not (hc.side == "hero" and p.is_down()):
						await get_tree().create_timer(0.35).timeout
						await _foe_attack(c, e.data.weapon, hc)
					boss_intent = "smash"
				_:
					await _foe_attack(c, e.data.weapon, hc)
		_pick_intent()
		await _end_foe_turn(c)
	elif not e.data.get("ranged", false):
		# Melee foes (cultists, rats): close in and strike.
		if dist > 1 and not c.frightened and not c.restrained:
			await _foe_move_toward(c, hc, 1)
			dist = _d(hc.col, c.col)
		if dist <= 1 and not c.frightened:
			await _foe_attack(c, e.data.weapon, hc)
		await _end_foe_turn(c)
	else:
		# Goblin archer: step away if cornered, then shoot.
		if dist <= 1 and not c.restrained:
			var opts := _reach_map(c.col, 6)
			var target: Vector2i = c.col
			for cell in opts:
				if not _occupied(cell, c) and _d(cell, hc.col) > _d(target, hc.col) and _sees(cell, hc.col):
					target = cell
			if target != c.col:
				game.log_line("%s disengages (Nimble Escape)." % c.name)
				await _foe_slide(c, target)
		await _foe_shoot(c, hc)
		await _end_foe_turn(c)


func _foe_hits_ally(e: Enemy, wpn: Dictionary, disadvantage: bool, c: Dictionary, tgt: Dictionary) -> void:
	var ally: Companion = tgt.node
	var dis := (1 if disadvantage else 0) + (1 if c.get("frightened", false) else 0) + (1 if c.get("restrained", false) else 0)
	var atk := Rules.attack(game.dice, wpn.attack, ally.ac, Dice.combine(0, dis))
	if atk.hit:
		var d := Rules.damage(game.dice, wpn.count, wpn.sides, wpn.bonus, atk.crit)
		game.log_line("%s: %s vs %s, d20 %d %+d = %d vs AC %d, %d damage." % [c.name, wpn.name, tgt.name, atk.kept, atk.bonus, atk.total, ally.ac, d.total])
		ally.take_damage(int(d.total))
		if ally.down:
			_refresh_order()
	else:
		game.log_line("%s: %s vs %s, d20 %d %+d = %d vs AC %d, miss." % [c.name, wpn.name, tgt.name, atk.kept, atk.bonus, atk.total, ally.ac])
		FloatText.fling(game, ally.global_position + Vector2(0, -20), Vector2(randf_range(-1, 1), -0.8), "MISS", "", Color(0.75, 0.75, 0.8), 0, 0.9)
		game.sfx.play("deflect", -6.0)
	await get_tree().create_timer(0.4).timeout


## An ally's turn: heal the hero if it's needed, otherwise close in and fight.
func _ally_turn(c: Dictionary) -> void:
	var ally: Companion = c.node
	var p: Player = game.player
	var hc := _hero()
	if ally.key == "erwar" and ally.slots > 0 and p.hp <= p.max_hp / 2:
		ally.slots -= 1
		var d := Rules.damage(game.dice, 1, 4, int(ally.stats.spell_mod))
		p.heal(int(d.total))
		if p.is_down():
			p._rise("Erwar's Healing Word brings %s back to %d HP." % [p.short_name(), p.hp])
		SpellFx.rise(game, p.global_position + Vector2(0, -6), Color(1.0, 0.95, 0.6))
		game.log_line("Erwar casts Healing Word on %s: +%d HP." % [p.short_name(), d.total])
	elif ally.key == "lyburnum" and ally.lay_pool > 0 and p.hp <= p.max_hp / 3 and _d(hc.col, c.col) <= 1:
		var amt := mini(ally.lay_pool, p.max_hp - p.hp)
		ally.lay_pool -= amt
		p.heal(amt)
		if p.is_down():
			p._rise("Lyburnum's hands bring %s back to %d HP." % [p.short_name(), p.hp])
		SpellFx.rise(game, p.global_position + Vector2(0, -6), Color(1.0, 0.95, 0.6))
		game.log_line("Lyburnum lays hands on %s: +%d HP." % [p.short_name(), amt])
		return
	var wpn: Dictionary = ally.stats.weapon
	var reach := _reach_cols(wpn)
	var foes := []
	for o in combatants:
		if o.side == "foe" and _alive(o):
			foes.append(o)
	if foes.is_empty():
		return
	foes.sort_custom(func(a, b): return _d(a.col, c.col) < _d(b.col, c.col))
	var t: Dictionary = foes[0]
	if _d(t.col, c.col) > reach or (reach > 1 and not _sees(c.col, t.col)):
		var opts := _reach_map(c.col, int(ally.stats.speed_ft) / 5)
		var dest: Vector2i = c.col
		var best := 9999
		for cell in opts:
			if _occupied(cell, c):
				continue
			var score := _d(cell, t.col) * 10 + _path(opts, cell).size()
			if _d(cell, t.col) <= reach and (reach <= 1 or _sees(cell, t.col)):
				score = _path(opts, cell).size()
			if score < best:
				best = score
				dest = cell
		if dest != c.col:
			ally.sprite.play("run")
			for nx in _path(opts, dest):
				var tw := create_tween()
				tw.tween_property(ally, "global_position", _pos(nx), 0.09)
				await tw.finished
			ally.sprite.play("idle")
			c.col = dest
	_face_nearest(ally, c)
	if _d(t.col, c.col) > reach:
		return
	var swings := 2 if ally.stats.extra_attack else 1
	for i in swings:
		if not _alive(t):
			break
		var tw2 := create_tween()
		tw2.tween_property(ally.weapon_pivot, "rotation", -2.2, 0.15)
		tw2.tween_property(ally.weapon_pivot, "rotation", 1.9, 0.07)
		tw2.tween_property(ally.weapon_pivot, "rotation", -0.55, 0.25)
		if str(wpn.get("kind", "")) != "melee":
			SpellFx.line(game, ally.global_position + Vector2(ally.facing * 8, -14), t.node.global_position + Vector2(0, -10),
				HeroKit.SPELL_COLORS.fire if wpn.kind == "bolt" else HeroKit.SPELL_COLORS.nature, 0.25, wpn.kind == "whip")
		await get_tree().create_timer(0.2).timeout
		var e: Enemy = t.node
		var atk := Rules.attack(game.dice, int(wpn.attack), e.ac, Dice.Mode.ADVANTAGE if t.restrained else Dice.Mode.NORMAL)
		var dmg := 0
		if atk.hit:
			dmg = int(Rules.damage(game.dice, int(wpn.count), int(wpn.sides), int(wpn.bonus), atk.crit).total)
		elif not atk.fumble:
			dmg = game.dice.die(4)
		game.log_line("%s: %s vs %s, d20 %d %+d = %d, %s." % [c.name, wpn.name, t.name, atk.kept, atk.bonus, atk.total, ("%d damage" % dmg) if dmg > 0 else "miss"])
		if dmg > 0:
			_foe_damage_text(t, dmg, Color(0.7, 1.0, 0.7))
		else:
			FloatText.fling(game, e.global_position + Vector2(0, -18), Vector2(0, -0.8), "MISS", "", Color(0.75, 0.75, 0.8), 0, 0.9)
		if dmg > 0:
			game.sfx.play("hit", -6.0)
			await _hurt_foe(t, dmg)
		await get_tree().create_timer(0.3).timeout


## A frightened foe repeats its Wisdom save at the end of each of its turns.
func _end_foe_turn(c: Dictionary) -> void:
	if c.frightened and _alive(c):
		var sv: Dictionary = game.player.kit.enemy_save(c.node, "wis", "and shakes off the fear")
		if sv.success:
			c.frightened = false


func _foe_move_toward(c: Dictionary, hc: Dictionary, reach: int) -> void:
	var opts := _reach_map(c.col, 6)
	var target: Vector2i = c.col
	var best := 9999
	for cell in opts:
		if _occupied(cell, c):
			continue
		var score := maxi(0, _d(cell, hc.col) - reach) * 10 + _path(opts, cell).size()
		if score < best:
			best = score
			target = cell
	if target != c.col:
		await _foe_slide(c, target, opts)



func _foe_slide(c: Dictionary, col: Vector2i, opts: Dictionary = {}) -> void:
	var e: Enemy = c.node
	var steps: Array[Vector2i] = _path(opts, col) if not opts.is_empty() else [col]
	e.sprite.play("run")
	for nx in steps:
		if nx.x != c.col.x:
			e.facing = 1 if nx.x > c.col.x else -1
			e.visual.scale.x = e.facing
		var tw := create_tween()
		tw.tween_property(e, "global_position", _pos(nx), 0.1)
		await tw.finished
		c.col = nx
	c.col = col
	e.sprite.play("idle")
	_face_nearest(e, c)



func _foe_attack(c: Dictionary, wpn: Dictionary, tgt: Dictionary = {}) -> void:
	var e: Enemy = c.node
	var p: Player = game.player
	_face_nearest(e, c)
	var a0 := e.look.angle()
	var tw := create_tween()
	tw.tween_property(e.weapon_pivot, "rotation", a0 - 1.6, 0.25)
	tw.tween_property(e.weapon_pivot, "rotation", a0 + 1.3, 0.08)
	tw.tween_property(e.weapon_pivot, "rotation", a0, 0.25)
	await get_tree().create_timer(0.33).timeout
	game.sfx.play("swing", -6.0)
	await _resolve_foe_attack(e, wpn, false, c, tgt)


func _foe_shoot(c: Dictionary, tgt: Dictionary = {}) -> void:
	var e: Enemy = c.node
	var p: Node2D = game.player if tgt.is_empty() else tgt.node
	_face_nearest(e, c)
	var arrow := Node2D.new()
	arrow.set_script(preload("res://scripts/game/arrow_fx.gd"))
	arrow.global_position = e.global_position + Vector2(0, -8)
	game.add_child(arrow)
	var tw := create_tween()
	tw.tween_property(arrow, "global_position", p.global_position + Vector2(0, -12), 0.3)
	await tw.finished
	arrow.queue_free()
	var adjacent := false
	for o in combatants:
		if o.side != "foe" and _alive(o) and _d(o.col, c.col) <= 1:
			adjacent = true
	await _resolve_foe_attack(e, e.data.weapon, adjacent, c, tgt)


func _resolve_foe_attack(e: Enemy, wpn: Dictionary, disadvantage: bool, c: Dictionary = {}, tgt: Dictionary = {}) -> void:
	if not tgt.is_empty() and tgt.side == "ally":
		await _foe_hits_ally(e, wpn, disadvantage, c, tgt)
		return
	if not tgt.is_empty() and tgt.side == "echo":
		await _foe_hits_echo(e, wpn, disadvantage, c)
		return
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
	if c.get("frightened", false):
		dis += 1
		reasons.append("frightened")
	if c.get("restrained", false):
		dis += 1
		reasons.append("restrained")
	var atk := Rules.attack(game.dice, wpn.attack, p.ac, Dice.combine(adv, dis), p.kit.take_foresight())
	var dmg := {}
	if atk.hit:
		var resisted: bool = rage_rounds > 0 and wpn.type in ["bludgeoning", "piercing", "slashing"]
		dmg = Rules.damage(game.dice, wpn.count, wpn.sides, wpn.bonus, atk.crit, resisted)
	game.show_attack(e, p, wpn.name, atk, dmg, reasons, false)
	if atk.hit:
		p.take_damage(int(dmg.total), atk.crit, 0.0)
		_hero_hit(int(dmg.total))
	else:
		game.sfx.play("deflect", -4.0)
	await get_tree().create_timer(0.4).timeout


## Boar-vhal's echo: AC 14 + proficiency bonus, 1 hit point. Any damage destroys it.
func _foe_hits_echo(e: Enemy, wpn: Dictionary, disadvantage: bool, c: Dictionary) -> void:
	var ac := 14 + int(game.player.stats.get("proficiency", 2))
	var dis := (1 if disadvantage else 0) + (1 if c.get("frightened", false) else 0) + (1 if c.get("restrained", false) else 0)
	var atk := Rules.attack(game.dice, wpn.attack, ac, Dice.combine(0, dis))
	game.log_line("%s: %s vs the echo, d20 %d %+d = %d vs AC %d, %s." % [c.name, wpn.name, atk.kept, atk.bonus, atk.total, ac, "it shatters" if atk.hit else "miss"])
	if atk.hit:
		if is_instance_valid(echo_node):
			SpellFx.burst(game, echo_node.global_position + Vector2(0, -12), Color(0.55, 0.75, 1.0), 14.0, 0.4)
			FloatText.fling(game, echo_node.global_position + Vector2(0, -24), Vector2(0, -1), "ECHO DESTROYED", "", Color(0.6, 0.8, 1.0), 0, 1.0)
			echo_node.queue_free()
		echo_col = NO_CELL
		game.sfx.play("deflect", -4.0)
		game.player.reclaim_potential()
	else:
		FloatText.fling(game, echo_node.global_position + Vector2(0, -20), Vector2(0, -0.8), "MISS", "", Color(0.75, 0.75, 0.8), 0, 0.9)
	await get_tree().create_timer(0.4).timeout


func _boss_shove(c: Dictionary, hc: Dictionary) -> void:
	var p: Player = game.player
	var dc: int = boss.data.shove_dc
	var mode_s := Dice.Mode.ADVANTAGE if rage_rounds > 0 else Dice.Mode.NORMAL
	var sv := Rules.save(game.dice, p.hero.str_save(), dc, mode_s)
	game.sfx.play("thud", -2.0)
	game.log_line("%s shoves: Strength save d20 %s %+d = %d vs DC %d, %s." % [boss.data.name,
		("%d|%d" % [sv.rolls[0], sv.rolls[1]]) if sv.rolls.size() > 1 else str(sv.kept), sv.bonus, sv.total, dc, "resisted" if sv.success else "failed"])
	if sv.success:
		FloatText.fling(game, p.global_position + Vector2(0, -24), Vector2(0, -1), "RESISTED", "", Color(0.7, 0.85, 1.0), 0, 1.0)
		return
	var away := Vector2i(signi(hc.col.x - c.col.x), signi(hc.col.y - c.col.y))
	var target: Vector2i = hc.col
	for i in 2:
		var nc: Vector2i = target + away
		if not _walkable(nc) or _occupied(nc, hc):
			break
		target = nc
	var tw := create_tween()
	tw.tween_property(p, "global_position", _pos(target), 0.18)
	await tw.finished
	hc.col = target
	h_prone = true
	p.sprite.play("hit")
	FloatText.fling(game, p.global_position + Vector2(0, -24), Vector2(0, -1), "PRONE", "", Color(1.0, 0.6, 0.4), 0, 1.0)
	game.log_line("%s is knocked prone (melee attacks have advantage until %s stands)." % [p.short_name(), p.hero.pronoun("he")])


## Hold Person: a Wisdom save or the hero is paralyzed and loses their next turn.
func _boss_hold(c: Dictionary, hc: Dictionary) -> void:
	var p: Player = game.player
	var dc: int = int(boss.data.get("hold_dc", 12))
	var sv := Rules.save(game.dice, int(p.stats.get("wis_save", 0)), dc)
	SpellFx.burst(game, p.global_position + Vector2(0, -12), Color(0.7, 0.4, 0.9), 14.0, 0.5)
	game.sfx.play("dodge", -4.0)
	game.log_line("%s casts Hold Person: Wisdom save d20 %d %+d = %d vs DC %d, %s." % [boss.data.name, sv.kept, sv.bonus, sv.total, dc, "resisted" if sv.success else "held fast"])
	if sv.success:
		FloatText.fling(game, p.global_position + Vector2(0, -24), Vector2(0, -1), "RESISTED", "", Color(0.7, 0.85, 1.0), 0, 1.0)
		return
	h_held = true
	FloatText.fling(game, p.global_position + Vector2(0, -24), Vector2(0, -1), "HELD", "", Color(0.8, 0.5, 1.0), 0, 1.0)


# ---------------- presentation ----------------

func _build_ui() -> void:
	if ui:
		ui.queue_free()
	ui = CanvasLayer.new()
	ui.layer = 11
	add_child(ui)
	var top := _panel(Vector2(166, 4), Vector2(116, 52))
	order_panel = top
	order_label = _label(top, Vector2(5, 3), 8, Color(0.92, 0.9, 0.85))
	order_label.label_settings.line_spacing = -3.0
	menu_panel = _panel(Vector2(4, MENU_TOP), Vector2(186, 100))
	menu_panel.scale = Vector2.ONE * Hud.UI_SCALE
	order_panel.scale = Vector2.ONE * Hud.UI_SCALE
	menu_label = _label(menu_panel, Vector2(6, 4), 8, Color.WHITE)
	menu_lines.clear()
	for i in 14:
		var l := _label(menu_panel, Vector2(6, 3 + i * 10), 8, Color.WHITE)
		l.visible = false
		menu_lines.append(l)
	intent_label = _label(ui, Vector2(196, 108), 8, Color(1, 0.6, 0.45))
	intent_label.size = Vector2(280, 22)
	intent_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Bottom-left, at the HUD's 80% scale, clear of the roll log in the bottom-right corner.
	info_label = _label(ui, Vector2(6, 258), 8, Color(0.7, 0.85, 1.0))
	info_label.size = Vector2(390, 10)
	info_label.pivot_offset = Vector2(0, 10)
	info_label.scale = Vector2.ONE * Hud.UI_SCALE
	info_label.clip_text = true
	game.hud.hints.visible = false
	game.hud.room_label.visible = false
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
	if is_instance_valid(info_label):
		info_label.text = t.to_upper()


func _refresh_order() -> void:
	if not active or not is_instance_valid(order_label):
		return
	var lines: Array[String] = ["ROUND %d  INITIATIVE" % round_no]
	for i in combatants.size():
		var c: Dictionary = combatants[i]
		if not _alive(c):
			continue
		var tag := ""
		if c.side == "foe":
			var e: Enemy = c.node
			tag = "UNHURT" if e.hp == e.max_hp else ("BLOODIED" if e.hp <= e.max_hp / 2 else "HURT")
		elif c.side == "ally":
			tag = "%d HP" % (c.node as Companion).hp
		else:
			tag = "%d HP" % game.player.hp
		lines.append(("> " if i == turn_index else "  ") + "%s  %s" % [str(c.name).to_upper(), tag])
	order_label.text = "\n".join(lines)
	# The box grows with the initiative list (allies make it longer); the action menu moves below it.
	var sz := order_label.get_minimum_size()
	order_panel.size = Vector2(maxf(116.0, sz.x + 10.0), sz.y + 8.0)
	# Centred at the top, drawn at the HUD's 80% scale.
	order_panel.pivot_offset = Vector2(order_panel.size.x / 2.0, 0)
	order_panel.position.x = 240.0 - order_panel.size.x / 2.0
	var order_right := 240.0 - order_panel.size.x * Hud.UI_SCALE / 2.0
	menu_panel.position.y = maxf(MENU_TOP, order_panel.position.y + order_panel.size.y * Hud.UI_SCALE + 4.0) if order_right < menu_panel.position.x + menu_panel.size.x * Hud.UI_SCALE else MENU_TOP
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
		for cell in _move_opts:
			var free: bool = not _occupied(cell, hc) or cell == hc.col
			draw_rect(Rect2(cell.x * T + 1, cell.y * T + 1, T - 2, T - 2), Color(0.4, 0.8, 1.0, 0.22) if free else Color(1, 0.3, 0.3, 0.2))
		draw_rect(Rect2(cursor_col.x * T, cursor_col.y * T, T, T), Color(0.4, 0.8, 1.0, 0.95), false, 1.0)
	elif mode == Mode.ECHO:
		for cell in _echo_opts:
			var ok: bool = not _occupied(cell, null) or cell == echo_col
			draw_rect(Rect2(cell.x * T + 1, cell.y * T + 1, T - 2, T - 2), Color(0.55, 0.75, 1.0, 0.2) if ok else Color(1, 0.3, 0.3, 0.2))
		draw_rect(Rect2(cursor_col.x * T, cursor_col.y * T, T, T), Color(0.55, 0.75, 1.0, 0.95), false, 1.0)
		# 30 ft from Boar-vhal: where the echo must be at the end of the turn.
		draw_rect(Rect2((hc.col.x - echo_leash) * T, (hc.col.y - echo_leash) * T, (echo_leash * 2 + 1) * T, (echo_leash * 2 + 1) * T), Color(0.55, 0.75, 1.0, 0.4), false, 1.0)
	elif mode == Mode.TARGET and not target_list.is_empty():
		var t: Dictionary = target_list[target_pick]
		var h := 34.0 if t.node == boss else 18.0
		draw_rect(Rect2(t.node.global_position + Vector2(-9, -h), Vector2(18, h + 3)), Color(1, 0.4, 0.3, 0.95), false, 1.0)
	if mode != Mode.IDLE:
		draw_rect(Rect2(hc.col.x * T + 1, hc.col.y * T + 1, T - 2, T - 2), Color(1, 0.9, 0.4, 0.8), false, 1.0)
	if conc == "moonbeam" and beam_col != NO_CELL:
		draw_rect(Rect2(beam_col.x * T, beam_col.y * T - 100, T, 100 + T), Color(0.8, 0.9, 1.0, 0.18))
	for c in combatants:
		if c.side == "foe" and _alive(c) and c.restrained:
			var at := _pos(c.col)
			for i in 4:
				draw_line(at + Vector2(-5 + i * 3, 1), at + Vector2(-4 + i * 3, -7), Color(0.35, 0.65, 0.25), 1.5)

