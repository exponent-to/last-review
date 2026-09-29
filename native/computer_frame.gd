extends Control
## The physical monitor and room behind the desktop. All input belongs to its screen.

const SCREEN_INSETS := Vector4(120.0, 130.0, 120.0, 140.0)
var _motion := true
var _elapsed := 0.0
var _day := 1
var _autonomy := 0
var _hardware_font: Font
var _day_minutes := 540


static func get_screen_rect(surface_size: Vector2) -> Rect2:
	return Rect2(Vector2(SCREEN_INSETS.x, SCREEN_INSETS.y), Vector2(
		maxf(0.0, surface_size.x - SCREEN_INSETS.x - SCREEN_INSETS.z),
		maxf(0.0, surface_size.y - SCREEN_INSETS.y - SCREEN_INSETS.w)))


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	var font_path := "res://art/fonts/IBMPlexMono-Regular.ttf"
	_hardware_font = load(font_path) if ResourceLoader.exists(font_path) else get_theme_default_font()
	resized.connect(queue_redraw)
	visibility_changed.connect(_sync_processing)
	get_window().focus_entered.connect(_sync_processing)
	get_window().focus_exited.connect(_sync_processing)
	_sync_processing()


func set_motion(enabled: bool) -> void:
	_motion = enabled
	_sync_processing()
	queue_redraw()


func set_story(day: int, autonomy: int) -> void:
	_day = maxi(1, day)
	_autonomy = clampi(autonomy, 0, 100)
	queue_redraw()


func set_time_of_day(minutes: int) -> void:
	_day_minutes = clampi(minutes, 540, 1080)
	queue_redraw()


func _sky_color() -> Color:
	if _day_minutes < 840:
		return Color("708e9f").lerp(Color("48687f"), float(_day_minutes - 540) / 300.0)
	return Color("48687f").lerp(Color("182339"), float(_day_minutes - 840) / 240.0)


func _sync_processing() -> void:
	var active := is_inside_tree() and is_visible_in_tree()
	if active:
		active = get_window().has_focus()
	set_process(_motion and active)


func _process(delta: float) -> void:
	if get_window().mode == Window.MODE_MINIMIZED:
		return
	_elapsed += minf(delta, 0.1)
	queue_redraw()


func _draw() -> void:
	_draw_room()
	var screen := get_screen_rect(size)
	var case_rect := Rect2(screen.position - Vector2(12, 12), screen.size + Vector2(24, 48))
	var case_bottom := case_rect.end.y
	# A little of the stand remains visible on the desk below the enclosure.
	var center_x := floorf(size.x * 0.5)
	draw_rect(Rect2(center_x - 18, case_bottom - 4, 36, 35), Color("233341"))
	draw_rect(Rect2(center_x - 55, case_bottom + 29, 110, 5), Color("394a58"))
	draw_rect(Rect2(center_x - 56, case_bottom + 34, 112, 2), Color("0d1823"))
	# A stepped charcoal/slate enclosure, with a physical lip below the screen.
	draw_rect(Rect2(case_rect.position + Vector2(4, 5), case_rect.size), Color("070f18"))
	draw_rect(case_rect, Color("303d4b"))
	draw_rect(Rect2(case_rect.position + Vector2(2, 2), case_rect.size - Vector2(4, 4)), Color("222f3d"))
	draw_rect(Rect2(case_rect.position + Vector2(2, 0), Vector2(case_rect.size.x - 4, 2)), Color("657582"))
	draw_rect(Rect2(case_rect.position + Vector2(0, 2), Vector2(2, case_rect.size.y - 4)), Color("4a5b69"))
	draw_rect(Rect2(Vector2(case_rect.end.x - 2, case_rect.position.y + 2), Vector2(2, case_rect.size.y - 4)), Color("121d28"))
	draw_rect(Rect2(Vector2(case_rect.position.x + 2, case_bottom - 2), Vector2(case_rect.size.x - 4, 2)), Color("0c1722"))
	# The inset rim stays outside the screen rectangle owned by the interface.
	draw_rect(screen.grow(3), Color("111e2c"))
	draw_rect(Rect2(screen.position - Vector2(1, 1), screen.size + Vector2(2, 2)), Color("526778"))
	draw_rect(screen, Color("172b40"))
	draw_rect(Rect2(Vector2(screen.position.x, screen.end.y + 3), Vector2(screen.size.x, 1)), Color("43515e"))
	if _hardware_font != null:
		draw_string(_hardware_font, Vector2(screen.position.x + 14, screen.end.y + 24), "NORTHSTAR  /  N-7", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("82939f"))
	# Speaker slots and the steady power light are hardware, not game meters.
	for slot in range(12):
		draw_rect(Rect2(floorf(size.x * 0.5) - 34 + slot * 6, screen.end.y + 15, 2, 9), Color("12212d"))
	var power_color := Color("8fc6ce")
	if _day >= 3 and _autonomy >= 65:
		power_color = Color("b8858d")
	draw_rect(Rect2(screen.end.x - 22, screen.end.y + 16, 5, 5), Color("101c28"))
	draw_rect(Rect2(screen.end.x - 21, screen.end.y + 17, 3, 3), power_color)


