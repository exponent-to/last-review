extends Control
## The physical monitor and room behind the desktop. All input belongs to its screen.

const SCREEN_INSETS := Vector4(100.0, 108.0, 100.0, 128.0)
## Room-pixel height of the desk's front fascia, measured up from the bottom.
const DESK_EDGE := 6.0
## The desk plane converges on a point above the monitor's centre (room pixels).
const DESK_VANISH_Y := 48.0
## Keyboard rows in key units, each 23u: main block, navigation, numpad. Negative
## widths are gaps; the five rows are numbers, three letter rows, and space.
const KEY_ROWS := [
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2, -0.5, 1, 1, 1, -0.5, 1, 1, 1, 1],
	[1.5, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5, -0.5, 1, 1, 1, -0.5, 1, 1, 1, 1],
	[1.75, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.25, -4, 1, 1, 1, 1],
	[2.25, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 2.75, -1.5, 1, -1.5, 1, 1, 1, 1],
	[1.25, 1.25, 1.25, 6.25, 1.25, 1.25, 1.25, 1.25, -0.5, 1, 1, 1, -0.5, 2, 1, 1],
]
var _motion := true
var _elapsed := 0.0
var _day := 1
var _autonomy := 0
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
		return Color("3d4144").lerp(Color("282b2d"), float(_day_minutes - 540) / 300.0)
	return Color("282b2d").lerp(Color("0a0b0c"), float(_day_minutes - 840) / 240.0)


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
	# The stand sits behind the enclosure; everything else on the desk is in front.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	_draw_stand(floorf(size.x * 0.25), ceilf(case_bottom * 0.5))
	draw_set_transform(Vector2.ZERO)
	# A stepped charcoal/slate enclosure, with a physical lip below the screen.
	draw_rect(Rect2(case_rect.position + Vector2(4, 4), case_rect.size), Color("030303"))
	draw_rect(case_rect, Color("151717"))
	draw_rect(Rect2(case_rect.position + Vector2(2, 2), case_rect.size - Vector2(4, 4)), Color("0f1011"))
	draw_rect(Rect2(case_rect.position + Vector2(2, 0), Vector2(case_rect.size.x - 4, 2)), Color("323537"))
	draw_rect(Rect2(case_rect.position + Vector2(0, 2), Vector2(2, case_rect.size.y - 4)), Color("242628"))
	draw_rect(Rect2(Vector2(case_rect.end.x - 2, case_rect.position.y + 2), Vector2(2, case_rect.size.y - 4)), Color("080808"))
	draw_rect(Rect2(Vector2(case_rect.position.x + 2, case_bottom - 2), Vector2(case_rect.size.x - 4, 2)), Color("050606"))
	# The inset rim stays outside the screen rectangle owned by the interface.
	draw_rect(screen.grow(3), Color("080809"))
	draw_rect(Rect2(screen.position - Vector2(1, 1), screen.size + Vector2(2, 2)), Color("2a2c2e"))
	draw_rect(screen, Color("0c0d0e"))
	draw_rect(Rect2(Vector2(screen.position.x, screen.end.y + 3), Vector2(screen.size.x, 1)), Color("1f2022"))
	# Speaker slots and the steady power light are hardware, not game meters.
	for slot in range(12):
		draw_rect(Rect2(floorf(size.x * 0.5) - 34 + slot * 6, screen.end.y + 15, 2, 9), Color("08090a"))
	var power_color := Color("6fdc8c")
	if _day >= 3 and _autonomy >= 65:
		power_color = Color("e5384a")
	draw_rect(Rect2(screen.end.x - 22, screen.end.y + 16, 5, 5), Color("070808"))
	draw_rect(Rect2(screen.end.x - 21, screen.end.y + 17, 3, 3), power_color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	_draw_desk_props(floorf(size.x * 0.25), ceilf(case_bottom * 0.5))
	draw_set_transform(Vector2.ZERO)


func _draw_room() -> void:
	# Two-pixel architectural drawing: recessed glass, wall, then a desk plane.
	var room_size := (size * 0.5).ceil()
	var desk_y := room_size.y - 62
	var window_bottom := desk_y - 73
	var glass := Rect2(23, 16, room_size.x - 46, window_bottom - 16)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(2, 2))
	draw_rect(Rect2(Vector2.ZERO, room_size), Color("0a0a0b"))
	# Wall surfaces, with a darker return on the right and a narrow ceiling seam.
	draw_rect(Rect2(4, 5, room_size.x - 8, desk_y - 5), Color("191a1b"))
	draw_rect(Rect2(room_size.x - 12, 5, 8, desk_y - 5), Color("111213"))
	draw_rect(Rect2(4, 3, room_size.x - 8, 2), Color("282a2d"))
	# Deep window reveal surrounds the glazing instead of continuing to the desk.
	draw_rect(Rect2(12, 8, room_size.x - 24, window_bottom + 2), Color("0a0b0b"))
	draw_rect(Rect2(15, 11, room_size.x - 30, window_bottom - 5), Color("313437"))
	draw_rect(Rect2(18, 14, room_size.x - 36, window_bottom - 12), Color("141516"))
	draw_rect(glass, _sky_color())
	_draw_city(glass)
	_draw_window_rain(glass)
	# Inner seals, mullions and the underside of the upper reveal.
	draw_rect(Rect2(21, 14, room_size.x - 42, 3), Color("0a0b0c"))
	for x: float in [20.0, floorf(room_size.x * 0.5), room_size.x - 24.0]:
		draw_rect(Rect2(x, 14, 4, window_bottom - 14), Color("0c0d0e"))
		draw_rect(Rect2(x + 3, 17, 1, window_bottom - 17), Color("393b3f"))
	draw_rect(Rect2(20, 37, room_size.x - 40, 4), Color("0c0d0e"))
	draw_rect(Rect2(20, 41, room_size.x - 40, 1), Color("3b3e41"))
	# Sill top projects into the room, its front and cast shadow giving depth.
	draw_colored_polygon(PackedVector2Array([
		Vector2(19, window_bottom), Vector2(room_size.x - 19, window_bottom),
		Vector2(room_size.x - 8, window_bottom + 9), Vector2(8, window_bottom + 9)
	]), Color("35383b"))
	draw_rect(Rect2(8, window_bottom + 9, room_size.x - 16, 4), Color("232527"))
	draw_rect(Rect2(8, window_bottom + 9, room_size.x - 16, 1), Color("4c5054"))
	draw_rect(Rect2(12, window_bottom + 13, room_size.x - 24, 7), Color("131315"))
	# Under-window wall rail and a radiator, partially hidden behind the monitor.
	draw_rect(Rect2(4, window_bottom + 45, room_size.x - 8, 1), Color("222426"))
	draw_rect(Rect2(4, desk_y - 7, room_size.x - 8, 5), Color("121313"))
	var radiator := Rect2(room_size.x - 57, window_bottom + 27, 39, 32)
	draw_rect(Rect2(radiator.position + Vector2(3, 3), radiator.size), Color("131315"))
	draw_rect(radiator, Color("3c3f43"))
	for fin in range(6):
		draw_rect(Rect2(radiator.position + Vector2(3 + fin * 6, 3), Vector2(3, 26)), Color("202224"))
		draw_rect(Rect2(radiator.position + Vector2(2 + fin * 6, 3), Vector2(1, 26)), Color("505559"))
	draw_rect(Rect2(radiator.position + Vector2(-5, 6), Vector2(5, 4)), Color("36393b"))
	draw_rect(Rect2(radiator.position + Vector2(-7, 4), Vector2(3, 8)), Color("54595d"))
	draw_rect(Rect2(radiator.position + Vector2(33, 32), Vector2(3, 10)), Color("2a2c2e"))
	# A small outlet and its cable disappear naturally behind the desk.
	draw_rect(Rect2(25, window_bottom + 29, 12, 16), Color("303335"))
	draw_rect(Rect2(27, window_bottom + 31, 8, 12), Color("53585d"))
	draw_rect(Rect2(29, window_bottom + 36, 5, 4), Color("141516"))
	draw_rect(Rect2(30, window_bottom + 40, 2, desk_y - window_bottom - 49), Color("0c0c0d"))
	for step in range(7):
		draw_rect(Rect2(31 + step * 2, desk_y - 9 + step * 2, 2, 2), Color("0c0c0d"))
	# Desk top: a lit back lip against the wall, an even laminate surface, then a
	# rounded front edge whose fascia falls away into shadow toward the viewer.
	var edge_y := room_size.y - DESK_EDGE
	draw_rect(Rect2(0, desk_y, room_size.x, edge_y - desk_y), Color("1a1b1e"))
	draw_rect(Rect2(0, desk_y - 1, room_size.x, 2), Color("3d4044"))
	draw_rect(Rect2(0, desk_y + 1, room_size.x, 2), Color("141517"))
	draw_rect(Rect2(0, edge_y, room_size.x, 1), Color("3a3d41"))
	draw_rect(Rect2(0, edge_y + 1, room_size.x, 1), Color("26282b"))
	draw_rect(Rect2(0, edge_y + 2, room_size.x, room_size.y - edge_y - 3), Color("121315"))
	draw_rect(Rect2(0, room_size.y - 1, room_size.x, 1), Color("060606"))
	draw_set_transform(Vector2.ZERO)


