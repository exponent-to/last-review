extends Node
## The soundtrack: the game author's tracks (made with Suno), one per scene.
##
##   menu       Title, looped
##   cold_open  Cold Open, once
##   morning    Morning, looped (reading before BEGIN SHIFT, and orientation)
##   shift      Motorik Minor, looped (BEGIN SHIFT to 18:00)
##   evening    After Hours, looped (Morgan's end-of-day panel)
##   ending     Last Reviewers (warm) or Helios Prime (bleak), once
##
## Every track is mastered to Motorik Minor's loudness (tools/music/
## prepare_tracks.py), so one TRACK_GAIN sets them all. Scene changes crossfade
## over FADE_SECONDS. Looping tracks play their opening once, then cycle a
## section set by the loop offset in their .import. Motorik Minor resumes where
## it stopped within a shift and starts from the top at a new BEGIN SHIFT; the
## others start from the top each time their scene begins.
##
## Pause and focus loss duck at once, behind a low-pass on the Music bus. The
## MUSIC toggle and volume persist in `settings_path`. On the web the music
## starts with the first click or key press, as browsers require, and plays as
## a stream (bus effects and loop offsets work as on desktop). With
## ?music=sample the players use Web Audio samples instead, which skip bus
## effects and ignore a stream's loop offset, so loops are then driven here:
## each pass plays a non-looping copy, and when it ends the looping stream
## starts at its loop offset, which the browser then repeats.

signal enabled_changed(enabled: bool)

const TRACKS := {
	"title": "res://audio/music/title.ogg",
	"cold_open": "res://audio/music/cold_open.ogg",
	"morning": "res://audio/music/morning.ogg",
	"motorik_minor": "res://audio/music/motorik_minor.ogg",
	"after_hours": "res://audio/music/after_hours.ogg",
	"last_reviewers": "res://audio/music/last_reviewers.ogg",
	"helios_prime": "res://audio/music/helios_prime.ogg",
}
const SCENE_TRACKS := {
	"menu": "title", "cold_open": "cold_open", "morning": "morning",
	"shift": "motorik_minor", "evening": "after_hours",
}
const ENDING_TRACKS := {"warm": "last_reviewers", "bleak": "helios_prime"}
## Tracks that play through once rather than loop.
const ONCE: Array[String] = ["cold_open", "last_reviewers", "helios_prime"]
## The track whose place is kept across leaving and re-entering its scene.
const RESUMING := "motorik_minor"
const BUS := "Music"
const DEFAULT_VOLUME := 0.7
## All tracks sit at -16.3 LUFS; this puts them about 6.4 dB lower in game.
const TRACK_GAIN := 0.48
const FADE_SECONDS := 2.0
## An author pushing back at the desk dips the workday song slightly.
const PUSHBACK_DIP := 0.85
const OPEN_CUTOFF := 20000.0
## Paused or unfocused: this much quieter, behind this low-pass, reached this fast.
const DUCK_GAIN := 0.35
const DUCK_CUTOFF := 650.0
const DUCK_SECONDS := 0.3
const SILENT_DB := -80.0

static var settings_path := "user://music.cfg"
## Headless runs (the test suite) have only a dummy audio driver, so the music
## stays silent there unless a test asks to exercise real playback.
static var play_headless := false
## Drive loop restarts here rather than trusting the stream (see above).
static var manual_loops := OS.has_feature("web")

var enabled := true
var volume := DEFAULT_VOLUME
var paused := false
var focused := true
## The ending variation held until the player leaves it ("" when none).
var ending := ""
var scene := "menu"

var _tense := false
var _players: Dictionary = {}
var _gains: Dictionary = {}
var _applied_db: Dictionary = {}
## Where RESUMING stopped, so it picks up there within the same shift.
var _resume := 0.0
## One-shot tracks that have played through since their scene began.
var _done: Dictionary = {}
## Per looping track: the looping stream and a non-looping copy for a pass that
## does not start at the loop offset (manual_loops only).
var _loop_streams: Dictionary = {}
var _pass_streams: Dictionary = {}
## Tracks this manager started and has not stopped: an end means "wrap", not
## "start over".
var _live: Dictionary = {}
var _bus := -1
var _filter: AudioEffectLowPassFilter
var _started := false
var _awaiting_gesture := false
var _duck := 0.0


## What plays for one moment of the game: {"track": name, "gain": 0..1}.
static func mix_for(at_scene: String, tense: bool = false, ending_kind: String = "") -> Dictionary:
	if at_scene == "ending":
		return {"track": ENDING_TRACKS.get(ending_kind, "after_hours"), "gain": 1.0}
	var gain := PUSHBACK_DIP if at_scene == "shift" and tense else 1.0
	return {"track": SCENE_TRACKS.get(at_scene, "title"), "gain": gain}


