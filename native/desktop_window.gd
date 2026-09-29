extends PanelContainer
## A native floating desktop window with mouse and keyboard titlebar movement.

signal activated(window_id: String)
signal minimized(window_id: String)
signal closed(window_id: String)

const TerminalFont: FontFile = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
const DESKTOP_MARGIN: float = 6.0

var window_id: String = ""
var window_title: String = "WINDOW"
var body: VBoxContainer
var title_button: Button
var maximize_button: Button
var close_button: Button
var launched: bool = false
var maximized: bool = false
var _normal_rect: Rect2
var _normal_minimum: Vector2
var _chrome_buttons: Array[Button] = []
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
	title_button.add_theme_font_override("font", TerminalFont)
	title_button.clip_text = true
	title_button.tooltip_text = "Drag to move; double-click to maximize or restore. Arrow keys move a restored window; Shift moves farther."
	title_button.gui_input.connect(_title_input)
	titlebar.add_child(title_button)
	var minimize_button: Button = Button.new()
	minimize_button.text = "—"
	minimize_button.custom_minimum_size = Vector2(30, 32)
	minimize_button.tooltip_text = "Minimize " + window_title + "; reopen from the taskbar."
	minimize_button.pressed.connect(minimize_window)
	titlebar.add_child(minimize_button)
	_chrome_buttons.append(minimize_button)
	maximize_button = Button.new()
	maximize_button.text = "□"
	maximize_button.custom_minimum_size = Vector2(30, 32)
	maximize_button.tooltip_text = "Maximize " + window_title
	maximize_button.pressed.connect(toggle_maximize)
	titlebar.add_child(maximize_button)
	_chrome_buttons.append(maximize_button)
	close_button = Button.new()
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(30, 32)
	close_button.tooltip_text = "Close " + window_title
	close_button.pressed.connect(close_window)
	titlebar.add_child(close_button)
	_chrome_buttons.append(close_button)
	var margin: MarginContainer = MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for edge: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 9)
	frame.add_child(margin)
	# Scroll when content needs more space than the desktop, rather than forcing
	# the outer window beyond the visible monitor.
	var content_scroll: ScrollContainer = ScrollContainer.new()
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.follow_focus = true
	margin.add_child(content_scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	content_scroll.add_child(body)
	set_active(false)
	var desktop: Control = get_parent() as Control
	if desktop != null:
		desktop.resized.connect(clamp_to_desktop)
	hide()


func set_active(active: bool) -> void:
	_active = active
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color("172433")
	panel.border_color = Color("b8c9dc") if active else Color("8e9fae")
	panel.set_border_width_all(3)
	panel.shadow_color = Color(0, 0, 0, 0.48)
	panel.shadow_size = 5
	panel.shadow_offset = Vector2(4, 5)
	add_theme_stylebox_override("panel", panel)
	if is_instance_valid(title_button):
		var title_style: StyleBoxFlat = StyleBoxFlat.new()
		title_style.bg_color = Color("214e9a") if active else Color("a8b9cc")
		title_style.content_margin_top = 5
		title_style.content_margin_bottom = 5
		for state_name: String in ["normal", "hover", "pressed", "focus"]:
			title_button.add_theme_stylebox_override(state_name, title_style)
		title_button.add_theme_color_override("font_color", Color("ffffff") if active else Color("21354c"))

		for color_name: String in ["font_hover_color", "font_pressed_color", "font_focus_color"]:
			title_button.add_theme_color_override(color_name, Color("ffffff") if active else Color("21354c"))
	for button: Button in _chrome_buttons:
		button.add_theme_font_override("font", TerminalFont)
		button.add_theme_font_size_override("font_size", 16)
		for state_name: String in ["normal", "hover", "pressed"]:
			var chrome: StyleBoxFlat = StyleBoxFlat.new()
			chrome.bg_color = Color("d9e3ec") if state_name == "hover" else Color("b7c8d8")
			chrome.set_border_width_all(1)
			chrome.border_color = Color("53687b") if state_name == "pressed" else Color("edf3f8")
			button.add_theme_stylebox_override(state_name, chrome)
		for color_name: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(color_name, Color("13243a"))


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
	launched = true
	show()
	clamp_to_desktop()
	focus_window()
	if keyboard_focus:
		title_button.grab_focus()


func close_window() -> void:
	_dragging = false
	launched = false
	hide()
	closed.emit(window_id)


func toggle_maximize() -> void:
	_dragging = false
	if maximized:
		maximized = false
		custom_minimum_size = _normal_minimum
		position = _normal_rect.position
		size = _normal_rect.size
	else:
		_normal_rect = Rect2(position, size)
		_normal_minimum = custom_minimum_size
		custom_minimum_size = Vector2.ZERO
		maximized = true
	maximize_button.text = "↙" if maximized else "□"
	maximize_button.tooltip_text = ("Restore " if maximized else "Maximize ") + window_title
	clamp_to_desktop()
	focus_window()


func clamp_to_desktop() -> void:
	var desktop: Control = get_parent() as Control
	if desktop == null:
		return
	if maximized:
		position = Vector2(DESKTOP_MARGIN, DESKTOP_MARGIN)
		size = (desktop.size - Vector2.ONE * DESKTOP_MARGIN * 2.0).max(Vector2.ZERO)
		return
	# Keep a useful titlebar fragment reachable even when the body is offscreen.
	position.x = clampf(position.x, -maxf(0.0, size.x - 140.0), maxf(0.0, desktop.size.x - 140.0))
	position.y = clampf(position.y, 0.0, maxf(0.0, desktop.size.y - 34.0))


func move_window(delta: Vector2) -> void:
	if maximized:
		return
	position += delta
	clamp_to_desktop()


func _title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			focus_window()
			if event.double_click:
				toggle_maximize()
				accept_event()
				return
			if maximized:
				return
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
