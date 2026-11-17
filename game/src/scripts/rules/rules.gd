class_name Rules
extends RefCounted
## 5e resolution: attack rolls, damage, saving throws and death saves.
## Pure functions over a Dice instance; no scene or engine state.


static func ability_mod(score: int) -> int:
	return floori((score - 10) / 2.0)


## Attack roll against Armor Class.
## Natural 20 always hits and is a critical; natural 1 always misses.
static func attack(dice: Dice, attack_bonus: int, target_ac: int, mode: int = Dice.Mode.NORMAL) -> Dictionary:
	var d := dice.d20(mode)
	var nat: int = d.kept
	var total := nat + attack_bonus
	var crit := nat == 20
	var fumble := nat == 1
	var hit := crit or (not fumble and total >= target_ac)
	return {
		"rolls": d.rolls, "kept": nat, "mode": d.mode, "bonus": attack_bonus,
		"total": total, "ac": target_ac, "hit": hit, "crit": crit, "fumble": fumble,
	}


## Damage roll. A critical doubles the dice, not the flat bonus.
## `resisted` halves the total, rounding down. `minimum_only` deals the
## lowest possible result (used by the optional "miss = minimum damage" rule).
static func damage(dice: Dice, count: int, sides: int, bonus: int, crit := false,
		resisted := false, minimum_only := false) -> Dictionary:
	var n := count * (2 if crit else 1)
	var faces: Array[int] = []
	if minimum_only:
		for i in n:
			faces.append(1)
	else:
		faces = dice.roll(n, sides)
	var raw := bonus
	for f in faces:
		raw += f
	raw = maxi(raw, 0)
	var total := floori(raw / 2.0) if resisted else raw
	return {"faces": faces, "sides": sides, "bonus": bonus, "raw": raw, "total": total,
		"crit": crit, "resisted": resisted}


## Saving throw or ability check against a DC. Natural 1 and 20 are not automatic.
static func save(dice: Dice, bonus: int, dc: int, mode: int = Dice.Mode.NORMAL) -> Dictionary:
	var d := dice.d20(mode)
	var total: int = d.kept + bonus
	return {"rolls": d.rolls, "kept": d.kept, "mode": d.mode, "bonus": bonus,
		"total": total, "dc": dc, "success": total >= dc}


## One death saving throw. Returns the d20 and its effect:
## "revive" (natural 20: regain 1 HP), "success" (10+), "fail", or "fail2" (natural 1: two failures).
static func death_save(dice: Dice) -> Dictionary:
	var r := dice.die(20)
	var effect := "success"
	if r == 20:
		effect = "revive"
	elif r == 1:
		effect = "fail2"
	elif r < 10:
		effect = "fail"
	return {"roll": r, "effect": effect}


## Tracks the three-and-three tally while a creature is at 0 hit points.
class DeathSaves:
	var successes := 0
	var failures := 0

	func reset() -> void:
		successes = 0
		failures = 0

	## Applies one death save result; returns "revive", "stable", "dead" or "".
	func apply(result: Dictionary) -> String:
		match result.effect:
			"revive":
				return "revive"
			"success":
				successes += 1
			"fail":
				failures += 1
			"fail2":
				failures += 2
		if failures >= 3:
			failures = 3
			return "dead"
		if successes >= 3:
			return "stable"
		return ""

	## Taking damage at 0 HP is one failure; a critical hit is two.
	func take_damage(crit: bool) -> String:
		failures += 2 if crit else 1
		if failures >= 3:
			failures = 3
			return "dead"
		return ""
