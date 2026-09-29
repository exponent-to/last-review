extends Control
## The physical monitor and room behind the desktop. All input belongs to its screen.

const SCREEN_INSETS := Vector4(120.0, 130.0, 120.0, 140.0)
var _motion := true
var _elapsed := 0.0
var _day := 1
var _autonomy := 0
var _hardware_font: Font


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
	# Hand-authored geometry on a two-pixel grid. The desk and window share
	# the monitor's perspective instead of being squeezed into its border.
	var room_size := (size * 0.5).ceil()
	var desk_y := room_size.y - 62
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	draw_rect(Rect2(Vector2.ZERO, room_size), Color("172431"))
	draw_rect(Rect2(12, 10, room_size.x - 24, desk_y - 20), Color("38566b"))
	# Two depths of skyline remain visible above and beside the monitor.
	for building in range(20):
		var x := building * 37 - 12
		var roof := 28 + (building * 17) % 59
		draw_rect(Rect2(x, roof, 27, maxf(0, desk_y - roof)), Color("293f52"))
		for floor_index in range(12):
			if (building + floor_index) % 3 == 0:
				draw_rect(Rect2(x + 5, roof + 5 + floor_index * 9, 3, 2), Color("738a98"))
	for building in range(9):
		var x := building * 83 + 9
		var roof := 96 + (building * 23) % 47
		draw_rect(Rect2(x, roof, 39, maxf(0, desk_y - roof)), Color("203446"))
	var travel := int(floorf(_elapsed * 21.0))
	for index in range(70):
		var x := 16 + (index * 47) % maxi(1, int(room_size.x - 32))
		var y := 12 + (index * 29 + travel) % maxi(1, int(desk_y - 26))
		draw_rect(Rect2(x, y, 1, 4 + index % 6), Color("779aaa"))
		if index % 4 == 0:
			draw_rect(Rect2(x - 1, y + 1, 1, 2), Color("567a90"))
	# Substantial window frame and sill establish an office around the screen.
	for x: float in [12.0, room_size.x * 0.5, room_size.x - 18.0]:
		draw_rect(Rect2(x, 8, 6, desk_y - 12), Color("111f2b"))
		draw_rect(Rect2(x + 5, 10, 1, desk_y - 16), Color("637d8c"))
	draw_rect(Rect2(12, 9, room_size.x - 24, 5), Color("182b3a"))
	draw_rect(Rect2(12, 37, room_size.x - 24, 4), Color("182b3a"))
	draw_rect(Rect2(12, 41, room_size.x - 24, 1), Color("637d8c"))
	draw_rect(Rect2(8, desk_y - 10, room_size.x - 16, 6), Color("526777"))
	draw_rect(Rect2(8, desk_y - 4, room_size.x - 16, 4), Color("0e1d29"))
	# Desk surface, edge, and a subtle pool of monitor light.
	draw_rect(Rect2(0, desk_y, room_size.x, room_size.y - desk_y), Color("293c4b"))
	draw_rect(Rect2(0, desk_y, room_size.x, 1), Color("6a7e8c"))
	draw_rect(Rect2(room_size.x * 0.5 - 120, desk_y + 19, 240, 33), Color("304553"))
	draw_rect(Rect2(0, room_size.y - 5, room_size.x, 5), Color("111e2b"))
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
