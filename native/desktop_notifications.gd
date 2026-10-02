extends Control
## Small transient notifications. Dismissing a bubble never marks its app read.
signal activated(app: String, target: String)
const NAMES := {"chat": "SLOUCH", "review": "REVIEW", "browser": "INTRANET", "system": "SYSTEM"}
const Portraits = preload("res://native/portraits.gd")
var _stack: VBoxContainer
var _items: Array[Dictionary] = []
var paused := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	_stack = VBoxContainer.new()
	_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stack.add_theme_constant_override("separation", 0)
	add_child(_stack)
	_stack.minimum_size_changed.connect(_fit.call_deferred)
	resized.connect(_fit.call_deferred)
	_fit.call_deferred()

func push(app: String, text: String, target: String = "", is_error: bool = false, person: String = "") -> void:
	for item: Dictionary in _items.duplicate():
		if item.app == app and item.target == target: _remove(item)
	if _items.size() == 3: _remove(_items[0])
	# One-line ticker cards ride in the taskbar, so they never cover work.
	var accent := Color("e5384a") if is_error else Color("6fdc8c")
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("141416")
	style.border_color = Color("2c2c31")
	style.set_border_width_all(1)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size.y = 34
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.focus_mode = Control.FOCUS_ALL
	card.tooltip_text = text + "\n\nOpen " + str(NAMES[app])
	_stack.add_child(card)
	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)
	var chip := PanelContainer.new()
	var chip_style := StyleBoxFlat.new()
	chip_style.bg_color = accent
	chip_style.content_margin_left = 7
	chip_style.content_margin_right = 7
	chip.add_theme_stylebox_override("panel", chip_style)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(chip)
	var title := Label.new()
	title.text = str(NAMES[app])
	title.add_theme_font_size_override("font_size", 10)
	title.add_theme_color_override("font_color", Color("0a0a0b"))
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	chip.add_child(title)
	# A Slouch message from a person carries their face.
	if app == "chat" and Portraits.texture_for(person) != null:
		style.content_margin_top = 1
		style.content_margin_bottom = 1
		content.add_child(Portraits.make(person, 32))
		card.set_meta("person", Portraits.id_for(person))
	var body := Label.new()
	body.text = text.replace("\n", " ")
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.clip_text = true
	body.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color("e6e2d6"))
	content.add_child(body)
	var waiting := Label.new()
	waiting.add_theme_font_size_override("font_size", 10)
	waiting.add_theme_color_override("font_color", Color("8c8981"))
	waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(waiting)
	card.set_meta("waiting", waiting)
	var dismiss := Button.new()
	dismiss.text = "×"
	dismiss.flat = true
	dismiss.custom_minimum_size = Vector2(24, 24)
	dismiss.tooltip_text = "Dismiss notification"
	content.add_child(dismiss)
	var item := {"app": app, "target": target, "card": card, "remaining": 9.0}
	# A thin fuse along the bottom shows how long the card will stay.
	card.draw.connect(func() -> void:
		card.draw_rect(Rect2(1, card.size.y - 2, (card.size.x - 2) * clampf(float(item.remaining) / 9.0, 0.0, 1.0), 1), Color(accent, 0.7)))
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.18)
	_items.append(item)
	dismiss.pressed.connect(_remove.bind(item))
	card.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ENTER, KEY_SPACE]):
			card.accept_event()
			_remove(item)
			activated.emit(app, target))
	_show_latest()
	_fit.call_deferred()

func _show_latest() -> void:
	# Older cards wait their turn behind the newest one; the badge keeps the count.
	for index in range(_items.size()):
		_items[index].card.visible = index == _items.size() - 1
	if not _items.is_empty():
		var waiting: Label = _items[-1].card.get_meta("waiting")
		waiting.text = "+%d" % (_items.size() - 1) if _items.size() > 1 else ""

func clear_app(app: String, target: String = "") -> void:
	for item: Dictionary in _items.duplicate():
		if item.app == app and (target.is_empty() or item.target == target): _remove(item)

func _remove(item: Dictionary) -> void:
	if item not in _items: return
	_items.erase(item)
	_stack.remove_child(item.card)
	item.card.queue_free()
	_show_latest()
	_fit.call_deferred()

func _fit() -> void:
	if not is_inside_tree(): return
	_stack.size.x = clampf(size.x * 0.38, 220, 440)
	if not get_tree().process_frame.is_connected(_queue_fit_position):
		get_tree().process_frame.connect(_queue_fit_position, CONNECT_ONE_SHOT)

func _queue_fit_position() -> void:
	if is_inside_tree() and not get_tree().process_frame.is_connected(_fit_position):
		get_tree().process_frame.connect(_fit_position, CONNECT_ONE_SHOT)

func _fit_position() -> void:
	if not is_inside_tree(): return
	_stack.size.y = _stack.get_combined_minimum_size().y
	_stack.position = Vector2(size.x - _stack.size.x - 6, size.y - _stack.size.y - 5)

func _process(delta: float) -> void:
	if paused or not is_visible_in_tree(): return
	for item: Dictionary in _items.duplicate():
		if item.card.get_global_rect().has_point(get_global_mouse_position()): continue
		item.remaining -= delta
		item.card.queue_redraw()
		if item.remaining <= 0: _remove(item)
