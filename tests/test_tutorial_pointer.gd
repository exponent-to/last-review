extends SceneTree

const Pointer = preload("res://native/tutorial_pointer.gd")
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
	var monitor := Control.new()
	monitor.position = Vector2(70, 85)
	monitor.size = Vector2(700, 500)
	monitor.scale = Vector2(1.2, 0.9)
	monitor.clip_contents = true
	root.add_child(monitor)
	var viewport_clip := Control.new()
	viewport_clip.position = Vector2(80, 60)
	viewport_clip.size = Vector2(230, 160)
	viewport_clip.clip_contents = true
	monitor.add_child(viewport_clip)
	var content := Control.new()
	content.size = Vector2(400, 600)
	viewport_clip.add_child(content)
	var target := Button.new()
	target.text = "Ask a question"
	target.position = Vector2(20, 30)
	target.size = Vector2(180, 36)
	content.add_child(target)
	var pointer := Pointer.new()
	monitor.add_child(pointer)
	pointer.set_target(target)
	await process_frame
	_check(pointer._visible_rect.is_equal_approx(Rect2(100, 90, 180, 36)), "Target geometry must match overlay space under translated and scaled ancestors.")
	_check(pointer.mouse_filter == Control.MOUSE_FILTER_IGNORE and pointer.focus_mode == Control.FOCUS_NONE, "Pointer must never intercept clicks or keyboard focus.")
	_check(pointer.z_index == 80 and pointer.clip_contents, "Pointer must sit below the pause layer and clip its own drawing.")
	var clicks := [0]
	target.pressed.connect(func(): clicks[0] += 1)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = target.get_global_transform_with_canvas() * Vector2(40, 18)
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
	_check(clicks[0] == 1, "Actual viewport clicks must pass through the overlay to its target button.")
	target.size.x = 200
	await process_frame
	await process_frame
	_check(is_equal_approx(pointer._visible_rect.size.x, 200), "The outline must track a resized target.")
	target.size.x = 180
	viewport_clip.position += Vector2(35, 12)
	await process_frame
	await process_frame
	_check(pointer._visible_rect.is_equal_approx(Rect2(135, 102, 180, 36)), "The pointer must follow a moved floating window without resetting its target.")
	content.position.y = -45
	await process_frame
	await process_frame
	_check(pointer._visible_rect.is_equal_approx(Rect2(135, 72, 180, 21)), "Scrolling must highlight only the target fragment inside the clip.")
	content.position.y = -100
	await process_frame
	await process_frame
	_check(not pointer._visible_rect.has_area(), "Fully scrolled-out targets must hide the cue.")
	content.position.y = 0
	target.hide()
	await process_frame
	await process_frame
	_check(not pointer._visible_rect.has_area(), "Hidden targets must hide the cue.")
	target.show()
	viewport_clip.position = Vector2(650, 450)
	await process_frame
	await process_frame
	_check(pointer._visible_rect.is_equal_approx(Rect2(670, 480, 30, 20)), "Target outlines must stop at the monitor boundary.")
	var arrow := pointer._arrow_points(Rect2(1, 1, 698, 498))
	_check(Rect2(Vector2.ZERO, monitor.size).has_point(arrow[0]) and Rect2(Vector2.ZERO, monitor.size).has_point(arrow[1]), "Even edge-to-edge target arrows must stay inside the monitor.")
	target.queue_free()
	await process_frame
	await process_frame
	_check(not pointer._visible_rect.has_area(), "Freed targets must clear without retaining or accessing a stale control.")
	pointer.set_target(null)
	_check(not pointer._visible_rect.has_area(), "Null explicitly clears the tutorial cue.")
	monitor.queue_free()
	await process_frame
	print("Tutorial pointer checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)
