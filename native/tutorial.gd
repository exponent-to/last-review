extends RefCounted
## Untimed practice uses the real reducer, then discards its consequences.
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
## Orientation progress format. Version 3 goes straight to REVIEW (no chat app).
const VERSION := 3
## Orientation stages, in order. Saves store the stage number.
const STAGE_WELCOME := 0
const STAGE_OPEN_REVIEW := 1
const STAGE_INSPECT := 2
const STAGE_STANDARDS := 3
const STAGE_CITE := 4
const STAGE_READY := 5

static func initial_progress() -> Dictionary:
	return {"version": VERSION, "stage": STAGE_WELCOME, "inspected_files": []}

static func initial_practice_state() -> Dictionary:
	return Simulation.initial_state(true)

static func observe(progress: Dictionary, event: Dictionary, state: Dictionary) -> Dictionary:
	var next := progress.duplicate(true)
	var stage := int(next.stage)
	var kind: String = str(event.get("type", ""))
	var packet: Dictionary = Catalog.practice()
	match stage:
		STAGE_WELCOME:
			if kind == "welcome-start": next.stage = STAGE_OPEN_REVIEW
		STAGE_OPEN_REVIEW:
			if kind == "open-review" and state.active_request_id == packet.id: next.stage = STAGE_INSPECT
		STAGE_INSPECT:
			if kind == "inspect-file" and state.active_request_id == packet.id:
				for file: Dictionary in packet.files:
					if event.get("path") == file.path and file.path not in next.inspected_files:
						next.inspected_files.append(file.path)
				if next.inspected_files.size() == packet.files.size(): next.stage = STAGE_STANDARDS
		STAGE_STANDARDS:
			if kind == "open-standards": next.stage = STAGE_CITE
		STAGE_CITE:
			if kind == "correct-submit" and not state.decisions.is_empty() and state.decisions[-1].pr_id == packet.id and state.decisions[-1].correct:
				next.stage = STAGE_READY
	return next

static func retry_practice_state(state: Dictionary) -> Dictionary:
	var next := initial_practice_state()
	for reply: Dictionary in state.chat_replies:
		next = Simulation.dispatch(next, {"type": "chat-reply", "contact": reply.contact, "pr_id": reply.pr_id, "reply_id": reply.reply_id})
	# The practice PR is already back on the desk; restore only optional consultation.
	if state.consulted_requests.has(Catalog.practice().id):
		next = Simulation.dispatch(next, {"type": "consult-ai"})
	return next

static func prompt(progress: Dictionary) -> Dictionary:
	var steps := [
		["ORIENTATION", "Welcome to Paperclip Labs. You won't need to understand code here; you check letters, colors, and paperwork. Orientation is off the clock. HR has put arrows on your screen. Follow them."],
		["OPEN REVIEW", "Maya's practice PR is on your desk. Open REVIEW."],
		["LOOK AT BOTH FILES", "Use the file dropdown. Read the comments in each file. A comment is any text after #. You are checking appearances, not what the program does."],
		["READ THE STANDARDS", "Three policies apply today. They change every second morning. Open INTRANET and choose STANDARDS to read them."],
		["CITE THE PHRASE", "Policy P01 bans load-bearing in comments. In Review, open the file with that comment and click its line. Tick P01 on the citation slip at the right, then stamp CHANGES REQUESTED. The other policies pass."],
		["READY", "That's the job. Your desk holds one PR at a time; the rest wait in line, and the line grows all day. Stamp one and the next steps up a moment later. Maya will revise what you sent back, and it will come around again behind a couple of other PRs. Nobody expects you to clear the line. PAUSE stops the clock whenever you need it. Start Monday when ready."]
	]
	var entry: Array = steps[int(progress.stage)]
	return {"title": entry[0], "body": entry[1]}

static func validate(value: Variant, state: Dictionary) -> Dictionary:
	var invalid := {"ok": false, "progress": {}, "error": "Invalid orientation progress."}
	if not value is Dictionary or value.size() != 3 or not Simulation._integer(value.get("version"), VERSION, VERSION) or not Simulation._integer(value.get("stage"), STAGE_WELCOME, STAGE_READY) or not value.get("inspected_files") is Array:
		return invalid
	if int(state.day) != 1 or int(state.shift_seconds) != 0 or state.phase != "review" or not state.shift_history.is_empty(): return invalid
	# Orientation runs on the practice desk, never on a real Monday.
	if not bool(state.get("practice", false)): return invalid
	var packet: Dictionary = Catalog.practice()
	var paths: Array = []
	for file: Dictionary in packet.files: paths.append(file.path)
	var seen: Array = []
	for path: Variant in value.inspected_files:
		if path not in paths or path in seen: return invalid
		seen.append(path)
	var stage := int(value.stage)
	if stage < STAGE_INSPECT and not seen.is_empty(): return invalid
	if stage > STAGE_INSPECT and seen.size() != paths.size(): return invalid
	for reply: Dictionary in state.chat_replies:
		if reply.pr_id != packet.id: return invalid
	if stage < STAGE_READY and not state.decisions.is_empty(): return invalid
	if stage == STAGE_READY and (state.decisions.size() != 1 or not state.decisions[0].correct or state.decisions[0].pr_id != packet.id): return invalid
	return {"ok": true, "progress": {"version": VERSION, "stage": stage, "inspected_files": seen}, "error": ""}
