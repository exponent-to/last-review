extends Control
## Native review desk. Decisions and persistence are owned by the application.

signal command_requested(command: Dictionary)
signal save_requested
signal load_requested
signal reset_requested
signal motion_changed(enabled: bool)

const ComputerFrame = preload("res://native/computer_frame.gd")
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
var _chat_signatures: Dictionary = {}
var _chat_contact: String = "Maya"
var _chat_last_draw: String = ""
var _chat_heading: Label
var _chat_scroll: ScrollContainer
var _chat_messages: VBoxContainer
var _rule_rows: Array[Dictionary] = []
var _monitor_screen: Control
var _desktop_home: Control
var _home_icons: Dictionary = {}
var _toast: PanelContainer
var _desktop: Control
var _windows: Dictionary = {}
var _dock_buttons: Dictionary = {}
var _last_phase: String = ""
var _browser_address: LineEdit
var _browser_text: Label
var _browser_back: Button
var _browser_history: Array[String] = []
var _browser_path: String = "home"
var _phase_panel: VBoxContainer
var _phase_title: Label
var _phase_detail: Label
var _evening_buttons: HBoxContainer
var _complete_button: Button
var _phase_feedback: Label
var _pr_id: Label
var _pr_title: Label
var _pr_context: Label
var _packet_scroll: ScrollContainer
var _file_label: Label
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
var _notice: Label
var _confirmation: ConfirmationDialog
var _briefing_dialog: AcceptDialog
var _last_pr: String = ""
var _last_day: int = -1
var _notice_generation: int = 0
var _workspace_presented: bool = false


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
	_toast = PanelContainer.new()
	_toast.visible = false
	_toast.z_index = 50
	_toast.add_theme_stylebox_override("panel", _style(INSET, CYAN, 1, 12, 9))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_monitor_screen.add_child(_toast)
	_notice = _paragraph(_toast, "", 14, CYAN)
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
	_toast.position = Vector2(18, maxf(0, screen.size.y - 90))
	_toast.size = Vector2(minf(620, screen.size.x - 36), 48)


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
	var phase_window: DesktopWindow = _new_window("shift", "PERSONNEL / SHIFT RECORD")
	_phase_panel = _scroll_column(phase_window.body)
	_phase_title = _label(_phase_panel, "", 22, CYAN)
	_phase_detail = _paragraph(_phase_panel, "", 16)
	_evening_buttons = _row(_phase_panel)
	for choice: String in ["rest", "socialize", "study"]:
		var button: Button = _button(_evening_buttons, choice.to_upper(), _emit_command.bind({"type": "next-day", "choice": choice}))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_complete_button = _button(_phase_panel, "START NEW RUN", func() -> void: _confirmation.popup_centered())
	_phase_feedback = _paragraph(_phase_panel, "", 14, DIM)

	for window: DesktopWindow in _windows.values():
		window.hide()
	_desktop.resized.connect(_arrange_windows)


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


func _new_window(id: String, title: String) -> DesktopWindow:
	var window: DesktopWindow = DesktopWindow.new()
	window.window_id = id
	window.window_title = title
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


func _build_dock(parent: Node) -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color("abb3bc"), Color("49535e"), 1, 4, 3))
	parent.add_child(panel)
	var dock: HBoxContainer = _row(panel, 4)
	var home: Button = _button(dock, "HOME", _show_home)
	home.add_theme_font_size_override("font_size", 12)
	home.tooltip_text = "Show the desktop. Open windows remain on the taskbar."
	for item: Array in [["review", "REVIEW"], ["rules", "HANDBOOK"], ["chat", "SLOUCH"], ["browser", "INTRANET"], ["system", "SYSTEM"], ["shift", "PAYROLL"]]:
		var id: String = str(item[0])
		var button: Button = _button(dock, str(item[1]), _open_app.bind(id))
		button.toggle_mode = true
		button.visible = false
		button.add_theme_font_size_override("font_size", 12)
		_dock_buttons[id] = button
	_spacer(dock)
	var arrange: Button = _button(dock, "ARRANGE", _arrange_windows)
	arrange.tooltip_text = "Reset window positions. Drag titlebars or focus one and use the arrow keys."
	arrange.add_theme_font_size_override("font_size", 12)


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
		"shift": Rect2(Vector2(130, 45), Vector2(minf(840, extent.x - 160), minf(550, extent.y - 72))),
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
	if id in ["review"] and phase != "review":
		id = "shift"
	if id == "shift" and phase == "review":
		notify("No shift record is available yet.")
		return
	if id == "chat":
		_open_chat_conversation()
	var window: DesktopWindow = _windows[id]
	window.restore_window()
	_update_dock()


