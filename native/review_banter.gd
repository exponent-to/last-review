extends Control
## The open PR's author sits in Review's top-left corner and talks while you review.
## It hears only what the reviewer visibly does: opening a PR, idling, flagging,
## withdrawing, stamping, and asking Helios. It never sees audit data, so a line
## can never hint whether a change is clean or whether a flag is right.

const Banter = preload("res://content/banter.gd")
const TerminalFont: FontFile = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
const PORTRAITS := "res://native/portraits.gd"
const PORTRAIT := 56
## Widest a speech bubble grows; it wraps beyond this.
const WIDTH := 420
## Space between the portrait and the bubble's tail.
const GAP := 4.0
const LINE_SECONDS := 4.6
## A goodbye is cut short when the next author is already waiting to talk.
const HANDOFF_SECONDS := 2.8
const FADE_IN := 0.16
const FADE_OUT := 0.4
const IDLE_SECONDS := 12.0
const FONT_SIZE := 12
const PAD := Vector2(9, 6)
const TAIL := 9.0
const SHADOW := 3.0
const MIN_BUBBLE := 64.0
const BUBBLE := Color("e6e2d6")
const INK := Color("121412")
const DIM := Color("8c8981")
const GREEN := Color("6fdc8c")
const FAREWELLS: Array[String] = ["approved", "changes"]

## Orientation keeps the desk quiet: only Maya's one greeting.
var quiet := false
## The open PR and its author; empty when no PR is open.
var pr_id := ""
var author := ""
## Who is talking and what they are saying; empty when silent.
var speaker := ""
var line := ""
var kind := ""
## Unpaused seconds since the reviewer last did something visible.
var idle_seconds := 0.0
var _age := 0.0
var _line_pr := ""
var _queued: Dictionary = {}
var _counts: Dictionary = {}
var _last_said: Dictionary = {}
var _quiet_greeted := false
var _text_width := 0.0
var _body := Vector2.ZERO
var _tail_tip := Vector2.ZERO
var _rest_y := 0.0
var _bubble: Control
var _seat: Control
var _portrait_for := "-"
var _name: Label


func _init() -> void:
	name = "ReviewBanter"
	custom_minimum_size = Vector2(PORTRAIT + GAP + TAIL + MIN_BUBBLE, PORTRAIT + 16)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble = Control.new()
	_bubble.name = "SpeechBubble"
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble.modulate.a = 0.0
	_bubble.draw.connect(_draw_bubble)
	add_child(_bubble)
	_seat = Control.new()
	_seat.name = "Portrait"
	_seat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seat.size = Vector2(PORTRAIT, PORTRAIT)
	add_child(_seat)
	_name = Label.new()
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_name.add_theme_font_override("font", TerminalFont)
	_name.add_theme_font_size_override("font_size", 11)
	_name.add_theme_color_override("font_color", DIM)
	add_child(_name)
	resized.connect(_layout)
	visible = false


## A PR became active. Revisions (v2 and later) get their own opener.
func open_pr(id: String, who: String, revision: int = 1) -> void:
	pr_id = id
	author = who
	idle_seconds = 0.0
	if quiet:
		if _quiet_greeted or who.to_lower() != "maya":
			_say("", "", "")
			return
		_quiet_greeted = true
	var trigger := "revision" if revision > 1 else "open"
	var text := _pick(who, trigger, id)
	if kind in FAREWELLS:
		# The last author is still saying goodbye; this one waits a beat.
		_queued = {"speaker": who, "text": text, "kind": trigger, "pr": id}
		_refresh()
	else:
		_queued = {}
		_say(who, text, trigger)


## No PR is open. A goodbye already underway finishes, then the desk empties.
func close_pr() -> void:
	pr_id = ""
	author = ""
	idle_seconds = 0.0
	_queued = {}
	if kind not in FAREWELLS: _say("", "", "")
	else: _refresh()


## The reviewer visibly did something to the open PR: flag, withdraw, consult.
func react(trigger: String) -> void:
	if quiet or pr_id.is_empty(): return
	idle_seconds = 0.0
	_queued = {}
	_say(author, _pick(author, trigger, pr_id), trigger)


