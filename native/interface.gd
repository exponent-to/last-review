extends Control
## Native review desk. Decisions and persistence are owned by the application.

signal command_requested(command: Dictionary)
signal save_requested
signal load_requested
signal reset_requested
signal motion_changed(enabled: bool)
signal pause_requested
signal menu_requested
signal tutorial_event(event: Dictionary)
signal tutorial_continue_requested

const Simulation = preload("res://native/simulation.gd")
const ComputerFrame = preload("res://native/computer_frame.gd")
const Notifications = preload("res://native/desktop_notifications.gd")
const DesktopWindow = preload("res://native/desktop_window.gd")
const Chat = preload("res://content/chat.gd")
const Catalog = preload("res://content/catalog.gd")
const TerminalFont: FontFile = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
const BACK: Color = Color("101824")
const SURFACE: Color = Color("192637")
const INSET: Color = Color("0d1520")
const BORDER: Color = Color("34465b")
const TEXT: Color = Color("e0e8ef")
const DIM: Color = Color("96a9be")
const CYAN: Color = Color("76c8dd")
const RED: Color = Color("e39499")
const GREEN: Color = Color("9ed6bb")

class DiffHighlighter extends SyntaxHighlighter:
	func _get_line_syntax_highlighting(line: int) -> Dictionary:
		var text: String = get_text_edit().get_line(line)
		var color: Color = Color("d6e1eb")
		if text.begins_with("+"):
			color = Color("9ed6bb")
		elif text.begins_with("-"):
			color = Color("e39499")
		elif text.begins_with("@@") or text.begins_with("diff"):
			color = Color("76c8dd")
		return {0: {"color": color}}

var scene_host: Control
var _state: Dictionary = {}
var _hud: Dictionary = {}
var _chat_contacts: Dictionary = {}
var _chat_unread: Dictionary = {}
var _chat_seen: Dictionary = {}
var _known_replies: Dictionary = {}
var _pending_replies: Dictionary = {}
var _reply_history_initialized := false
var _chat_contact: String = "Maya"
var _chat_last_draw: String = ""
var _chat_heading: Label
var _chat_scroll: ScrollContainer
var _chat_messages: VBoxContainer
var _rule_rows: Array[Dictionary] = []
var _monitor_screen: Control
var _desktop_home: Control
var _home_icons: Dictionary = {}
var _notifications: Notifications
var _app_counts := {"review": 0, "rules": 0, "chat": 0, "browser": 0, "system": 0}
var _app_badges: Dictionary = {}
var _known_requests: Dictionary = {}
var _unread_requests: Dictionary = {}
var _notification_day := -1
var _system_status: Label
var _desktop: Control
var _windows: Dictionary = {}
var _dock_buttons: Dictionary = {}
var _last_phase: String = ""
var _browser_address: LineEdit
var _browser_text: Label
var _browser_back: Button
var _browser_history: Array[String] = []
var _browser_path: String = "home"
var _evening_buttons: HBoxContainer
var _complete_button: Button
var _pr_id: Label
var _pr_title: Label
var _pr_context: Label
var _packet_scroll: ScrollContainer
var _file_label: Label
var _file_picker: OptionButton
var _review_files: Array = []
var _file_positions: Dictionary = {}
var _selected_files: Dictionary = {}
var _displayed_file_key: String = ""
var _diff: CodeEdit
var _search: LineEdit
var _category: OptionButton
var _rule_count: Label
var _selected_label: Label
var _clear_button: Button
var _approve: Button
var _reject: Button
var _consult: Button
var _ai_note: Label
var _feedback: Label
var _footer: Label
var _confirmation: ConfirmationDialog
var _briefing_dialog: AcceptDialog
var _last_pr: String = ""
var _last_day: int = -1
var _workspace_presented: bool = false
var _clock_label: Label
var _pause_button: Button
var _pause_overlay: ColorRect
var _resume_button: Button
var _paused: bool = false
var _chat_replies: VBoxContainer
var _chat_reply_pr: String = ""
var _tutorial_panel: PanelContainer
var _tutorial_title: Label
var _tutorial_body: Label
var _tutorial_next: Button
var _tutorial_active := false
var _tutorial_details: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _build_theme()
	scene_host = Control.new()
	scene_host.name = "ComputerFrameHost"
	scene_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scene_host)
	_monitor_screen = Control.new()
	_monitor_screen.name = "MonitorScreen"
	_monitor_screen.clip_contents = true
	add_child(_monitor_screen)
	var frame: VBoxContainer = _column(_monitor_screen, 0)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_os_menu(frame)
	_build_desktop(frame)
	_build_dock(frame)
	_build_tutorial_panel()
	_notifications = Notifications.new()
	_monitor_screen.add_child(_notifications)
	_notifications.activated.connect(_open_notification)
	_build_pause_overlay()
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Start a new run"
	_confirmation.dialog_text = "Discard this run and return to the first shift?\nYour disk save remains until overwritten."
	_confirmation.ok_button_text = "Start new run"
	_confirmation.cancel_button_text = "Keep reviewing"
	_confirmation.min_size = Vector2i(460, 160)
	_confirmation.confirmed.connect(func() -> void: reset_requested.emit())
	add_child(_confirmation)
	_briefing_dialog = AcceptDialog.new()
	_briefing_dialog.title = "Daily briefing"
	_briefing_dialog.min_size = Vector2i(660, 250)
	_briefing_dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_dialog.get_label().custom_minimum_size.x = 600
	add_child(_briefing_dialog)
	resized.connect(_layout_monitor)
	_layout_monitor.call_deferred()


func _layout_monitor() -> void:
	var screen: Rect2 = ComputerFrame.get_screen_rect(size)
	_monitor_screen.position = screen.position
	_monitor_screen.size = screen.size
	if is_instance_valid(_tutorial_panel):
		_tutorial_panel.position = Vector2(maxf(0, screen.size.x - 450), 48)


func _build_os_menu(parent: Node) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("b7bdc4"), Color("49535e"), 1, 8, 3))
	parent.add_child(panel)
	var row: HBoxContainer = _row(panel, 12)
	_label(row, "WORKSTATION", 12, Color("18212b"))
	_footer = _label(row, "READY", 11, Color("414b58"))
	_spacer(row)
	_hud["day"] = _label(row, "MONDAY", 12, Color("18212b"))
	_hud["status"] = _footer
	_clock_label = _label(row, "09:00", 14, Color("18212b"))
	_clock_label.custom_minimum_size.x = 50
	_clock_label.tooltip_text = "Shift: 09:00–18:00. Six real minutes. Pause stops the clock."
	_pause_button = _button(row, "PAUSE", func() -> void: pause_requested.emit())
	_pause_button.add_theme_font_size_override("font_size", 11)
	_pause_button.tooltip_text = "Pause the workday (Esc)"


