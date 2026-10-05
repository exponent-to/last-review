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
signal music_toggled(enabled: bool)
signal music_volume_changed(volume: float)
## The ending cinematic started: "warm" or "bleak", for the soundtrack.
signal ending_music(kind: String)

const Simulation = preload("res://native/simulation.gd")
const ComputerFrame = preload("res://native/computer_frame.gd")
const Notifications = preload("res://native/desktop_notifications.gd")
const DesktopWindow = preload("res://native/desktop_window.gd")
const Chat = preload("res://content/chat.gd")
const TutorialPointer = preload("res://native/tutorial_pointer.gd")
const DailyReader = preload("res://native/daily_reader.gd")
const ReviewBanter = preload("res://native/review_banter.gd")
const Encounters = preload("res://content/encounters.gd")
const Catalog = preload("res://content/catalog.gd")
const Portraits = preload("res://native/portraits.gd")
const Tutorial = preload("res://native/tutorial.gd")
const Endings = preload("res://content/endings.gd")
const EndingCinematic = preload("res://native/ending_cinematic.gd")
const Policy = preload("res://content/policy_campaign.gd")
const Records = preload("res://content/records.gd")
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
## One-line slip summaries. "P19@7" replaces "P19" from day 7, when it was amended.
const RULE_SUMMARIES := {
	"P01": "No ‘load-bearing’ in comments.",
	"P02": "def / if / else / return must be blue.",
	"P02@5": "Keywords blue, unless the file’s permit is INK-EXCEPTION.",
	"P02@9": "Keywords blue, unless permit is INK-EXCEPTION + this PR’s ticket.",
	"P09": "Whole PR: at most 30 lines changed (+ and −).",
	"P11": "No quoted string assigned to a password / secret / token / api_key name.",
	"P13": "Whole PR: changes existing code (M/R)? A tests/ file must change too.",
	"P16": "Ticket: linked, in Jiro, and Open or In Progress.",
	"P17": "Ticket: assigned to the PR’s author.",
	"P18": "Ticket: every non-test file sits directly in its component.",
	"P18@9": "Ticket: every non-test file sits in its component or below.",
	"P19": "Build: status not FAILED (FLAKY passes).",
	"P19@7": "Build: not FAILED. Helios overrides count as passing.",
	"P19@9": "Build: not FAILED, and not overridden by Helios.",
	"P20": "Build: rerun at most 3 times.",
	"P21": "Build: coverage falls 2.0 points at most.",
	"P15": "No exec/eval, helios.bootstrap, or minified one-liners.",
}
## The evening choices and what each does, in words rather than numbers
## (the effects themselves live in Simulation._evening).
const EVENINGS := [
	{"choice": "rest", "label": "GO HOME", "about": "Sleep it off. You'll start tomorrow calmer."},
	{"choice": "socialize", "label": "GET DINNER", "about": "Costs a little. Your coworkers warm to you; you unwind a bit."},
	{"choice": "study", "label": "STUDY", "about": "Morgan notices the effort. You'll be more tired tomorrow."},
]
const EVIDENCE_HINTS := {
	"line": "Cite the exact line.",
	"file": "Cite the file: WHOLE FILE or any of its lines.",
	"pr": "About the whole PR: WHOLE FILE on any changed file.",
	"ticket": "Cite the PR's ticket: open it in JIRO and SELECT AS EVIDENCE. WHOLE FILE doesn't count.",
	"build": "Cite the PR's build: open it in PIPELINE and SELECT AS EVIDENCE. WHOLE FILE doesn't count.",
}
## How Jiro colors a ticket status, and Pipeline a build status.
const STATUS_COLORS := {"Open": Color("9fc4e8"), "In Progress": Color("e0b44a"), "PASSED": Color("6fdc8c"), "FLAKY": Color("e0b44a"), "FAILED": Color("e5384a")}

class PolicyHighlighter extends SyntaxHighlighter:
	# Keyword ink is computed on the proposed file, then mapped onto diff rows.
	var spans: Dictionary = {}
	var removed: Dictionary = {}
	var ink := Color("72b7ff")
	func configure(rows: Array, source: String, color_name: String) -> void:
		ink = Color("ef94c3") if color_name == "pink" else Color("72b7ff")
		spans.clear()
		removed.clear()
		var row_for_line: Dictionary = {}
		for index in range(rows.size()):
			if rows[index].kind == "-": removed[index] = true
			else: row_for_line[int(rows[index].line) - 1] = index
		for span: Dictionary in load("res://content/policy_campaign.gd").keyword_spans(source):
			var row: int = int(row_for_line.get(int(span.line), -1))
			if row < 0: continue
			if not spans.has(row): spans[row] = []
			spans[row].append(span)
		clear_highlighting_cache()
	func _get_line_syntax_highlighting(line: int) -> Dictionary:
		if removed.has(line): return {0: {"color": Color("6f5a5c")}}
		var result := {0: {"color": Color("e0e8ef")}}
		for span: Dictionary in spans.get(line, []):
			result[int(span.start)] = {"color": ink}
			result[int(span.end)] = {"color": Color("e0e8ef")}
		return result

var scene_host: Control
var _state: Dictionary = {}
var _hud: Dictionary = {}
var _monitor_screen: Control
var _desktop_home: Control
var _home_icons: Dictionary = {}
var _notifications: Notifications
## Apps that can notify. Jiro and Pipeline never do: a record is checked, not delivered.
var _app_counts := {"review": 0, "browser": 0, "system": 0}
var _app_badges: Dictionary = {}
var _known_requests: Dictionary = {}
var _unread_requests: Dictionary = {}
var _notification_day := -1
var _system_status: Label
var _music_toggle: Button
var _music_volume: HSlider
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
## Morgan's end-of-day panel: her portrait, the day's notes, her closing words,
## and the evening choice (or, once the assignment is over, the way out).
var _evening_face: Control
var _evening_when: Label
var _evening_notes_heading: Label
var _evening_notes: VBoxContainer
var _evening_closing: VBoxContainer
var _evening_buttons: VBoxContainer
var _complete_button: Button
var _watch_ending: Button
var _ending_cinematic: Control
var _evening_key: String = ""
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
var _tutorial_dragged := false
var _tutorial_drag_offset := Vector2.ZERO
var _tutorial_dragging := false
var _tutorial_title: Label
var _tutorial_body: Label
var _tutorial_next: Button
var _tutorial_active := false
var _tutorial_pointer: Control
var _home_button: Button
var _code_legend: Label
var _tutorial_details: Dictionary = {}
var _paper: PanelContainer
var _banter: ReviewBanter
var _last_feedback_key := "-"
## Encounter beats already played at the desk; -1 until the first render.
var _beats_seen := -1
var _evidence: Dictionary = {}
var _diff_rows: Array = []
var _line_gutter := -1
var _mark_gutter := -1
var _diffstat_label: RichTextLabel
var _evidence_label: Label
var _slip_rows: Dictionary = {}
var _slip_day: int = -1
var _flag_buttons: Dictionary = {}
var _standards_link: Button
var _whole_file: Button
## The PR slip's record links: its Jiro ticket and its Pipeline build.
var _pr_refs: HBoxContainer
var _ticket_link: LinkButton
var _build_link: LinkButton
## Jiro: search, ticket list, and the ticket on view. `_jiro_view` is
## {"ticket": id} for a ticket Jiro has, {"link": id} for the desk PR's own link
## when Jiro has no such ticket (or the PR links none), or {} for nothing.
var _jiro_search: LineEdit
var _jiro_list: VBoxContainer
var _jiro_detail: VBoxContainer
var _jiro_view: Dictionary = {}
var _jiro_tickets: Array = []
var _jiro_key := ""
var _jiro_list_key := ""
## Pipeline: recent builds, and the build on view ("" for none).
var _pipeline_list: VBoxContainer
var _pipeline_detail: VBoxContainer
var _pipeline_build := ""
var _pipeline_builds: Array = []
var _pipeline_key := ""


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
		if _tutorial_dragged: _clamp_tutorial()
		else: _tutorial_panel.position = Vector2(maxf(0, screen.size.x - 450), 48)


func _build_os_menu(parent: Node) -> void:
	var panel: PanelContainer = PanelContainer.new()
	var bar := _style(Color("050506"), Color("050506"), 0, 10, 3)
	bar.border_width_bottom = 1
	bar.border_color = Color("3a1218")
	panel.add_theme_stylebox_override("panel", bar)
	parent.add_child(panel)
	var row: HBoxContainer = _row(panel, 12)
	_spacer(row)
	_hud["day"] = _label(row, day_label(1), 12, RED)
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
	box.custom_minimum_size.x = 380
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
	Portraits.set_paused(paused, self)
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


