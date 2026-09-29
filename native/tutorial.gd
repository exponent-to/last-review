extends RefCounted
## Untimed practice uses the real reducer, then discards its consequences.
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")

static func initial_progress() -> Dictionary:
	return {"version": 1, "stage": 0, "inspected_files": []}

static func initial_practice_state() -> Dictionary:
	return Simulation.advance(Simulation.initial_state(), 20)

static func observe(progress: Dictionary, event: Dictionary, state: Dictionary) -> Dictionary:
	var next := progress.duplicate(true)
	var stage := int(next.stage)
	var kind: String = str(event.get("type", ""))
	var packet: Dictionary = Catalog.request_at(0)
	match stage:
		0:
			if kind == "welcome-start": next.stage = 1
		1:
			if kind == "open-chat": next.stage = 2
		2:
			for reply: Dictionary in state.chat_replies:
				if kind == "chat-question" and reply.pr_id == packet.id and reply.reply_id == "clarify": next.stage = 3
		3:
			if kind == "open-review" and state.active_request_id == packet.id: next.stage = 4
		4:
			if kind == "inspect-file" and state.active_request_id == packet.id:
				for file: Dictionary in packet.files:
					if event.get("path") == file.path and file.path not in next.inspected_files:
						next.inspected_files.append(file.path)
				if next.inspected_files.size() == packet.files.size(): next.stage = 5
		5:
			if kind == "open-handbook": next.stage = 6
		6:
			if kind == "correct-submit" and not state.decisions.is_empty() and state.decisions[-1].pr_id == packet.id and state.decisions[-1].correct:
				next.stage = 7
	# A curious player may ask before the lesson reaches this step. Replies are
	# one-shot, so recognize the recorded answer instead of requiring it twice.
	if int(next.stage) == 2:
		for reply: Dictionary in state.chat_replies:
			if reply.pr_id == packet.id and reply.reply_id == "clarify": next.stage = 3
	return next

static func retry_practice_state(state: Dictionary) -> Dictionary:
	var next := initial_practice_state()
	for reply: Dictionary in state.chat_replies:
		next = Simulation.dispatch(next, {"type": "chat-reply", "contact": reply.contact, "pr_id": reply.pr_id, "reply_id": reply.reply_id})
	next = Simulation.dispatch(next, {"type": "select-request", "pr_id": str(Catalog.request_at(0).id)})
	if state.consulted_requests.has(Catalog.request_at(0).id):
		next = Simulation.dispatch(next, {"type": "consult-ai"})
	return next

static func prompt(progress: Dictionary) -> Dictionary:
	var steps := [
		["ORIENTATION DAY", "Welcome. This is a practice workstation: the clock is stopped, and mistakes here will not affect your career. You can move and resize these windows. Start when you're ready."],
		["MEET YOUR TEAM", "Open SLOUCH from the desktop. Maya has sent a practice PR. Messages are where new work and coworker conversations arrive."],
		["ASK A QUESTION", "Select Maya's conversation. Under ASK ABOUT, choose the question about the HTTP deadline. Her answer is a clue—check it against the code."],
		["FOLLOW THE LINK", "In Maya's conversation, click OPEN PR-1042. Scroll up in the messages if the link is above the answer."],
		["READ BOTH FILES", "Use the file selector above the code to read status.py and transport.py. The caller passes a deadline; the helper decides what reaches the HTTP call."],
		["CONSULT THE HANDBOOK", "Open HANDBOOK. It contains the standards you must apply to the whole PR. Your first real shift starts with just a few rules."],
		["REQUEST A CHANGE", "Find R01: Set outbound timeouts. The helper drops the deadline, leaving the HTTP call without a timeout. Tick R01, return to REVIEW, and choose REQUEST CHANGES."],
		["READY FOR MONDAY", "Maya has your note. In the real job, there is no instant grade: your manager will message you when bugs or delays surface. Each day lasts six minutes; PAUSE or Esc stops the clock. At closing, open Morgan's DM and choose how to spend your evening. Practice has no effect on your real run."]
	]
	var entry: Array = steps[int(progress.stage)]
	return {"title": entry[0], "body": entry[1]}

static func validate(value: Variant, state: Dictionary) -> Dictionary:
	var invalid := {"ok": false, "progress": {}, "error": "Invalid orientation progress."}
	if not value is Dictionary or value.size() != 3 or value.get("version") != 1 or not Simulation._integer(value.get("stage"), 0, 7) or not value.get("inspected_files") is Array:
		return invalid
	if int(state.day) != 1 or int(state.shift_seconds) != 20 or state.phase != "review" or not state.shift_history.is_empty(): return invalid
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
	var asked := false
	for reply: Dictionary in state.chat_replies:
		if reply.pr_id != packet.id: return invalid
		if reply.reply_id == "clarify": asked = true
	if stage >= 3 and not asked: return invalid
	if stage < 7 and not state.decisions.is_empty(): return invalid
	if stage == 7 and (state.decisions.size() != 1 or not state.decisions[0].correct or state.decisions[0].pr_id != packet.id): return invalid
	return {"ok": true, "progress": {"version": 1, "stage": stage, "inspected_files": seen}, "error": ""}