func _build_pause_overlay() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.color = Color("101824")
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.z_index = 100
	_pause_overlay.hide()
	_monitor_screen.add_child(_pause_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)
	var box := _column(center, 18)
	_label(box, "WORKDAY PAUSED", 24, TEXT)
	_paragraph(box, "Your clock is stopped.
Resume when you're ready.", 15, DIM)
	_resume_button = _button(box, "RESUME SHIFT", func() -> void: pause_requested.emit())
	_button(box, "SAVE AND MAIN MENU", func() -> void: menu_requested.emit())


func set_paused(paused: bool) -> void:
	_paused = paused
	_notifications.paused = paused
	_pause_overlay.visible = paused
	_pause_button.text = "RESUME" if paused else "PAUSE"
	if paused:
		_resume_button.grab_focus()
	else:
		focus_workspace()


func render_clock(state: Dictionary) -> void:
	var minutes: int = Simulation.clock_minutes(state)
	_clock_label.text = "%02d:%02d" % [int(minutes / 60), minutes % 60]
	_clock_label.add_theme_color_override("font_color", Color("842e3d") if minutes >= 17 * 60 else Color("18212b"))
	_pause_button.disabled = str(state.get("phase", "review")) != "review"


func _build_theme() -> Theme:
	var result: Theme = Theme.new()
	result.default_font = TerminalFont
	result.default_font_size = 15
	for type_name: String in ["Label", "Button", "CheckBox", "OptionButton", "LineEdit", "TextEdit", "CodeEdit", "PopupMenu"]:
		result.set_color("font_color", type_name, TEXT)
		result.set_color("font_hover_color", type_name, TEXT)
		result.set_color("font_focus_color", type_name, TEXT)
		result.set_color("font_pressed_color", type_name, CYAN)
		result.set_color("font_disabled_color", type_name, Color("677b92"))
	var focus: StyleBoxFlat = _style(Color.TRANSPARENT, CYAN, 2, 0, 0)
	focus.draw_center = false
	for type_name: String in ["Button", "CheckBox", "OptionButton"]:
		result.set_stylebox("normal", type_name, _style(SURFACE, BORDER, 1, 9, 7))
		result.set_stylebox("hover", type_name, _style(Color("263950"), CYAN, 1, 9, 7))
		result.set_stylebox("pressed", type_name, _style(Color("203f53"), CYAN, 1, 9, 7))
		result.set_stylebox("disabled", type_name, _style(INSET, BORDER, 1, 9, 7))
		result.set_stylebox("focus", type_name, focus)
	for type_name: String in ["LineEdit", "TextEdit", "CodeEdit"]:
		result.set_stylebox("normal", type_name, _style(INSET, BORDER, 1, 9, 8))
		result.set_stylebox("read_only", type_name, _style(INSET, BORDER, 1, 9, 8))
		result.set_stylebox("focus", type_name, focus)
		result.set_color("font_readonly_color", type_name, TEXT)
		result.set_color("font_placeholder_color", type_name, DIM)
		result.set_color("caret_color", type_name, CYAN)
		result.set_color("selection_color", type_name, Color("345673"))
	result.set_color("line_number_color", "CodeEdit", Color("61788f"))
	result.set_stylebox("panel", "PanelContainer", _style(SURFACE, BORDER, 1, 0, 0))
	result.set_stylebox("panel", "TabContainer", _style(SURFACE, BORDER, 1, 8, 8))
	result.set_stylebox("tab_selected", "TabContainer", _style(SURFACE, CYAN, 1, 20, 7))
	result.set_stylebox("tab_unselected", "TabContainer", _style(INSET, BORDER, 1, 20, 7))
	result.set_stylebox("tab_hovered", "TabContainer", _style(SURFACE, DIM, 1, 20, 7))
	result.set_stylebox("tab_focus", "TabContainer", focus)
	result.set_color("font_selected_color", "TabContainer", CYAN)
	result.set_color("font_unselected_color", "TabContainer", DIM)
	result.set_color("font_hovered_color", "TabContainer", TEXT)
	result.set_font_size("font_size", "TabContainer", 14)
	result.set_stylebox("panel", "AcceptDialog", _style(SURFACE, BORDER, 1, 16, 14))
	result.set_stylebox("panel", "PopupMenu", _style(SURFACE, BORDER, 1, 8, 8))
	result.set_stylebox("panel", "TooltipPanel", _style(INSET, BORDER, 1, 10, 8))
	result.set_color("font_color", "TooltipLabel", TEXT)
	return result


func _style(fill: Color, border: Color, width: int, x: int, y: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.content_margin_left = x
	style.content_margin_right = x
	style.content_margin_top = y
	style.content_margin_bottom = y
	return style


func _margin(parent: Node, x: int = 10, y: int = 10) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", x)
	margin.add_theme_constant_override("margin_right", x)
	margin.add_theme_constant_override("margin_top", y)
	margin.add_theme_constant_override("margin_bottom", y)
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


func _label(parent: Node, text: String, font_size: int = 15, color: Color = TEXT) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _paragraph(parent: Node, text: String, font_size: int = 15, color: Color = TEXT) -> Label:
	var label: Label = _label(parent, text, font_size, color)
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


func _tab(parent: TabContainer, title: String) -> VBoxContainer:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = title
	page.add_theme_constant_override("separation", 10)
	parent.add_child(page)
	return page


func _scroll_column(parent: Node) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	return _column(scroll, 10)


func _build_desktop(parent: Node) -> void:
	_desktop = Control.new()
	_desktop.name = "TerminalDesktop"
	_desktop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desktop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_desktop.clip_contents = true
	parent.add_child(_desktop)
	_build_home()
	var review: DesktopWindow = _new_window("review", "REVIEW / CHANGE CONTROL")
	var review_body: HBoxContainer = _row(review.body, 12)
	review_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var code: VBoxContainer = _column(review_body)
	code.size_flags_stretch_ratio = 2.4
	_build_review_content(code)
	_build_decision(review_body)
	_build_rulebook(_new_window("rules", "HANDBOOK / ENGINEERING STANDARDS").body)
	_build_chat(_new_window("chat", "SLOUCH / ENGINEERING").body)
	_build_system(_new_window("system", "SYSTEM / WORKSTATION SETTINGS").body)
	_build_browser(_new_window("browser", "INTRANET / LOCAL BROWSER").body)

	for window: DesktopWindow in _windows.values():
		window.hide()
	_desktop.resized.connect(_arrange_windows)
	_desktop.resized.connect(_layout_home_icons)


func _build_home() -> void:
	_desktop_home = Control.new()
	_desktop_home.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_desktop.add_child(_desktop_home)
	var wallpaper: ColorRect = ColorRect.new()
	wallpaper.color = Color("213949")
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallpaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop_home.add_child(wallpaper)
	# Sparse native geometric wallpaper, kept behind all launched applications.
	for index: int in range(4):
		var stripe: ColorRect = ColorRect.new()
		stripe.color = Color("263f50")
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stripe.anchor_left = 0.58 + index * 0.08
		stripe.anchor_right = stripe.anchor_left + 0.015
		stripe.anchor_top = 0.0
		stripe.anchor_bottom = 1.0
		_desktop_home.add_child(stripe)
	var launchers: Array = [
		["review", "REVIEW", "review"],
		["rules", "HANDBOOK", "handbook"],
		["chat", "SLOUCH", "slouch"],
		["browser", "INTRANET", "browser"],
		["system", "SYSTEM", "system"],
	]
	for index: int in range(launchers.size()):
		var item: Array = launchers[index]
		var id: String = str(item[0])
		var launcher: Button = _button(_desktop_home, "", _open_app.bind(id))
		launcher.position = Vector2(22, 18 + index * 104)
		launcher.size = Vector2(112, 94)
		launcher.tooltip_text = "Open " + str(item[1])
		launcher.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 0))
		launcher.add_theme_stylebox_override("hover", _style(Color("304f65"), Color("65839b"), 1, 0, 0))
		var contents: VBoxContainer = _column(launcher, 3)
		contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var icon: TextureRect = TextureRect.new()
		icon.texture = load("res://art/desktop-%s.svg" % str(item[2])) as Texture2D
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		contents.add_child(icon)
		var label: Label = _label(contents, str(item[1]), 13, TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		launcher.set_meta("caption", label)
		_home_icons[id] = launcher
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(73, 0)
		badge.custom_minimum_size = Vector2(26, 26)
		var badge_style := _style(Color("d44e57"), Color("ed8e94"), 1, 5, 1)
		badge_style.set_corner_radius_all(14)
		badge.add_theme_stylebox_override("panel", badge_style)
		launcher.add_child(badge)
		var number := _label(badge, "", 14, Color.WHITE)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.set_meta("number", number)
		badge.hide()
		_app_badges[id] = badge


func _layout_home_icons() -> void:
	var rows := maxi(1, int((_desktop.size.y - 26) / 104))
	var index := 0
	for launcher: Button in _home_icons.values():
		launcher.position = Vector2(22 + int(index / rows) * 122, 18 + (index % rows) * 104)
		index += 1


func _new_window(id: String, title: String) -> DesktopWindow:
	var window: DesktopWindow = DesktopWindow.new()
	window.window_id = id
	window.window_title = title
	window.resize_minimum_size = {"review": Vector2(650, 390), "rules": Vector2(340, 320), "chat": Vector2(520, 300)}.get(id, Vector2(420, 280))
	window.activated.connect(_focus_app)
	window.minimized.connect(func(_id: String) -> void: _update_dock())
	window.closed.connect(func(_id: String) -> void: _update_dock())
	_desktop.add_child(window)
	_windows[id] = window
	return window


func _build_review_content(code: VBoxContainer) -> void:
	var title_row: HBoxContainer = _row(code)
	_pr_id = _label(title_row, "PULL REQUEST", 12, CYAN)
	_spacer(title_row)
	_label(title_row, "DIFF / READ ONLY", 11, DIM)
	_pr_title = _paragraph(code, "", 17)
	var packet_scroll: ScrollContainer = ScrollContainer.new()
	_packet_scroll = packet_scroll
	packet_scroll.custom_minimum_size.y = 84
	packet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	packet_scroll.follow_focus = true
	code.add_child(packet_scroll)
	_pr_context = _paragraph(packet_scroll, "", 13, DIM)
	_file_label = _paragraph(code, "", 12, CYAN)
	_file_label.hide()
	_file_picker = OptionButton.new()
	_file_picker.fit_to_longest_item = false
	_file_picker.disabled = true
	_file_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_picker.add_theme_font_size_override("font_size", 12)
	_file_picker.item_selected.connect(_select_file)
	code.add_child(_file_picker)
	_diff = CodeEdit.new()
	_diff.name = "PullRequestDiff"
	_diff.editable = false
	_diff.gutters_draw_line_numbers = true
	_diff.gutters_line_numbers_min_digits = 2
	_diff.syntax_highlighter = DiffHighlighter.new()
	_diff.add_theme_font_size_override("font_size", 14)
	_diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diff.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_diff.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_diff.custom_minimum_size.y = 130
	code.add_child(_diff)


func _remember_file_position() -> void:
	if not _displayed_file_key.is_empty():
		_file_positions[_displayed_file_key] = {"line": _diff.get_caret_line(), "column": _diff.get_caret_column(), "vertical": _diff.scroll_vertical, "horizontal": _diff.scroll_horizontal}


func _set_review_files(request: Dictionary) -> void:
	_remember_file_position()
	_displayed_file_key = ""
	_review_files = request.get("files", [{"path": str(request.get("file", "")), "diff": str(request.get("diff", ""))}]).duplicate(true) if not request.is_empty() else []
	_file_picker.clear()
	for entry: Dictionary in _review_files:
		_file_picker.add_item(str(entry.get("path", "")))
	_file_picker.disabled = _review_files.is_empty()
	if _review_files.is_empty():
		_diff.text = ""
		return
	var selected: int = clampi(int(_selected_files.get(_last_pr, 0)), 0, _review_files.size() - 1)
	_file_picker.select(selected)
	_select_file(selected)


func _select_file(index: int) -> void:
	if index < 0 or index >= _review_files.size():
		return
	_remember_file_position()
	_file_picker.select(index)
	_selected_files[_last_pr] = index
	var entry: Dictionary = _review_files[index]
	var path: String = str(entry.get("path", ""))
	_displayed_file_key = _last_pr + "/" + path
	_file_label.text = path
	_file_picker.tooltip_text = "Changed file: " + path + " — review all files before signing off."
	_diff.text = str(entry.get("diff", ""))
	_diff.set_caret_line(0)
	_diff.set_caret_column(0)
	_diff.scroll_vertical = 0
	_diff.scroll_horizontal = 0
	_restore_file_position.call_deferred(_displayed_file_key)
	tutorial_event.emit({"type": "inspect-file", "path": path})


func _restore_file_position(key: String) -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if key != _displayed_file_key:
		return
	var previous: Dictionary = _file_positions.get(key, {})
	_diff.set_caret_line(int(previous.get("line", 0)))
	_diff.set_caret_column(int(previous.get("column", 0)))
	_diff.scroll_vertical = float(previous.get("vertical", 0.0))
	_diff.scroll_horizontal = int(previous.get("horizontal", 0))


func _build_dock(parent: Node) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("abb3bc"), Color("49535e"), 1, 4, 3))
	parent.add_child(panel)
	var dock: HBoxContainer = _row(panel, 4)
	var home: Button = _button(dock, "HOME", _show_home)
	home.add_theme_font_size_override("font_size", 12)
	home.tooltip_text = "Show the desktop. Open windows remain on the taskbar."
	for item: Array in [["review", "REVIEW"], ["rules", "HANDBOOK"], ["chat", "SLOUCH"], ["browser", "INTRANET"], ["system", "SYSTEM"]]:
		var id: String = str(item[0])
		var button: Button = _button(dock, str(item[1]), _open_app.bind(id))
		button.toggle_mode = true
		button.visible = false
		button.add_theme_font_size_override("font_size", 12)
		_dock_buttons[id] = button
	_spacer(dock)