func _draw_room() -> void:
	# Two-pixel architectural drawing: recessed glass, wall, then a desk plane.
	var room_size := (size * 0.5).ceil()
	var desk_y := room_size.y - 62
	var window_bottom := desk_y - 73
	var glass := Rect2(23, 16, room_size.x - 46, window_bottom - 16)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	draw_rect(Rect2(Vector2.ZERO, room_size), Color("172431"))
	# Wall surfaces, with a darker return on the right and a narrow ceiling seam.
	draw_rect(Rect2(4, 5, room_size.x - 8, desk_y - 5), Color("344652"))
	draw_rect(Rect2(room_size.x - 12, 5, 8, desk_y - 5), Color("233542"))
	draw_rect(Rect2(4, 3, room_size.x - 8, 2), Color("526571"))
	# Deep window reveal surrounds the glazing instead of continuing to the desk.
	draw_rect(Rect2(12, 8, room_size.x - 24, window_bottom + 2), Color("152532"))
	draw_rect(Rect2(15, 11, room_size.x - 30, window_bottom - 5), Color("607681"))
	draw_rect(Rect2(18, 14, room_size.x - 36, window_bottom - 12), Color("273d4c"))
	draw_rect(glass, _sky_color())
	# Skyline is clipped geometrically to the glass; the wall below stays indoors.
	for building in range(20):
		var x := building * 37 - 12
		var roof := 28 + (building * 17) % 59
		_room_rect(Rect2(x, roof, 27, maxf(0, glass.end.y - roof)), glass, Color("293f52"))
		for floor_index in range(25):
			if (building + floor_index) % 3 == 0:
				_room_rect(Rect2(x + 5, roof + 5 + floor_index * 9, 3, 2), glass, Color("738a98").lerp(Color("e0c795"), clampf(float(_day_minutes - 840) / 240.0, 0, 1)))
	for building in range(9):
		var x := building * 83 + 9
		var roof := 96 + (building * 23) % 47
		_room_rect(Rect2(x, roof, 39, maxf(0, glass.end.y - roof)), glass, Color("203446"))
	_draw_window_rain(glass)
	# Inner seals, mullions and the underside of the upper reveal.
	draw_rect(Rect2(21, 14, room_size.x - 42, 3), Color("142734"))
	for x: float in [20.0, floorf(room_size.x * 0.5), room_size.x - 24.0]:
		draw_rect(Rect2(x, 14, 4, window_bottom - 14), Color("182b3a"))
		draw_rect(Rect2(x + 3, 17, 1, window_bottom - 17), Color("6b8491"))
	draw_rect(Rect2(20, 37, room_size.x - 40, 4), Color("182b3a"))
	draw_rect(Rect2(20, 41, room_size.x - 40, 1), Color("718895"))
	# Sill top projects into the room, its front and cast shadow giving depth.
	draw_colored_polygon(PackedVector2Array([
		Vector2(19, window_bottom), Vector2(room_size.x - 19, window_bottom),
		Vector2(room_size.x - 8, window_bottom + 9), Vector2(8, window_bottom + 9)
	]), Color("667d89"))
	draw_rect(Rect2(8, window_bottom + 9, room_size.x - 16, 4), Color("455c6b"))
	draw_rect(Rect2(8, window_bottom + 9, room_size.x - 16, 1), Color("91a3aa"))
	draw_rect(Rect2(12, window_bottom + 13, room_size.x - 24, 7), Color("263946"))
	# Under-window wall rail and a radiator, partially hidden behind the monitor.
	draw_rect(Rect2(4, window_bottom + 45, room_size.x - 8, 1), Color("455966"))
	draw_rect(Rect2(4, desk_y - 7, room_size.x - 8, 5), Color("243744"))
	var radiator := Rect2(room_size.x - 57, window_bottom + 27, 39, 32)
	draw_rect(Rect2(radiator.position + Vector2(3, 3), radiator.size), Color("263946"))
	draw_rect(radiator, Color("758994"))
	for fin in range(6):
		draw_rect(Rect2(radiator.position + Vector2(3 + fin * 6, 3), Vector2(3, 26)), Color("3f5666"))
		draw_rect(Rect2(radiator.position + Vector2(2 + fin * 6, 3), Vector2(1, 26)), Color("9babb1"))
	draw_rect(Rect2(radiator.position + Vector2(-5, 6), Vector2(5, 4)), Color("687e8c"))
	draw_rect(Rect2(radiator.position + Vector2(-7, 4), Vector2(3, 8)), Color("a3afb4"))
	draw_rect(Rect2(radiator.position + Vector2(33, 32), Vector2(3, 10)), Color("526976"))
	# A small outlet and its cable disappear naturally behind the desk.
	draw_rect(Rect2(25, window_bottom + 29, 12, 16), Color("5e7380"))
	draw_rect(Rect2(27, window_bottom + 31, 8, 12), Color("a0afb6"))
	draw_rect(Rect2(29, window_bottom + 36, 5, 4), Color("273c4b"))
	draw_line(Vector2(31, window_bottom + 40), Vector2(31, desk_y - 10), Color("182a38"), 2)
	draw_line(Vector2(31, desk_y - 10), Vector2(48, desk_y + 3), Color("182a38"), 2)
	# Desk top, back lip, and a visible front fascia. No floating flat-color block.
	draw_rect(Rect2(0, desk_y, room_size.x, room_size.y - desk_y), Color("293c4b"))
	draw_rect(Rect2(0, desk_y - 1, room_size.x, 2), Color("768a97"))
	draw_rect(Rect2(0, desk_y + 1, room_size.x, 3), Color("3c5262"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(room_size.x * 0.5 - 96, desk_y + 4), Vector2(room_size.x * 0.5 + 96, desk_y + 4),
		Vector2(room_size.x * 0.5 + 150, room_size.y - 8), Vector2(room_size.x * 0.5 - 150, room_size.y - 8)
	]), Color("304553"))
	draw_line(Vector2(42, desk_y + 4), Vector2(8, room_size.y - 8), Color("223744"), 1)
	draw_line(Vector2(room_size.x - 42, desk_y + 4), Vector2(room_size.x - 8, room_size.y - 8), Color("223744"), 1)
	draw_rect(Rect2(room_size.x * 0.5 - 35, desk_y + 14, 80, 23), Color("203440"))
	draw_rect(Rect2(0, room_size.y - 8, room_size.x, 2), Color("536b7b"))
	draw_rect(Rect2(0, room_size.y - 6, room_size.x, 5), Color("182a38"))
	draw_rect(Rect2(0, room_size.y - 1, room_size.x, 1), Color("0d1924"))
	# A shallow keyboard grounds the monitor at a believable desk scale.
	var keyboard_x := floorf(room_size.x * 0.5) - 80
	draw_rect(Rect2(keyboard_x - 2, room_size.y - 22, 164, 16), Color("152330"))
	draw_rect(Rect2(keyboard_x, room_size.y - 23, 160, 14), Color("657785"))
	for row in range(3):
		for key in range(24):
			draw_rect(Rect2(keyboard_x + 3 + key * 6, room_size.y - 21 + row * 3, 5, 2), Color("354957"))
	# Mug on the near left of the desk: curved rim, shaded body, hollow handle.
	var mug := Vector2(16, room_size.y - 52)
	draw_rect(Rect2(mug + Vector2(-3, 43), Vector2(52, 5)), Color("192b38"))
	draw_rect(Rect2(mug + Vector2(35, 11), Vector2(12, 24)), Color("91a3ae"))
	draw_rect(Rect2(mug + Vector2(37, 15), Vector2(6, 16)), Color("293c4b"))
	draw_rect(Rect2(mug + Vector2(2, 5), Vector2(34, 36)), Color("8398a6"))
	draw_rect(Rect2(mug + Vector2(6, 40), Vector2(26, 4)), Color("617b8c"))
	draw_rect(Rect2(mug + Vector2(27, 7), Vector2(9, 31)), Color("617b8c"))
	draw_rect(Rect2(mug + Vector2(5, 6), Vector2(3, 28)), Color("a1b2bc"))
	draw_rect(Rect2(mug + Vector2(5, 2), Vector2(28, 8)), Color("b0bfc6"))
	draw_rect(Rect2(mug + Vector2(8, 4), Vector2(22, 4)), Color("172532"))
	# Folded note and pen, kept below the exposed right edge of the monitor.
	draw_rect(Rect2(room_size.x - 82, room_size.y - 39, 63, 25), Color("1c2e3c"))
	draw_rect(Rect2(room_size.x - 85, room_size.y - 42, 63, 25), Color("9aabb5"))
	for row in range(4):
		draw_rect(Rect2(room_size.x - 79, room_size.y - 36 + row * 4, 36 - row * 5, 1), Color("5d7386"))
	draw_rect(Rect2(room_size.x - 26, room_size.y - 35, 2, 25), Color("162638"))
	draw_set_transform(Vector2.ZERO)


