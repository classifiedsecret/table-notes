class_name TDMaps
extends RefCounted
## Maps for the top-down prototype: the Gryphon's Roost (taproom, upstairs hallway, five
## private rooms). The cellar rooms are in TDRooms.
##
## Grid legend: # wall, . floor, (space) nothing.
## Props: [name, x tiles, y tiles, options]. (x, y) is the point the prop stands on (its
## bottom centre), so depth sorting works; "wall" props hang on a wall face, "floor" props
## lie flat (centred on the point), "solid" gives a footprint [w, h] in pixels.
## NPCs: [key, x, y, face (1 east / -1 west), sitting?, patrol [x0, x1] or null, lift px]. Lift raises
## the drawn sprite above its sorting point (someone perched on a bar stool). Links: walk-on or press-E exits.

const BARREL := Color(0.72, 0.62, 0.55)   # barrels darker than the floorboards so they read
const HEROES := ["boarvhal", "erwar", "lyburnum", "suilean", "ceridwen"]
const HALL_DOOR_COL := {"boarvhal": 4, "erwar": 10, "lyburnum": 16, "suilean": 22, "ceridwen": 28}


static func _box(w: int, h: int, north_gaps: Array = [], south_gaps: Array = []) -> Array[String]:
	var g: Array[String] = []
	for y in h:
		var row := ""
		for x in w:
			var wall := y <= 1 or y == h - 2 or x == 0 or x == w - 1
			if y == h - 1:
				row += " "
				continue
			if (y <= 1 and north_gaps.has(x)) or (y == h - 2 and south_gaps.has(x)):
				wall = false
			row += "#" if wall else "."
		g.append(row)
	return g


