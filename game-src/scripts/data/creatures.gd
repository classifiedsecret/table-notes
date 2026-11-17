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


static func monster(key: String) -> Dictionary:
	return GOBLIN_WARRIOR if key == "warrior" else GOBLIN_MINION
