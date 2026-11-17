class_name Dice
extends RefCounted
## Seeded dice roller. Every random number in the rules comes from here,
## so a run with the same seed rolls the same dice.

enum Mode { DISADVANTAGE = -1, NORMAL = 0, ADVANTAGE = 1 }

var rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value


func die(sides: int) -> int:
	return rng.randi_range(1, sides)


## Rolls `count` dice with `sides` faces and returns each face.
func roll(count: int, sides: int) -> Array[int]:
	var out: Array[int] = []
	for i in count:
		out.append(die(sides))
	return out


## Rolls a d20 test. Returns {"rolls": [a] or [a, b], "kept": n, "mode": Mode}.
func d20(mode: int = Mode.NORMAL) -> Dictionary:
	var a := die(20)
	if mode == Mode.NORMAL:
		return {"rolls": [a], "kept": a, "mode": mode}
	var b := die(20)
	var kept := maxi(a, b) if mode == Mode.ADVANTAGE else mini(a, b)
	return {"rolls": [a, b], "kept": kept, "mode": mode}


## Advantage and disadvantage cancel out, however many sources there are of each.
static func combine(advantage_sources: int, disadvantage_sources: int) -> int:
	if advantage_sources > 0 and disadvantage_sources == 0:
		return Mode.ADVANTAGE
	if disadvantage_sources > 0 and advantage_sources == 0:
		return Mode.DISADVANTAGE
	return Mode.NORMAL
