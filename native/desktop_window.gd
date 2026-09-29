extends PanelContainer
## A native floating desktop window with mouse and keyboard titlebar movement.

signal activated(window_id: String)
signal minimized(window_id: String)

var window_id: String = ""
var window_title: String = "WINDOW"
var body: VBoxContainer
var title_button: Button
var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _active: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var frame: VBoxContainer = VBoxContainer.new()
	frame.add_theme_constant_override("separation", 0)
	add_child(frame)
	var titlebar: HBoxContainer = HBoxContainer.new()
	titlebar.add_theme_constant_override("separation", 0)
	frame.add_child(titlebar)
	title_button = Button.new()
	title_button.text = "  " + window_title
	title_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_button.custom_minimum_size.y = 32
	title_button.add_theme_font_size_override("font_size", 12)
	title_button.tooltip_text = "Drag to move. With the title focused, use arrow keys; Shift moves farther."
	title_button.gui_input.connect(_title_input)
	titlebar.add_child(title_button)
	var minimize_button: Button = Button.new()
	minimize_button.text = "—"
	minimize_button.custom_minimum_size = Vector2(34, 32)
	minimize_button.tooltip_text = "Minimize " + window_title + "; reopen from the taskbar."
	minimize_button.pressed.connect(minimize_window)
	titlebar.add_child(minimize_button)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 9)
	frame.add_child(margin)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	margin.add_child(body)
	set_active(false)


func set_active(active: bool) -> void:
	_active = active
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color("172433")
	panel.border_color = Color("79c7da") if active else Color("405268")
	panel.set_border_width_all(1)
	panel.shadow_color = Color(0, 0, 0, 0.48)
	panel.shadow_size = 5
	panel.shadow_offset = Vector2(4, 5)
	add_theme_stylebox_override("panel", panel)
	if is_instance_valid(title_button):
		var title_style: StyleBoxFlat = StyleBoxFlat.new()
		title_style.bg_color = Color("294d62") if active else Color("253448")
		title_style.content_margin_top = 5
		title_style.content_margin_bottom = 5
		title_button.add_theme_stylebox_override("normal", title_style)
		title_button.add_theme_color_override("font_color", Color("e0edf5") if active else Color("a3b5c8"))


func focus_window() -> void:
	if not is_inside_tree() or not visible:
		return
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	activated.emit(window_id)


func minimize_window() -> void:
	_dragging = false
	hide()
	minimized.emit(window_id)


func restore_window(keyboard_focus: bool = true) -> void:
	show()
	clamp_to_desktop()
	focus_window()
	if keyboard_focus:
		title_button.grab_focus()


func clamp_to_desktop() -> void:
	var desktop: Control = get_parent() as Control
	if desktop == null:
		return
	# Keep a useful titlebar fragment reachable even when the body is offscreen.
	position.x = clampf(position.x, -maxf(0.0, size.x - 140.0), maxf(0.0, desktop.size.x - 140.0))
	position.y = clampf(position.y, 0.0, maxf(0.0, desktop.size.y - 34.0))


func move_window(delta: Vector2) -> void:
	position += delta
	clamp_to_desktop()


func _title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			focus_window()
			_dragging = true
			# GUI events are title-button-local; preserve the grab point in desktop space.
			var viewport_point: Vector2 = title_button.get_global_transform_with_canvas() * event.position
			_drag_offset = _desktop_point(viewport_point) - position
		else:
			_dragging = false
	elif event is InputEventKey and event.pressed:
		var step: float = 32.0 if event.shift_pressed else 8.0
		var delta: Vector2 = Vector2.ZERO
		match event.keycode:
			KEY_LEFT: delta.x = -step
			KEY_RIGHT: delta.x = step
			KEY_UP: delta.y = -step
			KEY_DOWN: delta.y = step
		if delta != Vector2.ZERO:
			focus_window()
			move_window(delta)
			accept_event()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		_dragging = false
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed:
			_dragging = false
		elif _contains_viewport_point(self, event.position) and _is_top_window_at_pointer(event.position):
			focus_window()
	elif event is InputEventMouseMotion and _dragging:
		# Use the delivered motion coordinates, not the separately polled OS cursor.
		position = _desktop_point(event.position) - _drag_offset
		clamp_to_desktop()


func _desktop_point(viewport_point: Vector2) -> Vector2:
	var desktop := get_parent() as Control
	return desktop.get_global_transform_with_canvas().affine_inverse() * viewport_point


func _contains_viewport_point(control: Control, viewport_point: Vector2) -> bool:
	var local_point := control.get_global_transform_with_canvas().affine_inverse() * viewport_point
	return Rect2(Vector2.ZERO, control.size).has_point(local_point)


func _is_top_window_at_pointer(viewport_point: Vector2) -> bool:
	var siblings: Array[Node] = get_parent().get_children()
	siblings.reverse()
	for sibling: Node in siblings:
		if sibling is PanelContainer and sibling.visible and _contains_viewport_point(sibling, viewport_point):
			return sibling == self
	return true
