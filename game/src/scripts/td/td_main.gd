class_name TDMain
extends Node2D
## TOP-DOWN TEST ROOM (prototype). A 3/4 top-down take on Vanguard's Descent, in the style of
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
var world: Node2D          # y-sorted: walls, props, hero and goblins
var floor_layer: Node2D
var walls: StaticBody2D
var room_i := 0
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
var _toast_t := 0.0
var _spike_t := 0.0
var _log: Array[String] = []
var gold := 0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sfx = Sfx.new()
	add_child(sfx)
	music = Music.new()
	music.game = self
	add_child(music)
	music.play("delve", 1.5)
	hero = Hero.new()
	var hk := _url_value("hero")
	hero.set_key(hk if Kits.has(hk) else "boarvhal")
	hero.level = 3
	_build_hud()
	_load_room(0)


func _url_value(key: String) -> String:
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if q is String and (q as String).contains(key + "="):
			return (q as String).get_slice(key + "=", 1).get_slice("&", 0)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % key):
			return a.substr(key.length() + 3)
	return ""


# ---------------- rooms ----------------

func cell(c: Vector2i) -> String:
	if c.y < 0 or c.y >= grid.size() or c.x < 0 or c.x >= grid[c.y].length():
		return "#"
	return grid[c.y][c.x]


func is_wall(c: Vector2i) -> bool:
	var ch := cell(c)
	return ch == "#" or (ch == "D" and not door_open)


func to_cell(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T / 2.0, c.y * T + T / 2.0)


func _load_room(i: int) -> void:
	room_i = i
	for n in [world, floor_layer, walls]:
		if is_instance_valid(n):
			n.queue_free()
	foes.clear()
	spikes.clear()
	chest = {}
	door_cells.clear()
	door_open = false
	grid.assign(ROOMS[i])
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
	var w := grid[0].length()
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
			if ch == "#" or ch == "D":
				astar.set_point_solid(c, true)
				if ch == "D":
					door_cells.append(c)
				_wall_tile(c)
				continue
			_floor_tile(c)
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
	if player == null:
		player = TDHero.new()
		player.game = self
		player.hero = hero
		world.add_child(player)
	else:
		player.get_parent().remove_child(player)
		world.add_child(player)
	player.global_position = start
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	if camera == null:
		camera = Camera2D.new()
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 9.0
		add_child(camera)
	camera.limit_left = -T * 2
	camera.limit_top = -T * 3
	camera.limit_right = w * T + T * 2
	camera.limit_bottom = h * T + T * 2
	camera.global_position = player.global_position
	camera.reset_smoothing()
	toast("ROOM %d OF %d: CLEAR THE GOBLINS TO OPEN THE DOOR" % [i + 1, ROOMS.size()])
	log_line("Room %d: %d goblins." % [i + 1, foes.size()])


func _floor_tile(c: Vector2i) -> void:
	var s := Sprite2D.new()
	var n := 1 + ((c.x * 7 + c.y * 13) % 11)
	s.texture = Art.region("floor_%d" % (n if n <= 8 else 1))
	s.position = cell_center(c)
	floor_layer.add_child(s)


## 3/4 walls: a wall with floor in front of it (to the south) shows its face, with its top cap
## one cell above; walls along the sides show their edge; the south wall shows its top.
func _wall_tile(c: Vector2i) -> void:
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(T, T)
	shape.shape = r
	shape.position = cell_center(c)
	walls.add_child(shape)
	if cell(c) == "D":
		return
	var below := not _solid_char(cell(c + Vector2i(0, 1)))
	var above := not _solid_char(cell(c + Vector2i(0, -1)))
	var left := not _solid_char(cell(c + Vector2i(-1, 0)))
	var right := not _solid_char(cell(c + Vector2i(1, 0)))
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


func _solid_char(ch: String) -> bool:
	return ch == "#" or ch == "D"


func _spr(parent: Node, name: String, off: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.region(name)
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
		var shape := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(12, 8)
		shape.shape = r
		shape.position = Vector2(c.x * T + T / 2.0, c.y * T + T - 5)
		walls.add_child(shape)


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
	if camera and is_instance_valid(player):
		camera.global_position = player.global_position + Vector2(0, -8)
	# Spike traps: up for a second, down for two (5e: DC 13 Dex save, 2d4 piercing on a fail; half here on a success).
	_spike_t += delta
	var up := fmod(_spike_t, 3.0) < 1.0
	for s in spikes:
		if s.up != up:
			s.up = up
			(s.sprite as Sprite2D).texture = Art.region("floor_spikes_anim_f3" if up else "floor_spikes_anim_f0")
			if up and is_instance_valid(player) and to_cell(player.global_position) == s.cell:
				player.spike_hit()
	if not door_open and living_foes().is_empty() and not door_cells.is_empty():
		_open_door()
	if door_open and is_instance_valid(player):
		var pc := to_cell(player.global_position)
		if door_cells.has(pc) or door_cells.has(pc + Vector2i(0, 1)) and player.global_position.y < door_cells[0].y * T + T + 4:
			if room_i + 1 < ROOMS.size():
				_load_room(room_i + 1)
			else:
				toast("TEST COMPLETE! ESC RETURNS TO THE GAME.")


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
	toast("THE DOOR GRINDS OPEN." if room_i + 1 < ROOMS.size() else "ALL CLEAR! WALK THROUGH THE DOOR TO FINISH.")


func try_open_chest() -> bool:
	if chest.is_empty() or chest.open:
		return false
	if player.global_position.distance_to(chest.pos) > 22.0:
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
	var title := _lab(hud, Vector2(180, 4), "TOP-DOWN TEST ROOM (PROTOTYPE)", Color(0.6, 0.85, 1.0))
	title.size = Vector2(296, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var hints := _panel(Vector2(4, 186), Vector2(112, 80))
	_lab(hints, Vector2(5, 3), "WASD\nJ / CLICK\nSHIFT / K\nSPACE\nE\nH\nESC", Color(1, 0.85, 0.45))
	_lab(hints, Vector2(52, 3), "MOVE\nATTACK\nDODGE ROLL\nJUMP\nOPEN CHEST\nPOTION\nBACK TO GAME", Color(0.82, 0.8, 0.86))
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
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.location.search = ''")
		else:
			get_tree().quit()
