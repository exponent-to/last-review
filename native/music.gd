extends Node
## Adaptive soundtrack. Five 16-bar stems rendered by tools/music/compose.py
## (125 BPM, E Phrygian) loop in lockstep, one player each, started in the same
## mix step; the game only moves their volumes. The whole piece stays in the
## long, minimal intro of a dance-punk track: the shift gently adds a kick and
## bass pulse, a ticking hat, the figure's filter opening, and late in the day a
## busier, tenser layer. There is no drop.
##
## Layer changes wait for the next bar line and fade over two bars. Pause and
## focus loss duck at once, behind a low-pass on the Music bus. The MUSIC toggle
## and volume persist in `settings_path`. On the web the music starts with the
## first click or key press, as browsers require; there the players use Web
## Audio samples (Godot's web default), which loop natively but skip bus effects,
## so pause and the filtered variations rely on their lower levels.

const STEMS: Array[String] = ["intro", "pulse", "hats", "air", "tension"]
const STEM_PATH := "res://audio/music/%s.wav"
const BPM := 125.0
const LOOP_BARS := 16
const BAR_SECONDS := 240.0 / BPM
const LOOP_SECONDS := BAR_SECONDS * LOOP_BARS
const FADE_BARS := 2.0
const BUS := "Music"
const DEFAULT_VOLUME := 0.7
const OPEN_CUTOFF := 20000.0
## Paused or unfocused: this much quieter, behind this low-pass, reached this fast.
const DUCK_GAIN := 0.35
const DUCK_CUTOFF := 650.0
const DUCK_SECONDS := 0.3
const SILENT_DB := -80.0

## Shift layers by game hour, 09:00 through 17:00: [pulse, hats, air, tension].
## The intro bed plays throughout; each hour thickens a little.
const SHIFT_HOURS: Array = [
	[0.55, 0.0, 0.0, 0.0],   # 09:00 a soft kick and bass pulse arrive
	[0.8, 0.0, 0.0, 0.0],    # 10:00
	[1.0, 0.35, 0.0, 0.0],   # 11:00 the hat starts ticking
	[1.0, 0.6, 0.2, 0.0],    # 12:00 the figure's filter begins to open
	[1.0, 0.75, 0.4, 0.0],   # 13:00
	[1.0, 0.85, 0.55, 0.0],  # 14:00
	[1.0, 1.0, 0.7, 0.25],   # 15:00 claps and the drone creep in
	[1.0, 1.0, 0.85, 0.7],   # 16:00 late: busier, tenser
	[1.0, 1.0, 1.0, 1.0],    # 17:00
]

static var settings_path := "user://music.cfg"
## Headless runs (the test suite) have only a dummy audio driver, so the stems
## stay silent there unless a test asks to exercise real playback.
static var play_headless := false

var enabled := true
var volume := DEFAULT_VOLUME
var paused := false
var focused := true
## The ending variation held until the player leaves it ("" when none).
var ending := ""
var scene := "menu"

var _progress := 0.0
var _tense := false
var _players: Array[AudioStreamPlayer] = []
var _applied_db: Array[float] = []
var _bus := -1
var _filter: AudioEffectLowPassFilter
var _reverb: AudioEffectReverb
var _started := false
var _started_usec := 0
var _position_live := false
var _awaiting_gesture := false
## Current and target mixes: {stem: gain, "level", "cutoff", "reverb"}.
var _mix: Dictionary = {}
var _target: Dictionary = {}
var _pending: Dictionary = {}
var _fade_from: Dictionary = {}
var _fade_time := 0.0
var _fade_length := 0.0
var _duck := 0.0
var _last_bar := -1


## The mix for one moment of the game: a gain per stem, an overall level, a
## low-pass cutoff, and reverb wet. Pure, so tests can read it directly.
static func mix_for(at_scene: String, progress: float = 0.0, tense: bool = false, ending_kind: String = "") -> Dictionary:
	var mix := {"intro": 1.0, "pulse": 0.0, "hats": 0.0, "air": 0.0, "tension": 0.0, "level": 0.8, "cutoff": OPEN_CUTOFF, "reverb": 0.0}
	match at_scene:
		"menu":
			mix.level = 0.5
		"cold_open":
			mix.level = 0.42
			mix.cutoff = 2400.0
		"morning":
			mix.level = 0.8
		"shift":
			var hour: int = clampi(floori(clampf(progress, 0.0, 1.0) * SHIFT_HOURS.size()), 0, SHIFT_HOURS.size() - 1)
			var layers: Array = SHIFT_HOURS[hour]
			mix.pulse = layers[0]
			mix.hats = layers[1]
			mix.air = layers[2]
			mix.tension = layers[3]
			if tense:
				# An author pushing back: the hat and the late layer lean in.
				mix.hats = maxf(mix.hats, 0.6)
				mix.tension = maxf(mix.tension, 0.55)
			mix.level = 0.85
		"evening":
			# The end-of-day panel: the sparsest version, softened.
			mix.level = 0.55
			mix.cutoff = 3200.0
		"ending":
			if ending_kind == "bleak":
				# Lonely: the bare intro, far away behind a low-pass and a room.
				mix.level = 0.45
				mix.cutoff = 900.0
				mix.reverb = 0.3
			elif ending_kind == "warm":
				# A little warmer: the pulse returns softly, the figure half open.
				mix.pulse = 0.6
				mix.air = 0.5
				mix.level = 0.75
			else:
				mix.air = 0.3
				mix.level = 0.65
	return mix