static func taproom() -> Dictionary:
	return {
		"title": "THE GRYPHON'S ROOST - TAPROOM", "theme": "wood",
		"grid": _box(36, 18, [32, 33], [4, 5]),
		"spawns": {"stairs": Vector2(33.0, 5.2), "cellar": Vector2(29.5, 14.2), "door": Vector2(5.0, 14.6)},
		"links": [
			{"cells": [Vector2i(32, 1), Vector2i(33, 1), Vector2i(32, 0), Vector2i(33, 0)], "to": "upstairs", "spawn": "stairs", "walk": true},
			{"cells": [Vector2i(31, 13), Vector2i(32, 13), Vector2i(31, 14), Vector2i(32, 14)], "to": "cellar", "spawn": "ladder", "walk": true},
			{"cells": [Vector2i(4, 15), Vector2i(5, 15), Vector2i(4, 16), Vector2i(5, 16)], "to": "exit", "label": "EXIT TO SESSION SCRIBE"},
		],
		"props": [
			["fireplace", 4.5, 3.0, {"solid": [44, 10]}],
			["rug_big", 4.5, 5.4, {"floor": true}],
			["couch_side", 1.75, 8.0, {"solid": [20, 40]}],
			["stage", 11.5, 3.0, {"floor": true}],
			["banner_green", 8.0, 2.0, {"wall": true}], ["banner_green", 15.0, 2.0, {"wall": true}],
			["window", 7.5, 2.0, {"wall": true}], ["window", 17.5, 2.0, {"wall": true}],
			["sconce", 1.5, 1.8, {"wall": true}], ["sconce", 16.0, 1.8, {"wall": true}], ["sconce", 20.0, 1.8, {"wall": true}], ["sconce", 25.5, 1.8, {"wall": true}],
			["door_wood", 22.0, 2.0, {"wall": true, "label": "KITCHEN"}],
			["shelf", 30.0, 2.0, {"wall": true}],
			["keg_rack", 30.0, 3.4, {"solid": [32, 8]}],
			["bar_top", 27.5, 4.0, {}], ["bar_mid", 27.5, 5.0, {}], ["bar_mid", 27.5, 6.0, {}], ["bar_mid", 27.5, 7.0, {}],
			["bar_mid", 27.5, 8.0, {}], ["bar_end", 27.5, 9.75, {}],
			["barrel", 27.5, 7.02, {}],
			["stool", 26.2, 5.15, {}], ["stool", 26.2, 6.95, {}], ["stool", 26.2, 8.75, {}],
			["stairs_up", 33.0, 1.625, {"floor": true}],
			["table", 10.0, 9.0, {"solid": [30, 8], "on": [["mug_pair", -6, -16], ["plate", 6, -14]]}],
			["chair_front", 9.5, 7.78, {}],
			["chair_side", 11.7, 9.05, {"flip": true}],
			["table", 16.0, 12.0, {"solid": [30, 8], "on": [["plate", -5, -15], ["mug_pair", 6, -16]]}],
			["chair_front", 15.6, 10.69, {}],
			["chair_side", 14.3, 12.05, {}],
			["table_small", 8.5, 14.4, {"solid": [18, 8], "on": [["candle", 0, -16]]}],
			["chair_front", 8.5, 13.09, {}],
			["trapdoor", 31.5, 13.75, {"floor": true}],
			# Round tables with stools around them.
			["table_round", 20.5, 8.0, {"solid": [24, 8], "on": [["mug_pair", -4, -12]]}],
			["stool", 19.0, 8.1, {}], ["stool", 22.0, 8.1, {}], ["stool", 20.5, 6.6, {}],
			["table_round", 22.5, 13.8, {"solid": [24, 8], "on": [["plate", 3, -11], ["candle", -5, -13]]}],
			["stool", 21.0, 13.9, {}], ["stool", 24.0, 13.9, {}],
			["table_round_small", 5.0, 11.5, {"solid": [16, 6], "on": [["candle", 0, -10]]}],
			["stool", 3.8, 11.6, {}], ["stool", 6.2, 11.6, {}],
			["table_round_small", 14.5, 6.6, {"solid": [16, 6], "on": [["mug_pair", 0, -9]]}],
			["stool", 13.3, 6.7, {}], ["stool", 15.7, 6.7, {}],
			["doormat", 5.0, 15.5, {"floor": true}],
			["plant_tall", 1.5, 15.8, {"solid": [10, 6]}], ["plant_pot", 34.4, 15.8, {"solid": [10, 6]}],
			["barrel", 34.4, 10.2, {"solid": [12, 6], "tint": BARREL}], ["barrel", 34.4, 11.3, {"solid": [12, 6], "tint": BARREL}],
		],
		"bar_solid": Rect2(27 * 16, 3 * 16, 16, 7 * 16 - 2),
		"npcs": [
			["npc_suilean", 1.9, 8.05, 1, true, null, 22],
			["npc_bard", 11.0, 3.3, 1, false],
			["npc_orfi", 13.2, 3.4, -1, true],
			["npc_dishwasher", 23.6, 3.1, -1, false],
			["npc_kieran", 28.7, 6.4, -1, false],
			["npc_lyburnum", 26.2, 5.18, 1, true, null, 11],
			["npc_boarvhal", 26.2, 6.98, 1, true, null, 11],
			["npc_patron_c", 26.2, 8.78, 1, true, null, 11],
			["npc_ceridwen", 9.5, 7.81, 1, true],
			["npc_erwar", 11.7, 9.1, -1, true],
			["npc_patron_a", 15.6, 10.72, 1, true],
			["npc_patron_b", 14.3, 12.1, 1, true],
			["npc_dm", 8.5, 13.125, 1, true],
			["npc_server", 13.0, 10.0, 1, false, [9.0, 24.0]],
			["npc_galinnadin", 29.6, 13.3, 1, false],
		],
	}


static func upstairs() -> Dictionary:
	var links: Array = [{"cells": [Vector2i(30, 3), Vector2i(31, 3), Vector2i(30, 4), Vector2i(31, 4)], "to": "taproom", "spawn": "stairs", "walk": true}]
	var props: Array = [["stairs_down", 31.0, 4.0, {"floor": true}]]
	var spawns := {"stairs": Vector2(29.0, 4.4)}
	for k in HEROES:
		var c: int = HALL_DOOR_COL[k]
		links.append({"cells": [Vector2i(c, 2), Vector2i(c + 1, 2)], "to": "room_" + k, "spawn": "door",
			"label": "ENTER %s'S ROOM" % Kits.info(k).short.to_upper()})
		props.append(["door_wood", c + 1.0, 2.0, {"wall": true, "label": Kits.info(k).short.to_upper()}])
		spawns["door_" + k] = Vector2(c + 1.0, 3.3)
	for c in [7, 13, 19, 25]:
		props.append(["sconce", c + 0.0, 1.8, {"wall": true}])
	for x in range(2, 29):
		props.append(["runner", x + 0.5, 4.0, {"floor": true}])
	props.append(["plant_tall", 1.6, 5.9, {"solid": [10, 6]}])
	return {"title": "THE GRYPHON'S ROOST - UPSTAIRS", "theme": "wood", "grid": _box(34, 8), "spawns": spawns,
		"links": links, "props": props, "npcs": []}


