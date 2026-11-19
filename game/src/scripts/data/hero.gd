class_name Hero
extends RefCounted
## A persistent hero: saved between runs. Stats come from the hero kit and level (see Kits).

const XP_THRESHOLDS := [0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000]   # XP for levels 1..10
const MAX_LEVEL := 10

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
var quest_given := false   # the Hooded Stranger has given the cellar quest
var sewer_quest := false   # ... and, at 5th level, the Waterdeep Sewers quest (the grate opens)
var sewer_tier := 4        # difficulty in the sewers (Tier IV-VI)
var sewer_tier_unlocked := 4
var tier := 1


## Which party member this is (see Kits.ORDER).
var key := "boarvhal"


func set_key(k: String) -> void:
	key = k if Kits.has(k) else "boarvhal"
	name = Kits.info(key).name
	title = Kits.info(key).title


func short() -> String:
	return Kits.info(key).short


func pronoun(which: String) -> String:
	return Kits.info(key).get(which, "they")


## Strength saving throw bonus (used against shoves).
func str_save() -> int:
	return int(combat_stats().str_save)


func proficiency() -> int:
	return Kits.prof(level)


func max_hp() -> int:
	return int(combat_stats().hp)


func ac() -> int:
	return int(combat_stats().ac)


func rage_uses() -> int:
	return int(combat_stats().rage_uses)


func next_level_xp() -> int:
	return XP_THRESHOLDS[level] if level < MAX_LEVEL else -1


func has_reckless() -> bool:
	return key == "boarvhal" and level >= 2


func has_echo() -> bool:
	return key == "boarvhal" and level >= 3


func has_extra_attack() -> bool:
	return bool(combat_stats().extra_attack)


## Combat numbers in the shape the real-time and turn-based layers use.
func combat_stats() -> Dictionary:
	var s := Kits.stats(key, level)
	s.name = name
	return s


## Adds XP and returns the number of levels gained.
func add_xp(amount: int) -> int:
	xp += amount
	var gained := 0
	while level < MAX_LEVEL and xp >= XP_THRESHOLDS[level]:
		level += 1
		gained += 1
	return gained


func level_features(lv: int) -> String:
	return Kits.level_features(key, lv)


func to_dict() -> Dictionary:
	return {"id": id, "owner": owner, "name": name, "level": level, "xp": xp, "gold": gold, "potions": potions,
		"runs": runs, "clears": clears, "deaths": deaths, "kills": kills, "best_depth": best_depth,
		"nat20s": nat20s, "biggest_hit": biggest_hit, "tier_unlocked": tier_unlocked, "tier": tier, "quest_given": quest_given, "sewer_quest": sewer_quest,
		"sewer_tier": sewer_tier, "sewer_tier_unlocked": sewer_tier_unlocked, "class": key, "updated": Time.get_unix_time_from_system()}


func load_dict(d: Dictionary) -> void:
	for k in ["level", "xp", "gold", "potions", "runs", "clears", "deaths", "kills", "best_depth", "nat20s", "biggest_hit", "tier_unlocked", "tier"]:
		if d.has(k):
			set(k, int(d[k]))
	level = clampi(level, 1, MAX_LEVEL)
	quest_given = bool(d.get("quest_given", false))
	sewer_quest = bool(d.get("sewer_quest", false))
	sewer_tier = clampi(int(d.get("sewer_tier", 4)), 4, 6)
	sewer_tier_unlocked = clampi(int(d.get("sewer_tier_unlocked", 4)), 4, 6)
	tier_unlocked = clampi(tier_unlocked, 1, 3)
	tier = clampi(tier, 1, tier_unlocked)
