extends RefCounted
## Deterministic timed review rules. Catalog answers are used only to audit submitted decisions.
## One PR sits on the desk at a time. Stamping it brings the next in line a beat later;
## a change request sends it back to its author, whose revision rejoins the line.

const Catalog = preload("res://content/catalog.gd")
const Chat = preload("res://content/chat.gd")
const Policy = preload("res://content/policy_campaign.gd")
const SAVE_VERSION: int = 9
const SHIFT_SECONDS: int = 300
const START_MINUTE: int = 540
const END_MINUTE: int = 1080
const LOG_LIMIT: int = 40
const AUTHORS: Array = ["Maya", "Theo", "Inez"]
const EVENINGS: Array = ["rest", "socialize", "study"]
## Game seconds between a stamp and the next PR landing on the desk.
const DESK_BEAT: int = 3
## A revision rejoins the line behind this many PRs (or sooner if fewer remain).
const REVISION_GAP: int = 2

static func initial_state() -> Dictionary:
	var first_day: int = int(Catalog.campaign_days()[0])
	var state: Dictionary = {
		"version": SAVE_VERSION, "day": first_day, "request_index": 0, "phase": "review",
		"credits": 120, "trust": 70, "stress": 20, "autonomy": 10,
		"coworkers": {"Maya": 50, "Theo": 50, "Inez": 50},
		"selected_rules": [], "citation_evidence": {}, "consulted": false, "decisions": [],
		"shift_seconds": 0, "active_request_id": "", "consulted_requests": [],
		"desk_line": [], "desk_at": -1, "arrivals": [], "revisions": [],
		"actions": [], "shift_history": [], "chat_replies": [],
		"log": [{"day": first_day, "message": "Your review shift begins. Work lands on your desk one PR at a time."}],
		"last_feedback": {}, "last_debrief": {},
	}
	_open_desk(state)
	return state

static func clock_minutes(state: Dictionary) -> int:
	return START_MINUTE + floori(float(state.shift_seconds) * float(END_MINUTE - START_MINUTE) / float(SHIFT_SECONDS))

static func advance(state: Dictionary, seconds: int = 1) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if next.phase != "review" or seconds <= 0:
		return next
	var target: int = mini(Catalog.shift_seconds(), int(next.shift_seconds) + mini(seconds, Catalog.shift_seconds()))
	# The next PR lands at its scheduled second, so batched and stepped clocks agree.
	if int(next.desk_at) >= 0 and int(next.desk_at) < Catalog.shift_seconds() and int(next.desk_at) <= target:
		_deliver(next)
	next.shift_seconds = target
	if next.shift_seconds == Catalog.shift_seconds():
		next.actions.append({"type": "timeout", "day": next.day, "shift_seconds": Catalog.shift_seconds()})
		_debrief(next)
	return next

static func _reviewed(state: Dictionary, request_id: String) -> bool:
	for decision: Dictionary in state.decisions:
		if decision.pr_id == request_id:
			return true
	return false

static func _public_request(request: Dictionary, consulted: bool = false) -> Dictionary:
	var public: Dictionary = request.duplicate(true)
	public.erase("violations")
	public.erase("findings")
	public.erase("explanation")
	public.erase("recipe")
	if not consulted:
		public.erase("ai_verdict")
		public.erase("ai_note")
	return public

## Start a day's line: its authored packets in order, the first already on the desk.
static func _open_desk(state: Dictionary) -> void:
	state.desk_line = []
	for request: Dictionary in Catalog.requests_for_day(int(state.day)):
		state.desk_line.append(request.id)
	state.active_request_id = ""
	state.desk_at = int(state.shift_seconds)
	_deliver(state)

## The next PR in line reaches the desk at `desk_at` and becomes the active review.
static func _deliver(state: Dictionary) -> void:
	if int(state.desk_at) < 0 or state.desk_line.is_empty() or not str(state.active_request_id).is_empty():
		return
	var request_id: String = state.desk_line.pop_front()
	state.active_request_id = request_id
	state.arrivals.append({"pr_id": request_id, "day": state.day, "shift_seconds": state.desk_at})
	state.desk_at = -1
	state.selected_rules = []
	state.citation_evidence = {}
	state.consulted = request_id in state.consulted_requests

## The desk holds at most one PR. Kept as a list for callers that iterate.
static func available_requests(state: Dictionary) -> Array:
	var request: Dictionary = active_request(state)
	return [] if request.is_empty() else [request]

