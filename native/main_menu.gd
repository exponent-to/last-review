extends Control
## Opening view only. The application owns saves, game transitions, and quitting.

signal new_game_requested
signal load_game_requested
signal quit_requested

const ComputerFrame = preload("res://native/computer_frame.gd")
const TERMINAL_FONT = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
const INK := Color("d6e0e8")
const MUTED := Color("8ca2b5")
const CYAN := Color("9ed8e3")

var _load_available := false
var _motion := true
var _error_text := ""
var _backdrop: Control
var _screen: Panel
var _content: VBoxContainer
var _new_game: Button
var _load_game: Button
var _quit: Button
var _error: Label


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL


func _ready() -> void:
	_build_theme()
	_backdrop = ComputerFrame.new()
	add_child(_backdrop)
	_backdrop.set_motion(_motion)
	_screen = Panel.new()
	_screen.add_theme_stylebox_override("panel", _style(Color("102235"), Color("263e53")))
	add_child(_screen)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(center)
	_content = VBoxContainer.new()
	_content.custom_minimum_size.x = 510
	_content.add_theme_constant_override("separation", 13)
	center.add_child(_content)
	_label("LAST REVIEW", 48, INK)
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 24)
	_content.add_child(divider)
	_new_game = _button("New Game", "Begin a new run.")
	_new_game.pressed.connect(func() -> void: new_game_requested.emit())
	_load_game = _button("Load Game", "Continue your saved run.")
	_load_game.pressed.connect(func() -> void: load_game_requested.emit())
	_quit = _button("Quit", "Close Last Review.")
	_quit.visible = not OS.has_feature("web")
	_quit.pressed.connect(func() -> void: quit_requested.emit())
	_error = _label(_error_text, 14, Color("f2acac"))
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.custom_minimum_size.y = 42
	_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_load_available(_load_available)
	resized.connect(_layout)
	_layout()
	focus_default()


func set_load_available(available: bool) -> void:
	_load_available = available
	if is_instance_valid(_load_game):
		_load_game.disabled = not available
		_load_game.tooltip_text = "Continue your saved run." if available else "No saved run is available."
		if not available and _load_game.has_focus():
			focus_default()


func show_error(text: String) -> void:
	_error_text = text
	if is_instance_valid(_error):
		_error.text = text


func set_motion(enabled: bool) -> void:
	_motion = enabled
	if is_instance_valid(_backdrop):
		_backdrop.set_motion(enabled)


func focus_default() -> void:
	if is_instance_valid(_new_game) and is_visible_in_tree():
		_new_game.grab_focus()


func _layout() -> void:
	if not is_instance_valid(_screen):
		return
	var rect: Rect2 = ComputerFrame.get_screen_rect(size)
	_screen.position = rect.position
	_screen.size = rect.size


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_content.add_child(label)
	return label


func _button(text: String, hint: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = hint
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 47
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_content.add_child(button)
	return button


func _build_theme() -> void:
	var terminal := Theme.new()
	terminal.default_font = TERMINAL_FONT
	terminal.default_font_size = 17
	terminal.set_stylebox("normal", "Button", _style(Color("172e43"), Color("3e596c")))
	terminal.set_stylebox("hover", "Button", _style(Color("24435b"), CYAN))
	terminal.set_stylebox("pressed", "Button", _style(Color("0b1b2a"), CYAN))
	terminal.set_stylebox("disabled", "Button", _style(Color("122638"), Color("263e50")))
	var focus := _style(Color.TRANSPARENT, CYAN)
	focus.set_border_width_all(2)
	terminal.set_stylebox("focus", "Button", focus)
	terminal.set_color("font_color", "Button", INK)
	terminal.set_color("font_hover_color", "Button", Color.WHITE)
	terminal.set_color("font_pressed_color", "Button", CYAN)
	terminal.set_color("font_focus_color", "Button", Color.WHITE)
	terminal.set_color("font_disabled_color", "Button", Color("63798c"))
	terminal.set_stylebox("panel", "TooltipPanel", _style(Color("0e1c29"), MUTED))
	terminal.set_color("font_color", "TooltipLabel", INK)
	theme = terminal


func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
