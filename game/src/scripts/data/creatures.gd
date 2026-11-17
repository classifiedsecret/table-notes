class_name Creatures
## Stat data for M1. Heroes follow 2014 rules (SRD 5.1); monsters use 2024 stat blocks (SRD 5.2).
## Both SRDs are by Wizards of the Coast LLC and licensed under CC-BY-4.0.

## Boar-vhal Rockhauler at level 1 (Barbarian). STR 17, DEX 13, CON 16.
## AC = 10 + DEX + CON (Unarmored Defense). HP = 12 + CON.
const BOARVHAL := {
	"name": "Boar-vhal Rockhauler",
	"title": "Goliath Barbarian 1",
	"str": 17, "dex": 13, "con": 16,
	"ac": 14,
	"hp": 15,
	"speed_ft": 30,
	"proficiency": 2,
	"weapon": {"name": "Greataxe", "attack": 5, "count": 1, "sides": 12, "bonus": 3, "type": "slashing"},
	"rage_uses": 2,
	"rage_damage": 2,
	"rage_seconds": 60.0,   # 1 minute = 10 rounds
	"dex_save": 1,
}

## Goblin Minion (SRD 5.2, CR 1/8): AC 12, HP 7 (2d6), Dagger +4, 4 (1d4 + 2) piercing.
const GOBLIN_MINION := {
	"name": "Goblin Minion",
	"display": "Goblin",
	"ac": 12, "hp_count": 2, "hp_sides": 6,
	"speed_ft": 30,
	"weapon": {"name": "Dagger", "attack": 4, "count": 1, "sides": 4, "bonus": 2, "type": "piercing"},
	"sprite": "goblin_minion", "weapon_sprite": "weapon_knife",
	"windup": 0.42, "cooldown": 1.0, "xp": 25,
}

## Goblin Warrior (SRD 5.2, CR 1/4): AC 15, HP 10 (3d6), Scimitar +4, 5 (1d6 + 2) slashing.
const GOBLIN_WARRIOR := {
	"name": "Goblin Warrior",
	"display": "Goblin Warrior",
	"ac": 15, "hp_count": 3, "hp_sides": 6,
	"speed_ft": 30,
	"weapon": {"name": "Scimitar", "attack": 4, "count": 1, "sides": 6, "bonus": 2, "type": "slashing"},
	"sprite": "goblin_warrior", "weapon_sprite": "weapon_machete",
	"windup": 0.55, "cooldown": 1.3, "xp": 50,
}

## House rules for attack rolls (your table's call):
## a roll that misses the target's AC still lands a glancing blow for 1d4, no modifiers;
## a natural 1 always misses and the attacker takes 1d4 damage.
const GLANCING := {"count": 1, "sides": 4, "bonus": 0}
const FUMBLE_SELF := {"count": 1, "sides": 4, "bonus": 0}

## Goblin Archer: Goblin Warrior statline (SRD 5.2) without a shield, using its Shortbow +4, 5 (1d6 + 2) piercing.
const GOBLIN_ARCHER := {
	"name": "Goblin Archer",
	"display": "Goblin Archer",
	"ac": 13, "hp_count": 3, "hp_sides": 6,
	"speed_ft": 30,
	"weapon": {"name": "Shortbow", "attack": 4, "count": 1, "sides": 6, "bonus": 2, "type": "piercing"},
	"melee": {"name": "Scimitar", "attack": 4, "count": 1, "sides": 6, "bonus": 2, "type": "slashing"},
	"sprite": "goblin_warrior", "weapon_sprite": "weapon_bow",
	"windup": 0.7, "cooldown": 2.0, "xp": 50, "ranged": true,
}

## Bugbear Chief: boss of the Goblin Warren. Built on the SRD 5.2 Bugbear Warrior, tuned for one hero.
## AC 14, HP 5d8 + 5, reach 10 ft (Long-Limbed), Morningstar +4, 9 (2d6 + 2) piercing.
const BUGBEAR_CHIEF := {
	"name": "Bugbear Chief",
	"display": "Bugbear Chief",
	"ac": 14, "hp_count": 5, "hp_sides": 8, "hp_bonus": 5,
	"speed_ft": 30, "reach": 2, "dex_mod": 2, "str_save": 2,
	"weapon": {"name": "Morningstar", "attack": 4, "count": 2, "sides": 6, "bonus": 2, "type": "piercing"},
	"shove_dc": 12,
	"sprite": "bugbear_chief", "weapon_sprite": "weapon_big_hammer", "frame": [32, 36],
	"windup": 0.6, "cooldown": 1.5, "xp": 200,
}

## Dart trap: +5 to hit, 2 (1d4) piercing.
const DART := {"name": "Dart trap", "attack": 5, "count": 1, "sides": 4, "bonus": 0, "type": "piercing"}

## Spike pit in the test room: DEX save DC 12, 2d4 piercing, half on a success.
const SPIKES := {"dc": 12, "count": 2, "sides": 4, "bonus": 0, "type": "piercing"}

## Real-time conversion: 1 tile = 5 ft = 16 px; 1 round = 6 s.
const PX_PER_FT := 16.0 / 5.0
const ROUND_SECONDS := 6.0

## Waves for the test room: lists of monster keys.
const WAVES := [
	["minion", "minion"],
	["minion", "warrior"],
	["warrior", "minion", "minion"],
	["warrior", "warrior", "minion"],
]


## Difficulty tiers: tougher monsters and bigger rewards for higher-level heroes.
const TIERS := {
	1: {"name": "Tier I", "levels": "levels 1-2", "hp": 1.0, "atk": 0, "dmg": 0, "ac": 0, "xp": 1.0, "gold": 1.0},
	2: {"name": "Tier II", "levels": "levels 3-4", "hp": 1.8, "atk": 2, "dmg": 2, "ac": 1, "xp": 2.5, "gold": 2.0},
	3: {"name": "Tier III", "levels": "level 5", "hp": 2.6, "atk": 3, "dmg": 4, "ac": 2, "xp": 4.0, "gold": 3.0},
}


## Returns a copy of a stat block scaled for the tier.
static func scaled(base: Dictionary, tier: int) -> Dictionary:
	var t: Dictionary = TIERS[clampi(tier, 1, 3)]
	var d := base.duplicate(true)
	d.ac = int(d.ac) + int(t.ac)
	d.xp = roundi(float(d.xp) * float(t.xp))
	d["hp_scale"] = t.hp
	for k in ["weapon", "melee"]:
		if d.has(k):
			d[k].attack = int(d[k].attack) + int(t.atk)
			d[k].bonus = int(d[k].bonus) + int(t.dmg)
	return d


static func monster(key: String) -> Dictionary:
	match key:
		"warrior", "G": return GOBLIN_WARRIOR
		"archer", "a": return GOBLIN_ARCHER
		"boss", "B": return BUGBEAR_CHIEF
	return GOBLIN_MINION
