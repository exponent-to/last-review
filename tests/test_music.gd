extends SceneTree
## Soundtrack checks: the stems and the workday song exist, loop, and line up;
## the game state maps to the intended layers (Motorik Minor for the shift, the
## stem bed elsewhere); stem changes wait for a bar line while the song crosses
## at once and resumes where it stopped; pause ducks; and the MUSIC toggle and
## volume persist. Headless audio is a dummy driver, so these
## read the mix the manager applies rather than listening to it.

const Music = preload("res://native/music.gd")
const Main = preload("res://native/main.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	Music.settings_path = "user://music-test-%d.cfg" % Time.get_ticks_usec()
	# Exercise real (dummy-driver) playback here; other suites keep it silent.
	Music.play_headless = true
	_test_stems()
	_test_mapping()
	await _test_transitions()
	await _test_settings()
	await _test_application()
	DirAccess.remove_absolute(Music.settings_path)
	# Let the mixer release the stopped playbacks before quitting.
	await create_timer(0.3).timeout
	print("Music checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

func _test_stems() -> void:
	var lengths: Array = []
	for stem: String in Music.STEMS:
		var path: String = Music.STEM_PATH % stem
		_check(ResourceLoader.exists(path), "Stem %s must exist and be imported." % path)
		var stream := load(path) as AudioStreamWAV
		_check(stream != null, "Stem %s must import as a WAV stream." % stem)
		if stream == null: continue
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_begin == 0, "Stem %s must loop forward from its start." % stem)
		_check(stream.loop_end == roundi(Music.LOOP_SECONDS * stream.mix_rate), "Stem %s must loop after exactly %d bars at %d BPM." % [stem, Music.LOOP_BARS, Music.BPM])
		# A few continuation samples follow the loop end so interpolation reads the
		# loop's start at the wrap instead of silence.
		_check(stream.get_length() * stream.mix_rate > stream.loop_end, "Stem %s must carry continuation samples past its loop end." % stem)
		_check(stream.format == AudioStreamWAV.FORMAT_QOA and not stream.stereo, "Stem %s must ship as compact mono QOA." % stem)
		lengths.append([stream.loop_end, stream.mix_rate, stream.get_length()])
	_check(lengths.size() == Music.STEMS.size(), "Every stem must load.")
	_check(ResourceLoader.exists(Music.SONG_PATH), "The workday song must exist and be imported.")
	var song := load(Music.SONG_PATH) as AudioStreamOggVorbis
	_check(song != null and song.loop and song.loop_offset == 0.0, "Motorik Minor imports as a looping Ogg Vorbis stream.")
	if song != null:
		_check(song.get_length() > 170.0 and song.get_length() < 185.0, "The workday song is the full ~3-minute track.")
	_check(FileAccess.get_file_as_bytes(Music.SONG_PATH).size() <= 4 * 1024 * 1024, "The workday song stays at or under 4 MB for the web build.")
	for entry: Array in lengths:
		_check(entry == lengths[0], "All stems must share one loop length, rate, and file length to stay in lockstep.")

func _gains(mix: Dictionary) -> Array:
	return Music.STEMS.map(func(stem: String) -> float: return float(mix[stem]))

func _test_mapping() -> void:
	var morning := Music.mix_for("morning")
	_check(_gains(morning) == [1.0, 0.0, 0.0, 0.0, 0.0], "Morning reading plays only the sparse intro bed.")
	var menu := Music.mix_for("menu")
	_check(_gains(menu) == [1.0, 0.0, 0.0, 0.0, 0.0] and menu.level < morning.level, "The menu plays the intro bed at a lower level.")
	var cold := Music.mix_for("cold_open")
	_check(_gains(cold) == [1.0, 0.0, 0.0, 0.0, 0.0] and cold.cutoff < Music.OPEN_CUTOFF, "The cold open hears the intro bed, muffled.")
	# The shift is Motorik Minor alone, from BEGIN SHIFT to 18:00.
	for progress: float in [0.0, 0.05, 0.5, 0.85, 1.0]:
		var shift := Music.mix_for("shift", progress)
		_check(shift.song == 1.0 and _gains(shift) == [0.0, 0.0, 0.0, 0.0, 0.0], "The shift plays Motorik Minor and no stems (progress %.2f)." % progress)
	for other: String in ["menu", "cold_open", "morning", "evening", "ending"]:
		_check(Music.mix_for(other).song == 0.0, "%s keeps the stem bed, not the song." % other)
	var calm := Music.mix_for("shift", 0.1)
	var tense := Music.mix_for("shift", 0.1, true)
	_check(tense.song < calm.song and tense.song >= 0.8, "Pushback at the desk only dips the song slightly.")
	_check(_gains(tense) == _gains(calm), "Pushback no longer leans stems in.")
	var evening := Music.mix_for("evening")
	_check(_gains(evening) == [1.0, 0.0, 0.0, 0.0, 0.0] and evening.level < morning.level, "Morgan's end-of-day panel is the sparsest version.")
	var warm := Music.mix_for("ending", 0.0, false, "warm")
	var bleak := Music.mix_for("ending", 0.0, false, "bleak")
	_check(_gains(bleak) == [1.0, 0.0, 0.0, 0.0, 0.0] and bleak.cutoff < 1000.0 and bleak.reverb > 0.0, "A bleak ending is the lonely, filtered intro.")
	_check(warm.pulse > 0.0 and warm.air > 0.0 and warm.level > bleak.level and warm.cutoff == Music.OPEN_CUTOFF, "A good ending is a little warmer.")
	for warm_ending: String in ["last_reviewers", "soft_landing"]:
		_check(Music.ending_kind({"ending": warm_ending}) == "warm", "%s is a warm ending." % warm_ending)
	for bleak_ending: String in ["right_and_alone", "helios_prime", "player_fired", "garnished", "team_fired"]:
		_check(Music.ending_kind({"ending": bleak_ending}) == "bleak", "%s is a bleak ending." % bleak_ending)

func _test_transitions() -> void:
	var music := Music.new()
	root.add_child(music)
	await process_frame
	await create_timer(0.2).timeout
	var positions: Array = music._players.map(func(player: AudioStreamPlayer) -> float: return player.get_playback_position())
	_check(music._players.size() == Music.STEMS.size() and music._players.all(func(player: AudioStreamPlayer) -> bool: return player.playing), "Every stem plays from the start.")
	_check(positions.all(func(position: float) -> bool: return position == positions[0]), "The stems start in the same mix step and stay in lockstep.")
	music.set_process(false)
	music.set_enabled(true)
	music.set_scene("morning")
	music.step(0.1, true)
	music.step(10.0, false)
	_check(_gains(music.current_mix()) == [1.0, 0.0, 0.0, 0.0, 0.0], "The morning mix settles on the intro bed.")
	# Stem changes wait for a bar line and fade over two bars.
	music.set_scene("evening")
	music.step(0.5, false)
	_check(not music.pending_mix().is_empty() and is_equal_approx(music.current_mix().level, Music.mix_for("morning").level), "A stem change waits for the next bar line.")
	music.step(0.0, true)
	_check(music.pending_mix().is_empty(), "The bar line starts the change.")
	music.step(Music.BAR_SECONDS, false)
	var halfway: float = music.current_mix().level
	_check(halfway < Music.mix_for("morning").level and halfway > Music.mix_for("evening").level, "Stem changes fade over two bars rather than cutting.")
	music.step(Music.BAR_SECONDS * 2.0, false)
	music.set_scene("morning")
	music.step(0.0, true)
	music.step(10.0, false)
	# BEGIN SHIFT: the song crosses in at once, over about two seconds, from the top.
	music.set_scene("shift", 0.0)
	music.step(0.0, false)
	_check(music.pending_mix().is_empty(), "Entering the shift crossfades at once, without waiting for a bar.")
	music.step(Music.SONG_FADE_SECONDS * 0.5, false)
	var crossing := music.current_mix()
	_check(crossing.song > 0.2 and crossing.song < 0.8 and crossing.intro > 0.2 and crossing.intro < 0.8, "The morning bed and the song crossfade.")
	_check(music.song_playing(), "The song plays as soon as it fades in.")
	music.step(Music.SONG_FADE_SECONDS, false)
	_check(music.current_mix().song == 1.0 and _gains(music.current_mix()) == [0.0, 0.0, 0.0, 0.0, 0.0], "The crossfade lands on the song alone.")
	music.set_scene("shift", 0.1, true)
	music.step(0.0, true)
	music.step(Music.BAR_SECONDS * 3.0, false)
	_check(is_equal_approx(music.current_mix().song, Music.PUSHBACK_DIP), "Pushback dips the song.")
	music.set_scene("shift", 0.1)
	music.step(0.0, true)
	music.step(Music.BAR_SECONDS * 3.0, false)
	await create_timer(0.6).timeout
	var heard := music.song_position()
	_check(heard > 0.3, "The song advances while the shift runs.")
	# 18:00: back to the stems at the evening panel, remembering the song's place.
	music.set_scene("evening")
	music.step(0.0, false)
	music.step(Music.SONG_FADE_SECONDS + 0.1, false)
	_check(not music.song_playing() and music.current_mix().intro == 1.0, "The evening panel crossfades back to the stems and stops the song.")
	_check(music.song_position() >= heard, "The song remembers where it stopped.")
	# Back into the same shift (say, after the menu): it resumes there.
	music.set_scene("shift", 0.5)
	music.step(0.0, false)
	music.step(0.1, false)
	_check(music.song_playing() and music.song_position() >= heard, "Returning to a shift under way resumes the song where it was.")
	music.set_scene("evening")
	music.step(0.0, false)
	music.step(Music.SONG_FADE_SECONDS + 0.1, false)
	# A new day's BEGIN SHIFT starts the song from the top.
	music.set_scene("shift", 0.0)
	music.step(0.0, false)
	music.step(0.05, false)
	_check(music.song_playing() and music.song_position() < heard, "A new shift starts the song from the top.")
	# Pause ducks and filters at once, without waiting for a bar.
	music.set_paused(true)
	music.step(1.0, false)
	var ducked := music.current_mix()
	_check(ducked.output_level < ducked.level * 0.5 and ducked.output_cutoff <= Music.DUCK_CUTOFF + 1.0, "Pause ducks the music behind a low-pass.")
	_check(AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index(Music.BUS), 0), "The Music bus low-pass is engaged while paused.")
	music.set_paused(false)
	music.step(1.0, false)
	var resumed := music.current_mix()
	_check(is_equal_approx(resumed.output_level, resumed.level) and resumed.output_cutoff >= Music.OPEN_CUTOFF * 0.99, "Resuming restores the full mix.")
	music.set_focused(false)
	music.step(1.0, false)
	_check(music.current_mix().duck == 1.0, "Losing window focus ducks the music too.")
	music.set_focused(true)
	music.step(1.0, false)
	# Endings hold until the player leaves them.
	music.play_ending("bleak")
	music.step(0.0, true)
	music.step(10.0, false)
	_check(music.scene == "ending" and music.current_mix().cutoff < 1000.0, "play_ending('bleak') plays the lonely variation.")
	music.set_scene("shift", 0.2)
	_check(music.scene == "ending" and music.ending == "bleak", "An ending holds against ordinary scene updates.")
	music.set_scene("menu")
	_check(music.scene == "menu" and music.ending.is_empty(), "Returning to the menu releases the ending.")
	music.queue_free()
	await process_frame

