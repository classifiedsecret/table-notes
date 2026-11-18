class_name World
extends Node2D
## One top-down map: the inn's taproom, hallway and rooms, or a cave room in the Goblin Warren.
## Builds floor, walls that join up (3/4 view: a face with its cap above, side and south lips,
## corners), furniture and decor, people, exits, and the darkness of the warren.
##
## Everything that moves (hero, companions, goblins, chests, fires) lives in `ysort` so that
## whoever stands further south draws in front.

const T := 16
const LAYER_SOLID := 1

## Who sees in the dark (60 feet). Goliaths don't: Boar-vhal carries a torch below.
const DARKVISION := {"erwar": true, "lyburnum": true, "suilean": true, "ceridwen": true, "galinnadin": true, "orfi": false, "boarvhal": false}
const DARKVISION_PX := 192.0    # 60 feet
const TORCH_PX := 128.0         # a torch: 20 feet bright, 20 more dim

var game: Node
var map: Dictionary = {}
var rows: Array[String] = []
var w := 0
var h := 0
var theme := "wood"
var floor_layer: Node2D
var ysort: Node2D
var walls: StaticBody2D
var astar: AStarGrid2D
var player_spawn := Vector2.ZERO
var spawns: Array = []        # [monster key, position]
var chests: Array[Vector2] = []
var fires: Array[Vector2] = []
var darts: Array = []         # [position, direction Vector2]
var spikes: Array = []        # {cell, sprite, up}
var exit_pos := Vector2(-1000, -1000)
var exit_sprite: Sprite2D
var exit_opened := false
var npcs: Array[InnNPC] = []
var links: Array = []
var dark := false
var lights: Array = []        # [node or position, radius, kind 0 warm / 1 cool]
var _dark_rect: ColorRect
var _dark_mat: ShaderMaterial
var _spike_t := 0.0


# ---------------- building ----------------

func build(g: Node, m: Dictionary) -> void:
	game = g
	map = m
	theme = str(m.get("theme", "wood"))
	dark = bool(m.get("dark", false))
	rows.assign(m.grid)
	h = rows.size()
	w = 0
	for r in rows:
		w = maxi(w, r.length())
	floor_layer = Node2D.new()
	floor_layer.z_index = -10
	add_child(floor_layer)
	ysort = Node2D.new()
	ysort.y_sort_enabled = true
	add_child(ysort)
	walls = StaticBody2D.new()
	walls.collision_layer = LAYER_SOLID
	walls.collision_mask = 0
	add_child(walls)
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, w, h)
	astar.cell_size = Vector2(T, T)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in h:
		for x in w:
			var c := Vector2i(x, y)
			var ch := cell(c)
			if not floorish(ch):
				astar.set_point_solid(c, true)
				if ch == "#":
					_collide(Rect2(c.x * T, c.y * T, T, T))
					_wall(c)
				elif _touches_floor(c):
					_collide(Rect2(c.x * T, c.y * T, T, T))
				continue
			_floor_tile(c)
			_cell_content(c, ch)
	for p in m.get("props", []):
		place(p[0], Vector2(p[1], p[2]) * T, p[3])
	if m.has("bar_solid"):
		_collide(m.bar_solid, true)
	links = m.get("links", [])
	if dark:
		_build_darkness()


func cell(c: Vector2i) -> String:
	if c.y < 0 or c.y >= h or c.x < 0 or c.x >= rows[c.y].length():
		return " "
	return rows[c.y][c.x]


func floorish(ch: String) -> bool:
	return ch != "#" and ch != " "


func is_solid_cell(x: int, y: int) -> bool:
	return not floorish(cell(Vector2i(x, y)))


func is_wall_at(p: Vector2) -> bool:
	return not floorish(cell(to_cell(p)))


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T / 2.0, c.y * T + T / 2.0)


func size_px() -> Vector2:
	return Vector2(w * T, h * T)


