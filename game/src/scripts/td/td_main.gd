class_name TDMain
extends Node2D
## TOP-DOWN PROTOTYPE: the Gryphon's Roost and a two-room test dungeon. A 3/4 top-down take on Vanguard's Descent, in the style of
## Stardew Valley's mines: 8-way movement, aimed attacks, goblins that path around walls,
## spike traps, a chest and a door that opens once the room is clear. The rules core
## (Dice, Rules, Kits, Creatures) is the same one the side-scroller uses.
##
## Open with ?test=topdown (and optionally &hero=ceridwen ...) or from the cellar card.

const T := 16
## Legend: # wall, . floor, S start, g goblin minion, G goblin warrior, a goblin archer,
## ^ spike trap, c chest, o column, x crate, k skull, D door to the next room (two cells wide).
const ROOMS := [
	[
		"##########DD##########",
		"#.......o......o.....#",
		"#..k.................#",
		"#.........^^.........#",
		"#....g....^^....g....#",
		"#....................#",
		"#..o.............o...#",
		"#........g...........#",
		"#.x..................#",
		"#.xx......S.......c..#",
		"######################",
	],
	[
		"###########DD###########",
		"#.....o..........o.....#",
		"#..........a...........#",
		"#..k...................#",
		"#........^.....^.......#",
		"#...G............g.....#",
		"#........^.....^.......#",
		"#.................a....#",
		"#..o..g........k.......#",
		"#......................#",
		"#...........S.......x..#",
		"########################",
	],
]

var dice := Dice.new(randi() % 900000 + 100000)
var sfx: Sfx
var music: Music
var hero: Hero
var player: TDHero
var foes: Array[TDFoe] = []
var npcs: Array[InnNPC] = []
var world: Node2D          # y-sorted: walls, props, people
var floor_layer: Node2D
var walls: StaticBody2D
var map_name := ""
var map: Dictionary = {}
var room_i := -1           # dungeon room index, or -1 in the inn
var grid: Array[String] = []
var astar: AStarGrid2D
var door_cells: Array[Vector2i] = []
var door_open := false
var door_sprite: Sprite2D
var spikes: Array[Dictionary] = []
var chest: Dictionary = {}
var camera: Camera2D
var hud: CanvasLayer
var hp_label: Label
var hp_bar: ColorRect
var log_label: Label
var toast_label: Label
var prompt_label: Label
var title_label: Label
var _toast_t := 0.0
var _spike_t := 0.0
var _log: Array[String] = []
var _link_cool := 0.0
var _exit_armed := false
var gold := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sfx = Sfx.new()
	add_child(sfx)
	music = Music.new()
	music.game = self
	add_child(music)
	hero = Hero.new()
	var hk := _url_value("hero")
	hero.set_key(hk if Kits.has(hk) else "boarvhal")
	hero.level = 3
	_build_hud()
	var start := _url_value("map")
	if start == "":
		load_map("room_" + (hero.key if TDMaps.HEROES.has(hero.key) else "boarvhal"), "bed")
	else:
		load_map(start, _url_value("spawn"))


func _url_value(key: String) -> String:
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if q is String and (q as String).contains(key + "="):
			return (q as String).get_slice(key + "=", 1).get_slice("&", 0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return ""


# ---------------- maps ----------------

func cell(c: Vector2i) -> String:
	if c.y < 0 or c.y >= grid.size() or c.x < 0 or c.x >= grid[c.y].length():
		return " "
	return grid[c.y][c.x]


func _floorish(ch: String) -> bool:
	return ch != "#" and ch != "D" and ch != " "


func is_wall(c: Vector2i) -> bool:
	var ch := cell(c)
	return ch == "#" or ch == " " or (ch == "D" and not door_open)


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T / 2.0, c.y * T + T / 2.0)


