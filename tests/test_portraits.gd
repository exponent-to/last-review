extends SceneTree
## Cat portraits: every character has one; Slouch, the Review seat and the ticker show them.
const Portraits = preload("res://native/portraits.gd")
const Interface = preload("res://native/interface.gd")
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
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
	_test_lookup()
	await _test_interface()
	print("Cat portraits: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

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
	check(_faces(ui._paper).is_empty(), "The form itself does not repeat the author's portrait")
	ui._notifications.push("chat", "Maya: one more thing", "Maya", false, "Maya")
	var card: Control = ui._notifications._items[-1].card
	check(str(card.get_meta("person", "")) == "maya" and _faces(card).size() == 1, "A Slouch ticker card from Maya carries her face")
	ui._notifications.push("chat", "#engineering: notice", "company", false, "Operations")
	check(_faces(ui._notifications._items[-1].card).is_empty(), "Faceless senders keep the plain ticker card")
	for frame in range(8): await process_frame
	var stack: Control = ui._notifications._stack
	check(stack.position.y >= ui._monitor_screen.size.y - 48, "Ticker cards with a face still ride in the taskbar")
	ui.free()
