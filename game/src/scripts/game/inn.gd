class_name Inn
extends Node2D
## The Gryphon's Roost Inn, Waterdeep, seen from above: the party's tavern and the hub between
## delves. Taproom (front door, stage, tables, hearth and couch, bar, kitchen, the cellar
## trapdoor), the upstairs hallway, and each hero's private room. Each is its own map (TDMaps);
## walking onto stairs or through a doorway moves you between them.

## What the Hooded Stranger says the first time, one line per press of E.
const QUEST_LINES := [
	"You there. Yes, you, with the axe. Sit a moment.",
	"Three nights ago the floor of Kieran's cellar fell away into the dark. Something old breathes down there.",
	"Goblins have been crawling up out of it ever since, led by a bugbear who calls himself chief.",
	"The Guild pays for every level you clear. Put an end to that chief and the Roost sleeps easier.",
	"The trapdoor by the bar leads down. Go on, then. Roll well.",
]


## Party members and the DM. Lines are short and in character; easy to edit.
const CAST := [
	{"key": "npc_ceridwen", "name": "Ceridwen", "match": "ceridwen", "x": 300.0, "y": 202.0, "sit": true, "face": 1, "lines": [
		"I foresaw you coming down here. I also foresaw you forgetting your potions.",
		"The portents say the cellar goblins are restless tonight. The portents are rarely wrong. I am never wrong.",
		"Don't touch my spellbook. It bites. Metaphorically. Mostly."]},
	{"key": "npc_erwar", "name": "Erwar", "match": "erwar", "x": 340.0, "y": 202.0, "sit": true, "face": -1, "lines": [
		"War favours the prepared. Have you prayed, Boar-vhal? Have you at least stretched?",
		"If you fall down there, I'll be up here. Drink a potion first, then call for me.",
		"Strike first. Strike hard. Then tell me about it over an ale."]},
	{"key": "npc_lyburnum", "name": "Lyburnum", "match": "lyburnum", "x": 626.0, "y": 198.0, "sit": true, "face": 1, "lines": [
		"Conquer the cellar. Then conquer another ale.",
		"Fear is a weapon. Make the goblins hold it by the blade.",
		"Kieran waters the ale. I have chosen to let him live."]},
	{"key": "npc_suilean", "name": "Suilean", "match": "suilean", "x": 474.0, "y": 202.0, "sit": true, "face": 1, "lines": [
		"The roots under this inn are whispering. Something down there is digging.",
		"The fire is nice. The couch is nicer. Wake me when it's my turn.",
		"Bring me a mushroom from the warren. A weird one."]},
	{"key": "npc_galinnadin", "name": "Galinnadin", "match": "galinnadin", "x": 866.0, "y": 208.0, "sit": false, "face": -1, "lines": [
		"I'm not here. You didn't see me.",
		"I'll be back with the party soon. Someone has to pick the locks you smash.",
		"Nice axe. Shame if someone... polished it for you."]},
	{"key": "npc_orfi", "name": "Orfi", "match": "orfi", "x": 126.0, "y": 191.0, "sit": true, "face": 1, "lines": [
		"Breathe in. Breathe out. Punch goblin.",
		"Stillness first, Boar-vhal. Then fury.",
		"I'm meditating. You are standing in my light."]},
	{"key": "npc_boarvhal", "name": "Boar-vhal", "match": "boar", "x": 698.0, "y": 198.0, "sit": true, "face": -1, "lines": [
		"KEG! Kieran, this one's empty too.",
		"Goliaths don't get drunk. We get... enthusiastic.",
		"I'm not drinking. I'm hydrating for the cellar.",
		"You go on down. I'll guard the ale.",
		"Tell the goblins I'm busy. Busy drinking.",
	]},
	{"key": "npc_dm", "name": "Hooded Stranger", "match": "dungeon master", "x": 230.0, "y": 202.0, "sit": true, "face": 1, "lines": [
		"Roll for initiative.",
		"Are you sure you want to do that?",
		"The cellar door creaks open. What do you do?",
		"Make a Perception check. No, the other kind."]},
]

## Staff from Session Scribe's Business tab, matched by role. Fallbacks are used offline.
const STAFF := {
	"barkeep": {"key": "npc_kieran", "name": "Kieran", "x": 672.0, "y": 186.0, "lines": [
		"Welcome back to the Gryphon's Roost. Ale's two copper. Owners drink free, but the ledger notices.",
		"There's a hole in my cellar and goblins in the hole. Fix one of those, would you?",
		"If it goes badly down there, I'll hear it on the Sending Stone."]},
	"server": {"key": "npc_server", "name": "Server", "x": 360.0, "y": 208.0, "lines": [
		"Mind the tray!",
		"Table two wants another round. Table two always wants another round.",
		"The hooded one in the corner hasn't ordered in hours. Just keeps rolling dice."]},
	"dishwasher": {"key": "npc_dishwasher", "name": "Dishwasher", "x": 782.0, "y": 208.0, "lines": [
		"So. Many. Mugs.",
		"If you bring the goblins' cups back, I'm not washing them."]},
}