## The PR on the desk, without audit answers; empty between PRs and after closing.
static func active_request(state: Dictionary) -> Dictionary:
	var request: Dictionary = _desk(state)
	return {} if request.is_empty() else _public_request(request, request.id in state.consulted_requests)

## Internal, read-only: the full packet on the desk (audit data included).
static func _desk(state: Dictionary) -> Dictionary:
	if state.phase != "review" or str(state.active_request_id).is_empty() or _reviewed(state, state.active_request_id):
		return {}
	return Catalog.packet(state, state.active_request_id, false)

static func _update_request_index(state: Dictionary) -> void:
	var requests: Array = Catalog.originals()
	state.request_index = requests.size()
	for index in range(requests.size()):
		if int(requests[index].day) < int(state.day):
			continue
		if state.phase != "review" and int(requests[index].day) == int(state.day):
			continue
		if not _reviewed(state, requests[index].id):
			state.request_index = index
			return

static func _record(state: Dictionary, message: String) -> void:
	state.log.append({"day": state.day, "message": message})
	while state.log.size() > LOG_LIMIT:
		state.log.pop_front()

static func _active_rule(rule_id: Variant, day: int) -> bool:
	if typeof(rule_id) != TYPE_STRING:
		return false
	for rule: Dictionary in Catalog.rules_for_day(day):
		if rule.id == rule_id:
			return true
	return false

static func _same_rules(left: Array, right: Array) -> bool:
	var a: Array = left.duplicate()
	var b: Array = right.duplicate()
	a.sort()
	b.sort()
	return a == b

