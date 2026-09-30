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
	load("res://content/catalog.gd").campaign_version = 4
	var state := Tutorial.initial_practice_state()
	var progress := Tutorial.initial_progress()
	check(Simulation.validate_save(state).ok, "Practice uses a valid canonical simulation state.")
	check(Tutorial.observe(progress, {"type": "correct-submit"}, state) == progress, "Out-of-order events cannot skip training.")
	for event in ["welcome-start", "open-chat"]:
		progress = Tutorial.observe(progress, {"type": event}, state)
	check(Tutorial.observe(progress, {"type": "chat-question"}, state) == progress, "Question must really have been sent.")
	state = Simulation.dispatch(state, {"type": "chat-reply", "contact": "Maya", "pr_id": "PR-1042", "reply_id": "clarify"})
	var early := Tutorial.observe(Tutorial.initial_progress(), {"type": "welcome-start"}, state)
	early = Tutorial.observe(early, {"type": "open-chat"}, state)
	check(early.stage == 3 and Tutorial.validate(early, state).ok, "Asking early does not strand the lesson on an already-used reply.")
	progress = Tutorial.observe(progress, {"type": "chat-question"}, state)
	state = Simulation.dispatch(state, {"type": "select-request", "pr_id": "PR-1042"})
	progress = Tutorial.observe(progress, {"type": "open-review"}, state)
	for file: Dictionary in Tutorial.Catalog.request_at(0).files:
		progress = Tutorial.observe(progress, {"type": "inspect-file", "path": file.path}, state)
	progress = Tutorial.observe(progress, {"type": "open-handbook"}, state)
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
	check(SaveStore.decode_session(JSON.parse_string(Simulation.serialize_save(Simulation.initial_state()))).tutorial.is_empty(), "Existing raw v4 career saves remain loadable.")
	state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	state = Tutorial.retry_practice_state(state)
	check(state.decisions.is_empty() and state.chat_replies.size() == 1, "Retry preserves the question but removes the practice mistake.")
	state = Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": "R01"})
	state = Simulation.dispatch(state, {"type": "review", "verdict": "request_changes"})
	progress = Tutorial.observe(progress, {"type": "correct-submit"}, state)
	check(progress.stage == 7 and Tutorial.validate(progress, state).ok, "Finished practice can be saved before Monday.")
	print("Tutorial: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
