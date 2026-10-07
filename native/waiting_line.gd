extends VBoxContainer
## The line outside the booth: who is waiting for the desk, front first, in REVIEW's
## top-right corner beside the seated author. Each waiting PR is its author's face
## and how long they have stood there; the age turns amber, then red. It shows who
## wrote a PR and how long it has waited, never anything about what is in it.
## Nobody can be called up out of turn: the line is first come, first served.

const Portraits = preload("res://native/portraits.gd")
const Catalog = preload("res://content/catalog.gd")
const TerminalFont: FontFile = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
## Faces shown before the rest collapse into "+N".
const SHOWN := 5
const FACE := 26
## Game seconds of waiting (three minutes each) before an age turns amber, then red.
const AMBER_AFTER := 20
const RED_AFTER := 40
const DIM := Color("8c8981")
const TEXT := Color("e6e2d6")
const AMBER := Color("e0b44a")
const RED := Color("e5384a")

var _heading: Label
var _row: HBoxContainer
var _more: Label
## The waiting PRs drawn now, front first, and their age labels.
var _ids: Array = []
var _ages: Array = []


func _init() -> void:
	name = "WaitingLine"
	add_theme_constant_override("separation", 2)
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heading = _label("", 10, DIM)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_heading)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 3)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_more = _label("", 11, DIM)
	_more.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_more.custom_minimum_size = Vector2(0, FACE)
	visible = false


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", TerminalFont)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


## "12m", "1h05": how long someone has waited, on the office clock (3 min a second).
static func age_text(seconds: int) -> String:
	var minutes := maxi(0, seconds) * 3
	return "%dm" % minutes if minutes < 60 else "%dh%02d" % [minutes / 60, minutes % 60]


static func age_color(seconds: int) -> Color:
	return RED if seconds >= RED_AFTER else AMBER if seconds >= AMBER_AFTER else DIM


## `line` is Simulation.waiting(state): {id, author, revision, since, age}, front first.
## `open` is false when the desk is closed (before the shift, in the evening).
func render(line: Array, open: bool) -> void:
	visible = open
	if not open: return
	_heading.text = "IN LINE · %d" % line.size() if not line.is_empty() else "NOBODY WAITING"
	_heading.add_theme_color_override("font_color", age_color(int(line[0].age)) if not line.is_empty() and int(line[0].age) >= AMBER_AFTER else DIM)
	var ids: Array = line.slice(0, SHOWN).map(func(entry: Dictionary) -> String: return str(entry.id))
	if ids != _ids:
		_ids = ids
		_rebuild(line.slice(0, SHOWN))
	for index in range(_ages.size()):
		var entry: Dictionary = line[index]
		var label: Label = _ages[index]
		label.text = age_text(int(entry.age))
		label.add_theme_color_override("font_color", age_color(int(entry.age)))
		var face: Control = label.get_parent().get_child(0)
		face.tooltip_text = "%s · %s · waiting %s" % [Catalog.display_id(str(entry.id)), str(entry.author), age_text(int(entry.age))]
	var hidden := line.size() - mini(line.size(), SHOWN)
	_more.text = "+%d" % hidden
	_more.visible = hidden > 0
	_more.tooltip_text = "%d more waiting behind them" % hidden


func _rebuild(shown: Array) -> void:
	if _more.get_parent() == _row: _row.remove_child(_more)
	for child: Node in _row.get_children():
		_row.remove_child(child)
		child.queue_free()
	_ages = []
	for entry: Dictionary in shown:
		var spot := VBoxContainer.new()
		spot.add_theme_constant_override("separation", 0)
		spot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(spot)
		var face := Portraits.make(str(entry.author), FACE)
		face.custom_minimum_size = Vector2(FACE, FACE)
		# Hover shows who and how long; there is nothing to click. Nobody jumps the line.
		face.mouse_filter = Control.MOUSE_FILTER_PASS
		face.set_meta("pr_id", str(entry.id))
		spot.add_child(face)
		var age := _label("", 10, DIM)
		age.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spot.add_child(age)
		_ages.append(age)
	_row.add_child(_more)

