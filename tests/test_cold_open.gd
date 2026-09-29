extends SceneTree

const ColdOpen = preload("res://native/cold_open.gd")
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
	var scene := ColdOpen.new()
	root.add_child(scene)
	var completions := [0]
	scene.finished.connect(func(): completions[0] += 1)
	_check(scene._skip.visible and not scene._skip.disabled, "Skip must be available from the dark opening.")
	_check(scene._laptop_rect() == Rect2(310, 260, 500, 330), "Opening must show the distant laptop.")
	_check(scene._ping.stream is AudioStreamWAV and scene._ping.stream.data.size() > 0, "Notification ping must have a generated local audio buffer.")
	scene._focused = false # Unit tests validate the sound buffer without starting audio playback.
	scene.advance_sequence(1.6)
	_check(scene._pinged and completions[0] == 0, "New mail pings without completing the opening.")
	scene.set_paused(true)
	scene.advance_sequence(8)
	_check(scene._elapsed == 1.6, "Pause must freeze the staged sequence.")
	scene.set_paused(false)
	scene.advance_sequence(4.4)
	_check(scene._laptop_rect() == Rect2(64, 66, 992, 668), "Push-in must settle on a readable laptop screen.")
	scene._on_focus_exited()
	_check(not scene.is_processing(), "Application focus loss must pause animation processing.")
	scene._on_focus_entered()
	_check(scene.is_processing(), "Application focus return must resume animation processing.")
	scene.advance_sequence(14.1)
	_check(scene._elapsed >= 20.1 and completions[0] == 0, "The signed offer must remain visible before the tutorial transition.")
	scene.advance_sequence(3)
	scene.advance_sequence(100)
	scene._complete()
	_check(completions[0] == 1 and not scene.is_processing_input(), "Automatic completion must emit exactly once and release input handling.")
	_check(not scene.is_queued_for_deletion(), "Parent owns the transition and scene disposal.")
	scene.free()

	var still := ColdOpen.new()
	still.set_motion(false)
	root.add_child(still)
	_check(still._elapsed == 12 and still._continue.visible and not still.is_processing(), "Reduced motion must show the readable offer and a manual continue control.")
	still.advance_sequence(100)
	_check(not still._completed, "Reduced motion waits for user action.")
	var lines := still._wrapped_lines(ColdOpen.OFFER, 752, 14)
	_check(128 + (lines.size() - 1) * 18 < 480, "The entire offer must fit above the signature button.")
	for line in lines:
		_check(still._font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x <= 752, "Offer text must wrap inside its email column.")
	still.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for extent in [Vector2(1120, 800), Vector2(1280, 900)]:
		still.size = extent
		still._layout()
		_check(Rect2(Vector2.ZERO, extent).encloses(Rect2(still._skip.position, still._skip.size)), "Skip must remain visible at supported window sizes.")
		_check(Rect2(Vector2.ZERO, extent).encloses(Rect2(still._continue.position, still._continue.size)), "Reduced-motion continue must remain visible at supported window sizes.")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	still._input(escape)
	_check(still._completed, "Escape must skip the cold open.")
	still.free()

	var skipped := ColdOpen.new()
	root.add_child(skipped)
	skipped._skip.pressed.emit()
	_check(skipped._completed, "Visible Skip button must finish immediately.")
	skipped.free()
	var fast := ColdOpen.new()
	root.add_child(fast)
	fast._focused = false
	var fast_completions := [0]
	fast.finished.connect(func(): fast_completions[0] += 1)
	fast.advance_sequence(30.0)
	fast._complete()
	_check(fast._completed and fast_completions[0] == 1, "One full-duration advance must cross all stages and emit completion exactly once.")
	fast.free()
	await process_frame
	print("Cold-open checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)
