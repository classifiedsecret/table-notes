class_name InnNPC
extends Node2D
## Someone in the Gryphon's Roost: party member, staff or patron.
## Stands or sits, may walk a route, talks when you press E, and shows speech bubbles.

var key := ""
var display_name := ""
var lines: Array = []
var sitting := false
var facing := 1
var patrol := Vector2.ZERO          # x range to wander; zero = stays put
var speed := 26.0
var line_i := 0

var sprite: AnimatedSprite2D
var tag: Node2D
var bubble: Node2D
var marker: Label
var _mark_t := 0.0
var _bubble_t := 0.0
var _wait := 0.0
var _target_x := 0.0


static func make(strip: String, nm: String, pos: Vector2, talk: Array, sit := false, face := 1) -> InnNPC:
	var n := InnNPC.new()
	n.key = strip
	n.display_name = nm
	n.lines = talk
	n.sitting = sit
	n.facing = face
	n.position = pos
	return n


func _ready() -> void:
	var size: Vector2i = InnSprites.SIZES.get(key, Vector2i(16, 28))
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = Art.strip_frames(load("res://assets/sprites/%s.png" % key), size.x, size.y, {
		"idle": [0, 4, 5 + randi() % 3, true], "run": [4, 4, 9, true]})
	sprite.offset = Vector2(0, -size.y / 2.0 + (5.0 if sitting else 0.0))
	sprite.play("idle")
	sprite.frame = randi() % 4
	sprite.scale.x = facing
	add_child(sprite)
	tag = Node2D.new()
	tag.set_script(preload("res://scripts/game/enemy_bar.gd"))
	tag.position = Vector2(0, -size.y - 4 + (5 if sitting else 0))
	tag.modulate = Color(0.75, 0.95, 1.0)
	add_child(tag)
	tag.call("set_values", 1, 1, display_name, false)
	bubble = Node2D.new()
	bubble.set_script(preload("res://scripts/game/speech_bubble.gd"))
	bubble.position = Vector2(0, -size.y - 14 + (5 if sitting else 0))
	bubble.z_index = 60
	add_child(bubble)
	_target_x = position.x
	marker = Label.new()
	marker.text = "!"
	marker.add_theme_font_override("font", preload("res://assets/fonts/kenney_mini_square.ttf"))
	marker.add_theme_font_size_override("font_size", 16)
	marker.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	marker.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0))
	marker.add_theme_constant_override("outline_size", 4)
	marker.position = Vector2(-3, -size.y - 30 + (5 if sitting else 0))
	marker.z_index = 61
	marker.visible = false
	add_child(marker)


func rename(nm: String) -> void:
	display_name = nm
	if tag:
		tag.call("set_values", 1, 1, display_name, false)


## Next line of dialogue (cycles).
func next_line() -> String:
	if lines.is_empty():
		return "..."
	var l: String = lines[line_i % lines.size()]
	line_i += 1
	return l


## A bobbing "!" over someone with a quest to give.
func set_marker(on: bool) -> void:
	if marker and marker.visible != on:
		marker.visible = on


## Stand up or sit down (moves the sprite and its labels).
func set_sitting(on: bool) -> void:
	var d := (5.0 if on else 0.0) - (5.0 if sitting else 0.0)
	sitting = on
	for n in [sprite, tag, bubble, marker]:
		if n == sprite:
			sprite.offset.y += d
		elif n:
			n.position.y += d


func say(text: String, secs := 3.2) -> void:
	bubble.call("show_text", text, secs)


func face_toward(x: float) -> void:
	facing = 1 if x > global_position.x else -1
	sprite.scale.x = facing


func _process(delta: float) -> void:
	if marker and marker.visible:
		_mark_t += delta
		marker.position.y += sin(_mark_t * 5.0) * 0.12
	if patrol == Vector2.ZERO:
		return
	if _wait > 0.0:
		_wait -= delta
		sprite.play("idle")
		return
	var dx := _target_x - position.x
	if absf(dx) < 1.0:
		_wait = randf_range(1.5, 4.0)
		_target_x = randf_range(patrol.x, patrol.y)
		return
	facing = 1 if dx > 0.0 else -1
	sprite.scale.x = facing
	position.x += signf(dx) * minf(absf(dx), speed * delta)
	sprite.play("run")
