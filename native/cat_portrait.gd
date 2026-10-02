extends TextureRect
## A living cat portrait. `texture` always holds the plain face; blinks, idles,
## the talking flap and hover and poke reactions are overlay frames drawn on top
## of it. Frames swap in whole steps like a sprite sheet and are never tweened.
## Each cat's rhythm is seeded by its name, so it plays the same way every run.
## Build these with Portraits.make().

## The cat was clicked. The click still reaches whatever the face sits on.
signal clicked
signal hover_changed(hovered: bool)

const BLINK_SECONDS := 0.13
## Seconds between blinks, and between idle routines.
const BLINK_GAP := Vector2(2.4, 5.6)
const IDLE_GAP := Vector2(6.0, 10.0)
## How often a blink comes back as a double blink.
const DOUBLE_BLINK := 0.2
const REACT_SECONDS := 0.6
## [art pixels of lift, seconds]: a hop on a poke, a one-pixel bounce on hover.
const HOP := [[1, 0.05], [2, 0.09], [1, 0.05]]
const BOUNCE := [[1, 0.09]]
## Mouth open, shut, open, shut... seconds per step, cycled while talking.
const FLAP: Array[float] = [0.14, 0.1, 0.18, 0.12, 0.12, 0.09, 0.2, 0.13]

const HOVER := 1
const BLINK := 2
const TALK := 4
const CLICK := 8

## Motion-off holds every portrait still; the game's pause freezes them where they are.
static var _motion := true
static var _paused := false
static var _pause_owner: WeakRef = null

var person := ""
var talking := false
var hovered := false
var _frames: Dictionary = {}
var _idles: Array = []
var _blink_rng := RandomNumberGenerator.new()
var _idle_rng := RandomNumberGenerator.new()
## Seconds this portrait has been animating; stops while paused or unfocused.
var _clock := 0.0
var _next_blink := 0.0
var _blink_until := -1.0
var _next_idle := 0.0
var _idle: Array = []
var _idle_started := 0.0
var _idle_count := 0
var _talk_started := 0.0
var _hover_started := -1.0
var _react_started := -1.0
var _react_until := -1.0
var _focused := true
var _posed := false
var _shown_idle := ""
var _shown_flags := 0
var _shown_lift := 0
var _layers: Array[Texture2D] = []


## The game paused or resumed. A pause ends by itself once its owner is freed.
static func set_paused(paused: bool, owner: Object = null) -> void:
	_paused = paused
	_pause_owner = weakref(owner) if paused and owner != null else null


static func is_paused() -> bool:
	if _paused and _pause_owner != null and _pause_owner.get_ref() == null:
		_paused = false
		_pause_owner = null
	return _paused


static func set_motion(enabled: bool) -> void:
	_motion = enabled


func setup(id: String, face: Texture2D, frames: Dictionary, idles: Array) -> void:
	person = id
	texture = face
	_frames = frames
	_idles = idles
	_blink_rng.seed = hash(id + ":blink")
	_idle_rng.seed = hash(id + ":idle")
	_idle_count = _idle_rng.randi_range(0, maxi(0, idles.size() - 1))
	_next_blink = _blink_rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
	_next_idle = _idle_rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
		mouse_exited.connect(_on_mouse_exited)


## Mouth flaps while the cat is talking, and shuts when it stops.
func set_talking(on: bool) -> void:
	if on == talking: return
	talking = on
	_talk_started = _clock
	if on: _idle = []
	_compose()


## React to a poke: a startled or annoyed face for a moment, with a quick hop.
func poke() -> void:
	_react_started = _clock
	_react_until = _clock + REACT_SECONDS
	_idle = []
	_compose()
	clicked.emit()


## Hold a still pose of named frames lifted by `hop` art pixels, for previews
## such as tools/portrait_sheet.gd. An empty pose hands back to the animation.
func pose(frames: Array = [], hop: int = 0) -> void:
	_posed = not frames.is_empty() or hop > 0
	_layers.clear()
	for frame: Variant in frames: _layers.append(_frames[str(frame)])
	_shown_idle = "-"
	_shown_lift = hop
	queue_redraw()
	if not _posed: _compose()


## The overlay frames drawn this instant, bottom to top, and the hop in art pixels.
func layers() -> Array[Texture2D]:
	return _layers


func lift() -> int:
	return _shown_lift


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_ENTER_TREE, NOTIFICATION_VISIBILITY_CHANGED:
			set_process(is_visible_in_tree())
			if not is_visible_in_tree() and hovered: _on_mouse_exited()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_focused = false
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true


