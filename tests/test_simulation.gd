extends SceneTree

const Simulation = preload("res://native/simulation.gd")
const SaveStore = preload("res://native/save_store.gd")
const Catalog = preload("res://content/catalog.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_test_catalog()
	_test_reviews()
	_test_career()
	_test_saves()
	print("Review simulation checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _first_request_state() -> Dictionary:
	# The day's first PR is already on the desk; nobody picks it.
	return Simulation.advance(Simulation.initial_state(), 20)

## Wait for the next PR to land if the desk is empty, then review it exactly.
func _resolve(state: Dictionary) -> Dictionary:
	var current: Dictionary = state
	if Simulation.active_request(current).is_empty():
		if int(current.desk_at) < 0 or int(current.desk_at) >= Catalog.shift_seconds():
			return Simulation.advance(current, Simulation.Catalog.shift_seconds())
		current = Simulation.advance(current, int(current.desk_at) - int(current.shift_seconds))
	var request: Dictionary = Catalog.packet(current, current.active_request_id)
	for rule_id: String in request.violations:
		current = Simulation.dispatch(current, Catalog.audit_citation(request, rule_id))
	return Simulation.dispatch(current, {"type": "review", "verdict": "approve" if request.violations.is_empty() else "request_changes"})

func _waiting(state: Dictionary) -> bool:
	return not Simulation.active_request(state).is_empty() or (int(state.desk_at) >= 0 and int(state.desk_at) < Catalog.shift_seconds())

func _round_trip(state: Dictionary) -> void:
	var raw: String = Simulation.serialize_save(state)
	_check(not raw.is_empty(), "Reachable state must serialize at index %d." % state.request_index)
	var parser: JSON = JSON.new()
	_check(parser.parse(raw) == OK, "Serialized state must be JSON.")
	var loaded: Dictionary = Simulation.validate_save(parser.data)
	_check(loaded.ok and loaded.state == state, "JSON float numbers must validate and round-trip.")

func _test_reviews() -> void:
	var initial: Dictionary = _first_request_state()
	_check(initial.credits == 120 and initial.trust == 70 and initial.stress == 20 and initial.autonomy == 10, "Initial resources must match the career design.")
	_check(Simulation.advance(initial, 0) == initial, "A paused clock must not change the game.")
	_check(Simulation.dispatch(initial, {"type": "review", "verdict": "request_changes"}) == initial, "Rejection without citations must not advance.")
	_check(Simulation.dispatch(initial, {"type": "toggle-rule", "rule_id": "MISSING"}) == initial, "Unknown rules must not be selected.")
	for rule: Dictionary in Catalog.rules():
		if int(rule.introduced_day) > 1:
			_check(Simulation.dispatch(initial, {"type": "toggle-rule", "rule_id": rule.id}) == initial, "Future rules must not be selected.")
			break
	var request: Dictionary = Catalog.request_at(0)
	_check(not request.violations.is_empty(), "First request must offer a meaningful faulty-approval temptation.")
	var selected: Dictionary = Simulation.dispatch(initial, Catalog.audit_citation(request, request.violations[0]))
	_check(Simulation.dispatch(selected, {"type": "review", "verdict": "approve"}) == selected, "Approval with citations must not advance.")
	_check(Simulation.dispatch(selected, Catalog.audit_citation(request, request.violations[0])) == initial, "Citation toggles must be reversible.")
	var correct: Dictionary = _resolve(initial)
	_check(correct.request_index == 1 and correct.last_feedback.correct, "Exact citations must produce a correct rejection.")
	_check(correct.trust == 75 and correct.coworkers[request.author] == 48 and correct.stress == 23, "Correct rejection must improve trust but strain the author relationship.")
	_check(correct.last_feedback.expected_rules == request.violations and correct.last_feedback.message.length() < 600, "Feedback must disclose audit and bounded consequences only after review.")
	var wrong_rule: String = ""
	for rule: Dictionary in Catalog.rules_for_day(1):
		if rule.id not in request.violations:
			wrong_rule = rule.id
			break
	var overcited: Dictionary = Simulation.dispatch(selected, Catalog.audit_citation(request, wrong_rule))
	overcited = Simulation.dispatch(overcited, {"type": "review", "verdict": "request_changes"})
	_check(not overcited.last_feedback.correct, "Additional unsupported citations must make rejection incorrect.")
	var pointed: Dictionary = Catalog.audit_citation(request, request.violations[0])
	var _unpointed: Dictionary = pointed.duplicate()
	_unpointed.erase("path")
	_check(Simulation.dispatch(initial, _unpointed) == initial, "A citation must point at a file or line.")
	var misplaced: Dictionary = pointed.duplicate()
	misplaced.line = int(pointed.line) + 1
	var wrong_line: Dictionary = Simulation.dispatch(Simulation.dispatch(initial, misplaced), {"type": "review", "verdict": "request_changes"})
	_check(not wrong_line.last_feedback.correct and wrong_line.decisions[-1].evidence[pointed.rule_id].line == misplaced.line, "Citing the right rule on the wrong line is an incorrect review.")
	var policy := load("res://content/policy_campaign.gd")
	for finding: Dictionary in request.findings:
		_check(policy.evidence_accepted(request.findings, finding.rule_id, finding.path, int(finding.line)), "Every audited finding accepts its own location.")
	_check(policy.evidence_accepted([{"rule_id": "P03", "path": "a.py", "line": 0}], "P03", "a.py", 7) and not policy.evidence_accepted([{"rule_id": "P03", "path": "a.py", "line": 0}], "P03", "b.py", 0), "Whole-file rules accept any line of the right file only.")
	_check(overcited.trust == 63 and overcited.coworkers[request.author] == 43, "Incorrect rejection must hurt trust and relationships.")
	_check(Simulation.dispatch(initial, {"type": "consult-ai"}) == initial, "Helios is unavailable until Wednesday.")
	var bad_approval := Simulation.dispatch(initial, {"type": "review", "verdict": "approve"})
	_check(not bad_approval.last_feedback.correct and bad_approval.trust == 58 and bad_approval.coworkers[request.author] == 56, "Bad approval pleases the author while failing the audit.")
	_round_trip(bad_approval)
	var wednesday := Simulation.initial_state()
	for day in range(2):
		wednesday = Simulation.dispatch(Simulation.advance(wednesday, 300), {"type": "next-day", "choice": "rest"})
	_check(wednesday.active_request_id == Catalog.requests_for_day(3)[0].id, "Each morning puts the day's first PR on the desk.")
	var consulted := Simulation.dispatch(wednesday, {"type": "consult-ai"})
	_check(consulted.consulted and consulted.autonomy == wednesday.autonomy + 4, "Wednesday consultation increases reliance.")
	_check(Simulation.dispatch(consulted, {"type": "consult-ai"}) == consulted, "Consultation effects apply only once per PR.")
	_round_trip(consulted)
	var snapshot: Dictionary = initial.duplicate(true)
	var changed: Dictionary = Simulation.dispatch(initial, {"type": "consult-ai"})
	changed.log[0].message = "mutated"
	changed.coworkers.Maya = 0
	_check(initial == snapshot, "Transitions must deeply preserve input state.")
	var no_clock: Dictionary = Simulation.advance(initial)
	no_clock.log[0].message = "mutated"
	_check(initial == snapshot, "No-op time advancement must also return independent state.")

func _test_career() -> void:
	var state: Dictionary = Simulation.initial_state()
	var expected_credits: int = 120
	var shifts: int = 0
	var escalations: int = 0
	for day: int in Catalog.campaign_days():
		shifts += 1
		var before: int = state.decisions.size()
		while _waiting(state):
			if Simulation.active_request(state).is_empty():
				_check(Simulation.available_requests(state).is_empty(), "Between PRs the desk is empty; nothing can be picked.")
				state = Simulation.advance(state, int(state.desk_at) - int(state.shift_seconds))
			_check(Simulation.available_requests(state).size() == 1, "Only one PR is ever available at a time.")
			var on_desk: Dictionary = Catalog.packet(state, state.active_request_id)
			state = _resolve(state)
			_check(state.decisions.size() == before + 1, "Each valid submission signs exactly the PR on the desk.")
			_check(state.decisions[-1].correct, "Exact citations and approvals stay correct on revisions too.")
			if state.decisions[-1].verdict == "request_changes" and int(on_desk.revision) == 3: escalations += 1
			before = state.decisions.size()
			_round_trip(state)
		var signed: int = 0
		for decision: Dictionary in state.decisions:
			if Catalog.packet(state, decision.pr_id).day == day: signed += 1
		_check(signed >= Catalog.requests_for_day(day).size(), "Every authored PR and every revision reaches the desk before closing.")
		_check(state.phase == "review" and state.desk_line.is_empty(), "Clearing the line must not close the shift before the deadline.")
		state = Simulation.advance(state, Simulation.Catalog.shift_seconds())
		_check(state.phase == "debrief" and state.day == day, "The final authored PR in a shift must enter that day's debrief.")
		_check(state.last_debrief.pay == 80 + 10 * signed and state.last_debrief.expenses == 90 and state.last_debrief.correct == signed and state.last_debrief.reviewed == signed and state.last_debrief.handed_off == 0, "Daily pay must reflect audit correctness, revisions included.")
		expected_credits += 80 + 10 * signed - 90
		_check(state.credits == expected_credits, "Daily economy must apply exactly once.")
		_check(state.autonomy == 10 + 4 * shifts + escalations, "Management must increase automation authority each day, and Helios takes escalations.")
		var frozen: Dictionary = state.duplicate(true)
		for command: Dictionary in [{"type": "review", "verdict": "approve"}, {"type": "consult-ai"}, {"type": "next-day", "choice": "invalid"}]:
			_check(Simulation.dispatch(state, command) == frozen, "Invalid debrief actions must not replay daily pay.")
		state = Simulation.dispatch(state, {"type": "next-day", "choice": "rest"})
		_round_trip(state)
	_check(state.phase == "complete" and state.request_index == Catalog.requests().size() and state.day == Catalog.campaign_days()[-1], "Career must finish safely after ten shifts and evening choices.")
	_check(state.decisions.size() > Catalog.requests().size() and not state.revisions.is_empty() and state.shift_history[-1].evening_choice == "rest", "Change requests add revisions to the career; the final evening is recorded.")
	for command: Dictionary in [{"type": "review", "verdict": "approve"}, {"type": "next-day", "choice": "socialize"}, {"type": "consult-ai"}]:
		_check(Simulation.dispatch(state, command) == state, "Complete careers must not accept more rewards or decisions.")
	var debrief: Dictionary = Simulation.initial_state()
	while _waiting(debrief):
		debrief = _resolve(debrief)
	debrief = Simulation.advance(debrief, Simulation.Catalog.shift_seconds())
	var social: Dictionary = Simulation.dispatch(debrief, {"type": "next-day", "choice": "socialize"})
	_check(social.credits == debrief.credits - 15 and social.coworkers.Maya == mini(100, debrief.coworkers.Maya + 4), "Socializing must charge once and improve relationships.")
	_round_trip(social)
	var studied: Dictionary = Simulation.dispatch(debrief, {"type": "next-day", "choice": "study"})
	_check(studied.trust == mini(100, debrief.trust + 4) and studied.stress == mini(100, debrief.stress + 4), "Studying must improve trust at a stress cost.")
	_round_trip(studied)
	var maximum_stress: Dictionary = _first_request_state()
	maximum_stress.stress = 100
	maximum_stress.trust = 0
	var stressed: Dictionary = Simulation.dispatch(maximum_stress, {"type": "review", "verdict": "approve"})
	_check(stressed.stress == 100 and stressed.trust == 0, "Review consequences must clamp bounded resources.")

func _test_saves() -> void:
	var initial: Dictionary = Simulation.initial_state()
	_round_trip(initial)
	var selected: Dictionary = Simulation.dispatch(_first_request_state(), Catalog.audit_citation(Catalog.request_at(0), Catalog.rules_for_day(1)[0].id))
	selected = Simulation.dispatch(selected, {"type": "consult-ai"})
	_round_trip(selected)
	for value: Variant in [null, [], true, 42, "save", {"version": 1}, {"version": 2}]:
		_check(not Simulation.validate_save(value).ok, "Invalid types and workshop saves must be rejected.")
	for version in range(1, Simulation.SAVE_VERSION) + [Simulation.SAVE_VERSION + 1]:
		var unsupported := initial.duplicate(true)
		unsupported.version = version
		_check(not Simulation.validate_save(unsupported).ok, "Only the current save format is accepted.")
	var corruptions: Array = [
		["version", true], ["day", 4], ["day", 0], ["request_index", 1], ["request_index", 0.5],
		["credits", 121], ["credits", -10000], ["credits", INF], ["trust", NAN],
		["stress", "20"], ["autonomy", 11], ["phase", "complete"], ["consulted", true],
		["coworkers", {"Maya": 100, "Theo": 50, "Inez": 50}], ["selected_rules", ["BAD"]],
		["decisions", [{}]], ["log", []], ["last_feedback", {"correct": true}], ["last_debrief", {"pay": 999}],
		["active_request_id", ""], ["desk_line", []], ["desk_at", 3], ["arrivals", []],
		["revisions", [{"id": "PR-1042-v2"}]],
	]
	for corruption: Array in corruptions:
		var bad: Dictionary = initial.duplicate(true)
		bad[corruption[0]] = corruption[1]
		_check(not Simulation.validate_save(bad).ok, "Corrupted %s must be rejected." % corruption[0])
	var resolved: Dictionary = _resolve(initial)
	var falsified: Dictionary = resolved.duplicate(true)
	falsified.decisions[0].correct = not falsified.decisions[0].correct
	_check(not Simulation.validate_save(falsified).ok, "Decision audit results must be checked against content.")
	falsified = resolved.duplicate(true)
	falsified.decisions[0].evening_choice = "rest"
	_check(not Simulation.validate_save(falsified).ok, "Evening choices outside shift boundaries must be rejected.")
	falsified = resolved.duplicate(true)
	falsified.decisions[0].pr_id = "fabricated"
	_check(not Simulation.validate_save(falsified).ok, "Request history must follow catalog order.")
	falsified = initial.duplicate(true)
	var rule_id: String = Catalog.rules_for_day(1)[0].id
	falsified.selected_rules = [rule_id, rule_id]
	_check(not Simulation.validate_save(falsified).ok, "Duplicate citations must be rejected.")
	var validated: Dictionary = Simulation.validate_save(resolved)
	validated.state.decisions[0].cited_rules.clear()
	_check(not resolved.decisions[0].cited_rules.is_empty(), "Validation must return an independent normalized state.")
	_check(Simulation.serialize_save(falsified).is_empty(), "Invalid state must not serialize.")
	_check(not SaveStore.save_game(falsified).ok, "Persistence must reject corruption before touching files.")

func _test_catalog() -> void:
	var initial_ids: Array = []
	for rule: Dictionary in Catalog.rules_for_day(1):
		initial_ids.append(rule.id)
	initial_ids.sort()
	_check(initial_ids == ["P01", "P02", "P03"], "New reviewers must start with exactly three foundational policies.")
	_check(Catalog.rules_for_day(2).size() == 3 and Catalog.rules_for_day(3).size() == 6 and Catalog.rules_for_day(5).size() == 8, "Active standards must grow gradually across the first week.")
	_check(Catalog.rules_for_day(10).size() <= 8 and not Catalog.rule_active("P05", 7) and Catalog.rule_active("P13", 9), "Week two retires and replaces standards instead of piling them up.")
	_check(Catalog.campaign_days() == range(1, 11), "Campaign days must be derived in authored order: two weeks of five.")
	_check(Catalog.requests_for_day(1).size() == 15 and Catalog.requests_for_day(10).size() == 15, "Each shift lines up fifteen authored PRs.")
	var previous_day: int = 0
	var ids: Array = []
	for request: Dictionary in Catalog.requests():
		_check(int(request.day) >= previous_day and request.id not in ids, "Requests must have unique IDs and contiguous day ordering.")
		previous_day = int(request.day)
		ids.append(request.id)
		var active: Array = []
		for rule: Dictionary in Catalog.rules_for_day(int(request.day)):
			active.append(rule.id)
		for violation: String in request.violations:
			_check(violation in active, "Every audited violation must already be introduced when its PR arrives.")
		_check(not request.files.is_empty() and request.files[0].has("source"), "Review packets include the source being inspected.")
	for day: int in Catalog.campaign_days():
		var briefing: String = Catalog.briefing(day).to_lower()
		_check("requests await" not in briefing and "four requests" not in briefing and "remaining" not in briefing, "Briefings must not announce the queue length.")
	var copied: Array = Catalog.requests_for_day(1)
	copied[0].title = "mutated"
	_check(Catalog.request_at(0).title != "mutated", "Schedule helpers must return independent content copies.")
