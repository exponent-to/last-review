extends Control
## Opening view only. The application owns saves, game transitions, and quitting.

signal new_game_requested(slot: int)
signal load_game_requested(slot: int)
signal quit_requested

const ComputerFrame = preload("res://native/computer_frame.gd")
const TERMINAL_FONT = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
const INK := Color("e6e2d6")
const MUTED := Color("8c8981")
const CYAN := Color("6fdc8c")
const RED := Color("e5384a")

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
var _slot_heading: Label
var _slot_buttons: Array[Button] = []
var _back: Button
var _slots: Array[Dictionary] = []
var _slot_mode := ""
var _replace: ConfirmationDialog
var _pending_slot := 0
var _greeting: Label
var _blink := 0.0


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
	_screen.add_theme_stylebox_override("panel", _style(Color("0a0a0b"), Color("1c1c20")))
	add_child(_screen)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(center)
	_content = VBoxContainer.new()
	_content.custom_minimum_size.x = 510
	_content.add_theme_constant_override("separation", 13)
	center.add_child(_content)
	_greeting = _label("> hello, friend._", 15, CYAN)
	var title := _label("PRs please", 56, INK)
	# A red channel split, like a signal that doesn't quite belong to you.
	title.add_theme_color_override("font_shadow_color", Color(RED, 0.85))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title.add_theme_constant_override("shadow_outline_size", 0)
	_label("northstar engineering  ::  change control terminal n-7", 12, MUTED)
	var divider := ColorRect.new()
	divider.color = RED
	divider.custom_minimum_size = Vector2(64, 3)
	divider.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_content.add_child(divider)
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	_content.add_child(gap)
	_new_game = _button("New Game", "Begin a new run.")
	set_process(true)
	_new_game.pressed.connect(_show_slots.bind("new"))
	_load_game = _button("Load Game", "Continue your saved run.")
	_load_game.pressed.connect(_show_slots.bind("load"))
	_quit = _button("Quit", "Close PRs please.")
	_quit.visible = not OS.has_feature("web")
	_quit.pressed.connect(func() -> void: quit_requested.emit())
	_slot_heading = _label("Choose a save slot", 16, INK)
	_slot_heading.hide()
	for slot in range(1, 4):
		var button := _button("Slot %d — Empty" % slot, "")
		button.pressed.connect(_select_slot.bind(slot))
		button.hide()
		_slot_buttons.append(button)
	_back = _button("Back", "Return to New Game / Load Game")
	_back.pressed.connect(show_home)
	_back.hide()
	_replace = ConfirmationDialog.new()
	_replace.title = "Replace saved game?"
	_replace.ok_button_text = "Start new game"
	_replace.confirmed.connect(func() -> void: new_game_requested.emit(_pending_slot))
	add_child(_replace)
	_error = _label(_error_text, 14, RED)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.custom_minimum_size.y = 42
	_error.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_load_available(_load_available)
	resized.connect(_layout)
	_layout()
	focus_default()


func set_slots(slots: Array[Dictionary]) -> void:
	_slots = slots.duplicate(true)
	var available := false
	for slot: Dictionary in _slots:
		if slot.occupied: available = true
	set_load_available(available)
	if not _slot_mode.is_empty(): _show_slots(_slot_mode)


func show_home() -> void:
	_slot_mode = ""
	_new_game.show()
	_load_game.show()
	_quit.visible = not OS.has_feature("web")
	_slot_heading.hide()
	_back.hide()
	for button in _slot_buttons: button.hide()
	show_error("")
	focus_default()


func _show_slots(mode: String) -> void:
	_slot_mode = mode
	_new_game.hide()
	_load_game.hide()
	_quit.hide()
	_slot_heading.text = "New Game — choose a slot" if mode == "new" else "Load Game — choose a slot"
	_slot_heading.show()
	_back.show()
	show_error("")
	for index in range(3):
		var entry := _slots[index] if index < _slots.size() else {"occupied": false, "summary": "Empty"}
		var button := _slot_buttons[index]
		button.text = "Slot %d — %s" % [index + 1, entry.summary]
		button.disabled = mode == "load" and not entry.occupied
		button.show()
	_back.grab_focus()
	for button in _slot_buttons:
		if not button.disabled:
			button.grab_focus()
			break


func _select_slot(slot: int) -> void:
	if _slot_mode == "load":
		load_game_requested.emit(slot)
	elif _slot_mode == "new":
		if slot <= _slots.size() and _slots[slot - 1].occupied:
			_pending_slot = slot
			_replace.dialog_text = "Start a new game in Slot %d?
This replaces that slot's saved run. Other slots are kept." % slot
			_replace.popup_centered()
		else: new_game_requested.emit(slot)


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


func _process(delta: float) -> void:
	if not _motion or not is_instance_valid(_greeting): return
	_blink = fposmod(_blink + delta, 1.0)
	_greeting.text = "> hello, friend." + ("_" if _blink < 0.55 else " ")


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
	terminal.set_stylebox("normal", "Button", _style(Color("101012"), Color("2c2c31")))
	var hover := _style(Color("1a0c0f"), RED)
	hover.border_width_left = 6
	terminal.set_stylebox("hover", "Button", hover)
	terminal.set_stylebox("pressed", "Button", _style(Color("2a0d12"), RED))
	terminal.set_stylebox("disabled", "Button", _style(Color("0a0a0b"), Color("1c1c20")))
	var focus := _style(Color.TRANSPARENT, RED)
	focus.border_width_left = 6
	terminal.set_stylebox("focus", "Button", focus)
	terminal.set_color("font_color", "Button", INK)
	terminal.set_color("font_hover_color", "Button", Color.WHITE)
	terminal.set_color("font_pressed_color", "Button", RED)
	terminal.set_color("font_focus_color", "Button", Color.WHITE)
	terminal.set_color("font_disabled_color", "Button", Color("3f3d3a"))
	terminal.set_stylebox("panel", "TooltipPanel", _style(Color("0a0a0b"), MUTED))
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
