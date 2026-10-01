extends SceneTree
const Sim = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Policy = preload("res://content/policy_campaign.gd")
const Chat = preload("res://content/chat.gd")
const Press = preload("res://content/daily_press.gd")
const Store = preload("res://native/save_store.gd")
const Tutorial = preload("res://native/tutorial.gd")
const Interface = preload("res://native/interface.gd")
var checks := 0
var failures := 0
var state: Dictionary
var ui: Interface
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func command(event: Dictionary) -> void:
	state = Sim.dispatch(state, event)
	ui.render_state(state)
func run() -> void:
	check(Catalog.campaign_days() == [1, 2, 3, 4, 5], "Campaign is exactly Monday through Friday.")
	state = Sim.initial_state()
	check(Sim.available_requests(state).size() == 1, "First request is available immediately.")
	check(Sim.available_requests(Sim.advance(state, 19)).size() == 1, "No early second arrival.")
	check(Sim.available_requests(Sim.advance(state, 20)).size() == 2, "Second request arrives after 20 seconds.")
	check(Sim.available_requests(Sim.advance(state, 280)).size() == 15, "Full shift has 15 deliveries.")
	check(Sim.advance(state, 299).phase == "review" and Sim.advance(state, 300).phase == "debrief", "Five-minute deadline is exact.")
	root.size = Vector2i(1280, 900)
	ui = Interface.new()
	ui.command_requested.connect(command)
	root.add_child(ui)
	ui.render_state(state)
	for frame in range(4): await process_frame
	ui._open_next_pr()
	check(state.active_request_id == "PR-1042", "Next PR opens first arrived packet.")
	check(ui._diff.text == Catalog.request_at(0).files[0].source and ui._diff.gutters_draw_line_numbers, "Source and source line numbers are the actual audit evidence.")
	check(not ui._consult.visible, "Helios is hidden before Wednesday.")
	check(Sim.dispatch(state, {"type": "consult-ai"}) == state, "Hidden consultation cannot be invoked early.")
	state = Sim.advance(state, 20)
	ui.render_state(state)
	check(state.active_request_id == "PR-1042" and ui._arrival_ids.size() == 2, "Arrivals update queue without stealing the open file.")
	ui._open_next_pr()
	check(state.active_request_id == Catalog.requests_for_day(1)[1].id, "Next PR can switch to another pending item.")
	for frame in range(4): await process_frame
	check(ui._windows.review.body.get_combined_minimum_size().x < ui._windows.review.size.x - 20, "Long request titles cannot push decision controls outside the window.")
	var highlighter := Interface.PolicyHighlighter.new()
	highlighter.configure("def test():\n    return 'if' # else", "pink")
	var colors: Dictionary = highlighter._get_line_syntax_highlighting(1)
	check(colors.has(4) and colors.has(10) and colors.size() == 3, "Only real keyword tokens receive ink, not strings or comments.")
	# Exercise every real packet through the simulation, daily press, chat, and UI.
	state = Sim.initial_state()
	for day in range(1, 6):
		check(Catalog.rules_for_day(day).size() == [3,5,7,8,9][day-1], "Rulebook escalates each day.")
		check(Press.stories(day).size() == 3 and not Press.memo(day).body.is_empty(), "Every day has news and a morning memo.")
		for packet: Dictionary in Catalog.requests_for_day(day):
			state = Sim.advance(state, int(packet.arrival_seconds) - int(state.shift_seconds))
			state = Sim.dispatch(state, {"type":"select-request", "request_id":packet.id})
			ui.render_state(state)
			check(ui._consult.visible == (day >= 3), "Consultation unlocks on Wednesday.")
			check(not Sim.active_request(state).has("violations"), "Audit answers are hidden from review view.")
			for index in range(packet.files.size()):
				ui._select_file(index)
				check(ui._diff.text == packet.files[index].source, "Every file renders its exact source evidence.")
				if day >= 4: check(ui._code_legend.text.contains(str(packet.files[index].get("permit", "none"))), "Permit is visible per file.")
			if day >= 3 and int(packet.arrival_seconds) == 0:
				state = Sim.dispatch(state, {"type":"consult-ai"})
				check(state.consulted, "Helios can advise after unlocking.")
			for rule: String in Policy.evaluate(packet.files, day):
				state = Sim.dispatch(state, Sim.Catalog.audit_citation(packet, rule))
			state = Sim.dispatch(state, {"type":"review", "verdict":"approve" if packet.violations.is_empty() else "request_changes"})
			check(state.last_feedback.correct, "Visible evidence leads to a correct decision.")
			check(Sim.validate_save(state).ok, "Every packet's action history survives save replay.")
		state = Sim.advance(state, 300)
		check(state.phase == "debrief", "Each day ends with the manager.")
		check(not Chat.messages(state, "manager").is_empty(), "Manager delivers end-of-day messages.")
		state = Sim.dispatch(state, {"type":"next-day", "choice":"rest"})
	check(state.phase == "complete" and state.day == 5 and state.decisions.size() == 75, "Friday ends the campaign after 75 possible decisions.")
	check(Sim.dispatch(state, {"type":"next-day", "choice":"rest"}) == state, "No sixth day can be started.")
	var finished := state.duplicate(true)
	var careless := Sim.initial_state()
	for packet: Dictionary in Catalog.requests_for_day(1):
		careless = Sim.advance(careless, int(packet.arrival_seconds) - int(careless.shift_seconds))
		careless = Sim.dispatch(careless, {"type":"select-request", "request_id":packet.id})
		careless = Sim.dispatch(careless, {"type":"review", "verdict":"approve"})
	careless = Sim.advance(careless,300)
	var message_ids: Array = []
	for message: Dictionary in Chat.messages(careless,"manager"):
		check(message.id not in message_ids, "Manager warnings have unique notification identities.")
		message_ids.append(message.id)
	check(message_ids.size() <= 4, "Many mistakes produce a concise manager DM instead of repeated boilerplate.")
	var current := Sim.advance(Sim.initial_state(), 150)
	check(Sim.clock_minutes(current) == 810, "All saves use the five-minute clock.")
	var unsupported := current.duplicate(true)
	unsupported.version = 4
	check(not Sim.validate_save(unsupported).ok, "Unsupported saves cannot switch game rules.")
	Store.storage_root = "user://policy-slots-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(Store.storage_root)
	check(Store.save_game(current, {}, 1).ok, "Current campaign saves into slot 1.")
	check(Store.save_game(finished, {}, 2).ok, "Completed policy campaign can be saved.")
	check(Store.save_game(Tutorial.initial_practice_state(), Tutorial.initial_progress(), 3).ok, "New orientation saves independently.")
	var slots := Store.list_slots()
	check(slots[0].summary == "Day 1 · 13:30", "Slot summary has no campaign variant label.")
	for slot in range(1,4): check(Store.load_game(slot).ok, "All three current-format slots load.")
	for name in DirAccess.get_files_at(Store.storage_root): DirAccess.remove_absolute(Store.storage_root.path_join(name))
	DirAccess.remove_absolute(Store.storage_root)
	ui.free()
	print("Policy integration: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