func _show_home() -> void:
	for window: DesktopWindow in _windows.values():
		if window.visible:
			window.minimize_window()
	_update_dock()


func _arrange_windows() -> void:
	if not is_instance_valid(_desktop) or _windows.is_empty():
		return
	var extent: Vector2 = _desktop.size
	var layouts: Dictionary = {
		"review": Rect2(Vector2(150, 24), Vector2(minf(900, extent.x - 170), minf(620, extent.y - 48))),
		"rules": Rect2(Vector2(extent.x - 405, 42), Vector2(370, minf(570, extent.y - 70))),
		"chat": Rect2(Vector2(160, 55), Vector2(minf(760, extent.x - 190), minf(520, extent.y - 82))),
		"system": Rect2(Vector2(210, 90), Vector2(minf(650, extent.x - 240), minf(470, extent.y - 118))),
		"browser": Rect2(Vector2(185, 70), Vector2(minf(720, extent.x - 215), minf(500, extent.y - 98))),
	}
	for id: String in _windows:
		var window: DesktopWindow = _windows[id]
		if window.maximized:
			continue
		var layout: Rect2 = layouts[id]
		window.position = layout.position
		window.size = layout.size
		window.clamp_to_desktop()


func _open_app(id: String) -> void:
	if id == "decision":
		id = "review"
	var phase: String = str(_state.get("phase", "review"))
	if id == "review" and phase != "review":
		_chat_contact = "manager"
		id = "chat"
	if id == "chat":
		_open_chat_conversation()
	var window: DesktopWindow = _windows[id]
	window.restore_window()
	_mark_app_read(id)
	_update_dock()
	var event_type: String = {"chat": "open-chat", "review": "open-review", "rules": "open-handbook"}.get(id, "")
	if not event_type.is_empty(): tutorial_event.emit({"type": event_type})
	if id == "review" and not _review_files.is_empty():
		tutorial_event.emit({"type": "inspect-file", "path": _file_label.text})