## The top bar's workday: "WEEK 1 · MONDAY" through "WEEK 2 · FRIDAY".
static func day_label(day: int) -> String:
	var names: Array[String] = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY"]
	var days_per_week: int = names.size()
	return "WEEK %d · %s" % [(maxi(1, day) - 1) / days_per_week + 1, names[(maxi(1, day) - 1) % days_per_week]]


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
	# The PR's other documents: its ticket in Jiro and its build in Pipeline.
	_build_jiro(_new_window("jiro", "JIRO / TICKETS").body)
	_build_pipeline(_new_window("pipeline", "PIPELINE / CI").body)
	_build_system(_new_window("system", "SYSTEM / WORKSTATION SETTINGS").body)
	_build_browser(_new_window("browser", "INTRANET / LOCAL BROWSER").body)
	# Morgan's end-of-day panel has no icon: it opens by itself at closing and
	# stays on the taskbar until the evening is chosen, so it cannot be closed.
	var evening: DesktopWindow = _new_window("evening", "END OF DAY / MORGAN")
	evening.close_button.hide()
	_build_evening(evening.body)

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
	var mark := _label(motto, "PAPERCLIP LABS", 40, Color("1b1b1e"))
	mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var tagline := _label(motto, "making more of everything._", 13, Color("2a2a2e"))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# Jiro and Pipeline are installed on the mornings their standards arrive.
	var launchers: Array = [
		["review", "REVIEW", "review"],
		["jiro", "JIRO", "jiro"],
		["pipeline", "PIPELINE", "pipeline"],
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
		if not launcher.visible: continue
		launcher.position = Vector2(22 + int(index / rows) * 122, 18 + (index % rows) * 104)
		index += 1


## Whether an app is installed on `day`: Jiro from its first morning, Pipeline from its.
static func app_installed(id: String, day: int) -> bool:
	match id:
		"jiro": return day >= Policy.JIRO_DAY
		"pipeline": return day >= Policy.PIPELINE_DAY
	return true


## Show only the apps installed today; an app that isn't installed yet stays closed.
func _sync_installed_apps(day: int) -> void:
	var changed := false
	for id: String in ["jiro", "pipeline"]:
		var installed := app_installed(id, day) and not _tutorial_active
		if _home_icons[id].visible != installed:
			_home_icons[id].visible = installed
			changed = true
		if not installed and _windows[id].launched: _windows[id].close_window()
	if changed:
		_layout_home_icons()
		_update_dock()


func _new_window(id: String, title: String) -> DesktopWindow:
	var window: DesktopWindow = DesktopWindow.new()
	window.window_id = id
	window.window_title = title
	window.resize_minimum_size = {"review": Vector2(650, 390), "evening": Vector2(480, 340), "jiro": Vector2(600, 340), "pipeline": Vector2(600, 340)}.get(id, Vector2(420, 280))
	window.activated.connect(_focus_app)
	window.minimized.connect(func(_id: String) -> void: _update_dock())
	window.closed.connect(func(_id: String) -> void: _update_dock())
	_desktop.add_child(window)
	_windows[id] = window
	return window


func _build_review_content(code: VBoxContainer) -> void:
	# One PR at a time lands on the desk by itself; there is nothing to pick.
	# The PR's author sits in the top-left corner and talks while you review.
	_banter = ReviewBanter.new()
	_banter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_banter.answered.connect(_answer_pushback)
	code.add_child(_banter)
	# The PR itself is a one-line paper slip: title and number, no description.
	_paper = PanelContainer.new()
	var paper_style := _style(PAPER, PAPER_LINE, 1, 12, 6)
	paper_style.border_width_left = 4
	paper_style.shadow_color = Color(0, 0, 0, 0.55)
	paper_style.shadow_size = 0
	paper_style.shadow_offset = Vector2(3, 3)
	_paper.add_theme_stylebox_override("panel", paper_style)
	code.add_child(_paper)
	var slip_lines: VBoxContainer = _column(_paper, 1)
	var title_row: HBoxContainer = _row(slip_lines, 10)
	_pr_title = _label(title_row, "", 15, PAPER_INK)
	_pr_title.clip_text = true
	_pr_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_pr_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pr_title.custom_minimum_size.x = 80
	_pr_id = _label(title_row, "PULL REQUEST", 11, STAMP_RED)
	# From Wednesday the slip names the PR's ticket, and from Friday its build. Each
	# opens its app on that record; neither says anything about what's inside.
	_pr_refs = _row(slip_lines, 18)
	_ticket_link = _slip_link(_pr_refs, _open_desk_ticket)
	_ticket_link.tooltip_text = "Open this PR's ticket in JIRO."
	_build_link = _slip_link(_pr_refs, _open_desk_build)
	_build_link.tooltip_text = "Open this PR's build in PIPELINE."
	_pr_refs.hide()
	# The author's pitch lives in the speech bubble.
	_packet_scroll = ScrollContainer.new()
	_packet_scroll.hide()
	code.add_child(_packet_scroll)
	_pr_context = Label.new()
	_packet_scroll.add_child(_pr_context)
	_diffstat_label = RichTextLabel.new()
	_diffstat_label.bbcode_enabled = true
	_diffstat_label.fit_content = true
	_diffstat_label.scroll_active = false
	_diffstat_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_diffstat_label.add_theme_font_size_override("normal_font_size", 12)
	_diffstat_label.add_theme_color_override("default_color", DIM)
	_diffstat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	code.add_child(_diffstat_label)
	var file_row := _row(code, 8)
	_label(file_row, "$ git diff", 12, DIM)
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
	_whole_file.tooltip_text = "Point at this entire file, for rules about its ink, and for whole-PR rules (lines changed, tests): any changed file will do. Ticket and build standards need the record itself, from JIRO or PIPELINE."
	_diff = CodeEdit.new()
	_diff.name = "PullRequestDiff"
	_diff.editable = false
	# New-file line numbers and +/- markers; removed lines have no number.
	_diff.gutters_draw_line_numbers = false
	_line_gutter = _diff.get_gutter_count()
	_diff.add_gutter()
	_diff.set_gutter_type(_line_gutter, TextEdit.GUTTER_TYPE_STRING)
	_diff.set_gutter_width(_line_gutter, 34)
	_mark_gutter = _diff.get_gutter_count()
	_diff.add_gutter()
	_diff.set_gutter_type(_mark_gutter, TextEdit.GUTTER_TYPE_STRING)
	_diff.set_gutter_width(_mark_gutter, 18)
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
	var Policy = load("res://content/policy_campaign.gd")
	for entry: Dictionary in _review_files:
		var stat: Dictionary = Policy.diffstat([entry])
		var status: String = str(entry.get("status", "added"))
		var name: String = str(entry.get("path", ""))
		if status == "renamed": name = str(entry.get("old_path", "")) + " → " + name
		_file_picker.add_item("%s  %s   +%d −%d" % [{"added": "A", "modified": "M", "renamed": "R"}.get(status, "M"), name, stat.added, stat.removed])
	_file_picker.disabled = _review_files.is_empty()
	_diffstat_label.text = "" if _review_files.is_empty() else _diffstat_text(Policy.diffstat(_review_files))
	if _review_files.is_empty():
		# Between PRs the desk is clear: no stale gutter marks or line tint.
		_diff_rows = []
		_diff.text = ""
		_diff.set_line_gutter_text(0, _line_gutter, "")
		_diff.set_line_gutter_text(0, _mark_gutter, "")
		_code_legend.hide()
		_paint_evidence()
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
	_diff_rows = load("res://content/policy_campaign.gd").line_diff(str(entry.get("base", "")), str(entry.source))
	var highlighter := PolicyHighlighter.new()
	highlighter.configure(_diff_rows, str(entry.source), str(entry.get("keyword_ink", "blue")))
	_diff.syntax_highlighter = highlighter
	_diff.text = "\n".join(_diff_rows.map(func(row: Dictionary) -> String: return str(row.text)))
	for row_index in range(_diff_rows.size()):
		var row: Dictionary = _diff_rows[row_index]
		_diff.set_line_gutter_text(row_index, _line_gutter, "" if row.kind == "-" else str(row.line))
		_diff.set_line_gutter_item_color(row_index, _line_gutter, Color("4f4d49"))
		_diff.set_line_gutter_text(row_index, _mark_gutter, {"+": "+", "-": "−", " ": ""}[row.kind])
		_diff.set_line_gutter_item_color(row_index, _mark_gutter, GREEN if row.kind == "+" else RED)
	_evidence = {}
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
	# Keyword colors speak for themselves; only the file's permit needs a readout.
	var notes: Array[String] = []
	var day := int(_state.get("day", 1))
	if day >= Policy.PERMIT_DAY: notes.append("Permit: " + str(entry.get("permit", "none")))
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
	for item: Array in [["review", "REVIEW"], ["jiro", "JIRO"], ["pipeline", "PIPELINE"], ["browser", "INTRANET"], ["system", "SYSTEM"], ["evening", "END OF DAY"]]:
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
	var evening := Vector2(minf(680, extent.x - 160), minf(520, extent.y - 24))
	var layouts: Dictionary = {
		"review": Rect2(Vector2(142, 8), Vector2(extent.x - 150, extent.y - 16)),
		"system": Rect2(Vector2(210, 90), Vector2(minf(650, extent.x - 240), minf(470, extent.y - 118))),
		# Beside Review rather than over its citation slip, so a record and the slip can both be seen.
		"jiro": Rect2(Vector2(150, 30), Vector2(minf(860, extent.x - 170), minf(560, extent.y - 50))),
		"pipeline": Rect2(Vector2(170, 46), Vector2(minf(860, extent.x - 190), minf(560, extent.y - 66))),
		"browser": Rect2(Vector2(185, 70), Vector2(minf(720, extent.x - 215), minf(500, extent.y - 98))),
		# Centered beside the icons: the shift is over and this is the one thing left.
		"evening": Rect2(((extent - evening) * 0.5).floor().max(Vector2(142, 12)), evening),
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
	if not app_installed(id, int(_state.get("day", 1))): return
	# Opened from its icon, a record app starts on the desk PR's own record.
	if id == "jiro" and _jiro_view.is_empty(): _jiro_view = _desk_ticket_view()
	if id == "pipeline" and _pipeline_build.is_empty(): _pipeline_build = str(Simulation.active_request(_state).get("build", {}).get("id", ""))
	var window: DesktopWindow = _windows[id]
	window.restore_window()
	_mark_app_read(id)
	_update_dock()
	if id in ["jiro", "pipeline"]: _render_records(true)
	if id == "review": tutorial_event.emit({"type": "open-review"})
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
	# Browser chrome uses the same compact type as every other control.
	for chrome: Node in navigation.get_children() + links.get_children():
		if chrome is Button: chrome.add_theme_font_size_override("font_size", 12)
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
			_browser_text.text = "REVIEW PROCEDURE\n\nRead the author packet and changed code. Use the standards index to identify every applicable violation.\nApprove clean work with no citations. To request changes, point at the evidence, then tick the standard it breaks on the citation slip:\n• Line standards: click the offending line.\n• File standards (ink): WHOLE FILE, or any line of that file.\n• Whole-PR standards (lines changed, tests): WHOLE FILE on any changed file. The diffstat above the diff counts lines for you.\n• Ticket standards: open the PR's ticket in JIRO (click it on the PR slip) and SELECT AS EVIDENCE.\n• Build standards: open the PR's build in PIPELINE (also on the slip) and SELECT AS EVIDENCE. WHOLE FILE never counts for a ticket or a build.\nStandards are reissued every second morning; the daily memo lists what was added, amended, or retired. Full standards are on the intranet.\nThe author sits at your desk and reacts to your decisions. At closing, your manager checks in about bugs, delays, and work handed to Helios.\nHelios recommendations are optional and can be wrong."
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
	_update_dock()
	# The day's first PR landed during the morning reading, which cleared its card.
	# The shift starts with the card back, so the desk is one click away.
	var desk: Dictionary = Simulation.active_request(_state)
	if not desk.is_empty() and _unread_requests.has(str(desk.id)):
		_ambient_push("review", _desk_card_text(desk), str(desk.id), str(desk.author))
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
	# The citation slip: select the offending line, then tick the standard it
	# breaks. Full rule text lives on INTRANET > STANDARDS.
	_selected_label = _paragraph(holder, "", 11, DIM)
	var column: VBoxContainer = _scroll_column(holder)
	column.add_theme_constant_override("separation", 4)
	for rule: Dictionary in Catalog.rules():
		var id: String = str(rule.id)
		var slip := PanelContainer.new()
		slip.add_theme_stylebox_override("panel", _style(INSET, BORDER, 1, 6, 4))
		column.add_child(slip)
		var line := _row(slip, 6)
		var check := CheckBox.new()
		check.text = id
		check.add_theme_font_size_override("font_size", 12)
		check.tooltip_text = "%s  %s\n\n%s" % [id, str(rule.title), str(rule.text)]
		check.pressed.connect(_flag_rule.bind(id))
		line.add_child(check)
		var words := _column(line, 1)
		var summary := _paragraph(words, _rule_summary(rule, 1), 11, DIM)
		summary.mouse_filter = Control.MOUSE_FILTER_PASS
		var where := _label(words, "", 10, RED)
		where.clip_text = true
		where.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		where.custom_minimum_size.x = 60
		where.hide()
		_flag_buttons[id] = check
		_slip_rows[id] = {"panel": slip, "summary": summary, "where": where, "rule": rule}
	_consult = _button(column, "ASK HELIOS", _ask_helios)
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
		var first: int = _diff.get_selection_from_line() if _diff.has_selection() else _diff.get_caret_line()
		var last: int = _diff.get_selection_to_line() if _diff.has_selection() else first
		picked = 0
		for row in range(first, last + 1):
			picked = _line_for_row(row)
			if picked > 0: break
		if picked <= 0:
			notify("That line is being removed. Flag a line in the new version.", false, "review")
			return
	_evidence = {"path": path, "line": picked}
	tutorial_event.emit({"type": "point-evidence", "path": path, "line": picked})
	_paint_evidence()


func _row_for_line(line: int) -> int:
	# Display row of a 1-based line in the proposed file, or -1.
	if line <= 0: return -1
	for row in range(_diff_rows.size()):
		if int(_diff_rows[row].line) == line: return row
	return -1


func _line_for_row(row: int) -> int:
	return int(_diff_rows[row].line) if row >= 0 and row < _diff_rows.size() else 0


func _diffstat_text(stat: Dictionary) -> String:
	# A git-style bar: ten blocks split between additions and removals.
	var total: int = int(stat.added) + int(stat.removed)
	var plus: int = 0 if total == 0 else clampi(roundi(10.0 * stat.added / total), 1 if stat.added > 0 else 0, 10)
	return "%d file%s   [color=#6fdc8c]+%d[/color] [color=#e5384a]−%d[/color]   [color=#6fdc8c]%s[/color][color=#e5384a]%s[/color]   %d line%s changed" % [stat.files, "" if stat.files == 1 else "s", stat.added, stat.removed, "+".repeat(plus), "−".repeat(10 - plus if total > 0 else 0), total, "" if total == 1 else "s"]


## The slip's one-line summary of a standard as it reads on `day`.
func _rule_summary(rule: Dictionary, day: int) -> String:
	var id := str(rule.id)
	var text := str(RULE_SUMMARIES.get(id, rule.title))
	for amendment: Dictionary in rule.get("amendments", []):
		if int(amendment.day) <= day and RULE_SUMMARIES.has("%s@%d" % [id, int(amendment.day)]):
			text = str(RULE_SUMMARIES["%s@%d" % [id, int(amendment.day)]])
	return text


func _clear_evidence() -> void:
	_evidence = {}
	_paint_evidence()


func _flag_rule(rule_id: String) -> void:
	if _evidence.is_empty():
		# With nothing selected, a ticked rule can still be withdrawn.
		if rule_id in _state.get("selected_rules", []): _withdraw_citation(rule_id)
		else:
			var scope: String = Policy.scope(rule_id)
			notify("Select the PR's %s in %s first, then tick the standard." % [scope, "JIRO" if scope == "ticket" else "PIPELINE"] if scope in ["ticket", "build"] else "Select the offending line first (or WHOLE FILE), then tick the standard.", false, "review")
			render_state(_state)
		return
	var cited: Dictionary = _state.get("citation_evidence", {})
	var location: Dictionary = _evidence.duplicate()
	if rule_id in _state.get("selected_rules", []):
		_emit_command({"type": "toggle-rule", "rule_id": rule_id})
		if cited.get(rule_id, {}) == location:
			_clear_evidence()
			if rule_id not in _state.get("selected_rules", []): _banter.react("withdraw", _desk_lines("unflag", [rule_id], rule_id))
			return
	if location.has("record"):
		_emit_command({"type": "toggle-rule", "rule_id": rule_id, "record": str(location.record), "id": str(location.id)})
	else:
		_emit_command({"type": "toggle-rule", "rule_id": rule_id, "path": location.path, "line": int(location.line)})
	_clear_evidence()
	if rule_id in _state.get("selected_rules", []): _banter.react("flag", _desk_lines("flag", [rule_id], rule_id))


func _render_slip(state: Dictionary, can_review: bool) -> void:
	var day: int = int(state.get("day", 1))
	var cited: Dictionary = state.get("citation_evidence", {})
	if day != _slip_day:
		# Standards are reissued every second morning: some arrive, some are
		# amended, and retired ones leave the slip.
		_slip_day = day
		for rule: Dictionary in Catalog.rules_for_day(day):
			var id := str(rule.id)
			_slip_rows[id].summary.text = _rule_summary(rule, day)
			_flag_buttons[id].tooltip_text = "%s  %s\n\n%s\n\n%s" % [id, str(rule.title), str(rule.text), str(EVIDENCE_HINTS[load("res://content/policy_campaign.gd").scope(id)])]
	# The citation an author is pushing back on is outlined in amber until answered.
	var disputed: String = str(Encounters.pending(state).get("disputed", ""))
	for id: String in _slip_rows:
		var row: Dictionary = _slip_rows[id]
		var check: CheckBox = _flag_buttons[id]
		var location: Dictionary = cited.get(id, {})
		row.panel.visible = Catalog.rule_active(id, day)
		check.set_pressed_no_signal(not location.is_empty())
		check.disabled = not can_review
		row.where.visible = not location.is_empty()
		row.where.text = "" if location.is_empty() else "→ " + _location_text(location) + ("  · DISPUTED" if id == disputed else "")
		row.where.tooltip_text = row.where.text
		row.where.add_theme_color_override("font_color", AMBER if id == disputed else RED)
		row.summary.add_theme_color_override("font_color", TEXT if check.button_pressed else DIM)
		var edge: Color = AMBER if id == disputed else (RED if check.button_pressed else BORDER)
		row.panel.add_theme_stylebox_override("panel", _style(Color("1e0d10") if check.button_pressed else INSET, edge, 1, 6, 4))


func _withdraw_citation(rule_id: String) -> void:
	_emit_command({"type": "toggle-rule", "rule_id": rule_id})
	if rule_id not in _state.get("selected_rules", []): _banter.react("withdraw", _desk_lines("unflag", [rule_id], rule_id))


func _ask_helios() -> void:
	_emit_command({"type": "consult-ai"})
	if bool(_state.get("consulted", false)): _banter.react("consult", _desk_lines("consult"))


## INSIST or WITHDRAW, from the buttons under the author's pushback.
func _answer_pushback(choice: String) -> void:
	_emit_command({"type": "pushback", "choice": choice})


## The open PR's author's lines for a desk moment, in their current mood.
func _desk_lines(node: String, cited: Array = [], focus: String = "") -> Array:
	var request: Dictionary = Simulation.active_request(_state)
	if request.is_empty(): return []
	return Encounters.desk_lines(request, node, Encounters.mood(_state, str(request.get("author", ""))), cited, focus)


## Identity only (author and title), never audit data, for an encounter's words.
func _encounter_packet(pr_id: String, author: String) -> Dictionary:
	return {"id": pr_id, "author": author, "title": str(Catalog.packet(_state, pr_id, false).get("title", ""))}


## Play one encounter beat at the desk: a pushback with its buttons, a withdrawn
## citation, typing for a revise-now, or the author's goodbye.
func _play_beat(beat: Dictionary) -> void:
	var node := str(beat.get("node", ""))
	var author := str(beat.get("author", ""))
	var id := str(beat.get("pr_id", ""))
	var options: Array = Encounters.desk_lines(_encounter_packet(id, author), node, str(beat.get("mood", "neutral")), beat.get("cited", []), str(beat.get("disputed", "")))
	match node:
		"pushback": _banter.ask(author, id, options)
		"withdrawn": _banter.settle(author, options)
		"revise_now": _banter.start_typing(author, id, options)
		_: _banter.farewell(author, "approve" if node in Encounters.APPROVALS else "request_changes", id, options, node)


func _location_text(location: Dictionary) -> String:
	if location.has("record"):
		var id := str(location.get("id", ""))
		if str(location.record) == "ticket": return "NO TICKET" if id.is_empty() else "TICKET " + id
		return "BUILD " + id
	var name := str(location.get("path", "")).get_file()
	return ("FILE  " if int(location.get("line", 0)) == 0 else "LINE %d  " % int(location.line)) + name


func _paint_evidence() -> void:
	if not is_instance_valid(_diff) or not is_instance_valid(_evidence_label): return
	var path: String = _file_label.text
	var cited: Dictionary = _state.get("citation_evidence", {})
	for row in range(_diff.get_line_count()):
		var kind: String = str(_diff_rows[row].kind) if row < _diff_rows.size() else " "
		_diff.set_line_background_color(row, Color(GREEN, 0.07) if kind == "+" else Color(RED, 0.09) if kind == "-" else Color(0, 0, 0, 0))
	for rule_id: String in cited:
		var location: Dictionary = cited[rule_id]
		var cited_row := _row_for_line(int(location.get("line", 0)))
		if str(location.get("path", "")) == path and cited_row >= 0:
			_diff.set_line_background_color(cited_row, Color(RED, 0.26))
	# A record selected in Jiro or Pipeline is evidence whichever file is open.
	var pointing := not _evidence.is_empty() and (_evidence.has("record") or str(_evidence.get("path", "")) == path)
	var pointed_row := _row_for_line(int(_evidence.get("line", 0))) if not _evidence.has("record") else -1
	if pointing and pointed_row >= 0:
		_diff.set_line_background_color(pointed_row, Color(AMBER, 0.28))
	_whole_file.disabled = _review_files.is_empty()
	if _review_files.is_empty():
		_evidence_label.text = ""
		_selected_label.text = ""
	elif pointing:
		_evidence_label.text = "> %s selected" % _location_text(_evidence)
		_selected_label.text = "Tick the standard it breaks."
		_selected_label.add_theme_color_override("font_color", AMBER)
		_evidence_label.add_theme_color_override("font_color", AMBER)
	else:
		var day := int(_state.get("day", 1))
		_evidence_label.text = "Select a line, a PIPELINE build, a JIRO ticket, or" if app_installed("pipeline", day) else "Select a line, a JIRO ticket, or" if app_installed("jiro", day) else "Select the offending line, or"
		_selected_label.text = "Full text: INTRANET > STANDARDS"
		_selected_label.add_theme_color_override("font_color", DIM)
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


func _build_evening(page: VBoxContainer) -> void:
	# Closing time: Morgan, the day's notes, her closing words, and the evening.
	# Consequences stay in prose; there are no scores, pay, or grades here.
	var heading := _row(page, 14)
	_evening_face = Portraits.make("Morgan", 64)
	heading.add_child(_evening_face)
	var who := _column(heading, 2)
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	_label(who, "MORGAN", 16, CYAN)
	_label(who, "Engineering Manager", 12, DIM)
	_evening_when = _label(who, "", 12, AMBER)
	var rule := ColorRect.new()
	rule.color = BORDER
	rule.custom_minimum_size.y = 1
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(rule)
	var content: VBoxContainer = _scroll_column(page)
	_evening_notes_heading = _label(content, "TODAY", 11, DIM)
	_evening_notes = _column(content, 6)
	_evening_closing = _column(content, 8)
	_evening_buttons = _column(page, 4)
	_label(_evening_buttons, "TONIGHT", 11, DIM)
	var choices := _row(_evening_buttons, 8)
	for item: Dictionary in EVENINGS:
		# Each choice says what it does, under the button and on hover.
		var option := _column(choices, 4)
		var button := _button(option, str(item.label), _emit_command.bind({"type": "next-day", "choice": str(item.choice)}))
		button.custom_minimum_size.y = 40
		button.add_theme_font_size_override("font_size", 13)
		button.tooltip_text = str(item.about)
		var about := _paragraph(option, str(item.about), 12, DIM)
		about.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.set_meta("about", about)
	# On the final evening (or a firing), the way out is to watch how it ends,
	# then return to the menu. The cinematic card also offers the menu directly.
	_watch_ending = _button(page, "▶ SEE HOW IT ENDS", func() -> void: _play_ending())
	_watch_ending.custom_minimum_size.y = 40
	_watch_ending.add_theme_font_size_override("font_size", 13)
	_watch_ending.add_theme_stylebox_override("normal", _style(Color(AMBER, 0.08), AMBER, 1, 14, 6))
	_watch_ending.add_theme_stylebox_override("hover", _style(Color(AMBER, 0.2), Color("ffd27a"), 1, 14, 6))
	_watch_ending.add_theme_color_override("font_color", AMBER)
	_watch_ending.add_theme_color_override("font_hover_color", Color.WHITE)
	_watch_ending.tooltip_text = "Play the ending cinematic."
	_complete_button = _button(page, "RETURN TO MAIN MENU", func() -> void: menu_requested.emit())
	_complete_button.custom_minimum_size.y = 40
	_complete_button.add_theme_font_size_override("font_size", 13)
	_complete_button.add_theme_stylebox_override("normal", _style(Color(RED, 0.08), RED, 1, 14, 6))
	_complete_button.add_theme_stylebox_override("hover", _style(Color(RED, 0.2), Color("ff6b78"), 1, 14, 6))
	_complete_button.add_theme_color_override("font_color", RED)
	_complete_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_complete_button.tooltip_text = "Save and return to the main menu."
	_evening_buttons.hide()
	_complete_button.hide()
	_watch_ending.hide()


## Play the ending cinematic over the whole monitor, from the ending the run earned.
func _play_ending() -> void:
	if is_instance_valid(_ending_cinematic): return
	var key := str(_state.get("ending", ""))
	if key.is_empty() or not Endings.has(key): return
	var fired := key in ["player_fired", "team_fired"]
	_ending_cinematic = EndingCinematic.new()
	_ending_cinematic.setup(Endings.title(key), Endings.beats(key), Endings.morgan(key), fired)
	_ending_cinematic.z_index = 200
	_ending_cinematic.finished.connect(func() -> void:
		if is_instance_valid(_ending_cinematic):
			_ending_cinematic.queue_free()
			_ending_cinematic = null
		menu_requested.emit())
	_monitor_screen.add_child(_ending_cinematic)
	# The soundtrack follows: warm for the endings where people stood together.
	ending_music.emit(Endings.music_kind(key))


## Fill Morgan's panel from the shift that just closed (content/chat.gd `evening`).
func _render_evening(state: Dictionary) -> void:
	var phase := str(state.get("phase", "review"))
	var evening: Dictionary = Chat.evening(state)
	_evening_buttons.visible = phase == "debrief"
	_complete_button.visible = phase == "complete"
	var ending_key := str(state.get("ending", ""))
	_watch_ending.visible = phase == "complete" and Endings.has(ending_key)
	if _watch_ending.visible:
		var fired := ending_key in ["player_fired", "team_fired"]
		_watch_ending.text = ("▶ SEE WHY" if fired else "▶ SEE HOW IT ENDS")
	var key := phase + JSON.stringify(evening)
	if key == _evening_key: return
	_evening_key = key
	for holder: VBoxContainer in [_evening_notes, _evening_closing]:
		for child: Node in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	_evening_notes_heading.visible = not evening.get("notes", []).is_empty()
	if evening.is_empty():
		_evening_when.text = ""
		return
	_evening_when.text = day_label(int(evening.day)) + ("  ·  ASSIGNMENT CLOSED" if phase == "complete" else "  ·  18:00  ·  SHIFT CLOSED")
	for text: String in evening.notes:
		var note := PanelContainer.new()
		var bar := _style(INSET, AMBER, 0, 10, 7)
		bar.border_width_left = 3
		note.add_theme_stylebox_override("panel", bar)
		_evening_notes.add_child(note)
		_paragraph(note, text, 13, TEXT)
	for text: String in evening.closing:
		_paragraph(_evening_closing, text, 16, TEXT)
	var scroll := _evening_closing.get_parent().get_parent() as ScrollContainer
	if scroll != null: scroll.scroll_vertical = 0


func _process(delta: float) -> void:
	_sync_tutorial_pointer()
	if not _paused: _banter.tick(delta)


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and not _evidence.is_empty() and _windows.review.visible:
		_clear_evidence()
		get_viewport().set_input_as_handled()


# --- Jiro and Pipeline ---------------------------------------------------------
# Two more documents to check against the PR, like the papers at a border booth:
# its ticket in Jiro and its build in Pipeline. They show records only (what the
# ticket and build say), never whether a standard is broken. SELECT AS EVIDENCE
# picks a record for the citation slip, like clicking a line in Review.

## A link on the paper slip, in the slip's ink.
func _slip_link(parent: Node, action: Callable) -> LinkButton:
	var link := LinkButton.new()
	link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	link.focus_mode = Control.FOCUS_ALL
	link.add_theme_font_size_override("font_size", 12)
	for color_name: String in ["font_color", "font_focus_color"]:
		link.add_theme_color_override(color_name, PAPER_INK)
	for color_name: String in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		link.add_theme_color_override(color_name, STAMP_RED)
	link.pressed.connect(action)
	parent.add_child(link)
	return link


## The slip's links for the PR on the desk (none before Jiro, no build before Pipeline).
func _render_slip_refs(request: Dictionary) -> void:
	var day := int(_state.get("day", 1))
	_pr_refs.visible = not request.is_empty() and app_installed("jiro", day)
	if not _pr_refs.visible: return
	var ref := str(request.get("ticket_ref", ""))
	_ticket_link.text = ("Closes %s →" % ref) if not ref.is_empty() else "No ticket linked →"
	var build: Dictionary = request.get("build", {})
	_build_link.visible = app_installed("pipeline", day) and not build.is_empty()
	_build_link.text = "Build %s →" % str(build.get("id", ""))


## A record app's two columns: a scrolling list on the left, the record on the right.
func _record_columns(page: VBoxContainer) -> Array:
	var columns := _row(page, 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size.x = 250
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(list_scroll)
	var list := _column(list_scroll, 3)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style(INSET, BORDER, 1, 14, 12))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.size_flags_stretch_ratio = 1.6
	columns.add_child(card)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(detail_scroll)
	var detail := _column(detail_scroll, 8)
	return [list, detail]


func _record_row(parent: Node, text: String, pressed: bool, action: Callable) -> Button:
	var row := _button(parent, text, action)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.clip_text = true
	row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.custom_minimum_size = Vector2(0, 44)
	row.toggle_mode = true
	row.set_pressed_no_signal(pressed)
	row.add_theme_font_size_override("font_size", 12)
	row.add_theme_stylebox_override("pressed", _style(Color("1e1a0e"), AMBER, 1, 9, 7))
	return row


## A label: value line on a record card.
func _record_field(grid: GridContainer, name: String, value: String, color: Color = TEXT) -> Label:
	_label(grid, name, 11, DIM)
	var shown := _paragraph(grid, value, 13, color)
	shown.custom_minimum_size.x = 120
	return shown


func _evidence_button(parent: Node, record: String, id: String) -> Button:
	var chosen: bool = _evidence.get("record", "") == record and str(_evidence.get("id", "")) == id
	var button := _button(parent, "SELECTED AS EVIDENCE" if chosen else "SELECT AS EVIDENCE", _select_record.bind(record, id))
	button.custom_minimum_size.y = 32
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", AMBER)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(Color(AMBER, 0.12 if chosen else 0.06), AMBER, 1, 14, 6))
	button.add_theme_stylebox_override("hover", _style(Color(AMBER, 0.22), Color("f2cf7a"), 1, 14, 6))
	var on_desk := not Simulation.active_request(_state).is_empty() and Encounters.pending(_state).is_empty()
	button.disabled = not on_desk
	button.tooltip_text = "Point your citation at this %s, then tick the standard it breaks on the slip in REVIEW." % record if on_desk else "There is no PR on your desk to cite."
	return button


## Which of the player's own citations point at this record (never the audit's).
func _cited_note(parent: Node, record: String, id: String) -> void:
	var cited: Array = []
	for rule_id: String in _state.get("citation_evidence", {}):
		var location: Dictionary = _state.citation_evidence[rule_id]
		if location.get("record", "") == record and str(location.get("id", "")) == id: cited.append(rule_id)
	if not cited.is_empty(): _label(parent, "You cited this for " + ", ".join(cited), 11, RED)


## A record card's top line: its ID and status on the left, SELECT AS EVIDENCE on
## the right, so the control is always in view however long the record is.
func _record_head(parent: Node, record: String, id: String, title: String, status: String, color: Color) -> void:
	var head := _row(parent, 10)
	var name := _label(head, title, 13, CYAN)
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not status.is_empty():
		var shown := _label(head, status, 12, color)
		shown.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_spacer(head)
	_evidence_button(head, record, id)
	_cited_note(parent, record, id)


## Pick a record as the evidence for the next tick on the slip, and bring Review up.
func _select_record(record: String, id: String) -> void:
	if str(_state.get("phase", "")) != "review" or Simulation.active_request(_state).is_empty(): return
	_evidence = {"record": record, "id": id}
	_open_app("review")
	_paint_evidence()
	_render_records(true)


func _build_jiro(page: VBoxContainer) -> void:
	var bar := _row(page, 6)
	_jiro_search = LineEdit.new()
	_jiro_search.placeholder_text = "Search by ticket ID (PAPER-412) or words"
	_jiro_search.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jiro_search.add_theme_font_size_override("font_size", 13)
	_jiro_search.clear_button_enabled = true
	_jiro_search.text_changed.connect(func(_text: String) -> void: _render_jiro_list())
	_jiro_search.text_submitted.connect(_jiro_find)
	bar.add_child(_jiro_search)
	var find := _button(bar, "FIND", func() -> void: _jiro_find(_jiro_search.text))
	find.add_theme_font_size_override("font_size", 12)
	var mine := _button(bar, "THIS PR'S TICKET", _open_desk_ticket)
	mine.add_theme_font_size_override("font_size", 12)
	mine.tooltip_text = "Show the ticket linked on the slip of the PR on your desk."
	var parts := _record_columns(page)
	_jiro_list = parts[0]
	_jiro_detail = parts[1]


## Jiro's view of the desk PR's link: its ticket, or a card saying Jiro has none.
func _desk_ticket_view() -> Dictionary:
	var request: Dictionary = Simulation.active_request(_state)
	if request.is_empty(): return {}
	var ref := str(request.get("ticket_ref", ""))
	return {"ticket": ref} if not Catalog.ticket(_state, ref).is_empty() else {"link": ref}


## Open Jiro on the desk PR's link (the ticket on its slip).
func _open_desk_ticket() -> void:
	if Simulation.active_request(_state).is_empty() or not app_installed("jiro", int(_state.get("day", 1))): return
	_jiro_view = _desk_ticket_view()
	_jiro_search.text = ""
	_open_app("jiro")


## FIND: an exact ticket ID opens it; the desk PR's own broken link opens its card.
func _jiro_find(text: String) -> void:
	var wanted := text.strip_edges().to_upper()
	var request: Dictionary = Simulation.active_request(_state)
	if not Catalog.ticket(_state, wanted).is_empty(): _jiro_view = {"ticket": wanted}
	elif not wanted.is_empty() and wanted == str(request.get("ticket_ref", "")): _jiro_view = {"link": wanted}
	else:
		var matches: Array = _jiro_matches()
		_jiro_view = {"ticket": str(matches[0].id)} if matches.size() == 1 else {"none": wanted}
	_render_records(true)


func _jiro_matches() -> Array:
	var wanted := _jiro_search.text.strip_edges().to_lower()
	if wanted.is_empty(): return _jiro_tickets
	return _jiro_tickets.filter(func(ticket: Dictionary) -> bool: return wanted in str(ticket.id).to_lower() or wanted in str(ticket.title).to_lower())


func _render_jiro_list() -> void:
	for child: Node in _jiro_list.get_children():
		_jiro_list.remove_child(child)
		child.queue_free()
	var shown: Array = _jiro_matches()
	_label(_jiro_list, "%d TICKET%s" % [shown.size(), "" if shown.size() == 1 else "S"], 11, DIM)
	for ticket: Dictionary in shown:
		var id := str(ticket.id)
		var row := _record_row(_jiro_list, "%s  ·  %s\n%s  ·  %s" % [id, ticket.status, ticket.assignee, ticket.title], _jiro_view.get("ticket", "") == id, func() -> void:
			_jiro_view = {"ticket": id}
			_render_records(true))
		row.tooltip_text = "%s  %s" % [id, ticket.title]


func _render_jiro_detail() -> void:
	for child: Node in _jiro_detail.get_children():
		_jiro_detail.remove_child(child)
		child.queue_free()
	var request: Dictionary = Simulation.active_request(_state)
	var ticket: Dictionary = {}
	for listed: Dictionary in _jiro_tickets:
		if _jiro_view.has("ticket") and str(listed.id) == str(_jiro_view.ticket): ticket = listed
	if not ticket.is_empty():
		_record_head(_jiro_detail, "ticket", str(ticket.id), str(ticket.id), str(ticket.status).to_upper(), STATUS_COLORS.get(str(ticket.status), DIM))
		_paragraph(_jiro_detail, str(ticket.title), 17, TEXT)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 4)
		_jiro_detail.add_child(grid)
		_record_field(grid, "STATUS", str(ticket.status), STATUS_COLORS.get(str(ticket.status), DIM))
		_record_field(grid, "ASSIGNEE", str(ticket.assignee))
		_record_field(grid, "COMPONENT", str(ticket.component))
		_record_field(grid, "REPORTER", str(ticket.reporter))
		_record_field(grid, "PRIORITY", str(ticket.priority))
		_record_field(grid, "OPENED", str(ticket.opened).trim_prefix("opened "))
		if not ticket.get("watchers", []).is_empty(): _record_field(grid, "WATCHERS", ", ".join(ticket.watchers))
		_record_field(grid, "LINKED PRS", ", ".join(ticket.get("linked", [])) if not ticket.get("linked", []).is_empty() else "none")
		if not str(ticket.get("resolution", "")).is_empty(): _paragraph(_jiro_detail, str(ticket.resolution), 13, AMBER)
		_paragraph(_jiro_detail, str(ticket.description), 14, TEXT)
		for line: String in ticket.get("history", []): _paragraph(_jiro_detail, "· " + line, 12, DIM)
	elif _jiro_view.has("link") and not request.is_empty() and str(_jiro_view.link) == str(request.get("ticket_ref", "")):
		# The desk PR's link, when Jiro has nothing to show for it.
		var ref := str(_jiro_view.link)
		_record_head(_jiro_detail, "ticket", ref, "NO TICKET LINKED" if ref.is_empty() else ref, "", DIM)
		_paragraph(_jiro_detail, ("%s's slip has no Closes line. It links no ticket." % Catalog.display_id(str(request.id))) if ref.is_empty() else ("Jiro has no ticket %s. %s links it anyway." % [ref, Catalog.display_id(str(request.id))]), 15, TEXT)
	elif _jiro_view.has("none"):
		_paragraph(_jiro_detail, "Jiro has no ticket matching %s." % str(_jiro_view.none) if not str(_jiro_view.none).is_empty() else "Type a ticket ID to find it.", 14, DIM)
	else:
		_paragraph(_jiro_detail, "Pick a ticket on the left, or click the ticket on the PR slip in REVIEW to open the PR's own.", 14, DIM)


func _build_pipeline(page: VBoxContainer) -> void:
	var bar := _row(page, 6)
	_label(bar, "RECENT BUILDS, NEWEST FIRST", 11, DIM)
	_spacer(bar)
	var mine := _button(bar, "THIS PR'S BUILD", _open_desk_build)
	mine.add_theme_font_size_override("font_size", 12)
	mine.tooltip_text = "Show the build of the PR on your desk."
	var parts := _record_columns(page)
	_pipeline_list = parts[0]
	_pipeline_detail = parts[1]


func _open_desk_build() -> void:
	var request: Dictionary = Simulation.active_request(_state)
	if request.is_empty() or not app_installed("pipeline", int(_state.get("day", 1))): return
	_pipeline_build = str(request.get("build", {}).get("id", ""))
	_open_app("pipeline")


func _render_pipeline() -> void:
	for holder: VBoxContainer in [_pipeline_list, _pipeline_detail]:
		for child: Node in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	for build: Dictionary in _pipeline_builds:
		var id := str(build.id)
		var status := Records.status_text(build)
		_record_row(_pipeline_list, "%s  ·  %s\n%s  ·  %s" % [id, status, Catalog.display_id(str(build.pr_id)), build.branch], id == _pipeline_build, func() -> void:
			_pipeline_build = id
			_render_records(true))
	if _pipeline_builds.is_empty(): _paragraph(_pipeline_list, "No builds yet today.", 13, DIM)
	var shown: Dictionary = {}
	for build: Dictionary in _pipeline_builds:
		if str(build.id) == _pipeline_build: shown = build
	if shown.is_empty():
		_paragraph(_pipeline_detail, "Pick a build on the left, or click the build on the PR slip in REVIEW to open the PR's own.", 14, DIM)
		return
	_record_head(_pipeline_detail, "build", str(shown.id), "BUILD " + str(shown.id), Catalog.display_id(str(shown.pr_id)), DIM)
	_label(_pipeline_detail, "%s @ %s · %s" % [shown.branch, shown.commit, shown.duration], 12, DIM)
	var status := Records.status_text(shown)
	var color: Color = AMBER if str(shown.get("override", "")) == "helios" else STATUS_COLORS.get(status, TEXT)
	_label(_pipeline_detail, status, 20, color)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	_pipeline_detail.add_child(grid)
	_record_field(grid, "RERUNS", str(int(shown.reruns)))
	_record_field(grid, "COVERAGE", "%s → %s" % [Records.coverage_text(int(shown.coverage_before)), Records.coverage_text(int(shown.coverage_after))])
	_label(_pipeline_detail, "TESTS", 11, DIM)
	for test: Dictionary in shown.tests:
		var line := _row(_pipeline_detail, 8)
		var result := str(test.result)
		_label(line, {"pass": "pass ", "fail": "FAIL ", "flaky": "flaky"}.get(result, result), 12, {"pass": GREEN, "fail": RED, "flaky": AMBER}.get(result, DIM))
		var name := _label(line, str(test.name), 12, TEXT)
		name.clip_text = true
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not shown.log.is_empty():
		_label(_pipeline_detail, "LOG", 11, DIM)
		var log_panel := PanelContainer.new()
		log_panel.add_theme_stylebox_override("panel", _style(Color("030304"), BORDER, 1, 10, 8))
		_pipeline_detail.add_child(log_panel)
		_paragraph(log_panel, "\n".join(shown.log), 12, Color("b9b5aa"))


## Refresh Jiro and Pipeline while they're on screen, when what they show changes
## (new arrivals, a new PR on the desk, a citation), or right away when the player
## opens or navigates them (`force`). Closed or minimized, they don't render at all.
func _render_records(force: bool = false) -> void:
	var day := int(_state.get("day", 1))
	var desk := str(Simulation.active_request(_state).get("id", ""))
	var data := "%d|%s|%d|%s" % [day, _state.get("phase", ""), _state.get("arrivals", []).size(), desk]
	var marks := JSON.stringify([_state.get("citation_evidence", {}), _evidence, Encounters.pending(_state).is_empty()])
	if app_installed("jiro", day) and (force or _windows.jiro.visible):
		var list_key := data + "|" + JSON.stringify(_jiro_view)
		if force or list_key != _jiro_list_key:
			_jiro_list_key = list_key
			_jiro_tickets = Catalog.tickets(_state)
			_render_jiro_list()
		if force or list_key + marks != _jiro_key:
			_jiro_key = list_key + marks
			_render_jiro_detail()
	if app_installed("pipeline", day) and (force or _windows.pipeline.visible) and (force or data + _pipeline_build + marks != _pipeline_key):
		_pipeline_key = data + _pipeline_build + marks
		_pipeline_builds = Catalog.builds(_state).filter(func(build: Dictionary) -> bool: return int(build.day) == day)
		_render_pipeline()


func _build_system(page: VBoxContainer) -> void:
	var content: VBoxContainer = _scroll_column(page)
	_label(content, "LOCAL RECORD", 16, CYAN)
	_save_slot_label = _label(content, "Current save: Slot 1", 14, CYAN)
	_system_status = _paragraph(content, "Local storage is ready.", 14, CYAN)
	_paragraph(content, "Three local save slots. New Game and Load Game on the main menu let you choose a slot. Each shift lasts %d real minutes, from 09:00 to 18:00. Time runs while you read code and intranet pages. Pause with Esc or the desktop clock control. Switching away pauses automatically." % (Catalog.shift_seconds() / 60), 14, DIM)
	var saves: HBoxContainer = _row(content)
	_button(saves, "SAVE RUN", func() -> void: save_requested.emit())
	_button(saves, "LOAD RUN", func() -> void: load_requested.emit())
	_button(saves, "NEW RUN", func() -> void: _confirmation.popup_centered())
	_button(content, "SAVE AND MAIN MENU", func() -> void: menu_requested.emit())
	_build_sound_settings(content)
	_label(content, "REVIEW PROCEDURE", 16, CYAN)
	_paragraph(content, "1. Read the author's note and the code diff.\n2. In REVIEW, click or select each violating line (or WHOLE FILE for file and whole-PR standards) and pick the standard it breaks. For ticket and build standards, open the PR's ticket in JIRO or its build in PIPELINE from the PR slip, SELECT AS EVIDENCE, then pick the standard. Full standards: INTRANET > STANDARDS. They change every second morning.\n3. Approve with no citations, or request changes with citations.\n4. The author answers at your desk: thanks, a revision, or pushback (INSIST or WITHDRAW).\n\nYour desk holds one PR at a time. Stamp it and the next lands a moment later; REVIEW shows a badge and a notification when it does. A PR you send back returns as a revision after a couple of others. AI advice is optional and fallible. At 18:00, Helios takes unfinished work and Morgan's end-of-day note opens. Choose your evening there to wrap up the day.", 14, DIM)


## SOUND: the soundtrack's on/off toggle and volume, kept on this computer.
func _build_sound_settings(content: VBoxContainer) -> void:
	_label(content, "SOUND", 16, CYAN)
	var row: HBoxContainer = _row(content, 12)
	_music_toggle = Button.new()
	_music_toggle.toggle_mode = true
	_music_toggle.button_pressed = true
	_music_toggle.text = "MUSIC: ON"
	_music_toggle.custom_minimum_size = Vector2(130, 35)
	_music_toggle.toggled.connect(func(on: bool) -> void:
		_show_music_enabled(on)
		music_toggled.emit(on))
	row.add_child(_music_toggle)
	_label(row, "VOLUME", 14, DIM).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_music_volume = HSlider.new()
	_music_volume.min_value = 0.0
	_music_volume.max_value = 1.0
	_music_volume.step = 0.05
	_music_volume.value = 0.7
	_music_volume.custom_minimum_size = Vector2(150, 24)
	_music_volume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_music_volume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_music_volume.tooltip_text = "Soundtrack volume."
	_music_volume.add_theme_stylebox_override("slider", _style(INSET, BORDER, 1, 0, 3))
	_music_volume.add_theme_stylebox_override("grabber_area", _style(Color("1f4a2b"), Color.TRANSPARENT, 0, 0, 3))
	_music_volume.add_theme_stylebox_override("grabber_area_highlight", _style(Color("2c6b3d"), Color.TRANSPARENT, 0, 0, 3))
	_music_volume.value_changed.connect(func(value: float) -> void: music_volume_changed.emit(value))
	row.add_child(_music_volume)


func set_music_settings(enabled: bool, volume: float) -> void:
	_music_toggle.set_pressed_no_signal(enabled)
	_music_volume.set_value_no_signal(volume)
	_show_music_enabled(enabled)


func _show_music_enabled(on: bool) -> void:
	_music_toggle.text = "MUSIC: ON" if on else "MUSIC: OFF"
	_music_volume.editable = on


func set_save_slot(slot: int) -> void:
	_save_slot_label.text = "Current save: Slot %d · stored on this computer" % slot


func _emit_command(command: Dictionary) -> void:
	command_requested.emit(command)


func _clear_citations() -> void:
	var selected: Array = _state.get("selected_rules", []).duplicate()
	for rule_id: String in selected:
		_emit_command({"type": "toggle-rule", "rule_id": rule_id})
	if not selected.is_empty() and _state.get("selected_rules", []).is_empty(): _banter.react("withdraw", _desk_lines("unflag", selected))


func render_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	render_clock(state)
	var day: int = int(state.get("day", 1))
	var phase: String = str(state.get("phase", "review"))
	var selected: Array = state.get("selected_rules", [])
	var consulted: bool = bool(state.get("consulted", false))
	var active_request: Dictionary = Simulation.active_request(state)
	# An author pushing back holds the review until INSIST or WITHDRAW; an author
	# revising at the desk keeps their seat until v2 replaces the PR.
	var pending: Dictionary = Encounters.pending(state)
	var typing: Dictionary = Encounters.typing(state)
	var can_review: bool = phase == "review" and not active_request.is_empty() and pending.is_empty()
	_consult.visible = day >= 3
	_ai_note.visible = _consult.visible
	_hud["day"].text = day_label(day)
	_sync_installed_apps(day)
	if day != _last_day:
		_last_day = day
		var briefing: String = Catalog.briefing(day)
		_briefing_dialog.dialog_text = briefing
		if _browser_path in ["memo", "news", "standards"] or _browser_path.begins_with("story/"):
			_browse("news" if _browser_path.begins_with("story/") else _browser_path, false)
	_render_slip(state, can_review)
	_paint_evidence()
	_clear_button.disabled = selected.is_empty() or not can_review
	_approve.disabled = not selected.is_empty() or not can_review
	_approve.tooltip_text = "Clear citations before approving." if not selected.is_empty() else "Approve this pull request."
	# CHANGES REQUESTED works with or without citations: with none, it is a
	# deliberate, unexplained rejection, and the author will want to know why.
	_reject.disabled = not can_review
	_reject.tooltip_text = "Request changes for every cited rule." if not selected.is_empty() else "Send it back. With no citation, this is a rejection with no reason given."
	_consult.disabled = consulted or not can_review
	_render_evening(state)
	if phase != _last_phase:
		var previous_phase: String = _last_phase
		_last_phase = phase
		if not previous_phase.is_empty():
			_windows["review"].minimize_window()
		if phase == "review":
			_windows["evening"].close_window()
		else:
			# The shift is over: Morgan's end-of-day panel is the one window
			# that opens by itself. Loading an evening save opens it too.
			_open_app("evening")
		_update_dock()
	if phase != "review":
		# Off the clock the desk is closed; REVIEW still opens, and says so.
		_last_pr = ""
		_pr_id.text = "REVIEW / " + ("SHIFT CLOSED" if phase == "debrief" else "ASSIGNMENT CLOSED")
		_pr_title.text = "The desk is closed until morning" if phase == "debrief" else "The desk is closed"
		_file_label.text = ""
		if not _review_files.is_empty() or not _diff.text.is_empty():
			_set_review_files({})
	if phase == "review":
		# Deliberately never read audit-only violations or explanation here.
		var request: Dictionary = active_request
		var request_id: String = str(request.get("id", ""))
		if request.is_empty():
			_last_pr = ""
			_pr_id.text = "REVIEW / DESK CLEAR"
			_pr_title.text = "Your desk is clear"
			_pr_context.text = "Work lands here by itself, one PR at a time. Check every file against today’s policies."
			_file_label.text = ""
			if not typing.is_empty():
				_pr_id.text = "%s / BEING REVISED" % Catalog.display_id(str(typing.revision_id))
				_pr_title.text = "%s is revising it at your desk" % str(typing.author)
			if not _review_files.is_empty() or not _diff.text.is_empty():
				_set_review_files({})
		if not request_id.is_empty() and request_id != _last_pr:
			_last_pr = request_id
			# Jiro and Pipeline open on the new PR's own records next time.
			_jiro_view = {}
			_pipeline_build = ""
			_pr_id.text = "%s / AWAITING REVIEW" % Catalog.display_id(request_id)
			_pr_title.text = str(request.get("title", ""))
			_pr_context.text = "%s: %s\n\n%s" % [str(request.get("author", "")), str(request.get("message", "")), str(request.get("description", ""))]
			_set_review_files(request)
			_clear_evidence()
			_packet_scroll.scroll_vertical = 0
			var arrival: Dictionary = Encounters.arrival(state, request)
			_banter.open_pr(request_id, str(request.get("author", "")), int(request.get("revision", 1)), Encounters.desk_lines(request, str(arrival.node), str(arrival.mood), arrival.cited), str(arrival.node))
		if not request_id.is_empty():
			_pr_id.text = "%s / %s" % [Catalog.display_id(request_id), "PUSHED BACK" if not pending.is_empty() else "AWAITING REVIEW"]
		_ai_note.text = "Helios can take a look. Its advice may be wrong, and using it gives the assistant more influence."
		if consulted:
			_ai_note.text = "AI: %s\n%s" % [str(request.get("ai_verdict", "")).replace("_", " ").to_upper(), str(request.get("ai_note", ""))]
	if active_request.is_empty() and typing.is_empty(): _banter.close_pr()
	_render_slip_refs(active_request)
	var feedback: Dictionary = state.get("last_feedback", {})
	var feedback_key := "" if feedback.is_empty() else str(feedback.get("pr_id", "")) + str(feedback.get("verdict", ""))
	if feedback_key != _last_feedback_key:
		if _last_feedback_key != "-" and not feedback_key.is_empty():
			_play_stamp(str(feedback.get("verdict", "")))
		_last_feedback_key = feedback_key
	# The author answers through the encounter: mood and what you did, never whether
	# you were right. History already on record when the desk first renders stays quiet.
	var encounters: Array = state.get("encounters", [])
	if _beats_seen < 0 or encounters.size() < _beats_seen: _beats_seen = encounters.size()
	for index in range(_beats_seen, encounters.size()): _play_beat(encounters[index])
	_beats_seen = encounters.size()
	if not pending.is_empty() and not _banter.asking: _play_beat(pending)
	if not typing.is_empty() and not _banter.typing:
		_banter.start_typing(str(typing.author), str(typing.pr_id), Encounters.desk_lines(_encounter_packet(str(typing.pr_id), str(typing.author)), "revise_now", str(typing.mood), typing.cited))
	_feedback.text = "No review sent yet." if feedback.is_empty() else "%s · %s sent to %s." % [Catalog.display_id(str(feedback.get("pr_id", ""))), "Approval" if feedback.get("verdict") == "approve" else "Change request", str(feedback.get("author", ""))]
	if not pending.is_empty():
		_feedback.text = "%s · %s is pushing back on %s. INSIST or WITHDRAW." % [Catalog.display_id(str(pending.pr_id)), str(pending.author), Encounters.noun(str(pending.get("disputed", "")))]
	_sync_app_events()
	_render_records()


func _ambient_push(app: String, text: String, target: String = "", person: String = "") -> void:
	# Orientation stays quiet: only direct guidance and errors reach the ticker.
	if not _tutorial_active: _notifications.push(app, text, target, false, person)


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
	# Morgan's end-of-day panel opens by itself and carries no badge.
	if not is_instance_valid(_notifications) or not _app_counts.has(app): return
	# Looking at Review reads the PR on the desk.
	if app == "review": _unread_requests.clear()
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
	# A day's memo and standards are news on its morning, not in its evening.
	if day != _notification_day and _state.get("phase") == "review":
		_notification_day = day
		# Every second morning the standards are reissued: added, amended, or retired.
		var changes: Dictionary = Catalog.rule_changes(day)
		var changed: bool = not (changes.added.is_empty() and changes.amended.is_empty() and changes.retired.is_empty())
		if changed and not _app_is_reading("browser"):
			_app_counts.browser += 1
			_ambient_push("browser", "New standards are posted on the intranet." if changes.amended.is_empty() and changes.retired.is_empty() else "The standards have changed. Read the intranet before you sign anything.", "standards")
		if not _app_is_reading("browser"):
			_app_counts.browser += 1
			_ambient_push("browser", "A new daily memo is on the intranet.", "memo")
	# The desk holds one PR; its badge reads 1 until the player looks at Review.
	var desk: Dictionary = Simulation.active_request(_state)
	var desk_id := str(desk.get("id", ""))
	if not desk_id.is_empty() and not _known_requests.has(desk_id):
		_known_requests[desk_id] = true
		if not _app_is_reading("review"):
			_unread_requests[desk_id] = true
			_ambient_push("review", _desk_card_text(desk), desk_id, str(desk.author))
	for id: String in _unread_requests.keys():
		if id != desk_id:
			_unread_requests.erase(id)
			_notifications.clear_app("review", id)
	_app_counts.review = _unread_requests.size()
	_update_app_badges()


## The review card for the PR on the desk: its number, author, and title.
func _desk_card_text(desk: Dictionary) -> String:
	return "%s from %s: %s" % [Catalog.display_id(str(desk.id)), str(desk.author), str(desk.title)]


func _open_notification(app: String, target: String) -> void:
	if _paused: return
	# A review card always opens Review: the desk holds one PR, the one there now.
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
	_tutorial_panel.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_tutorial_panel.tooltip_text = "Drag to move these instructions."
	_tutorial_panel.gui_input.connect(_tutorial_drag_input)
	_tutorial_panel.hide()
	_monitor_screen.add_child(_tutorial_panel)
	var box := _column(_tutorial_panel, 6)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	var heading := _row(box, 8)
	heading.mouse_filter = Control.MOUSE_FILTER_PASS
	_tutorial_title = _label(heading, "ORIENTATION", 12, RED)
	_spacer(heading)
	var fold := _button(heading, "−", func() -> void:
		_tutorial_body.visible = not _tutorial_body.visible
		_tutorial_next.visible = _tutorial_body.visible and int(_tutorial_details.get("stage", 0)) in [Tutorial.STAGE_WELCOME, Tutorial.STAGE_READY]
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
	_banter.quiet = _tutorial_active
	if starting:
		for app: String in _app_counts: _notifications.clear_app(app)
	_update_app_badges()
	_tutorial_details = progress.duplicate(true)
	_tutorial_panel.visible = _tutorial_active
	if not _tutorial_active: return
	_tutorial_title.text = str(prompt.title)
	_tutorial_body.text = str(prompt.body)
	if step_changed: _tutorial_body.show()
	_tutorial_next.visible = _tutorial_body.visible and int(progress.stage) in [Tutorial.STAGE_WELCOME, Tutorial.STAGE_READY]
	_tutorial_next.text = "START MONDAY" if int(progress.stage) == Tutorial.STAGE_READY else "START ORIENTATION"
	if not _tutorial_dragged: _tutorial_panel.position = Vector2(maxf(0, _monitor_screen.size.x - 450), 48)
	_tutorial_panel.size.x = 430
	_fit_tutorial.call_deferred()
	_clock_label.text = "TRAINING"
	_hud["day"].text = "ORIENTATION"


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
			Tutorial.STAGE_WELCOME, Tutorial.STAGE_READY: target = _tutorial_next
			# Maya's practice PR is already on the desk: straight to REVIEW.
			Tutorial.STAGE_OPEN_REVIEW: target = _tutorial_launcher("review")
			Tutorial.STAGE_INSPECT: target = _file_picker if _windows.review.visible and _windows.review._active else _tutorial_launcher("review")
			Tutorial.STAGE_STANDARDS: target = _standards_link if _windows.browser.visible and _windows.browser._active else _tutorial_launcher("browser")
			Tutorial.STAGE_CITE:
				var id := "P01"
				if id not in _state.get("selected_rules", []):
					if _windows.review.visible and _windows.review._active:
						# Practice only: guide to the visible comment, never to hidden audit data.
						var evidence := _practice_evidence(id)
						var pointed: bool = not _evidence.is_empty() and not evidence.is_empty() and _evidence.get("path", "") == evidence.path and int(_evidence.get("line", -1)) == int(evidence.line)
						if pointed: target = _flag_buttons[id]
						elif evidence.is_empty() or _file_label.text != evidence.path: target = _file_picker
						else: target = _diff
					else: target = _tutorial_launcher("review")
				else: target = _reject if _windows.review.visible and _windows.review._active else _tutorial_launcher("review")
	# Once the player places the panel, it stays where they put it.
	if not _tutorial_dragged and is_instance_valid(target) and target != _tutorial_next and _tutorial_panel.get_global_rect().intersects(target.get_global_rect()):
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


func _tutorial_drag_input(event: InputEvent) -> void:
	# Drag anywhere on the panel that isn't a button.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_tutorial_dragging = event.pressed
		_tutorial_drag_offset = event.position
		_tutorial_panel.accept_event()
	elif event is InputEventMouseMotion and _tutorial_dragging:
		_tutorial_dragged = true
		_tutorial_panel.position += event.position - _tutorial_drag_offset
		_clamp_tutorial()
		_tutorial_panel.accept_event()


func _clamp_tutorial() -> void:
	var limit := (_monitor_screen.size - _tutorial_panel.size).max(Vector2.ZERO)
	_tutorial_panel.position = _tutorial_panel.position.clamp(Vector2.ZERO, limit)


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
