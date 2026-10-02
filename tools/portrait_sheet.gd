extends SceneTree
## Render every cat's animation frames to one PNG for art review, drawn by the
## same portrait control the game uses: base, blink, each idle frame, talk, hover,
## click, and the click hop.
## sh scripts/run.sh --script res://tools/portrait_sheet.gd -- <out.png> [cell px]
const Portraits = preload("res://native/portraits.gd")
const TerminalFont: FontFile = preload("res://art/fonts/IBMPlexMono-Regular.ttf")
const CAST: Array[String] = ["maya", "theo", "inez", "morgan", "helios"]
const GAP := 16
const LABEL := 26


func _initialize() -> void:
	_run.call_deferred()


## [label, overlay frames, hop in art pixels] for each cell in a cat's row.
static func columns(id: String) -> Array:
	var cells: Array = [["base", [], 0], ["blink", ["blink"], 0]]
	var seen: Dictionary = {}
	for routine: Array in Portraits.IDLES[id]:
		for step: Array in routine:
			var frame := str(step[0])
			if frame in ["", "blink"] or seen.has(frame): continue
			seen[frame] = true
			cells.append([frame, [frame], 0])
	cells.append_array([["talk", ["talk"], 0], ["hover", ["hover"], 0], ["click", ["click"], 0], ["click hop", ["click"], 2]])
	return cells


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if not args.is_empty() else "user://portrait-sheet.png"
	var cell := int(args[1]) if args.size() > 1 else 256
	var widest := 0
	for id: String in CAST: widest = maxi(widest, columns(id).size())
	var sheet := SubViewport.new()
	sheet.size = Vector2i(GAP + widest * (cell + GAP), GAP + CAST.size() * (cell + LABEL + GAP))
	sheet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sheet)
	var backdrop := ColorRect.new()
	backdrop.color = Color("18181c")
	backdrop.size = sheet.size
	sheet.add_child(backdrop)
	for row in range(CAST.size()):
		var cells := columns(CAST[row])
		for column in range(cells.size()):
			var at := Vector2(GAP + column * (cell + GAP), GAP + row * (cell + LABEL + GAP))
			var cat: Control = Portraits.make(CAST[row], cell)
			sheet.add_child(cat)
			cat.position = at
			cat.size = Vector2(cell, cell)
			cat.set_process(false)
			cat.pose(cells[column][1], cells[column][2])
			var label := Label.new()
			label.text = (CAST[row].to_upper() + "  " if column == 0 else "") + str(cells[column][0])
			label.add_theme_font_override("font", TerminalFont)
			label.add_theme_font_size_override("font_size", 14)
			label.add_theme_color_override("font_color", Color("e6e2d6") if column == 0 else Color("8c8981"))
			label.position = at + Vector2(0, cell + 3)
			sheet.add_child(label)
	for frame in range(4): await process_frame
	await RenderingServer.frame_post_draw
	sheet.get_texture().get_image().save_png(out)
	print("saved ", out)
	quit()
