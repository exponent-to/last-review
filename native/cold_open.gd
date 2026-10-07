extends Control
## A laptop wake-up followed by a player-controlled fictional inbox.

signal finished

const ARRIVAL_TIME := 6.6
const SIGN_HOLD := 1.2
const DESIGN_SIZE := Vector2(1120, 800)
const OFFER := "Hi,\n\nWe enjoyed your conversation with our recruiting assistant. Paperclip Labs would like to offer you the role of Junior Software Engineer.\n\nPay: 20 Paperclip credits (CR) a day, plus 8 CR per signed review\nLocation: on site. Start: Monday.\n\nYou'll review changes, work with the team, and help us build the future of human-centered automation. Our assistant, Helios, will handle the routine parts.\n\nWe know you have options. This offer expires tonight.\n\nMorgan\nEngineering Manager, Paperclip Labs"
const REJECTIONS := [
	["Stealth Stealth", "An update on your application", "We've decided to remain stealthy about your candidacy."],
	["Pivotly", "You're almost a culture fit", "We pivoted away from employing people during your interview."],
	["Foundr's Friend", "A very competitive process", "The founder's roommate had uniquely relevant experience."],
	["Disrupt Soup", "Let's stay connected", "We loved your work. Unfortunately, our budget is exposure."],
	["Unicorn Pending", "Following up, again", "This role requires previous experience in this exact role."]
]

var _elapsed := 0.0
var _paused := false
var _focused := true
var _motion := true
var _completed := false
var _pinged := false
var _font: Font
var _skip: Button
var _mail_buttons: Array[Button] = []
var _inbox_button: Button
var _sign_button: Button
var _selected_mail := -2 # -2: inbox, -1: offer, 0+: rejection.
var _signed := false
var _signed_elapsed := 0.0
var _ping: AudioStreamPlayer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_font = load("res://art/fonts/IBMPlexMono-Regular.ttf")
	_skip = _make_button("SKIP  [ESC]")
	_skip.pressed.connect(_complete)
	add_child(_skip)
	for index in range(-1, REJECTIONS.size()):
		var button := _mail_hit_button("Open Paperclip Labs offer" if index == -1 else "Open " + str(REJECTIONS[index][0]))
		button.pressed.connect(_open_mail.bind(index))
		_mail_buttons.append(button)
	_inbox_button = _mail_hit_button("Back to Inbox")
	_inbox_button.pressed.connect(_open_mail.bind(-2))
	_sign_button = _mail_hit_button("Accept and sign offer")
	_sign_button.pressed.connect(_sign_offer)
	_ping = AudioStreamPlayer.new()
	_ping.stream = _ping_sound()
	_ping.volume_db = -20.0
	add_child(_ping)
	get_window().focus_entered.connect(_on_focus_entered)
	get_window().focus_exited.connect(_on_focus_exited)
	_focused = get_window().has_focus()
	resized.connect(_layout)
	_layout()
	_skip.grab_focus()
	_sync_processing()


func set_paused(paused: bool) -> void:
	_paused = paused
	if paused and is_instance_valid(_ping):
		_ping.stop()
	_sync_processing()


func set_motion(enabled: bool) -> void:
	_motion = enabled
	if not enabled:
		_elapsed = ARRIVAL_TIME
		_pinged = true
	if is_node_ready(): _layout()
	_sync_processing()
	queue_redraw()


func _sync_processing() -> void:
	set_process(not _completed and (_motion or _signed) and not _paused and _focused)


func _on_focus_entered() -> void:
	_focused = true
	_sync_processing()


func _on_focus_exited() -> void:
	_focused = false
	if is_instance_valid(_ping):
		_ping.stop()
	_sync_processing()


func _process(delta: float) -> void:
	advance_sequence(minf(delta, 0.1))


## Deterministic progression for a replay or test. Application focus gates _process.
func advance_sequence(delta: float) -> void:
	if _completed or _paused or delta <= 0.0:
		return
	if _signed:
		_signed_elapsed += delta
		if _signed_elapsed >= SIGN_HOLD: _complete()
		return
	if not _motion: return
	var was_ready := _elapsed >= ARRIVAL_TIME
	_elapsed = minf(ARRIVAL_TIME, _elapsed + delta)
	if _elapsed >= 1.6 and not _pinged:
		_pinged = true
		if is_instance_valid(_ping) and _focused:
			_ping.play()
	if not was_ready and _elapsed >= ARRIVAL_TIME:
		_layout()
		_mail_buttons[0].grab_focus()
	queue_redraw()


