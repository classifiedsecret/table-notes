class_name TDHero
extends CharacterBody2D
## The hero in the top-down prototype: 8-way movement, attacks aimed at the mouse (or the way
## you face), a dodge roll with brief invulnerability, potions. Rolls use the same Rules core.

const SPEED := 92.0
const ROLL_SPEED := 190.0
const ROLL_TIME := 0.32

var game: TDMain
var hero: Hero
var stats: Dictionary
var hp := 10
var max_hp := 10
var ac := 10
var potions := 2
var visual: Node2D
var sprite: AnimatedSprite2D
var weapon_pivot: Node2D
var slash: Node2D
var aim := Vector2.RIGHT
var _attack_t := 0.0
var _roll_t := 0.0
var _roll_dir := Vector2.ZERO
var _iframes := 0.0
var _flash := 0.0
var down := false
var _last_mouse := Vector2.ZERO
var _mouse_idle := 99.0
var _space_held := false
var _hop_t := 0.0
const HOP_TIME := 0.42


func _ready() -> void:
	stats = hero.combat_stats()
	max_hp = int(stats.hp)
	hp = max_hp
	ac = int(stats.ac)
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, 6)
	shape.shape = r
	shape.position = Vector2(0, -3)
	add_child(shape)
	visual = Node2D.new()
	add_child(visual)
	var shadow := Sprite2D.new()
	shadow.texture = _shadow_tex()
	shadow.modulate = Color(0, 0, 0, 0.35)
	add_child(shadow)
	move_child(shadow, 0)
	var info := Kits.info(hero.key)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.strip_frames(load("res://assets/sprites/%s.png" % info.sprite), 16, 28, {
		"idle": [0, 4, 6, true], "run": [4, 4, 11, true], "hit": [8, 1, 1, false]})
	sprite.offset = Vector2(0, -14)
	sprite.play("idle")
	visual.add_child(sprite)
	weapon_pivot = Node2D.new()
	weapon_pivot.position = Vector2(0, -10)
	add_child(weapon_pivot)
	var w := Sprite2D.new()
	w.texture = Art.region(info.weapon_sprite)
	w.offset = Vector2(0, -10)
	w.rotation = PI / 2.0
	weapon_pivot.add_child(w)
	slash = Node2D.new()
	slash.set_script(preload("res://scripts/td/td_slash.gd"))
	weapon_pivot.add_child(slash)


static func _shadow_tex() -> Texture2D:
	var img := Image.create(12, 5, false, Image.FORMAT_RGBA8)
	for y in 5:
		for x in 12:
			var d := Vector2((x - 5.5) / 6.0, (y - 2.0) / 2.5).length()
			if d <= 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)