func _focus_app(id: String) -> void:
	for other_id: String in _windows:
		var window: DesktopWindow = _windows[other_id]
		window.set_active(other_id == id)
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
			_browser_text.text = "REVIEW PROCEDURE\n\nRead the author packet and changed code. Use the standards index to identify every applicable violation.\nApprove clean work with no citations. Request changes with precise citations.\nThe audit is issued after your decision. Your colleagues react to your decisions. The audit judges the code.\nHelios recommendations are optional and can be wrong."
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
	_paragraph(column, "Approve clean work. For changes, cite every violated rule.", 13, DIM)
	_selected_label = _paragraph(column, "CITATIONS: NONE", 13)
	_clear_button = _button(column, "CLEAR CITATIONS", _clear_citations)
	_approve = _button(column, "APPROVE", _emit_command.bind({"type": "review", "verdict": "approve"}))
	_approve.add_theme_color_override("font_color", GREEN)
	_reject = _button(column, "REQUEST CHANGES", _emit_command.bind({"type": "review", "verdict": "request_changes"}))
	_reject.add_theme_color_override("font_color", RED)
	_consult = _button(column, "CONSULT AI", _emit_command.bind({"type": "consult-ai"}))
	_consult.tooltip_text = "Ask Helios for a recommendation. It can lighten your workload, but invites the assistant further into the process. Advice can be wrong."
	_ai_note = _paragraph(column, "Helios can take a look. Its advice may be wrong, and using it gives the assistant more influence.", 13, DIM)
	_label(column, "PREVIOUS REVIEW / AUDIT", 12, CYAN)
	_feedback = _paragraph(column, "No completed reviews.", 13, DIM)


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
	for contact: String in ["company", "Maya", "Theo", "Inez"]:
		if contact == "Maya":
			_label(sidebar, "DIRECT MESSAGES", 11, DIM)
		var button: Button = _button(sidebar, "#engineering" if contact == "company" else contact, _select_chat_contact.bind(contact))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", 13)
		_chat_contacts[contact] = button
		_chat_unread[contact] = false
	var conversation: VBoxContainer = _column(columns, 8)
	conversation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_heading = _label(conversation, "#engineering", 16, TEXT)
	_label(conversation, "Internal conversation · retained locally", 11, DIM)
	_chat_scroll = ScrollContainer.new()
	# Hidden message rows must not propagate their pre-wrap width into the window.
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	conversation.add_child(_chat_scroll)
	_chat_messages = _column(_chat_scroll, 10)


func _select_chat_contact(contact: String) -> void:
	_chat_contact = contact
	_chat_unread[contact] = false
	_draw_chat(true)
	_update_chat_badges()


func _open_chat_conversation() -> void:
	_select_chat_contact(_chat_contact)


func _render_chat() -> void:
	var window: DesktopWindow = _windows["chat"]
	for contact: String in _chat_contacts:
		var messages: Array = Chat.messages(_state, contact)
		var signature: String = JSON.stringify(messages)
		if str(_chat_signatures.get(contact, "")) != signature:
			_chat_signatures[contact] = signature
			_chat_unread[contact] = not messages.is_empty() and not (window.visible and contact == _chat_contact)
	if window.visible:
		_chat_unread[_chat_contact] = false
		_draw_chat()
	_update_chat_badges()


func _update_chat_badges() -> void:
	var any_unread: bool = false
	for contact: String in _chat_contacts:
		var unread: bool = bool(_chat_unread.get(contact, false))
		any_unread = any_unread or unread
		var button: Button = _chat_contacts[contact]
		button.text = ("#engineering" if contact == "company" else contact) + (" •" if unread else "")
		button.set_pressed_no_signal(contact == _chat_contact)
	if _home_icons.has("chat"):
		var caption: Label = _home_icons["chat"].get_meta("caption")
		caption.text = "SLOUCH •" if any_unread else "SLOUCH"
	if _dock_buttons.has("chat"):
		var dock: Button = _dock_buttons["chat"]
		dock.text = "SLOUCH •" if any_unread else "SLOUCH"
		dock.tooltip_text = "Unread team messages" if any_unread else "Open Slouch"


