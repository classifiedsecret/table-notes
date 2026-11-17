class_name FloatText
extends Node2D
## A dice pop-up: an optional quick tumble of random numbers, then the result, floating up and fading.

var _big: Label
var _small: Label
var _final_big := ""
var _tumble_sides := 0
var _tumble_time := 0.0
var _life := 0.0
var _duration := 1.3
var _vel := Vector2(0, -22)


static func spawn(parent: Node, pos: Vector2, big: String, small: String, color: Color,
		tumble_sides := 0, duration := 1.3, big_size := 16) -> FloatText:
	var f := FloatText.new()
	f.position = pos.round()
	f.z_index = 50
	f._duration = duration
	f._final_big = big
	f._tumble_sides = tumble_sides
	f._tumble_time = 0.16 if tumble_sides > 0 else 0.0
	f._big = Label.new()
	f._big.label_settings = Art.label_settings(big_size, color, 3, true)
	f._big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f._big.size = Vector2(160, 16)
	f._big.position = Vector2(-80, -14)
	f._big.text = big if tumble_sides == 0 else str(randi_range(1, tumble_sides))
	f.add_child(f._big)
	if small != "":
		f._small = Label.new()
		f._small.label_settings = Art.label_settings(8, Color(0.92, 0.9, 0.85), 2)
		f._small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		f._small.size = Vector2(200, 10)
		f._small.position = Vector2(-100, 1)
		f._small.text = small
		f.add_child(f._small)
	parent.add_child(f)
	return f


func _process(delta: float) -> void:
	_life += delta
	if _tumble_time > 0.0:
		_tumble_time -= delta
		_big.text = str(randi_range(1, _tumble_sides)) if _tumble_time > 0.0 else _final_big
		if _tumble_time <= 0.0:
			scale = Vector2(1.35, 1.35)
		return
	scale = scale.lerp(Vector2.ONE, minf(1.0, delta * 14.0))
	position += _vel * delta
	_vel.y *= 0.96
	var t := _life / _duration
	modulate.a = 1.0 if t < 0.7 else maxf(0.0, 1.0 - (t - 0.7) / 0.3)
	if _life >= _duration:
		queue_free()