func _physics_process(delta: float) -> void:
	_attack_t = maxf(0.0, _attack_t - delta)
	if _hop_t > 0.0:
		_hop_t = maxf(0.0, _hop_t - delta)
		var k := 1.0 - _hop_t / HOP_TIME
		visual.position.y = -sin(k * PI) * 12.0
		weapon_pivot.position.y = -10.0 + visual.position.y
	elif visual.position.y != 0.0:
		visual.position.y = 0.0
		weapon_pivot.position.y = -10.0
	_iframes = maxf(0.0, _iframes - delta)
	_flash = maxf(0.0, _flash - delta * 4.0)
	sprite.modulate = Color(1, 1 - _flash * 0.6, 1 - _flash * 0.6, 0.55 if _iframes > 0.0 and _roll_t <= 0.0 and int(_iframes * 20) % 2 == 0 else 1.0)
	if down:
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Aim at the mouse while it's being used; otherwise aim the way you walk.
	var mp := get_viewport().get_mouse_position()
	if mp.distance_to(_last_mouse) > 0.5:
		_mouse_idle = 0.0
	_last_mouse = mp
	_mouse_idle += delta
	var mouse := get_global_mouse_position() - (global_position + Vector2(0, -10))
	if _mouse_idle < 1.5 and mouse.length() > 4.0:
		aim = mouse.normalized()
	elif input != Vector2.ZERO:
		aim = input.normalized()
	if _roll_t > 0.0:
		_roll_t -= delta
		velocity = _roll_dir * ROLL_SPEED
		visual.rotation += delta * 22.0 * signf(_roll_dir.x if _roll_dir.x != 0.0 else 1.0)
		if _roll_t <= 0.0:
			visual.rotation = 0.0
	else:
		velocity = velocity.move_toward(input * SPEED, 900.0 * delta)
		# Dodge roll: Shift, K or C (or the gamepad's B), as in the side-scroller.
		if Input.is_action_just_pressed("dodge") and input != Vector2.ZERO:
			_roll_t = ROLL_TIME
			_roll_dir = input.normalized()
			_iframes = ROLL_TIME + 0.05
			game.sfx.play("dodge", -6.0)
		if Input.is_action_just_pressed("attack") and _attack_t <= 0.0:
			_attack()
		if Input.is_action_just_pressed("interact"):
			game.try_open_chest()
		# Space (or the gamepad's A): a quick hop. While airborne, spike traps and arrows pass beneath you.
		var space := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_joy_button_pressed(0, JOY_BUTTON_A)
		if space and not _space_held and _hop_t <= 0.0:
			_hop_t = HOP_TIME
			game.sfx.play("jump", -8.0)
		_space_held = space
		if Input.is_action_just_pressed("potion"):
			_potion()
	move_and_slide()
	visual.scale.x = -1.0 if aim.x < 0.0 else 1.0
	weapon_pivot.rotation = lerp_angle(weapon_pivot.rotation, aim.angle(), 0.35) if _attack_t <= 0.0 else weapon_pivot.rotation
	weapon_pivot.z_index = -1 if aim.y < -0.3 else 1
	if _roll_t <= 0.0:
		sprite.play("run" if velocity.length() > 12.0 else "idle")


func _attack() -> void:
	var wpn: Dictionary = stats.weapon
	var kind := str(wpn.get("kind", "melee"))
	_attack_t = 0.55 if not stats.extra_attack else 0.35
	if kind == "bolt" or kind == "whip":
		_spell_bolt(wpn)
		return
	# Melee: a sweeping arc in the direction you aim.
	var reach: float = float(wpn.get("reach", 24.0)) + 4.0
	var tw := create_tween()
	var a0 := aim.angle()
	weapon_pivot.rotation = a0 - 1.4
	tw.tween_property(weapon_pivot, "rotation", a0 + 1.4, 0.14)
	tw.tween_property(weapon_pivot, "rotation", a0, 0.2)
	slash.call("play", 1.0)
	game.sfx.play("swing", -4.0)
	var hit_any := false
	for f in game.living_foes():
		var to := f.global_position + Vector2(0, -6) - (global_position + Vector2(0, -8))
		if to.length() <= reach and absf(aim.angle_to(to)) <= 1.25:
			_roll_against(f, wpn)
			hit_any = true
	if not hit_any:
		pass


func _spell_bolt(wpn: Dictionary) -> void:
	# Fire Bolt / Thorn Whip as an aimed missile in the prototype.
	var b := TDArrow.new()
	b.game = game
	b.friendly = true
	b.weapon = wpn
	b.color = Color(1.0, 0.55, 0.2) if wpn.kind == "bolt" else Color(0.5, 0.85, 0.4)
	b.velocity = aim * 260.0
	b.max_dist = 200.0 if wpn.kind == "bolt" else 80.0
	game.world.add_child(b)
	b.global_position = global_position + Vector2(0, -10) + aim * 8.0
	game.sfx.play("swing", -8.0, 0.3)


