class_name HeroKit
extends Node
## Class resources and abilities for the hero being played, in real time.
## The Player owns movement, the basic attack and damage; this owns spells and features.

const SPELL_COLORS := {"fire": Color(1.0, 0.55, 0.2), "force": Color(0.7, 0.6, 1.0),
	"radiant": Color(1.0, 0.95, 0.6), "nature": Color(0.5, 0.85, 0.4)}

var p: Player
var game: Node
var key := "boarvhal"
var s: Dictionary = {}

var slots := [0, 0]           # 1st-level, 2nd-level-and-higher
var lay_pool := 0
var channel := 0              # War Blessing / Dread Aura uses
var wild_uses := 0
var foresight: Array = []     # unused Foresight d20s
var foresight_armed := -1     # index into foresight, -1 when none is readied
var blessing_armed := false
var smite_on := false
var relentless_ready := true
var form := ""                # "", "bear" or "spider"
var form_hp := 0
var form_max := 0
var spirit: SpellZone
var concentration: SpellZone  # Entangle or Moonbeam
var _cast_t := 0.0
var _level := 0


func setup(player: Player, g: Node) -> void:
	p = player
	game = g
	refresh()


## Re-reads the hero's numbers (new hero or level-up). New maximums top up what's left.
func refresh() -> void:
	var old := s
	key = p.hero.key if p.hero else "boarvhal"
	s = p.stats
	if old.is_empty() or old.get("key", "") != key:
		_level = int(p.hero.level) if p.hero else 1
		long_rest()
		return
	for i in 2:
		slots[i] += maxi(0, int(s.slots[i]) - int(old.slots[i]))
	lay_pool += maxi(0, int(s.lay_pool) - int(old.lay_pool))
	channel += maxi(0, int(s.channel) - int(old.channel))
	wild_uses += maxi(0, int(s.wild_uses) - int(old.wild_uses))
	if key == "ceridwen" and int(p.hero.level) >= 2 and _level < 2 and foresight.is_empty():
		_roll_foresight()
	_level = int(p.hero.level)


## Start of a delve: everything back.
func long_rest() -> void:
	slots = (s.slots as Array).duplicate()
	lay_pool = int(s.lay_pool)
	channel = int(s.channel)
	wild_uses = int(s.wild_uses)
	relentless_ready = true
	blessing_armed = false
	smite_on = false
	foresight.clear()
	foresight_armed = -1
	if key == "ceridwen" and p.hero and p.hero.level >= 2:
		_roll_foresight()
	end_form(false)
	end_zone(spirit)
	end_zone(concentration)


func _roll_foresight() -> void:
	foresight = [game.dice.die(20), game.dice.die(20)]
	foresight_armed = -1
	game.log_line("Foresight: Ceridwen glimpses %d and %d. Press U to ready one." % [foresight[0], foresight[1]])


## Campfire short rest: Channel Divinity and Wild Shape come back.
func short_rest() -> String:
	var parts: Array[String] = []
	if int(s.channel) > 0 and channel < int(s.channel):
		channel = int(s.channel)
		parts.append("Channel Divinity restored")
	if int(s.wild_uses) > 0 and wild_uses < int(s.wild_uses):
		wild_uses = int(s.wild_uses)
		parts.append("Wild Shape restored")
	if key == "ceridwen" and slots[0] < int(s.slots[0]):
		slots[0] += 1   # Arcane Recovery
		parts.append("Arcane Recovery: one spell slot back")
	return ", ".join(parts)


func busy() -> bool:
	return _cast_t > 0.0


func _physics_process(delta: float) -> void:
	_cast_t = maxf(0.0, _cast_t - delta)


