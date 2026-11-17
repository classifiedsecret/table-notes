class_name Music
extends Node
## Background music: one track at a time, crossfaded. Tracks loop.
## M toggles music on/off (remembered between visits).

const TRACKS := {
	"tavern": "res://assets/music/gryphons_roost.ogg",
	"delve": "res://assets/music/dungeon_delve.ogg",     # has a light echo baked in
	"boss": "res://assets/music/bugbears_enrage.ogg",
}
const LEVEL_DB := -9.0      # sits under the sound effects
const SILENT_DB := -60.0
const SETTINGS := "user://settings.cfg"

var current := ""
var muted := false
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _streams := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = _make()
	_b = _make()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		muted = bool(cfg.get_value("audio", "music_muted", false))


func _make() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = SILENT_DB
	add_child(p)
	return p


func _stream(key: String) -> AudioStream:
	if not _streams.has(key):
		var s: AudioStream = load(TRACKS[key])
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_streams[key] = s
	return _streams[key]


## Switch to a track ("" for silence). Does nothing if it is already playing.
func play(key: String, fade := 1.5) -> void:
	if key == current:
		return
	current = key
	var old := _a
	var new := _b
	_a = new
	_b = old
	_fade(old, SILENT_DB, fade, true)
	if key == "":
		return
	new.stream = _stream(key)
	new.volume_db = SILENT_DB
	new.play()
	_fade(new, SILENT_DB if muted else LEVEL_DB, fade, false)


func stop(fade := 1.5) -> void:
	play("", fade)


func toggle_mute() -> bool:
	muted = not muted
	_fade(_a, SILENT_DB if muted else LEVEL_DB, 0.4, false)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "music_muted", muted)
	cfg.save(SETTINGS)
	return muted


func _fade(p: AudioStreamPlayer, to_db: float, secs: float, stop_after: bool) -> void:
	if p.has_meta("tw"):
		var old_tw: Tween = p.get_meta("tw")
		if old_tw and old_tw.is_valid():
			old_tw.kill()
	var tw := create_tween()
	tw.tween_property(p, "volume_db", to_db, secs)
	if stop_after:
		tw.tween_callback(p.stop)
	p.set_meta("tw", tw)
