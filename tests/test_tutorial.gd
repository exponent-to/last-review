extends SceneTree
const Tutorial = preload("res://native/tutorial.gd")
const Simulation = preload("res://native/simulation.gd")
const SaveStore = preload("res://native/save_store.gd")
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var state := Tutorial.initial_practice_state()
	var progress := Tutorial.initial_progress()
	check(Simulation.validate_save(state).ok, "Practice uses a valid canonical simulation state.")
	check(Tutorial.observe(progress, {"type": "correct-submit"}, state) == progress, "Out-of-order events cannot skip training.")
	for event in ["welcome-start", "open-chat"]:
		progress = Tutorial.observe(progress, {"type": event}, state)
	check(progress.stage == 3 and Tutorial.validate(progress, state).ok, "Opening Slouch goes directly to the PR link without a reply.")
	var unsupported := progress.duplicate(true)
	unsupported.version = 1
	check(not Tutorial.validate(unsupported, state).ok, "Only the current orientation format is supported.")
	check(state.active_request_id == "PR-1042", "The practice PR is already on the desk.")
	progress = Tutorial.observe(progress, {"type": "open-review"}, state)
	for file: Dictionary in Tutorial.Catalog.request_at(0).files:
		progress = Tutorial.observe(progress, {"type": "inspect-file", "path": file.path}, state)
	progress = Tutorial.observe(progress, {"type": "open-standards"}, state)
	check(progress.stage == 6, "Real training sequence reaches disposition.")
	var envelope := {"format": "last-review-session", "version": 1, "state": state, "tutorial": progress}
	var loaded := SaveStore.decode_session(JSON.parse_string(JSON.stringify(envelope)))
	check(loaded.ok and loaded.tutorial.stage == 6 and loaded.state == state, "Tutorial session survives a JSON save round trip.")
	var tampered := envelope.duplicate(true)
	tampered.tutorial.stage = 7
	check(not SaveStore.decode_session(tampered).ok, "A completed lesson cannot be invented without a correct practice review.")
	tampered = envelope.duplicate(true)
	tampered.tutorial.inspected_files.append("invented.py")
	check(not SaveStore.decode_session(tampered).ok, "Invalid file-inspection state is rejected.")
	check(SaveStore.decode_session(JSON.parse_string(Simulation.serialize_save(Simulation.initial_state()))).tutorial.is_empty(), "Current career saves remain loadable.")
	state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	state = Tutorial.retry_practice_state(state)
	check(state.decisions.is_empty() and state.chat_replies.is_empty() and state.active_request_id == "PR-1042", "Retry removes the mistake and puts the practice PR back on the desk.")
	state = Simulation.dispatch(state, Simulation.Catalog.audit_citation(Simulation.Catalog.request_at(0), "P01"))
	state = Simulation.dispatch(state, {"type": "review", "verdict": "request_changes"})
	progress = Tutorial.observe(progress, {"type": "correct-submit"}, state)
	check(progress.stage == 7 and Tutorial.validate(progress, state).ok, "Finished practice can be saved before Monday.")
	check(state.desk_line[mini(2, state.desk_line.size() - 1)] == "PR-1042-v2" and int(state.shift_seconds) == 0, "Practice queues Maya's revision, but the stopped clock never delivers it.")
	check(not Tutorial.prompt(progress).body.contains("NEXT PR"), "The handoff explains the one-at-a-time desk, not a picker.")
	print("Tutorial: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
