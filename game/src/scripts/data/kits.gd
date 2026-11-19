class_name Kits
extends RefCounted
## The playable heroes (DMV party presets), levels 1-10.
## Heroes use 2014 rules (SRD 5.1, CC-BY-4.0). War Blessing, Foresight, Dread Aura and the
## bear/spider Wild Shape list stand in for non-SRD subclasses and are original to this game.
##
## Keys: L = "rage" action, R = "reckless" action, U = "echo" action, Y = "form" action.

const ORDER := ["boarvhal", "ceridwen", "erwar", "lyburnum", "suilean"]

const BASE := {
	"boarvhal": {"name": "Boar-vhal Rockhauler", "short": "Boar-vhal", "title": "Goliath Barbarian",
		"sprite": "boarvhal", "weapon_sprite": "weapon_double_axe", "he": "he", "his": "his", "him": "him",
		"match": "boar"},
	"ceridwen": {"name": "Ceridwen Lynwood", "short": "Ceridwen", "title": "Half-Elf Wizard",
		"sprite": "hero_ceridwen", "weapon_sprite": "weapon_red_magic_staff", "he": "she", "his": "her", "him": "her",
		"match": "ceridwen"},
	"erwar": {"name": "Erwar", "short": "Erwar", "title": "Aasimar Cleric",
		"sprite": "hero_erwar", "weapon_sprite": "weapon_mace", "he": "he", "his": "his", "him": "him",
		"match": "erwar"},
	"lyburnum": {"name": "Lyburnum Nailo", "short": "Lyburnum", "title": "Half-Orc Paladin",
		"sprite": "hero_lyburnum", "weapon_sprite": "weapon_knight_sword", "he": "he", "his": "his", "him": "him",
		"match": "lyburnum"},
	"suilean": {"name": "Suilean na Coille", "short": "Suilean", "title": "Elf Druid",
		"sprite": "hero_suilean", "weapon_sprite": "weapon_green_magic_staff", "he": "she", "his": "her", "him": "her",
		"match": "suilean"},
}


static func has(key: String) -> bool:
	return BASE.has(key)


static func info(key: String) -> Dictionary:
	return BASE.get(key, BASE["boarvhal"])


## Matches a Session Scribe party member name ("Ceridwen", "Sùilean na Coille") to a hero key.
static func key_for_name(member_name: String) -> String:
	var n := member_name.to_lower().replace("ù", "u").replace("ú", "u")
	for k in ORDER:
		if n.contains(str(BASE[k].match)):
			return k
	return ""


static func prof(level: int) -> int:
	return 2 + (level - 1) / 4   # +2 at 1-4, +3 at 5-8, +4 at 9-10


static func mod(score: int) -> int:
	return floori((score - 10) / 2.0)


## Full-caster spell slots as [1st level, 2nd level and higher].
## (2nd-level and higher slots are pooled: at 10th level that is three 2nd, three 3rd, three 4th, two 5th.)
static func caster_slots(level: int) -> Array:
	return [[2, 0], [3, 0], [4, 2], [4, 3], [4, 5], [4, 6], [4, 7], [4, 8], [4, 10], [4, 11]][clampi(level, 1, 10) - 1]


## Ability score improvements at 4th and 8th level go into each hero's main ability (max 20).
static func _main_score(base: int, level: int) -> int:
	return mini(20, base + (2 if level >= 4 else 0) + (2 if level >= 8 else 0))


