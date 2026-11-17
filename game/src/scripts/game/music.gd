class_name Music
extends Node
## Background music: one track at a time, crossfaded. Tracks loop.
## M toggles music on/off (remembered between visits).

const TRACKS := {
	"tavern": "res://assets/music/gryphons_roost.ogg",
	"delve": "res://assets/music/dungeon_delve.ogg",     # has a light echo baked in
	"boss": "res://assets/music/bugbears_enrage.ogg",
}
const BASE_LINEAR := 0.59  # with volume 0.6 this is about -9 dB, under the sound effects
const SILENT_DB := -60.0
const SETTINGS := "user://settings.cfg"

var current := ""
var muted := false
var volume := 0.6          # 0..1, mouse wheel adjusts it
var game: Node
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
		volume = float(cfg.get_value("audio", "music_volume", 0.6))


func level_db() -> float:
	return linear_to_db(maxf(0.001, volume * BASE_LINEAR)) if volume > 0.0 else SILENT_DB


## Mouse wheel: music volume up and down, in 10% steps.
func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed:
		return
	var step := 0.0
	if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
		step = 0.1
	elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step = -0.1
	if step == 0.0:
		return
	volume = clampf(snappedf(volume + step, 0.1), 0.0, 1.0)
	if muted and step > 0.0:
		muted = false
	_fade(_a, SILENT_DB if muted else level_db(), 0.15, false)
	_save()
	if game:
		game.toast("MUSIC VOLUME %d%%" % roundi(volume * 100.0))


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("audio", "music_muted", muted)
	cfg.set_value("audio", "music_volume", volume)
	cfg.save(SETTINGS)


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
	_fade(new, SILENT_DB if muted else level_db(), fade, false)


func stop(fade := 1.5) -> void:
	play("", fade)


func toggle_mute() -> bool:
	muted = not muted
	_fade(_a, SILENT_DB if muted else level_db(), 0.4, false)
	_save()
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
