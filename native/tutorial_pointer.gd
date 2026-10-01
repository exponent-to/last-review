extends Control
## Mount as a full-rect child of the clipped monitor screen, alongside its windows.
## Tracks viewport transforms and ancestor clips without taking focus or mouse input.

const INK := Color("e0b44a")
const SHADOW := Color(0, 0, 0, 0.75)
const ARROW_LENGTH := 26.0
var _target_ref: WeakRef
var _visible_rect := Rect2()
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	z_index = 80
	clip_contents = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_target(target: Control) -> void:
	_target_ref = weakref(target) if is_instance_valid(target) else null
	_refresh_target()


func _process(delta: float) -> void:
	_refresh_target()
	if _visible_rect.has_area():
		_time = fposmod(_time + delta, TAU)
		queue_redraw()


func _refresh_target() -> void:
	var next := _visible_target_rect()
	if next != _visible_rect:
		_visible_rect = next
		queue_redraw()


func _visible_target_rect() -> Rect2:
	if not is_inside_tree() or not is_visible_in_tree() or _target_ref == null:
		return Rect2()
	var target := _target_ref.get_ref() as Control
	if not is_instance_valid(target) or not target.is_inside_tree() or not target.is_visible_in_tree():
		return Rect2()
	if target.get_viewport() != get_viewport():
		return Rect2()
	# Bring the target and every clipping ancestor into this overlay's local space.
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var target_transform := to_local * target.get_global_transform_with_canvas()
	var visible_rect := (target_transform * Rect2(Vector2.ZERO, target.size)).intersection(Rect2(Vector2.ZERO, size))
	var ancestor := target.get_parent()
	while ancestor != null and visible_rect.has_area():
		if ancestor is Control and ancestor.clip_contents:
			var clip_transform: Transform2D = to_local * ancestor.get_global_transform_with_canvas()
			visible_rect = visible_rect.intersection(clip_transform * Rect2(Vector2.ZERO, ancestor.size))
		ancestor = ancestor.get_parent()
	return visible_rect if visible_rect.has_area() else Rect2()


func _draw() -> void:
	if not _visible_rect.has_area():
		return
	# Amber corner brackets mark the target without boxing over its own border.
	var outline := _visible_rect.grow(4).intersection(Rect2(Vector2.ZERO, size).grow(-1))
	if not outline.has_area():
		return
	var arm := minf(12.0, minf(outline.size.x, outline.size.y) * 0.4)
	var o := outline
	for bar: Rect2 in [
		Rect2(o.position.x, o.position.y, arm, 3), Rect2(o.position.x, o.position.y, 3, arm),
		Rect2(o.end.x - arm, o.position.y, arm, 3), Rect2(o.end.x - 3, o.position.y, 3, arm),
		Rect2(o.end.x - arm, o.end.y - 3, arm, 3), Rect2(o.end.x - 3, o.end.y - arm, 3, arm),
		Rect2(o.position.x, o.end.y - 3, arm, 3), Rect2(o.position.x, o.end.y - arm, 3, arm)]:
		draw_rect(bar, INK)
	# A chunky pixel arrow that nudges toward the target.
	var arrow := _arrow_points(outline)
	var start: Vector2 = arrow[0]
	var tip: Vector2 = arrow[1]
	var direction := (tip - start).normalized()
	var bob := (sin(_time * 3.0) * 0.5 + 0.5) * 5.0
	tip -= direction * bob
	start -= direction * bob
	var side := Vector2(-direction.y, direction.x)
	var head := tip - direction * 10.0
	var shape := PackedVector2Array([
		tip, head + side * 8.0, head + side * 3.0, start + side * 3.0,
		start - side * 3.0, head - side * 3.0, head - side * 8.0])
	var shadow := PackedVector2Array()
	for point: Vector2 in shape: shadow.append(point + Vector2(2, 2))
	draw_colored_polygon(shadow, SHADOW)
	draw_colored_polygon(shape, INK)


func _arrow_points(rect: Rect2) -> Array[Vector2]:
	var center := rect.get_center()
	var required := ARROW_LENGTH + 6.0
	if rect.position.x >= required:
		return [Vector2(rect.position.x - required, center.y), Vector2(rect.position.x - 4, center.y)]
	if size.x - rect.end.x >= required:
		return [Vector2(rect.end.x + required, center.y), Vector2(rect.end.x + 4, center.y)]
	if rect.position.y >= required:
		return [Vector2(center.x, rect.position.y - required), Vector2(center.x, rect.position.y - 4)]
	if size.y - rect.end.y >= required:
		return [Vector2(center.x, rect.end.y + required), Vector2(center.x, rect.end.y + 4)]
	# Edge-to-edge targets have no outside margin; use a short arrow within the rim.
	var tip := rect.position + Vector2(minf(12, rect.size.x * 0.5), minf(5, rect.size.y * 0.25))
	return [tip + Vector2(0, minf(ARROW_LENGTH, rect.size.y * 0.5)), tip]