func _test_settings() -> void:
	DirAccess.remove_absolute(Music.settings_path)
	var defaults := Music.load_settings()
	_check(defaults.enabled == true and is_equal_approx(defaults.volume, Music.DEFAULT_VOLUME), "Music defaults on at a modest volume.")
	var music := Music.new()
	root.add_child(music)
	await process_frame
	music.set_enabled(false)
	music.set_volume(0.3)
	_check(not music.is_playing() and AudioServer.is_bus_mute(AudioServer.get_bus_index(Music.BUS)), "MUSIC off stops and mutes the soundtrack.")
	music.queue_free()
	await process_frame
	var saved := Music.load_settings()
	_check(saved.enabled == false and is_equal_approx(saved.volume, 0.3), "The MUSIC toggle and volume persist on this computer.")
	var again := Music.new()
	root.add_child(again)
	await process_frame
	_check(not again.enabled and is_equal_approx(again.volume, 0.3) and not again.is_playing(), "A new session starts with the saved music settings.")
	again.set_enabled(true)
	_check(again.is_playing() or OS.has_feature("web"), "MUSIC on starts the soundtrack again.")
	again.queue_free()
	await process_frame
	DirAccess.remove_absolute(Music.settings_path)

func _test_application() -> void:
	root.size = Vector2i(1280, 900)
	Main.SaveStore.storage_root = "user://music-app-test-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(Main.SaveStore.storage_root)
	var app := Main.new()
	root.add_child(app)
	await process_frame
	await process_frame
	_check(is_instance_valid(app.music) and app.music.scene == "menu", "The main menu plays the menu mix.")
	var toggle: Button = app.interface._music_toggle
	var slider: HSlider = app.interface._music_volume
	_check(toggle.button_pressed == app.music.enabled and is_equal_approx(slider.value, app.music.volume), "SYSTEM shows the current music settings.")
	toggle.button_pressed = false
	_check(not app.music.enabled and toggle.text == "MUSIC: OFF" and not slider.editable, "SYSTEM's MUSIC toggle turns the soundtrack off.")
	slider.editable = true
	slider.value = 0.45
	_check(is_equal_approx(app.music.volume, 0.45), "SYSTEM's volume slider sets the music volume.")
	toggle.button_pressed = true
	_check(app.music.enabled and Music.load_settings().enabled, "Turning MUSIC back on persists.")
	# Into a shift: morning first, then the clock drives the layers.
	app.menu.hide()
	app.interface.show()
	app.interface.begin_morning()
	app._sync_music()
	_check(app.music.scene == "morning", "Morning reading plays the morning mix.")
	app.interface.morning_active = false
	app.state.shift_seconds = int(Main.Simulation.Catalog.shift_seconds() * 0.85)
	app._sync_music()
	_check(app.music.scene == "shift" and Music.mix_for("shift", 0.85).song == 1.0, "During the shift the workday song plays.")
	app._set_paused(true)
	app._sync_music()
	_check(app.music.paused, "Pausing the shift pauses (ducks) the music.")
	app._set_paused(false)
	app._sync_music()
	_check(not app.music.paused, "Resuming the shift restores the music.")
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(Music.settings_path)