static func dispatch(state: Dictionary, command: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var kind: Variant = command.get("type", "")
	var event: Dictionary = {"type": kind, "day": state.day, "shift_seconds": state.shift_seconds}
	if next.phase == "complete":
		return next
	if kind == "next-day":
		if next.phase == "debrief" and command.get("choice") in EVENINGS:
			event.choice = command.choice
			next.actions.append(event)
			_evening(next, command.choice)
		return next
	if next.phase != "review":
		return next
	if kind == "chat-reply":
		var contact: Variant = command.get("contact")
		if typeof(contact) != TYPE_STRING:
			return next
		for option: Dictionary in Chat.reply_options(next, contact):
			if option.id == command.get("reply_id") and option.pr_id == command.get("pr_id"):
				event.contact = contact
				event.reply_id = option.id
				event.pr_id = option.pr_id
				next.chat_replies.append({"day": next.day, "shift_seconds": next.shift_seconds, "pr_id": option.pr_id, "contact": contact, "reply_id": option.id})
				next.actions.append(event)
				break
		return next
	var active: Dictionary = _desk(next)
	if active.is_empty():
		return next
	match kind:
		"toggle-rule":
			var rule_id: Variant = command.get("rule_id")
			if not _active_rule(rule_id, int(next.day)):
				return next
			if rule_id in next.selected_rules:
				next.selected_rules.erase(rule_id)
				next.citation_evidence.erase(rule_id)
			else:
				# A citation pins a rule to the file and line the reviewer pointed at.
				var location: Variant = _evidence_location(active, command)
				if location == null:
					return next
				next.selected_rules.append(rule_id)
				next.citation_evidence[rule_id] = location
		"consult-ai":
			if int(next.day) < 3: return next
			if not next.consulted:
				next.consulted = true
				next.consulted_requests.append(active.id)
				next.autonomy = clampi(int(next.autonomy) + 4, 0, 100)
				next.stress = clampi(int(next.stress) - 2, 0, 100)
				_record(next, "You asked the assistant to assess this PR. Automation reliance +4; stress -2.")
				event.pr_id = active.id
				next.actions.append(event)
		"review":
			var verdict: Variant = command.get("verdict")
			if verdict not in ["approve", "request_changes"]:
				return next
			if (verdict == "approve" and not next.selected_rules.is_empty()) or (verdict == "request_changes" and next.selected_rules.is_empty()):
				return next
			event.pr_id = active.id
			event.verdict = verdict
			event.cited_rules = next.selected_rules.duplicate()
			event.evidence = next.citation_evidence.duplicate(true)
			next.actions.append(event)
			_review(next, verdict)
	return next

static func _evidence_location(request: Dictionary, command: Dictionary) -> Variant:
	var path: Variant = command.get("path")
	if typeof(path) != TYPE_STRING: return null
	for file: Dictionary in request.get("files", []):
		if file.path == path:
			var count: int = str(file.source).split("\n", true).size()
			if not _integer(command.get("line"), 0, count): return null
			return {"path": path, "line": int(command.line)}
	return null

static func _cite(state: Dictionary, rule_id: String, evidence: Variant) -> Dictionary:
	var location: Dictionary = evidence if typeof(evidence) == TYPE_DICTIONARY else {}
	return dispatch(state, {"type": "toggle-rule", "rule_id": rule_id, "path": location.get("path"), "line": location.get("line")})

static func _review(state: Dictionary, verdict: String) -> void:
	var request: Dictionary = Catalog.packet(state, state.active_request_id, false)
	var expected: Array = request.violations
	var correct: bool = expected.is_empty() if verdict == "approve" else _same_rules(state.selected_rules, expected)
	if verdict == "request_changes" and correct:
		for rule_id: String in state.selected_rules:
			var location: Dictionary = state.citation_evidence.get(rule_id, {})
			if not Policy.evidence_accepted(request.findings, rule_id, str(location.get("path", "")), int(location.get("line", -1))):
				correct = false
	var relationship_change: int = (4 if correct else 6) if verdict == "approve" else (-2 if correct else -7)
	var trust_change: int = (3 if correct else -12) if verdict == "approve" else (5 if correct else -7)
	var stress_change: int = 3 + (0 if correct else (8 if verdict == "approve" else 6))
	var previous_relationship: int = int(state.coworkers[request.author])
	var previous_trust: int = int(state.trust)
	state.coworkers[request.author] = clampi(previous_relationship + relationship_change, 0, 100)
	state.trust = clampi(previous_trust + trust_change, 0, 100)
	state.stress = clampi(int(state.stress) + stress_change, 0, 100)
	state.decisions.append({
		"pr_id": request.id, "verdict": verdict, "cited_rules": state.selected_rules.duplicate(),
		"evidence": state.citation_evidence.duplicate(true), "consulted": state.consulted, "correct": correct, "shift_seconds": state.shift_seconds,
	})
	var response: String
	if verdict == "approve":
		response = "%s appreciates the approval." % request.author if correct else "%s is relieved you let it through, but the audit flags the risk." % request.author
	else:
		response = "%s accepts the fix but resents the extra work." % request.author if correct else "%s pushes back against an unsupported or incomplete review." % request.author
	var message: String = "%s %s Trust %+d; relationship %+d; stress +%d." % [str(request.explanation).left(280), response, int(state.trust) - previous_trust, int(state.coworkers[request.author]) - previous_relationship, stress_change]
	state.last_feedback = {
		"pr_id": request.id, "author": request.author, "correct": correct, "verdict": verdict,
		"message": message.left(599), "expected_rules": expected.duplicate(),
		"relationship_delta": int(state.coworkers[request.author]) - previous_relationship,
		"trust_delta": int(state.trust) - previous_trust,
	}
	_record(state, "%s: %s. %s" % [request.id, "audit passed" if correct else "audit failed", response])
	if verdict == "request_changes":
		if int(request.revision) < Policy.MAX_REVISION:
			_send_back(state, request)
		else:
			# No v4: the author escalates and Helios takes the PR off the human desk.
			state.autonomy = clampi(int(state.autonomy) + 1, 0, 100)
			_record(state, "%s escalated %s after three rounds. Helios has taken it over." % [request.author, request.origin_id])
	state.active_request_id = ""
	state.selected_rules = []
	state.citation_evidence = {}
	state.consulted = false
	state.desk_at = -1 if state.desk_line.is_empty() else int(state.shift_seconds) + DESK_BEAT
	_update_request_index(state)

## The author revises what was cited. Only cited rules that really were broken get
## fixed; the revision rejoins the line behind the next few PRs.
static func _send_back(state: Dictionary, request: Dictionary) -> void:
	var version: int = int(request.revision) + 1
	var revision_id: String = Policy.revision_id(request, version)
	var cited: Array = state.selected_rules.duplicate()
	cited.sort()
	var fixed: Array = cited.filter(func(rule_id: String) -> bool: return rule_id in request.violations)
	state.revisions.append({
		"id": revision_id, "parent_id": request.id, "origin_id": request.origin_id, "version": version, "day": state.day,
		"cited": cited, "fixed": fixed, "regression": Policy.regression_rule(request, revision_id, fixed, cited),
	})
	state.desk_line.insert(mini(REVISION_GAP, state.desk_line.size()), revision_id)

static func _debrief(state: Dictionary) -> void:
	state.phase = "debrief"
	var correct: int = 0
	var reviewed: int = 0
	var shift_ids: Array = []
	for request: Dictionary in Catalog.requests_for_day(int(state.day)):
		shift_ids.append(request.id)
	for entry: Dictionary in state.revisions:
		if int(entry.day) == int(state.day):
			shift_ids.append(entry.id)
	for decision: Dictionary in state.decisions:
		if decision.pr_id in shift_ids:
			reviewed += 1
			if decision.correct:
				correct += 1
	# Whatever is on the desk or still in line at the bell goes to Helios.
	var handed_off: int = state.desk_line.size() + (0 if str(state.active_request_id).is_empty() else 1)
	var pay: int = 80 + 10 * correct
	state.credits = clampi(int(state.credits) + pay - 90, -9999, 9999)
	state.autonomy = clampi(int(state.autonomy) + (4 + handed_off), 0, 100)
	var message: String = "The shift has ended. Your signed reviews are recorded, and payroll has been settled."
	if handed_off > 0:
		message = "Closing bell. Unsigned work has been handed to Helios; it earns no review bonus. Management is expanding the assistant's authority."
	state.last_debrief = {
		"day": state.day, "reviewed": reviewed, "correct": correct, "pay": pay,
		"expenses": 90, "balance": state.credits, "message": message,
		"timed_out": handed_off > 0, "handed_off": handed_off, "shift_seconds": state.shift_seconds,
	}
	state.shift_history.append({"day": state.day, "shift_seconds": state.shift_seconds, "reviewed": reviewed, "handed_off": handed_off})
	state.active_request_id = ""
	state.desk_line = []
	state.desk_at = -1
	state.selected_rules = []
	state.citation_evidence = {}
	state.consulted = false
	_update_request_index(state)
	_record(state, message)

static func _evening(state: Dictionary, choice: String) -> void:
	state.shift_history[-1].evening_choice = choice
	match choice:
		"rest":
			state.stress = clampi(int(state.stress) - 18, 0, 100)
			_record(state, "You go home and rest. Stress -18.")
		"socialize":
			state.credits = clampi(int(state.credits) - 15, -9999, 9999)
			state.stress = clampi(int(state.stress) - 8, 0, 100)
			for author: String in AUTHORS:
				state.coworkers[author] = clampi(int(state.coworkers[author]) + 4, 0, 100)
			_record(state, "Dinner with the team costs 15. Relationships +4; stress -8.")
		"study":
			state.trust = clampi(int(state.trust) + 4, 0, 100)
			state.stress = clampi(int(state.stress) + 4, 0, 100)
			_record(state, "You spend the evening studying the rulebook. Trust +4; stress +4.")
	if int(state.request_index) == Catalog.requests().size():
		state.phase = "complete"
		_record(state, "Assignment complete. The assistant has more authority; your decisions still have human consequences.")
	else:
		state.day = int(Catalog.request_at(int(state.request_index)).day)
		state.phase = "review"
		state.shift_seconds = 0
		_open_desk(state)
		_update_request_index(state)
		_record(state, "Day %d begins. Read the updated rulebook before reviewing." % state.day)

static func _invalid(reason: String) -> Dictionary:
	return {"ok": false, "state": {}, "error": "Invalid save: " + reason}

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	if typeof(value) == TYPE_FLOAT and (not is_finite(value) or value != floor(value)):
		return false
	return value >= minimum and value <= maximum

static func _rule_list(value: Variant, day: int) -> bool:
	if typeof(value) != TYPE_ARRAY or value.size() > Catalog.rules_for_day(day).size():
		return false
	var seen: Array = []
	for rule_id: Variant in value:
		if not _active_rule(rule_id, day) or rule_id in seen:
			return false
		seen.append(rule_id)
	return true

static func _matches(expected: Variant, candidate: Variant) -> bool:
	# JSON parses numbers as floats; compare exact integral values, never booleans.
	if typeof(expected) == TYPE_INT:
		return _integer(candidate, expected, expected)
	if typeof(expected) != typeof(candidate):
		return false
	if typeof(expected) == TYPE_DICTIONARY:
		if expected.size() != candidate.size():
			return false
		for key: Variant in expected:
			if not candidate.has(key) or not _matches(expected[key], candidate[key]):
				return false
		return true
	if typeof(expected) == TYPE_ARRAY:
		if expected.size() != candidate.size():
			return false
		for index in range(expected.size()):
			if not _matches(expected[index], candidate[index]):
				return false
		return true
	return expected == candidate

static func validate_save(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _invalid("game state must be an object.")
	if not _integer(value.get("version"), SAVE_VERSION, SAVE_VERSION):
		return _invalid("this save cannot be loaded. Start a new game in this slot.")
	var days: Array = Catalog.campaign_days()
	var campaign_size: int = Catalog.requests().size()
	for field: String in ["day", "request_index", "credits", "trust", "stress", "autonomy", "shift_seconds"]:
		var minimum: int = -9999 if field == "credits" else (int(days[0]) if field == "day" else 0)
		var maximum: int = 9999 if field == "credits" else (int(days[-1]) if field == "day" else (campaign_size if field == "request_index" else (Catalog.shift_seconds() if field == "shift_seconds" else 100)))
		if not _integer(value.get(field), minimum, maximum):
			return _invalid("%s has an invalid integer value." % field)
	if int(value.day) not in days or typeof(value.get("active_request_id")) != TYPE_STRING:
		return _invalid("invalid day or active request.")
	if value.get("phase") not in ["review", "debrief", "complete"] or typeof(value.get("consulted")) != TYPE_BOOL:
		return _invalid("invalid phase or consultation flag.")
	if not _rule_list(value.get("selected_rules"), int(value.day)):
		return _invalid("selected rules must be unique active rule IDs.")
	# Each authored PR can be reviewed and consulted up to three times (v1-v3), plus replies.
	if typeof(value.get("actions")) != TYPE_ARRAY or value.actions.size() > campaign_size * 12 + days.size() * 2:
		return _invalid("invalid or oversized action history.")
	var replay: Dictionary = initial_state()
	for index in range(value.actions.size()):
		var event: Variant = value.actions[index]
		if typeof(event) != TYPE_DICTIONARY or not _integer(event.get("day"), int(replay.day), int(replay.day)) or not _integer(event.get("shift_seconds"), int(replay.shift_seconds), Catalog.shift_seconds()):
			return _invalid("action %d has an invalid day or timestamp." % index)
		var kind: Variant = event.get("type")
		if kind not in ["timeout", "next-day", "consult-ai", "review", "chat-reply"]:
			return _invalid("unknown action in history.")
		if kind == "timeout":
			if replay.phase != "review" or int(event.shift_seconds) != Catalog.shift_seconds():
				return _invalid("shift closure is outside its deadline.")
			replay = advance(replay, Catalog.shift_seconds() - int(replay.shift_seconds))
		else:
			if replay.phase == "review" and int(event.shift_seconds) == Catalog.shift_seconds():
				return _invalid("a work action occurs at or after the closing bell.")
			replay = advance(replay, int(event.shift_seconds) - int(replay.shift_seconds))
			var command: Dictionary = event.duplicate(true)
			if kind in ["consult-ai", "review"]:
				if typeof(event.get("pr_id")) != TYPE_STRING:
					return _invalid("action is missing its request identity.")
				if replay.active_request_id != event.pr_id:
					return _invalid("action targets a request that is not on the desk.")
				if kind == "review":
					if not _rule_list(event.get("cited_rules"), int(replay.day)) or typeof(event.get("evidence")) != TYPE_DICTIONARY:
						return _invalid("review contains invalid citations.")
					replay.selected_rules = []
					replay.citation_evidence = {}
					for rule_id: String in event.cited_rules:
						replay = _cite(replay, rule_id, event.evidence.get(rule_id))
				command.erase("cited_rules")
				command.erase("evidence")
			command.erase("day")
			command.erase("shift_seconds")
			replay = dispatch(replay, command)
		if replay.actions.size() != index + 1 or not _matches(replay.actions[index], event):
			return _invalid("action %d cannot occur in this history." % index)
	if int(value.day) != int(replay.day) or int(value.shift_seconds) < int(replay.shift_seconds):
		return _invalid("current clock precedes its action history.")
	replay = advance(replay, int(value.shift_seconds) - int(replay.shift_seconds))
	if typeof(value.get("citation_evidence")) != TYPE_DICTIONARY:
		return _invalid("citations are missing their evidence.")
	replay.selected_rules = []
	replay.citation_evidence = {}
	for rule_id: String in value.selected_rules:
		replay = _cite(replay, rule_id, value.citation_evidence.get(rule_id))
	if not _matches(replay, value):
		return _invalid("state does not match its timed actions, arrivals, or earned resources.")
	return {"ok": true, "state": replay, "error": ""}

static func serialize_save(state: Dictionary) -> String:
	var result: Dictionary = validate_save(state)
	return JSON.stringify(result.state) if result.ok else ""