## Everything the real-time and turn-based layers need for one hero at one level.
static func stats(key: String, level: int) -> Dictionary:
	var b := info(key)
	var p := prof(level)
	var s := {
		"key": key, "name": b.name, "short": b.short, "title": "%s %d" % [b.title, level], "proficiency": p,
		"speed_ft": 30, "rage_uses": 0, "rage_damage": 0, "rage_seconds": 0.0, "slots": [0, 0],
		"spell_attack": 0, "spell_dc": 0, "spell_mod": 0, "lay_pool": 0, "channel": 0, "wild_uses": 0,
		"extra_attack": false, "abilities": {}, "locked": {}, "hit_die": 8, "con_mod": 2, "hp": 10, "ac": 10,
		"str_save": 0, "dex_save": 0, "con_save": 2, "wis_save": 0, "savage": false, "relentless": false,
		"athletics": 0,
	}
	match key:
		"ceridwen":
			var intel := mod(_main_score(16, level))
			s.hp = 8 + (level - 1) * 6
			s.hit_die = 6
			s.ac = 15                    # Mage Armor (13 + Dex), cast before the delve
			s.dex_save = 2
			s.str_save = -1
			s.athletics = -1
			s.wis_save = 1 + p
			s.spell_mod = intel
			s.spell_attack = intel + p
			s.spell_dc = 8 + intel + p
			s.slots = caster_slots(level)
			s.weapon = {"name": "Fire Bolt", "kind": "bolt", "attack": intel + p, "count": 2 if level >= 5 else 1,
				"sides": 10, "bonus": 0, "type": "fire", "spell": true}
			s.abilities = {"L": "magic_missile"}
			s.locked = {"U": [2, "Foresight"], "R": [3, "Scorching Ray"]}
			if level >= 2:
				s.abilities.U = "foresight"
			if level >= 3:
				s.abilities.R = "scorching_ray"
			if level >= 6:
				s.abilities.R = "fireball"   # Fireball takes Scorching Ray's key
		"erwar":
			var wis := mod(_main_score(16, level))
			s.hp = 10 + (level - 1) * 7
			s.ac = 18                    # chain mail and shield
			s.str_save = 2
			s.athletics = 2
			s.wis_save = wis + p
			s.spell_mod = wis
			s.spell_attack = wis + p
			s.spell_dc = 8 + wis + p
			s.slots = caster_slots(level)
			s.channel = (1 if level >= 2 else 0) + (1 if level >= 6 else 0)
			s.divine_strike = level >= 8   # +1d8 radiant on mace hits
			s.weapon = {"name": "Mace", "kind": "melee", "attack": 2 + p, "count": 1, "sides": 6, "bonus": 2,
				"type": "bludgeoning", "reach": 22.0, "swing": 0.85}
			s.abilities = {"L": "healing_word"}
			s.locked = {"U": [2, "War Blessing"], "R": [3, "Spiritual Weapon"]}
			if level >= 2:
				s.abilities.U = "war_blessing"
			if level >= 3:
				s.abilities.R = "spiritual_weapon"
			if level >= 6:
				s.abilities.R = "spirit_guardians"   # Spirit Guardians takes Spiritual Weapon's key
		"lyburnum":
			var strm := mod(_main_score(16, level))
			var aura := 2 if level >= 6 else 0   # Aura of Protection: + Charisma to saves
			s.hp = 12 + (level - 1) * 8
			s.hit_die = 10
			s.ac = 18 + (1 if level >= 2 else 0)   # chain mail, shield; Defense fighting style at 2
			s.str_save = strm + aura
			s.dex_save = aura
			s.con_save = 2 + aura
			s.athletics = strm + p
			s.wis_save = 0 + p + aura
			s.spell_mod = 2
			s.spell_dc = 8 + 2 + p
			s.lay_pool = 5 * level
			s.aura = aura
			s.slots = [[0, 0], [2, 0], [3, 0], [3, 0], [4, 2], [4, 2], [4, 3], [4, 3], [4, 5], [4, 5]][level - 1]
			s.channel = 1 if level >= 3 else 0
			s.savage = true
			s.relentless = true
			s.extra_attack = level >= 5
			s.weapon = {"name": "Longsword", "kind": "melee", "attack": strm + p, "count": 1, "sides": 8, "bonus": strm,
				"type": "slashing", "reach": 24.0, "swing": 1.0}
			s.abilities = {"L": "lay_on_hands"}
			s.locked = {"R": [2, "Divine Smite"], "U": [3, "Dread Aura"]}
			if level >= 2:
				s.abilities.R = "smite"
			if level >= 3:
				s.abilities.U = "dread_aura"
		"suilean":
			var wis := mod(_main_score(16, level))
			s.hp = 10 + (level - 1) * 7
			s.ac = 15                    # leather, wooden shield, Dex
			s.speed_ft = 35              # wood elf
			s.dex_save = 2
			s.wis_save = wis + p
			s.spell_mod = wis
			s.spell_attack = wis + p
			s.spell_dc = 8 + wis + p
			s.slots = caster_slots(level)
			s.wild_uses = 2 if level >= 2 else 0
			s.brown_bear = level >= 6   # Circle Forms: the bear shape becomes a brown bear
			s.weapon = {"name": "Thorn Whip", "kind": "whip", "attack": wis + p, "count": 2 if level >= 5 else 1,
				"sides": 6, "bonus": 0, "type": "piercing", "spell": true, "reach": 72.0}
			s.abilities = {"L": "entangle"}
			s.locked = {"U": [2, "Wild Shape: Bear"], "Y": [2, "Wild Shape: Spider"], "R": [3, "Moonbeam"]}
			if level >= 2:
				s.abilities.U = "bear"
				s.abilities.Y = "spider"
			if level >= 3:
				s.abilities.R = "moonbeam"
		_:   # boarvhal
			var strm := mod(_main_score(17, level))
			s.hp = 15 + (level - 1) * 10
			s.hit_die = 12
			s.con_mod = 3
			s.ac = 14                    # Unarmored Defense: 10 + Dex 1 + Con 3
			s.speed_ft = 30 + (10 if level >= 5 else 0)
			s.str_save = strm + p
			s.athletics = strm + p
			s.dex_save = 1
			s.con_save = 3 + p
			s.rage_uses = 2 if level < 3 else (3 if level < 6 else 4)
			s.rage_damage = 2 if level < 9 else 3
			s.brutal = 1 if level >= 9 else 0         # Brutal Critical: one extra weapon die on a crit
			s.reclaim = level >= 6                    # Reclaim Potential
			s.feral = level >= 7                      # Feral Instinct: advantage on initiative
			s.rage_seconds = 60.0
			s.extra_attack = level >= 5
			s.weapon = {"name": "Greataxe", "kind": "melee", "attack": strm + p, "count": 1, "sides": 12, "bonus": strm,
				"type": "slashing", "reach": 26.0, "swing": 1.0}
			s.abilities = {"L": "rage"}
			s.locked = {"R": [2, "Reckless Attack"], "U": [3, "Echo"], "Y": [3, "Move Echo"]}
			if level >= 2:
				s.abilities.R = "reckless"
			if level >= 3:
				s.abilities.U = "echo"
				s.abilities.Y = "echo_move"
	return s