func _open_mail(index: int) -> void:
	if _completed or _paused or _signed or _elapsed < ARRIVAL_TIME: return
	if index < -2 or index >= REJECTIONS.size(): return
	_selected_mail = index
	_layout()
	if index == -1: _sign_button.grab_focus()
	elif index >= 0: _inbox_button.grab_focus()
	else: _mail_buttons[0].grab_focus()
	queue_redraw()


func _sign_offer() -> void:
	if _completed or _paused or _signed or _selected_mail != -1 or _elapsed < ARRIVAL_TIME: return
	_signed = true
	_layout()
	_sync_processing()
	queue_redraw()


func _complete() -> void:
	if _completed:
		return
	_completed = true
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	if is_instance_valid(_ping):
		_ping.stop()
	if is_instance_valid(_skip):
		_skip.disabled = true
	for button in _mail_buttons: button.disabled = true
	_sign_button.disabled = true
	_inbox_button.disabled = true
	finished.emit()


func _input(event: InputEvent) -> void:
	if _completed or not is_visible_in_tree():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		# Consume before emitting: the parent removes this scene in the handoff.
		get_viewport().set_input_as_handled()
		_complete()


func _unhandled_input(_event: InputEvent) -> void:
	if not _completed and is_visible_in_tree():
		get_viewport().set_input_as_handled()


func _layout() -> void:
	_skip.position = Vector2(maxf(12, size.x - 174), 14)
	_skip.size = Vector2(160, 36)
	if not is_instance_valid(_sign_button): return
	var ready_for_mail := _elapsed >= ARRIVAL_TIME and not _signed
	for index in range(_mail_buttons.size()):
		var button := _mail_buttons[index]
		button.visible = ready_for_mail and _selected_mail == -2
		_place_mail_button(button, Rect2(161, 79 if index == 0 else 153 + (index - 1) * 73, 785, 65))
	_inbox_button.visible = ready_for_mail and _selected_mail != -2
	_place_mail_button(_inbox_button, Rect2(8, 82, 136, 32))
	_sign_button.visible = ready_for_mail and _selected_mail == -1
	_place_mail_button(_sign_button, Rect2(175, 496, 286, 42))
	queue_redraw()


func _place_mail_button(button: Button, rect: Rect2) -> void:
	var view_scale := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var origin := ((size - DESIGN_SIZE * view_scale) * 0.5).floor()
	var laptop := _laptop_rect()
	var mail_scale := (laptop.size.x - 36) / 956.0
	button.position = origin + (laptop.position + Vector2(18, 18) + rect.position * mail_scale) * view_scale
	button.size = rect.size * mail_scale * view_scale


func _mail_hit_button(label: String) -> Button:
	var button := Button.new()
	button.tooltip_text = label
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.2, 0.4, 0.6, 0.12)
	button.add_theme_stylebox_override("hover", hover)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("467b9c")
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	add_child(button)
	return button