func _room_rect(rect: Rect2, bounds: Rect2, color: Color) -> void:
	var clipped := rect.intersection(bounds)
	if clipped.has_area():
		draw_rect(clipped, color)


static func _rain_seed(index: int, salt: int) -> float:
	# Stable rain phases across frames and resizing, without touching gameplay RNG.
	return fposmod(sin(float(index) * 127.1 + float(salt) * 311.7) * 43758.5453, 1.0)


func _draw_window_rain(glass: Rect2) -> void:
	if glass.size.x <= 0 or glass.size.y <= 0: return
	var light := Color("c5dbe2").lerp(Color("7e9fb9"), float(_day_minutes - 540) / 540.0)
	var wind := 0.13 + sin(_elapsed * 0.19) * 0.05
	# Distant rain is fine and faint; nearer rain is faster and longer. Each
	# streak has its own phase and speed, so the field never moves as one sheet.
	for layer in range(3):
		for index in range(65):
			var seed_index := index + layer * 71
			var speed := (42.0 + layer * 44.0) * lerpf(0.7, 1.35, _rain_seed(seed_index, 1))
			var length := lerpf(2.0, 6.0, _rain_seed(seed_index, 2)) + layer * 3.0
			var y := fposmod(_rain_seed(seed_index, 3) * glass.size.y + _elapsed * speed, glass.size.y)
			var x := fposmod(_rain_seed(seed_index, 4) * glass.size.x - _elapsed * speed * wind, glass.size.x)
			var head := glass.position + Vector2(x, y)
			var tail := head + Vector2(length * wind, -length)
			tail.x = clampf(tail.x, glass.position.x, glass.end.x)
			tail.y = maxf(glass.position.y, tail.y)
			var tint := light
			tint.a = (0.09 + layer * 0.055) * lerpf(0.6, 1.0, _rain_seed(seed_index, 5))
			draw_line(tail, head, tint, 0.45 + layer * 0.18, true)