## Wild Shape forms (SRD 5.1 Black Bear, Brown Bear; Giant Wolf Spider).
const FORMS := {
	"brown_bear": {"name": "Brown Bear", "hp": 34, "ac": 11, "speed_ft": 40, "sprite": "form_bear", "frame": [24, 18],
		"tint": Color(1.25, 1.05, 0.85),
		"weapon": {"name": "Claws", "kind": "melee", "attack": 6, "count": 2, "sides": 6, "bonus": 4, "type": "slashing",
			"reach": 24.0, "swing": 0.8}},
	"bear": {"name": "Black Bear", "hp": 19, "ac": 11, "speed_ft": 40, "sprite": "form_bear", "frame": [24, 18],
		"weapon": {"name": "Claws", "kind": "melee", "attack": 4, "count": 2, "sides": 4, "bonus": 2, "type": "slashing",
			"reach": 24.0, "swing": 0.8}},
	"spider": {"name": "Giant Wolf Spider", "hp": 11, "ac": 13, "speed_ft": 40, "sprite": "form_spider", "frame": [24, 14],
		"climb": true,
		"weapon": {"name": "Bite", "kind": "melee", "attack": 3, "count": 1, "sides": 6, "bonus": 1, "type": "piercing",
			"reach": 20.0, "swing": 0.7, "poison_dc": 11}},
}


