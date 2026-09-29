extends Control
## A native workshop control desk. State and disk persistence belong to the app.

signal command_requested(command: Dictionary)
signal save_requested
signal load_requested
signal reset_requested
signal motion_changed(enabled: bool)

const DESK: Color = Color("343b36")
const PAPER: Color = Color("b8b6a1")
const PAPER_LIGHT: Color = Color("cecab2")
const INK: Color = Color("262b26")
const MUTED: Color = Color("5e6458")
const LINE: Color = Color("777e6c")
const RUST: Color = Color("833f32")

var scene_host: Control
var _values: Dictionary = {}
var _command_buttons: Array[Button] = []
var _production_buttons: Array[Button] = []
var _speed_buttons: Dictionary = {}
var _production_note: Label
var _scene_status: Label
var _log_labels: Array[Label] = []
var _clock_label: Label
var _notice: Label
var _confirmation: ConfirmationDialog
var _last_log: String = ""
var _notice_generation: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _build_theme()
	var background: ColorRect = ColorRect.new()
	background.color = DESK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var outer: MarginContainer = _margin(self, 14, 10)
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame: VBoxContainer = _column(outer, 8)
	_build_header(frame)
	_build_resources(frame)
	_build_scene(frame)
	var tabs: TabContainer = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.tab_alignment = TabBar.ALIGNMENT_LEFT
	frame.add_child(tabs)
	_build_control(_tab(tabs, "CONTROL"))
	_build_records(_tab(tabs, "RECORDS"))
	_build_system(_tab(tabs, "SYSTEM"))
	_build_footer(frame)
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Reset workshop"
	_confirmation.dialog_text = "Discard the current workshop and start a new run?\nSaved progress remains on disk until overwritten."
	_confirmation.ok_button_text = "Reset workshop"
	_confirmation.cancel_button_text = "Cancel"
	_confirmation.min_size = Vector2i(490, 160)
	_confirmation.confirmed.connect(func() -> void: reset_requested.emit())
	add_child(_confirmation)


func _build_theme() -> Theme:
	var result: Theme = Theme.new()
	var mono: SystemFont = SystemFont.new()
	mono.font_names = PackedStringArray(["Menlo", "Courier New", "monospace"])
	result.default_font = mono
	result.default_font_size = 15
	result.set_color("font_color", "Label", INK)
	result.set_color("font_color", "TooltipLabel", PAPER_LIGHT)
	result.set_stylebox("panel", "TooltipPanel", _style(DESK, LINE, 1, 10, 7))
	result.set_stylebox("panel", "AcceptDialog", _style(PAPER, INK, 2, 16, 14))
	result.set_color("font_color", "Button", PAPER_LIGHT)
	result.set_color("font_hover_color", "Button", PAPER_LIGHT)
	result.set_color("font_focus_color", "Button", PAPER_LIGHT)
	result.set_color("font_pressed_color", "Button", PAPER_LIGHT)
	result.set_color("font_disabled_color", "Button", Color("888f7e"))
	result.set_stylebox("normal", "Button", _style(DESK, INK, 1, 10, 7))
	result.set_stylebox("hover", "Button", _style(Color("454f43"), INK, 1, 10, 7))
	result.set_stylebox("pressed", "Button", _style(RUST, INK, 1, 10, 7))
	result.set_stylebox("disabled", "Button", _style(Color("51584b"), LINE, 1, 10, 7))
	var focus: StyleBoxFlat = _style(Color.TRANSPARENT, PAPER_LIGHT, 2, 0, 0)
	focus.draw_center = false
	focus.set_expand_margin_all(2)
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("panel", "PanelContainer", _style(PAPER, INK, 1, 0, 0))
	result.set_stylebox("panel", "TabContainer", _style(PAPER, INK, 1, 9, 9))
	result.set_stylebox("tab_selected", "TabContainer", _style(PAPER, INK, 1, 20, 8))
	result.set_stylebox("tab_unselected", "TabContainer", _style(Color("454c42"), INK, 1, 20, 8))
	result.set_stylebox("tab_hovered", "TabContainer", _style(Color("5c6455"), INK, 1, 20, 8))
	result.set_stylebox("tab_focus", "TabContainer", focus)
	result.set_color("font_selected_color", "TabContainer", INK)
	result.set_color("font_unselected_color", "TabContainer", PAPER_LIGHT)
	result.set_color("font_hovered_color", "TabContainer", PAPER_LIGHT)
	result.set_font_size("font_size", "TabContainer", 14)
	result.set_constant("separation", "VBoxContainer", 8)
	result.set_constant("separation", "HBoxContainer", 8)
	result.set_color("font_color", "CheckBox", PAPER_LIGHT)
	result.set_color("font_hover_color", "CheckBox", PAPER_LIGHT)
	result.set_color("font_pressed_color", "CheckBox", PAPER_LIGHT)
	result.set_color("font_hover_pressed_color", "CheckBox", PAPER_LIGHT)
	result.set_stylebox("focus", "CheckBox", focus)
	return result


