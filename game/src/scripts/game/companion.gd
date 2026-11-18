class_name Companion
extends CharacterBody2D
## A party member who joined the delve. Follows the hero, fights with their own kit
## (Kits.stats at the hero's level), and lends a hand: Erwar's Healing Word,
## Lyburnum's Lay on Hands. Knocked out at 0 HP; the party patches them up between rooms.

const T := 16.0
const JUMP_VELOCITY := -322.0
const ATTACK_COOLDOWN := 1.35

var game: Node
var key := ""
var stats: Dictionary
var hp := 10
var max_hp := 10
var ac := 10
var facing := 1
var index := 0                 # place in the marching order
var visual: Node2D
var sprite: AnimatedSprite2D
var weapon_pivot: Node2D
var tag: Label
var down := false
var _cd := 0.5
var _support_cd := 3.0
var _stuck_t := 0.0
var _rage_room := false
var slots := 0
var lay_pool := 0


static func make(g: Node, k: String, level: int, i: int) -> Companion:
	var c := Companion.new()
	c.game = g
	c.key = k
	c.index = i
	c.stats = Kits.stats(k, level)
	c.max_hp = int(c.stats.hp)
	c.hp = c.max_hp
	c.ac = int(c.stats.ac)
	c.slots = int(c.stats.slots[0]) + int(c.stats.slots[1])
	c.lay_pool = int(c.stats.lay_pool)
	return c


func short_name() -> String:
	return Kits.info(key).short


func _ready() -> void:
	collision_layer = 0
	collision_mask = Room.LAYER_SOLID | Room.LAYER_PLATFORM
	floor_snap_length = 6.0
	z_index = 4
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 22)
	shape.shape = r
	shape.position = Vector2(0, -11)
	add_child(shape)
	visual = Node2D.new()
	visual.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(visual)
	var info := Kits.info(key)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.strip_frames(load("res://assets/sprites/%s.png" % info.sprite), 16, 28, {
		"idle": [0, 4, 6, true], "run": [4, 4, 11, true], "hit": [8, 1, 1, false]})
	sprite.offset = Vector2(0, -14)
	sprite.play("idle")
	visual.add_child(sprite)
	weapon_pivot = Node2D.new()
	weapon_pivot.position = Vector2(3, -9)
	weapon_pivot.rotation = -0.55
	visual.add_child(weapon_pivot)
	var w := Sprite2D.new()
	w.texture = Art.region(info.weapon_sprite)
	w.offset = Vector2(0, -9)
	weapon_pivot.add_child(w)
	tag = Label.new()
	tag.label_settings = Art.label_settings(8, Color(0.6, 1.0, 0.6), 2)
	tag.text = short_name().to_upper()
	tag.position = Vector2(-20, -44)
	tag.size = Vector2(40, 10)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.z_index = 20
	add_child(tag)


func hurt_rect() -> Rect2:
	return Rect2(global_position + Vector2(-5, -22), Vector2(10, 22))


func is_down() -> bool:
	return down


func is_invulnerable() -> bool:
	return down


## Places the companion behind the hero at the start of a room.
func arrive(at: Vector2, hero_facing: int) -> void:
	global_position = at + Vector2(-hero_facing * (14.0 + 12.0 * index), 0)
	velocity = Vector2.ZERO
	reset_physics_interpolation()
	_rage_room = false
	if down:
		down = false
		hp = maxi(1, hp)
		visual.rotation = 0.0
		visual.modulate = Color.WHITE
		game.log_line("The party patches up %s (1 HP)." % short_name())