static func level_features(key: String, lv: int) -> String:
	match key:
		"ceridwen":
			match lv:
				2: return "Foresight (I): at the start of every delve you glimpse two d20 results. Press I to ready one; the next attack roll, yours or a foe's against you, uses that number."
				3: return "Scorching Ray (L): three rays of fire, 2d6 each (2nd-level slot). Spell slots: 4 + 2."
				4: return "Ability Score Improvement: Intelligence 18. +1 to spell attacks and save DCs."
				5: return "Fire Bolt now deals 2d10. More spell slots (4 + 5)."
				6: return "Fireball (L, replaces Scorching Ray): a bead of flame bursts in a 20-ft radius, 8d6 fire, Dexterity save for half (3rd-level slot)."
				7: return "More spell slots (4 + 7)."
				8: return "Ability Score Improvement: Intelligence 20. +1 to spell attacks and save DCs."
				9: return "Proficiency +4. More spell slots (4 + 10)."
				10: return "More spell slots (4 + 11). Fireball now burns hotter from higher slots."
		"erwar":
			match lv:
				2: return "War Blessing (I): ready it, and the next attack that would miss gains +10. Once per delve (a campfire restores it)."
				3: return "Spiritual Weapon (L): a spectral mace fights beside you for a minute (2nd-level slot)."
				4: return "Ability Score Improvement: Wisdom 18. Healing and the spectral mace hit harder."
				5: return "More spell slots (4 + 5). Proficiency +3."
				6: return "Spirit Guardians (L, replaces Spiritual Weapon): radiant spirits circle you for a minute; foes within 15 ft take 3d8 radiant, Wisdom save for half (3rd-level slot). War Blessing twice per delve."
				7: return "More spell slots (4 + 7)."
				8: return "Ability Score Improvement: Wisdom 20. Divine Strike: your mace hits deal an extra 1d8 radiant."
				9: return "Proficiency +4. More spell slots (4 + 10)."
				10: return "More spell slots (4 + 11). Spirit Guardians grow stronger with higher slots."
		"lyburnum":
			match lv:
				2: return "Divine Smite (L toggles): hits spend a spell slot for +2d8 radiant. Defense fighting style: +1 AC."
				3: return "Dread Aura (I): foes within 30 ft make a Wisdom save or flee in fear. Once per delve (a campfire restores it)."
				4: return "Ability Score Improvement: Strength 18. +1 to hit and damage."
				5: return "Extra Attack: much faster sword strikes. More smites."
				6: return "Aura of Protection: +2 to every saving throw you make."
				7: return "More spell slots (4 + 3). Lay on Hands pool 35."
				8: return "Ability Score Improvement: Strength 20. +1 to hit and damage."
				9: return "Proficiency +4. More spell slots (4 + 5)."
				10: return "Aura of Courage: you can't be frightened. Lay on Hands pool 50."
		"suilean":
			match lv:
				2: return "Wild Shape: I turns you into a black bear, Y into a giant wolf spider. Two uses per delve."
				3: return "Moonbeam (L): a beam of moonlight scorches foes standing in it (2nd-level slot). Press L again to move it."
				4: return "Ability Score Improvement: Wisdom 18. +1 to spell attacks and save DCs."
				5: return "Thorn Whip now deals 2d6. More spell slots (4 + 5)."
				6: return "Circle Forms: your bear shape is now a brown bear (34 HP, claws 2d6 + 4)."
				7: return "More spell slots (4 + 7)."
				8: return "Ability Score Improvement: Wisdom 20. +1 to spell attacks and save DCs."
				9: return "Proficiency +4. More spell slots (4 + 10)."
				10: return "More spell slots (4 + 11). Moonbeam burns hotter from higher slots."
		_:
			match lv:
				2: return "Reckless Attack (L / right trigger): advantage on your attacks, but enemies get advantage on you. Danger Sense: advantage on Dexterity saves."
				3: return "Echo (I): leave a shimmering double of yourself; goblins next to it are flanked. I again swaps places. Right-click (or Y) moves it anywhere; more than 30 ft from you and it fades. Rage uses: 3."
				4: return "Ability Score Improvement: Strength 19. +1 to hit and damage."
				5: return "Extra Attack: much faster axe swings. Fast Movement: +10 ft speed. Proficiency +3."
				6: return "Reclaim Potential: when your echo is destroyed, you shake it off and recover 2d6 + 3 hit points. Rage uses: 4."
				7: return "Feral Instinct: advantage on initiative rolls."
				8: return "Ability Score Improvement: Strength 20. +1 to hit and damage."
				9: return "Brutal Critical: one extra greataxe die on a critical hit. Rage damage +3. Proficiency +4."
				10: return "Your echo lingers: it can now stray 60 ft from you before it fades."
	return ""


## Key hints for the run, per hero: [key, what it does].
static func hints(key: String, level := 1) -> Array:
	var head := [["WASD", "MOVE"], ["SPACE", "HOP"]]
	var tail := [["SHIFT", "DODGE ROLL"], ["E", "USE"], ["H", "POTION"], ["TAB", "ROLL LOG"], ["WHEEL", "MUSIC VOL"], ["ESC", "PAUSE"]]
	var mid: Array = []
	match key:
		"ceridwen": mid = [["J/CLICK", "FIRE BOLT"], ["K", "MAGIC MISSILE"], ["L", "FIREBALL" if level >= 6 else "SCORCHING RAY"], ["I", "FORESIGHT"]]
		"erwar": mid = [["J/CLICK", "MACE"], ["K", "HEALING WORD"], ["L", "SPIRIT GUARDIANS" if level >= 6 else "SPIRIT WEAPON"], ["I", "WAR BLESSING"]]
		"lyburnum": mid = [["J/CLICK", "LONGSWORD"], ["K", "LAY ON HANDS"], ["L", "DIVINE SMITE"], ["I", "DREAD AURA"]]
		"suilean": mid = [["J/CLICK", "THORN WHIP"], ["K", "ENTANGLE"], ["L", "MOONBEAM"], ["I", "BEAR FORM"], ["Y", "SPIDER FORM"]]
		_: mid = [["J/CLICK", "ATTACK"], ["K", "RAGE"], ["L", "RECKLESS"], ["I", "ECHO / SWAP"], ["Y/RMB", "MOVE ECHO"]]
	return head + mid + tail
