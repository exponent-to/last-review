extends Control
## Local narrative title sequence. It never loads game data or contacts a service.

signal finished

const FONT_PATH := "res://art/fonts/IBMPlexMono-Regular.ttf"
const DURATION := 10.4
const LINE_STARTS := [0.35, 1.55, 2.85, 4.55, 6.35, 8.25]
const LINES := [
	"Local review workspace initialized.",
	"Reviewer identity confirmed.",
	"Every change requires your judgment.",
	"HELIOS: I'll take care of the routine work.",
	"HELIOS: You can focus on what matters.",
	"Review authority updated: assisted.",
]
const INK := Color("c9d8e2")
const MUTED := Color("7e96ac")
const CYAN := Color("8ed7df")

var _elapsed := 0.0
var _motion := true
var _paused := false
var _completed := false
var _final_revealed := false
var _lines: Array[Label] = []
var _title: Label
var _subtitle: Label
var _authority: Label
var _role: Label
var _hint: Label
var _skip: Button
var _begin: Button


func _init() -> void:
	custom_minimum_size = Vector2(1120, 800)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var intro_theme := Theme.new()
	if ResourceLoader.exists(FONT_PATH):
		intro_theme.default_font = load(FONT_PATH)
	intro_theme.default_font_size = 16
	intro_theme.set_color("font_color", "Label", INK)
	theme = intro_theme
	_build()
	_skip.grab_focus()
	_refresh()
	_sync_processing()


func set_motion(enabled: bool) -> void:
	_motion = enabled
	if not enabled:
		_elapsed = DURATION
	if is_node_ready():
		_refresh()
	_sync_processing()


func set_paused(paused: bool) -> void:
	_paused = paused
	_sync_processing()


func _sync_processing() -> void:
	set_process(not _completed and not _paused and _motion and _elapsed < DURATION)


func _process(delta: float) -> void:
	if _completed or _paused or not _motion:
		return
	_elapsed = minf(_elapsed + minf(delta, 0.1), DURATION)
	_refresh()
	_sync_processing()


func _input(event: InputEvent) -> void:
	if _completed or not is_visible_in_tree():
		return
	if event is InputEventKey:
		# Keep onboarding shortcuts and keyboard focus inside the intro.
		get_viewport().set_input_as_handled()
		if not event.pressed or event.echo:
			return
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
			_complete()
		elif event.keycode == KEY_TAB and is_instance_valid(_skip):
			if _final_revealed and not _begin.has_focus():
				_begin.grab_focus()
			else:
				_skip.grab_focus()
		elif event.keycode == KEY_SPACE:
			if _skip.has_focus() or (_final_revealed and _begin.has_focus()):
				_complete()


func _unhandled_input(_event: InputEvent) -> void:
	if not _completed and is_visible_in_tree():
		get_viewport().set_input_as_handled()


func _complete() -> void:
	if _completed:
		return
	_completed = true
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	if is_instance_valid(_skip):
		_skip.disabled = true
		_skip.release_focus()
	if is_instance_valid(_begin):
		_begin.disabled = true
		_begin.release_focus()
	# Parent owns disposal and the transition to its existing game interface.
	finished.emit()


func _refresh() -> void:
	if _lines.is_empty():
		return
	for index in range(LINES.size()):
		var character_count := maxi(0, int((_elapsed - LINE_STARTS[index]) * 42.0))
		_lines[index].visible_characters = mini(character_count, LINES[index].length())
	var assisted := _elapsed >= 8.25
	_authority.text = "ASSISTED" if assisted else "HUMAN"
	_authority.add_theme_color_override("font_color", CYAN if assisted else INK)
	_role.text = "HELIOS / WORKFLOW SUPPORT" if _elapsed >= 4.55 else "HELIOS / ADVISORY ONLY"
	if _elapsed >= DURATION and not _final_revealed:
		_final_revealed = true
		_title.modulate = Color.WHITE
		_subtitle.text = "Your judgment is still required."
		_hint.text = "ENTER — BEGIN SHIFT   /   ESC — SKIP"
		_begin.show()
		_begin.grab_focus()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("0b1421")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 72)
	margin.add_theme_constant_override("margin_top", 48)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	margin.add_child(column)

	var masthead := HBoxContainer.new()
	column.add_child(masthead)
	masthead.add_child(_label("HELIOS / ENGINEERING OPERATIONS", 15, CYAN))
	var masthead_space := Control.new()
	masthead_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masthead.add_child(masthead_space)
	masthead.add_child(_label("INTERNAL // LOCAL SESSION", 13, MUTED))
	column.add_child(_gap(20))
	column.add_child(_rule())
	column.add_child(_gap(46))
	column.add_child(_label("REVIEWER ONBOARDING", 14, MUTED))
	column.add_child(_gap(12))
	_title = _label("LAST REVIEW", 72, INK)
	_title.modulate = Color("8195a8")
	column.add_child(_title)
	_subtitle = _label("A place for human judgment.", 19, MUTED)
	column.add_child(_subtitle)
	column.add_child(_gap(38))

	var terminal := HBoxContainer.new()
	terminal.add_theme_constant_override("separation", 30)
	column.add_child(terminal)
	var output := VBoxContainer.new()
	output.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output.add_theme_constant_override("separation", 13)
	terminal.add_child(output)
	output.add_child(_label("SESSION RECORD", 12, MUTED))
	output.add_child(_gap(4))
	for index in range(LINES.size()):
		var line := _label(LINES[index], 17, CYAN if index in [3, 4] else INK)
		line.custom_minimum_size.y = 23
		line.visible_characters = 0
		line.clip_text = true
		output.add_child(line)
		_lines.append(line)

	var divider := ColorRect.new()
	divider.color = Color("2a3e52")
	divider.custom_minimum_size.x = 1
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	terminal.add_child(divider)
	var assignment := VBoxContainer.new()
	assignment.custom_minimum_size.x = 265
	assignment.add_theme_constant_override("separation", 12)
	terminal.add_child(assignment)
	assignment.add_child(_label("REVIEW AUTHORITY", 12, MUTED))
	_authority = _label("HUMAN", 27, INK)
	assignment.add_child(_authority)
	assignment.add_child(_gap(14))
	_role = _label("HELIOS / ADVISORY ONLY", 12, MUTED)
	assignment.add_child(_role)
	assignment.add_child(_label("FINAL ACCOUNTABILITY", 12, MUTED))
	assignment.add_child(_label("YOU", 21, INK))

	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stretch.custom_minimum_size.y = 28
	column.add_child(stretch)
	column.add_child(_rule())
	column.add_child(_gap(22))
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)
	_hint = _label("ENTER / ESC — SKIP", 12, MUTED)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_hint)
	_skip = _button("SKIP INTRO", false)
	_skip.pressed.connect(_complete)
	footer.add_child(_skip)
	_begin = _button("BEGIN SHIFT", true)
	_begin.pressed.connect(_complete)
	_begin.hide()
	footer.add_child(_begin)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 1
	rule.color = Color("2a3e52")
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


func _button(text: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(160, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("cadce3") if primary else Color("152539")
	normal.border_color = Color("cadce3") if primary else Color("425d75")
	normal.set_border_width_all(1)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("e0eff1") if primary else Color("233c52")
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = CYAN
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("focus", focus)
	for state in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(state, Color("152539") if primary else INK)
	return button