func _focus_app(id: String) -> void:
	for other_id: String in _windows:
		var window: DesktopWindow = _windows[other_id]
		window.set_active(other_id == id)
	_mark_app_read(id)
	_update_dock()


func _update_dock() -> void:
	for id: String in _dock_buttons:
		var button: Button = _dock_buttons[id]
		var window: DesktopWindow = _windows[id]
		button.visible = window.launched
		button.set_pressed_no_signal(window.visible)
		button.tooltip_text = ("Focus " if window.visible else "Reopen ") + window.window_title


func _build_browser(page: VBoxContainer) -> void:
	var navigation: HBoxContainer = _row(page, 5)
	_browser_back = _button(navigation, "<", _browser_go_back)
	_browser_back.tooltip_text = "Previous intranet page"
	_browser_address = LineEdit.new()
	_browser_address.editable = false
	_browser_address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser_address.add_theme_font_size_override("font_size", 13)
	navigation.add_child(_browser_address)
	_button(navigation, "HOME", _browse.bind("home"))
	var links: HBoxContainer = _row(page)
	_button(links, "PROCEDURE", _browse.bind("procedure"))
	_button(links, "DAILY MEMO", _browse.bind("memo"))
	_button(links, "STANDARDS", _open_app.bind("rules"))
	_button(links, "SLOUCH", _open_app.bind("chat"))
	var content: VBoxContainer = _scroll_column(page)
	_browser_text = _paragraph(content, "", 15)
	_browse("home")


func _browse(path: String, record: bool = true) -> void:
	if record and _browser_path != path:
		_browser_history.append(_browser_path)
	_browser_path = path
	_browser_address.text = "intranet://engineering/" + path
	_browser_back.disabled = _browser_history.is_empty()
	match path:
		"procedure":
			_browser_text.text = "REVIEW PROCEDURE\n\nRead the author packet and changed code. Use the standards index to identify every applicable violation.\nApprove clean work with no citations. Request changes with precise citations.\nYour colleagues react to your decisions. Later, your manager checks in about bugs, delays, and the release.\nHelios recommendations are optional and can be wrong."
		"memo":
			_browser_text.text = "DAILY OPERATIONS MEMO\n\n" + Catalog.briefing(int(_state.get("day", 1)))
		_:
			_browser_text.text = "ENGINEERING INTRANET\nLOCAL TERMINAL / INTERNAL ACCESS\n\nWorkstation online.\n\nOpen STANDARDS to consult the active rulebook, SLOUCH to read messages from your coworkers, or DAILY MEMO for the current instructions.\n\nExternal access restricted by company policy."


func _browser_go_back() -> void:
	if not _browser_history.is_empty():
		var previous: String = _browser_history.pop_back()
		_browse(previous, false)


