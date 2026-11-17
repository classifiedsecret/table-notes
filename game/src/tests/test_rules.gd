extends SceneTree
## Rules core tests. Run: godot --headless --script res://tests/test_rules.gd

var failures := 0
var checks := 0


func check(cond: bool, label: String) -> void:
	checks += 1
	if not cond:
		failures += 1
		printerr("FAIL: ", label)


func _init() -> void:
	var dice := Dice.new(12345)

	# d20 range and rough uniformity over 20,000 rolls.
	var counts := {}
	for i in 20000:
		var r := dice.die(20)
		counts[r] = counts.get(r, 0) + 1
	check(counts.size() == 20 and counts.keys().min() == 1 and counts.keys().max() == 20, "d20 covers 1..20")
	for k in counts:
		check(abs(counts[k] - 1000) < 150, "d20 face %d roughly uniform (%d)" % [k, counts[k]])

	# Advantage keeps the higher, disadvantage the lower; averages move the right way.
	var adv_sum := 0
	var dis_sum := 0
	for i in 5000:
		var a := dice.d20(Dice.Mode.ADVANTAGE)
		check(a.kept == maxi(a.rolls[0], a.rolls[1]), "advantage keeps higher")
		adv_sum += a.kept
		var d := dice.d20(Dice.Mode.DISADVANTAGE)
		check(d.kept == mini(d.rolls[0], d.rolls[1]), "disadvantage keeps lower")
		dis_sum += d.kept
	check(abs(adv_sum / 5000.0 - 13.825) < 0.4, "advantage mean about 13.8")
	check(abs(dis_sum / 5000.0 - 7.175) < 0.4, "disadvantage mean about 7.2")
	check(Dice.combine(2, 1) == Dice.Mode.NORMAL, "adv and dis cancel")
	check(Dice.combine(1, 0) == Dice.Mode.ADVANTAGE, "adv alone")
	check(Dice.combine(0, 3) == Dice.Mode.DISADVANTAGE, "dis alone")

	# Natural 20 always hits and crits; natural 1 always misses.
	var saw_crit := false
	var saw_fumble := false
	for i in 4000:
		var hi := Rules.attack(dice, 0, 30)
		if hi.kept == 20:
			saw_crit = true
			check(hi.hit and hi.crit, "nat 20 hits AC 30")
		elif true:
			check(not hi.hit, "non-20 misses AC 30")
		var lo := Rules.attack(dice, 50, 5)
		if lo.kept == 1:
			saw_fumble = true
			check(not lo.hit and lo.fumble, "nat 1 misses even at +50")
		else:
			check(lo.hit, "+50 hits AC 5")
	check(saw_crit and saw_fumble, "saw both nat 20 and nat 1")

	# Hit chance for +5 vs AC 12 is (20 - 12 + 5 + 1) / 20 = 70%.
	var hits := 0
	for i in 20000:
		if Rules.attack(dice, 5, 12).hit:
			hits += 1
	check(abs(hits / 20000.0 - 0.70) < 0.02, "+5 vs AC 12 hits about 70%% (%.3f)" % (hits / 20000.0))

	# Damage: crit doubles dice not bonus; resistance halves rounding down; minimum rule.
	for i in 2000:
		var dmg := Rules.damage(dice, 1, 12, 3)
		check(dmg.faces.size() == 1 and dmg.total >= 4 and dmg.total <= 15, "1d12+3 in 4..15")
		var c := Rules.damage(dice, 1, 12, 3, true)
		check(c.faces.size() == 2 and c.total >= 5 and c.total <= 27, "crit 2d12+3 in 5..27")
	var res := Rules.damage(dice, 1, 4, 2, false, true, true)
	check(res.raw == 3 and res.total == 1, "resisted minimum 1d4+2 = 3 halves to 1")
	var mn := Rules.damage(dice, 2, 6, 0, false, false, true)
	check(mn.total == 2, "minimum 2d6 = 2")

	# Saving throws: natural 20 is not an automatic success.
	var auto_pass := false
	for i in 3000:
		var s := Rules.save(dice, 0, 25)
		if s.success:
			auto_pass = true
	check(not auto_pass, "DC 25 save with +0 never succeeds")

	# Death saves: three successes stabilise, three failures kill, nat 1 counts double, nat 20 revives.
	var ds := Rules.DeathSaves.new()
	check(ds.apply({"effect": "success"}) == "", "1 success")
	check(ds.apply({"effect": "fail"}) == "", "1 fail")
	check(ds.apply({"effect": "fail2"}) == "dead", "nat 1 makes 3 failures")
	ds.reset()
	ds.apply({"effect": "success"}); ds.apply({"effect": "success"})
	check(ds.apply({"effect": "success"}) == "stable", "3 successes stable")
	ds.reset()
	check(ds.apply({"effect": "revive"}) == "revive", "nat 20 revives")
	ds.reset()
	check(ds.take_damage(true) == "" and ds.failures == 2, "crit at 0 HP is two failures")
	check(ds.take_damage(false) == "dead", "then one more kills")
	var effects := {}
	for i in 4000:
		var r := Rules.death_save(dice)
		effects[r.effect] = effects.get(r.effect, 0) + 1
		if r.roll == 20: check(r.effect == "revive", "20 revives")
		elif r.roll == 1: check(r.effect == "fail2", "1 is double fail")
		elif r.roll >= 10: check(r.effect == "success", "10+ succeeds")
		else: check(r.effect == "fail", "2-9 fails")

	# Ability modifiers.
	check(Rules.ability_mod(17) == 3 and Rules.ability_mod(10) == 0 and Rules.ability_mod(9) == -1 and Rules.ability_mod(1) == -5, "ability mods")

	# Seeded dice repeat.
	var a1 := Dice.new(99)
	var a2 := Dice.new(99)
	check(a1.roll(10, 20) == a2.roll(10, 20), "same seed same rolls")

	print("RULES TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
