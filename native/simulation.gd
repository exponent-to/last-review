extends RefCounted
## Turn-based review rules. Catalog answers are used only to audit submitted decisions.

const Catalog = preload("res://content/catalog.gd")
const LOG_LIMIT: int = 40
const AUTHORS: Array = ["Maya", "Theo", "Inez"]
const EVENINGS: Array = ["rest", "socialize", "study"]

static func initial_state() -> Dictionary:
	return {
		"version": 2, "day": 1, "request_index": 0, "phase": "review",
		"credits": 120, "trust": 70, "stress": 20, "autonomy": 10,
		"coworkers": {"Maya": 50, "Theo": 50, "Inez": 50},
		"selected_rules": [], "consulted": false, "decisions": [],
		"log": [{"day": 1, "message": "Your review shift begins. Read carefully; there is no timer."}],
		"last_feedback": {}, "last_debrief": {},
	}

static func advance(state: Dictionary, _ticks: int = 1) -> Dictionary:
	return state.duplicate(true)

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
	if next.phase == "complete":
		return next
	if kind == "next-day":
		if next.phase == "debrief" and command.get("choice") in EVENINGS:
			_evening(next, command.choice)
		return next
	if next.phase != "review":
		return next
	match kind:
		"toggle-rule":
			var rule_id: Variant = command.get("rule_id")
			if not _active_rule(rule_id, int(next.day)):
				return next
			if rule_id in next.selected_rules:
				next.selected_rules.erase(rule_id)
			else:
				next.selected_rules.append(rule_id)
		"consult-ai":
			if not next.consulted:
				next.consulted = true
				next.autonomy = clampi(int(next.autonomy) + 4, 0, 100)
				next.stress = clampi(int(next.stress) - 2, 0, 100)
				_record(next, "You asked the assistant to assess this PR. Automation reliance +4; stress -2.")
		"review":
			var verdict: Variant = command.get("verdict")
			if verdict not in ["approve", "request_changes"]:
				return next
			if (verdict == "approve" and not next.selected_rules.is_empty()) or (verdict == "request_changes" and next.selected_rules.is_empty()):
				return next
			_review(next, verdict)
	return next

static func _review(state: Dictionary, verdict: String) -> void:
	var request: Dictionary = Catalog.request_at(int(state.request_index))
	var expected: Array = request.violations
	var correct: bool = expected.is_empty() if verdict == "approve" else _same_rules(state.selected_rules, expected)
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
		"consulted": state.consulted, "correct": correct,
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
	state.request_index += 1
	state.selected_rules = []
	state.consulted = false
	if int(state.request_index) % 4 == 0:
		_debrief(state)

static func _debrief(state: Dictionary) -> void:
	state.phase = "debrief"
	var correct: int = 0
	for index in range(int(state.request_index) - 4, int(state.request_index)):
		if state.decisions[index].correct:
			correct += 1
	var pay: int = 80 + 10 * correct
	state.credits = clampi(int(state.credits) + pay - 90, -9999, 9999)
	state.autonomy = clampi(int(state.autonomy) + 12, 0, 100)
	state.last_debrief = {
		"day": state.day, "reviewed": 4, "correct": correct, "pay": pay,
		"expenses": 90, "balance": state.credits,
		"message": "Shift audited: %d of 4 correct. Pay %d, living expenses 90. Management expands the assistant's authority; automation reliance +12." % [correct, pay],
	}
	_record(state, state.last_debrief.message)

static func _evening(state: Dictionary, choice: String) -> void:
	state.decisions[-1].evening_choice = choice
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
	if state.day == 3:
		state.phase = "complete"
		_record(state, "Three shifts complete. The assistant has more authority; your decisions still have human consequences.")
	else:
		state.day += 1
		state.phase = "review"
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

static func validate_save(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _invalid("game state must be an object.")
	if not _integer(value.get("version"), 2, 2):
		return _invalid("this is not a Last Review version 2 save. Old workshop saves cannot be loaded; start a new review career.")
	for field: String in ["day", "request_index", "credits", "trust", "stress", "autonomy"]:
		var minimum: int = -9999 if field == "credits" else (1 if field == "day" else 0)
		var maximum: int = 9999 if field == "credits" else (3 if field == "day" else (12 if field == "request_index" else 100))
		if not _integer(value.get(field), minimum, maximum):
			return _invalid("%s has an invalid integer value." % field)
	if value.get("phase") not in ["review", "debrief", "complete"] or typeof(value.get("consulted")) != TYPE_BOOL:
		return _invalid("invalid phase or consultation flag.")
	if not _rule_list(value.get("selected_rules"), int(value.day)):
		return _invalid("selected rules must be unique active rule IDs.")
	if typeof(value.get("coworkers")) != TYPE_DICTIONARY or value.coworkers.size() != 3:
		return _invalid("coworker relationships are missing.")
	for author: String in AUTHORS:
		if not _integer(value.coworkers.get(author), 0, 100):
			return _invalid("invalid relationship with " + author + ".")
	if typeof(value.get("decisions")) != TYPE_ARRAY or value.decisions.size() != int(value.request_index):
		return _invalid("decision history does not match the request index.")
	if typeof(value.get("log")) != TYPE_ARRAY or value.log.size() > LOG_LIMIT or typeof(value.get("last_feedback")) != TYPE_DICTIONARY or typeof(value.get("last_debrief")) != TYPE_DICTIONARY:
		return _invalid("invalid activity or feedback data.")
	# Replay the bounded journal to verify resources, phases, audits, and one-time pay.
	var replay: Dictionary = initial_state()
	for index in range(value.decisions.size()):
		var decision: Variant = value.decisions[index]
		if typeof(decision) != TYPE_DICTIONARY or replay.phase != "review":
			return _invalid("decision %d occurs outside a review shift." % index)
		if decision.get("pr_id") != Catalog.request_at(index).id or decision.get("verdict") not in ["approve", "request_changes"]:
			return _invalid("decision %d has an invalid request or verdict." % index)
		if typeof(decision.get("consulted")) != TYPE_BOOL or typeof(decision.get("correct")) != TYPE_BOOL or not _rule_list(decision.get("cited_rules"), int(replay.day)):
			return _invalid("decision %d has invalid citations or flags." % index)
		for rule_id: String in decision.cited_rules:
			replay = dispatch(replay, {"type": "toggle-rule", "rule_id": rule_id})
		if decision.consulted:
			replay = dispatch(replay, {"type": "consult-ai"})
		replay = dispatch(replay, {"type": "review", "verdict": decision.verdict})
		if replay.request_index != index + 1:
			return _invalid("decision %d could not be submitted." % index)
		if decision.has("evening_choice"):
			if replay.phase != "debrief" or decision.evening_choice not in EVENINGS:
				return _invalid("evening choice occurs outside a completed shift.")
			replay = dispatch(replay, {"type": "next-day", "choice": decision.evening_choice})
		if replay.decisions[index] != decision:
			return _invalid("decision %d does not match its audit." % index)
	for rule_id: String in value.selected_rules:
		replay = dispatch(replay, {"type": "toggle-rule", "rule_id": rule_id})
	if value.consulted:
		replay = dispatch(replay, {"type": "consult-ai"})
	if replay != value:
		return _invalid("state does not match its decision history, phase, or earned resources.")
	return {"ok": true, "state": replay, "error": ""}

static func serialize_save(state: Dictionary) -> String:
	var result: Dictionary = validate_save(state)
	return JSON.stringify(result.state) if result.ok else ""
