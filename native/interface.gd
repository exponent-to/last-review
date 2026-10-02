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
const TutorialPointer = preload("res://native/tutorial_pointer.gd")
const DailyReader = preload("res://native/daily_reader.gd")
const Catalog = preload("res://content/catalog.gd")
const TerminalFont: FontFile = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
# Night-shift terminal palette: black glass, phosphor green, one alarm red,
# and paper documents for anything a person signs.
const BACK: Color = Color("0a0a0b")
const SURFACE: Color = Color("141416")
const INSET: Color = Color("070708")
const BORDER: Color = Color("2c2c31")
const TEXT: Color = Color("e6e2d6")
const DIM: Color = Color("8c8981")
const CYAN: Color = Color("6fdc8c")
const RED: Color = Color("e5384a")
const GREEN: Color = Color("6fdc8c")
const AMBER: Color = Color("e0b44a")
const PAPER: Color = Color("a9ada4")
const PAPER_INK: Color = Color("121412")
const PAPER_MUTED: Color = Color("3c3f39")
const PAPER_LINE: Color = Color("7a7e75")
const STAMP_GREEN: Color = Color("2f8a4f")
const STAMP_RED: Color = Color("c0202f")
const RULE_SUMMARIES := {
	"P01": "No ‘load-bearing’ in comments.",
	"P02": ".py files: lowercase a in the first 20 lines.",
	"P03": "def / if / else / return must be blue.",
	"P04": "No uppercase A–Z in the filename.",
	"P05": "At most 60 characters per source line.",
	"P06": "Last nonempty line: # approved by a pigeon",
	"P07": "No ! in comments.",
	"P08": "No tab characters anywhere.",
	"P09": "No whole word ‘urgent’ inside quotes.",
}

class PolicyHighlighter extends SyntaxHighlighter:
	var spans: Dictionary = {}
	var ink := Color("72b7ff")
	func configure(source: String, color_name: String) -> void:
		ink = Color("ef94c3") if color_name == "pink" else Color("72b7ff")
		spans.clear()
		for span: Dictionary in load("res://content/policy_campaign.gd").keyword_spans(source):
			if not spans.has(int(span.line)): spans[int(span.line)] = []
			spans[int(span.line)].append(span)
		clear_highlighting_cache()
	func _get_line_syntax_highlighting(line: int) -> Dictionary:
		var result := {0: {"color": Color("e0e8ef")}}
		for span: Dictionary in spans.get(line, []):
			result[int(span.start)] = {"color": ink}
			result[int(span.end)] = {"color": Color("e0e8ef")}
		return result

var scene_host: Control
var _state: Dictionary = {}
var _hud: Dictionary = {}
var _chat_contacts: Dictionary = {}
var _chat_unread: Dictionary = {}
var _chat_seen: Dictionary = {}
var _chat_contact: String = "Maya"
var _chat_last_draw: String = ""
var _chat_heading: Label
var _chat_scroll: ScrollContainer
var _chat_messages: VBoxContainer
var _monitor_screen: Control
var _desktop_home: Control
var _home_icons: Dictionary = {}
var _notifications: Notifications
var _app_counts := {"review": 0, "chat": 0, "browser": 0, "system": 0}
var _app_badges: Dictionary = {}
var _known_requests: Dictionary = {}
var _unread_requests: Dictionary = {}
var _notification_day := -1
var _system_status: Label
var _save_slot_label: Label
var _desktop: Control
var _windows: Dictionary = {}
var _dock_buttons: Dictionary = {}
var _last_phase: String = ""
var _browser_address: LineEdit
var _browser_text: Label
var _browser_plain: ScrollContainer
var _daily_reader: DailyReader
var morning_active := false
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
var _begin_shift_button: Button
var _pause_overlay: ColorRect
var _resume_button: Button
var _paused: bool = false
var _tutorial_panel: PanelContainer
var _tutorial_title: Label
var _tutorial_body: Label
var _tutorial_next: Button
var _tutorial_active := false
var _tutorial_pointer: Control
var _tutorial_pr_link: Button
var _home_button: Button
var _arrival_picker: OptionButton
var _next_pr: Button
var _arrival_ids: Array[String] = []
var _code_legend: Label
var _tutorial_details: Dictionary = {}
var _paper: PanelContainer
var _last_feedback_key := "-"
var _evidence: Dictionary = {}
var _evidence_label: Label
var _flag_box: PanelContainer
var _flag_title: Label
var _flag_buttons: Dictionary = {}
var _citation_list: VBoxContainer
var _standards_link: Button
var _chat_channel_label: Label
var _whole_file: Button


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
	_build_flag_box()
	_notifications = Notifications.new()
	_monitor_screen.add_child(_notifications)
	_notifications.activated.connect(_open_notification)
	_build_pause_overlay()
	_build_crt_overlay()
	_confirmation = ConfirmationDialog.new()
	_confirmation.title = "Start a new run"
	_confirmation.dialog_text = "Save this run and choose a slot for a new game?"
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
	var bar := _style(Color("050506"), Color("050506"), 0, 10, 3)
	bar.border_width_bottom = 1
	bar.border_color = Color("3a1218")
	panel.add_theme_stylebox_override("panel", bar)
	parent.add_child(panel)
	var row: HBoxContainer = _row(panel, 12)
	var prompt := _label(row, "root@northstar:~$", 12, CYAN)
	prompt.tooltip_text = "Workstation N-7. Every keystroke is company property."
	_footer = _label(row, "READY", 11, DIM)
	_spacer(row)
	_hud["day"] = _label(row, "MONDAY", 12, RED)
	_hud["status"] = _footer
	_clock_label = _label(row, "09:00", 15, GREEN)
	_clock_label.custom_minimum_size.x = 50
	_clock_label.tooltip_text = "Shift: 09:00–18:00. %d real minutes. Pause stops the clock." % (Catalog.shift_seconds() / 60)
	_pause_button = _button(row, "PAUSE", func() -> void: pause_requested.emit())
	_pause_button.add_theme_font_size_override("font_size", 11)
	_pause_button.custom_minimum_size.y = 28
	_pause_button.tooltip_text = "Pause the workday (Esc)"
	_begin_shift_button = _button(row, "BEGIN SHIFT →", _finish_morning)
	_begin_shift_button.add_theme_font_size_override("font_size", 13)
	_begin_shift_button.custom_minimum_size.y = 30
	_begin_shift_button.add_theme_stylebox_override("normal", _style(RED, Color("ff6b78"), 1, 14, 4))
	_begin_shift_button.add_theme_stylebox_override("hover", _style(Color("ff4d5e"), Color.WHITE, 1, 14, 4))
	_begin_shift_button.add_theme_stylebox_override("disabled", _style(Color("2a1015"), Color("4a1a21"), 1, 14, 4))
	_begin_shift_button.add_theme_color_override("font_color", Color.WHITE)
	_begin_shift_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_begin_shift_button.add_theme_color_override("font_disabled_color", Color("7a3a42"))
	_begin_shift_button.hide()


