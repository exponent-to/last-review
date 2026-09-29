extends SceneTree
## Verify the opening cannot accidentally submit a review during its handoff.
const Main = preload("res://native/main.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 900)
	var app := Main.new()
	root.add_child(app)
	await process_frame
	_check(app.intro.visible and not app.interface.visible, "Opening must isolate the workstation from input.")
	app._on_focus_exited()
	_check(not app.intro.is_processing() and not app.scenery.is_processing(), "Focus loss must pause decorative animation.")
	app._on_focus_entered()
	var skip := InputEventKey.new()
	skip.pressed = true
	skip.keycode = KEY_ENTER
	root.push_input(skip)
	await process_frame
	var release := InputEventKey.new()
	release.keycode = KEY_ENTER
	release.pressed = false
	root.push_input(release)
	await process_frame
	_check(app.interface.visible and not is_instance_valid(app.intro), "Skipping must reveal the workstation and dispose the intro.")
	_check(app.state.request_index == 0 and app.state.decisions.is_empty(), "Skipping must not approve the first PR.")
	_check(root.gui_get_focus_owner() == app.interface, "Workstation handoff must focus a neutral surface.")
	_check(not app.interface._briefing_dialog.visible, "Skip key release must not open an unrelated control.")
	app._on_motion(false)
	app._on_focus_exited()
	app._on_focus_entered()
	_check(not app.scenery.is_processing(), "Focus restore must honor disabled background motion.")
	app.free()
	print("Native application handoff: %d failures" % failures)
	quit(1 if failures else 0)