func press(slot: String) -> void:
	if p.is_down():
		return
	var id: String = s.abilities.get(slot, "")
	if id == "":
		var lock: Array = s.locked.get(slot, [])
		if not lock.is_empty():
			game.toast("%s unlocks at level %d." % [lock[1], lock[0]])
		return
	if form != "" and id not in ["bear", "spider"]:
		game.toast("Beasts can't cast spells. Press U or Y to change back.")
		return
	if _cast_t > 0.0:
		return
	match id:
		"rage": p._try_rage()
		"reckless": p._toggle_reckless()
		"echo": p._try_echo()
		"echo_move":
			if is_instance_valid(p.echo):
				p.command_echo(p.echo.global_position + Vector2(p.facing * Player.ECHO_RANGE_PX, 0))
			else:
				game.toast("No echo to command. Press U to make one.")
		"magic_missile": _magic_missile()
		"scorching_ray": _scorching_ray()
		"foresight": _cycle_foresight()
		"healing_word": _healing_word()
		"spiritual_weapon": _spiritual_weapon()
		"war_blessing": _war_blessing()
		"lay_on_hands": _lay_on_hands()
		"smite": _toggle_smite()
		"dread_aura": _dread_aura()
		"entangle": _entangle()
		"moonbeam": _moonbeam()
		"bear", "spider": _wild_shape(id)


# ---------------- shared helpers ----------------

## Spends the lowest slot of at least `min_level` (1 or 2). Returns the level spent, 0 if none.
func _spend_slot(min_level := 1) -> int:
	if min_level <= 1 and slots[0] > 0:
		slots[0] -= 1
		return 1
	if slots[1] > 0:
		slots[1] -= 1
		return 2
	return 0


func _no_slot(min_level := 1) -> void:
	game.toast("No %sspell slots left. They return on a long rest at the tavern." % ("" if min_level <= 1 else "2nd-level "))


func _bonus_ready() -> bool:
	if p.bonus_cd > 0.0:
		game.toast("Bonus action recharging (%.0fs)" % ceilf(p.bonus_cd))
		return false
	return true


func _enemies_in_view() -> Array:
	var out := []
	for e: Enemy in game.living_enemies():
		var d: Vector2 = e.global_position - p.global_position
		if absf(d.x) < 250.0 and absf(d.y) < 140.0:
			out.append(e)
	out.sort_custom(func(x, y): return x.global_position.distance_to(p.global_position) < y.global_position.distance_to(p.global_position))
	return out


func _face(e: Node2D) -> void:
	p.facing = 1 if e.global_position.x >= p.global_position.x else -1
	p.visual.scale.x = p.facing


func _hand() -> Vector2:
	return p.global_position + Vector2(p.facing * 8.0, -14.0)


## A spell attack roll against an enemy, reported like a weapon attack.
func spell_attack(e: Enemy, label: String, count: int, sides: int, bonus: int, dtype: String) -> Dictionary:
	var wpn := {"name": label, "attack": int(s.spell_attack), "count": count, "sides": sides, "bonus": bonus, "type": dtype, "spell": true}
	return p.roll_attack(e, wpn)


func enemy_save(e: Enemy, ability: String, label: String) -> Dictionary:
	var sv := Rules.save(game.dice, e.save_bonus(ability), int(s.spell_dc))
	game.log_line("%s %s save: d20 %d %+d = %d vs DC %d, %s." % [e.data.name, ability.to_upper(), sv.kept, sv.bonus, sv.total, sv.dc,
		"resists %s" % label if sv.success else "fails"])
	return sv


func _damage_enemy(e: Enemy, amount: int, col: Color, label: String) -> void:
	if amount <= 0 or not is_instance_valid(e) or e.is_dead():
		return
	FloatText.fling(game, e.global_position + Vector2(0, -16), Vector2(randf_range(-1.2, 1.2), -0.8), str(amount), "", col, 0, 1.1)
	game.sfx.play("hit", -5.0)
	e.take_hit(amount, false, int(signf(e.global_position.x - p.global_position.x)), false)
	if not label.is_empty():
		game.log_line(label)


# ---------------- Ceridwen ----------------

