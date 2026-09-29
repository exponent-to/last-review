extends Control
## Decorative pixel workshop. Game rules and simulation time belong to the host.

const SOURCE_SIZE := Vector2(320.0, 120.0)
const ASSET_SIZES := {
	"surroundings": Vector2i(640, 120),
	"workshop": Vector2i(320, 120),
	"cloud": Vector2i(47, 13),
	"smoke": Vector2i(7, 5),
	"worker": Vector2i(32, 22),
}

var _textures: Dictionary = {}
var _motion := true
var _working := true
var _elapsed := 0.0
var _asset_error := false


func _init() -> void:
	custom_minimum_size = SOURCE_SIZE * 2.0
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
	_sync_processing()
	queue_redraw()


func set_motion(enabled: bool) -> void:
	_motion = enabled
	_sync_processing()
	queue_redraw()


func set_working(enabled: bool) -> void:
	_working = enabled
	queue_redraw()


func _sync_processing() -> void:
	set_process(_motion and not _asset_error and is_visible_in_tree())


func _process(delta: float) -> void:
	if get_window().mode == Window.MODE_MINIMIZED:
		return
	# Never catch up decorative time after a stalled or minimized window.
	_elapsed += minf(delta, 0.1)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("818971"))
	if _asset_error:
		draw_string(get_theme_default_font(), Vector2(16, 28),
			"Workshop illustration could not be loaded.", HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16, Color("304b42"))
		return
	if _textures.size() != ASSET_SIZES.size():
		return

	# Integer scaling keeps each source pixel square. Center any letterboxing.
	var fit := minf(size.x / SOURCE_SIZE.x, size.y / SOURCE_SIZE.y)
	var pixel_scale := floorf(fit) if fit >= 1.0 else fit
	if pixel_scale <= 0.0:
		return
	var offset := ((size - SOURCE_SIZE * pixel_scale) * 0.5).floor()
	draw_set_transform(offset, 0.0, Vector2.ONE * pixel_scale)
	draw_texture(_textures["surroundings"], Vector2(-160, 0))
	draw_texture(_textures["workshop"], Vector2.ZERO)

	var cloud_x := floorf(fposmod(_elapsed * 1.4 + 31.0, 367.0)) - 47.0
	_draw_cloud(cloud_x, 12.0)
	cloud_x = floorf(fposmod(_elapsed * 0.8 + 181.0, 367.0)) - 47.0
	_draw_cloud(cloud_x, 7.0)
	if _working:
		for index in range(3):
			var rise := fposmod(_elapsed * 3.0 + index * 7.0, 21.0)
			draw_texture(_textures["smoke"],
				Vector2(217.0 + floorf(rise / 5.0), 23.0 - floorf(rise)))

	var worker_frame := int(floorf(_elapsed * 3.0)) % 2 if _working and _motion else 0
	var worker_x := 153.0 + floorf((sin(_elapsed * 0.28) + 1.0) * 7.0) if _working else 160.0
	draw_texture_rect_region(_textures["worker"], Rect2(worker_x, 84, 16, 22),
		Rect2(worker_frame * 16, 0, 16, 22))
	draw_set_transform(Vector2.ZERO)


func _draw_cloud(x: float, y: float) -> void:
	# Crop at the artwork edge so clouds cannot drift into the letterbox.
	var left := maxf(x, 0.0)
	var width := minf(x + 47.0, SOURCE_SIZE.x) - left
	if width > 0.0:
		draw_texture_rect_region(_textures["cloud"], Rect2(left, y, width, 13),
			Rect2(left - x, 0, width, 13))


func _fail_asset(path: String, reason: String) -> void:
	_asset_error = true
	_textures.clear()
	set_process(false)
	push_error("Workshop scene: %s (%s)" % [path, reason])
	queue_redraw()