func _make_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color("cad7e0"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("111c29")
	normal.border_color = Color("536473")
	normal.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", normal)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("24384a")
	button.add_theme_stylebox_override("hover", hover)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Color("9bc4d6")
	button.add_theme_stylebox_override("focus", focus)
	return button


func _laptop_rect() -> Rect2:
	var progress := clampf((_elapsed - 3.5) / 2.5, 0.0, 1.0)
	var eased := progress * progress * (3.0 - 2.0 * progress)
	return Rect2(Vector2(310, 260).lerp(Vector2(64, 66), eased), Vector2(500, 330).lerp(Vector2(992, 668), eased))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("060a10"))
	if _font == null:
		return
	var scale_factor := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var origin := ((size - DESIGN_SIZE * scale_factor) * 0.5).floor()
	draw_set_transform(origin, 0.0, Vector2.ONE * scale_factor)
	var laptop := _laptop_rect()
	var room_light := clampf((_elapsed - 1.6) / 0.8, 0.0, 1.0)
	# The screen catches the desk edge and wall; the room stays mostly unlit.
	draw_rect(Rect2(0, 0, 1120, 800), Color("060a10").lerp(Color("111c2b"), room_light * 0.35))
	draw_rect(Rect2(0, 586, 1120, 214), Color("0c121c").lerp(Color("243447"), room_light * 0.3))
	draw_rect(Rect2(0, 586, 1120, 2), Color("1d2a39").lerp(Color("47576a"), room_light * 0.3))
	draw_rect(Rect2(72, 138, 162, 278), Color("080e18"))
	draw_rect(Rect2(78, 144, 150, 266), Color("0e1724"))
	draw_rect(Rect2(150, 144, 4, 266), Color("060b13"))
	for light in range(6):
		draw_rect(Rect2(90 + light * 21, 355 - (light % 3) * 25, 3, 4), Color("26374b"))
	draw_rect(Rect2(laptop.position + Vector2(5, 7), laptop.size), Color("020407"))
	draw_rect(laptop, Color("273443"))
	draw_rect(Rect2(laptop.position + Vector2(2, 2), laptop.size - Vector2(4, 4)), Color("16212e"))
	draw_rect(Rect2(laptop.position, Vector2(laptop.size.x, 2)), Color("4a5a69"))
	var screen := Rect2(laptop.position + Vector2(18, 18), laptop.size - Vector2(36, 87))
	draw_rect(screen.grow(2), Color("080e16"))
	var brightness := clampf((_elapsed - 1.6) / 0.8, 0.0, 1.0)
	draw_rect(screen, Color("09111b").lerp(Color("cfdae0"), brightness))
	# Laptop base and keyboard stay physically attached during the push-in.
	var base_y := laptop.end.y - 51
	draw_rect(Rect2(laptop.position.x - 10, base_y, laptop.size.x + 20, 48), Color("344251"))
	draw_rect(Rect2(laptop.position.x - 6, base_y + 1, laptop.size.x + 12, 2), Color("627080"))
	for row in range(3):
		for key in range(17):
			var key_width := (laptop.size.x - 100) / 17.0
			draw_rect(Rect2(laptop.position.x + 50 + key * key_width, base_y + 6 + row * 6, key_width - 3, 3), Color("14212e"))
	draw_rect(Rect2(laptop.get_center().x - 34, base_y + 28, 68, 14), Color("293746"))
	draw_rect(Rect2(laptop.position.x - 6, laptop.end.y - 2, laptop.size.x + 12, 4), Color("0c1520"))
	draw_rect(Rect2(laptop.position.x + laptop.size.x * 0.5 - 2, laptop.position.y + 7, 4, 3), Color("070d14"))
	if brightness > 0.7:
		_draw_mail(screen)
	if _elapsed >= 1.6 and _elapsed < 3.5:
		var notification := Rect2(laptop.position.x + 82, laptop.position.y - 42, laptop.size.x - 164, 30)
		draw_rect(notification, Color("273b4d"))
		_text(notification.position + Vector2(12, 20), "New mail — Paperclip Labs", 13, Color("d4e5eb"))
	draw_set_transform(Vector2.ZERO)


func _draw_mail(screen: Rect2) -> void:
	# Render mail on a fixed readable layout, scaled with the laptop itself.
	var mail_scale := screen.size.x / 956.0
	var saved_transform := Transform2D(0.0, screen.position)
	var view_scale := minf(size.x / DESIGN_SIZE.x, size.y / DESIGN_SIZE.y)
	var origin := ((size - DESIGN_SIZE * view_scale) * 0.5).floor()
	draw_set_transform(origin + saved_transform.origin * view_scale, 0.0, Vector2.ONE * view_scale * mail_scale)
	var mail_height := screen.size.y / mail_scale
	draw_rect(Rect2(0, 0, 956, 34), Color("334e66"))
	_text(Vector2(15, 23), "POSTBOX", 15, Color("e4edf1"))
	_text_right(Vector2(941, 22), "you@postbox.local", 13, Color("b7cbd9"))
	draw_rect(Rect2(0, 34, 152, mail_height - 34), Color("a9bdcb"))
	_text(Vector2(15, 67), "MAILBOXES", 12, Color("3e566b"))
	draw_rect(Rect2(8, 82, 136, 32), Color("6e8ca4"))
	_text(Vector2(18, 104), "Inbox", 15, Color("f0f4f4"))
	_text(Vector2(18, 141), "Sent", 14, Color("425c72"))
	_text(Vector2(18, 175), "Drafts", 14, Color("425c72"))
	_text(Vector2(18, 209), "Trash", 14, Color("425c72"))
	if _selected_mail == -2:
		_draw_inbox()
	elif _selected_mail == -1:
		_draw_offer()
	else:
		_draw_rejection()
	draw_set_transform(origin, 0.0, Vector2.ONE * view_scale)


