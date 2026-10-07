extends SceneTree
## Soundtrack checks: every scene's track exists, imports, loops or plays once
## as intended, and fits the web budget; each game moment maps to its track;
## scenes crossfade; Motorik Minor resumes within a shift and restarts at a new
## one; one-shots play through once; pause and focus loss duck; endings hold;
## and the MUSIC toggle and volume persist. Headless audio is a dummy driver,
## so these read what the manager applies rather than listening to it.

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
	_test_tracks()
	_test_mapping()
	await _test_transitions()
	await _test_manual_loops()
	await _test_settings()
	await _test_application()
	DirAccess.remove_absolute(Music.settings_path)
	# Let the mixer release the stopped playbacks before quitting.
	await create_timer(0.3).timeout
	print("Music checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

func _test_tracks() -> void:
	var total := 0
	for track: String in Music.TRACKS:
		var path: String = Music.TRACKS[track]
		_check(ResourceLoader.exists(path), "%s must exist and be imported." % path)
		var stream := load(path) as AudioStreamOggVorbis
		_check(stream != null, "%s imports as Ogg Vorbis." % track)
		if stream == null: continue
		total += FileAccess.get_file_as_bytes(path).size()
		if track in Music.ONCE:
			_check(not stream.loop, "%s plays once." % track)
			_check(stream.get_length() >= 60.0 and stream.get_length() <= 110.0, "%s is cut to its scene (60-110 s)." % track)
		else:
			_check(stream.loop, "%s loops." % track)
			_check(stream.loop_offset >= 0.0 and stream.loop_offset < stream.get_length() - 20.0, "%s loops a section of at least 20 s." % track)
	_check(total <= 15 * 1024 * 1024, "All music together stays within 15 MB for the web build (%d bytes)." % total)
	_check(not ResourceLoader.exists("res://audio/music/intro.wav"), "The procedural stems are retired.")

func _test_mapping() -> void:
	var expected := {"menu": "title", "cold_open": "cold_open", "morning": "morning", "shift": "motorik_minor", "evening": "after_hours"}
	for at_scene: String in expected:
		_check(Music.mix_for(at_scene).track == expected[at_scene] and Music.mix_for(at_scene).gain == 1.0, "%s plays %s." % [at_scene, expected[at_scene]])
	_check(Music.mix_for("ending", false, "warm").track == "last_reviewers", "A warm ending plays Last Reviewers.")
	_check(Music.mix_for("ending", false, "bleak").track == "helios_prime", "A bleak ending plays Helios Prime.")
	var tense := Music.mix_for("shift", true)
	_check(tense.track == "motorik_minor" and tense.gain < 1.0 and tense.gain >= 0.8, "Pushback at the desk only dips the workday song slightly.")
	_check(Music.mix_for("morning", true).gain == 1.0, "Only the shift dips on pushback.")
	for warm_ending: String in ["last_reviewers", "soft_landing"]:
		_check(Music.ending_kind({"ending": warm_ending}) == "warm", "%s is a warm ending." % warm_ending)
	for bleak_ending: String in ["right_and_alone", "helios_prime", "player_fired", "garnished", "team_fired"]:
		_check(Music.ending_kind({"ending": bleak_ending}) == "bleak", "%s is a bleak ending." % bleak_ending)

func _settle(music: Node, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		music.step(minf(0.25, left))
		left -= 0.25

func _test_transitions() -> void:
	var music := Music.new()
	root.add_child(music)
	await process_frame
	music.set_process(false)
	_settle(music, 3.0)
	_check(music.track_playing("title") and music.current_mix().gains.title == 1.0, "The menu fades Title in.")
	# Scenes crossfade over about two seconds.
	music.set_scene("morning")
	music.step(Music.FADE_SECONDS * 0.5)
	var crossing: Dictionary = music.current_mix().gains
	_check(crossing.title > 0.3 and crossing.title < 0.7 and crossing.morning > 0.3 and crossing.morning < 0.7, "Title and Morning crossfade.")
	_check(music.track_playing("title") and music.track_playing("morning"), "Both play during the crossfade.")
	_settle(music, Music.FADE_SECONDS)
	_check(not music.track_playing("title") and music.current_mix().gains.morning == 1.0, "The crossfade lands on Morning alone and stops Title.")
	# BEGIN SHIFT: Motorik Minor from the top; pushback dips it.
	music.set_scene("shift", 0.0)
	_settle(music, Music.FADE_SECONDS + 0.5)
	_check(music.track_playing("motorik_minor") and music.current_mix().gains.motorik_minor == 1.0, "The shift plays Motorik Minor.")
	music.set_scene("shift", 0.1, true)
	_settle(music, 1.0)
	_check(is_equal_approx(music.current_mix().gains.motorik_minor, Music.PUSHBACK_DIP), "Pushback dips the song.")
	music.set_scene("shift", 0.1)
	_settle(music, 1.0)
	await create_timer(0.6).timeout
	var heard: float = music.track_position("motorik_minor")
	_check(heard > 0.3, "The song advances while the shift runs.")
	# 18:00: After Hours at the evening panel; the song remembers its place.
	music.set_scene("evening")
	_settle(music, Music.FADE_SECONDS + 0.5)
	_check(music.track_playing("after_hours") and not music.track_playing("motorik_minor"), "The evening panel crossfades to After Hours.")
	_check(music.track_position("motorik_minor") >= heard, "The song remembers where it stopped.")
	music.set_scene("shift", 0.5)
	_settle(music, 0.25)
	_check(music.track_playing("motorik_minor") and music.track_position("motorik_minor") >= heard, "Returning to a shift under way resumes the song.")
	music.set_scene("evening")
	_settle(music, Music.FADE_SECONDS + 0.5)
	music.set_scene("shift", 0.0)
	_settle(music, 0.25)
	_check(music.track_playing("motorik_minor") and music.track_position("motorik_minor") < heard, "A new shift starts the song from the top.")
	# The cold open plays once and does not loop when it ends.
	music.set_scene("cold_open")
	_settle(music, Music.FADE_SECONDS + 0.5)
	_check(music.track_playing("cold_open"), "The cold open plays Cold Open.")
	music._players.cold_open.finished.emit()
	music._players.cold_open.stop()
	_settle(music, 0.5)
	_check(not music.track_playing("cold_open"), "Cold Open is not restarted once it has played through.")
	# Pause ducks and filters at once.
	music.set_scene("morning")
	_settle(music, Music.FADE_SECONDS + 0.5)
	music.set_paused(true)
	_settle(music, 0.5)
	var ducked := music.current_mix()
	_check(ducked.duck_gain < 0.5 and ducked.output_cutoff <= Music.DUCK_CUTOFF + 1.0, "Pause ducks the music behind a low-pass.")
	_check(AudioServer.is_bus_effect_enabled(AudioServer.get_bus_index(Music.BUS), 0), "The Music bus low-pass is engaged while paused.")
	music.set_paused(false)
	_settle(music, 0.5)
	_check(music.current_mix().duck_gain == 1.0 and music.current_mix().output_cutoff >= Music.OPEN_CUTOFF * 0.99, "Resuming restores the music.")
	music.set_focused(false)
	_settle(music, 0.5)
	_check(music.current_mix().duck == 1.0, "Losing window focus ducks the music too.")
	music.set_focused(true)
	_settle(music, 0.5)
	# Endings hold until the player leaves them.
	music.play_ending("bleak")
	_settle(music, Music.FADE_SECONDS + 0.5)
	_check(music.scene == "ending" and music.track_playing("helios_prime"), "play_ending('bleak') plays Helios Prime.")
	music.set_scene("shift", 0.2)
	_check(music.scene == "ending" and music.ending == "bleak", "An ending holds against ordinary scene updates.")
	music.set_scene("menu")
	_check(music.scene == "menu" and music.ending.is_empty(), "Returning to the menu releases the ending.")
	music.play_ending("warm")
	_settle(music, Music.FADE_SECONDS + 0.5)
	_check(music.track_playing("last_reviewers") and not music.track_playing("helios_prime"), "play_ending('warm') plays Last Reviewers.")
	music.queue_free()
	await process_frame

## Web samples restart a loop from wherever play() began, ignoring the loop
## offset, so on the web the manager drives the wrap itself.
func _test_manual_loops() -> void:
	Music.manual_loops = true
	var music := Music.new()
	root.add_child(music)
	await process_frame
	music.set_process(false)
	music.set_scene("morning")
	_settle(music, Music.FADE_SECONDS + 0.5)
	var player: AudioStreamPlayer = music._players.morning
	var offset := music.loop_offset("morning")
	_check(offset > 20.0, "Morning has a loop offset past its intro (%.1f s)." % offset)
	_check(player.playing and not (player.stream as AudioStreamOggVorbis).loop, "With manual loops, the first pass plays a non-looping copy from the top.")
	_check(player.get_playback_position() < 5.0, "The first pass starts at the beginning.")
	# The pass ends: the manager restarts at the loop offset on the looping stream.
	player.stop()
	player.finished.emit()
	_check(player.playing and (player.stream as AudioStreamOggVorbis).loop, "At the end of a pass the looping stream takes over.")
	_check(player.get_playback_position() >= offset - 0.05, "The wrap restarts at loop_begin (%.2f s), not at 0 (got %.2f s)." % [offset, player.get_playback_position()])
	# A late finished signal, or _apply seeing the gap first, must not double-start or restart from 0.
	var at := player.get_playback_position()
	player.finished.emit()
	music.step(0.1)
	_check(player.playing and player.get_playback_position() >= at - 0.01, "A repeated end signal neither double-starts nor rewinds.")
	player.stop()
	music.step(0.1)
	_check(player.playing and player.get_playback_position() >= offset - 0.05, "If the frame sees the end before the signal, it still wraps to the loop offset.")
	# Motorik Minor resumed mid-song wraps to its own offset (0), not to the resume point.
	music.set_scene("shift", 0.0)
	_settle(music, Music.FADE_SECONDS + 0.5)
	music._resume = 120.0
	music.set_scene("evening")
	_settle(music, Music.FADE_SECONDS + 0.5)
	music._resume = 120.0
	music.set_scene("shift", 0.5)
	_settle(music, 0.25)
	var song: AudioStreamPlayer = music._players.motorik_minor
	_check(song.playing and song.get_playback_position() >= 119.9 and not (song.stream as AudioStreamOggVorbis).loop, "A resumed song plays a non-looping pass from where it stopped.")
	song.stop()
	song.finished.emit()
	_check(song.playing and song.get_playback_position() < 1.0, "The resumed song wraps to its loop offset (0), not to its resume point.")
	# One-shots still play once.
	music.set_scene("cold_open")
	_settle(music, Music.FADE_SECONDS + 0.5)
	var cold: AudioStreamPlayer = music._players.cold_open
	cold.stop()
	cold.finished.emit()
	_settle(music, 0.5)
	_check(not cold.playing, "Cold Open still plays once with manual loops.")
	music.queue_free()
	await process_frame
	Music.manual_loops = false


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
	_check(is_instance_valid(app.music) and app.music.scene == "menu" and app.music.target().track == "title", "The main menu plays Title.")
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
	# Into a shift: Morning first, then Motorik Minor.
	app.menu.hide()
	app.interface.show()
	app.interface.begin_morning()
	app._sync_music()
	_check(app.music.scene == "morning" and app.music.target().track == "morning", "Morning reading plays Morning.")
	app.interface.morning_active = false
	app.state.shift_seconds = int(Main.Simulation.Catalog.shift_seconds() * 0.85)
	app._sync_music()
	_check(app.music.scene == "shift" and app.music.target().track == "motorik_minor", "During the shift the workday song plays.")
	app._set_paused(true)
	app._sync_music()
	_check(app.music.paused, "Pausing the shift pauses (ducks) the music.")
	app._set_paused(false)
	app._sync_music()
	_check(not app.music.paused, "Resuming the shift restores the music.")
	# The menu's MUSIC corner switch and SYSTEM's toggle stay in step.
	var corner: Button = app.menu._music_toggle
	_check(corner.text == "MUSIC: ON" and corner.button_pressed, "The menu shows MUSIC: ON.")
	corner.button_pressed = false
	_check(not app.music.enabled and not app.interface._music_toggle.button_pressed and app.interface._music_toggle.text == "MUSIC: OFF", "The menu's switch turns music off and SYSTEM follows.")
	_check(corner.text == "MUSIC: OFF", "The menu shows MUSIC: OFF.")
	app.interface._music_toggle.button_pressed = true
	_check(app.music.enabled and corner.button_pressed and corner.text == "MUSIC: ON", "SYSTEM's toggle turns music back on and the menu follows.")
	# Until the browser's first gesture, the menu hints at clicking for sound.
	app.menu.show()
	app.music._awaiting_gesture = true
	app._sync_music()
	_check(app.menu._sound_hint.visible, "The menu hints 'click anywhere for sound' while audio is blocked.")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	app.music._input(click)
	app._sync_music()
	_check(not app.menu._sound_hint.visible and not app.music.awaiting_gesture(), "The first click clears the hint.")
	app.music._awaiting_gesture = true
	corner.button_pressed = false
	app._sync_music()
	_check(not app.menu._sound_hint.visible, "With music off there is nothing to hint about.")
	corner.button_pressed = true
	app.queue_free()
	await process_frame
	DirAccess.remove_absolute(Music.settings_path)
