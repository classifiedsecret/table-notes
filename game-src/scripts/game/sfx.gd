class_name Sfx
extends Node
## Small pool of audio players. Sounds are Kenney packs (CC0).

const SOUNDS := {
	"die": ["die_1", "die_2", "die_3", "die_4"],
	"swing": ["swing_1", "swing_2"],
	"hit": ["impactPunch_heavy_000", "chop"],
	"hit_light": ["impactPunch_medium_000", "impactPunch_medium_001"],
	"deflect": ["impactPlate_light_000", "impactPlate_light_001"],
	"crit": ["impactBell_heavy_000"],
	"step": ["step_0", "step_1", "step_2", "step_3"],
	"jump": ["jump"],
	"dodge": ["dodge"],
	"thud": ["impactSoft_heavy_000"],
}

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	for key: String in SOUNDS:
		var list: Array[AudioStream] = []
		for file: String in SOUNDS[key]:
			list.append(load("res://assets/audio/%s.ogg" % file))
		_streams[key] = list
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(key: String, volume_db := 0.0, pitch_jitter := 0.08) -> void:
	if not _streams.has(key):
		return
	var list: Array = _streams[key]
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = list[randi() % list.size()]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