## Where a desk point at `x` on row `from_y` lands on row `to_y`: in one-point
## perspective, everything lying on the desk widens toward the viewer.
func _desk_x(x: float, from_y: float, to_y: float) -> float:
	var vanish_x := floorf(size.x * 0.25)
	return roundf(vanish_x + (x - vanish_x) * (to_y - DESK_VANISH_Y) / (from_y - DESK_VANISH_Y))


## A shape lying flat on the desk, given by its far edge, drawn as crisp rows.
## `rounding` trims the far corners, tapering over as many rows.
func _desk_quad(left: float, right: float, top: float, rows: int, color: Color, rounding := 0) -> void:
	for row in range(rows):
		var y := top + row
		var inset := float(maxi(0, rounding - row))
		var l := _desk_x(left, top, y) + inset
		var r := _desk_x(right, top, y) - inset
		if r > l:
			draw_rect(Rect2(l, y, r - l, 1), color)


func _draw_stand(cx: float, case_bottom: float) -> void:
	# A broad, low foot plate on the desk, with the neck rising behind the case.
	var foot := case_bottom + 8
	_desk_quad(cx - 75, cx + 75, foot + 6, 1, Color("08090a"))
	_desk_quad(cx - 73, cx + 73, foot + 4, 2, Color("131416"))
	_desk_quad(cx - 72, cx + 72, foot, 4, Color("2a2c30"), 3)
	_desk_quad(_desk_x(cx - 72, foot, foot + 3), _desk_x(cx + 72, foot, foot + 3), foot + 3, 1, Color("3c3f44"))
	# The neck faces the viewer, so it stays darker than the lit plate it stands on.
	var neck_top := case_bottom - 2
	var neck := Rect2(cx - 16, neck_top, 32, foot + 2 - neck_top)
	draw_rect(neck, Color("1f2023"))
	draw_rect(Rect2(neck.position, Vector2(2, neck.size.y)), Color("313337"))
	draw_rect(Rect2(neck.end.x - 5, neck_top, 5, neck.size.y), Color("131416"))
	draw_rect(Rect2(cx - 19, foot + 2, 38, 1), Color("17181a"))