func _build_rulebook(parent: Node) -> void:
	var column: VBoxContainer = _column(parent)
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.size_flags_stretch_ratio = 1.05
	column.custom_minimum_size.x = 300
	_label(column, "ENGINEERING RULEBOOK", 13, CYAN)
	_search = LineEdit.new()
	_search.placeholder_text = "Search ID, title, or text"
	_search.clear_button_enabled = true
	_search.custom_minimum_size.y = 35
	_search.text_changed.connect(func(_text: String) -> void: _filter_rules())
	column.add_child(_search)
	_category = OptionButton.new()
	_category.add_item("All categories")
	_category.custom_minimum_size.y = 34
	_category.item_selected.connect(func(_index: int) -> void: _filter_rules())
	column.add_child(_category)
	_rule_count = _paragraph(column, "", 12, DIM)
	var rules_body: VBoxContainer = _scroll_column(column)
	var categories: Array[String] = []
	var all_rules: Array = Catalog.rules()
	for rule: Dictionary in all_rules:
		var category: String = str(rule.get("category", "General"))
		if not categories.has(category):
			categories.append(category)
			_category.add_item(category)
		var panel: PanelContainer = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(INSET, BORDER, 1, 0, 0))
		rules_body.add_child(panel)
		var body: VBoxContainer = _column(_margin(panel, 8, 8), 5)
		var check: CheckBox = CheckBox.new()
		check.text = str(rule.get("id", "")) + "  / CITE"
		check.add_theme_font_size_override("font_size", 13)
		var id: String = str(rule.get("id", ""))
		check.toggled.connect(func(_pressed: bool) -> void: _emit_command({"type": "toggle-rule", "rule_id": id}))
		body.add_child(check)
		_paragraph(body, str(rule.get("title", "")), 14, TEXT)
		_paragraph(body, str(rule.get("text", "")), 13, DIM)
		_rule_rows.append({"rule": rule, "panel": panel, "check": check})


func _build_decision(parent: Node) -> void:
	var holder: VBoxContainer = _column(parent)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.size_flags_stretch_ratio = 0.9
	holder.custom_minimum_size.x = 240
	_label(holder, "REVIEW DISPOSITION", 13, CYAN)
	var column: VBoxContainer = _scroll_column(holder)
	_paragraph(column, "Review every changed file. Approve the whole PR, or cite every violated rule.", 13, DIM)
	_selected_label = _paragraph(column, "CITATIONS: NONE", 13)
	_clear_button = _button(column, "CLEAR CITATIONS", _clear_citations)
	_approve = _button(column, "APPROVE", _emit_command.bind({"type": "review", "verdict": "approve"}))
	_approve.add_theme_color_override("font_color", GREEN)
	_reject = _button(column, "REQUEST CHANGES", _emit_command.bind({"type": "review", "verdict": "request_changes"}))
	_reject.add_theme_color_override("font_color", RED)
	_consult = _button(column, "CONSULT AI", _emit_command.bind({"type": "consult-ai"}))
	_consult.tooltip_text = "Ask Helios for a recommendation. It can lighten your workload, but invites the assistant further into the process. Advice can be wrong."
	_ai_note = _paragraph(column, "Helios can take a look. Its advice may be wrong, and using it gives the assistant more influence.", 13, DIM)
	_label(column, "SENT", 12, DIM)
	_feedback = _paragraph(column, "No review sent yet.", 13, DIM)


func _build_chat(page: VBoxContainer) -> void:
	var header: HBoxContainer = _row(page)
	_label(header, "SLOUCH", 16, CYAN)
	_spacer(header)
	_label(header, "COMPANY WORKSPACE", 11, DIM)
	var columns: HBoxContainer = _row(page, 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sidebar: VBoxContainer = _column(columns, 6)
	sidebar.size_flags_horizontal = Control.SIZE_FILL
	sidebar.custom_minimum_size.x = 155
	_label(sidebar, "CHANNELS", 11, DIM)
	for contact: String in ["company", "Maya", "Theo", "Inez", "manager"]:
		if contact == "Maya":
			_label(sidebar, "DIRECT MESSAGES", 11, DIM)
		var button: Button = _button(sidebar, "#engineering" if contact == "company" else "Morgan" if contact == "manager" else contact, _select_chat_contact.bind(contact))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 13)
		_chat_contacts[contact] = button
		_chat_unread[contact] = 0
	var conversation: VBoxContainer = _column(columns, 8)
	conversation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_heading = _label(conversation, "#engineering", 16, TEXT)
	_chat_scroll = ScrollContainer.new()
	# Hidden message rows must not propagate their pre-wrap width into the window.
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversation.add_child(_chat_scroll)
	_chat_messages = _column(_chat_scroll, 10)
	_chat_replies = _column(conversation, 4)
	_chat_replies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_evening_buttons = _row(conversation, 5)
	for item: Array in [["rest", "GO HOME"], ["socialize", "GET DINNER"], ["study", "STUDY"]]:
		var button := _button(_evening_buttons, str(item[1]), _emit_command.bind({"type": "next-day", "choice": str(item[0])}))
		button.add_theme_font_size_override("font_size", 11)
	_complete_button = _button(conversation, "RETURN TO MAIN MENU", func() -> void: menu_requested.emit())
	_evening_buttons.hide()
	_complete_button.hide()


func _select_chat_contact(contact: String) -> void:
	_chat_contact = contact
	_render_phase(_state)
	_chat_unread[contact] = 0
	if is_instance_valid(_notifications): _notifications.clear_app("chat", contact)
	_draw_chat(true)
	_update_chat_badges()


func _open_chat_conversation() -> void:
	_select_chat_contact(_chat_contact)


func _track_chat_replies() -> void:
	for reply: Dictionary in _state.get("chat_replies", []):
		var key := str(reply.contact) + "|" + str(reply.pr_id) + "|" + str(reply.reply_id)
		if not _known_replies.has(key):
			_known_replies[key] = true
			if _reply_history_initialized:
				_pending_replies[key] = {"contact": str(reply.contact), "remaining": 2.4}
	_reply_history_initialized = true


func _visible_chat_messages(contact: String) -> Array:
	var result: Array = []
	for message: Dictionary in Chat.messages(_state, contact):
		if not _pending_replies.has(str(message.get("reply_key", ""))): result.append(message)
	return result


func _waiting_for_reply(contact: String) -> bool:
	for pending: Dictionary in _pending_replies.values():
		if pending.contact == contact: return true
	return false


func _process(delta: float) -> void:
	_tick_chat_replies(delta)


func _tick_chat_replies(delta: float) -> void:
	if _paused or not is_visible_in_tree(): return
	var delivered := false
	for key: String in _pending_replies.keys():
		_pending_replies[key].remaining -= maxf(0, delta)
		if _pending_replies[key].remaining <= 0:
			_pending_replies.erase(key)
			delivered = true
	if delivered: _render_chat()