func _style(fill: Color, border: Color, width: int, horizontal: int, vertical: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


func _margin(parent: Node, horizontal: int = 12, vertical: int = 10) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	parent.add_child(margin)
	return margin


func _column(parent: Node, separation: int = 8) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column


func _row(parent: Node, separation: int = 8) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", separation)
	parent.add_child(row)
	return row


func _label(parent: Node, text: String, font_size: int = 15, color: Color = INK) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _paragraph(parent: Node, text: String, font_size: int = 15) -> Label:
	var label: Label = _label(parent, text, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


func _button(parent: Node, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size.y = 35
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _spacer(parent: Node) -> void:
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(spacer)


func _form(parent: Node, title: String) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style(PAPER_LIGHT, LINE, 1, 0, 0))
	parent.add_child(panel)
	var body: VBoxContainer = _column(_margin(panel), 9)
	_label(body, title, 14, RUST)
	return body


func _tab(parent: TabContainer, title: String) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var body: VBoxContainer = _column(scroll, 10)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return body


func _build_header(parent: Node) -> void:
	var row: HBoxContainer = _row(parent)
	_label(row, "YARD  /  WORKSHOP 01", 16, PAPER_LIGHT)
	_spacer(row)
	_label(row, "OPERATIONS TERMINAL  ·  001", 12, Color("929b85"))


func _build_resources(parent: Node) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("242c27"), Color("697462"), 1, 0, 0))
	parent.add_child(panel)
	var row: HBoxContainer = _row(_margin(panel, 14, 9), 18)
	for item: Array in [["FUNDS", "credits"], ["MATERIALS", "materials"], ["PARTS", "goods"], ["CREW", "workers"]]:
		var cell: HBoxContainer = _row(row, 12)
		_label(cell, str(item[0]), 12, Color("929b85"))
		var value: Label = _label(cell, "0", 19, PAPER_LIGHT)
		_register_value(str(item[1]), value)


func _build_scene(parent: Node) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("1b241e"), INK, 2, 4, 4))
	parent.add_child(panel)
	var column: VBoxContainer = _column(panel, 3)
	var heading: HBoxContainer = _row(column)
	_label(heading, " EXTERIOR / WORKSHOP", 11, Color("929b85"))
	_spacer(heading)
	_scene_status = _label(heading, "STANDING BY ", 11, PAPER_LIGHT)
	scene_host = Control.new()
	scene_host.name = "SceneHost"
	scene_host.custom_minimum_size = Vector2(640, 240)
	scene_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scene_host.clip_contents = true
	column.add_child(scene_host)


func _register_value(key: String, label: Label) -> void:
	if not _values.has(key):
		_values[key] = []
	var labels: Array = _values[key]
	labels.append(label)