## The reviewer stamped a PR. Its author reacts to the verdict alone.
func farewell(who: String, verdict: String, id: String = "") -> void:
	if quiet or who.is_empty(): return
	idle_seconds = 0.0
	# A greeting for a PR that opened in the same moment plays after the goodbye.
	var greeting: Dictionary = {}
	if kind in ["open", "revision"] and _line_pr == pr_id and _line_pr != id:
		greeting = {"speaker": speaker, "text": line, "kind": kind, "pr": _line_pr}
	var trigger := "approved" if verdict == "approve" else "changes"
	_say(who, _pick(who, trigger, id), trigger, id)
	_queued = greeting


## Advance by unpaused game time. The caller skips this while paused.
func tick(delta: float) -> void:
	if delta <= 0.0: return
	if not line.is_empty():
		_age += delta
		if _age >= _duration():
			var queued := _queued
			_queued = {}
			if queued.is_empty(): _say("", "", "")
			else: _say(str(queued.speaker), str(queued.text), str(queued.kind), str(queued.pr))
	if not quiet and not pr_id.is_empty() and is_visible_in_tree():
		idle_seconds += delta
		if idle_seconds >= IDLE_SECONDS and line.is_empty():
			idle_seconds = 0.0
			_say(author, _pick(author, "idle", pr_id), "idle")
	_fade()


func is_speaking() -> bool:
	return not line.is_empty()


func bubble_rect() -> Rect2:
	return Rect2(_bubble.position, _bubble.size) if is_speaking() else Rect2()


## The cat portrait once the portraits module exists; a lettered square until then.
static func make_portrait(person: String, side: int = PORTRAIT) -> Control:
	if ResourceLoader.exists(PORTRAITS):
		var portraits: Variant = load(PORTRAITS)
		if portraits is Script:
			for method: Dictionary in portraits.get_script_method_list():
				if str(method.name) == "make":
					var made: Variant = portraits.make(person, side)
					if made is Control: return made
					break
	return _placeholder(person, side)


static func _placeholder(person: String, side: int) -> Control:
	var frame := PanelContainer.new()
	frame.name = "PlaceholderPortrait"
	frame.custom_minimum_size = Vector2(side, side)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0d0f0d")
	style.border_color = Color(GREEN, 0.55)
	style.set_border_width_all(1)
	frame.add_theme_stylebox_override("panel", style)
	var initial := Label.new()
	initial.text = person.left(1).to_upper()
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.add_theme_font_override("font", TerminalFont)
	initial.add_theme_font_size_override("font_size", int(side * 0.46))
	initial.add_theme_color_override("font_color", GREEN)
	frame.add_child(initial)
	return frame


func _pick(who: String, trigger: String, id: String) -> String:
	# Deterministic: PR id and trigger pick the opening line, a counter walks on,
	# and the author never repeats the same line twice in a row.
	var key := id + ":" + trigger
	var count := int(_counts.get(key, 0))
	_counts[key] = count + 1
	var index := (key.hash() & 0x7fffffff) + count
	var text := Banter.line(who, trigger, index)
	var last_key := who.to_lower() + ":" + trigger
	if text == str(_last_said.get(last_key, "")): text = Banter.line(who, trigger, index + 1)
	_last_said[last_key] = text
	return text


func _say(who: String, text: String, trigger: String, id: String = pr_id) -> void:
	speaker = who if not text.is_empty() else ""
	line = text
	kind = trigger if not text.is_empty() else ""
	_line_pr = id if not text.is_empty() else ""
	_age = 0.0
	_refresh()
	_layout()
	_fade()


func _duration() -> float:
	return HANDOFF_SECONDS if not _queued.is_empty() else LINE_SECONDS