const PATRONS := [
	{"key": "npc_bard", "name": "Bard", "x": 160.0, "y": 196.0, "sit": false, "face": 1, "lines": [
		"This next one's called 'The Goliath and the Goblin'. It's short.",
		"Tips go in the hat. Goblin ears do not go in the hat."]},
	{"key": "npc_patron_a", "name": "Patron", "x": 396.0, "y": 202.0, "sit": true, "face": 1, "lines": [
		"Heard there's goblins under this place.",
		"Owners are heroes, they say. You one of them?"]},
	{"key": "npc_patron_b", "name": "Patron", "x": 428.0, "y": 202.0, "sit": true, "face": -1, "lines": [
		"I heard the owners eat goblins.",
		"Don't spill my drink and we'll get along fine."]},
	{"key": "npc_patron_c", "name": "Patron", "x": 728.0, "y": 198.0, "sit": true, "face": -1, "lines": [
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
	[["npc_boarvhal", "*drains the keg* ANOTHER!"], ["npc_kieran", "That's your third keg, Boar-vhal."]],
	[["npc_boarvhal", "*glug glug glug*"]],
	[["npc_lyburnum", "Boar-vhal, that's a keg, not a mug."], ["npc_boarvhal", "It's a mug if you're tall enough."]],
]


var game: Node
var room: World               # the map you are in
var current := ""
var dm: InnNPC
var staff_npcs := {}          # role -> InnNPC in the taproom
var staff_names := {}         # role -> name from Session Scribe
var _hidden_key := ""
var _away := {}               # npc key -> slot: party members waiting at the trapdoor
var _chat_t := 4.0
var _chat_queue: Array = []
var _drink_t := 2.0
var _link_cool := 0.0


func build(g: Node) -> void:
	game = g


## Moves to another inn map. The game adopts the new World (hero and companions move into it).
func go(map_name: String, spawn := "") -> void:
	current = map_name
	if is_instance_valid(room):
		room.queue_free()
	room = World.new()
	add_child(room)
	room.build(game, TDMaps.get_map(map_name))
	npcs_from_map()
	var at: Vector2 = room.map.spawns.get(spawn, room.map.spawns.values()[0]) * World.T if not room.map.spawns.is_empty() else Vector2(64, 64)
	room.player_spawn = at
	_link_cool = 0.5
	game.on_inn_map(room, at)


func npcs_from_map() -> void:
	dm = null
	staff_npcs.clear()
	for d in room.map.npcs:
		var key: String = d[0]
		var info := _cast_data(key)
		var pos: Vector2 = Vector2(d[1], d[2]) * World.T
		var sit: bool = d[4]
		var face: int = d[3]
		var lift: float = float(d[6]) if d.size() > 6 else 0.0
		var hero_key := key.trim_prefix("npc_")
		if _away.has(key):
			# Agreed to come along: waiting by the trapdoor.
			pos = Vector2(28.6 - _away[key] * 1.1, 12.2) * World.T
			sit = false
			lift = 0.0
			face = 1
		var patrol: Variant = d[5] if d.size() > 5 else null
		var n := room.add_npc(key, info.name, pos, info.lines, sit, face, lift, patrol == null)
		if patrol != null:
			n.patrol = Vector2(patrol[0], patrol[1]) * World.T
			n.speed = 30.0
		n.visible = key != _hidden_key
		if n.visible == false:
			n.set_process(false)
		if key == "npc_dm":
			dm = n
		for role in STAFF:
			if STAFF[role].key == key:
				staff_npcs[role] = n
				if staff_names.has(role):
					n.rename(staff_names[role])
		if hero_key == "boarvhal" and not _away.has(key):
			n.set_meta("drinking", true)


func _cast_data(key: String) -> Dictionary:
	for c in CAST + PATRONS:
		if c.key == key:
			return c
	for r in STAFF:
		if STAFF[r].key == key:
			return STAFF[r]
	return {"name": key.trim_prefix("npc_").capitalize(), "lines": ["..."]}


func _by_key(k: String) -> InnNPC:
	if not is_instance_valid(room):
		return null
	for n in room.npcs:
		if n.key == k:
			return n
	return null


## The hero being played isn't sitting around in the inn as well.
func set_playing(hero_key: String) -> void:
	_hidden_key = "npc_" + hero_key
	if is_instance_valid(room):
		for n in room.npcs:
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
		if key != "" and nm != "":
			staff_names[key] = nm
			if staff_npcs.has(key):
				staff_npcs[key].rename(nm)


## Prices from the Business tab (kept for when the taproom gets its chalkboard back).
var prices: Array[String] = []

func set_prices(text: String) -> void:
	prices.clear()
	for raw in text.split("\n"):
		var parts := raw.strip_edges().split("--")
		if parts.size() == 2:
			prices.append("%s %s" % [parts[0].strip_edges().to_upper(), parts[1].strip_edges().to_upper()])


## The person closest to p, if near enough to talk to.
func nearest(p: Vector2) -> InnNPC:
	if not is_instance_valid(room):
		return null
	var best: InnNPC = null
	var bd := 30.0
	for n in room.npcs:
		if not n.visible:
			continue
		var d := n.global_position.distance_to(p)
		if n == dm and dm.marker and dm.marker.visible:
			d -= 10.0   # whoever has a quest to give answers first
		if d < bd:
			bd = d
			best = n
	return best


## A door or stair at this spot that you use with E: {"to", "spawn", "label"}.
func door_at(p: Vector2) -> Dictionary:
	if not is_instance_valid(room):
		return {}
	var l := room.near_link(p)
	if l.is_empty() or l.to == "exit":
		return {}
	return l


func at_exit(p: Vector2) -> bool:
	if not is_instance_valid(room):
		return false
	var l := room.near_link(p)
	return not l.is_empty() and l.to == "exit"


## Standing on the open trapdoor down to the cellar.
func at_cellar(p: Vector2) -> bool:
	if not is_instance_valid(room) or current != "taproom":
		return false
	var l := room.link_at(room.to_cell(p), true)
	return not l.is_empty() and l.to == "cellar"


func near_cellar(p: Vector2) -> bool:
	return current == "taproom" and p.distance_to(Vector2(31.5, 13.8) * World.T) < 30.0


## Map and spawn point where a hero wakes up: their own room.
func room_spawn(hero_key: String) -> Array:
	return ["room_" + (hero_key if TDMaps.HEROES.has(hero_key) else "boarvhal"), "bed"]


## A party member who agreed to come along waits by the trapdoor.
func send_to_cellar(k: String, slot: int) -> void:
	_away[k] = slot
	if current == "taproom":
		go_keep_player()
		var n := _by_key(k)
		if n:
			n.say("Ready when you are.", 2.0)


func return_home(k: String) -> void:
	if _away.has(k):
		_away.erase(k)
		if current == "taproom":
			go_keep_player()


## Rebuilds the current map with the hero where they stand (after the cast changes).
func go_keep_player() -> void:
	var p: Vector2 = game.player.global_position
	var name := current
	current = ""
	if is_instance_valid(room):
		room.queue_free()
	current = name
	room = World.new()
	add_child(room)
	room.build(game, TDMaps.get_map(name))
	npcs_from_map()
	room.player_spawn = p
	game.on_inn_map(room, p)


func clear_party() -> void:
	_away.clear()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(room) or not is_instance_valid(game.player) or not game.accepting_input():
		return
	_link_cool -= delta
	var p: Vector2 = game.player.global_position
	if _link_cool <= 0.0:
		var l := room.link_at(room.to_cell(p), true)
		if not l.is_empty() and l.to != "cellar":
			_link_cool = 0.6
			game.sfx.play("step", -4.0)
			go(l.to, l.get("spawn", ""))
			return
	# Name tags only for whoever is close, so the room doesn't drown in labels.
	var near := nearest(p)
	for n in room.npcs:
		if n.tag:
			n.tag.visible = n == near or n.global_position.distance_to(p) < 44.0


func _process(delta: float) -> void:
	if not is_instance_valid(room) or not is_instance_valid(game.player):
		return
	var boar := _by_key("npc_boarvhal")
	if boar and boar.visible and boar.has_meta("drinking"):
		_drink_t -= delta
		if _drink_t <= 0.0:
			_drink_t = randf_range(4.0, 7.0)
			if randf() < 0.35:
				boar.say("*glug*", 1.4)
	_chat_t -= delta
	if _chat_t <= 0.0 and _chat_queue.is_empty():
		_chat_t = randf_range(5.0, 9.0)
		var options := []
		for ex in CHATTER:
			var first := _by_key(ex[0][0])
			if first and first.visible and first.global_position.distance_to(game.player.global_position) < 200.0:
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