func _draw_desk_props(cx: float, case_bottom: float) -> void:
	var room_size := (size * 0.5).ceil()
	# A felt mat under the keyboard and mouse, edged where it meets the desk.
	var mat := case_bottom + 15
	_desk_quad(cx - 162, cx + 214, mat, int(room_size.y - DESK_EDGE - 1 - mat), Color("141518"), 2)
	_desk_quad(cx - 162, cx + 214, mat, 1, Color("202226"), 2)
	_draw_keyboard(cx, case_bottom + 16)
	_draw_mouse(cx + 170, case_bottom + 21)
	_draw_ink_pad(cx - 258, case_bottom + 25)
	_draw_stamp(cx - 242, case_bottom + 28, Color("c0202f"))
	_draw_stamp(cx - 204, case_bottom + 33, Color("2f8a4f"))
	_draw_tray(room_size.x - 100, room_size.x - 22, case_bottom + 6)
	_draw_mug(8, case_bottom + 36)


func _draw_keyboard(cx: float, top: float) -> void:
	# A full-size office keyboard: a back rim with lock lights, five rows of keycaps
	# whose fronts catch less light, then the case front and its contact shadow.
	var left := cx - 150
	var right := cx + 150
	_desk_quad(left - 1, right + 1, top + 21, 1, Color("08090a"))
	_desk_quad(left, right, top + 18, 3, Color("131416"))
	_desk_quad(left, right, top, 18, Color("1e1f22"), 2)
	_desk_quad(_desk_x(left, top, top + 18), _desk_x(right, top, top + 18), top + 18, 1, Color("2c2e32"))
	for row in range(KEY_ROWS.size()):
		var y := top + 2 + row * 3
		var l := _desk_x(left + 4, top, y)
		var units := 0.0
		for width in KEY_ROWS[row]:
			units += absf(float(width))
		var unit := (_desk_x(right - 4, top, y) - l) / units
		var at := 0.0
		for width in KEY_ROWS[row]:
			var span := absf(float(width))
			if float(width) > 0.0:
				var x0 := l + roundf(at * unit)
				var x1 := l + roundf((at + span) * unit) - 1
				draw_rect(Rect2(x0, y, x1 - x0, 2), Color("383b3f"))
				draw_rect(Rect2(x0, y + 2, x1 - x0, 1), Color("27292c"))
			at += span
	# Lock lights above the numpad; only num lock is on.
	var lights := _desk_x(right - 4, top, top) - 40
	for light in range(3):
		draw_rect(Rect2(lights + light * 6, top, 2, 1), Color("6fdc8c") if light == 0 else Color("0e0f10"))