## Which ending variation fits a finished run, mirroring Morgan's last word in
## content/chat.gd: Helios as the default gate, or a reassignment, is bleak.
static func ending_kind(state: Dictionary) -> String:
	if int(state.get("autonomy", 0)) >= 90 or int(state.get("trust", 0)) < 40:
		return "bleak"
	return "warm"


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
	for stem: String in STEMS:
		var path: String = STEM_PATH % stem
		var player := AudioStreamPlayer.new()
		player.name = stem.capitalize()
		player.bus = BUS
		player.volume_db = SILENT_DB
		if ResourceLoader.exists(path):
			player.stream = load(path)
		else:
			push_warning("Missing music stem %s; run tools/music/compose.py, then import." % path)
		add_child(player)
		_players.append(player)
		_applied_db.append(SILENT_DB)
	_target = mix_for(scene)
	_mix = _target.duplicate()
	_mix.level = 0.0
	# Browsers only allow audio after a user gesture.
	_awaiting_gesture = OS.has_feature("web")
	_start()
	_apply()


func _ensure_bus() -> void:
	_bus = AudioServer.get_bus_index(BUS)
	if _bus == -1:
		AudioServer.add_bus()
		_bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_bus, BUS)
		AudioServer.set_bus_send(_bus, "Master")
	if AudioServer.get_bus_effect_count(_bus) < 2:
		var low_pass := AudioEffectLowPassFilter.new()
		low_pass.resonance = 0.6
		AudioServer.add_bus_effect(_bus, low_pass, 0)
		var room := AudioEffectReverb.new()
		room.room_size = 0.75
		room.damping = 0.6
		room.spread = 1.0
		room.dry = 1.0
		room.wet = 0.0
		AudioServer.add_bus_effect(_bus, room, 1)
	_filter = AudioServer.get_bus_effect(_bus, 0) as AudioEffectLowPassFilter
	_reverb = AudioServer.get_bus_effect(_bus, 1) as AudioEffectReverb


func _start() -> void:
	if _started or not enabled or _awaiting_gesture or not is_inside_tree(): return
	if DisplayServer.get_name() == "headless" and not play_headless: return
	_started = true
	# Hold the mixer so every stem starts in the same mix step; equal lengths
	# and rates then keep them sample-locked for as long as they loop.
	AudioServer.lock()
	for player: AudioStreamPlayer in _players:
		if player.stream != null: player.play()
	AudioServer.unlock()
	_started_usec = Time.get_ticks_usec()
	_position_live = false
	_last_bar = _bar_index()
	# Enter on the current mix at once and let the level swell in over a bar.
	_pending = {}
	_target = _desired()
	_fade_from = _target.duplicate()
	_fade_from.level = 0.0
	_mix = _fade_from.duplicate()
	_fade_time = 0.0
	_fade_length = BAR_SECONDS


func _stop() -> void:
	_started = false
	for player: AudioStreamPlayer in _players:
		player.stop()


func _exit_tree() -> void:
	# Release the playbacks the mixer holds, so quitting leaves nothing behind.
	_stop()
	for player: AudioStreamPlayer in _players:
		player.stream = null


func _enter_tree() -> void:
	# Re-entering the tree (never on first entry, before _ready) restores the stems.
	if _players.is_empty(): return
	for index in _players.size():
		var path: String = STEM_PATH % STEMS[index]
		if ResourceLoader.exists(path): _players[index].stream = load(path)
	_start.call_deferred()


func _input(event: InputEvent) -> void:
	if not _awaiting_gesture: return
	var gesture := (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch) and event.is_pressed()
	if gesture:
		_awaiting_gesture = false
		_start()