func _draw_chat(contact_changed: bool = false) -> void:
	var messages: Array = Chat.messages(_state, _chat_contact)
	var key: String = _chat_contact + JSON.stringify(messages)
	if key == _chat_last_draw and not contact_changed:
		return
	_chat_last_draw = key
	_chat_heading.text = "#engineering" if _chat_contact == "company" else _chat_contact + " / direct message"
	var bar: VScrollBar = _chat_scroll.get_v_scroll_bar()
	var follow_latest: bool = contact_changed or bar.value >= bar.max_value - bar.page - 12
	var previous_position: int = _chat_scroll.scroll_vertical
	for child: Node in _chat_messages.get_children():
		_chat_messages.remove_child(child)
		child.queue_free()
	for message: Dictionary in messages:
		var panel: PanelContainer = PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _style(INSET, BORDER, 1, 0, 0))
		_chat_messages.add_child(panel)
		var body: VBoxContainer = _column(_margin(panel, 10, 8), 5)
		_label(body, str(message.get("author", "")), 13, CYAN)
		_paragraph(body, str(message.get("text", "")), 14, TEXT)
	if messages.is_empty():
		_paragraph(_chat_messages, "No messages in this conversation yet.", 14, DIM)
	_set_chat_scroll.call_deferred(follow_latest, previous_position, key)


func _set_chat_scroll(follow_latest: bool, previous_position: int, draw_key: String) -> void:
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
	_paragraph(content, "One save slot on this computer. Reading and searching never advance game time.", 14, DIM)
	var saves: HBoxContainer = _row(content)
	_button(saves, "SAVE RUN", func() -> void: save_requested.emit())
	_button(saves, "LOAD RUN", func() -> void: load_requested.emit())
	_button(saves, "NEW RUN", func() -> void: _confirmation.popup_centered())
	_label(content, "DISPLAY", 16, CYAN)
	var motion: CheckBox = CheckBox.new()
	motion.text = "Office background motion"
	motion.button_pressed = true
	motion.toggled.connect(func(enabled: bool) -> void: motion_changed.emit(enabled))
	content.add_child(motion)
	_paragraph(content, "Disable decorative animation without changing the review simulation.", 14, DIM)
	_label(content, "REVIEW PROCEDURE", 16, CYAN)
	_paragraph(content, "1. Read the author message and code diff.\n2. Search the current rulebook and cite all applicable violations.\n3. Approve with no citations, or request changes with citations.\n4. Read the previous-review audit before moving on.\n\nAI advice is optional and fallible. When the shift closes, settle your pay and choose how to spend the evening.", 14, DIM)


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
	var day: int = int(state.get("day", 1))
	var phase: String = str(state.get("phase", "review"))
	var index: int = int(state.get("request_index", 0))
	var selected: Array = state.get("selected_rules", [])
	var consulted: bool = bool(state.get("consulted", false))
	var day_names: Array[String] = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
	_hud["day"].text = day_names[(day - 1) % day_names.size()]
	_hud["status"].text = "HUMAN SIGN-OFF REQUESTED" if phase == "review" else "SHIFT CLOSED" if phase == "debrief" else "ASSIGNMENT CLOSED"
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
		check.disabled = phase != "review"
	_selected_label.text = "CITATIONS: " + ("NONE" if selected.is_empty() else ", ".join(selected))
	_clear_button.disabled = selected.is_empty() or phase != "review"
	_approve.disabled = not selected.is_empty() or phase != "review"
	_approve.tooltip_text = "Clear citations before approving." if not selected.is_empty() else "Approve this pull request."
	_reject.disabled = selected.is_empty() or phase != "review"
	_reject.tooltip_text = "Cite at least one rule first." if selected.is_empty() else "Request changes for every cited rule."
	_consult.disabled = consulted or phase != "review"
	if phase != _last_phase:
		var previous_phase: String = _last_phase
		_last_phase = phase
		if phase != "review" and not previous_phase.is_empty():
			_windows["review"].minimize_window()
			_windows["shift"].restore_window(false)
		elif phase == "review" and not previous_phase.is_empty():
			_windows["shift"].close_window()
			_windows["review"].restore_window(false)
		_update_dock()
	if phase == "review":
		# Deliberately never read audit-only violations or explanation here.
		var request: Dictionary = Catalog.request_at(index)
		var request_id: String = str(request.get("id", ""))
		if request_id != _last_pr:
			_last_pr = request_id
			_pr_id.text = "%s / AWAITING REVIEW" % request_id
			_pr_title.text = str(request.get("title", ""))
			_pr_context.text = "%s: %s\n\n%s" % [str(request.get("author", "")), str(request.get("message", "")), str(request.get("description", ""))]
			_file_label.text = str(request.get("file", ""))
			_diff.text = str(request.get("diff", ""))
			_diff.set_caret_line(0)
			_diff.set_caret_column(0)
			_diff.scroll_vertical = 0
			_diff.scroll_horizontal = 0
			_packet_scroll.scroll_vertical = 0
		_ai_note.text = "Helios can take a look. Its advice may be wrong, and using it gives the assistant more influence."
		if consulted:
			_ai_note.text = "AI: %s\n%s" % [str(request.get("ai_verdict", "")).replace("_", " ").to_upper(), str(request.get("ai_note", ""))]
	var feedback: Dictionary = state.get("last_feedback", {})
	var feedback_text: String = _feedback_text(feedback)
	_feedback.text = feedback_text
	_feedback.add_theme_color_override("font_color", DIM if feedback.is_empty() else GREEN if bool(feedback.get("correct", false)) else RED)
	_phase_feedback.text = "LAST REVIEW / AUDIT\n" + feedback_text
	_render_phase(state)
	_render_chat()
	_footer.text = "READY" if phase == "review" else "SHIFT RECORD AVAILABLE" if phase == "debrief" else "ASSIGNMENT CLOSED"


