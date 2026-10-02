extends SceneTree
## Cat portraits: every character has one; Slouch, the Review seat and the ticker
## show them, and they blink, idle, talk, and react to hover and pokes.
const Portraits = preload("res://native/portraits.gd")
const CatPortrait = preload("res://native/cat_portrait.gd")
const Interface = preload("res://native/interface.gd")
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Banter = preload("res://content/banter.gd")
const ReviewBanter = preload("res://native/review_banter.gd")
const CAST: Array[String] = ["Maya", "Theo", "Inez", "Morgan", "Helios"]
const STEP := 1.0 / 60.0
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 900)
	_test_lookup()
	_test_frames()
	_test_blinks()
	_test_idles()
	_test_talking()
	_test_hover_and_poke()
	_test_pause_and_motion()
	await _test_pointer()
	await _test_interface()
	print("Cat portraits: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

## A portrait whose clock the test drives by hand.
func _cat(person: String, side: int = 56) -> CatPortrait:
	var cat: CatPortrait = Portraits.make(person, side)
	root.add_child(cat)
	cat.set_process(false)
	return cat

func _run_for(cat: CatPortrait, seconds: float) -> void:
	for tick in range(roundi(seconds / STEP)): cat._process(STEP)

func _shows(cat: CatPortrait, frame: String) -> bool:
	return Portraits.FRAMES[cat.person][frame] in cat.layers()

## When each kind of frame first shows, over a stretch of driven time.
func _timeline(cat: CatPortrait, seconds: float) -> Dictionary:
	var starts: Dictionary = {}
	var previous: Array = []
	for tick in range(roundi(seconds / STEP)):
		cat._process(STEP)
		var now: Array = cat.layers().duplicate()
		for layer: Texture2D in now:
			if layer in previous: continue
			var name: String = Portraits.FRAMES[cat.person].find_key(layer)
			if not starts.has(name): starts[name] = []
			starts[name].append(cat._clock)
		previous = now
	return starts

func _test_frames() -> void:
	for person: String in CAST:
		var id := Portraits.id_for(person)
		var frames: Dictionary = Portraits.FRAMES.get(id, {})
		for frame: String in ["blink", "talk", "hover", "click"]:
			check(frames.has(frame), "%s has a %s frame" % [person, frame])
		var idles: Array = Portraits.IDLES.get(id, [])
		check(not idles.is_empty(), "%s has an idle routine" % person)
		var own_idle_frames := 0
		for routine: Array in idles:
			var seconds := 0.0
			for step: Array in routine:
				var frame := str(step[0])
				check(frame.is_empty() or frames.has(frame), "%s's idles use frames that exist (%s)" % [person, frame])
				if frame not in ["", "blink", "talk", "hover", "click"]: own_idle_frames += 1
				seconds += float(step[1])
			check(seconds > 0.2 and seconds < 2.5, "%s's idles are brief gestures" % person)
		check(own_idle_frames > 0, "%s has idle frames of their own" % person)
		for frame: String in frames:
			var texture: Texture2D = frames[frame]
			var path := "res://art/cats/%s-%s.svg" % [id, frame]
			check(texture.resource_path == path and texture.get_size() == Vector2(32, 32), "%s is a 32×32 frame" % path)
			check(FileAccess.file_exists(path + ".import"), "%s has committed import settings" % path)
			var svg := FileAccess.get_file_as_string(path)
			check(svg.contains("viewBox=\"0 0 32 32\"") and svg.contains("shape-rendering=\"crispEdges\""), "%s uses the 32×32 crisp pixel grid" % path)
			# Overlays are hard-edged pixels over a clear sheet.
			var image := texture.get_image()
			check(image != null, "%s rasterizes" % path)
			if image == null: continue
			image.convert(Image.FORMAT_RGBA8)
			var opaque := 0
			var soft := 0
			for y in range(32):
				for x in range(32):
					var alpha := image.get_pixel(x, y).a8
					if alpha == 255: opaque += 1
					elif alpha != 0: soft += 1
			check(opaque > 0 and opaque < 32 * 32 / 2 and soft == 0, "%s is a crisp overlay that changes some pixels (%d opaque, %d soft)" % [path, opaque, soft])

func _test_blinks() -> void:
	for person: String in CAST:
		var a := _cat(person)
		var b := _cat(person)
		var blinks_a: Array = _timeline(a, 30.0).get("blink", [])
		var blinks_b: Array = _timeline(b, 30.0).get("blink", [])
		check(blinks_a.size() >= 5, "%s blinks every few seconds (%d in 30s)" % [person, blinks_a.size()])
		check(blinks_a == blinks_b, "%s blinks on the same deterministic schedule every time" % person)
		check(not blinks_a.is_empty() and blinks_a[0] >= CatPortrait.BLINK_GAP.x, "%s's first blink waits a moment" % person)
		var longest := 0.0
		for index in range(1, blinks_a.size()): longest = maxf(longest, blinks_a[index] - blinks_a[index - 1])
		check(longest <= CatPortrait.BLINK_GAP.y * 2.0 + 2.5, "%s never stares for long" % person)
		a.free()
		b.free()
	var maya := _cat("Maya")
	var theo := _cat("Theo")
	check(_timeline(maya, 20.0).get("blink", []) != _timeline(theo, 20.0).get("blink", []), "Each cat blinks to its own rhythm")
	maya.free()
	theo.free()

func _test_idles() -> void:
	for person: String in CAST:
		var cat := _cat(person)
		var id := cat.person
		var starts := _timeline(cat, 60.0)
		var first := INF
		for routine: Array in Portraits.IDLES[id]:
			for step: Array in routine:
				var frame := str(step[0])
				if frame.is_empty() or frame == "blink": continue
				check(starts.has(frame), "%s plays the %s idle within a minute" % [person, frame])
				if starts.has(frame): first = minf(first, starts[frame][0])
		check(first >= CatPortrait.IDLE_GAP.x and first <= CatPortrait.IDLE_GAP.y + 0.1, "%s's first idle comes after 6-10 seconds (%.1f)" % [person, first])
		cat.free()

func _test_talking() -> void:
	var cat := _cat("Maya")
	check(cat.layers().is_empty(), "A fresh portrait shows the plain face")
	cat.set_talking(true)
	check(cat.talking and _shows(cat, "talk"), "Talking opens the mouth right away")
	var flaps := 0
	var was_open := true
	for tick in range(roundi(2.0 / STEP)):
		cat._process(STEP)
		var open := _shows(cat, "talk")
		if open != was_open: flaps += 1
		was_open = open
	check(flaps >= 8, "The mouth flaps open and shut while talking (%d changes in 2s)" % flaps)
	cat.set_talking(false)
	check(not _shows(cat, "talk"), "The mouth shuts when the line ends")
	_run_for(cat, 1.0)
	check(not _shows(cat, "talk"), "A quiet cat keeps its mouth shut")
	cat.free()

func _test_hover_and_poke() -> void:
	var cat := _cat("Theo")
	check(cat.mouse_filter == Control.MOUSE_FILTER_PASS, "Portraits notice the mouse without swallowing clicks")
	check(cat.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Portraits show a pointing hand")
	var hovers: Array = []
	var clicks: Array = []
	cat.hover_changed.connect(func(on: bool) -> void: hovers.append(on))
	cat.clicked.connect(func() -> void: clicks.append(true))
	cat.mouse_entered.emit()
	check(hovers == [true] and cat.hovered and _shows(cat, "hover"), "Hovering perks the cat up and says so")
	check(cat.lift() == 1, "Hovering starts with a one-pixel bounce")
	_run_for(cat, 0.2)
	check(cat.lift() == 0 and _shows(cat, "hover"), "The bounce settles while the cat stays perked")
	_run_for(cat, 15.0)
	check(cat.layers().size() <= 2 and _shows(cat, "hover"), "No idle routine starts while hovered")
	cat.mouse_exited.emit()
	check(hovers == [true, false] and not cat.hovered and not _shows(cat, "hover"), "Leaving the cat relaxes it")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	cat._gui_input(press)
	check(clicks.size() == 1 and cat.layers() == [Portraits.FRAMES.theo.click], "A click shows the startled face and emits clicked")
	var hop: Array = []
	for tick in range(roundi(0.3 / STEP)):
		hop.append(cat.lift())
		cat._process(STEP)
	check(hop.max() == 2 and hop[0] >= 1 and hop[-1] == 0, "A click makes a quick, stepped hop: %s" % [hop])
	check(_shows(cat, "click"), "The reaction holds past the hop")
	_run_for(cat, CatPortrait.REACT_SECONDS)
	check(not _shows(cat, "click") and cat.lift() == 0, "The reaction ends after about 0.6s")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	cat._gui_input(release)
	check(clicks.size() == 1, "Only the press counts as a poke")
	cat.free()

func _test_pause_and_motion() -> void:
	var cat := _cat("Morgan")
	var owner := Node.new()
	Portraits.set_paused(true, owner)
	_run_for(cat, 12.0)
	check(cat._clock == 0.0 and cat.layers().is_empty(), "No animation advances while paused")
	cat.set_talking(true)
	var frozen: Array = cat.layers().duplicate()
	_run_for(cat, 2.0)
	check(cat.layers() == frozen, "A paused cat holds its frame mid-sentence")
	Portraits.set_paused(false)
	_run_for(cat, 0.5)
	check(cat._clock > 0.4, "Resuming lets the clock run again")
	Portraits.set_paused(true, owner)
	owner.free()
	check(not CatPortrait.is_paused(), "A pause ends once whatever paused the game is gone")
	cat.set_talking(false)
	Portraits.set_motion(false)
	var still := true
	cat.set_talking(true)
	for tick in range(roundi(20.0 / STEP)):
		cat._process(STEP)
		if not cat.layers().is_empty() or cat.lift() != 0: still = false
	check(still, "With motion off the cat holds still: no blinks, idles or mouth flaps")
	cat.mouse_entered.emit()
	check(_shows(cat, "hover") and cat.lift() == 0, "With motion off, hover still changes the face but does not bounce")
	cat.poke()
	_run_for(cat, 0.1)
	check(_shows(cat, "click") and cat.lift() == 0, "With motion off, a poke reacts without hopping")
	Portraits.set_motion(true)
	cat.free()

func _test_pointer() -> void:
	# Through the real GUI: the poke reaches the cat and still reaches what it sits on.
	var card := Panel.new()
	card.size = Vector2(120, 60)
	card.position = Vector2(40, 40)
	root.add_child(card)
	var cat: CatPortrait = Portraits.make("Inez", 32)
	card.add_child(cat)
	cat.position = Vector2(10, 10)
	cat.size = Vector2(32, 32)
	var card_clicks: Array = []
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed: card_clicks.append(event))
	var pokes: Array = []
	cat.clicked.connect(func() -> void: pokes.append(true))
	await process_frame
	var centre := cat.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = centre
	move.global_position = centre
	root.push_input(move, true)
	await process_frame
	check(cat.hovered, "Moving the mouse onto a portrait hovers it")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = centre
	press.global_position = centre
	press.button_mask = MOUSE_BUTTON_MASK_LEFT
	root.push_input(press, true)
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	release.button_mask = 0
	root.push_input(release, true)
	await process_frame
	check(pokes.size() == 1 and _shows(cat, "click"), "Clicking a portrait pokes the cat")
	check(card_clicks.size() == 1, "The card under the portrait still gets the click")
	var away := InputEventMouseMotion.new()
	away.position = Vector2(400, 400)
	away.global_position = away.position
	root.push_input(away, true)
	await process_frame
	check(not cat.hovered, "Moving away un-hovers it")
	card.free()

func _test_lookup() -> void:
	for person: String in ["Maya", "Theo", "Inez", "Morgan", "Helios"]:
		var texture := Portraits.texture_for(person)
		check(texture != null and texture.get_size() == Vector2(32, 32), "%s has a 32×32 portrait" % person)
		check(Portraits.texture_for(person.to_upper()) == texture and Portraits.texture_for(person.to_lower()) == texture, "%s's portrait lookup ignores case" % person)
	var morgan := Portraits.texture_for("Morgan")
	check(Portraits.texture_for("manager") == morgan and Portraits.texture_for("Morgan / Engineering Manager") == morgan, "The manager contact and its intro signature use Morgan's portrait")
	var seen: Dictionary = {}
	for person: String in ["Maya", "Theo", "Inez", "Morgan", "Helios"]: seen[Portraits.texture_for(person)] = true
	check(seen.size() == 5, "Each character has a distinct portrait")
	for nobody: String in ["You", "Operations", "company", "#engineering", ""]:
		check(Portraits.texture_for(nobody) == null, "'%s' has no portrait" % nobody)
	var face := Portraits.make("theo", 48)
	check(face is TextureRect and face.texture == Portraits.texture_for("Theo"), "make() builds a TextureRect for a known character")
	check(face.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and face.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "Portraits stay crisp and square")
	check(face.custom_minimum_size == Vector2(48, 48), "make() honours the requested size")
	face.free()
	var blank := Portraits.make("You", 48)
	check(not blank is TextureRect and blank.get_child_count() == 0, "make() returns an empty Control for the player")
	blank.free()

func _faces(node: Node) -> Array:
	# Only cat portraits; scroll containers keep texture rects of their own.
	return node.find_children("*", "TextureRect", true, false).filter(func(rect: TextureRect) -> bool: return rect.texture in Portraits.TEXTURES.values())

func _test_interface() -> void:
	root.size = Vector2i(1280, 900)
	var ui: Interface = Interface.new()
	root.add_child(ui)
	var state: Dictionary = Simulation.advance(Simulation.initial_state(), 20)
	# A historical reply puts one of the player's own lines in Maya's thread.
	state = Simulation.dispatch(state, {"type": "chat-reply", "contact": "Maya", "pr_id": str(Catalog.request_at(0).id), "reply_id": "clarify"})
	ui.render_state(state)
	ui._open_app("chat")
	ui._select_chat_contact("Maya")
	for frame in range(3): await process_frame
	var incoming := 0
	var outgoing := 0
	for row: Node in ui._chat_messages.get_children():
		var panels: Array = row.find_children("*", "PanelContainer", false, false)
		if panels.is_empty() or not panels[0].has_meta("outgoing"): continue
		var faces := _faces(row)
		if panels[0].get_meta("outgoing"):
			outgoing += 1
			check(faces.is_empty(), "The player's own Slouch messages carry no avatar")
		else:
			incoming += 1
			check(faces.size() == 1 and faces[0].texture == Portraits.texture_for("Maya"), "A Slouch message from Maya renders her avatar")
			check(faces[0].get_global_rect().end.x <= panels[0].get_global_rect().position.x, "The avatar sits left of the message bubble")
			check(faces[0] is CatPortrait and faces[0].mouse_filter == Control.MOUSE_FILTER_PASS, "Slouch avatars are live cats that leave clicks to the message")
	check(incoming > 0 and outgoing > 0, "Maya's thread has messages from both sides")
	for contact: String in ["Maya", "Theo", "Inez", "manager"]:
		check(ui._chat_contacts[contact].icon == Portraits.texture_for(contact), "The %s DM button shows their portrait" % contact)
	check(ui._chat_contacts.company.icon == null, "The #engineering channel has no portrait")
	var request: Dictionary = Catalog.request_at(0)
	ui._open_pr_link(str(request.id))
	state = Simulation.dispatch(state, {"type": "select-request", "pr_id": str(request.id)})
	ui.render_state(state)
	var seat := _faces(ui._banter._seat)
	check(seat.size() == 1 and seat[0].texture == Portraits.texture_for(str(request.author)), "The author seated beside the PR form is their cat")
	var face: CatPortrait = seat[0]
	var author := str(request.author)
	check(ui._banter.is_speaking() and face.talking, "The seated author's mouth moves while their bubble shows")
	check(face.mouse_filter != Control.MOUSE_FILTER_IGNORE and face.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "The seated author can be poked")
	ui._process(ReviewBanter.LINE_SECONDS + 0.01)
	check(not ui._banter.is_speaking() and not face.talking, "The mouth stops when the bubble goes")
	face.poke()
	check(ui._banter.kind == "poke" and ui._banter.speaker == author and ui._banter.line in Banter.lines(author, "poke"), "Poking the seated author gets a line from them")
	check(face.talking and _shows(face, "click"), "The poked author reacts, then talks")
	var first_poke: String = ui._banter.line
	face.poke()
	check(ui._banter.kind == "poke" and ui._banter.line != first_poke, "Poking again gets a different line")
	ui.set_paused(true)
	check(CatPortrait.is_paused(), "Pausing the shift pauses the portraits")
	ui.set_paused(false)
	check(not CatPortrait.is_paused(), "Resuming the shift resumes them")
	check(_faces(ui._paper).is_empty(), "The form itself does not repeat the author's portrait")
	ui._notifications.push("chat", "Maya: one more thing", "Maya", false, "Maya")
	var card: Control = ui._notifications._items[-1].card
	check(str(card.get_meta("person", "")) == "maya" and _faces(card).size() == 1, "A Slouch ticker card from Maya carries her face")
	check(_faces(card)[0].mouse_filter == Control.MOUSE_FILTER_PASS, "A face on a ticker card leaves the click to the card")
	ui._notifications.push("chat", "#engineering: notice", "company", false, "Operations")
	check(_faces(ui._notifications._items[-1].card).is_empty(), "Faceless senders keep the plain ticker card")
	for frame in range(8): await process_frame
	var stack: Control = ui._notifications._stack
	check(stack.position.y >= ui._monitor_screen.size.y - 48, "Ticker cards with a face still ride in the taskbar")
	ui.set_paused(true)
	ui.free()
	check(not CatPortrait.is_paused(), "A freed interface leaves no pause behind")
