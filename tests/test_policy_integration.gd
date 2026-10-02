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
## Wait for the next PR to land; false when nothing else is coming today.
func await_desk() -> bool:
	if not Sim.active_request(state).is_empty(): return true
	if int(state.desk_at) < 0 or int(state.desk_at) >= Catalog.shift_seconds(): return false
	state = Sim.advance(state, int(state.desk_at) - int(state.shift_seconds))
	return true
func run() -> void:
	check(Catalog.campaign_days() == [1, 2, 3, 4, 5], "Campaign is exactly Monday through Friday.")
	state = Sim.initial_state()
	check(Sim.available_requests(state).size() == 1 and state.active_request_id == "PR-1042", "The first request is on the desk immediately.")
	for wait in [19, 20, 280]:
		check(Sim.available_requests(Sim.advance(state, wait)).size() == 1, "Waiting never adds a second PR to the desk.")
	check(Sim.advance(state, 299).phase == "review" and Sim.advance(state, 300).phase == "debrief", "Five-minute deadline is exact.")
	root.size = Vector2i(1280, 900)
	ui = Interface.new()
	ui.command_requested.connect(command)
	root.add_child(ui)
	ui.render_state(state)
	for frame in range(4): await process_frame
	ui._open_pr_link("PR-1042")
	check(state.active_request_id == "PR-1042" and ui._windows.review.visible, "The Slouch link opens the PR already on the desk.")
	var live_rows: Array = ui._diff_rows.filter(func(row: Dictionary) -> bool: return row.kind != "-")
	check("\n".join(live_rows.map(func(row: Dictionary) -> String: return row.text)) == Catalog.request_at(0).files[0].source, "The proposed source is the audit evidence.")
	var numbered := true
	for row_index in range(ui._diff_rows.size()):
		var row: Dictionary = ui._diff_rows[row_index]
		numbered = numbered and ui._diff.get_line_gutter_text(row_index, ui._line_gutter) == ("" if row.kind == "-" else str(row.line))
	check(numbered and ui._diff_rows.any(func(row: Dictionary) -> bool: return row.kind == "-"), "The gutter numbers the proposed file, and the tutorial PR shows removed lines.")
	check(not ui._consult.visible, "Helios is hidden before Wednesday.")
	check(Sim.dispatch(state, {"type": "consult-ai"}) == state, "Hidden consultation cannot be invoked early.")
	state = Sim.advance(state, 20)
	ui.render_state(state)
	check(state.active_request_id == "PR-1042" and ui._pr_id.text.begins_with("PR-1042"), "Time passing never swaps the PR on the desk.")
	ui._approve.pressed.emit()
	check(ui._pr_id.text.contains("DESK CLEAR"), "A stamp clears the desk for a beat.")
	state = Sim.advance(state, Sim.DESK_BEAT)
	ui.render_state(state)
	check(state.active_request_id == Catalog.requests_for_day(1)[1].id and ui._pr_id.text.begins_with(state.active_request_id), "The next PR lands on the desk by itself.")
	for frame in range(4): await process_frame
	check(ui._windows.review.body.get_combined_minimum_size().x < ui._windows.review.size.x - 20, "Long request titles cannot push decision controls outside the window.")
	var highlighter := Interface.PolicyHighlighter.new()
	var sample := "def test():\n    return 'if' # else"
	highlighter.configure(Policy.line_diff("", sample), sample, "pink")
	var colors: Dictionary = highlighter._get_line_syntax_highlighting(1)
	check(colors.has(4) and colors.has(10) and colors.size() == 3, "Only real keyword tokens receive ink, not strings or comments.")
	var edited := "def test():\n    pass\n    return 'if'"
	var edit_rows: Array = Policy.line_diff("def test():\n    return 'if'", edited)
	highlighter.configure(edit_rows, edited, "blue")
	var removed_row := edit_rows.map(func(row: Dictionary) -> String: return row.kind).find("-")
	check(removed_row < 0 or highlighter._get_line_syntax_highlighting(removed_row).size() == 1, "Removed lines are dimmed, never inked as live keywords.")
	# Exercise every real packet through the simulation, daily press, chat, and UI.
	state = Sim.initial_state()
	for day in range(1, 6):
		check(Catalog.rules_for_day(day).size() == [3,5,7,8,9][day-1], "Rulebook escalates each day.")
		check(Press.stories(day).size() == 3 and not Press.memo(day).body.is_empty(), "Every day has news and a morning memo.")
		var first_of_day := true
		while await_desk():
			var packet: Dictionary = Catalog.packet(state, state.active_request_id)
			ui.render_state(state)
			check(ui._consult.visible == (day >= 3), "Consultation unlocks on Wednesday.")
			check(not Sim.active_request(state).has("violations"), "Audit answers are hidden from review view.")
			for index in range(packet.files.size()):
				ui._select_file(index)
				check("\n".join(ui._diff_rows.filter(func(row: Dictionary) -> bool: return row.kind != "-").map(func(row: Dictionary) -> String: return row.text)) == packet.files[index].source, "Every file renders its exact proposed source, with removed lines marked.")
				if day >= 4: check(ui._code_legend.text.contains(str(packet.files[index].get("permit", "none"))), "Permit is visible per file.")
			if day >= 3 and (first_of_day or int(packet.revision) > 1):
				state = Sim.dispatch(state, {"type":"consult-ai"})
				check(state.consulted, "Helios can advise after unlocking, revisions included.")
			first_of_day = false
			for rule: String in Policy.evaluate(packet.files, day):
				state = Sim.dispatch(state, Sim.Catalog.audit_citation(packet, rule))
			state = Sim.dispatch(state, {"type":"review", "verdict":"approve" if packet.violations.is_empty() else "request_changes"})
			check(state.last_feedback.correct, "Visible evidence leads to a correct decision.")
			check(Sim.validate_save(state).ok, "Every packet's action history survives save replay.")
		state = Sim.advance(state, 300)
		check(state.phase == "debrief", "Each day ends with the manager.")
		check(not Chat.messages(state, "manager").is_empty(), "Manager delivers end-of-day messages.")
		state = Sim.dispatch(state, {"type":"next-day", "choice":"rest"})
	var originals_signed := 0
	for decision: Dictionary in state.decisions:
		if Catalog.packet(state, decision.pr_id).revision == 1: originals_signed += 1
	check(state.phase == "complete" and state.day == 5 and originals_signed == 75 and state.decisions.size() > 75, "Friday ends the campaign with every PR and its revisions signed.")
	check(Sim.dispatch(state, {"type":"next-day", "choice":"rest"}) == state, "No sixth day can be started.")
	var finished := state.duplicate(true)
	var careless := Sim.initial_state()
	while not Sim.active_request(careless).is_empty():
		careless = Sim.dispatch(careless, {"type":"review", "verdict":"approve"})
		careless = Sim.advance(careless, Sim.DESK_BEAT)
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