## One attack roll at a goblin (glancing rule: below AC still deals 1d4; a natural 1 hurts you).
func _roll_against(f: TDFoe, wpn: Dictionary) -> void:
	var behind := f.facing.dot(f.global_position - global_position) > 0.3
	var atk := Rules.attack(game.dice, int(wpn.attack), f.ac, Dice.Mode.ADVANTAGE if behind else Dice.Mode.NORMAL)
	var dmg := 0
	var glancing: bool = not atk.hit and not atk.fumble
	if atk.hit:
		dmg = int(Rules.damage(game.dice, int(wpn.count), int(wpn.sides), int(wpn.bonus), atk.crit).total)
	elif glancing:
		dmg = game.dice.die(4)
	else:
		var self_hurt := game.dice.die(4)
		take_damage(self_hurt)
		game.log_line("Natural 1! %s takes %d." % [hero.short(), self_hurt])
		FloatText.fling(game.world, f.global_position + Vector2(0, -18), Vector2(0, -1), "MISS", "", Color(0.75, 0.75, 0.8), 0, 0.9)
		return
	var col := Color(1.0, 0.85, 0.3) if atk.crit else (Color(0.8, 0.8, 0.8) if glancing else Color.WHITE)
	FloatText.fling(game.world, f.global_position + Vector2(0, -18), Vector2(randf_range(-1, 1), -1), str(dmg), "", col, 0, 1.0)
	game.log_line("%s: %s d20 %d %+d = %d vs AC %d%s, %d damage%s." % [hero.short(), wpn.name, atk.kept, atk.bonus, atk.total, f.ac,
		" (from behind)" if behind else "", dmg, " (glancing)" if glancing else ""])
	game.sfx.play("hit", -3.0)
	f.hurt(dmg, (f.global_position - global_position).normalized(), atk.crit)


func _potion() -> void:
	if potions <= 0 or hp >= max_hp:
		return
	potions -= 1
	var faces: Array[int] = game.dice.roll(2, 4)
	var heal: int = faces[0] + faces[1] + 2
	hp = mini(max_hp, hp + heal)
	game.toast("POTION OF HEALING: +%d HP (%d LEFT)" % [heal, potions])


## A goblin's strike reached the hero: roll against AC (a dodge roll avoids it entirely).
func receive_attack(foe_name: String, wpn: Dictionary) -> void:
	if _iframes > 0.0 or down:
		return
	var atk := Rules.attack(game.dice, int(wpn.attack), ac)
	if atk.hit:
		var d := Rules.damage(game.dice, int(wpn.count), int(wpn.sides), int(wpn.bonus), atk.crit)
		game.log_line("%s: %s d20 %d %+d = %d vs AC %d, %d damage." % [foe_name, wpn.name, atk.kept, atk.bonus, atk.total, ac, d.total])
		take_damage(int(d.total))
	else:
		game.log_line("%s: %s d20 %d %+d = %d vs AC %d, miss." % [foe_name, wpn.name, atk.kept, atk.bonus, atk.total, ac])
		FloatText.fling(game.world, global_position + Vector2(0, -26), Vector2(randf_range(-1, 1), -1), "MISS", "", Color(0.75, 0.75, 0.8), 0, 0.9)
		game.sfx.play("deflect", -6.0)


func airborne() -> bool:
	return _hop_t > 0.08 and _hop_t < HOP_TIME - 0.06


func spike_hit() -> void:
	if _iframes > 0.0 or down or airborne():
		return
	var sv := Rules.save(game.dice, int(stats.dex_save), 13)
	var d := Rules.damage(game.dice, 2, 4, 0)
	var amt: int = d.total if not sv.success else floori(d.total / 2.0)
	game.log_line("Spikes! DEX save %d vs DC 13, %d piercing." % [sv.total, amt])
	take_damage(amt)


func take_damage(amount: int) -> void:
	if amount <= 0:
		return
	hp = maxi(0, hp - amount)
	_flash = 1.0
	_iframes = maxf(_iframes, 0.4)
	FloatText.fling(game.world, global_position + Vector2(0, -26), Vector2(randf_range(-1, 1), -1), str(amount), "", Color(1, 0.4, 0.35), 0, 1.0)
	game.sfx.play("hit_light", -4.0)
	if hp <= 0:
		down = true
		visual.rotation = PI / 2.0
		game.toast("%s FALLS! (IT'S A TEST: BACK ON YOUR FEET IN 2 SECONDS)" % hero.short().to_upper())
		get_tree().create_timer(2.0).timeout.connect(func():
			down = false
			visual.rotation = 0.0
			hp = max_hp
			_iframes = 1.0)