func _draw_mouse(x: float, top: float) -> void:
	# A dome-shaped mouse: lit from the screen above, its underside curving away.
	const INSETS := [8, 5, 3, 2, 2, 1, 1, 1, 1, 1, 2, 3, 5]
	draw_rect(Rect2(x + 3, top + INSETS.size(), 20, 1), Color("08090a"))
	for row in range(INSETS.size()):
		var inset: int = INSETS[row]
		var width := 26 - inset * 2
		var body := Color("2a2c30") if row < 9 else Color("1b1c1f")
		draw_rect(Rect2(x + inset, top + row, width, 1), body)
		if row > 0 and row < 9:
			draw_rect(Rect2(x + inset, top + row, 3, 1), Color("3b3e43"))
			draw_rect(Rect2(x + 26 - inset - 4, top + row, 4, 1), Color("1d1e21"))
	draw_rect(Rect2(x + 13, top, 1, 5), Color("141517"))
	draw_rect(Rect2(x + 12, top + 1, 3, 2), Color("4a4e52"))


func _draw_ink_pad(x: float, top: float) -> void:
	# A shallow tin pad, its felt soaked in red ink.
	_desk_quad(x - 1, x + 47, top + 8, 1, Color("08090a"))
	_desk_quad(x, x + 46, top + 5, 3, Color("1b1c1f"))
	_desk_quad(x, x + 46, top, 5, Color("3a3d41"), 1)
	_desk_quad(x + 3, x + 43, top + 1, 3, Color("5a161f"))
	_desk_quad(x + 3, x + 43, top + 1, 1, Color("8f2230"))


