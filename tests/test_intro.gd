extends SceneTree

const Intro = preload("res://native/intro.gd")
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
	var skipped := Intro.new()
	root.add_child(skipped)
	var skip_signals := [0]
	skipped.finished.connect(func(): skip_signals[0] += 1)
	_check(skipped._skip.visible and not skipped._skip.disabled, "Skip must be available immediately.")
	skipped._skip.pressed.emit()
	skipped._complete()
	_check(skip_signals[0] == 1, "Repeated completion must emit finished only once.")
	_check(not skipped.is_processing() and not skipped.is_processing_input(), "Completion must stop processing and input interception.")
	_check(not skipped.is_queued_for_deletion(), "The parent owns intro disposal.")
	skipped.free()

	var reduced := Intro.new()
	reduced.set_motion(false)
	root.add_child(reduced)
	var reduced_signals := [0]
	reduced.finished.connect(func(): reduced_signals[0] += 1)
	_check(reduced._final_revealed and reduced._begin.visible, "Reduced motion must reveal the final title immediately.")
	_check(reduced._begin.has_focus(), "Reduced motion must focus the begin button.")
	_check(not reduced.is_processing() and reduced_signals[0] == 0, "Reduced motion must wait for the player's begin action.")
	for index in range(reduced._lines.size()):
		_check(reduced._lines[index].visible_characters == Intro.LINES[index].length(), "Reduced motion must reveal all onboarding text.")
	reduced._begin.pressed.emit()
	_check(reduced_signals[0] == 1, "Begin shift must complete the intro.")
	reduced.free()

	var animated := Intro.new()
	root.add_child(animated)
	animated.set_paused(true)
	var paused_time: float = animated._elapsed
	animated._process(0.1)
	_check(animated._elapsed == paused_time and not animated.is_processing(), "Focus pause must preserve animation time.")
	animated.set_paused(false)
	_check(animated.is_processing(), "Focus restore must resume active onboarding.")
	for frame in range(110):
		animated._process(0.1)
	_check(animated._final_revealed and not animated._completed, "Timed onboarding must reach a waiting final prompt.")
	_check(not animated.is_processing(), "Final prompt must stop animation processing.")
	animated.set_motion(true)
	_check(not animated.is_processing(), "Re-enabling motion must not replay an already revealed intro.")
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	animated._input(enter)
	_check(animated._completed, "Enter must complete onboarding.")
	animated.free()

	var escaped := Intro.new()
	root.add_child(escaped)
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	escaped._input(escape)
	_check(escaped._completed, "Escape must skip onboarding immediately.")
	escaped.free()
	print("Intro checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)
