class_name Chest
extends Node2D
## A locked chest. Smashing it open is a Strength (Athletics) check, DC 12. Each failure makes noise.

var game: Node
var opened := false
var sprite: AnimatedSprite2D
var _cd := 0.0


func _ready() -> void:
	sprite = AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.set_animation_loop("default", false)
	sf.set_animation_speed("default", 8)
	for i in 3:
		sf.add_frame("default", Art.region("chest_full_open_anim_f%d" % i))
	sprite.sprite_frames = sf
	sprite.offset = Vector2(0, -8)
	add_child(sprite)


func _process(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)


func prompt() -> String:
	return "" if opened else "E: SMASH OPEN"


func interact(p: Player) -> void:
	if opened or _cd > 0.0:
		return
	_cd = 1.0
	var mode := Dice.Mode.ADVANTAGE if p.raging() else Dice.Mode.NORMAL
	var chk := Rules.save(game.dice, p.stats.athletics, 12, mode)
	game.sfx.play("thud", -6.0)
	game.log_line("Strength (Athletics) check: d20 %s +%d = %d vs DC 12, %s." % [
		"%d|%d" % [chk.rolls[0], chk.rolls[1]] if chk.rolls.size() > 1 else str(chk.kept), chk.bonus, chk.total, "success" if chk.success else "failure"])
	if not chk.success:
		game.toast("The lid holds. The racket echoes through the warren...")
		if game.dice.die(100) <= 35:
			game.spawn_monster("minion", global_position + Vector2(-60 if p.global_position.x > global_position.x else 60, 0))
			game.toast("The noise draws a goblin!")
		return
	opened = true
	sprite.play()
	var gp: int = roundi(((game.dice.roll(2, 6).reduce(func(a, b): return a + b, 0)) * 5 + 5 * game.hero.level) * float(Creatures.TIERS[game.hero.tier].gold))
	var potion: bool = game.dice.die(100) <= 50
	game.run_gold += gp
	if potion:
		game.run_potions += 1
	game.toast("The chest bursts open: %d gp%s." % [gp, " and a Potion of Healing" if potion else ""])
	game.log_line("Chest: %d gp%s." % [gp, ", Potion of Healing" if potion else ""])
	game.sfx.play("crit", -10.0)