func _render_chat() -> void:
	var first_render := _chat_seen.is_empty()
	for contact: String in _chat_contacts:
		var messages: Array = _visible_chat_messages(contact)
		var seen: Dictionary = _chat_seen.get(contact, {})
		var incoming: Array = []
		for message: Dictionary in messages:
			if message.author == "You": continue
			var key := str(message.id)
			if not seen.has(key):
				seen[key] = true
				incoming.append(message)
		_chat_seen[contact] = seen
		var reading := _app_is_reading("chat") and contact == _chat_contact
		if reading:
			_chat_unread[contact] = 0
		else:
			_chat_unread[contact] = int(_chat_unread.get(contact, 0)) + incoming.size()
			if not first_render and not incoming.is_empty():
				var sender := "#engineering" if contact == "company" else "Morgan" if contact == "manager" else contact
				_notifications.push("chat", sender + ": " + str(incoming[-1].text), contact)
	if _windows["chat"].visible: _draw_chat()
	_update_chat_badges()
	if first_render and int(_app_counts.chat) > 0:
		_notifications.push("chat", "Your team has left you messages.", _chat_contact)


func _update_chat_badges() -> void:
	var total := 0
	for contact: String in _chat_contacts:
		var unread := int(_chat_unread.get(contact, 0))
		total += unread
		var button: Button = _chat_contacts[contact]
		button.text = ("#engineering" if contact == "company" else "Morgan" if contact == "manager" else contact) + ("  %d" % unread if unread > 0 else "")
		button.set_pressed_no_signal(contact == _chat_contact)
	_app_counts.chat = total
	_update_app_badges()


func _draw_chat(contact_changed: bool = false) -> void:
	var messages: Array = _visible_chat_messages(_chat_contact)
	var waiting := _waiting_for_reply(_chat_contact)
	var options: Array = [] if waiting else Chat.reply_options(_state, _chat_contact)
	var reply_targets: Array[String] = []
	for option: Dictionary in options:
		if str(option.pr_id) not in reply_targets:
			reply_targets.append(str(option.pr_id))
	if _chat_reply_pr not in reply_targets:
		_chat_reply_pr = "" if reply_targets.is_empty() else reply_targets[0]
	var key: String = _chat_contact + JSON.stringify(messages) + JSON.stringify(options) + _chat_reply_pr + str(waiting) + str(_state.get("phase", ""))
	if key == _chat_last_draw and not contact_changed:
		return
	_chat_last_draw = key
	_chat_heading.text = "#engineering" if _chat_contact == "company" else ("Morgan / Engineering Manager" if _chat_contact == "manager" else _chat_contact + " / direct message")
	var bar: VScrollBar = _chat_scroll.get_v_scroll_bar()
	var follow_latest: bool = contact_changed or bar.value >= bar.max_value - bar.page - 12
	var previous_position: int = _chat_scroll.scroll_vertical
	for child: Node in _chat_messages.get_children():
		_chat_messages.remove_child(child)
		child.queue_free()
	for message: Dictionary in messages:
		var outgoing: bool = str(message.author) == "You"
		var row := _row(_chat_messages, 0)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gap.size_flags_stretch_ratio = 0.18
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if outgoing: row.add_child(gap)
		var panel := PanelContainer.new()
		panel.set_meta("outgoing", outgoing)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio = 0.82
		var bubble_style := _style(Color("263e55") if outgoing else INSET, Color("54738e") if outgoing else BORDER, 1, 0, 0)
		bubble_style.set_corner_radius_all(7)
		panel.add_theme_stylebox_override("panel", bubble_style)
		row.add_child(panel)
		if not outgoing: row.add_child(gap)
		var body: VBoxContainer = _column(_margin(panel, 10, 8), 5)
		var heading := _row(body, 8)
		var author := _label(heading, str(message.get("author", "")), 12, Color("b6cfe5") if outgoing else CYAN)
		author.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label(heading, Chat.timestamp(message), 10, DIM)
		_paragraph(body, str(message.get("text", "")), 14, TEXT)
		if message.has("pr_id"):
			var pr_id: String = str(message.pr_id)
			var link := _button(body, "OPEN " + pr_id + "  →", _open_pr_link.bind(pr_id))
			link.alignment = HORIZONTAL_ALIGNMENT_LEFT
			link.add_theme_font_size_override("font_size", 12)
			link.add_theme_color_override("font_color", CYAN)
	if messages.is_empty():
		_paragraph(_chat_messages, "No messages in this conversation yet.", 14, DIM)
	for child: Node in _chat_replies.get_children():
		_chat_replies.remove_child(child)
		child.queue_free()
	if waiting:
		_paragraph(_chat_replies, _chat_contact + " is typing…", 13, CYAN)
	elif not options.is_empty():
		var reply_header := _row(_chat_replies, 8)
		_label(reply_header, "ASK ABOUT", 10, DIM)
		var target := OptionButton.new()
		target.add_theme_font_size_override("font_size", 11)
		for pr_id: String in reply_targets:
			target.add_item(pr_id)
		target.select(reply_targets.find(_chat_reply_pr))
		target.item_selected.connect(func(index: int) -> void:
			_chat_reply_pr = reply_targets[index]
			_draw_chat())
		reply_header.add_child(target)
	for option: Dictionary in options:
		if str(option.pr_id) != _chat_reply_pr:
			continue
		var reply := _button(_chat_replies, str(option.text), _emit_command.bind({"type": "chat-reply", "contact": _chat_contact, "reply_id": str(option.id), "pr_id": str(option.pr_id)}))
		reply.alignment = HORIZONTAL_ALIGNMENT_LEFT
		reply.add_theme_font_size_override("font_size", 12)
		reply.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		reply.tooltip_text = str(option.text)
	_set_chat_scroll.call_deferred(follow_latest, previous_position, key)


func _open_pr_link(pr_id: String) -> void:
	for request: Dictionary in Simulation.available_requests(_state):
		if str(request.id) == pr_id:
			_emit_command({"type": "select-request", "pr_id": pr_id})
			_open_app("review")
			return
	notify("This review is closed. Its conversation remains in SLOUCH.")


func _set_chat_scroll(follow_latest: bool, previous_position: int, draw_key: String) -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if draw_key != _chat_last_draw:
		return
	if follow_latest:
		_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)
	else:
		_chat_scroll.scroll_vertical = previous_position