func _draw_stamp(x: float, base: float, ink: Color) -> void:
	# A rubber stamp standing on its inked die: a wide mount with a coloured label,
	# a short turned neck, and a rounded knob.
	draw_rect(Rect2(x - 1, base, 24, 1), Color("08090a"))
	draw_rect(Rect2(x, base - 1, 22, 1), ink.darkened(0.35))
	draw_rect(Rect2(x, base - 9, 22, 8), Color("2c2e32"))
	draw_rect(Rect2(x, base - 9, 22, 1), Color("44474c"))
	draw_rect(Rect2(x + 18, base - 8, 4, 7), Color("1e1f22"))
	draw_rect(Rect2(x + 3, base - 7, 14, 4), ink)
	draw_rect(Rect2(x + 5, base - 6, 10, 2), ink.darkened(0.4))
	draw_rect(Rect2(x + 9, base - 13, 4, 4), Color("1e1f22"))
	draw_rect(Rect2(x + 9, base - 13, 1, 4), Color("383b3f"))
	draw_rect(Rect2(x + 5, base - 20, 12, 7), Color("2c2e32"))
	draw_rect(Rect2(x + 6, base - 21, 10, 1), Color("44474c"))
	draw_rect(Rect2(x + 5, base - 19, 2, 5), Color("44474c"))
	draw_rect(Rect2(x + 14, base - 19, 3, 6), Color("1e1f22"))
	draw_rect(Rect2(x + 6, base - 13, 10, 1), Color("1e1f22"))


func _draw_tray(left: float, right: float, top: float) -> void:
	# An outbox of reviewed printouts: the top sheet carries a fresh red stamp, and
	# the lip is smudged where inky fingers have lifted the stack.
	var lip := top + 13
	_desk_quad(left - 1, right + 1, lip + 7, 1, Color("08090a"))
	_desk_quad(left, right, top - 2, lip - top + 2, Color("151618"), 1)
	_desk_quad(left + 3, right - 3, top, lip - top, Color("4d5155"))
	for line in range(5):
		var y := top + 2 + line * 2
		var start := _desk_x(left + 8, top, y)
		draw_rect(Rect2(start, y, [40, 52, 30, 46, 22][line], 1), Color("393c40"))
	var mark := Rect2(_desk_x(right - 34, top, top + 5), top + 5, 24, 6)
	draw_rect(mark, Color("c0202f"))
	draw_rect(mark.grow(-1), Color("4d5155"))
	draw_rect(Rect2(mark.position + Vector2(3, 2), Vector2(18, 2)), Color("c0202f"))
	_desk_quad(_desk_x(left, top - 2, lip), _desk_x(right, top - 2, lip), lip, 7, Color("1e2023"))
	_desk_quad(_desk_x(left, top - 2, lip), _desk_x(right, top - 2, lip), lip, 1, Color("383b3f"))
	_draw_pen(_desk_x(left + 9, top, lip - 3), lip - 3)
	for smudge: Vector3 in [Vector3(12, 2, 3), Vector3(16, 4, 2), Vector3(57, 3, 2)]:
		draw_rect(Rect2(_desk_x(left + smudge.x, top - 2, lip), lip + smudge.y, smudge.z, 1), Color("4a161c"))


func _draw_pen(x: float, y: float) -> void:
	# A review pen lying across the sheet, its red cap and clip toward the right.
	draw_rect(Rect2(x - 1, y + 1, 32, 1), Color("2e3134"))
	draw_rect(Rect2(x - 2, y, 2, 1), Color("70767b"))
	draw_rect(Rect2(x, y - 1, 26, 1), Color("3a3d41"))
	draw_rect(Rect2(x, y, 26, 1), Color("17181a"))
	draw_rect(Rect2(x + 25, y - 1, 6, 2), Color("c0202f"))
	draw_rect(Rect2(x + 21, y - 2, 7, 1), Color("70767b"))


