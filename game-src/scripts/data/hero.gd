class_name Hero
extends RefCounted
## A persistent hero: saved between runs. Stats are derived from level (2014 Barbarian table, SRD 5.1).

const XP_THRESHOLDS := [0, 300, 900, 2700, 6500]   # XP needed for levels 1..5
const MAX_LEVEL := 5

var id := "guest_boarvhal"
var owner := ""
var name := "Boar-vhal Rockhauler"
var title := "Goliath Barbarian"
var level := 1
var xp := 0
var gold := 0
var potions := 1
var runs := 0
var clears := 0
var deaths := 0
var kills := 0
var best_depth := 0
var nat20s := 0
var biggest_hit := 0
var tier_unlocked := 1
var tier := 1


func str_score() -> int:
	return 17 + (2 if level >= 4 else 0)   # Ability Score Improvement at 4


func str_mod() -> int:
	return Rules.ability_mod(str_score())


func proficiency() -> int:
	return 2 if level < 5 else 3


func max_hp() -> int:
	# 12 + CON at 1st level, then the fixed average 7 + CON per level.
	return 15 + (level - 1) * 10


func ac() -> int:
	return 14   # Unarmored Defense: 10 + DEX 1 + CON 3


func rage_uses() -> int:
	return 2 if level < 3 else 3


func next_level_xp() -> int:
	return XP_THRESHOLDS[level] if level < MAX_LEVEL else -1


func has_reckless() -> bool:
	return level >= 2


func has_echo() -> bool:
	return level >= 3


func has_extra_attack() -> bool:
	return level >= 5


## Combat numbers in the shape the real-time and turn-based layers use.
func combat_stats() -> Dictionary:
	var atk := str_mod() + proficiency()
	return {
		"name": name,
		"title": "%s %d" % [title, level],
		"ac": ac(),
		"hp": max_hp(),
		"speed_ft": 30 + (10 if level >= 5 else 0),   # Fast Movement at 5
		"proficiency": proficiency(),
		"weapon": {"name": "Greataxe", "attack": atk, "count": 1, "sides": 12, "bonus": str_mod(), "type": "slashing"},
		"rage_uses": rage_uses(),
		"rage_damage": 2,
		"rage_seconds": 60.0,
		"dex_save": 1,
		"athletics": str_mod() + proficiency(),
		"hit_die": 12,
		"con_mod": 3,
	}


## Adds XP and returns the number of levels gained.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while level < MAX_LEVEL and xp >= XP_THRESHOLDS[level]:
		level += 1
		gained += 1
	return gained


func level_features(lv: int) -> String:
	match lv:
		2: return "Reckless Attack (R / right trigger): advantage on your attacks, but enemies get advantage on you. Danger Sense: advantage on Dexterity saves."
		3: return "Echo (U / right bumper): leave a shimmering double of yourself. Goblins next to it are flanked, so you attack them with advantage. Press again to swap places. Rage uses: 3."
		4: return "Ability Score Improvement: Strength 19. +1 to hit and damage."
		5: return "Extra Attack: much faster axe swings. Fast Movement: +10 ft speed. Proficiency +3."
	return ""


func to_dict() -> Dictionary:
	return {"id": id, "owner": owner, "name": name, "level": level, "xp": xp, "gold": gold, "potions": potions,
		"runs": runs, "clears": clears, "deaths": deaths, "kills": kills, "best_depth": best_depth,
		"nat20s": nat20s, "biggest_hit": biggest_hit, "tier_unlocked": tier_unlocked, "tier": tier, "class": "barbarian", "updated": Time.get_unix_time_from_system()}


func load_dict(d: Dictionary) -> void:
	for k in ["level", "xp", "gold", "potions", "runs", "clears", "deaths", "kills", "best_depth", "nat20s", "biggest_hit", "tier_unlocked", "tier"]:
		if d.has(k):
			set(k, int(d[k]))
	level = clampi(level, 1, MAX_LEVEL)
	tier_unlocked = clampi(tier_unlocked, 1, 3)
	tier = clampi(tier, 1, tier_unlocked)