func _build_control(page: VBoxContainer) -> void:
	var columns: HBoxContainer = _row(page, 10)
	var orders: VBoxContainer = _form(columns, "PRODUCTION ORDER / 01")
	_production_note = _paragraph(orders, "Line idle. Select MAKE PARTS.", 14)
	var modes: HBoxContainer = _row(orders, 6)
	for mode: String in ["idle", "parts"]:
		var command: Dictionary = {"type": "set-production", "production": mode}
		var button: Button = _button(modes, "STOP LINE" if mode == "idle" else "MAKE PARTS", _emit_command.bind(command))
		button.toggle_mode = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.set_meta("production", mode)
		_production_buttons.append(button)
	_command(orders, "REQUISITION 10 MATERIALS    $30", "buy-materials")
	_command(orders, "DISPATCH ALL PARTS     $12 / UNIT", "sell-goods")
	_command(orders, "ASSIGN WORKER             $100", "hire-worker")
	var log: VBoxContainer = _form(columns, "DISPATCH REGISTER / LATEST")
	var log_label: Label = _paragraph(log, "No entries.", 14)
	log_label.set_meta("limit", 5)
	_log_labels.append(log_label)


func _command(parent: Node, text: String, command_type: String) -> void:
	var button: Button = _button(parent, text, _emit_command.bind({"type": command_type}))
	button.set_meta("command", command_type)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_command_buttons.append(button)


func _balance(parent: Node, title: String, key: String) -> void:
	var row: HBoxContainer = _row(parent)
	_label(row, title, 15)
	_spacer(row)
	_register_value(key, _label(row, "0", 15))


func _build_records(page: VBoxContainer) -> void:
	var columns: HBoxContainer = _row(page, 10)
	var inventory: VBoxContainer = _form(columns, "INVENTORY STATEMENT")
	_balance(inventory, "Funds available", "credits")
	_balance(inventory, "Materials held", "materials")
	_balance(inventory, "Finished parts", "goods")
	_balance(inventory, "Dispatch value", "inventory_value")
	_label(inventory, "Crew limit: 6\nMaterials: $30 / 10\nDispatch:  $12 / part\nWorker:    $100", 13, MUTED)
	var history: VBoxContainer = _form(columns, "ACTIVITY REGISTER")
	var log_label: Label = _paragraph(history, "No entries.", 14)
	log_label.set_meta("limit", 20)
	_log_labels.append(log_label)


func _build_system(page: VBoxContainer) -> void:
	var columns: HBoxContainer = _row(page, 10)
	var storage: VBoxContainer = _form(columns, "LOCAL RECORDS")
	_paragraph(storage, "One save slot on this computer.", 14)
	var saves: HBoxContainer = _row(storage)
	_button(saves, "SAVE RECORD", func() -> void: save_requested.emit())
	_button(saves, "LOAD RECORD", func() -> void: load_requested.emit())
	_paragraph(storage, "Reset current run. Saved record is retained.", 14)
	_button(storage, "NEW WORKSHOP", func() -> void: _confirmation.popup_centered())
	var display: VBoxContainer = _form(columns, "DISPLAY OPTIONS")
	var motion: CheckBox = CheckBox.new()
	motion.text = "Background motion"
	motion.button_pressed = true
	motion.custom_minimum_size.y = 36
	motion.toggled.connect(func(enabled: bool) -> void: motion_changed.emit(enabled))
	display.add_child(motion)
	_paragraph(display, "Scene animation only. Simulation time is controlled below.", 14)


