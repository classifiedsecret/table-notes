class_name Room
extends Node2D
## Builds a room from a text grid.
## '#' solid, '=' one-way platform, '^' spikes, 'P' player start, 'L'/'R' doors,
## 'b' banner, 'h' wall hole, 'c' column (decorations, not solid), '.' empty.

const T := 16
const LAYER_SOLID := 1
const LAYER_PLATFORM := 2

var rows: PackedStringArray
var w := 0
var h := 0
var player_spawn := Vector2.ZERO
var doors: Array[Vector2] = []
var spike_rects: Array[Rect2] = []
var spike_sprites: Array[AnimatedSprite2D] = []
var exit_pos := Vector2(-1000, -1000)
var exit_door: Sprite2D
var spawns: Array = []        # [key, position]
var chests: Array[Vector2] = []
var fires: Array[Vector2] = []
var darts: Array = []         # [position, direction]
var back_color := Color(0.36, 0.33, 0.42)

const WALL := Vector2i(2, 1)      # wall_mid at (32, 16)
const LIP := Vector2i(2, 0)       # wall_top_mid at (32, 0)

## Optional wood interior (the inn): a 48x16 strip of back planks, solid beam and top trim.
var wood_tiles: Texture2D = null


func build(text: String) -> void:
	rows = text.strip_edges(false, true).split("\n", false)
	h = rows.size()
	w = rows[0].length()
	var ts := _make_tileset()

	var back := TileMapLayer.new()
	back.tile_set = ts
	back.collision_enabled = false
	back.modulate = back_color
	back.z_index = -20
	add_child(back)

	var deco := Node2D.new()
	deco.z_index = -10
	add_child(deco)

	var solid := TileMapLayer.new()
	solid.tile_set = ts
	solid.z_index = -5
	add_child(solid)

	var lips := Node2D.new()
	lips.z_index = -4
	add_child(lips)

	var spike_frames := SpriteFrames.new()
	spike_frames.set_animation_speed("default", 6)
	spike_frames.set_animation_loop("default", true)
	for i in [0, 1, 2, 3, 3, 3, 2, 1, 0, 0, 0, 0]:
		spike_frames.add_frame("default", Art.region("floor_spikes_anim_f%d" % i))

	for y in h:
		for x in w:
			var ch := rows[y][x]
			var c := Vector2i(x, y)
			var src_id := 1 if wood_tiles else 0
			if ch != "#":
				back.set_cell(c, src_id, Vector2i(0, 0) if wood_tiles else WALL)
			match ch:
				"#":
					solid.set_cell(c, src_id, Vector2i(1, 0) if wood_tiles else WALL)
					if not is_solid_cell(x, y - 1) and y > 0:
						var lip := Sprite2D.new()
						if wood_tiles:
							var at := AtlasTexture.new()
							at.atlas = wood_tiles
							at.region = Rect2(32, 0, 16, 8)
							lip.texture = at
						else:
							lip.texture = Art.region("wall_top_mid")
						lip.position = Vector2(x * T + 8, y * T + (4 if wood_tiles else -4))
						lips.add_child(lip)
				"=":
					solid.set_cell(c, 0, LIP, 1)
				"^":
					var s := AnimatedSprite2D.new()
					s.sprite_frames = spike_frames
					s.position = Vector2(x * T + 8, y * T + 8)
					s.play()
					s.frame = x % 4
					deco.add_child(s)
					spike_sprites.append(s)
					spike_rects.append(Rect2(x * T, y * T + 9, T, 7))
				"P", "S":
					player_spawn = Vector2(x * T + 8, (y + 1) * T)
				"X":
					exit_pos = Vector2(x * T + 8, (y + 1) * T)
					exit_door = Sprite2D.new()
					exit_door.texture = Art.region("doors_leaf_closed")
					exit_door.position = Vector2(x * T + 8, (y + 1) * T - 16)
					deco.add_child(exit_door)
				"g", "G", "a", "B":
					spawns.append([ch, Vector2(x * T + 8, (y + 1) * T)])
				"C":
					chests.append(Vector2(x * T + 8, (y + 1) * T))
				"F":
					fires.append(Vector2(x * T + 8, (y + 1) * T))
				"D", "d":
					darts.append([Vector2(x * T + 8, y * T + 8), -1.0 if ch == "D" else 1.0])
				"L", "R":
					doors.append(Vector2(x * T + 8, (y + 1) * T))
					var door := Sprite2D.new()
					door.texture = Art.region("doors_leaf_closed")
					door.position = Vector2(x * T + 8, (y + 1) * T - 16)
					door.modulate = Color(0.8, 0.75, 0.8)
					deco.add_child(door)
				"b":
					var b := Sprite2D.new()
					b.texture = Art.region(["wall_banner_red", "wall_banner_blue", "wall_banner_green"][x % 3])
					b.position = Vector2(x * T + 8, y * T + 8)
					deco.add_child(b)
				"h":
					var hole := Sprite2D.new()
					hole.texture = Art.region("wall_hole_%d" % (1 + x % 2))
					hole.position = Vector2(x * T + 8, y * T + 8)
					hole.modulate = Color(0.7, 0.65, 0.75)
					deco.add_child(hole)
				"c":
					var col := Sprite2D.new()
					col.texture = Art.region("column")
					var floor_y := _floor_below(x, y)
					col.position = Vector2(x * T + 8, floor_y - 24)
					col.modulate = Color(0.6, 0.56, 0.66)
					deco.add_child(col)


func _floor_below(x: int, y: int) -> float:
	var yy := y
	while yy < h and not is_solid_cell(x, yy):
		yy += 1
	return yy * T


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, LAYER_SOLID)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, LAYER_PLATFORM)
	ts.set_physics_layer_collision_mask(1, 0)
	var src := TileSetAtlasSource.new()
	src.texture = Art.ATLAS
	src.texture_region_size = Vector2i(T, T)
	ts.add_source(src, 0)
	src.create_tile(WALL)
	var td := src.get_tile_data(WALL, 0)
	td.add_collision_polygon(0)
	td.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	src.create_tile(LIP)
	var alt := src.create_alternative_tile(LIP, 1)
	var pd := src.get_tile_data(LIP, alt)
	pd.texture_origin = Vector2i(0, 12)
	pd.add_collision_polygon(1)
	pd.set_collision_polygon_points(1, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -3), Vector2(-8, -3)]))
	pd.set_collision_polygon_one_way(1, 0, true)
	if wood_tiles:
		var ws := TileSetAtlasSource.new()
		ws.texture = wood_tiles
		ws.texture_region_size = Vector2i(T, T)
		ts.add_source(ws, 1)
		ws.create_tile(Vector2i(0, 0))
		ws.create_tile(Vector2i(1, 0))
		var wd := ws.get_tile_data(Vector2i(1, 0), 0)
		wd.add_collision_polygon(0)
		wd.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	return ts


func is_solid_cell(x: int, y: int) -> bool:
	if y < 0 or y >= h or x < 0 or x >= w:
		return true
	return rows[y][x] == "#"


func is_ground_at(p: Vector2) -> bool:
	var x := floori(p.x / T)
	var y := floori(p.y / T)
	if y < 0 or y >= h or x < 0 or x >= w:
		return true
	var ch := rows[y][x]
	return ch == "#" or ch == "="


func open_exit() -> void:
	if exit_door:
		exit_door.texture = Art.region("doors_leaf_open")


func size_px() -> Vector2:
	return Vector2(w * T, h * T)