func _refresh() -> void:
	visible = not pr_id.is_empty() or not line.is_empty()
	var who := speaker if not speaker.is_empty() else author
	_name.text = who.to_upper()
	if who.to_lower() != _portrait_for:
		_portrait_for = who.to_lower()
		for child: Node in _seat.get_children():
			_seat.remove_child(child)
			child.queue_free()
		if not who.is_empty():
			var portrait := make_portrait(who, PORTRAIT)
			# A live cat can be poked; the lettered placeholder stays inert.
			if portrait.has_signal("clicked"): portrait.clicked.connect(_poked)
			else: portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_seat.add_child(portrait)
			portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for seated: Node in _seat.get_children():
		if seated.has_method("set_talking"): seated.set_talking(is_speaking())


## The reviewer clicked the seated cat. A goodbye already underway plays out.
func _poked() -> void:
	if kind not in FAREWELLS: react("poke")


func _layout() -> void:
	# Portrait in the corner, name beneath it, bubble to the right with its
	# tail pointing back at the face.
	var side := float(PORTRAIT)
	_seat.position = Vector2.ZERO
	_seat.size = Vector2(side, side)
	_name.position = Vector2(-8, side + 1)
	_name.size = Vector2(side + 16, 14)
	if line.is_empty():
		# Shrink back to the portrait when nobody is talking.
		_bubble.size = Vector2.ZERO
		if not is_equal_approx(custom_minimum_size.y, side + 16.0): custom_minimum_size.y = side + 16.0
		return
	var left := side + GAP
	# Before the first real layout the width can be tiny; never wrap narrower
	# than a readable column, or the strip balloons to a tall sliver.
	var widest := maxf(180.0, minf(WIDTH, size.x - left - TAIL - SHADOW) - PAD.x * 2)
	var natural := TerminalFont.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_text_width = maxf(16.0, minf(ceilf(natural) + 1.0, widest))
	var text := TerminalFont.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, _text_width, FONT_SIZE)
	_body = Vector2(maxf(MIN_BUBBLE, ceilf(text.x) + PAD.x * 2), ceilf(text.y) + PAD.y * 2)
	_rest_y = 4.0
	_bubble.position = Vector2(left, _rest_y)
	_bubble.size = Vector2(TAIL, 0) + _body + Vector2(SHADOW, SHADOW)
	_tail_tip = Vector2(0, minf(_body.y * 0.5, side * 0.45 - _rest_y))
	var tall := maxf(side + 16.0, _rest_y + _bubble.size.y + 2.0)
	if not is_equal_approx(custom_minimum_size.y, tall): custom_minimum_size.y = tall
	_bubble.queue_redraw()


func _fade() -> void:
	if line.is_empty():
		_bubble.modulate.a = 0.0
		return
	var shown := clampf(_age / FADE_IN, 0.0, 1.0)
	var leaving := clampf((_duration() - _age) / FADE_OUT, 0.0, 1.0)
	_bubble.modulate.a = minf(shown, leaving)
	# A small upward pop as the line appears.
	_bubble.position.y = _rest_y + (1.0 - shown) * 4.0


func _draw_bubble() -> void:
	if line.is_empty(): return
	var body := Rect2(Vector2(TAIL, 0), _body)
	var tail := PackedVector2Array([Vector2(TAIL + 1.0, _tail_tip.y - 6.0), Vector2(TAIL + 1.0, _tail_tip.y + 6.0), _tail_tip])
	var shade := Color(0, 0, 0, 0.55)
	var offset := Vector2(SHADOW, SHADOW)
	_bubble.draw_rect(Rect2(body.position + offset, body.size), shade)
	var shadow_tail := PackedVector2Array()
	for point: Vector2 in tail: shadow_tail.append(point + offset)
	_bubble.draw_colored_polygon(shadow_tail, shade)
	_bubble.draw_rect(body, BUBBLE)
	_bubble.draw_colored_polygon(tail, BUBBLE)
	_bubble.draw_multiline_string(TerminalFont, Vector2(TAIL + PAD.x, PAD.y + TerminalFont.get_ascent(FONT_SIZE)), line, HORIZONTAL_ALIGNMENT_LEFT, _text_width, FONT_SIZE, -1, INK)