func _build_footer(parent: Node) -> void:
	_notice = _label(parent, "", 14, PAPER_LIGHT)
	_notice.visible = false
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row: HBoxContainer = _row(parent)
	_clock_label = _label(row, "RUNNING / TICK 0000", 13, PAPER_LIGHT)
	_spacer(row)
	_label(row, "CLOCK", 12, Color("929b85"))
	var speeds: HBoxContainer = _row(row, 4)
	speeds.size_flags_horizontal = Control.SIZE_SHRINK_END
	for speed: int in [0, 1, 2, 4]:
		var text: String = "PAUSE" if speed == 0 else "%d×" % speed
		var button: Button = _button(speeds, text, _emit_command.bind({"type": "set-speed", "speed": speed}))
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(48, 32)
		button.tooltip_text = "Pause simulation" if speed == 0 else "Simulation speed: %d×" % speed
		_speed_buttons[speed] = button


func _emit_command(command: Dictionary) -> void:
	command_requested.emit(command)


func render_state(state: Dictionary) -> void:
	var credits: int = int(state.get("credits", 0))
	var materials: int = int(state.get("materials", 0))
	var goods: int = int(state.get("goods", 0))
	var workers: int = int(state.get("workers", 0))
	var tick: int = int(state.get("tick", 0))
	var speed: int = int(state.get("speed", 1))
	var production: String = str(state.get("production", "idle"))
	var display_values: Dictionary = {
		"credits": "$%d" % credits,
		"materials": str(materials),
		"goods": str(goods),
		"workers": "%d / 6" % workers,
		"inventory_value": "$%d" % (goods * 12),
	}
	for key: String in _values:
		var labels: Array = _values[key]
		for label: Label in labels:
			label.text = str(display_values.get(key, ""))
	var status: String = "STANDING BY"
	var note: String = "Line idle. Select MAKE PARTS."
	if production == "parts":
		if materials == 0:
			status = "MATERIALS REQUIRED"
			note = "Line waiting. Requisition materials."
		elif speed == 0:
			status = "CLOCK STOPPED"
			note = "Order active. Resume clock to proceed."
		else:
			status = "ORDER IN PROGRESS"
			note = "Parts assembly active. Crew assigned: %d." % workers
	_scene_status.text = status + " "
	_production_note.text = note
	for button: Button in _production_buttons:
		button.set_pressed_no_signal(str(button.get_meta("production")) == production)
	for button_speed: int in _speed_buttons:
		var button: Button = _speed_buttons[button_speed]
		button.set_pressed_no_signal(button_speed == speed)
	_clock_label.text = "%s / TICK %04d" % ["PAUSED" if speed == 0 else "RUNNING", tick]
	for button: Button in _command_buttons:
		var action: String = str(button.get_meta("command"))
		match action:
			"buy-materials":
				button.disabled = credits < 30
				button.tooltip_text = "Insufficient funds." if button.disabled else "Purchase 10 raw materials."
			"sell-goods":
				button.disabled = goods == 0
				button.tooltip_text = "No finished parts available." if button.disabled else "Dispatch %d parts for $%d." % [goods, goods * 12]
			"hire-worker":
				button.disabled = credits < 100 or workers >= 6
				button.tooltip_text = "Crew at capacity." if workers >= 6 else "Assignment costs $100."
	var entries: Array = state.get("log", [])
	var log_key: String = JSON.stringify(entries)
	if log_key != _last_log:
		_last_log = log_key
		for label: Label in _log_labels:
			var limit: int = int(label.get_meta("limit"))
			var lines: PackedStringArray = []
			for index: int in range(entries.size() - 1, maxi(-1, entries.size() - limit - 1), -1):
				var entry: Dictionary = entries[index]
				lines.append("%04d  %s" % [int(entry.get("tick", 0)), str(entry.get("message", ""))])
			label.text = "\n\n".join(lines) if not lines.is_empty() else "No entries."


func notify(message: String, is_error: bool = false) -> void:
	_notice_generation += 1
	var generation: int = _notice_generation
	_notice.text = message
	_notice.add_theme_color_override("font_color", Color("e4a287") if is_error else PAPER_LIGHT)
	_notice.visible = true
	await get_tree().create_timer(8.0).timeout
	if generation == _notice_generation:
		_notice.visible = false
