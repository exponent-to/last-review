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
	progress = Tutorial.observe(progress, {"type": "welcome-start"}, state)
	check(progress.stage == Tutorial.STAGE_OPEN_REVIEW and Tutorial.validate(progress, state).ok, "Orientation starts by opening REVIEW.")
	check(Tutorial.prompt(progress).title == "OPEN REVIEW" and Tutorial.prompt(progress).body == "Maya's practice PR is on your desk. Open REVIEW.", "The first step sends the player straight to REVIEW.")
	check(Tutorial.observe(progress, {"type": "open-chat"}, state) == progress, "There is no chat step to take.")
	var unsupported := progress.duplicate(true)
	unsupported.version = 2
	check(not Tutorial.validate(unsupported, state).ok, "Only the current orientation format is supported; the old Slouch stages are rejected.")
	for stage in [-1, Tutorial.STAGE_READY + 1, 7]:
		unsupported = progress.duplicate(true)
		unsupported.stage = stage
		check(not Tutorial.validate(unsupported, state).ok, "Stage %d is not an orientation stage." % stage)
	check(state.active_request_id == "PR-1042", "The practice PR is already on the desk.")
	progress = Tutorial.observe(progress, {"type": "open-review"}, state)
	check(progress.stage == Tutorial.STAGE_INSPECT, "Opening REVIEW goes straight to the files.")
	var early := progress.duplicate(true)
	early.stage = Tutorial.STAGE_OPEN_REVIEW
	early.inspected_files = [Tutorial.Catalog.request_at(0).files[0].path]
	check(not Tutorial.validate(early, state).ok, "Files cannot be inspected before REVIEW is open.")
	for file: Dictionary in Tutorial.Catalog.request_at(0).files:
		progress = Tutorial.observe(progress, {"type": "inspect-file", "path": file.path}, state)
	check(progress.stage == Tutorial.STAGE_STANDARDS, "Inspecting both files moves on to the standards.")
	progress = Tutorial.observe(progress, {"type": "open-standards"}, state)
	check(progress.stage == Tutorial.STAGE_CITE, "Real training sequence reaches disposition.")
	var envelope := {"format": "last-review-session", "version": 1, "state": state, "tutorial": progress}
	var loaded := SaveStore.decode_session(JSON.parse_string(JSON.stringify(envelope)))
	check(loaded.ok and loaded.tutorial.stage == Tutorial.STAGE_CITE and loaded.state == state, "Tutorial session survives a JSON save round trip.")
	var tampered := envelope.duplicate(true)
	tampered.tutorial.stage = Tutorial.STAGE_READY
	check(not SaveStore.decode_session(tampered).ok, "A completed lesson cannot be invented without a correct practice review.")
	tampered = envelope.duplicate(true)
	tampered.tutorial.inspected_files.append("invented.py")
	check(not SaveStore.decode_session(tampered).ok, "Invalid file-inspection state is rejected.")
	tampered = envelope.duplicate(true)
	tampered.state.version = Simulation.SAVE_VERSION - 1
	check(not SaveStore.decode_session(tampered).ok, "Orientation saves from the Slouch-era format are rejected.")
	check(SaveStore.decode_session(JSON.parse_string(Simulation.serialize_save(Simulation.initial_state()))).tutorial.is_empty(), "Current career saves remain loadable.")
	state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	state = Tutorial.retry_practice_state(state)
	check(state.decisions.is_empty() and state.chat_replies.is_empty() and state.active_request_id == "PR-1042", "Retry removes the mistake and puts the practice PR back on the desk.")
	state = Simulation.dispatch(state, Simulation.Catalog.audit_citation(Simulation.Catalog.request_at(0), "P01"))
	state = Simulation.dispatch(state, {"type": "review", "verdict": "request_changes"})
	progress = Tutorial.observe(progress, {"type": "correct-submit"}, state)
	check(progress.stage == Tutorial.STAGE_READY and Tutorial.validate(progress, state).ok, "Finished practice can be saved before Monday.")
	check(state.desk_line[mini(2, state.desk_line.size() - 1)] == "PR-1042-v2" and int(state.shift_seconds) == 0, "Practice queues Maya's revision, but the stopped clock never delivers it.")
	check(not Tutorial.prompt(progress).body.contains("NEXT PR"), "The handoff explains the one-at-a-time desk, not a picker.")
	for stage in range(Tutorial.STAGE_WELCOME, Tutorial.STAGE_READY + 1):
		var step := Tutorial.prompt({"stage": stage})
		check(not (step.title + step.body).to_lower().contains("slouch") and not step.body.contains("OPEN PR-"), "Orientation step %d never mentions Slouch or a chat link." % stage)
	print("Tutorial: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