func _build_system(page: VBoxContainer) -> void:
	var content: VBoxContainer = _scroll_column(page)
	_label(content, "LOCAL RECORD", 16, CYAN)
	_system_status = _paragraph(content, "Local storage is ready.", 14, CYAN)
	_paragraph(content, "One local save slot. Each shift lasts six real minutes, from 09:00 to 18:00. Reading code and Slouch messages uses time. Pause with Esc or the desktop clock control. Switching away pauses automatically.", 14, DIM)
	var saves: HBoxContainer = _row(content)
	_button(saves, "SAVE RUN", func() -> void: save_requested.emit())
	_button(saves, "LOAD RUN", func() -> void: load_requested.emit())
	_button(saves, "NEW RUN", func() -> void: _confirmation.popup_centered())
	_button(content, "SAVE AND MAIN MENU", func() -> void: menu_requested.emit())
	_label(content, "REVIEW PROCEDURE", 16, CYAN)
	_paragraph(content, "1. Read the author message and code diff.\n2. Search the current rulebook and cite all applicable violations.\n3. Approve with no citations, or request changes with citations.\n4. Watch Slouch for your coworker’s response and your manager’s follow-up.\n\nPR links arrive in Slouch throughout the day. Ask coworkers for context, then open their links to review. AI advice is optional and fallible. At 18:00, Helios takes unfinished work. Morgan will message you in Slouch. Open that conversation to wrap up the day.", 14, DIM)


func _emit_command(command: Dictionary) -> void:
	command_requested.emit(command)


func _clear_citations() -> void:
	var selected: Array = _state.get("selected_rules", []).duplicate()
	for rule_id: String in selected:
		_emit_command({"type": "toggle-rule", "rule_id": rule_id})


func _filter_rules() -> void:
	if not is_instance_valid(_search):
		return
	var query: String = _search.text.strip_edges().to_lower()
	var category: String = _category.get_item_text(_category.selected)
	var day: int = int(_state.get("day", 1))
	var visible_count: int = 0
	var active_count: int = 0
	var new_count: int = 0
	for entry: Dictionary in _rule_rows:
		var rule: Dictionary = entry["rule"]
		var active: bool = int(rule.get("introduced_day", 1)) <= day
		if active:
			active_count += 1
		if int(rule.get("introduced_day", 1)) == day:
			new_count += 1
		var haystack: String = (str(rule.get("id", "")) + " " + str(rule.get("title", "")) + " " + str(rule.get("text", ""))).to_lower()
		var matches: bool = active and (query.is_empty() or haystack.contains(query)) and (_category.selected == 0 or str(rule.get("category", "")) == category)
		var panel: Control = entry["panel"]
		panel.visible = matches
		if matches:
			visible_count += 1
	_rule_count.text = "%d shown / %d active rules" % [visible_count, active_count]
	if day > 1 and new_count > 0:
		_rule_count.text += "\n%d added this shift" % new_count


func render_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	_track_chat_replies()
	render_clock(state)
	var day: int = int(state.get("day", 1))
	var phase: String = str(state.get("phase", "review"))
	var selected: Array = state.get("selected_rules", [])
	var consulted: bool = bool(state.get("consulted", false))
	var active_request: Dictionary = Simulation.active_request(state)
	var can_review: bool = phase == "review" and not active_request.is_empty()
	var day_names: Array[String] = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
	_hud["day"].text = day_names[(day - 1) % day_names.size()]
	_hud["status"].text = ("HUMAN SIGN-OFF REQUESTED" if can_review else "INCOMING WORK / SLOUCH") if phase == "review" else "SHIFT CLOSED" if phase == "debrief" else "ASSIGNMENT CLOSED"
	if day != _last_day:
		_last_day = day
		var briefing: String = Catalog.briefing(day)
		_briefing_dialog.dialog_text = briefing
		_filter_rules()
		if _browser_path == "memo":
			_browse("memo", false)
	for entry: Dictionary in _rule_rows:
		var rule: Dictionary = entry["rule"]
		var check: CheckBox = entry["check"]
		check.set_pressed_no_signal(selected.has(str(rule.get("id", ""))))
		check.disabled = not can_review
	_selected_label.text = "CITATIONS: " + ("NONE" if selected.is_empty() else ", ".join(selected))
	_clear_button.disabled = selected.is_empty() or not can_review
	_approve.disabled = not selected.is_empty() or not can_review
	_approve.tooltip_text = "Clear citations before approving." if not selected.is_empty() else "Approve this pull request."
	_reject.disabled = selected.is_empty() or not can_review
	_reject.tooltip_text = "Cite at least one rule first." if selected.is_empty() else "Request changes for every cited rule."
	_consult.disabled = consulted or not can_review
	if phase != _last_phase:
		var previous_phase: String = _last_phase
		_last_phase = phase
		if phase != "review" and not previous_phase.is_empty():
			_windows["review"].minimize_window()
		elif phase == "review" and not previous_phase.is_empty():
			_windows["review"].minimize_window()
		_update_dock()
	if phase == "review":
		# Deliberately never read audit-only violations or explanation here.
		var request: Dictionary = active_request
		var request_id: String = str(request.get("id", ""))
		if request.is_empty():
			_last_pr = ""
			_pr_id.text = "REVIEW / NO PR OPEN"
			_pr_title.text = "Check SLOUCH for review requests"
			_pr_context.text = "Coworkers send links as their work is ready. Open a PR from its conversation. The workday clock continues while you read."
			_file_label.text = ""
			if not _review_files.is_empty() or not _diff.text.is_empty():
				_set_review_files({})
		if not request_id.is_empty() and request_id != _last_pr:
			_last_pr = request_id
			_pr_id.text = "%s / AWAITING REVIEW" % request_id
			_pr_title.text = str(request.get("title", ""))
			_pr_context.text = "%s: %s\n\n%s" % [str(request.get("author", "")), str(request.get("message", "")), str(request.get("description", ""))]
			_set_review_files(request)
			_packet_scroll.scroll_vertical = 0
		_ai_note.text = "Helios can take a look. Its advice may be wrong, and using it gives the assistant more influence."
		if consulted:
			_ai_note.text = "AI: %s\n%s" % [str(request.get("ai_verdict", "")).replace("_", " ").to_upper(), str(request.get("ai_note", ""))]
	var feedback: Dictionary = state.get("last_feedback", {})
	_feedback.text = "No review sent yet." if feedback.is_empty() else "%s · %s sent to %s." % [str(feedback.get("pr_id", "")), "Approval" if feedback.get("verdict") == "approve" else "Change request", str(feedback.get("author", ""))]
	_render_phase(state)
	_render_chat()
	_sync_app_events()
	_footer.text = "ORIENTATION" if _tutorial_active else "READY" if phase == "review" else "OFF THE CLOCK"