## Report where the game is. A change waits for the next bar line; an ending
## set by play_ending holds until the player is back at the menu or a cold open.
func set_scene(next_scene: String, progress: float = 0.0, tense: bool = false) -> void:
	if not ending.is_empty():
		if next_scene in ["menu", "cold_open"]:
			ending = ""
		else:
			return
	scene = next_scene
	_progress = progress
	_tense = tense
	_retarget()


## Hook for ending screens: "warm" for a good ending, "bleak" for a lonely one.
## Any other kind gets a neutral take; "" releases the hold.
func play_ending(kind: String) -> void:
	ending = kind
	if not kind.is_empty():
		scene = "ending"
	_retarget()


func set_paused(value: bool) -> void:
	paused = value


func set_focused(value: bool) -> void:
	focused = value


func set_enabled(value: bool) -> void:
	if value == enabled: return
	enabled = value
	save_settings()
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


## Seconds into the 16-bar loop. Godot's playback position is the mixer's
## sample clock; where it does not advance (web samples), the wall clock since
## the synchronized start stands in.
func loop_position() -> float:
	if not _started: return 0.0
	var position := _players[0].get_playback_position()
	if position > 0.0: _position_live = true
	if _position_live:
		return fmod(position + AudioServer.get_time_since_last_mix(), LOOP_SECONDS)
	return fmod(float(Time.get_ticks_usec() - _started_usec) / 1000000.0, LOOP_SECONDS)


## The playback position in bars within the loop.
func bar_position() -> float:
	return loop_position() / BAR_SECONDS


## The gains actually applied now (after fades and ducking), for tests and debugging.
func current_mix() -> Dictionary:
	var result := _mix.duplicate()
	result.duck = _duck
	result.output_level = float(_mix.get("level", 0.0)) * lerpf(1.0, DUCK_GAIN, _duck)
	result.output_cutoff = _cutoff_now()
	return result


func pending_mix() -> Dictionary:
	return _pending.duplicate()


func _desired() -> Dictionary:
	return mix_for(scene, _progress, _tense, ending)


func _retarget() -> void:
	var desired := _desired()
	if desired == _target:
		_pending = {}
	elif desired != _pending:
		_pending = desired


func _process(delta: float) -> void:
	var bar := _bar_index()
	var crossed := bar != _last_bar
	_last_bar = bar
	step(delta, crossed)


## Advance fades by `delta` seconds. `bar_line` says a bar boundary just
## passed; without playback (music off) changes apply at once.
func step(delta: float, bar_line: bool) -> void:
	if not _pending.is_empty() and (bar_line or not _started):
		_fade_from = _mix.duplicate()
		_target = _pending
		_pending = {}
		_fade_time = 0.0
		_fade_length = FADE_BARS * BAR_SECONDS if _started else 0.0
	if _fade_time < _fade_length:
		_fade_time = minf(_fade_length, _fade_time + maxf(0.0, delta))
	var t := 1.0 if _fade_length <= 0.0 else _fade_time / _fade_length
	for key: String in _target:
		var a: float = float(_fade_from.get(key, _target[key]))
		var b: float = float(_target[key])
		if key == "cutoff":
			_mix[key] = exp(lerpf(log(a), log(b), t))
		else:
			_mix[key] = lerpf(a, b, t)
	var duck_target := 1.0 if paused or not focused else 0.0
	_duck = move_toward(_duck, duck_target, maxf(0.0, delta) / DUCK_SECONDS)
	_apply()


func _cutoff_now() -> float:
	var cutoff: float = float(_mix.get("cutoff", OPEN_CUTOFF))
	return exp(lerpf(log(cutoff), log(minf(cutoff, DUCK_CUTOFF)), _duck))


func _apply() -> void:
	if _players.is_empty(): return
	# The user's volume rides on each player rather than the bus, so it holds
	# for web samples too.
	var master := float(_mix.get("level", 0.0)) * lerpf(1.0, DUCK_GAIN, _duck) * volume
	for index in _players.size():
		var db := _db(float(_mix.get(STEMS[index], 0.0)) * master)
		if absf(db - _applied_db[index]) > 0.01:
			_players[index].volume_db = db
			_applied_db[index] = db
	AudioServer.set_bus_mute(_bus, not enabled)
	var cutoff := _cutoff_now()
	_filter.cutoff_hz = cutoff
	AudioServer.set_bus_effect_enabled(_bus, 0, cutoff < OPEN_CUTOFF * 0.95)
	var wet: float = float(_mix.get("reverb", 0.0))
	_reverb.wet = wet
	AudioServer.set_bus_effect_enabled(_bus, 1, wet > 0.001)


func _bar_index() -> int:
	return floori(bar_position()) if _started else -1


static func _db(gain: float) -> float:
	return SILENT_DB if gain <= 0.0001 else maxf(SILENT_DB, linear_to_db(gain))
