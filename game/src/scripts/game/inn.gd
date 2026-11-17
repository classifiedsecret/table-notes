class_name Inn
extends Node2D
## The Gryphon's Roost Inn, Waterdeep: the party's tavern and the hub between delves.
## Ground floor: front door, stage, tables, fireplace and couch, bar, kitchen, stairs, cellar door.
## Upper floor: rooms to let and the party's private rooms.

const FLOOR_Y := 208.0
const UP_Y := 96.0
const CELLAR_X := 984.0
const LAYER_STAIRS := 8
const STAIR_FOOT := Vector2(896, 208)
const STAIR_TOP := Vector2(784, 96)
## What the Hooded Stranger says the first time, one line per press of E.
const QUEST_LINES := [
	"You there. Yes, you, with the axe. Sit a moment.",
	"Three nights ago the floor of Kieran's cellar fell away into the dark. Something old breathes down there.",
	"Goblins have been crawling up out of it ever since, led by a bugbear who calls himself chief.",
	"The Guild pays for every level you clear. Put an end to that chief and the Roost sleeps easier.",
	"The cellar stair is at the far end of the taproom. Go on, then. Roll well.",
]

var game: Node
var room: Room
var npcs: Array[InnNPC] = []
var dm: InnNPC
var staff_npcs := {}          # role key -> InnNPC
var board: Label
var _chat_t := 4.0
var _chat_queue: Array = []
var _hidden_key := ""

## Party members and the DM. Lines are short and in character; easy to edit.
const CAST := [
	{"key": "npc_ceridwen", "name": "Ceridwen", "match": "ceridwen", "x": 300.0, "y": 208.0, "sit": true, "face": 1, "lines": [
		"I foresaw you coming down here. I also foresaw you forgetting your potions.",
		"The portents say the cellar goblins are restless tonight. The portents are rarely wrong. I am never wrong.",
		"Don't touch my spellbook. It bites. Metaphorically. Mostly."]},
	{"key": "npc_erwar", "name": "Erwar", "match": "erwar", "x": 340.0, "y": 208.0, "sit": true, "face": -1, "lines": [
		"War favours the prepared. Have you prayed, Boar-vhal? Have you at least stretched?",
		"If you fall down there, I'll be up here. Drink a potion first, then call for me.",
		"Strike first. Strike hard. Then tell me about it over an ale."]},
	{"key": "npc_lyburnum", "name": "Lyburnum", "match": "lyburnum", "x": 636.0, "y": 208.0, "sit": true, "face": 1, "lines": [
		"Conquer the cellar. Then conquer another ale.",
		"Fear is a weapon. Make the goblins hold it by the blade.",
		"Kieran waters the ale. I have chosen to let him live."]},
	{"key": "npc_suilean", "name": "Suilean", "match": "suilean", "x": 520.0, "y": 208.0, "sit": true, "face": 1, "lines": [
		"The roots under this inn are whispering. Something down there is digging.",
		"The fire is nice. The couch is nicer. Wake me when it's my turn.",
		"Bring me a mushroom from the warren. A weird one."]},
	{"key": "npc_galinnadin", "name": "Galinnadin", "match": "galinnadin", "x": 448.0, "y": 96.0, "sit": false, "face": -1, "lines": [
		"I'm not here. You didn't see me.",
		"I'll be back with the party soon. Someone has to pick the locks you smash.",
		"Nice axe. Shame if someone... polished it for you."]},
	{"key": "npc_orfi", "name": "Orfi", "match": "orfi", "x": 560.0, "y": 96.0, "sit": true, "face": -1, "lines": [
		"Breathe in. Breathe out. Punch goblin.",
		"Stillness first, Boar-vhal. Then fury.",
		"I'm meditating. You are standing in my light."]},
	{"key": "npc_dm", "name": "Hooded Stranger", "match": "dungeon master", "x": 230.0, "y": 208.0, "sit": true, "face": 1, "lines": [
		"Roll for initiative.",
		"Are you sure you want to do that?",
		"The cellar door creaks open. What do you do?",
		"Make a Perception check. No, the other kind."]},
]

