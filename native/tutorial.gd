extends RefCounted
## Untimed practice uses the real reducer, then discards its consequences.
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")

static func initial_progress() -> Dictionary:
	return {"version": 2, "stage": 0, "inspected_files": []}

static func initial_practice_state() -> Dictionary:
	return Simulation.initial_state()

static func observe(progress: Dictionary, event: Dictionary, state: Dictionary) -> Dictionary:
	var next := progress.duplicate(true)
	var stage := int(next.stage)
	var kind: String = str(event.get("type", ""))
	var packet: Dictionary = Catalog.request_at(0)
	match stage:
		0:
			if kind == "welcome-start": next.stage = 1
		1:
			if kind == "open-chat": next.stage = 3
		3:
			if kind == "open-review" and state.active_request_id == packet.id: next.stage = 4
		4:
			if kind == "inspect-file" and state.active_request_id == packet.id:
				for file: Dictionary in packet.files:
					if event.get("path") == file.path and file.path not in next.inspected_files:
						next.inspected_files.append(file.path)
				if next.inspected_files.size() == packet.files.size(): next.stage = 5
		5:
			if kind == "open-standards": next.stage = 6
		6:
			if kind == "correct-submit" and not state.decisions.is_empty() and state.decisions[-1].pr_id == packet.id and state.decisions[-1].correct:
				next.stage = 7
	return next

static func retry_practice_state(state: Dictionary) -> Dictionary:
	var next := initial_practice_state()
	for reply: Dictionary in state.chat_replies:
		next = Simulation.dispatch(next, {"type": "chat-reply", "contact": reply.contact, "pr_id": reply.pr_id, "reply_id": reply.reply_id})
	# The practice PR is already back on the desk; restore only optional consultation.
	if state.consulted_requests.has(Catalog.request_at(0).id):
		next = Simulation.dispatch(next, {"type": "consult-ai"})
	return next

static func prompt(progress: Dictionary) -> Dictionary:
	var steps := [
		["ORIENTATION", "You don't need to know how to code. Check the letters, colors, and paperwork. This practice is untimed. Follow the arrows."],
		["OPEN SLOUCH", "Maya's practice PR is already on your desk. Open SLOUCH to read her note about it."],
		["OPEN THE PR", "Select Maya's conversation and click OPEN PR-1042."],
		["OPEN THE PR", "Click OPEN PR-1042 in Maya's message. It opens the PR on your desk in REVIEW."],
		["LOOK AT BOTH FILES", "Use the file dropdown. Read the comments in each file. A comment is any text after #. You are checking appearances, not what the program does."],
		["READ THE STANDARDS", "Two policies apply today. You'll get more each morning. Open INTRANET and choose STANDARDS to read them."],
		["CITE THE PHRASE", "Policy P01 bans load-bearing in comments. In Review, open the file with that comment and click its line. Tick P01 on the citation slip at the right, then stamp CHANGES REQUESTED. The other policy passes."],
		["READY", "That's the job. Your desk holds one PR at a time; stamp it and the next one lands a moment later. Maya will revise what you sent back, and it will come around again behind a couple of other PRs. You aren't expected to clear the line. Pause whenever you need. Start Monday when ready."]
	]
	var entry: Array = steps[int(progress.stage)]
	return {"title": entry[0], "body": entry[1]}

static func validate(value: Variant, state: Dictionary) -> Dictionary:
	var invalid := {"ok": false, "progress": {}, "error": "Invalid orientation progress."}
	if not value is Dictionary or value.size() != 3 or not Simulation._integer(value.get("version"), 2, 2) or not Simulation._integer(value.get("stage"), 0, 7) or not value.get("inspected_files") is Array:
		return invalid
	if int(state.day) != 1 or int(state.shift_seconds) != 0 or state.phase != "review" or not state.shift_history.is_empty(): return invalid
	var packet: Dictionary = Catalog.request_at(0)
	var paths: Array = []
	for file: Dictionary in packet.files: paths.append(file.path)
	var seen: Array = []
	for path: Variant in value.inspected_files:
		if path not in paths or path in seen: return invalid
		seen.append(path)
	var stage := int(value.stage)
	if stage < 4 and not seen.is_empty(): return invalid
	if stage >= 5 and seen.size() != paths.size(): return invalid
	for reply: Dictionary in state.chat_replies:
		if reply.pr_id != packet.id: return invalid
	if stage == 2: return invalid
	if stage < 7 and not state.decisions.is_empty(): return invalid
	if stage == 7 and (state.decisions.size() != 1 or not state.decisions[0].correct or state.decisions[0].pr_id != packet.id): return invalid
	return {"ok": true, "progress": {"version": 2, "stage": stage, "inspected_files": seen}, "error": ""}
