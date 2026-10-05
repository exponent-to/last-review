extends Control
## A short ending cinematic in the game's style: timed text beats over a dark,
## emptying office with Helios's amber eyes, then a final title card. Built like
## the cold open. The interface plays it from Morgan's end-of-day panel when the
## run is over, and it ends by asking to return to the main menu.

signal finished

const TerminalFont: FontFile = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
const BACK := Color("07070a")
const DIM := Color("8c8981")
const TEXT := Color("e6e2d6")
const AMBER := Color("e0b44a")
const RED := Color("e5384a")
## Seconds each beat holds before the next fades in.
const BEAT_SECONDS := 3.0
const FADE := 0.6

var _title := ""
var _beats: Array = []
var _morgan := ""
var _fired := false
var _elapsed := 0.0
var _index := -1
var _done := false
var _skip: Button
var _return: Button
var _eye_phase := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## key: an ending id (content/endings.gd). Fired endings pulse red, not amber.
func setup(title: String, beats: Array, morgan_line: String, fired: bool = false) -> void:
	_title = title
	_beats = beats
	_morgan = morgan_line
	_fired = fired


func _ready() -> void:
	_skip = _button("SKIP  [ESC]")
	_skip.pressed.connect(_finish_sequence)
	add_child(_skip)
	_return = _button("RETURN TO MAIN MENU")
	_return.pressed.connect(func() -> void: finished.emit())
	_return.hide()
	add_child(_return)
	resized.connect(_layout)
	_layout()
	_skip.grab_focus()
	set_process(true)


func _button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_override("font", TerminalFont)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("12141a")
	normal.border_color = RED if _fired else AMBER
	normal.set_border_width_all(1)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("24282f")
	button.add_theme_stylebox_override("hover", hover)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Color.WHITE
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	return button


func _layout() -> void:
	if not is_instance_valid(_skip): return
	_skip.position = Vector2(maxf(12, size.x - 172), 14)
	_skip.size = Vector2(158, 34)
	var btn := Vector2(300, 46)
	_return.size = btn
	_return.position = Vector2((size.x - btn.x) * 0.5, size.y - 120)


func _process(delta: float) -> void:
	if _done: return
	_eye_phase += delta
	_elapsed += delta
	if _index < 0 or _elapsed >= BEAT_SECONDS:
		_elapsed = 0.0
		_index += 1
		if _index >= _beats.size():
			_finish_sequence()
			return
	queue_redraw()


func _finish_sequence() -> void:
	# Stop on the final card: the title, Morgan's last word, and the way out.
	if _done:
		return
	_done = true
	_index = _beats.size()
	_skip.hide()
	_return.show()
	_return.grab_focus()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _done: finished.emit()
		else: _finish_sequence()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACK)
	# A faint grid of empty desks, dimming toward the back of the room. The final
	# card clears them so the title and Morgan's words read cleanly.
	if not _done:
		for row in range(5):
			var y := size.y * 0.30 + row * 46.0
			var shade := Color(0.10, 0.10, 0.13).lerp(BACK, row / 5.0)
			for col in range(6):
				var x := size.x * 0.12 + col * (size.x * 0.76 / 6.0)
				draw_rect(Rect2(x, y, size.x * 0.76 / 6.0 - 14, 20), shade)
	# Helios's eyes, watching from the dark. Amber on most endings, red on a firing.
	var eye_color := RED if _fired else AMBER
	var pulse := 0.5 + 0.5 * sin(_eye_phase * (3.2 if _fired else 1.4))
	var cx := size.x * 0.5
	var ey := size.y * 0.2
	for side in [-1.0, 1.0]:
		draw_rect(Rect2(cx + side * 34 - 11, ey - 6, 22, 12), Color(eye_color, 0.22 + 0.5 * pulse))
		draw_rect(Rect2(cx + side * 34 - 5, ey - 3, 10, 6), Color(eye_color, 0.6 + 0.4 * pulse))
	if _done:
		_draw_card()
		return
	# The current beat, centered, fading in.
	if _index < 0 or _index >= _beats.size(): return
	var alpha := clampf(_elapsed / FADE, 0.0, 1.0) * clampf((BEAT_SECONDS - _elapsed) / FADE, 0.0, 1.0)
	alpha = clampf(alpha + 0.25, 0.0, 1.0)
	var text := str(_beats[_index])
	_centered(text, size.y * 0.52, 20, Color(TEXT, alpha), size.x - 160)
	_centered("%d / %d" % [_index + 1, _beats.size()], size.y * 0.52 + 70, 12, Color(DIM, alpha * 0.7), size.x - 160)


func _draw_card() -> void:
	_centered(_title.to_upper(), size.y * 0.30, 34, RED if _fired else AMBER, size.x - 120)
	_centered(_morgan, size.y * 0.30 + 70, 16, TEXT, minf(760, size.x - 160))


func _centered(text: String, y: float, font_size: int, color: Color, wrap: float) -> void:
	var lines := _wrap(text, wrap, font_size)
	var line_height := TerminalFont.get_height(font_size) + 4
	var top := y - (lines.size() - 1) * line_height * 0.5
	for i in range(lines.size()):
		var w := TerminalFont.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(TerminalFont, Vector2((size.x - w) * 0.5, top + i * line_height), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _wrap(text: String, width: float, font_size: int) -> Array:
	var result: Array = []
	var line := ""
	for word in text.split(" ", false):
		var candidate := word if line.is_empty() else line + " " + word
		if not line.is_empty() and TerminalFont.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
			result.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty(): result.append(line)
	return result