func _draw_mug(x: float, base: float) -> void:
	# A tall ceramic mug: an elliptical rim around dark coffee, a shaded body and a
	# hollow handle. Its coffee steams through the morning, then goes cold.
	var top := base - 40
	draw_rect(Rect2(x - 1, base, 54, 1), Color("08090a"))
	draw_rect(Rect2(x + 1, base - 1, 38, 1), Color("383c3f"))
	draw_rect(Rect2(x, top + 4, 40, base - top - 5), Color("4f5458"))
	draw_rect(Rect2(x + 3, top + 6, 3, base - top - 10), Color("666b70"))
	draw_rect(Rect2(x + 27, top + 5, 13, base - top - 6), Color("3d4144"))
	draw_rect(Rect2(x + 36, top + 5, 4, base - top - 6), Color("2e3134"))
	# Rim and coffee, as an ellipse seen from slightly above.
	draw_rect(Rect2(x + 5, top, 30, 1), Color("70767b"))
	draw_rect(Rect2(x + 2, top + 1, 36, 3), Color("70767b"))
	draw_rect(Rect2(x, top + 3, 40, 2), Color("80868b"))
	draw_rect(Rect2(x + 6, top + 1, 28, 1), Color("1c1512"))
	draw_rect(Rect2(x + 4, top + 2, 32, 1), Color("140f0d"))
	draw_rect(Rect2(x + 7, top + 3, 26, 1), Color("140f0d"))
	# A small prompt glyph printed on the glaze.
	for pixel: Vector2 in [Vector2(12, 17), Vector2(13, 18), Vector2(12, 19), Vector2(15, 19), Vector2(16, 19), Vector2(17, 19)]:
		draw_rect(Rect2(Vector2(x, top) + pixel, Vector2.ONE), Color("6fdc8c"))
	# Handle, open in the middle so the desk shows through.
	draw_rect(Rect2(x + 40, top + 10, 7, 3), Color("4a4e52"))
	draw_rect(Rect2(x + 45, top + 12, 4, 15), Color("3d4144"))
	draw_rect(Rect2(x + 40, top + 26, 7, 3), Color("3d4144"))
	draw_rect(Rect2(x + 40, top + 10, 7, 1), Color("666b70"))
	# Steam: two faint wisps that sway as they rise, fading with height and as the
	# morning wears on.
	var heat := clampf(1.0 - float(_day_minutes - 540) / 210.0, 0.0, 1.0)
	if heat <= 0.0:
		return
	for wisp in range(2):
		for rise in range(10):
			var sway := roundf(sin(_elapsed * 1.6 - rise * 0.55 + wisp * 2.1) * 1.4)
			var tint := Color("9aa4a8")
			tint.a = 0.20 * heat * (1.0 - rise / 10.0)
			draw_rect(Rect2(x + 14 + wisp * 11 + sway, top - 2 - rise * 2, 1, 2), tint)


func _draw_city(glass: Rect2) -> void:
	var evening := clampf(float(_day_minutes - 780) / 300.0, 0.0, 1.0)
	# The far blocks sit in rain haze; their rooflines and equipment remain visible
	# above the monitor. Stable patterns keep lights from flickering on redraw.
	for building in range(20):
		var x := glass.position.x - 18 + building * 37
		var roof := 27 + (building * 17) % 55
		var width := 25 + (building % 3) * 4
		var facade := Color("242628").lerp(Color("141516"), evening)
		_city_rect(Rect2(x, roof, width, glass.end.y - roof), glass, facade)
		_city_rect(Rect2(x + width - 5, roof, 5, glass.end.y - roof), glass, Color("191b1c"))
		_city_rect(Rect2(x - 1, roof, width + 2, 2), glass, Color("393c3f").lerp(Color("222426"), evening))
		_city_rect(Rect2(x + 5, roof - 5, 9, 5), glass, Color("1b1d1e"))
		for floor_index in range(32):
			var y := roof + 6 + floor_index * 12
			for column in range(3):
				var lit := (building * 11 + floor_index * 7 + column * 3) % 7 < 1
				var tint := Color("393d3f").lerp(Color("d8b26a"), evening) if lit else Color("191b1d").lerp(Color("0c0d0e"), evening)
				_city_rect(Rect2(x + 4 + column * 7, y, 3, 4), glass, tint)
	# Nearby buildings are anchored at the exposed sides, so their detail isn't
	# lost behind the monitor when the window changes size.
	_draw_neighbor(glass.position.x - 7, 102, 56, glass, false, evening)
	_draw_neighbor(glass.end.x - 49, 118, 58, glass, true, evening)
	_draw_neon(glass, evening)


