class_name Echo
extends Node2D
## Boar-vhal's Echo (Echo Knight): a shimmering double. Goblins treat it as a foe: it has
## AC 14 + Boar-vhal's proficiency bonus and 1 hit point, so any hit destroys it.

var game: Node
var ac := 16


func is_down() -> bool:
	return false


func is_invulnerable() -> bool:
	return false


func airborne() -> bool:
	return false


func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-6, -20), Vector2(12, 22))


func receive_attack(enemy: Node2D, wpn: Dictionary) -> void:
	var atk := Rules.attack(game.dice, int(wpn.attack), ac)
	var who: String = enemy.data.name if "data" in enemy else "A goblin"
	game.log_line("%s: %s vs the echo, d20 %d %+d = %d vs AC %d, %s." % [who, wpn.name, atk.kept, atk.bonus, atk.total, ac, "it shatters" if atk.hit else "miss"])
	if not atk.hit:
		FloatText.fling(game, global_position + Vector2(0, -20), Vector2(0, -0.8), "MISS", "", Color(0.75, 0.75, 0.8), 0, 0.9)
		game.sfx.play("deflect", -8.0)
		return
	SpellFx.burst(game, global_position + Vector2(0, -12), Color(0.55, 0.75, 1.0), 14.0, 0.4)
	FloatText.fling(game, global_position + Vector2(0, -24), Vector2(0, -1), "ECHO DESTROYED", "", Color(0.6, 0.8, 1.0), 0, 1.0)
	game.sfx.play("deflect", -4.0)
	game.toast("Your echo is destroyed.")
	game.player.reclaim_potential()
	queue_free()