func _magic_missile() -> void:
	var targets := _enemies_in_view()
	if targets.is_empty():
		game.toast("No foe in sight for Magic Missile.")
		return
	var lvl := _spend_slot(1)
	if lvl == 0:
		_no_slot()
		return
	_cast_t = 0.45
	_face(targets[0])
	p.cast_pose()
	var darts := 3 + (lvl - 1)
	game.log_line("Magic Missile (%s-level slot): %d darts of force, 1d4+1 each, never miss." % ["1st" if lvl == 1 else "2nd", darts])
	game.sfx.play("dodge", -4.0)
	for i in darts:
		var e: Enemy = targets[i % targets.size()]
		SpellFx.dart(game, _hand(), e, SPELL_COLORS.force, func(t):
			var dmg := Rules.damage(game.dice, 1, 4, 1)
			_damage_enemy(t, int(dmg.total), Color(0.8, 0.7, 1.0), "Magic Missile dart: 1d4 %s +1 = %d force to %s." % [str(dmg.faces), dmg.total, t.data.name]), i * 0.08)


func _scorching_ray() -> void:
	var targets := _enemies_in_view()
	if targets.is_empty():
		game.toast("No foe in sight for Scorching Ray.")
		return
	var lvl := _spend_slot(2)
	if lvl == 0:
		_no_slot(2)
		return
	_cast_t = 0.55
	_face(targets[0])
	p.cast_pose()
	game.log_line("Scorching Ray: three rays of fire, a ranged spell attack each.")
	for i in 3:
		var e: Enemy = targets[i % targets.size()]
		get_tree().create_timer(0.12 * i).timeout.connect(func():
			if is_instance_valid(e) and not e.is_dead():
				SpellFx.line(game, _hand(), e.global_position + Vector2(0, -8), SPELL_COLORS.fire, 0.22)
				spell_attack(e, "Scorching Ray", 2, 6, 0, "fire"))


func _cycle_foresight() -> void:
	if foresight.is_empty():
		game.toast("No Foresight dice left this delve.")
		return
	foresight_armed += 1
	if foresight_armed >= foresight.size():
		foresight_armed = -1
	if foresight_armed < 0:
		game.toast("Foresight put away.")
	else:
		game.toast("Foresight ready: the next attack roll, yours or a foe's against you, will be a %d." % foresight[foresight_armed])


## Called for every attack roll that involves the hero. Returns the forced d20, or 0.
func take_foresight() -> int:
	if foresight_armed < 0 or foresight_armed >= foresight.size():
		return 0
	var v: int = foresight[foresight_armed]
	foresight.remove_at(foresight_armed)
	foresight_armed = -1
	game.log_line("Foresight: the d20 is a %d, as Ceridwen foresaw." % v)
	game.banner("FORESIGHT %d" % v, Color(0.75, 0.7, 1.0))
	return v


# ---------------- Erwar ----------------

func _healing_word() -> void:
	if p.hp >= p.max_hp:
		game.toast("Already at full health.")
		return
	if not _bonus_ready():
		return
	var lvl := _spend_slot(1)
	if lvl == 0:
		_no_slot()
		return
	p.bonus_cd = Player.BONUS_ACTION_COOLDOWN
	var dmg := Rules.damage(game.dice, lvl, 4, int(s.spell_mod))
	p.heal(int(dmg.total))
	SpellFx.rise(game, p.global_position + Vector2(0, -6), Color(1.0, 0.95, 0.6))
	game.toast("Healing Word: +%d HP" % dmg.total)
	game.log_line("Bonus action: Healing Word (%s-level slot), %dd4 %s %+d = %d HP." % ["1st" if lvl == 1 else "2nd", lvl, str(dmg.faces), dmg.bonus, dmg.total])
	game.sfx.play("dodge", -4.0)


func _spiritual_weapon() -> void:
	if is_instance_valid(spirit):
		game.toast("Your spectral mace is already fighting (%ds left)." % ceili(spirit.ends_in()))
		return
	if not _bonus_ready():
		return
	var lvl := _spend_slot(2)
	if lvl == 0:
		_no_slot(2)
		return
	p.bonus_cd = Player.BONUS_ACTION_COOLDOWN
	spirit = SpellZone.make(game, self, SpellZone.Kind.SPIRIT, p.global_position + Vector2(0, -28), 60.0)
	game.banner("SPIRITUAL WEAPON", Color(0.6, 0.85, 1.0))
	game.log_line("Bonus action: Spiritual Weapon. A spectral mace fights beside Erwar for a minute (1d8%+d force).")
	game.sfx.play("dodge", -4.0)