func load_map(name: String, spawn := "") -> void:
	map_name = name
	map = TDMaps.get_map(name)
	room_i = int(map.get("dungeon", -1))
	for n in [world, floor_layer, walls]:
		if is_instance_valid(n):
			n.queue_free()
	if is_instance_valid(player) and player.get_parent():
		player.get_parent().remove_child(player)
	foes.clear()
	npcs.clear()
	spikes.clear()
	chest = {}
	door_cells.clear()
	door_open = false
	door_sprite = null
	_exit_armed = false
	grid.assign(map.grid)
	var wood: bool = map.theme == "wood"
	floor_layer = Node2D.new()
	floor_layer.z_index = -10
	add_child(floor_layer)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	walls = StaticBody2D.new()
	walls.collision_layer = 1
	add_child(walls)
	var start := Vector2.ZERO
	var w := 0
	for row in grid:
		w = maxi(w, row.length())
	var h := grid.size()
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(T, T)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var ch := cell(c)
			if not _floorish(ch):
				astar.set_point_solid(c, true)
				if ch == "D":
					door_cells.append(c)
				if ch != " ":
					_collide(Rect2(c.x * T, c.y * T, T, T))
					if wood:
						_wood_wall(c)
					else:
						_wall_tile(c)
				elif _touches_floor(c):
					_collide(Rect2(c.x * T, c.y * T, T, T))
				continue
			_floor_tile(c, wood)
			match ch:
				"S": start = cell_center(c) + Vector2(0, 6)
				"g": _spawn_foe("g", c)
				"G": _spawn_foe("G", c)
				"a": _spawn_foe("a", c)
				"^": _spike(c)
				"c": _chest(c)
				"o": _prop("column", c, true, Vector2(0, 0))
				"x": _prop("crate", c, true, Vector2(0, 0))
				"k": _prop("skull", c, false, Vector2(0, 0))
	_door()
	for p in map.props:
		_place(p[0], Vector2(p[1], p[2]) * T, p[3])
	if map.has("bar_solid"):
		_collide(map.bar_solid, true)
	_people()
	if spawn != "" and map.spawns.has(spawn):
		start = map.spawns[spawn] * T
	elif start == Vector2.ZERO and not map.spawns.is_empty():
		start = map.spawns.values()[0] * T
	if player == null:
		player = TDHero.new()
		player.game = self
		player.hero = hero
	world.add_child(player)
	player.global_position = start
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	_link_cool = 0.4
	if camera == null:
		camera = Camera2D.new()
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 9.0
		add_child(camera)
	# Small rooms sit in the middle of the screen; big ones scroll.
	var pw := w * T
	var ph := h * T
	var mx := maxf(T * 2.0, (480.0 - pw) / 2.0)
	var my := maxf(T * 2.0, (270.0 - ph) / 2.0)
	camera.limit_left = int(-mx)
	camera.limit_top = int(-my - T)
	camera.limit_right = int(pw + mx)
	camera.limit_bottom = int(ph + my - T)
	camera.global_position = player.global_position
	camera.reset_smoothing()
	title_label.text = map.title
	if room_i >= 0:
		music.play("delve", 1.5)
		toast("ROOM %d OF %d: CLEAR THE GOBLINS TO OPEN THE DOOR" % [room_i + 1, ROOMS.size()])
		log_line("Room %d: %d goblins." % [room_i + 1, foes.size()])
	else:
		music.play("tavern", 1.5)