func _touches_floor(c: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if floorish(cell(c + d)):
			return true
	return false


func _collide(r: Rect2, pathing := false) -> void:
	var shape := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	shape.shape = rs
	shape.position = r.get_center()
	walls.add_child(shape)
	if pathing:
		var mid := to_cell(r.get_center())
		if astar.is_in_boundsv(mid):
			astar.set_point_solid(mid, true)
		for y in range(floori(r.position.y / T), ceili(r.end.y / T)):
			for x in range(floori(r.position.x / T), ceili(r.end.x / T)):
				# Only block cells mostly covered, so narrow props don't seal corridors.
				var cr := Rect2(x * T, y * T, T, T).intersection(r)
				if astar.is_in_boundsv(Vector2i(x, y)) and cr.get_area() >= T * T * 0.3:
					astar.set_point_solid(Vector2i(x, y), true)


func _floor_tile(c: Vector2i) -> void:
	var s := Sprite2D.new()
	if theme == "cave":
		s.texture = TDArt.tex("dirt_%d" % (1 + ((c.x * 7 + c.y * 13 + (c.x * c.y) % 5) % 4)))
	else:
		s.texture = TDArt.tex("floor_%d" % (1 + ((c.x * 3 + c.y * 5 + (c.x / 3) * 7) % 4)))
	s.position = cell_center(c)
	floor_layer.add_child(s)


## Walls in 3/4 view. A wall with floor to its south shows its face, with the cap one cell up;
## west and east walls show their top with the inner lip, carried up to the top row so they meet
## the north cap in a clean T; the south wall shows its lip along the top; inner corners join.
func _wall(c: Vector2i) -> void:
	var pre := "cave_" if theme == "cave" else "wall_"
	var f := func(dx: int, dy: int) -> bool: return floorish(cell(c + Vector2i(dx, dy)))
	var base := Node2D.new()
	base.position = Vector2(c.x * T + T / 2.0, c.y * T + T)
	ysort.add_child(base)
	if f.call(0, 1):
		var cap := "cap"
		if f.call(1, -1):
			cap = "cap_l"
		elif f.call(-1, -1):
			cap = "cap_r"
		_tspr(base, pre + "face", Vector2(0, -8))
		if not f.call(0, -1):
			_tspr(base, pre + cap, Vector2(0, -24))
		return
	if _under_cap(c):
		return
	var piece := "mass"
	if f.call(1, 0) or f.call(1, 1) or f.call(1, 2):
		piece = "side_l"
	elif f.call(-1, 0) or f.call(-1, 1) or f.call(-1, 2):
		piece = "side_r"
	elif f.call(0, -1):
		piece = "south"
	elif f.call(1, -1):
		piece = "corner_sw"
	elif f.call(-1, -1):
		piece = "corner_se"
	_tspr(base, pre + piece, Vector2(0, -8))


func _under_cap(c: Vector2i) -> bool:
	var b := c + Vector2i(0, 1)
	return cell(b) == "#" and floorish(cell(b + Vector2i(0, 1)))


func _tspr(parent: Node, name: String, off: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = TDArt.tex(name)
	s.position = off
	parent.add_child(s)
	return s


## What a dungeon map cell holds besides floor.
func _cell_content(c: Vector2i, ch: String) -> void:
	var foot := Vector2(c.x * T + T / 2.0, c.y * T + T - 3)
	match ch:
		"S": player_spawn = foot
		"g": spawns.append(["minion", foot])
		"G": spawns.append(["warrior", foot])
		"a": spawns.append(["archer", foot])
		"B": spawns.append(["B", foot])
		"^": _spike(c)
		"c": chests.append(foot)
		"f": fires.append(foot)
		"d": _dart(c)
		"X":
			exit_pos = foot
			var base := Node2D.new()
			base.position = Vector2(c.x * T + T / 2.0, c.y * T + 0.5)
			ysort.add_child(base)
			exit_sprite = Sprite2D.new()
			exit_sprite.texture = TDArt.tex("tunnel_barred")
			exit_sprite.offset = Vector2(0, -15)
			base.add_child(exit_sprite)
		"o": place("stalagmite", foot + Vector2(0, 2), {"solid": [10, 6]})
		"r": place("rocks", foot + Vector2(0, 2), {"solid": [14, 6]})
		"k": place("bones", cell_center(c), {"floor": true})
		"m":
			place("glowcap", foot + Vector2(0, 2), {})
			add_light(cell_center(c), 40.0, 1)
		"w": place("puddle", cell_center(c), {"floor": true})
		"t":
			place("torch_post", foot + Vector2(0, 2), {"solid": [6, 4]})
			add_light(foot + Vector2(0, -16), TORCH_PX * 0.8, 0)
		"T": place("goblin_tent", foot + Vector2(0, 2), {"solid": [28, 10]})
		"p": place("totem", foot + Vector2(0, 2), {"solid": [8, 5]})
		"b": place("bedroll", cell_center(c), {"floor": true})
		"H": place("throne", foot + Vector2(0, 2), {"solid": [26, 10]})


func _spike(c: Vector2i) -> void:
	var s := Sprite2D.new()
	s.texture = TDArt.solo("floor_spikes_anim_f0")
	s.position = cell_center(c)
	floor_layer.add_child(s)
	s.z_index = 1
	spikes.append({"cell": c, "sprite": s, "up": false})


## A dart trap set in the nearest wall, firing across the room.
func _dart(c: Vector2i) -> void:
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		if not floorish(cell(c + d)):
			darts.append([cell_center(c) - Vector2(d) * 6.0, -Vector2(d)])
			return
	darts.append([cell_center(c), Vector2.RIGHT])


## A piece of furniture or decor. pos is the point it stands on (its bottom centre).
## floor: lies flat under everyone. wall: hangs on a north wall face and sorts with that wall.
func place(name: String, pos: Vector2, o: Dictionary) -> Node2D:
	var tex := TDArt.tex(name)
	if tex == null:
		push_warning("World: no art for " + name)
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.flip_h = bool(o.get("flip", false))
	if o.has("tint"):
		s.modulate = o.tint
	if o.get("floor", false):
		s.position = pos
		s.z_index = 1
		floor_layer.add_child(s)
		return s
	var base := Node2D.new()
	base.position = pos
	var lift := 0.0
	if o.get("wall", false):
		base.position.y = (floorf((pos.y - 0.01) / T) + 1.0) * T + 0.5
		lift = base.position.y - pos.y
	ysort.add_child(base)
	s.offset = Vector2(0, -tex.get_height() / 2.0)
	s.position.y = -lift
	s.scale = Vector2.ONE * float(o.get("scale", 1.0))
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
		add_light(pos + Vector2(0, -10), 110.0, 0)
	if name == "sconce":
		add_light(pos + Vector2(0, -6), 70.0, 0)
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
	return base


## Adds a person standing or sitting in the inn. Returns the InnNPC (already in the y-sort).
func add_npc(key: String, nm: String, pos: Vector2, talk: Array, sit: bool, face: int, lift := 0.0, solid := true) -> InnNPC:
	var n := InnNPC.make(key, nm, pos, talk, sit, face)
	ysort.add_child(n)
	npcs.append(n)
	if solid:
		_collide(Rect2(pos.x - 5, pos.y - 5, 10, 5), true)
	if lift != 0.0:
		n.sprite.offset.y -= lift
		for c in [n.tag, n.bubble, n.marker]:
			if c:
				c.position.y -= lift
	return n


# ---------------- moving about ----------------

## Path for a goblin (world points), around walls and props.
func path_to(from: Vector2, to: Vector2) -> PackedVector2Array:
	var a := to_cell(from)
	var b := to_cell(to)
	if not astar.is_in_boundsv(a) or not astar.is_in_boundsv(b):
		return PackedVector2Array()
	if astar.is_point_solid(b):
		# Aim for the nearest open cell next to the target instead.
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			if astar.is_in_boundsv(b + d) and not astar.is_point_solid(b + d):
				b = b + d
				break
	var pts := astar.get_point_path(a, b, true)
	for i in pts.size():
		pts[i] += Vector2(T / 2.0, T / 2.0)
	return pts


## Clear line between two points: no wall cell in the way.
func line_clear(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 6.0)
	for i in range(1, n):
		if is_wall_at(a.lerp(b, i / float(n))):
			return false
	return true


## The nearest open floor point to p (for pulls, pushes and arrivals).
func open_spot(p: Vector2) -> Vector2:
	var c := to_cell(p)
	if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
		return p
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var cc := c + Vector2i(dx, dy)
				if astar.is_in_boundsv(cc) and not astar.is_point_solid(cc):
					return cell_center(cc) + Vector2(0, 5)
	return p


func link_at(c: Vector2i, walk: bool) -> Dictionary:
	for l in links:
		if bool(l.get("walk", false)) == walk and l.cells.has(c):
			return l
	return {}


func near_link(p: Vector2) -> Dictionary:
	var pc := to_cell(p)
	for d in [Vector2i.ZERO, Vector2i(0, -1), Vector2i(0, 1)]:
		var l := link_at(pc + d, false)
		if not l.is_empty():
			return l
	return {}


func open_exit() -> void:
	exit_opened = true
	if exit_sprite:
		exit_sprite.texture = TDArt.tex("tunnel")
		game.sfx.play("thud", -6.0)


## Spikes: up for a second, down for two. True if a spike is up under p.
func spike_up_at(p: Vector2) -> bool:
	var c := to_cell(p)
	for s in spikes:
		if s.up and s.cell == c:
			return true
	return false


func _process(delta: float) -> void:
	if not spikes.is_empty():
		_spike_t += delta
		var up := fmod(_spike_t, 3.0) < 1.0
		for s in spikes:
			if s.up != up:
				s.up = up
				(s.sprite as Sprite2D).texture = TDArt.solo("floor_spikes_anim_f3" if up else "floor_spikes_anim_f0")
	if dark:
		_update_darkness()


# ---------------- darkness and darkvision ----------------

func add_light(at: Variant, radius: float, kind: int) -> void:
	lights.append([at, radius, kind])


func _build_darkness() -> void:
	_dark_rect = ColorRect.new()
	_dark_rect.position = Vector2(-T * 8, -T * 8)
	_dark_rect.size = size_px() + Vector2(T * 16, T * 16)
	_dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dark_rect.z_index = 40
	_dark_mat = ShaderMaterial.new()
	_dark_mat.shader = preload("res://scripts/td/darkness.gdshader")
	_dark_rect.material = _dark_mat
	add_child(_dark_rect)


## The hero's own sight: darkvision (60 ft, colours drain to grey) or a torch for Boar-vhal.
func _update_darkness() -> void:
	var pts := PackedVector4Array()
	var hero_key: String = game.hero.key if game and "hero" in game and game.hero else ""
	var p: Node2D = game.player if game and "player" in game else null
	if p and is_instance_valid(p):
		var eye := p.global_position + Vector2(0, -10)
		if DARKVISION.get(hero_key, false):
			pts.append(Vector4(eye.x, eye.y, DARKVISION_PX, 1.0))
			pts.append(Vector4(eye.x, eye.y, 30.0, 0.0))       # a little candle-light of your own
		else:
			pts.append(Vector4(eye.x, eye.y, TORCH_PX * (0.96 + 0.04 * sin(Time.get_ticks_msec() * 0.011)), 0.0))
	for l in lights:
		var at: Vector2 = l[0].global_position if l[0] is Node2D else l[0]
		var flick: float = 1.0 if l[2] == 1 else 0.94 + 0.06 * sin(Time.get_ticks_msec() * 0.009 + at.x)
		pts.append(Vector4(at.x, at.y, l[1] * flick, float(l[2]) * 2.0))   # 0 warm, 2 cool (glowcaps)
		if pts.size() >= 31:
			break
	_dark_mat.set_shader_parameter("light_count", pts.size())
	_dark_mat.set_shader_parameter("lights", pts)