func _draw_inbox() -> void:
	_text(Vector2(172, 65), "Inbox", 21, Color("20354b"))
	_text_right(Vector2(930, 64), "NEWEST FIRST", 11, Color("50677b"))
	var arrived := _elapsed >= ARRIVAL_TIME
	if arrived:
		var fresh := Rect2(161, 79, 785, 65)
		draw_rect(fresh, Color("edf5f6"))
		draw_rect(Rect2(161, 79, 4, 65), Color("467b9c"))
		_text(Vector2(175, 99), "PAPERCLIP LABS  /  Morgan", 15, Color("24425b"))
		_text(Vector2(175, 120), "An offer for you", 16, Color("172c43"))
		_text_right(Vector2(930, 100), "JUST NOW", 11, Color("4a6f87"))
	for index in range(REJECTIONS.size()):
		var y := (153 if arrived else 79) + index * 73
		draw_rect(Rect2(162, y + 64, 782, 1), Color("a8bac8"))
		_text(Vector2(175, y + 15), str(REJECTIONS[index][0]), 14, Color("4d6477"))
		_text(Vector2(175, y + 35), str(REJECTIONS[index][1]), 15, Color("314b62"))
		_text(Vector2(175, y + 53), str(REJECTIONS[index][2]), 12, Color("546b7e"))


func _draw_offer() -> void:
	_text(Vector2(172, 64), "An offer for you", 22, Color("20354b"))
	_text(Vector2(173, 90), "Morgan  <morgan@paperclip.local>", 13, Color("536b80"))
	draw_rect(Rect2(173, 104, 757, 1), Color("9db1bf"))
	var lines := _wrapped_lines(OFFER, 752, 14)
	for index in range(lines.size()):
		_text(Vector2(175, 128 + index * 18), str(lines[index]), 14, Color("293f54"))
	var signed := _signed
	draw_rect(Rect2(175, 496, 286, 42), Color("526d7c") if signed else Color("315f7e"))
	_text(Vector2(190, 522), "SIGNED — YOU" if signed else "ACCEPT & SIGN OFFER", 15, Color("e7f0f3"))
	if signed:
		_text(Vector2(485, 522), "See you Monday.", 14, Color("496575"))
	else:
		_text(Vector2(485, 522), "Electronic signature", 12, Color("607687"))


func _draw_rejection() -> void:
	var mail: Array = REJECTIONS[_selected_mail]
	_text(Vector2(172, 64), str(mail[1]), 22, Color("20354b"))
	_text(Vector2(173, 90), str(mail[0]) + " / Recruiting", 13, Color("536b80"))
	draw_rect(Rect2(173, 104, 757, 1), Color("9db1bf"))
	var lines := _wrapped_lines("Hi,\n\n" + str(mail[2]) + "\n\nThanks for your interest.\n" + str(mail[0]), 752, 14)
	for index in range(lines.size()):
		_text(Vector2(175, 128 + index * 18), lines[index], 14, Color("293f54"))


func _text(at: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## Text whose right edge sits at `at.x`, so header and list metadata share a margin.
func _text_right(at: Vector2, value: String, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_text(Vector2(at.x - width, at.y), value, font_size, color)


func _wrapped_lines(text: String, width: float, font_size: int) -> Array[String]:
	var result: Array[String] = []
	for paragraph in text.split("\n"):
		var line := ""
		for word in paragraph.split(" ", false):
			var candidate := word if line.is_empty() else line + " " + word
			if not line.is_empty() and _font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width:
				result.append(line)
				line = word
			else:
				line = candidate
		result.append(line)
	return result


func _ping_sound() -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var samples := 4410
	var data := PackedByteArray()
	data.resize(samples * 2)
	for sample in range(samples):
		var time := float(sample) / stream.mix_rate
		var envelope := sin(PI * float(sample) / samples) * exp(-time * 13.0)
		var value := int(sin(TAU * 880.0 * time) * envelope * 14000.0)
		data.encode_s16(sample * 2, value)
	stream.data = data
	return stream