static func private_room(k: String) -> Dictionary:
	var p: Array = []
	match k:
		"boarvhal":   # goliath barbarian: a huge bed under a fur, a bear pelt, his axe, a trophy, a keg
			p = [["bed_fur", 2.3, 5.6, {"solid": [26, 40]}], ["pelt", 6.2, 5.6, {"floor": true}],
				["boar_head", 2.5, 2.0, {"wall": true}], ["mountain_painting", 6.0, 2.0, {"wall": true}], ["axe_rack", 9.0, 1.6, {"wall": true, "scale": 0.5}],
				["barrel", 10.2, 3.3, {"solid": [12, 6], "tint": BARREL}], ["barrel", 9.3, 3.3, {"solid": [12, 6], "tint": BARREL}]]
		"erwar":      # aasimar cleric: an altar to the sun under stained glass, his chain and shield, a cot
			p = [["sun_window", 6.0, 2.0, {"wall": true}], ["altar", 6.0, 3.3, {"solid": [24, 8]}],
				["chain_stand", 9.6, 3.4, {"solid": [10, 6]}], ["cot", 2.0, 5.6, {"solid": [16, 30]}],
				["rug_round", 6.0, 5.8, {"floor": true}], ["sconce", 3.5, 1.8, {"wall": true}], ["sconce", 8.5, 1.8, {"wall": true}]]
		"lyburnum":   # half-orc paladin: the order's banner, plate on its stand, sword and shield, a dummy, a cot
			p = [["banner_green", 6.0, 2.0, {"wall": true}], ["plate_stand", 4.3, 3.4, {"solid": [10, 6]}],
				["sword_rack", 8.0, 3.3, {"solid": [18, 6]}], ["dummy", 8.6, 6.3, {"solid": [10, 6]}],
				["cot", 2.0, 5.6, {"solid": [16, 30]}], ["sconce", 2.5, 1.8, {"wall": true}], ["sconce", 9.5, 1.8, {"wall": true}]]
		"suilean":    # elf druid: moonlit window, vines, drying herbs, a mossy bed, plants and mushrooms
			p = [["moon_window", 6.0, 2.0, {"wall": true}], ["hanging_vines", 3.0, 2.0, {"wall": true}], ["herb_rack", 9.0, 1.9, {"wall": true}],
				["bed_moss", 2.2, 5.5, {"solid": [20, 32]}], ["plant_tall", 10.0, 3.3, {"solid": [10, 6]}],
				["plant_pot", 9.8, 7.4, {"solid": [10, 6]}], ["plant_pot", 5.0, 3.2, {"solid": [10, 6]}], ["mushrooms", 7.6, 6.2, {}]]
		"ceridwen":   # half-elf wizard: a crammed bookcase, desk and spellbook, a star chart, crystal ball, bed
			p = [["bookcase", 2.2, 3.5, {"solid": [24, 8]}], ["star_chart", 6.0, 2.0, {"wall": true}],
				["desk", 6.0, 3.6, {"solid": [28, 8]}], ["stool", 8.4, 3.6, {"on": [["crystal_ball", 0, -11]]}],
				["bed_purple", 9.6, 5.8, {"solid": [20, 34]}], ["rug_round", 5.0, 6.0, {"floor": true}],
				["sconce", 4.0, 1.8, {"wall": true}]]
	p.append(["doormat", 6.0, 7.6, {"floor": true}])
	return {"title": "%s'S ROOM" % Kits.info(k).short.to_upper(), "theme": "wood", "grid": _box(12, 10, [], [5, 6]),
		"spawns": {"door": Vector2(6.0, 7.2), "bed": Vector2(5.5, 5.2)},
		"links": [{"cells": [Vector2i(5, 8), Vector2i(6, 8)], "to": "upstairs", "spawn": "door_" + k, "walk": true}],
		"props": p, "npcs": []}