## Which ending variation fits a finished run: the ending it earned
## (content/endings.gd). The Last Reviewers and Soft Landing are warm; every
## other ending, including a firing, is bleak.
static func ending_kind(state: Dictionary) -> String:
	return load("res://content/endings.gd").music_kind(str(state.get("ending", "")))


static func load_settings() -> Dictionary:
	var config := ConfigFile.new()
	var result := {"enabled": true, "volume": DEFAULT_VOLUME}
	if config.load(settings_path) == OK:
		result.enabled = bool(config.get_value("music", "enabled", true))
		result.volume = clampf(float(config.get_value("music", "volume", DEFAULT_VOLUME)), 0.0, 1.0)
	return result


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("music", "enabled", enabled)
	config.set_value("music", "volume", volume)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save music settings: " + error_string(error))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var settings := load_settings()
	enabled = settings.enabled
	volume = settings.volume
	_ensure_bus()
	# On the web, music plays through Godot's streamed output: in some Chrome
	# setups Web Audio samples start and run but come out silent. Streams also
	# honour loop offsets themselves. ?music=sample restores samples to compare.
	var streamed := OS.has_feature("web") and not str(JavaScriptBridge.eval("location.search", true)).contains("music=sample")
	if streamed: manual_loops = false
	for track: String in TRACKS:
		var player := AudioStreamPlayer.new()
		player.name = track.to_pascal_case()
		player.bus = BUS
		if streamed: player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.volume_db = SILENT_DB
		add_child(player)
		player.finished.connect(_on_finished.bind(track))
		_players[track] = player
		_gains[track] = 0.0
		_applied_db[track] = SILENT_DB
	_load_streams()
	# Browsers only allow audio after a user gesture.
	_awaiting_gesture = OS.has_feature("web")
	_start()
	_apply()


func _load_streams() -> void:
	for track: String in TRACKS:
		var path: String = TRACKS[track]
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			_players[track].stream = stream
			if track not in ONCE and stream is AudioStreamOggVorbis:
				_loop_streams[track] = stream
				var once_through := stream.duplicate() as AudioStreamOggVorbis
				once_through.loop = false
				_pass_streams[track] = once_through
		else:
			push_warning("Missing music track %s." % path)


func _ensure_bus() -> void:
	_bus = AudioServer.get_bus_index(BUS)
	if _bus == -1:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, BUS)
		AudioServer.set_bus_send(_bus, "Master")
	if AudioServer.get_bus_effect_count(_bus) < 1:
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.resonance = 0.6
		AudioServer.add_bus_effect(_bus, low_pass, 0)
	_filter = AudioServer.get_bus_effect(_bus, 0) as AudioEffectLowPassFilter


func _start() -> void:
	if _started or not enabled or _awaiting_gesture or not is_inside_tree(): return
	if DisplayServer.get_name() == "headless" and not play_headless: return
	_started = true
	# Fade the current scene's track in from silence.
	for track: String in _gains:
		_gains[track] = 0.0


func _stop() -> void:
	_started = false
	for track: String in _players:
		_stop_track(track)


func _stop_track(track: String) -> void:
	var player: AudioStreamPlayer = _players[track]
	_live[track] = false
	if player.playing:
		if track == RESUMING:
			_resume = player.get_playback_position()
		player.stop()


func _exit_tree() -> void:
	# Release the playbacks the mixer holds, so quitting leaves nothing behind.
	_stop()
	for player: AudioStreamPlayer in _players.values():
		player.stream = null


func _enter_tree() -> void:
	# Re-entering the tree (never on first entry, before _ready) restores the tracks.
	if _players.is_empty(): return
	_load_streams()
	_start.call_deferred()


func _input(event: InputEvent) -> void:
	if not _awaiting_gesture: return
	var gesture := (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch) and event.is_pressed()
	if gesture:
		_awaiting_gesture = false
		_start()


## Report where the game is; `progress` is how far the shift has run (0..1).
## An ending set by play_ending holds until the player is back at the menu or
## a cold open.
func set_scene(next_scene: String, progress: float = 0.0, tense: bool = false) -> void:
	if not ending.is_empty():
		if next_scene in ["menu", "cold_open"]:
			ending = ""
		else:
			return
	# A shift that has just begun starts the workday song from the top;
	# returning to a shift already under way picks it up where it stopped.
	if next_scene == "shift" and scene != "shift" and progress <= 0.0:
		_resume = 0.0
	scene = next_scene
	_tense = tense


## Hook for ending screens: "warm" for a good ending, "bleak" for a lonely one.
## Any other kind gets After Hours; "" releases the hold.
func play_ending(kind: String) -> void:
	ending = kind
	if not kind.is_empty():
		scene = "ending"