func _draw_neon(glass: Rect2, evening: float) -> void:
	# A rooftop corporate sign in the strip of window above the monitor; it hums
	# brighter after dark and one letter keeps failing.
	var sign := Rect2(glass.end.x - 150, 18, 66, 9)
	var hum := 0.85 + 0.15 * sin(_elapsed * 7.0) * sin(_elapsed * 2.3)
	var red := Color("e5384a").lerp(Color("ff5566"), evening)
	var glow := red
	glow.a = (0.10 + evening * 0.12) * hum
	_room_rect(sign.grow(5), glass, glow)
	_room_rect(sign.grow(2), glass, Color(glow, glow.a * 1.6))
	_room_rect(sign, glass, Color("1a0a0d"))
	for letter in range(9):
		var block := Rect2(sign.position.x + 2 + letter * 7, sign.position.y + 2, 5, 5)
		var lit := red if (letter != 6 or fmod(_elapsed, 5.0) > 0.3) else Color("4a161c")
		_room_rect(block, glass, Color(lit, hum))
		_room_rect(Rect2(block.position + Vector2(1, 1), Vector2(3, 3)), glass, Color("1a0a0d") if letter % 2 == 0 else Color(lit, hum))
	draw_rect(Rect2(sign.position.x + 10, sign.end.y, 2, 6), Color("121315"))
	draw_rect(Rect2(sign.end.x - 12, sign.end.y, 2, 6), Color("121315"))
	# Aircraft-warning beacons on the far rooftops blink out of phase.
	for index in range(5):
		var beacon := Vector2(glass.position.x + 40 + index * 113, 20 + (index * 5) % 9)
		if fmod(_elapsed + index * 0.7, 2.4) < 0.5:
			_room_rect(Rect2(beacon - Vector2(1, 1), Vector2(3, 3)), glass, Color("ff4455"))


func _draw_neighbor(x: float, roof: float, width: float, glass: Rect2, modern: bool, evening: float) -> void:
	var face := Color("1a1b1d") if modern else Color("1e1f22")
	face = face.lerp(Color("101112"), evening * 0.7)
	_city_rect(Rect2(x, roof, width, glass.end.y - roof), glass, face)
	_city_rect(Rect2(x + width - 9, roof, 9, glass.end.y - roof), glass, Color("0e0f11"))
	# A roof lip and shaded return provide depth without busy rooftop clutter.
	_city_rect(Rect2(x - 1, roof, width + 2, 2), glass, Color("2f3235").lerp(Color("202224"), evening))
	_city_rect(Rect2(x, roof + 2, width, 2), glass, Color("131415"))
	for floor_index in range(30):
		var y := roof + 11 + floor_index * 18
		if y >= glass.end.y: break
		for column in range(3):
			var wx := x + 6 + column * 13
			var lit := (floor_index * 5 + column * 3 + (2 if modern else 0)) % 11 < 2
			var tint := Color("36393b").lerp(Color("b89a62"), evening) if lit else Color("171719").lerp(Color("0d0e0f"), evening)
			_city_rect(Rect2(wx, y, 6, 8), glass, tint)
			_city_rect(Rect2(wx, y + 8, 6, 1), glass, Color("252729"))


func _city_rect(rect: Rect2, glass: Rect2, color: Color) -> void:
	# Avoid thousands of invisible facade details behind the opaque monitor.
	var screen := get_screen_rect(size)
	var occlusion := Rect2((screen.position - Vector2(12, 12)) * 0.5, (screen.size + Vector2(24, 48)) * 0.5)
	if not occlusion.encloses(rect): _room_rect(rect, glass, color)


func _room_rect(rect: Rect2, bounds: Rect2, color: Color) -> void:
	var clipped := rect.intersection(bounds)
	if clipped.has_area():
		draw_rect(clipped, color)


static func _rain_seed(index: int, salt: int) -> float:
	# Stable rain phases across frames and resizing, without touching gameplay RNG.
	return fposmod(sin(float(index) * 127.1 + float(salt) * 311.7) * 43758.5453, 1.0)


func _draw_window_rain(glass: Rect2) -> void:
	if glass.size.x <= 0 or glass.size.y <= 0: return
	var light := Color("9aa4a8").lerp(Color("5c6870"), float(_day_minutes - 540) / 540.0)
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