func spirit_attack(e: Enemy) -> void:
	if not is_instance_valid(e) or e.is_dead():
		return
	spell_attack(e, "Spiritual Weapon", 1, 8, int(s.spell_mod), "force")


func _war_blessing() -> void:
	if blessing_armed:
		game.toast("War Blessing is already readied.")
		return
	if channel <= 0:
		game.toast("War Blessing is spent. A campfire's short rest restores it.")
		return
	blessing_armed = true
	game.toast("War Blessing readied: your next attack that would miss gains +10.")


## Called after an attack roll misses. Returns true if the blessing turned it into a hit.
func try_blessing(atk: Dictionary, target_ac: int) -> bool:
	if not blessing_armed or atk.fumble or atk.hit or int(atk.total) + 10 < target_ac:
		return false
	blessing_armed = false
	channel -= 1
	atk.total = int(atk.total) + 10
	atk.bonus = int(atk.bonus) + 10
	atk.hit = true
	game.banner("WAR BLESSING +10", Color(1.0, 0.9, 0.5))
	game.log_line("War Blessing: +10 turns the miss into a hit.")
	return true


# ---------------- Lyburnum ----------------

func _lay_on_hands() -> void:
	if lay_pool <= 0:
		game.toast("Lay on Hands is spent. It returns on a long rest.")
		return
	if p.hp >= p.max_hp:
		game.toast("Already at full health.")
		return
	var amt := mini(lay_pool, p.max_hp - p.hp)
	lay_pool -= amt
	p.heal(amt)
	_cast_t = 0.6
	p.cast_pose()
	SpellFx.rise(game, p.global_position + Vector2(0, -6), Color(1.0, 0.95, 0.6))
	game.toast("Lay on Hands: +%d HP (%d left in the pool)" % [amt, lay_pool])
	game.log_line("Action: Lay on Hands, %d HP from the pool (%d left)." % [amt, lay_pool])


func _toggle_smite() -> void:
	if not smite_on and slots[0] + slots[1] <= 0:
		_no_slot()
		return
	smite_on = not smite_on
	game.toast("Divine Smite ON: hits spend a spell slot for radiant damage." if smite_on else "Divine Smite off.")


## Extra radiant damage for a melee hit, if Smite is on. Returns the damage dictionary or {}.
func smite_damage(crit: bool) -> Dictionary:
	if not smite_on or form != "":
		return {}
	var lvl := _spend_slot(1)
	if lvl == 0:
		smite_on = false
		game.toast("Out of spell slots: Divine Smite off.")
		return {}
	var dmg := Rules.damage(game.dice, 1 + lvl, 8, 0, crit)
	if slots[0] + slots[1] <= 0:
		smite_on = false
	SpellFx.burst(game, p.global_position + Vector2(p.facing * 18.0, -14.0), SPELL_COLORS.radiant, 16.0)
	game.log_line("Divine Smite (%s-level slot): %dd8 %s = %d radiant." % ["1st" if lvl == 1 else "2nd", dmg.faces.size(), str(dmg.faces), dmg.total])
	return dmg


func _dread_aura() -> void:
	if channel <= 0:
		game.toast("Dread Aura is spent. A campfire's short rest restores it.")
		return
	channel -= 1
	_cast_t = 0.5
	p.cast_pose()
	SpellFx.burst(game, p.global_position + Vector2(0, -12), Color(0.75, 0.4, 0.9), 96.0, 0.7)
	game.banner("DREAD AURA", Color(0.8, 0.5, 1.0))
	game.sfx.play("thud", -2.0)
	var n := 0
	for e: Enemy in game.living_enemies():
		if e.global_position.distance_to(p.global_position) <= 96.0:
			var sv := enemy_save(e, "wis", "the fear")
			if not sv.success:
				e.frighten(10.0)
				n += 1
	game.log_line("Dread Aura: %d foe%s flee in terror." % [n, "" if n == 1 else "s"])