func _build_pause_overlay() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.color = BACK
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.z_index = 100
	_pause_overlay.hide()
	_monitor_screen.add_child(_pause_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(center)
	var box := _column(center, 18)
	_label(box, "// SESSION SUSPENDED", 24, RED)
	_paragraph(box, "The clock is stopped. Nobody is watching.\nFor now.", 15, DIM)
	_resume_button = _button(box, "RESUME SHIFT", func() -> void: pause_requested.emit())
	_button(box, "SAVE AND MAIN MENU", func() -> void: menu_requested.emit())


func _build_crt_overlay() -> void:
	# Faint scanlines and a dark vignette sell the glass; they never take input.
	var crt := Control.new()
	crt.name = "CrtOverlay"
	crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt.focus_mode = Control.FOCUS_NONE
	crt.z_index = 110
	crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt.draw.connect(func() -> void:
		for y in range(0, int(crt.size.y), 3):
			crt.draw_rect(Rect2(0, y, crt.size.x, 1), Color(0, 0, 0, 0.13))
		for step in range(10):
			var shade := Color(0, 0, 0, 0.035 * (10 - step))
			crt.draw_rect(Rect2(Vector2(step * 2, step * 2), crt.size - Vector2(step * 4, step * 4)), shade, false, 2.0))
	crt.resized.connect(crt.queue_redraw)
	_monitor_screen.add_child(crt)


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
	_clock_label.add_theme_color_override("font_color", RED if minutes >= 17 * 60 else AMBER if minutes >= 15 * 60 else GREEN)
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
		result.set_color("font_disabled_color", type_name, Color("4f4d49"))
	var focus: StyleBoxFlat = _style(Color.TRANSPARENT, CYAN, 2, 0, 0)
	focus.draw_center = false
	for type_name: String in ["Button", "OptionButton"]:
		result.set_stylebox("normal", type_name, _style(SURFACE, BORDER, 1, 9, 7))
		result.set_stylebox("hover", type_name, _style(Color("1d1f1d"), CYAN, 1, 9, 7))
		result.set_stylebox("pressed", type_name, _style(Color("142a1b"), CYAN, 1, 9, 7))
		result.set_stylebox("disabled", type_name, _style(INSET, Color("1c1c20"), 1, 9, 7))
		result.set_stylebox("focus", type_name, focus)
	var bare := _style(Color.TRANSPARENT, Color.TRANSPARENT, 0, 2, 2)
	for state_name: String in ["normal", "pressed", "disabled", "hover_pressed"]:
		result.set_stylebox(state_name, "CheckBox", bare)
	result.set_stylebox("hover", "CheckBox", _style(Color("1d1f1d"), Color.TRANSPARENT, 0, 2, 2))
	result.set_stylebox("focus", "CheckBox", focus)
	result.set_color("font_pressed_color", "CheckBox", RED)
	result.set_color("font_hover_pressed_color", "CheckBox", RED)
	for type_name: String in ["LineEdit", "TextEdit", "CodeEdit"]:
		result.set_stylebox("normal", type_name, _style(INSET, BORDER, 1, 9, 8))
		result.set_stylebox("read_only", type_name, _style(INSET, BORDER, 1, 9, 8))
		result.set_stylebox("focus", type_name, focus)
		result.set_color("font_readonly_color", type_name, TEXT)
		result.set_color("font_placeholder_color", type_name, DIM)
		result.set_color("caret_color", type_name, CYAN)
		result.set_color("selection_color", type_name, Color("5a1d25"))
	result.set_color("line_number_color", "CodeEdit", Color("4f4d49"))
	result.set_color("current_line_color", "CodeEdit", Color("16181a"))
	result.set_color("background_color", "CodeEdit", INSET)
	# CheckBoxes read as ink boxes on a form: hollow, then a red cross when cited.
	result.set_icon("unchecked", "CheckBox", _check_icon(false))
	result.set_icon("checked", "CheckBox", _check_icon(true))
	result.set_icon("unchecked_disabled", "CheckBox", _check_icon(false, true))
	result.set_icon("checked_disabled", "CheckBox", _check_icon(true, true))
	for scroll_name: String in ["VScrollBar", "HScrollBar"]:
		result.set_stylebox("scroll", scroll_name, _style(INSET, INSET, 0, 4, 4))
		result.set_stylebox("grabber", scroll_name, _style(Color("3a3a40"), Color("3a3a40"), 0, 4, 4))
		result.set_stylebox("grabber_highlight", scroll_name, _style(Color("57575e"), Color("57575e"), 0, 4, 4))
		result.set_stylebox("grabber_pressed", scroll_name, _style(RED, RED, 0, 4, 4))
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


func _check_icon(checked: bool, disabled: bool = false) -> ImageTexture:
	# A 16px pixel box drawn at runtime so form marks stay crisp at any scale.
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var edge := Color("4f4d49") if disabled else DIM
	for i in range(1, 15):
		for j in [1, 14]:
			image.set_pixel(i, j, edge)
			image.set_pixel(j, i, edge)
	if checked:
		var mark := Color("7a2a31") if disabled else RED
		for i in range(4, 12):
			for t in [0, 1]:
				image.set_pixel(i, clampi(i + t - 1, 3, 12), mark)
				image.set_pixel(i, clampi(15 - i + t - 1, 3, 12), mark)
	return ImageTexture.create_from_image(image)


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
	wallpaper.color = BACK
	wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wallpaper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_desktop_home.add_child(wallpaper)
	# A faint surveillance grid and a corporate motto, kept behind every app.
	var grid := Control.new()
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.draw.connect(func() -> void:
		for x in range(0, int(grid.size.x), 48): grid.draw_rect(Rect2(x, 0, 1, grid.size.y), Color("121214"))
		for y in range(0, int(grid.size.y), 48): grid.draw_rect(Rect2(0, y, grid.size.x, 1), Color("121214")))
	grid.resized.connect(grid.queue_redraw)
	_desktop_home.add_child(grid)
	var motto := VBoxContainer.new()
	motto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motto.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	motto.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	motto.grow_vertical = Control.GROW_DIRECTION_BEGIN
	motto.offset_right = -28
	motto.offset_bottom = -22
	motto.add_theme_constant_override("separation", 0)
	_desktop_home.add_child(motto)
	var mark := _label(motto, "NORTHSTAR", 46, Color("1b1b1e"))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var tagline := _label(motto, "we review so you don't have to._", 13, Color("2a2a2e"))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var launchers: Array = [
		["review", "REVIEW", "review"],
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
		launcher.add_theme_stylebox_override("hover", _style(Color("16181a"), Color("3a3a40"), 1, 0, 0))
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
		var label: Label = _label(contents, str(item[1]).to_lower(), 13, TEXT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		launcher.set_meta("caption", label)
		_home_icons[id] = launcher
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(73, 0)
		badge.custom_minimum_size = Vector2(26, 26)
		var badge_style := _style(RED, Color("ff8a95"), 1, 5, 1)
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
	window.resize_minimum_size = {"review": Vector2(650, 390), "chat": Vector2(520, 300)}.get(id, Vector2(420, 280))
	window.activated.connect(_focus_app)
	window.minimized.connect(func(_id: String) -> void: _update_dock())
	window.closed.connect(func(_id: String) -> void: _update_dock())
	_desktop.add_child(window)
	_windows[id] = window
	return window


func _build_review_content(code: VBoxContainer) -> void:
	var incoming := _row(code, 6)
	_arrival_picker = OptionButton.new()
	_arrival_picker.fit_to_longest_item = false
	_arrival_picker.clip_text = true
	_arrival_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_arrival_picker.item_selected.connect(func(index: int) -> void:
		if index > 0 and index <= _arrival_ids.size(): _open_pr_link(_arrival_ids[index - 1]))
	incoming.add_child(_arrival_picker)
	_next_pr = _button(incoming, "NEXT PR →", _open_next_pr)
	_next_pr.add_theme_font_size_override("font_size", 12)
	# The author packet is a paper form on the desk, not another terminal pane.
	_paper = PanelContainer.new()
	var paper_style := _style(PAPER, PAPER_LINE, 1, 14, 10)
	paper_style.border_width_left = 4
	paper_style.border_color = PAPER_LINE
	paper_style.shadow_color = Color(0, 0, 0, 0.55)
	paper_style.shadow_size = 0
	paper_style.shadow_offset = Vector2(3, 3)
	_paper.add_theme_stylebox_override("panel", paper_style)
	code.add_child(_paper)
	var form: VBoxContainer = _column(_paper, 4)
	var title_row: HBoxContainer = _row(form)
	_label(title_row, "NORTHSTAR // INTERNAL // FORM CR-7", 10, PAPER_MUTED)
	_spacer(title_row)
	_pr_id = _label(title_row, "PULL REQUEST", 11, STAMP_RED)
	var rule := ColorRect.new()
	rule.color = PAPER_LINE
	rule.custom_minimum_size.y = 1
	form.add_child(rule)
	_pr_title = _paragraph(form, "", 17, PAPER_INK)
	var packet_scroll: ScrollContainer = ScrollContainer.new()
	_packet_scroll = packet_scroll
	packet_scroll.custom_minimum_size.y = 70
	packet_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	packet_scroll.follow_focus = true
	form.add_child(packet_scroll)
	_pr_context = _paragraph(packet_scroll, "", 13, PAPER_MUTED)
	var file_row := _row(code, 8)
	_label(file_row, "$ cat", 12, DIM)
	_file_label = _paragraph(code, "", 12, CYAN)
	_file_label.hide()
	_file_picker = OptionButton.new()
	_file_picker.fit_to_longest_item = false
	_file_picker.clip_text = true
	_file_picker.disabled = true
	_file_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_file_picker.add_theme_font_size_override("font_size", 12)
	_file_picker.item_selected.connect(_select_file)
	file_row.add_child(_file_picker)
	_code_legend = _paragraph(code, "", 11, AMBER)
	_code_legend.hide()
	# Inspect: point at the evidence first, then tick the rule it breaks.
	var pointer_row := _row(code, 8)
	_evidence_label = _paragraph(pointer_row, "", 12, DIM)
	_whole_file = _button(pointer_row, "WHOLE FILE", func() -> void: _point_at(0))
	_whole_file.custom_minimum_size.y = 26
	_whole_file.add_theme_font_size_override("font_size", 11)
	_whole_file.tooltip_text = "Point at this entire file, for rules about its filename, ink, opening lines, or quoted labels."
	_diff = CodeEdit.new()
	_diff.name = "PullRequestDiff"
	_diff.editable = false
	_diff.gutters_draw_line_numbers = true
	_diff.gutters_line_numbers_min_digits = 2
	_diff.syntax_highlighter = PolicyHighlighter.new()
	_diff.add_theme_font_size_override("font_size", 14)
	_diff.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_diff.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_diff.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_diff.custom_minimum_size.y = 130
	code.add_child(_diff)
	_diff.caret_changed.connect(_update_code_legend)
	_diff.gui_input.connect(func(event: InputEvent) -> void:
		var clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed
		var keyed: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_KP_ENTER]
		if clicked or keyed: _point_at.call_deferred(-1))


func _remember_file_position() -> void:
	if not _displayed_file_key.is_empty():
		_file_positions[_displayed_file_key] = {"line": _diff.get_caret_line(), "column": _diff.get_caret_column(), "vertical": _diff.scroll_vertical, "horizontal": _diff.scroll_horizontal}


func _set_review_files(request: Dictionary) -> void:
	_remember_file_position()
	_displayed_file_key = ""
	_review_files = request.get("files", []).duplicate(true) if not request.is_empty() else []
	_file_picker.clear()
	for entry: Dictionary in _review_files:
		_file_picker.add_item(str(entry.get("path", "")))
	_file_picker.disabled = _review_files.is_empty()
	if _review_files.is_empty():
		_diff.text = ""
		_code_legend.hide()
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
	# Colorblind fallback: the ink name stays available on hover, off the main view.
	_file_picker.tooltip_text = "Changed file: " + path + " — review all files before signing off.\nKeyword ink: " + str(entry.get("keyword_ink", "blue"))
	var highlighter := PolicyHighlighter.new()
	highlighter.configure(str(entry.source), str(entry.get("keyword_ink", "blue")))
	_diff.syntax_highlighter = highlighter
	_diff.text = str(entry.source)
	_evidence = {}
	if is_instance_valid(_flag_box): _flag_box.hide()
	_diff.draw_tabs = true
	_update_code_legend()
	_paint_evidence()
	_diff.set_caret_line(0)
	_diff.set_caret_column(0)
	_diff.scroll_vertical = 0
	_diff.scroll_horizontal = 0
	_restore_file_position.call_deferred(_displayed_file_key)
	tutorial_event.emit({"type": "inspect-file", "path": path})


func _update_code_legend() -> void:
	var index := _file_picker.selected
	if index < 0 or index >= _review_files.size() or not _review_files[index].has("source"): return
	var entry: Dictionary = _review_files[index]
	# Keyword colors speak for themselves; only permits and line lengths need a readout.
	var notes: Array[String] = []
	if int(_state.get("day", 1)) >= 4: notes.append("Permit: " + str(entry.get("permit", "none")))
	if int(_state.get("day", 1)) >= 2:
		notes.append("Line %d · %d characters (click a line to measure)" % [_diff.get_caret_line() + 1, _diff.get_line(_diff.get_caret_line()).length()])
	_code_legend.text = "\n".join(notes)
	_code_legend.visible = not notes.is_empty()


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
	var taskbar := _style(Color("050506"), Color("050506"), 0, 4, 3)
	taskbar.border_width_top = 1
	taskbar.border_color = Color("2c2c31")
	panel.add_theme_stylebox_override("panel", taskbar)
	parent.add_child(panel)
	var dock: HBoxContainer = _row(panel, 4)
	var home: Button = _button(dock, "HOME", _show_home)
	_home_button = home
	home.add_theme_font_size_override("font_size", 12)
	home.tooltip_text = "Show the desktop. Open windows remain on the taskbar."
	for item: Array in [["review", "REVIEW"], ["chat", "SLOUCH"], ["browser", "INTRANET"], ["system", "SYSTEM"]]:
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
		"review": Rect2(Vector2(142, 8), Vector2(extent.x - 150, extent.y - 16)),
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
	var event_type: String = {"chat": "open-chat", "review": "open-review"}.get(id, "")
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
	_button(links, "NEWS", _browse.bind("news"))
	_button(links, "PROCEDURE", _browse.bind("procedure"))
	_button(links, "DAILY MEMO", _browse.bind("memo"))
	_standards_link = _button(links, "STANDARDS", _browse.bind("standards"))
	var content: VBoxContainer = _scroll_column(page)
	_browser_text = _paragraph(content, "", 15)
	_browser_plain = content.get_parent()
	_daily_reader = DailyReader.new()
	page.add_child(_daily_reader)
	_daily_reader.navigate_requested.connect(_browse)
	_daily_reader.start_shift_requested.connect(_finish_morning)
	_daily_reader.hide()
	_browse("home")


func _browse(path: String, record: bool = true) -> void:
	if record and _browser_path != path:
		_browser_history.append(_browser_path)
	_browser_path = path
	_browser_address.text = "intranet://engineering/" + path
	_browser_back.disabled = _browser_history.is_empty()
	var reading := path in ["news", "memo", "standards"] or path.begins_with("story/")
	if path == "standards":
		_mark_app_read("browser")
		tutorial_event.emit({"type": "open-standards"})
	_browser_plain.visible = not reading
	_daily_reader.visible = reading
	if reading:
		_daily_reader.show_page(int(_state.get("day", 1)), path, morning_active)
		_sync_morning_control()
		return
	match path:
		"procedure":
			_browser_text.text = "REVIEW PROCEDURE\n\nRead the author packet and changed code. Use the standards index to identify every applicable violation.\nApprove clean work with no citations. To request changes, click the offending line (or WHOLE FILE for filename, ink, opening-line, and quoted-label rules), then pick the standard it breaks in the box that opens on that line. Full standards are on the intranet.\nYour colleagues react to your decisions. Later, your manager checks in about bugs, delays, and the release.\nHelios recommendations are optional and can be wrong."
		_:
			_browser_text.text = "ENGINEERING INTRANET\nLOCAL TERMINAL / INTERNAL ACCESS\n\nWorkstation online.\n\nNEWS carries the morning headlines. DAILY MEMO carries today's instructions from management. PROCEDURE describes the review process.\n\nExternal access restricted by company policy."


func begin_morning() -> void:
	morning_active = true
	_browser_history.clear()
	_browse("news", false)
	_open_app("browser")
	if not _windows["browser"].maximized: _windows["browser"].toggle_maximize()
	# Morning reading explains these arrivals; keep badges, clear covering bubbles.
	for app: String in _app_counts: _notifications.clear_app(app)
	_clock_label.text = "09:00"
	_footer.text = "BEFORE WORK"
	_sync_morning_control()


func _sync_morning_control() -> void:
	_begin_shift_button.visible = morning_active
	_pause_button.visible = not morning_active
	_begin_shift_button.disabled = not _daily_reader._memo_seen
	_begin_shift_button.tooltip_text = "Start the %d-minute workday" % (Catalog.shift_seconds() / 60) if _daily_reader._memo_seen else "Read today's memo in Intranet to begin your shift"


func _finish_morning() -> void:
	if not morning_active or not _daily_reader._memo_seen: return
	morning_active = false
	_sync_morning_control()
	_daily_reader.show_page(int(_state.get("day", 1)), _browser_path, false)
	_windows["browser"].minimize_window()
	_footer.text = "READY"
	_update_dock()
	focus_workspace()


func _browser_go_back() -> void:
	if not _browser_history.is_empty():
		var previous: String = _browser_history.pop_back()
		_browse(previous, false)


func _build_decision(parent: Node) -> void:
	var holder: VBoxContainer = _column(parent, 6)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	holder.size_flags_stretch_ratio = 0.95
	holder.custom_minimum_size.x = 250
	var heading := _row(holder, 6)
	_label(heading, "CITATIONS", 13, RED)
	_spacer(heading)
	_clear_button = _button(heading, "CLEAR", _clear_citations)
	_clear_button.custom_minimum_size.y = 24
	_clear_button.add_theme_font_size_override("font_size", 10)
	_clear_button.tooltip_text = "Withdraw every citation on this PR."
	# Citations are made on the code itself; full rule text lives on the intranet.
	var column: VBoxContainer = _scroll_column(holder)
	column.add_theme_constant_override("separation", 6)
	_selected_label = _paragraph(column, "NONE YET", 12, DIM)
	_citation_list = _column(column, 4)
	_paragraph(column, "Click a line to flag it. Full standards: INTRANET > STANDARDS.", 11, DIM)
	_consult = _button(column, "ASK HELIOS", _emit_command.bind({"type": "consult-ai"}))
	_consult.add_theme_color_override("font_color", AMBER)
	_consult.tooltip_text = "Ask Helios for a recommendation. It can lighten your workload, but invites the assistant further into the process. Advice can be wrong."
	_ai_note = _paragraph(column, "Helios can take a look. Its advice may be wrong, and using it gives the assistant more influence.", 12, DIM)
	_label(column, "LAST SENT", 11, DIM)
	_feedback = _paragraph(column, "No review sent yet.", 12, DIM)
	# Rubber stamps stay pinned below the slip so they are never scrolled away.
	_approve = _stamp_button(holder, "APPROVED", GREEN, _emit_command.bind({"type": "review", "verdict": "approve"}))
	_reject = _stamp_button(holder, "CHANGES REQUESTED", RED, _emit_command.bind({"type": "review", "verdict": "request_changes"}))


func _point_at(line: int) -> void:
	# line -1 reads the clicked (or first selected) line; 0 means the whole file.
	if _displayed_file_key.is_empty() or _review_files.is_empty(): return
	if not bool(_state.get("phase", "review") == "review"): return
	var path: String = _file_label.text
	var picked: int = line
	if line < 0:
		picked = (_diff.get_selection_from_line() if _diff.has_selection() else _diff.get_caret_line()) + 1
	_evidence = {"path": path, "line": picked}
	tutorial_event.emit({"type": "point-evidence", "path": path, "line": picked})
	_paint_evidence()
	_open_flag_box()


func _build_flag_box() -> void:
	# A code-review comment box that opens on the flagged line.
	_flag_box = PanelContainer.new()
	var frame := _style(Color("0d0d0f"), AMBER, 1, 10, 8)
	frame.border_width_left = 4
	frame.shadow_color = Color(0, 0, 0, 0.6)
	frame.shadow_size = 8
	_flag_box.add_theme_stylebox_override("panel", frame)
	_flag_box.z_index = 60
	_flag_box.hide()
	_monitor_screen.add_child(_flag_box)
	var box := _column(_flag_box, 6)
	var heading := _row(box, 8)
	_flag_title = _label(heading, "", 12, AMBER)
	_spacer(heading)
	var close := _button(heading, "×", _close_flag_box)
	close.flat = true
	close.custom_minimum_size = Vector2(24, 22)
	close.tooltip_text = "Close without citing (Esc)"
	var choices := HFlowContainer.new()
	choices.add_theme_constant_override("h_separation", 6)
	choices.add_theme_constant_override("v_separation", 6)
	box.add_child(choices)
	for rule: Dictionary in Catalog.rules():
		var id: String = str(rule.id)
		var choice := Button.new()
		choice.text = id
		choice.toggle_mode = true
		choice.custom_minimum_size = Vector2(54, 30)
		choice.add_theme_font_size_override("font_size", 13)
		choice.tooltip_text = "%s  %s\n%s" % [id, str(rule.title), str(RULE_SUMMARIES.get(id, ""))]
		choice.add_theme_stylebox_override("pressed", _style(Color("2a0d12"), RED, 1, 9, 7))
		choice.add_theme_color_override("font_pressed_color", RED)
		choice.pressed.connect(_flag_rule.bind(id))
		choices.add_child(choice)
		_flag_buttons[id] = choice
	_paragraph(box, "Pick the standard this breaks. Hover an ID for its summary.", 11, DIM)


func _open_flag_box() -> void:
	if _evidence.is_empty(): return
	var day: int = int(_state.get("day", 1))
	var cited: Dictionary = _state.get("citation_evidence", {})
	_flag_title.text = "FLAG %s AS BREAKING:" % _location_text(_evidence).to_upper()
	for rule: Dictionary in Catalog.rules():
		var button: Button = _flag_buttons[str(rule.id)]
		button.visible = int(rule.introduced_day) <= day
		button.set_pressed_no_signal(cited.get(str(rule.id), {}) == _evidence)
	_flag_box.size = Vector2(minf(420, _monitor_screen.size.x - 24), 0)
	_flag_box.show()
	_place_flag_box.call_deferred()


func _place_flag_box() -> void:
	if not is_instance_valid(_flag_box) or not _flag_box.visible or _evidence.is_empty(): return
	_flag_box.size.y = _flag_box.get_combined_minimum_size().y
	var anchor: Vector2
	if int(_evidence.line) > 0:
		var rect: Rect2i = _diff.get_rect_at_line_column(int(_evidence.line) - 1, 0)
		anchor = _diff.global_position + Vector2(rect.position.x, rect.end.y + 4) if rect.position.y >= 0 else _diff.global_position + Vector2(24, 8)
	else:
		anchor = _whole_file.global_position + Vector2(_whole_file.size.x - _flag_box.size.x, _whole_file.size.y + 4)
	var local := anchor - _monitor_screen.global_position
	# Flip above the line when the box would run off the bottom of the screen.
	if local.y + _flag_box.size.y > _monitor_screen.size.y - 8 and int(_evidence.line) > 0:
		local.y -= _flag_box.size.y + 30
	_flag_box.position = local.clamp(Vector2(8, 8), (_monitor_screen.size - _flag_box.size - Vector2(8, 8)).max(Vector2(8, 8)))


func _close_flag_box() -> void:
	if is_instance_valid(_flag_box): _flag_box.hide()
	_evidence = {}
	_paint_evidence()


func _flag_rule(rule_id: String) -> void:
	if _evidence.is_empty(): return
	var cited: Dictionary = _state.get("citation_evidence", {})
	var location: Dictionary = _evidence.duplicate()
	if rule_id in _state.get("selected_rules", []):
		_emit_command({"type": "toggle-rule", "rule_id": rule_id})
		if cited.get(rule_id, {}) == location:
			_close_flag_box()
			return
	_emit_command({"type": "toggle-rule", "rule_id": rule_id, "path": location.path, "line": int(location.line)})
	_close_flag_box()


func _render_citation_list(state: Dictionary, can_review: bool) -> void:
	for child: Node in _citation_list.get_children():
		_citation_list.remove_child(child)
		child.queue_free()
	var cited: Dictionary = state.get("citation_evidence", {})
	for rule_id: String in state.get("selected_rules", []):
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _style(Color("1e0d10"), RED, 1, 6, 3))
		_citation_list.add_child(row)
		var line := _row(row, 4)
		var text := _label(line, rule_id + "  " + _location_text(cited.get(rule_id, {})), 11, TEXT)
		text.clip_text = true
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.custom_minimum_size.x = 40
		text.tooltip_text = text.text
		var remove := _button(line, "×", _emit_command.bind({"type": "toggle-rule", "rule_id": rule_id}))
		remove.flat = true
		remove.disabled = not can_review
		remove.custom_minimum_size = Vector2(24, 22)
		remove.tooltip_text = "Withdraw " + rule_id


func _location_text(location: Dictionary) -> String:
	var name := str(location.get("path", "")).get_file()
	return ("FILE  " if int(location.get("line", 0)) == 0 else "LINE %d  " % int(location.line)) + name


func _paint_evidence() -> void:
	if not is_instance_valid(_diff) or not is_instance_valid(_evidence_label): return
	var path: String = _file_label.text
	var cited: Dictionary = _state.get("citation_evidence", {})
	for line in range(_diff.get_line_count()):
		_diff.set_line_background_color(line, Color(0, 0, 0, 0))
	for rule_id: String in cited:
		var location: Dictionary = cited[rule_id]
		if str(location.path) == path and int(location.line) > 0 and int(location.line) <= _diff.get_line_count():
			_diff.set_line_background_color(int(location.line) - 1, Color(RED, 0.22))
	var pointing := not _evidence.is_empty() and str(_evidence.path) == path
	if pointing and int(_evidence.line) > 0 and int(_evidence.line) <= _diff.get_line_count():
		_diff.set_line_background_color(int(_evidence.line) - 1, Color(AMBER, 0.28))
	_whole_file.disabled = _review_files.is_empty()
	if _review_files.is_empty():
		_evidence_label.text = ""
	elif pointing:
		_evidence_label.text = "> FLAGGING %s — pick the standard it breaks" % _location_text(_evidence).to_upper()
		_evidence_label.add_theme_color_override("font_color", AMBER)
	else:
		_evidence_label.text = "Click or select a line to flag it. WHOLE FILE flags the file itself."
		_evidence_label.add_theme_color_override("font_color", DIM)


func _stamp_button(parent: Node, text: String, ink: Color, action: Callable) -> Button:
	var stamp := _button(parent, text, action)
	stamp.custom_minimum_size.y = 46
	stamp.add_theme_font_size_override("font_size", 15)
	var faded := ink.darkened(0.7)
	stamp.add_theme_stylebox_override("normal", _style(Color(ink, 0.06), ink, 3, 10, 6))
	stamp.add_theme_stylebox_override("hover", _style(Color(ink, 0.18), ink.lightened(0.25), 3, 10, 6))
	stamp.add_theme_stylebox_override("pressed", _style(Color(ink, 0.32), ink.lightened(0.4), 3, 10, 6))
	stamp.add_theme_stylebox_override("disabled", _style(INSET, faded, 2, 10, 6))
	for color_name: String in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		stamp.add_theme_color_override(color_name, ink.lightened(0.15) if color_name != "font_color" else ink)
	stamp.add_theme_color_override("font_disabled_color", faded.lightened(0.1))
	return stamp


func _play_stamp(verdict: String) -> void:
	# Papers on the desk get stamped: a brief, physical confirmation of the verdict.
	if not is_instance_valid(_paper) or not _paper.is_visible_in_tree(): return
	var approved := verdict == "approve"
	var ink := STAMP_GREEN if approved else STAMP_RED
	var mark := PanelContainer.new()
	var frame := _style(Color(PAPER, 0.0), ink, 4, 16, 6)
	frame.draw_center = false
	mark.add_theme_stylebox_override("panel", frame)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.z_index = 45
	var word := _label(mark, "APPROVED" if approved else "CHANGES REQUESTED", 30 if approved else 24, ink)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monitor_screen.add_child(mark)
	mark.size = mark.get_combined_minimum_size()
	var paper_rect := _paper.get_global_rect()
	mark.position = paper_rect.get_center() - _monitor_screen.global_position - mark.size * 0.5
	mark.pivot_offset = mark.size * 0.5
	mark.rotation = -0.16
	mark.scale = Vector2(1.7, 1.7)
	mark.modulate.a = 0.0
	var tween := mark.create_tween()
	tween.tween_property(mark, "scale", Vector2.ONE, 0.11).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(mark, "modulate:a", 0.92, 0.08)
	tween.tween_interval(0.75)
	tween.tween_property(mark, "modulate:a", 0.0, 0.45)
	tween.tween_callback(mark.queue_free)


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
	_chat_channel_label = _label(sidebar, "CHANNELS", 11, DIM)
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


func _process(_delta: float) -> void:
	_sync_tutorial_pointer()
	if is_instance_valid(_flag_box) and _flag_box.visible:
		if not _windows.review.is_visible_in_tree() or _evidence.is_empty(): _close_flag_box()
		else: _place_flag_box()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and is_instance_valid(_flag_box) and _flag_box.visible:
		_close_flag_box()
		get_viewport().set_input_as_handled()


func _render_chat() -> void:
	var first_render := _chat_seen.is_empty()
	for contact: String in _chat_contacts:
		var messages: Array = Chat.messages(_state, contact)
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
				_ambient_push("chat", sender + ": " + str(incoming[-1].text), contact)
	if _windows["chat"].visible: _draw_chat()
	_update_chat_badges()
	if first_render and int(_app_counts.chat) > 0:
		_ambient_push("chat", "Your team has left you messages.", _chat_contact)


func _update_chat_badges() -> void:
	var total := 0
	for contact: String in _chat_contacts:
		var unread := int(_chat_unread.get(contact, 0))
		var button: Button = _chat_contacts[contact]
		# Orientation shows only the coworker who sent the practice PR.
		button.visible = not _tutorial_active or contact == "Maya"
		if not button.visible: continue
		total += unread
		button.text = ("#engineering" if contact == "company" else "Morgan" if contact == "manager" else contact) + ("  %d" % unread if unread > 0 else "")
		button.set_pressed_no_signal(contact == _chat_contact)
	_app_counts.chat = total
	if is_instance_valid(_chat_channel_label): _chat_channel_label.visible = not _tutorial_active
	_update_app_badges()


func _draw_chat(contact_changed: bool = false) -> void:
	var messages: Array = Chat.messages(_state, _chat_contact)
	var key: String = _chat_contact + JSON.stringify(messages) + str(_state.get("phase", ""))
	if key == _chat_last_draw and not contact_changed:
		return
	_tutorial_pr_link = null
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
			if pr_id == str(Catalog.request_at(0).id): _tutorial_pr_link = link
			link.alignment = HORIZONTAL_ALIGNMENT_LEFT
			link.add_theme_font_size_override("font_size", 12)
			link.add_theme_color_override("font_color", CYAN)
	if messages.is_empty():
		_paragraph(_chat_messages, "No messages in this conversation yet.", 14, DIM)
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
	_save_slot_label = _label(content, "Current save: Slot 1", 14, CYAN)
	_system_status = _paragraph(content, "Local storage is ready.", 14, CYAN)
	_paragraph(content, "Three local save slots. New Game and Load Game on the main menu let you choose a slot. Each shift lasts %d real minutes, from 09:00 to 18:00. Reading code and Slouch messages uses time. Pause with Esc or the desktop clock control. Switching away pauses automatically." % (Catalog.shift_seconds() / 60), 14, DIM)
	var saves: HBoxContainer = _row(content)
	_button(saves, "SAVE RUN", func() -> void: save_requested.emit())
	_button(saves, "LOAD RUN", func() -> void: load_requested.emit())
	_button(saves, "NEW RUN", func() -> void: _confirmation.popup_centered())
	_button(content, "SAVE AND MAIN MENU", func() -> void: menu_requested.emit())
	_label(content, "REVIEW PROCEDURE", 16, CYAN)
	_paragraph(content, "1. Read the author message and code diff.\n2. In REVIEW, click or select each violating line (or WHOLE FILE) and pick the standard it breaks. Full standards: INTRANET > STANDARDS.\n3. Approve with no citations, or request changes with citations.\n4. Watch Slouch for your coworker’s response and your manager’s follow-up.\n\nPR links arrive in Slouch throughout the day. Ask coworkers for context, then open their links to review. AI advice is optional and fallible. At 18:00, Helios takes unfinished work. Morgan will message you in Slouch. Open that conversation to wrap up the day.", 14, DIM)


func set_save_slot(slot: int) -> void:
	_save_slot_label.text = "Current save: Slot %d · stored on this computer" % slot


func _emit_command(command: Dictionary) -> void:
	command_requested.emit(command)


func _clear_citations() -> void:
	var selected: Array = _state.get("selected_rules", []).duplicate()
	for rule_id: String in selected:
		_emit_command({"type": "toggle-rule", "rule_id": rule_id})


func render_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	render_clock(state)
	_sync_arrival_picker()
	var day: int = int(state.get("day", 1))
	var phase: String = str(state.get("phase", "review"))
	var selected: Array = state.get("selected_rules", [])
	var consulted: bool = bool(state.get("consulted", false))
	var active_request: Dictionary = Simulation.active_request(state)
	var can_review: bool = phase == "review" and not active_request.is_empty()
	_consult.visible = day >= 3
	_ai_note.visible = _consult.visible
	var day_names: Array[String] = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
	_hud["day"].text = day_names[(day - 1) % day_names.size()]
	_hud["status"].text = ("HUMAN SIGN-OFF REQUESTED" if can_review else "INCOMING WORK / SLOUCH") if phase == "review" else "SHIFT CLOSED" if phase == "debrief" else "ASSIGNMENT CLOSED"
	if day != _last_day:
		_last_day = day
		var briefing: String = Catalog.briefing(day)
		_briefing_dialog.dialog_text = briefing
		if _browser_path in ["memo", "news", "standards"] or _browser_path.begins_with("story/"):
			_browse("news" if _browser_path.begins_with("story/") else _browser_path, false)
	_selected_label.visible = selected.is_empty()
	_render_citation_list(state, can_review)
	_paint_evidence()
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
			_pr_title.text = "Pick up an arrived PR"
			_pr_context.text = "Use NEXT PR, the dropdown, or a Slouch link. Check the visible file against today’s policies."
			_file_label.text = ""
			if not _review_files.is_empty() or not _diff.text.is_empty():
				_set_review_files({})
		if not request_id.is_empty() and request_id != _last_pr:
			_last_pr = request_id
			_pr_id.text = "%s / AWAITING REVIEW" % request_id
			_pr_title.text = str(request.get("title", ""))
			_pr_context.text = "%s: %s\n\n%s" % [str(request.get("author", "")), str(request.get("message", "")), str(request.get("description", ""))]
			_set_review_files(request)
			_close_flag_box()
			_packet_scroll.scroll_vertical = 0
		_ai_note.text = "Helios can take a look. Its advice may be wrong, and using it gives the assistant more influence."
		if consulted:
			_ai_note.text = "AI: %s\n%s" % [str(request.get("ai_verdict", "")).replace("_", " ").to_upper(), str(request.get("ai_note", ""))]
	var feedback: Dictionary = state.get("last_feedback", {})
	var feedback_key := "" if feedback.is_empty() else str(feedback.get("pr_id", "")) + str(feedback.get("verdict", ""))
	if feedback_key != _last_feedback_key:
		if _last_feedback_key != "-" and not feedback_key.is_empty(): _play_stamp(str(feedback.get("verdict", "")))
		_last_feedback_key = feedback_key
	_feedback.text = "No review sent yet." if feedback.is_empty() else "%s · %s sent to %s." % [str(feedback.get("pr_id", "")), "Approval" if feedback.get("verdict") == "approve" else "Change request", str(feedback.get("author", ""))]
	_render_phase(state)
	_render_chat()
	_sync_app_events()
	_footer.text = "ORIENTATION" if _tutorial_active else "READY" if phase == "review" else "OFF THE CLOCK"


func _render_phase(state: Dictionary) -> void:
	_evening_buttons.visible = _chat_contact == "manager" and state.get("phase") == "debrief"
	_complete_button.visible = _chat_contact == "manager" and state.get("phase") == "complete"


func _ambient_push(app: String, text: String, target: String = "") -> void:
	# Orientation stays quiet: only direct guidance and errors reach the ticker.
	if not _tutorial_active: _notifications.push(app, text, target)


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
		# The morning memo belongs to Monday, not to orientation.
		if _tutorial_active and app == "browser": count = 0
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
		if added > 0 and not _app_is_reading("browser"):
			_app_counts.browser += 1
			_ambient_push("browser", "New standards are posted on the intranet.", "standards")
		if not _app_is_reading("browser"):
			_app_counts.browser += 1
			_ambient_push("browser", "A new daily memo is on the intranet.", "memo")
	var pending: Dictionary = {}
	for request: Dictionary in Simulation.available_requests(_state):
		var id := str(request.id)
		pending[id] = true
		if not _known_requests.has(id):
			_known_requests[id] = true
			_unread_requests[id] = true
			_ambient_push("review", "%s from %s: %s" % [id, request.author, request.title], id)
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
	if app == "browser" and target in ["memo", "standards"]: _browse(target)
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
	_tutorial_pointer = TutorialPointer.new()
	_monitor_screen.add_child(_tutorial_pointer)
	_tutorial_panel = PanelContainer.new()
	var note := _style(INSET, RED, 1, 12, 10)
	note.border_width_left = 5
	_tutorial_panel.add_theme_stylebox_override("panel", note)
	_tutorial_panel.z_index = 40
	_tutorial_panel.hide()
	_monitor_screen.add_child(_tutorial_panel)
	var box := _column(_tutorial_panel, 6)
	var heading := _row(box, 8)
	_tutorial_title = _label(heading, "ORIENTATION", 12, RED)
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
	var starting: bool = not _tutorial_active and not progress.is_empty()
	_tutorial_active = not progress.is_empty()
	if starting:
		for app: String in _app_counts: _notifications.clear_app(app)
	_update_chat_badges()
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


func _sync_arrival_picker() -> void:
	if not is_instance_valid(_arrival_picker): return
	var packets := Simulation.available_requests(_state)
	var ids: Array[String] = []
	for packet: Dictionary in packets: ids.append(str(packet.id))
	if ids != _arrival_ids or _arrival_picker.item_count == 0:
		_arrival_ids = ids
		_arrival_picker.clear()
		_arrival_picker.add_item("Arrived PRs" if not ids.is_empty() else "Waiting for work…")
		for packet: Dictionary in packets:
			_arrival_picker.add_item(str(packet.id) + " · " + str(packet.author) + " · " + str(packet.title))
	_arrival_picker.select(ids.find(str(_state.get("active_request_id", ""))) + 1)
	_arrival_picker.disabled = ids.is_empty()
	_next_pr.disabled = ids.is_empty() or (ids.size() == 1 and ids[0] == str(_state.get("active_request_id", "")))


func _open_next_pr() -> void:
	for id: String in _arrival_ids:
		if id != str(_state.get("active_request_id", "")):
			_open_pr_link(id)
			return


func _tutorial_launcher(app: String) -> Control:
	if _dock_buttons[app].visible: return _dock_buttons[app]
	for window: Control in _windows.values():
		if window.visible and window.get_global_rect().intersects(_home_icons[app].get_global_rect()): return _home_button
	return _home_icons[app]


func _sync_tutorial_pointer() -> void:
	if not is_instance_valid(_tutorial_pointer): return
	var target: Control = null
	if _tutorial_active and not _paused:
		match int(_tutorial_details.get("stage", 0)):
			0, 7: target = _tutorial_next
			1: target = _tutorial_launcher("chat")
			3:
				if not _windows.chat.visible or not _windows.chat._active: target = _tutorial_launcher("chat")
				elif _chat_contact != "Maya": target = _chat_contacts.Maya
				elif is_instance_valid(_tutorial_pr_link): target = _tutorial_pr_link
			4: target = _file_picker if _windows.review.visible and _windows.review._active else _tutorial_launcher("review")
			5: target = _standards_link if _windows.browser.visible and _windows.browser._active else _tutorial_launcher("browser")
			6:
				var id := "P01"
				if id not in _state.get("selected_rules", []):
					if _windows.review.visible and _windows.review._active:
						# Practice only: guide to the visible comment, never to hidden audit data.
						var evidence := _practice_evidence(id)
						var pointed: bool = not _evidence.is_empty() and not evidence.is_empty() and _evidence.path == evidence.path and int(_evidence.line) == int(evidence.line)
						if pointed and _flag_box.visible: target = _flag_buttons[id]
						elif evidence.is_empty() or _file_label.text != evidence.path: target = _file_picker
						else: target = _diff
					else: target = _tutorial_launcher("review")
				else: target = _reject if _windows.review.visible and _windows.review._active else _tutorial_launcher("review")
	if is_instance_valid(target) and target != _tutorial_next and _tutorial_panel.get_global_rect().intersects(target.get_global_rect()):
		for location: Vector2 in [Vector2(12, _monitor_screen.size.y - _tutorial_panel.size.y - 50), Vector2(_monitor_screen.size.x - _tutorial_panel.size.x - 12, _monitor_screen.size.y - _tutorial_panel.size.y - 50), Vector2(12, 48)]:
			var candidate := Rect2(_monitor_screen.global_position + location, _tutorial_panel.size)
			if not candidate.intersects(target.get_global_rect()):
				_tutorial_panel.position = location
				break
	_tutorial_pointer.set_target(target)


func _practice_evidence(rule_id: String) -> Dictionary:
	var files: Array = Simulation.active_request(_state).get("files", [])
	for finding: Dictionary in load("res://content/policy_campaign.gd").findings(files, 1):
		if finding.rule_id == rule_id: return finding
	return {}


func _fit_tutorial() -> void:
	if not is_inside_tree(): return
	if not get_tree().process_frame.is_connected(_queue_tutorial_fit):
		get_tree().process_frame.connect(_queue_tutorial_fit, CONNECT_ONE_SHOT)


func _queue_tutorial_fit() -> void:
	if is_inside_tree() and not get_tree().process_frame.is_connected(_apply_tutorial_fit):
		get_tree().process_frame.connect(_apply_tutorial_fit, CONNECT_ONE_SHOT)


func _apply_tutorial_fit() -> void:
	if is_inside_tree():
		_tutorial_panel.size.y = _tutorial_panel.get_combined_minimum_size().y