func _touches_floor(c: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if _floorish(cell(c + d)):
			return true
	return false


func _collide(r: Rect2, pathing := false) -> void:
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	shape.shape = rs
	shape.position = r.get_center()
	walls.add_child(shape)
	if pathing and astar:
		for y in range(floori(r.position.y / T), ceili(r.end.y / T)):
			for x in range(floori(r.position.x / T), ceili(r.end.x / T)):
				if astar.is_in_boundsv(Vector2i(x, y)):
					astar.set_point_solid(Vector2i(x, y), true)


func _floor_tile(c: Vector2i, wood: bool) -> void:
	var s := Sprite2D.new()
	if wood:
		# planks run east-west; each row of boards is offset so the seams don't line up
		var n := 1 + ((c.x * 3 + c.y * 5 + (c.x / 3) * 7) % 4)
		s.texture = TDArt.tex("floor_%d" % n)
	else:
		var n := 1 + ((c.x * 7 + c.y * 13) % 11)
		s.texture = TDArt.solo("floor_%d" % (n if n <= 8 else 1))
	s.position = cell_center(c)
	floor_layer.add_child(s)


## Wooden 3/4 walls. A wall with floor to its south shows its plank face, with its top (the cap)
## drawn one cell higher; west and east walls show their top with the inner edge; the south wall
## shows its top with the lip on the room side; inner corners get corner pieces; deep wall is mass.
## Every piece is parented to a node at the bottom of its cell so it y-sorts with people.
func _wood_wall(c: Vector2i) -> void:
	var f := func(dx: int, dy: int) -> bool: return _floorish(cell(c + Vector2i(dx, dy)))
	var base := Node2D.new()
	base.position = Vector2(c.x * T + T / 2.0, c.y * T + T)
	world.add_child(base)
	var piece := ""
	if f.call(0, 1):
		# The cap shows an end lip where the wall above it opens onto floor (a gap such as a stairwell).
		var cap := "wall_cap"
		if f.call(1, -1):
			cap = "wall_cap_l"
		elif f.call(-1, -1):
			cap = "wall_cap_r"
		_tspr(base, "wall_face", Vector2(0, -8))
		_tspr(base, cap, Vector2(0, -24))
		return
	if _under_cap(c):
		return          # the face below draws its cap over this cell
	# West and east walls keep their inner lip all the way up to the top row, so the top of
	# the side wall meets the north wall's cap in a clean T instead of stopping short.
	if f.call(1, 0) or f.call(1, 1) or f.call(1, 2):
		piece = "wall_side_l"
	elif f.call(-1, 0) or f.call(-1, 1) or f.call(-1, 2):
		piece = "wall_side_r"
	elif f.call(0, -1):
		piece = "wall_south"
	elif f.call(1, -1):
		piece = "wall_corner_sw"
	elif f.call(-1, -1):
		piece = "wall_corner_se"
	else:
		piece = "wall_mass"
	_tspr(base, piece, Vector2(0, -8))


## A wall cell directly above a face, which the face's cap covers.
func _under_cap(c: Vector2i) -> bool:
	var b := c + Vector2i(0, 1)
	return not _floorish(cell(b)) and cell(b) != " " and _floorish(cell(b + Vector2i(0, 1)))


## A wall cell that is part of a west or east wall rather than a north face.
func _is_side(c: Vector2i) -> bool:
	if _floorish(cell(c)) or cell(c) == " ":
		return false
	return not _floorish(cell(c + Vector2i(0, 1)))


func _tspr(parent: Node, name: String, off: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = TDArt.tex(name)
	s.position = off
	parent.add_child(s)
	return s


## A piece of furniture or decor. pos is the point it stands on (its bottom centre).
## floor: lies flat under everyone. wall: hangs on a north wall face (sorts with that wall).
func _place(name: String, pos: Vector2, o: Dictionary) -> void:
	var tex := TDArt.tex(name)
	if tex == null:
		push_warning("TD: no art for " + name)
		return
	var s := Sprite2D.new()
	s.texture = tex
	s.flip_h = bool(o.get("flip", false))
	if o.get("floor", false):
		s.position = pos
		floor_layer.add_child(s)
		s.z_index = 1
		return
	var base := Node2D.new()
	base.position = pos
	var lift := 0.0
	if o.get("wall", false):
		# Sort just in front of the bottom of the wall face it hangs on, wherever on the face it sits.
		base.position.y = (floorf((pos.y - 0.01) / T) + 1.0) * T + 0.5
		lift = base.position.y - pos.y
	world.add_child(base)
	s.offset = Vector2(0, -tex.get_height() / 2.0)
	s.position.y = -lift
	s.scale = Vector2.ONE * float(o.get("scale", 1.0))
	if o.has("tint"):
		s.modulate = o.tint
	base.add_child(s)
	for it in o.get("on", []):
		var t := Sprite2D.new()
		t.texture = TDArt.tex(it[0])
		t.position = Vector2(it[1], it[2])
		base.add_child(t)
	if name == "fireplace":
		var fire := Node2D.new()
		fire.set_script(preload("res://scripts/game/hearth_fire.gd"))
		fire.position = Vector2(0, -6)
		base.add_child(fire)
	if o.has("label"):
		var l := Label.new()
		l.label_settings = Art.label_settings(8, Color(1, 0.88, 0.55), 2)
		l.text = o.label
		l.size = Vector2(80, 10)
		l.position = Vector2(-40, -tex.get_height() - 10 - lift)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		base.add_child(l)
	if o.has("solid"):
		var sz: Array = o.solid
		_collide(Rect2(pos.x - sz[0] / 2.0, pos.y - sz[1], sz[0], sz[1]), true)


# ---------------- people ----------------

func _cast_data(key: String) -> Dictionary:
	for c in Inn.CAST + Inn.PATRONS:
		if c.key == key:
			return c
	for r in Inn.STAFF:
		if Inn.STAFF[r].key == key:
			return Inn.STAFF[r]
	return {"name": key.trim_prefix("npc_").capitalize(), "lines": ["..."]}


func _people() -> void:
	for d in map.npcs:
		var key: String = d[0]
		if key == "npc_" + hero.key:
			continue      # that's you
		var info := _cast_data(key)
		var n := InnNPC.make(key, info.name, Vector2(d[1], d[2]) * T, info.lines, d[4], d[3])
		world.add_child(n)
		npcs.append(n)
		if d.size() > 5 and d[5] != null:
			n.patrol = Vector2(d[5][0], d[5][1]) * T
			n.speed = 30.0
		else:
			_collide(Rect2(n.position.x - 5, n.position.y - 5, 10, 5), true)
		if d.size() > 6:
			_lift(n, float(d[6]))
		if key == "npc_dm":
			n.set_marker(not hero.quest_given)


## Draw someone higher than the point they sort at (sitting up on a stool in front of it).
func _lift(n: InnNPC, px: float) -> void:
	n.sprite.offset.y -= px
	for c in [n.tag, n.bubble, n.marker]:
		if c:
			c.position.y -= px


func npc_near() -> InnNPC:
	var best: InnNPC = null
	var bd := 30.0
	for n in npcs:
		var d := n.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = n
	return best


func _link_at(c: Vector2i, walk: bool) -> Dictionary:
	for l in map.links:
		if bool(l.get("walk", false)) == walk and l.cells.has(c):
			return l
	return {}


func _near_link() -> Dictionary:
	var pc := to_cell(player.global_position)
	for d in [Vector2i.ZERO, Vector2i(0, -1), Vector2i(0, 1)]:
		var l := _link_at(pc + d, false)
		if not l.is_empty():
			return l
	return {}


## E: open a chest, use a door, or talk to whoever is closest.
func interact() -> void:
	if try_open_chest():
		return
	var l := _near_link()
	if not l.is_empty():
		_follow(l)
		return
	var n := npc_near()
	if n:
		n.face_toward(player.global_position.x)
		if key_is(n, "npc_dm") and not hero.quest_given:
			hero.quest_given = true
			n.set_marker(false)
			n.say("Goblins in the cellar, hero. Under the trapdoor by the bar. Bring back what they stole.", 4.5)
			toast("QUEST ACCEPTED: CLEAR THE CELLAR")
			sfx.play("crit", -6.0)
		else:
			n.say(n.next_line(), 3.6)
			sfx.play("step", -8.0)


func key_is(n: InnNPC, k: String) -> bool:
	return n.key == k


func _follow(l: Dictionary) -> void:
	if l.to == "exit":
		if not _exit_armed:
			_exit_armed = true
			toast("PRESS E AGAIN TO RETURN TO SESSION SCRIBE")
			return
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.location.href = 'https://session-scribe.com/'")
		else:
			get_tree().quit()
		return
	if l.to == "dungeon1" and not hero.quest_given:
		toast("THE TRAPDOOR IS BARRED. TALK TO THE HOODED STRANGER FIRST.")
		player.global_position += Vector2(-10, -6)
		return
	sfx.play("step", -4.0)
	load_map(l.to, l.get("spawn", ""))


func _leave() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.location.search = ''")
	else:
		get_tree().quit()


func _spawn_foe(key: String, c: Vector2i) -> void:
	var f := TDFoe.new()
	f.game = self
	f.data = Creatures.monster(key)
	world.add_child(f)
	f.global_position = cell_center(c) + Vector2(0, 6)
	foes.append(f)


func living_foes() -> Array[TDFoe]:
	var out: Array[TDFoe] = []
	for f in foes:
		if is_instance_valid(f) and not f.dead:
			out.append(f)
	return out


# ---------------- dungeon pieces ----------------

## Stone 3/4 walls for the dungeon (0x72 tiles).
func _wall_tile(c: Vector2i) -> void:
	if cell(c) == "D":
		return
	var below := _floorish(cell(c + Vector2i(0, 1)))
	var above := _floorish(cell(c + Vector2i(0, -1)))
	var left := _floorish(cell(c + Vector2i(-1, 0)))
	var right := _floorish(cell(c + Vector2i(1, 0)))
	var base := Node2D.new()       # sorts by the bottom edge of the wall cell
	base.position = Vector2(c.x * T + T / 2.0, c.y * T + T)
	world.add_child(base)
	if below:
		_spr(base, "wall_mid", Vector2(0, -8))
		_spr(base, "wall_top_mid", Vector2(0, -24))
		if (c.x + c.y) % 7 == 3:
			_spr(base, ["wall_banner_red", "wall_banner_blue", "wall_banner_green"][c.x % 3], Vector2(0, -8))
	elif right:
		_spr(base, "wall_outer_mid_left", Vector2(0, -8))
	elif left:
		_spr(base, "wall_outer_mid_right", Vector2(0, -8))
	elif above:
		_spr(base, "wall_top_mid", Vector2(0, -8))
		_spr(base, "wall_mid", Vector2(0, 8))
	else:
		var dark := ColorRect.new()
		dark.color = Color(0.06, 0.05, 0.08)
		dark.size = Vector2(T, T)
		dark.position = Vector2(-T / 2.0, -T)
		base.add_child(dark)


func _spr(parent: Node, name: String, off: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = TDArt.solo(name) if name.begins_with("wall_") else Art.region(name)
	s.position = off
	parent.add_child(s)
	return s


func _prop(name: String, c: Vector2i, solid: bool, off: Vector2) -> void:
	var base := Node2D.new()
	base.position = Vector2(c.x * T + T / 2.0, c.y * T + T - 2)
	world.add_child(base)
	var s := _spr(base, name, off)
	s.offset = Vector2(0, -s.texture.get_size().y / 2.0 + 2)
	if solid:
		astar.set_point_solid(c, true)
		_collide(Rect2(c.x * T + 2, c.y * T + T - 9, 12, 8))


func _door() -> void:
	if door_cells.is_empty():
		return
	var a := door_cells[0]
	var base := Node2D.new()
	base.position = Vector2(a.x * T + T, a.y * T + T)
	world.add_child(base)
	door_sprite = _spr(base, "doors_leaf_closed", Vector2(0, -16))
	_spr(base, "doors_frame_top", Vector2(0, -36))


func _spike(c: Vector2i) -> void:
	var s := Sprite2D.new()
	s.texture = Art.region("floor_spikes_anim_f0")
	s.position = cell_center(c)
	floor_layer.add_child(s)
	spikes.append({"cell": c, "sprite": s, "up": false})


func _chest(c: Vector2i) -> void:
	var base := Node2D.new()
	base.position = Vector2(c.x * T + T / 2.0, c.y * T + T - 2)
	world.add_child(base)
	var s := _spr(base, "chest_full_open_anim_f0", Vector2(0, -8))
	chest = {"cell": c, "sprite": s, "open": false, "pos": base.position}
	astar.set_point_solid(c, true)


## Path for a goblin (world points), around walls and props.
func path_to(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := to_cell(from)
	var b := to_cell(to)
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b) or astar.is_point_solid(b):
		return PackedVector2Array()
	var pts := astar.get_point_path(a, b)
	for i in pts.size():
		pts[i] += Vector2(T / 2.0, T / 2.0)
	return pts


## Clear line between two points (for archers): no wall cell in the way.
func line_clear(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 6.0)
	for i in range(1, n):
		if is_wall(to_cell(a.lerp(b, i / float(n)))):
			return false
	return true


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	camera.global_position = player.global_position + Vector2(0, -8)
	_link_cool -= delta
	var pc := to_cell(player.global_position)
	if _link_cool <= 0.0:
		var l := _link_at(pc, true)
		if not l.is_empty():
			_link_cool = 0.6
			_follow(l)
			return
	_update_prompt()
	if room_i < 0:
		return
	# Spike traps: up for a second, down for two (5e: DC 13 Dex save, 2d4 piercing on a fail; half here on a success).
	_spike_t += delta
	var up := fmod(_spike_t, 3.0) < 1.0
	for s in spikes:
		if s.up != up:
			s.up = up
			(s.sprite as Sprite2D).texture = Art.region("floor_spikes_anim_f3" if up else "floor_spikes_anim_f0")
			if up and pc == s.cell:
				player.spike_hit()
	if not door_open and living_foes().is_empty() and not door_cells.is_empty():
		_open_door()
	if door_open:
		if door_cells.has(pc) or door_cells.has(pc + Vector2i(0, 1)) and player.global_position.y < door_cells[0].y * T + T + 4:
			load_map(map.next, map.next_spawn)


func _update_prompt() -> void:
	var near := npc_near()
	for n in npcs:
		if n.tag:
			n.tag.visible = n == near or n.global_position.distance_to(player.global_position) < 44.0
	var t := ""
	if chest_near():
		t = "E: OPEN THE CHEST"
	else:
		var l := _near_link()
		if not l.is_empty():
			t = "E: " + String(l.get("label", "ENTER"))
		else:
			var n := npc_near()
			if n:
				t = "E: TALK TO " + n.display_name.to_upper()
	prompt_label.text = t


func _open_door() -> void:
	door_open = true
	for c in door_cells:
		astar.set_point_solid(c, false)
	for sh in walls.get_children():
		var cs := sh as CollisionShape2D
		for c in door_cells:
			if cs.position == cell_center(c):
				cs.disabled = true
	if door_sprite:
		door_sprite.texture = Art.region("doors_leaf_open")
	sfx.play("thud", -4.0)
	toast("THE DOOR GRINDS OPEN." if room_i + 1 < ROOMS.size() else "ALL CLEAR! THE DOOR LEADS BACK UP TO THE TAPROOM.")


func try_open_chest() -> bool:
	if not chest_near():
		return false
	chest.open = true
	(chest.sprite as Sprite2D).texture = Art.region("chest_full_open_anim_f2")
	var faces: Array[int] = dice.roll(3, 6)
	var gp: int = faces.reduce(func(a, b): return a + b, 0) * 2
	gold += gp
	sfx.play("crit", -4.0)
	toast("THE CHEST HOLDS %d GP." % gp)
	log_line("Chest: 3d6 x2 = %d gp." % gp)
	return true


func chest_near() -> bool:
	return not chest.is_empty() and not chest.open and player.global_position.distance_to(chest.pos) <= 22.0


# ---------------- HUD ----------------

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	var top := _panel(Vector2(4, 4), Vector2(170, 34))
	var nm := _lab(top, Vector2(6, 3), "%s, %s" % [hero.short().to_upper(), hero.combat_stats().title.to_upper()], Color(1, 0.88, 0.55))
	nm.size = Vector2(160, 10)
	var back := ColorRect.new()
	back.color = Color(0.25, 0.08, 0.08)
	back.position = Vector2(6, 16)
	back.size = Vector2(110, 6)
	top.add_child(back)
	hp_bar = ColorRect.new()
	hp_bar.color = Color(0.85, 0.2, 0.2)
	hp_bar.position = Vector2(6, 16)
	hp_bar.size = Vector2(110, 6)
	top.add_child(hp_bar)
	hp_label = _lab(top, Vector2(120, 14), "", Color.WHITE)
	title_label = _lab(hud, Vector2(180, 4), "", Color(0.6, 0.85, 1.0))
	title_label.size = Vector2(296, 10)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var sub := _lab(hud, Vector2(180, 14), "TOP-DOWN PROTOTYPE", Color(0.5, 0.55, 0.65))
	sub.size = Vector2(296, 10)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt_label = _lab(hud, Vector2(0, 206), "", Color(1, 0.9, 0.5))
	prompt_label.size = Vector2(480, 10)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hints := _panel(Vector2(4, 186), Vector2(112, 80))
	_lab(hints, Vector2(5, 3), "WASD\nJ / CLICK\nSHIFT / K\nSPACE\nE\nH\nESC", Color(1, 0.85, 0.45))
	_lab(hints, Vector2(52, 3), "MOVE\nATTACK\nDODGE ROLL\nJUMP\nTALK / USE\nPOTION\nBACK TO GAME", Color(0.82, 0.8, 0.86))
	log_label = _lab(hud, Vector2(122, 222), "", Color(0.75, 0.75, 0.8))
	log_label.size = Vector2(354, 44)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label = _lab(hud, Vector2(0, 40), "", Color(1, 0.95, 0.75))
	toast_label.size = Vector2(480, 10)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _panel(pos: Vector2, size: Vector2) -> Control:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.09, 0.6)
	sb.border_color = Color(0.4, 0.34, 0.26)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.position = pos
	p.size = size
	hud.add_child(p)
	var holder := Control.new()
	p.add_child(holder)
	return holder


func _lab(parent: Node, pos: Vector2, text: String, col: Color) -> Label:
	var l := Label.new()
	l.label_settings = Art.label_settings(8, col, 2)
	l.label_settings.line_spacing = -2.0
	l.text = text
	l.position = pos
	parent.add_child(l)
	return l


func toast(t: String) -> void:
	toast_label.text = t
	_toast_t = 3.0


func log_line(t: String) -> void:
	_log.append(t)
	while _log.size() > 3:
		_log.pop_front()
	log_label.text = "\n".join(_log).to_upper()


func _process(delta: float) -> void:
	_toast_t -= delta
	toast_label.modulate.a = clampf(_toast_t, 0.0, 1.0)
	if is_instance_valid(player):
		hp_bar.size.x = 110.0 * clampf(player.hp / float(player.max_hp), 0.0, 1.0)
		hp_label.text = "HP %d/%d  GP %d" % [player.hp, player.max_hp, gold]
	if Input.is_action_just_pressed("back"):
		_leave()