## Half-Orc Relentless Endurance: once per delve, drop to 1 HP instead of 0.
func try_relentless() -> bool:
	if not s.get("relentless", false) or not relentless_ready:
		return false
	relentless_ready = false
	game.banner("RELENTLESS ENDURANCE", Color(1.0, 0.6, 0.4))
	game.log_line("Relentless Endurance: Lyburnum drops to 1 HP instead of 0 (once per delve).")
	return true


# ---------------- Suilean ----------------

func _entangle() -> void:
	var lvl := _spend_slot(1)
	if lvl == 0:
		_no_slot()
		return
	end_zone(concentration)
	_cast_t = 0.5
	p.cast_pose()
	var at := _ground_at_foe(56.0)
	concentration = SpellZone.make(game, self, SpellZone.Kind.ENTANGLE, at, 30.0)
	game.log_line("Entangle: grasping vines fill a 20-foot square. Strength save DC %d or be restrained (concentration)." % s.spell_dc)
	game.sfx.play("dodge", -6.0)


func entangle_save(e: Enemy) -> bool:
	return enemy_save(e, "str", "the vines").success


func _moonbeam() -> void:
	var at := _ground_at_foe(64.0)
	if is_instance_valid(concentration) and concentration.kind == SpellZone.Kind.MOONBEAM:
		concentration.move_to(at)
		_cast_t = 0.4
		game.toast("Moonbeam moved.")
		return
	var lvl := _spend_slot(2)
	if lvl == 0:
		_no_slot(2)
		return
	end_zone(concentration)
	_cast_t = 0.5
	p.cast_pose()
	concentration = SpellZone.make(game, self, SpellZone.Kind.MOONBEAM, at, 30.0)
	concentration.half_w = 10.0
	game.log_line("Moonbeam: a silver beam (Constitution save DC %d, 2d10 radiant, half on a success). Press R again to move it." % s.spell_dc)
	game.sfx.play("dodge", -6.0)


func moonbeam_hit(e: Enemy) -> void:
	var sv := enemy_save(e, "con", "half the light")
	var dmg := Rules.damage(game.dice, 2, 10, 0)
	var total: int = dmg.total if not sv.success else floori(dmg.total / 2.0)
	_damage_enemy(e, total, Color(0.85, 0.92, 1.0), "Moonbeam: 2d10 %s = %d radiant to %s%s." % [str(dmg.faces), dmg.total, e.data.name, " (halved: %d)" % total if sv.success else ""])


## Ground spells land under the nearest foe in range (auto-aim), else in front of the hero.
func _ground_at_foe(fallback: float) -> Vector2:
	var e := p.nearest_enemy(180.0)
	if e:
		p.facing = 1 if e.global_position.x >= p.global_position.x else -1
		p.visual.scale.x = p.facing
		return Vector2(e.global_position.x, e.global_position.y) if e.is_on_floor() else _ground_below(e.global_position)
	return _ground_ahead(fallback)


func _ground_below(at: Vector2) -> Vector2:
	var room: Room = game.room
	var y := at.y
	for i in 12:
		if room.is_solid_cell(floori(at.x / Room.T), floori((y + 1.0) / Room.T)):
			break
		y += Room.T
	return Vector2(at.x, floorf(y / Room.T) * Room.T)


## A point on the floor in front of the hero (the zone sits on the ground).
func _ground_ahead(dist: float) -> Vector2:
	var room: Room = game.room
	var x := p.global_position.x + p.facing * dist
	var y := p.global_position.y
	for i in 8:
		if room.is_solid_cell(floori(x / Room.T), floori((y + 1.0) / Room.T)):
			break
		y += Room.T
	return Vector2(x, floorf(y / Room.T) * Room.T if y != p.global_position.y else y)