## Staff from Session Scribe's Business tab, matched by role. Fallbacks are used offline.
const STAFF := {
	"barkeep": {"key": "npc_kieran", "name": "Kieran", "x": 664.0, "y": 208.0, "lines": [
		"Welcome back to the Gryphon's Roost. Ale's two copper. Owners drink free, but the ledger notices.",
		"There's a hole in my cellar and goblins in the hole. Fix one of those, would you?",
		"If it goes badly down there, I'll hear it on the Sending Stone."]},
	"server": {"key": "npc_server", "name": "Server", "x": 360.0, "y": 208.0, "lines": [
		"Mind the tray!",
		"Table two wants another round. Table two always wants another round.",
		"The hooded one in the corner hasn't ordered in hours. Just keeps rolling dice."]},
	"dishwasher": {"key": "npc_dishwasher", "name": "Dishwasher", "x": 744.0, "y": 208.0, "lines": [
		"So. Many. Mugs.",
		"If you bring the goblins' cups back, I'm not washing them."]},
}

const PATRONS := [
	{"key": "npc_bard", "name": "Bard", "x": 160.0, "y": 196.0, "sit": false, "face": 1, "lines": [
		"This next one's called 'The Goliath and the Goblin'. It's short.",
		"Tips go in the hat. Goblin ears do not go in the hat."]},
	{"key": "npc_patron_a", "name": "Patron", "x": 396.0, "y": 208.0, "sit": true, "face": 1, "lines": [
		"Heard there's goblins under this place.",
		"Owners are heroes, they say. You one of them?"]},
	{"key": "npc_patron_b", "name": "Patron", "x": 428.0, "y": 208.0, "sit": true, "face": -1, "lines": [
		"I heard the owners eat goblins.",
		"Don't spill my drink and we'll get along fine."]},
	{"key": "npc_patron_c", "name": "Patron", "x": 704.0, "y": 208.0, "sit": true, "face": -1, "lines": [
		"It's not a costume.",
		"Best stew in Waterdeep. Don't tell the cook I said so."]},
]

## Ambient exchanges: [[speaker key, line], ...]. One plays every few seconds near the player.
const CHATTER := [
	[["npc_ceridwen", "Your aura says 'third ale'."], ["npc_erwar", "My aura says 'mind your business'."]],
	[["npc_erwar", "Did you foresee who's paying tonight?"], ["npc_ceridwen", "Yes. That's why I'm leaving early."]],
	[["npc_lyburnum", "Another."], ["npc_kieran", "That's your fifth 'another'."]],
	[["npc_patron_a", "Heard there's goblins in the cellar."], ["npc_patron_b", "Heard the owners eat goblins."]],
	[["npc_bard", "*strums a jaunty tune*"]],
	[["npc_server", "Coming through!"]],
	[["npc_dm", "*rolls a die behind a little screen*"]],
	[["npc_suilean", "*snores softly*"]],
	[["npc_orfi", "*breathes slowly*"]],
	[["npc_galinnadin", "*counts coins that are not his*"]],
	[["npc_kieran", "Who ordered the stew?"], ["npc_patron_c", "Me. Obviously me."]],
	[["npc_dishwasher", "MORE MUGS?"]],
]


func build(g: Node) -> void:
	game = g
	room = Room.new()
	room.back_color = Color(0.44, 0.34, 0.30)
	add_child(room)
	room.build(FileAccess.get_file_as_string("res://rooms/inn_gryphons_roost.txt"))
	_furnish()
	_stairs()
	_people()


