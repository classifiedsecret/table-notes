class_name TDRooms
extends RefCounted
## The Goblin Warren in top-down: cave rooms drawn as text. normalize() closes any gaps with rock,
## fills enclosed hollows, and pads rows, so the shapes can be drawn loosely.
##
## # rock   . floor   S start   X the way on (a tunnel in a north face, barred until cleared)
## g goblin minion   G goblin warrior   a goblin archer   B the Bugbear Chief
## ^ spikes   d dart trap (fires away from the nearest wall)   c chest   f campfire
## o stalagmite   r rocks   k bones   m glowcaps   w puddle   t torch   T tent   p totem   b bedroll   H throne

const POOL := {
	"combat": ["combat_1", "combat_2", "combat_3"],
	"gauntlet": ["gauntlet_1", "gauntlet_2"],
	"treasure": ["treasure_1"],
	"campfire": ["campfire_1"],
	"elite": ["elite_1"],
	"boss": ["boss"],
}

const ROOMS := {
	"combat_1": [
		"     ##############",
		"   ###....X.......###",
		"  ##..........o.....##",
		" ##...t..............###",
		" #.......g......k......##",
		"##..o.........r.....g...#",
		"#.......................#",
		"#...m.....G.........t...#",
		"##.....................##",
		" ##.......S.......w....#",
		"  ###.................##",
		"    ####...........####",
		"       #############",
	],
	"combat_2": [
		"   ########         ########",
		"  ##......##########....X..##",
		" ##..g.......o..........m...##",
		" #......t........a.......o...#",
		" #...r....................g..#",
		" ##.......####......t.......##",
		"  #......##  ##.............#",
		"  ##....##    ##....k......##",
		"   #.S..#      #..........##",
		"   ##...##    ##.....g...##",
		"    ##...######.........##",
		"     ##................##",
		"      ##################",
	],
	"combat_3": [
		" ###########################",
		"##.........k..........X....##",
		"#..t....g.........o.....a...#",
		"#.......................t...#",
		"##..o.....###......g.......##",
		" #........# #..............#",
		" ##.......###....w.......###",
		"  #..g.......r..........##",
		"  ##.S............m....##",
		"   ####..............###",
		"      ################",
	],
	"elite_1": [
		"      ##################",
		"    ###.......X........###",
		"   ##..t...p......p...t..##",
		"  ##......................##",
		"  #....G........T......G...#",
		"  #..........................#",
		" ##..o.....a........a....o..##",
		" #...........................#",
		" ##....b.......g.......b....##",
		"  ##.........................#",
		"   ###.......S.........m...##",
		"     ####..............#####",
		"        ################",
	],
	"gauntlet_1": [
		" ######################################",
		"##....^^.....d........^^......^^...X..##",
		"#.S...^^...........o..^^..g...^^......#",
		"#.....^^..t....^^.....^^......^^..t...#",
		"##...........d^^............m.......##",
		" ######...........######..........###",
		"      ####################.......##",
		"                         #########",
	],
	"gauntlet_2": [
		"   ##########",
		"  ##...X....##",
		"  #...^^^....#",
		"  #d........##",
		"  ##..^^^...#",
		"   #........d#",
		"  ##...^^^..#",
		"  #d.........#",
		"  ##..t......##",
		"   #...^^^....#",
		"   ##.......a.#",
		"    #d.^^^...##",
		"    ##.......#",
		"     ##..S..##",
		"      #######",
	],
	"treasure_1": [
		"    ##############",
		"  ###.....X......###",
		" ##...m........m...##",
		" #.....###..###.....#",
		" #..t..#      #..t..#",
		" ##....##.c..##....##",
		"  #.....#....#.....#",
		"  ##..g.##..##.g..##",
		"   #....... .......#",
		"   ##.....S......##",
		"    ###.........###",
		"      ###########",
	],
	"campfire_1": [
		"    ############",
		"  ###....X.....###",
		" ##..m.........m.##",
		" #.....b....b.....#",
		" #........f.......#",
		" ##...b......b...##",
		"  #....k.........#",
		"  ##.....S.....w##",
		"   ###.........##",
		"     ##########",
	],
	"boss": [
		"   ##############################",
		"  ##..............H.............##",
		" ##..t.....p..............p...t..##",
		" #................................#",
		" #....o......................o....#",
		"##................................##",
		"#.......T....................T.....#",
		"#.....................................#",
		"#..................................#",
		"##.......o......B........o........##",
		" #................................#",
		" ##..t.....................a...t..##",
		"  ##..........S..................##",
		"   ###########################.###",
		"                             ###",
	],
}


static func grid(name: String) -> Array[String]:
	return normalize(ROOMS[name])


static func normalize(src: Array) -> Array[String]:
	var w := 0
	for r in src:
		w = maxi(w, (r as String).length())
	w += 2
	var g: Array = []
	g.append(" ".repeat(w))
	for r in src:
		g.append((" " + (r as String)).rpad(w))
	g.append(" ".repeat(w))
	var h := g.size()
	var cells := []
	for y in h:
		cells.append(Array((g[y] as String).split("")))
	# Close gaps: nothing walkable may touch the void outside.
	for y in h:
		for x in w:
			if cells[y][x] != " " and cells[y][x] != "#":
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var yy: int = y + dy
						var xx: int = x + dx
						if yy >= 0 and yy < h and xx >= 0 and xx < w and cells[yy][xx] == " ":
							cells[yy][xx] = "#"
	# Hollows inside the rock (void not connected to the outside) become solid rock.
	var outside := {}
	var todo: Array[Vector2i] = [Vector2i(0, 0)]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h or outside.has(c) or cells[c.y][c.x] != " ":
			continue
		outside[c] = true
		todo.append_array([c + Vector2i(1, 0), c + Vector2i(-1, 0), c + Vector2i(0, 1), c + Vector2i(0, -1)])
	var out: Array[String] = []
	for y in h:
		for x in w:
			if cells[y][x] == " " and not outside.has(Vector2i(x, y)):
				cells[y][x] = "#"
		out.append("".join(cells[y]))
	return out