func zone_ended(z: SpellZone) -> void:
	if z == concentration:
		concentration = null
		game.log_line("Concentration ends.")
	if z == spirit:
		spirit = null
		game.log_line("The spectral mace fades.")


func end_zone(z: SpellZone) -> void:
	if is_instance_valid(z):
		z.queue_free()
	if z == concentration:
		concentration = null
	if z == spirit:
		spirit = null


## Taking damage while concentrating: Constitution save, DC 10 or half the damage.
func concentration_check(amount: int) -> void:
	if not is_instance_valid(concentration):
		return
	var dc := maxi(10, floori(amount / 2.0))
	var sv := Rules.save(game.dice, int(s.con_save), dc)
	game.log_line("Concentration: CON save d20 %d %+d = %d vs DC %d, %s." % [sv.kept, sv.bonus, sv.total, dc, "held" if sv.success else "lost"])
	if not sv.success:
		end_zone(concentration)
		game.toast("Concentration broken!")


func _wild_shape(which: String) -> void:
	if form == which:
		end_form(true)
		return
	if wild_uses <= 0:
		game.toast("Wild Shape is spent. A campfire's short rest restores it.")
		return
	wild_uses -= 1
	end_zone(concentration)
	var f: Dictionary = Kits.FORMS[which]
	form = which
	form_max = int(f.hp)
	form_hp = form_max
	p.set_form(f)
	SpellFx.burst(game, p.global_position + Vector2(0, -8), SPELL_COLORS.nature, 18.0)
	game.banner(str(f.name).to_upper(), Color(0.6, 0.9, 0.5))
	game.log_line("Wild Shape: Suilean becomes a %s (%d HP, AC %d). %d use%s left." % [f.name, f.hp, f.ac, wild_uses, "" if wild_uses == 1 else "s"])
	game.sfx.play("thud", -6.0)


func end_form(announce: bool) -> void:
	if form == "":
		return
	form = ""
	form_hp = 0
	p.set_form({})
	if announce:
		SpellFx.burst(game, p.global_position + Vector2(0, -8), SPELL_COLORS.nature, 14.0)
		game.log_line("Suilean returns to her own shape.")


## Damage taken while in beast form comes off the beast first. Returns what carries over.
func absorb(amount: int) -> int:
	if form == "":
		return amount
	form_hp -= amount
	if form_hp > 0:
		return 0
	var over := -form_hp
	game.toast("The beast form drops!")
	end_form(true)
	return over


# ---------------- HUD ----------------

func status_line() -> String:
	var sl := "SLOTS %d" % slots[0] + (" +%d" % slots[1] if int(s.slots[1]) > 0 else "")
	match key:
		"ceridwen":
			var f := ""
			for i in foresight.size():
				f += (" [%d]" % foresight[i]) if i == foresight_armed else (" %d" % foresight[i])
			return sl + ("  FORESIGHT" + f if not foresight.is_empty() else "")
		"erwar":
			var t := sl
			if int(s.channel) > 0:
				t += "  BLESS %s" % ("READY" if blessing_armed else str(channel))
			if is_instance_valid(spirit):
				t += "  MACE %dS" % ceili(spirit.ends_in())
			return t
		"lyburnum":
			var t := "HANDS %d" % lay_pool
			if int(s.slots[0]) > 0:
				t += "  SMITE %s %d" % ["ON" if smite_on else "OFF", slots[0] + slots[1]]
			if int(s.channel) > 0:
				t += "  AURA %d" % channel
			return t
		"suilean":
			if form != "":
				return "%s %d/%d  SHAPES %d" % [str(Kits.FORMS[form].name).to_upper(), maxi(0, form_hp), form_max, wild_uses]
			var t := sl
			if int(s.wild_uses) > 0:
				t += "  SHAPES %d" % wild_uses
			if is_instance_valid(concentration):
				t += "  %s %dS" % ["VINES" if concentration.kind == SpellZone.Kind.ENTANGLE else "BEAM", ceili(concentration.ends_in())]
			return t
	return ""