func _physics_process(delta: float) -> void:
	if not game.accepting_input() or game.phase != 1:   # real-time rooms only
		return
	var g: float = ProjectSettings.get_setting("physics/2d/default_gravity")
	velocity.y = minf(420.0, velocity.y + g * delta * (1.45 if velocity.y > 0.0 else 1.0))
	if down:
		velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
		move_and_slide()
		return
	_cd = maxf(0.0, _cd - delta)
	_support_cd = maxf(0.0, _support_cd - delta)
	var p: Player = game.player
	_support(p)
	var foe := _pick_foe()
	var goal_x := p.global_position.x - p.facing * (16.0 + 12.0 * index)
	var reach := _reach()
	if foe:
		var dx := foe.global_position.x - global_position.x
		facing = 1 if dx > 0 else -1
		var dy := absf(foe.global_position.y - global_position.y)
		if absf(dx) <= reach and dy < (40.0 if reach > 30.0 else 18.0):
			goal_x = global_position.x
			if _cd <= 0.0:
				_attack(foe)
		else:
			goal_x = foe.global_position.x - facing * (reach * 0.7)
	var to := goal_x - global_position.x
	var want := 0.0 if absf(to) < 6.0 else signf(to)
	var speed: float = Player.RUN_SPEED * float(stats.speed_ft) / 30.0
	velocity.x = move_toward(velocity.x, want * speed, 1100.0 * delta)
	if want != 0.0 and not foe:
		facing = int(want)
	visual.scale.x = facing
	# Jump walls and ledges; climb toward a hero standing higher up.
	var blocked := is_on_wall() and want != 0.0
	var hero_above := p.global_position.y < global_position.y - 24.0 and absf(p.global_position.x - global_position.x) < 70.0
	if is_on_floor() and (blocked or (hero_above and p.is_on_floor())):
		velocity.y = JUMP_VELOCITY
	move_and_slide()
	sprite.play("run" if absf(velocity.x) > 10.0 and is_on_floor() else "idle")
	# Lost the hero? Catch up the way followers do: step out of the shadows beside them.
	var far := global_position.distance_to(p.global_position) > 230.0
	_stuck_t = _stuck_t + delta if (far or (blocked and absf(velocity.x) < 5.0)) else 0.0
	if _stuck_t > 1.6 and p.is_on_floor():
		_stuck_t = 0.0
		SpellFx.burst(game, global_position + Vector2(0, -10), Color(0.7, 0.9, 0.7), 8.0, 0.3)
		global_position = p.global_position + Vector2(-p.facing * 14.0, 0)
		velocity = Vector2.ZERO
		reset_physics_interpolation()


func _reach() -> float:
	match str(stats.weapon.get("kind", "melee")):
		"bolt": return 150.0
		"whip": return 64.0
	return float(stats.weapon.get("reach", 22.0)) - 2.0


func _pick_foe() -> Enemy:
	var best: Enemy = null
	var bd := 170.0
	for e: Enemy in game.living_enemies():
		var d := e.global_position.distance_to(global_position)
		if d < bd and absf(e.global_position.y - global_position.y) < 90.0:
			bd = d
			best = e
	return best


## Healing for the hero (or the companion themself) when it is badly needed.
func _support(p: Player) -> void:
	if _support_cd > 0.0 or p.is_down():
		return
	if key == "erwar" and slots > 0 and p.hp <= p.max_hp / 2:
		slots -= 1
		var d := Rules.damage(game.dice, 1, 4, int(stats.spell_mod))
		p.heal(int(d.total))
		SpellFx.rise(game, p.global_position + Vector2(0, -6), Color(1.0, 0.95, 0.6))
		game.log_line("Erwar casts Healing Word on %s: +%d HP." % [p.short_name(), d.total])
		game.toast("Erwar: Healing Word +%d" % d.total)
		_support_cd = 8.0
	elif key == "lyburnum" and lay_pool > 0 and p.hp <= p.max_hp / 3 and global_position.distance_to(p.global_position) < 40.0:
		var amt := mini(lay_pool, p.max_hp - p.hp)
		lay_pool -= amt
		p.heal(amt)
		SpellFx.rise(game, p.global_position + Vector2(0, -6), Color(1.0, 0.95, 0.6))
		game.log_line("Lyburnum lays hands on %s: +%d HP." % [p.short_name(), amt])
		game.toast("Lyburnum: Lay on Hands +%d" % amt)
		_support_cd = 8.0


func _attack(e: Enemy) -> void:
	_cd = ATTACK_COOLDOWN * (0.6 if stats.extra_attack else 1.0)
	var wpn: Dictionary = stats.weapon
	var kind := str(wpn.get("kind", "melee"))
	if key == "boarvhal" and not _rage_room:
		_rage_room = true
		game.log_line("Boar-vhal rages!")
		FloatText.fling(game, global_position + Vector2(0, -30), Vector2(0, -1), "RAGE", "", Color(1, 0.45, 0.35), 0, 0.9)
	var tw := create_tween()
	tw.tween_property(weapon_pivot, "rotation", -2.2, 0.15)
	tw.tween_property(weapon_pivot, "rotation", 1.9, 0.07)
	tw.tween_property(weapon_pivot, "rotation", -0.55, 0.3)
	var hand := global_position + Vector2(facing * 8.0, -16.0)
	if kind == "bolt":
		var b := SpellFx.bolt(game, hand, (e.global_position + Vector2(0, -10) - hand).normalized() * 300.0, HeroKit.SPELL_COLORS.fire,
			func(t): roll_attack(t, wpn))
		b.target = e
		return
	if kind == "whip":
		SpellFx.line(game, hand, e.global_position + Vector2(0, -10), HeroKit.SPELL_COLORS.nature, 0.22, true)
	game.sfx.play("swing", -9.0)
	roll_attack(e, wpn)