func _process(delta: float) -> void:
	if delta <= 0.0 or not _focused or is_paused(): return
	_clock += delta
	if _clock >= _next_blink:
		_blink_until = _clock + BLINK_SECONDS
		var twice := _blink_rng.randf() < DOUBLE_BLINK
		_next_blink = _clock + (BLINK_SECONDS * 2.2 if twice else _blink_rng.randf_range(BLINK_GAP.x, BLINK_GAP.y))
	if not _idle.is_empty() and _clock - _idle_started >= _routine_seconds(_idle):
		_idle = []
	if _clock >= _next_idle:
		if hovered or talking or _react_until > _clock or _idles.is_empty():
			_next_idle = _clock + 1.0
		else:
			_idle = _idles[_idle_count % _idles.size()]
			_idle_count += 1
			_idle_started = _clock
			_next_idle = _clock + _routine_seconds(_idle) + _idle_rng.randf_range(IDLE_GAP.x, IDLE_GAP.y)
	_compose()


func _gui_input(event: InputEvent) -> void:
	# Not accepted: the button or card under the face still gets its click.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		poke()


func _on_mouse_entered() -> void:
	if hovered: return
	hovered = true
	_hover_started = _clock
	_idle = []
	_compose()
	hover_changed.emit(true)


func _on_mouse_exited() -> void:
	if not hovered: return
	hovered = false
	_compose()
	hover_changed.emit(false)


## Pick the frames for this instant; redraw only when they change.
func _compose() -> void:
	if _frames.is_empty() or _posed: return
	var idle := ""
	var flags := 0
	var hop := 0
	if _react_until > _clock:
		flags = CLICK
		if _motion: hop = _step(HOP, _clock - _react_started)
	else:
		if hovered:
			flags |= HOVER
			if _motion: hop = _step(BOUNCE, _clock - _hover_started)
		if _motion:
			idle = _idle_frame()
			if _blink_until > _clock and idle.is_empty(): flags |= BLINK
			if talking and _mouth_open(): flags |= TALK
	if idle == _shown_idle and flags == _shown_flags and hop == _shown_lift: return
	_shown_idle = idle
	_shown_flags = flags
	_shown_lift = hop
	_layers.clear()
	if flags & CLICK:
		_layers.append(_frames.click)
	else:
		if not idle.is_empty(): _layers.append(_frames[idle])
		if flags & HOVER: _layers.append(_frames.hover)
		if flags & BLINK: _layers.append(_frames.blink)
		if flags & TALK: _layers.append(_frames.talk)
	queue_redraw()


func _idle_frame() -> String:
	if _idle.is_empty(): return ""
	var t := _clock - _idle_started
	for step: Array in _idle:
		t -= float(step[1])
		if t < 0.0: return str(step[0])
	return ""


func _mouth_open() -> bool:
	var total := 0.0
	for seconds: float in FLAP: total += seconds
	var t := fmod(_clock - _talk_started, total)
	for index in range(FLAP.size()):
		t -= FLAP[index]
		if t < 0.0: return index % 2 == 0
	return false


static func _routine_seconds(routine: Array) -> float:
	var total := 0.0
	for step: Array in routine: total += float(step[1])
	return total


static func _step(steps: Array, elapsed: float) -> int:
	if elapsed < 0.0: return 0
	for step: Array in steps:
		elapsed -= float(step[1])
		if elapsed < 0.0: return int(step[0])
	return 0


func _draw() -> void:
	if texture == null or (_layers.is_empty() and _shown_lift == 0): return
	# The same square TextureRect draws the face into (keep-aspect, centered).
	var art := texture.get_size()
	var width := int(art.x * size.y / art.y)
	var height := int(size.y)
	if width > size.x:
		width = int(size.x)
		height = int(art.y * width / art.x)
	var rect := Rect2(int((size.x - width) / 2), int((size.y - height) / 2), width, height)
	# A hop lifts the whole picture inside its frame; the face's own bottom rows,
	# drawn underneath, fill the gap it leaves.
	var px := rect.size.y / art.y
	var src := Rect2(0, _shown_lift, art.x, art.y - _shown_lift)
	var dst := Rect2(rect.position, Vector2(rect.size.x, rect.size.y - _shown_lift * px))
	if _shown_lift > 0: draw_texture_rect_region(texture, dst, src)
	for layer: Texture2D in _layers: draw_texture_rect_region(layer, dst, src)
