extends Control
## A decorative office whose staffing and terminals reflect the review story.

const SOURCE_SIZE := Vector2(640.0, 72.0)
const ASSET_SIZES := {
	"office": Vector2i(640, 72),
	"office-worker": Vector2i(32, 27),
	"office-terminal": Vector2i(72, 12),
	"office-rain": Vector2i(77, 28),
	"office-indicator": Vector2i(6, 2),
}

var _textures: Dictionary = {}
var _motion := true
var _day := 1
var _autonomy := 0
var _elapsed := 0.0
var _asset_error := false


func _init() -> void:
	custom_minimum_size = Vector2(640.0, 144.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _ready() -> void:
	for asset_name: String in ASSET_SIZES:
		var source_path := "res://art/%s.svg" % asset_name
		var source := FileAccess.get_file_as_string(source_path)
		if source.is_empty():
			_fail_asset(source_path, "missing or empty SVG")
			return
		var image := Image.new()
		var error := image.load_svg_from_string(source, 1.0)
		if error != OK or image.get_size() != ASSET_SIZES[asset_name]:
			_fail_asset(source_path, "SVG decode failed or source size changed")
			return
		_textures[asset_name] = ImageTexture.create_from_image(image)
	resized.connect(queue_redraw)
	visibility_changed.connect(_sync_processing)
	get_window().focus_entered.connect(_sync_processing)
	get_window().focus_exited.connect(_sync_processing)
	_sync_processing()
	queue_redraw()


func set_motion(enabled: bool) -> void:
	_motion = enabled
	_sync_processing()
	queue_redraw()


func set_story(day: int, autonomy: int) -> void:
	_day = clampi(day, 1, 3)
	_autonomy = clampi(autonomy, 0, 100)
	queue_redraw()


func _sync_processing() -> void:
	var active := is_inside_tree() and is_visible_in_tree()
	if active:
		active = get_window().has_focus()
	set_process(_motion and not _asset_error and active)


func _process(delta: float) -> void:
	if get_window().mode == Window.MODE_MINIMIZED or not get_window().has_focus():
		return
	_elapsed += minf(delta, 0.1)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("172330"))
	if _asset_error:
		draw_string(get_theme_default_font(), Vector2(16, 28),
			"Office illustration could not be loaded.", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16, Color("aabfcb"))
		return
	if _textures.size() != ASSET_SIZES.size():
		return
	# Height sets the pixel scale; spare side-room scenery can crop at small widths.
	var fit := size.y / SOURCE_SIZE.y
	var pixel_scale := floorf(fit) if fit >= 1.0 else fit
	if pixel_scale <= 0.0:
		return
	var offset := ((size - SOURCE_SIZE * pixel_scale) * 0.5).floor()
	draw_set_transform(offset, 0.0, Vector2.ONE * pixel_scale)
	draw_texture(_textures["office"], Vector2.ZERO)
	_draw_rain()

	for desk in range(4):
		var automated := desk >= 4 - _automated_terminal_count()
		var terminal_frame := 0
		if automated:
			terminal_frame = 2 if _day == 3 or _autonomy >= 65 else 1
		draw_texture_rect_region(_textures["office-terminal"],
			Rect2(110 + desk * 116, 37, 24, 12), Rect2(terminal_frame * 24, 0, 24, 12))
		if _desk_occupied(desk):
			var pose := int(floorf(_elapsed * 2.0 + desk * 0.5)) % 2 if _motion else 0
			draw_texture_rect_region(_textures["office-worker"],
				Rect2(92 + desk * 116, 35, 16, 27), Rect2(pose * 16, 0, 16, 27))

	var live_servers := clampi(_day * 2 + int(_autonomy / 20.0), 1, 8)
	for index in range(8):
		var column := index / 4
		var row := index % 4
		var indicator_frame := 0
		if index < live_servers:
			indicator_frame = 1
			if _day == 3 and index == 7:
				indicator_frame = 2
			elif _motion and int(floorf(_elapsed * 0.8 + index)) % 5 == 0:
				indicator_frame = 0
		draw_texture_rect_region(_textures["office-indicator"],
			Rect2(555 + column * 29, 21 + row * 9, 2, 2), Rect2(indicator_frame * 2, 0, 2, 2))
	draw_set_transform(Vector2.ZERO)


func _automated_terminal_count() -> int:
	return clampi(_day + int(_autonomy / 35.0), 1, 4)


func _desk_occupied(desk: int) -> bool:
	if _day == 1:
		return true
	if _day == 2:
		return desk != 2
	return desk == 0


func _draw_rain() -> void:
	var phase := (28 - int(floorf(_elapsed * 5.0)) % 28) % 28
	for tile in range(6):
		var x := 46 + tile * 77
		var width := mini(77, 504 - x)
		# Wrap the source strip inside the window; never draw over desks or walls.
		draw_texture_rect_region(_textures["office-rain"],
			Rect2(x, 13, width, 28 - phase), Rect2(0, phase, width, 28 - phase))
		if phase > 0:
			draw_texture_rect_region(_textures["office-rain"],
				Rect2(x, 41 - phase, width, phase), Rect2(0, 0, width, phase))


func _fail_asset(path: String, reason: String) -> void:
	_asset_error = true
	_textures.clear()
	set_process(false)
	push_error("Office scene: %s (%s)" % [path, reason])
	queue_redraw()