## One attack roll by the companion (house rule: a miss above a natural 1 still glances for 1d4).
func roll_attack(e: Enemy, wpn: Dictionary) -> Dictionary:
	if not is_instance_valid(e) or e.is_dead():
		return {}
	var atk := Rules.attack(game.dice, int(wpn.attack), e.ac, Dice.Mode.ADVANTAGE if e.restrained_t > 0.0 else Dice.Mode.NORMAL)
	var dmg := 0
	var glancing: bool = not atk.hit and not atk.fumble
	if atk.hit:
		var bonus: int = int(wpn.bonus) + (2 if _rage_room and key == "boarvhal" else 0)
		dmg = int(Rules.damage(game.dice, int(wpn.count), int(wpn.sides), bonus, atk.crit).total)
	elif glancing:
		dmg = game.dice.die(4)
	var col := Color(1.0, 0.85, 0.4) if atk.crit else (Color(0.75, 0.75, 0.75) if glancing else Color(0.7, 1.0, 0.7))
	FloatText.fling(game, e.global_position + Vector2(0, -16), Vector2(randf_range(-1.2, 1.2), -0.8), str(dmg) if dmg > 0 else "MISS", "", col, 0, 1.0)
	game.log_line("%s: %s vs %s, d20 %d %+d = %d, %s." % [short_name(), wpn.name, e.data.name, atk.kept, atk.bonus, atk.total,
		("%d damage" % dmg) + (" (glancing)" if glancing else "") if dmg > 0 else "miss"])
	if dmg > 0:
		game.sfx.play("hit", -7.0)
		e.take_hit(dmg, atk.crit, facing, glancing)
	return atk


## A goblin's strike that reached this companion.
func receive_attack(enemy: Node2D, wpn: Dictionary) -> void:
	if down:
		return
	var atk := Rules.attack(game.dice, int(wpn.attack), ac)
	if not atk.hit:
		FloatText.fling(game, global_position + Vector2(0, -20), Vector2(randf_range(-1, 1), -0.8), "MISS", "", Color(0.75, 0.75, 0.8), 0, 0.9)
		game.sfx.play("deflect", -8.0)
		return
	var resisted: bool = key == "boarvhal" and _rage_room and wpn.type in ["bludgeoning", "piercing", "slashing"]
	var d := Rules.damage(game.dice, int(wpn.count), int(wpn.sides), int(wpn.bonus), atk.crit, resisted)
	take_damage(int(d.total))
	game.log_line("%s hits %s for %d." % [enemy.data.name if "data" in enemy else "A goblin", short_name(), d.total])


func take_damage(amount: int) -> void:
	if down or amount <= 0:
		return
	if key == "lyburnum" and hp - amount <= 0 and lay_pool >= 0 and not has_meta("relentless_used"):
		set_meta("relentless_used", true)
		amount = hp - 1
		game.log_line("Lyburnum's Relentless Endurance keeps him on his feet at 1 HP.")
	hp = maxi(0, hp - amount)
	FloatText.fling(game, global_position + Vector2(0, -20), Vector2(randf_range(-1, 1), -0.8), str(amount), "", Color(1, 0.4, 0.35), 0, 1.0)
	game.sfx.play("hurt", -8.0)
	var tw := create_tween()
	visual.modulate = Color(1, 0.5, 0.5)
	tw.tween_property(visual, "modulate", Color.WHITE, 0.25)
	if hp <= 0:
		_knock_out()


func heal(amount: int) -> void:
	if down:
		down = false
		visual.rotation = 0.0
	hp = mini(max_hp, hp + amount)


func _knock_out() -> void:
	down = true
	velocity.x = 0.0
	visual.rotation = -1.4 * facing
	visual.modulate = Color(0.7, 0.7, 0.7)
	game.log_line("%s is knocked out! The party will patch them up after the fight." % short_name())
	game.toast("%s is down!" % short_name())


func _process(_delta: float) -> void:
	if tag:
		tag.text = "%s %d/%d" % [short_name().to_upper(), hp, max_hp] if not down else "%s (DOWN)" % short_name().to_upper()
		tag.modulate.a = 0.9