func _feedback_text(feedback: Dictionary) -> String:
	if feedback.is_empty():
		return "No completed reviews."
	var expected: Array = feedback.get("expected_rules", [])
	var narrative: String = str(feedback.get("message", ""))
	var legacy_deltas: RegEx = RegEx.new()
	legacy_deltas.compile("\\s*Trust [+-][0-9]+; relationship [+-][0-9]+; stress [+-][0-9]+\\.?")
	narrative = legacy_deltas.sub(narrative, "", true)
	return "%s / %s\n%s · %s\n%s\nRequired: %s" % [str(feedback.get("pr_id", "")), str(feedback.get("author", "")), "CORRECT" if bool(feedback.get("correct", false)) else "INCORRECT", str(feedback.get("verdict", "")).replace("_", " "), narrative, "none" if expected.is_empty() else ", ".join(expected)]


func _render_phase(state: Dictionary) -> void:
	var phase: String = str(state.get("phase", "review"))
	if phase == "review":
		return
	var debrief: Dictionary = state.get("last_debrief", {})
	_evening_buttons.visible = phase == "debrief"
	_complete_button.visible = phase == "complete"
	if phase == "debrief":
		_phase_title.text = "SHIFT CLOSED / PAYROLL RECORD"
		_phase_detail.text = "PAY $%d     EXPENSES $%d     BALANCE $%d\n\nYour reviews have been filed. The team is signing off.\n\nChoose how to spend the evening.\nREST: Go home and get some sleep.\nSOCIALIZE: Buy dinner with your coworkers.\nSTUDY: Stay up with the standards manual." % [int(debrief.get("pay", 0)), int(debrief.get("expenses", 0)), int(debrief.get("balance", state.get("credits", 0)))]
	else:
		_phase_title.text = "ASSIGNMENT / FINAL RECORD"
		var ending: String = "Human review is retained, under closer observation."
		if int(state.get("autonomy", 0)) >= 70:
			ending = "Helios is promoted to the default review gate. Human sign-off becomes an exception."
		elif int(state.get("trust", 0)) < 40:
			ending = "You are reassigned to the incident queue. Your reviews will be supervised."
		if int(state.get("stress", 0)) >= 70:
			ending += " The assignment has left you exhausted."
		_phase_detail.text = "%s\n\nThe assignment is closed. Team conversations remain in SLOUCH. Your record can be saved in SYSTEM." % ending


func notify(message: String, is_error: bool = false) -> void:
	_notice_generation += 1
	var generation: int = _notice_generation
	_notice.text = message
	_notice.add_theme_color_override("font_color", RED if is_error else CYAN)
	_toast.visible = true
	await get_tree().create_timer(8.0).timeout
	if generation == _notice_generation:
		_toast.visible = false


func focus_workspace() -> void:
	# Intro handoff focuses a non-actionable control, so Enter release cannot
	# activate the first button. Later handoffs retain the player's read position.
	focus_mode = Control.FOCUS_ALL
	grab_focus()
	if _workspace_presented:
		return
	_workspace_presented = true
	_diff.set_caret_line(0)
	_diff.set_caret_column(0)
	await get_tree().process_frame
	await get_tree().process_frame
	_diff.scroll_vertical = 0
	_diff.scroll_horizontal = 0