## The inn's cellar, down the ladder from the taproom trapdoor: casks and stores, a sewer
## grate in the north wall, and in the west wall the cave-in that broke through into the
## Goblin Warren.
static func cellar() -> Dictionary:
	var g: Array[String] = []
	for y in 14:
		if y <= 1 or y == 12:
			g.append("#".repeat(30))
		elif y == 13:
			g.append(" ".repeat(30))
		elif y == 6 or y == 7:
			g.append(".".repeat(29) + "#")             # the breach runs out through the west wall
		else:
			g.append("####" + ".".repeat(25) + "#")
	var props: Array = [
		["ladder", 24.5, 3.0, {}],
		["grate", 13.0, 2.0, {"wall": true, "label": "SEWER GRATE"}],
		["shelf", 7.0, 2.0, {"wall": true}],
		["keg_rack", 18.5, 3.4, {"solid": [32, 8]}],
		["sconce", 10.0, 1.8, {"wall": true}], ["sconce", 16.0, 1.8, {"wall": true}], ["sconce", 21.5, 1.8, {"wall": true}],
		["sconce", 27.5, 1.8, {"wall": true}],
		["cobweb", 4.5, 1.6, {"wall": true}], ["cobweb", 28.4, 1.6, {"wall": true, "flip": true}],
		["rubble", 5.2, 5.6, {"solid": [24, 7], "label": "CAVE-IN"}],
		["rubble", 5.0, 9.4, {"solid": [24, 7], "flip": true}],
		["rocks", 7.0, 8.9, {}],
		["barrel", 27.6, 10.2, {"solid": [12, 6], "tint": BARREL}], ["barrel", 26.7, 10.4, {"solid": [12, 6], "tint": BARREL}],
		["barrel", 27.6, 11.4, {"solid": [12, 6], "tint": BARREL}], ["barrel", 28.3, 8.8, {"solid": [12, 6], "tint": BARREL}],
		["crate", 9.0, 11.6, {"solid": [14, 6]}], ["crate", 10.1, 11.7, {"solid": [14, 6]}], ["crate", 9.5, 10.6, {"solid": [14, 6]}],
		["sacks", 14.0, 11.6, {"solid": [16, 6]}], ["sacks", 16.0, 11.5, {"solid": [16, 6]}],
		["shelf", 22.0, 11.9, {"solid": [44, 6]}],
	]
	return {"title": "THE GRYPHON'S ROOST - CELLAR", "theme": "cellar", "dark": true, "grid": g, "cave_x": 4,
		"spawns": {"ladder": Vector2(24.5, 4.4), "breach": Vector2(6.5, 7.6)},
		"links": [
			{"cells": [Vector2i(24, 2), Vector2i(25, 2)], "to": "taproom", "spawn": "cellar", "walk": true},
			{"cells": [Vector2i(0, 6), Vector2i(0, 7), Vector2i(1, 6), Vector2i(1, 7), Vector2i(2, 6), Vector2i(2, 7)], "to": "warren", "walk": true},
			{"cells": [Vector2i(12, 2), Vector2i(13, 2)], "to": "sewer", "label": "EXAMINE THE SEWER GRATE"},
		],
		"props": props, "npcs": []}


static func get_map(name: String) -> Dictionary:
	if name == "cellar":
		return cellar()
	if name == "taproom":
		return taproom()
	if name == "upstairs":
		return upstairs()
	if name.begins_with("room_"):
		return private_room(name.substr(5))
	return taproom()


## A cave room of the Goblin Warren as a map.
static func cave(name: String) -> Dictionary:
	return {"title": "THE GOBLIN WARREN", "theme": "cave", "dark": true, "grid": TDRooms.grid(name),
		"spawns": {}, "links": [], "props": [], "npcs": []}
