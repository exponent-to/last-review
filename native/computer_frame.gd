extends Control
## The physical monitor and room behind the desktop. All input belongs to its screen.

const SCREEN_INSETS := Vector4(30.0, 32.0, 30.0, 58.0)
const RAIN_COLUMNS := [7, 31, 59, 83, 112, 141, 176, 207, 234, 269, 297, 331, 359, 394, 426, 458, 492, 521, 553, 586, 612, 647]
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
	var case_rect := Rect2(Vector2(18, 20), (size - Vector2(36, 40)).max(Vector2.ZERO))
	var screen := get_screen_rect(size)
	# A little of the stand remains visible on the desk below the enclosure.
	var center_x := floorf(size.x * 0.5)
	draw_rect(Rect2(center_x - 18, size.y - 28, 36, 20), Color("233341"))
	draw_rect(Rect2(center_x - 55, size.y - 10, 110, 5), Color("394a58"))
	draw_rect(Rect2(center_x - 56, size.y - 5, 112, 2), Color("0d1823"))
	# A stepped charcoal/slate enclosure, with a physical lip below the screen.
	draw_rect(Rect2(case_rect.position + Vector2(4, 5), case_rect.size), Color("070f18"))
	draw_rect(case_rect, Color("303d4b"))
	draw_rect(Rect2(case_rect.position + Vector2(2, 2), case_rect.size - Vector2(4, 4)), Color("222f3d"))
	draw_rect(Rect2(Vector2(20, 20), Vector2(maxf(0, size.x - 40), 2)), Color("657582"))
	draw_rect(Rect2(Vector2(18, 22), Vector2(2, maxf(0, size.y - 44))), Color("4a5b69"))
	draw_rect(Rect2(Vector2(size.x - 20, 22), Vector2(2, maxf(0, size.y - 44))), Color("121d28"))
	draw_rect(Rect2(Vector2(20, size.y - 22), Vector2(maxf(0, size.x - 40), 2)), Color("0c1722"))
	# The inset rim stays outside the screen rectangle owned by the interface.
	draw_rect(screen.grow(3), Color("111e2c"))
	draw_rect(Rect2(screen.position - Vector2(1, 1), screen.size + Vector2(2, 2)), Color("526778"))
	draw_rect(screen, Color("172b40"))
	draw_rect(Rect2(Vector2(30, size.y - 55), Vector2(maxf(0, size.x - 60), 1)), Color("43515e"))
	if _hardware_font != null:
		draw_string(_hardware_font, Vector2(44, size.y - 34), "NORTHSTAR  /  N-7", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("82939f"))
	# Speaker slots and the steady power light are hardware, not game meters.
	for slot in range(12):
		draw_rect(Rect2(floorf(size.x * 0.5) - 34 + slot * 6, size.y - 43, 2, 9), Color("12212d"))
	var power_color := Color("8fc6ce")
	if _day >= 3 and _autonomy >= 65:
		power_color = Color("b8858d")
	draw_rect(Rect2(size.x - 52, size.y - 42, 5, 5), Color("101c28"))
	draw_rect(Rect2(size.x - 51, size.y - 41, 3, 3), power_color)


func _draw_room() -> void:
	# Hand-authored geometry on a two-pixel grid, visible only around the monitor.
	var room_size := (size * 0.5).ceil()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	draw_rect(Rect2(Vector2.ZERO, room_size), Color("111e2c"))
	draw_rect(Rect2(0, 0, room_size.x, room_size.y - 10), Color("263e52"))
	for building in range(20):
		var x := building * 37 - 12
		var roof := 38 + (building * 17) % 59
		draw_rect(Rect2(x, roof, 27, maxf(0, room_size.y - roof - 12)), Color("192b3e"))
		for floor_index in range(3):
			draw_rect(Rect2(x + 5, roof + 5 + floor_index * 8, 2, 2), Color("4d6c80"))
	var travel := int(floorf(_elapsed * 21.0))
	for index in range(RAIN_COLUMNS.size()):
		var x: int = RAIN_COLUMNS[index]
		var y := (index * 29 + travel) % maxi(1, int(room_size.y - 12))
		draw_rect(Rect2(x, y, 1, 5 + index % 4), Color("7292a5"))
		# A second curtain keeps rain visible along the left and right room edges.
		if index < 8:
			draw_rect(Rect2(2 + index % 5, (y + 19) % maxi(1, int(room_size.y - 12)), 1, 5), Color("54788f"))
			draw_rect(Rect2(room_size.x - 3 - index % 5, (y + 47) % maxi(1, int(room_size.y - 12)), 1, 6), Color("6a8ca3"))
	draw_rect(Rect2(0, 3, room_size.x, 2), Color("142331"))
	draw_rect(Rect2(0, room_size.y - 10, room_size.x, 10), Color("182632"))
	draw_rect(Rect2(0, room_size.y - 10, room_size.x, 1), Color("3b4c5c"))
	draw_set_transform(Vector2.ZERO)