func _render_phase(state: Dictionary) -> void:
	_evening_buttons.visible = _chat_contact == "manager" and state.get("phase") == "debrief"
	_complete_button.visible = _chat_contact == "manager" and state.get("phase") == "complete"


func notify(message: String, is_error: bool = false, app: String = "system") -> void:
	if app == "system":
		_system_status.text = message
		_system_status.add_theme_color_override("font_color", RED if is_error else CYAN)
	if not _app_is_reading(app): _app_counts[app] = int(_app_counts.get(app, 0)) + 1
	_notifications.push(app, message, "", is_error)
	_update_app_badges()


func _app_is_reading(app: String) -> bool:
	return is_visible_in_tree() and _windows.has(app) and _windows[app].visible and _windows[app]._active and not _paused


func _mark_app_read(app: String) -> void:
	if not is_instance_valid(_notifications): return
	if app == "chat":
		_chat_unread[_chat_contact] = 0
		_notifications.clear_app(app, _chat_contact)
		_update_chat_badges()
	elif app != "review":
		_app_counts[app] = 0
		_notifications.clear_app(app)
	_update_app_badges()


func _update_app_badges() -> void:
	for app: String in _app_counts:
		var count := int(_app_counts[app])
		if _app_badges.has(app):
			var badge: PanelContainer = _app_badges[app]
			badge.visible = count > 0
			var number: Label = badge.get_meta("number")
			number.text = "99+" if count > 99 else str(count)
		if _dock_buttons.has(app):
			_dock_buttons[app].text = str(Notifications.NAMES[app]) + (" (%d)" % count if count > 0 else "")


func _sync_app_events() -> void:
	var day := int(_state.get("day", 1))
	if day != _notification_day:
		_notification_day = day
		var added := 0
		for rule: Dictionary in Catalog.rules():
			if int(rule.introduced_day) == day: added += 1
		if added > 0 and not _app_is_reading("rules"):
			_app_counts.rules += added
			_notifications.push("rules", "New review standards are available. Read the handbook before signing off.")
		if not _app_is_reading("browser"):
			_app_counts.browser += 1
			_notifications.push("browser", "A new daily memo is on the intranet.", "memo")
	var pending: Dictionary = {}
	for request: Dictionary in Simulation.available_requests(_state):
		var id := str(request.id)
		pending[id] = true
		if not _known_requests.has(id):
			_known_requests[id] = true
			_unread_requests[id] = true
			_notifications.push("review", "%s from %s: %s" % [id, request.author, request.title], id)
	for id: String in _unread_requests.keys():
		if not pending.has(id) or str(_state.get("active_request_id", "")) == id:
			_unread_requests.erase(id)
			_notifications.clear_app("review", id)
	_app_counts.review = _unread_requests.size()
	_update_app_badges()


func _open_notification(app: String, target: String) -> void:
	if _paused: return
	if app == "review" and not target.is_empty():
		_open_pr_link(target)
		return
	if app == "chat" and not target.is_empty(): _select_chat_contact(target)
	if app == "browser" and target == "memo": _browse("memo")
	_open_app(app)


func focus_workspace() -> void:
	# Menu handoff focuses a non-actionable control, so Enter release cannot
	# activate the first button. Later handoffs retain the player's read position.
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	if _workspace_presented:
		return
	_workspace_presented = true
	_diff.set_caret_line(0)
	_diff.set_caret_column(0)
	await get_tree().process_frame
	if not is_inside_tree(): return
	await get_tree().process_frame
	_diff.scroll_vertical = 0
	_diff.scroll_horizontal = 0


func _build_tutorial_panel() -> void:
	_tutorial_panel = PanelContainer.new()
	_tutorial_panel.add_theme_stylebox_override("panel", _style(INSET, CYAN, 1, 12, 10))
	_tutorial_panel.z_index = 40
	_tutorial_panel.hide()
	_monitor_screen.add_child(_tutorial_panel)
	var box := _column(_tutorial_panel, 6)
	var heading := _row(box, 8)
	_tutorial_title = _label(heading, "ORIENTATION", 12, CYAN)
	_spacer(heading)
	var fold := _button(heading, "−", func() -> void:
		_tutorial_body.visible = not _tutorial_body.visible
		_tutorial_next.visible = _tutorial_body.visible and int(_tutorial_details.get("stage", 0)) in [0, 7]
		_fit_tutorial.call_deferred())
	fold.custom_minimum_size = Vector2(26, 24)
	fold.tooltip_text = "Collapse or expand orientation instructions"
	_tutorial_body = _paragraph(box, "", 13, TEXT)
	_tutorial_body.minimum_size_changed.connect(func() -> void: _fit_tutorial.call_deferred())
	visibility_changed.connect(func() -> void:
		if visible: _fit_tutorial.call_deferred())
	_tutorial_next = _button(box, "START ORIENTATION", func() -> void: tutorial_continue_requested.emit())


func render_tutorial(progress: Dictionary, prompt: Dictionary) -> void:
	var step_changed: bool = _tutorial_details.get("stage", -1) != progress.get("stage", -1)
	_tutorial_active = not progress.is_empty()
	_tutorial_details = progress.duplicate(true)
	_tutorial_panel.visible = _tutorial_active
	if not _tutorial_active: return
	_tutorial_title.text = str(prompt.title)
	_tutorial_body.text = str(prompt.body)
	if step_changed: _tutorial_body.show()
	_tutorial_next.visible = _tutorial_body.visible and int(progress.stage) in [0, 7]
	_tutorial_next.text = "START MONDAY" if int(progress.stage) == 7 else "START ORIENTATION"
	_tutorial_panel.position = Vector2(maxf(0, _monitor_screen.size.x - 450), 48)
	_tutorial_panel.size.x = 430
	_fit_tutorial.call_deferred()
	_clock_label.text = "TRAINING"
	_hud["day"].text = "ORIENTATION"
	_footer.text = "CLOCK STOPPED"


func _fit_tutorial() -> void:
	if not is_inside_tree(): return
	await get_tree().process_frame
	if not is_inside_tree(): return
	await get_tree().process_frame
	if is_inside_tree():
		_tutorial_panel.size.y = _tutorial_panel.get_combined_minimum_size().y
