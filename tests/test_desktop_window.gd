extends SceneTree
## Send real viewport input through hit testing, titlebar GUI handling and drag capture.

const DesktopWindow = preload("res://native/desktop_window.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _button(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	root.push_input(event, true)


func _motion(point: Vector2, previous: Vector2, held: bool = true) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - previous
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event, true)


func _run() -> void:
	root.size = Vector2i(1280, 900)
	var desktop := Control.new()
	desktop.position = Vector2(70, 85)
	desktop.size = Vector2(800, 550)
	root.add_child(desktop)
	var window := DesktopWindow.new()
	window.window_id = "review"
	window.position = Vector2(100, 90)
	window.size = Vector2(340, 240)
	desktop.add_child(window)
	# A later sibling makes activation reorder the tree before titlebar hit testing.
	var neighbor := DesktopWindow.new()
	neighbor.window_id = "rules"
	neighbor.position = Vector2(500, 100)
	neighbor.size = Vector2(270, 260)
	desktop.add_child(neighbor)
	for frame in range(3):
		await process_frame

	var start: Vector2 = window.title_button.get_global_transform_with_canvas() * Vector2(30, 16)
	var initial: Vector2 = window.position
	_button(start, true)
	_check(window._dragging, "Viewport titlebar press must begin dragging after activation reorders siblings.")
	_check(desktop.get_child(desktop.get_child_count() - 1) == window, "Pointer activation must raise the clicked window.")
	var moved := start + Vector2(180, 54)
	_motion(moved, start)
	_check(window.position.is_equal_approx(initial + Vector2(180, 54)), "Viewport mouse motion must move the window by the pointer delta.")
	var beyond := Vector2(2400, 1800)
	_motion(beyond, moved)
	_check(window.position.is_equal_approx(Vector2(660, 516)), "Pointer drag must clamp right/bottom while retaining the titlebar.")
	_button(beyond, false)
	var released: Vector2 = window.position
	_motion(start, beyond, false)
	_check(window.position == released, "Movement after button release must not drag the window.")

	# Repeat through GUI hit testing under a translated, non-uniformly scaled desktop.
	window.position = Vector2(120, 90)
	desktop.scale = Vector2(1.25, 0.9)
	await process_frame
	start = window.title_button.get_global_transform_with_canvas() * Vector2(35, 16)
	initial = window.position
	_button(start, true)
	moved = start + Vector2(125, 54)
	_motion(moved, start)
	_check(window.position.is_equal_approx(initial + Vector2(100, 60)), "Drag coordinates must transform viewport motion into desktop-local movement.")
	var before_still: Vector2 = window.position
	_motion(moved, moved)
	_check(window.position == before_still, "Repeated motion at the same pointer position must not jump or drift.")
	_motion(Vector2(-1200, -900), moved)
	_check(window.position.is_equal_approx(Vector2(-200, 0)), "Pointer drag must clamp left/top and preserve a reachable titlebar.")
	_button(Vector2(-1200, -900), false)
	released = window.position
	_motion(start, Vector2(-1200, -900), false)
	_check(window.position == released and not window._dragging, "An offscreen release must stop dragging permanently.")

	desktop.free()
	print("Desktop pointer checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)