func set_paused(value: bool) -> void:
	paused = value


func set_focused(value: bool) -> void:
	focused = value


func set_enabled(value: bool) -> void:
	if value == enabled: return
	enabled = value
	save_settings()
	enabled_changed.emit(enabled)
	if enabled:
		_start()
	else:
		_stop()
	_apply()


func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	save_settings()
	_apply()


func is_playing() -> bool:
	return _started


## True while the browser still blocks audio (music on, no click or key yet).
func awaiting_gesture() -> bool:
	return enabled and _awaiting_gesture


## The loop offset a looping track restarts at (0 for one-shots).
func loop_offset(track: String) -> float:
	var stream := _loop_streams.get(track) as AudioStreamOggVorbis
	return stream.loop_offset if stream != null else 0.0


## Begin a track at `from` seconds. With manual loops, a looping track plays a
## non-looping pass first; _wrap takes over at its end.
func _begin(track: String, from: float) -> void:
	var player: AudioStreamPlayer = _players[track]
	_live[track] = true
	if manual_loops and _pass_streams.has(track):
		player.stream = _pass_streams[track]
	elif _loop_streams.has(track):
		player.stream = _loop_streams[track]
	player.play(from)


## A looping track reached its end: restart at the loop offset on the looping
## stream, which the browser then repeats from that same offset by itself.
func _wrap(track: String) -> void:
	var player: AudioStreamPlayer = _players[track]
	if player.playing: return
	player.stream = _loop_streams[track]
	player.play(loop_offset(track))


func _on_finished(track: String) -> void:
	if track in ONCE:
		_done[track] = true
	elif manual_loops and _live.get(track, false) and _loop_streams.has(track):
		_wrap(track)


## The mix for where the game is now.
func target() -> Dictionary:
	return mix_for(scene, _tense, ending)


## The gains actually applied now (after fades and ducking), for tests and debugging.
func current_mix() -> Dictionary:
	return {"track": target().track, "gains": _gains.duplicate(), "duck": _duck,
		"output_cutoff": _cutoff_now(), "duck_gain": lerpf(1.0, DUCK_GAIN, _duck)}


func track_playing(track: String) -> bool:
	return _players.has(track) and _players[track].playing


func track_position(track: String) -> float:
	if track_playing(track): return _players[track].get_playback_position()
	return _resume if track == RESUMING else 0.0


func _process(delta: float) -> void:
	step(delta)


## Advance crossfades and ducking by `delta` seconds. Without playback (music
## off, or headless) the gains move to their targets at once.
func step(delta: float) -> void:
	var want := target()
	var rate := maxf(0.0, delta) / FADE_SECONDS
	for track: String in _gains:
		var goal: float = float(want.gain) if track == want.track else 0.0
		if goal == 0.0 and track in ONCE:
			_done.erase(track)
		_gains[track] = move_toward(_gains[track], goal, rate) if _started else goal
	var duck_target := 1.0 if paused or not focused else 0.0
	_duck = move_toward(_duck, duck_target, maxf(0.0, delta) / DUCK_SECONDS)
	_apply()


func _cutoff_now() -> float:
	return exp(lerpf(log(OPEN_CUTOFF), log(DUCK_CUTOFF), _duck))


func _apply() -> void:
	if _players.is_empty(): return
	# The user's volume rides on each player rather than the bus, so it holds
	# for web samples too.
	var master := TRACK_GAIN * lerpf(1.0, DUCK_GAIN, _duck) * volume
	var want := target()
	for track: String in _players:
		var player: AudioStreamPlayer = _players[track]
		var gain: float = _gains[track]
		var db := _db(gain * master)
		if absf(db - float(_applied_db[track])) > 0.01:
			player.volume_db = db
			_applied_db[track] = db
		var wanted: bool = track == want.track
		if _started and wanted and gain > 0.0001 and not player.playing and player.stream != null and not _done.get(track, false):
			if manual_loops and _live.get(track, false) and _loop_streams.has(track):
				_wrap(track)   # ended before its finished signal arrived
			else:
				_begin(track, _resume if track == RESUMING else 0.0)
		elif gain <= 0.0001 and not wanted:
			_stop_track(track)
	AudioServer.set_bus_mute(_bus, not enabled)
	var cutoff := _cutoff_now()
	_filter.cutoff_hz = cutoff
	AudioServer.set_bus_effect_enabled(_bus, 0, cutoff < OPEN_CUTOFF * 0.95)


static func _db(gain: float) -> float:
	return SILENT_DB if gain <= 0.0001 else maxf(SILENT_DB, linear_to_db(gain))