func _spr(name: String, pos: Vector2, z := -3, from_bottom := true, flip := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = InnProps.tex(name) if InnProps.RECTS.has(name) else Art.region(name)
	s.centered = true
	s.position = pos - Vector2(0, s.texture.get_height() / 2.0 if from_bottom else 0.0)
	s.z_index = z
	s.flip_h = flip
	add_child(s)
	return s


func _label(text: String, pos: Vector2, color: Color, size := 8, z := -2) -> Label:
	var l := Label.new()
	l.label_settings = Art.label_settings(size, color, 2)
	l.text = text
	l.position = pos
	l.z_index = z
	add_child(l)
	return l


func _furnish() -> void:
	# Floorboards on both floors.
	for x in range(16, 1008, 16):
		_spr("plank", Vector2(x + 8, FLOOR_Y + 4), -4)
		if x < 784:
			_spr("plank", Vector2(x + 8, UP_Y + 4), -4)
	# Ground floor, left to right.
	_spr("doors_leaf_closed", Vector2(40, FLOOR_Y), -6)
	_label("WAY OUT", Vector2(24, 158), Color(0.8, 0.75, 0.6))
	_spr("window", Vector2(84, 166), -6)
	_spr("curtain", Vector2(104, FLOOR_Y), -5)
	_spr("curtain", Vector2(216, FLOOR_Y), -5)
	_spr("stage", Vector2(160, FLOOR_Y), -4)
	_spr("table", Vector2(246, FLOOR_Y), 2)
	_spr("chair_r", Vector2(228, FLOOR_Y), 1)
	_spr("table", Vector2(320, FLOOR_Y), 2)
	_spr("chair_r", Vector2(298, FLOOR_Y), 1)
	_spr("chair_l", Vector2(342, FLOOR_Y), 1)
	_spr("book", Vector2(314, FLOOR_Y - 13), 3)
	_spr("mug", Vector2(328, FLOOR_Y - 13), 3)
	_spr("table", Vector2(412, FLOOR_Y), 2)
	_spr("stool", Vector2(394, FLOOR_Y), 1)
	_spr("stool", Vector2(430, FLOOR_Y), 1)
	_spr("mug", Vector2(406, FLOOR_Y - 13), 3)
	_spr("mug", Vector2(418, FLOOR_Y - 13), 3)
	_spr("window", Vector2(468, 166), -6)
	_spr("fireplace", Vector2(528, FLOOR_Y), -5)
	var fire := Node2D.new()
	fire.set_script(preload("res://scripts/game/campfire.gd"))
	fire.position = Vector2(528, FLOOR_Y - 4)
	fire.z_index = -4
	fire.set("game", game)
	add_child(fire)
	_spr("rug", Vector2(528, FLOOR_Y + 1), -3)
	_spr("couch", Vector2(524, FLOOR_Y), 2)
	board = _label("", Vector2(564, 124), Color(0.92, 0.95, 0.9), 8, -3)
	_spr("chalkboard", Vector2(588, 160), -6)
	_label("TONIGHT", Vector2(566, 122), Color(1, 0.9, 0.6), 8, -2)
	board.position = Vector2(566, 131)
	board.label_settings.line_spacing = -3.0
	set_prices("Meals -- 8sp\nAle -- 2cp\nWine -- 2sp\nRoom per night -- 2gp")
	_spr("shelf", Vector2(664, 166), -6)
	_spr("bar_end", Vector2(613, FLOOR_Y), 3)
	for x in range(616, 728, 16):
		_spr("bar", Vector2(x + 8, FLOOR_Y), 3)
	_spr("bar_end", Vector2(731, FLOOR_Y), 3)
	_spr("stool", Vector2(636, FLOOR_Y), 5)
	_spr("stool", Vector2(704, FLOOR_Y), 5)
	_spr("mug", Vector2(650, FLOOR_Y - 25), 4)
	_spr("doors_leaf_closed", Vector2(776, FLOOR_Y), -6)
	_label("KITCHEN", Vector2(756, 162), Color(0.8, 0.75, 0.6))
	_spr("barrel", Vector2(836, FLOOR_Y), -5)
	_spr("barrel", Vector2(852, FLOOR_Y), -5)
	_spr("barrel", Vector2(844, FLOOR_Y - 17), -5)
	_label("CELLAR", Vector2(966, 160), Color(1, 0.75, 0.45))
	for x in [200.0, 360.0, 480.0, 690.0]:
		_spr("lantern", Vector2(x, 112), -2, false)
		_glow(Vector2(x, 128))
	# Upper floor: rooms to let and the party's private rooms.
	for i in 4:
		var dx := 56.0 + i * 72.0
		_spr("doors_leaf_closed", Vector2(dx, UP_Y), -6)
		_label("ROOM %d" % (i + 1), Vector2(dx - 15, 46), Color(0.8, 0.75, 0.6))
	_spr("window", Vector2(340, 56), -6)
	for i in 2:
		var dx := 400.0 + i * 64.0
		_spr("doors_leaf_closed", Vector2(dx, UP_Y), -6)
	_label("THE DMV - PRIVATE", Vector2(392, 44), Color(1, 0.85, 0.45))
	_spr("rug", Vector2(560, UP_Y + 1), -3)
	_spr("bed", Vector2(640, UP_Y), -4)
	_spr("window", Vector2(700, 56), -6)
	for x in range(736, 784, 16):
		_spr("railing", Vector2(x + 8, UP_Y), 2)
	for x in [150.0, 330.0, 520.0]:
		_spr("lantern", Vector2(x, 16), -2, false)
		_glow(Vector2(x, 32))


func _glow(pos: Vector2) -> void:
	var g := Node2D.new()
	g.set_script(preload("res://scripts/game/lamp_glow.gd"))
	g.position = pos
	g.z_index = -7
	add_child(g)


## A 45-degree staircase you can walk up, jump through from below and drop through with S + Space.
func _stairs() -> void:
	var a := STAIR_FOOT
	var b := STAIR_TOP
	var body := StaticBody2D.new()
	body.collision_layer = LAYER_STAIRS
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var seg := SegmentShape2D.new()
	seg.a = a
	seg.b = b
	cs.shape = seg
	cs.one_way_collision = true
	cs.one_way_collision_margin = 4.0
	body.add_child(cs)
	add_child(body)
	var steps := Node2D.new()
	steps.set_script(preload("res://scripts/game/stair_art.gd"))
	steps.set("a", a)
	steps.set("b", b)
	steps.z_index = -4
	add_child(steps)


func _people() -> void:
	for c in CAST:
		_add(c)
	for role in STAFF:
		var n := _add(STAFF[role])
		staff_npcs[role] = n
	staff_npcs["server"].patrol = Vector2(250, 470)
	staff_npcs["server"].speed = 30.0
	for p in PATRONS:
		_add(p)


func _add(d: Dictionary) -> InnNPC:
	var n := InnNPC.make(d.key, d.name, Vector2(d.x, d.y), d.lines, d.get("sit", false), d.get("face", 1))
	n.z_index = 4 if d.key == "npc_kieran" else (1 if d.get("sit", false) else 2)
	if d.key == "npc_kieran":
		n.z_index = 2   # behind the bar counter (z 3)
	add_child(n)
	npcs.append(n)
	if d.key == "npc_dm":
		dm = n
	return n


## Hides the character the player is ("You are" in Session Scribe), e.g. Ceridwen for Jessica, the stranger for the DM.
func hide_player_character(party_name: String) -> void:
	var nm := party_name.to_lower()
	for c in CAST:
		if nm != "" and nm.contains(c.match) and c.key != "npc_dm":   # the stranger stays: he gives the quest
			_hidden_key = c.key
	for n in npcs:
		n.visible = n.key != _hidden_key


## Staff from Session Scribe's Business tab: names by role (barkeep, server, dishwasher).
func apply_staff(list: Array) -> void:
	for d in list:
		if typeof(d) != TYPE_DICTIONARY:
			continue
		var role := str(d.get("role", "")).to_lower()
		var nm := str(d.get("name", "")).strip_edges()
		var key := ""
		if role.contains("barkeep") or role.contains("manager") or role.contains("cook"):
			key = "barkeep"
		elif role.contains("server") or role.contains("wait"):
			key = "server"
		elif role.contains("dish"):
			key = "dishwasher"
		if key != "" and staff_npcs.has(key) and nm != "":
			staff_npcs[key].rename(nm)


## Prices from the Business tab's notes: lines like "Ale -- 2cp" go on the chalkboard.
func set_prices(text: String) -> void:
	var rows: Array[String] = []
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		var parts := line.split("--")
		if parts.size() == 2:
			var item := parts[0].strip_edges().replace("Room per night", "Room")
			rows.append("%s %s" % [item.to_upper(), parts[1].strip_edges().to_upper()])
	if not rows.is_empty():
		board.text = "\n".join(rows.slice(0, 3))   # the board holds three lines


func nearest(p: Vector2) -> InnNPC:
	var best: InnNPC = null
	var bd := 26.0
	for n in npcs:
		if not n.visible:
			continue
		var d := absf(n.global_position.x - p.x)
		if n == dm and dm.marker and dm.marker.visible:
			d -= 14.0   # whoever has a quest to give answers first
		if d < bd and absf(n.global_position.y - p.y) < 24.0:
			bd = d
			best = n
	return best


## The stairs only carry you when you mean to use them: press W (up) at the foot,
## or walk onto them from the landing. Otherwise you pass underneath.
var _on_stairs := false

func _physics_process(_delta: float) -> void:
	var pl: CharacterBody2D = game.player if game and is_inside_tree() else null
	if pl == null:
		return
	var p := pl.global_position
	var line_y := STAIR_FOOT.y + (p.x - STAIR_FOOT.x) * (STAIR_TOP.y - STAIR_FOOT.y) / (STAIR_TOP.x - STAIR_FOOT.x)
	if not _on_stairs:
		var at_foot := absf(p.y - FLOOR_Y) < 3.0 and p.x > STAIR_FOOT.x - 24.0 and p.x < STAIR_FOOT.x + 18.0 and Input.is_action_pressed("move_up")
		var at_top := absf(p.y - UP_Y) < 3.0 and p.x > STAIR_TOP.x - 10.0 and p.x < STAIR_TOP.x + 6.0
		_on_stairs = at_foot or at_top
	else:
		var off_bottom := absf(p.y - FLOOR_Y) < 3.0 and (p.x > STAIR_FOOT.x + 4.0 or p.x < STAIR_FOOT.x - 40.0)
		var off_top := absf(p.y - UP_Y) < 3.0 and p.x < STAIR_TOP.x - 12.0
		var below := p.y > line_y + 8.0
		var dropping := Input.is_action_pressed("move_down") and Input.is_action_just_pressed("jump")
		if off_bottom or off_top or below or dropping:
			_on_stairs = false
	pl.set_collision_mask_value(4, _on_stairs)   # LAYER_STAIRS
	# Name tags only for people close by, so the room doesn't drown in labels.
	for n in npcs:
		if n.tag:
			n.tag.visible = absf(n.global_position.x - p.x) < 90.0 and absf(n.global_position.y - p.y) < 60.0


func at_cellar(p: Vector2) -> bool:
	return p.x > CELLAR_X - 14.0 and absf(p.y - FLOOR_Y) < 4.0


func _process(delta: float) -> void:
	if not visible:
		return
	_chat_t -= delta
	if _chat_t <= 0.0 and _chat_queue.is_empty():
		_chat_t = randf_range(5.0, 9.0)
		var options := []
		for ex in CHATTER:
			var first := _by_key(ex[0][0])
			if first and first.visible and absf(first.global_position.x - game.player.global_position.x) < 260.0:
				options.append(ex)
		if not options.is_empty():
			_chat_queue = options[randi() % options.size()].duplicate()
			_chat_t = 0.0
	if not _chat_queue.is_empty() and _chat_t <= 0.0:
		var step: Array = _chat_queue.pop_front()
		var who := _by_key(step[0])
		if who and who.visible:
			who.say(step[1])
		_chat_t = 2.4 if not _chat_queue.is_empty() else randf_range(5.0, 9.0)


func _by_key(k: String) -> InnNPC:
	for n in npcs:
		if n.key == k:
			return n
	return null
