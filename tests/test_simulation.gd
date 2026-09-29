extends SceneTree

const Simulation = preload("res://native/simulation.gd")
const SaveStore = preload("res://native/save_store.gd")
const Catalog = preload("res://content/catalog.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
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

func _resolve(state: Dictionary) -> Dictionary:
	var current: Dictionary = state
	var request: Dictionary = Catalog.request_at(int(state.request_index))
	for rule_id: String in request.violations:
		current = Simulation.dispatch(current, {"type": "toggle-rule", "rule_id": rule_id})
	return Simulation.dispatch(current, {"type": "review", "verdict": "approve" if request.violations.is_empty() else "request_changes"})

func _round_trip(state: Dictionary) -> void:
	var raw: String = Simulation.serialize_save(state)
	_check(not raw.is_empty(), "Reachable state must serialize at index %d." % state.request_index)
	var parser: JSON = JSON.new()
	_check(parser.parse(raw) == OK, "Serialized state must be JSON.")
	var loaded: Dictionary = Simulation.validate_save(parser.data)
	_check(loaded.ok and loaded.state == state, "JSON float numbers must validate and round-trip.")

func _test_reviews() -> void:
	var initial: Dictionary = Simulation.initial_state()
	_check(initial.credits == 120 and initial.trust == 70 and initial.stress == 20 and initial.autonomy == 10, "Initial resources must match the career design.")
	_check(Simulation.advance(initial, 99999) == initial, "Reading must never have a time penalty.")
	_check(Simulation.dispatch(initial, {"type": "review", "verdict": "request_changes"}) == initial, "Rejection without citations must not advance.")
	_check(Simulation.dispatch(initial, {"type": "toggle-rule", "rule_id": "MISSING"}) == initial, "Unknown rules must not be selected.")
	for rule: Dictionary in Catalog.rules():
		if int(rule.introduced_day) > 1:
			_check(Simulation.dispatch(initial, {"type": "toggle-rule", "rule_id": rule.id}) == initial, "Future rules must not be selected.")
			break
	var request: Dictionary = Catalog.request_at(0)
	_check(not request.violations.is_empty(), "First request must offer a meaningful faulty-approval temptation.")
	var selected: Dictionary = Simulation.dispatch(initial, {"type": "toggle-rule", "rule_id": request.violations[0]})
	_check(Simulation.dispatch(selected, {"type": "review", "verdict": "approve"}) == selected, "Approval with citations must not advance.")
	_check(Simulation.dispatch(selected, {"type": "toggle-rule", "rule_id": request.violations[0]}) == initial, "Citation toggles must be reversible.")
	var correct: Dictionary = _resolve(initial)
	_check(correct.request_index == 1 and correct.last_feedback.correct, "Exact citations must produce a correct rejection.")
	_check(correct.trust == 75 and correct.coworkers[request.author] == 48 and correct.stress == 23, "Correct rejection must improve trust but strain the author relationship.")
	_check(correct.last_feedback.expected_rules == request.violations and correct.last_feedback.message.length() < 600, "Feedback must disclose audit and bounded consequences only after review.")
	var wrong_rule: String = ""
	for rule: Dictionary in Catalog.rules_for_day(1):
		if rule.id not in request.violations:
			wrong_rule = rule.id
			break
	var overcited: Dictionary = Simulation.dispatch(selected, {"type": "toggle-rule", "rule_id": wrong_rule})
	overcited = Simulation.dispatch(overcited, {"type": "review", "verdict": "request_changes"})
	_check(not overcited.last_feedback.correct, "Additional unsupported citations must make rejection incorrect.")
	_check(overcited.trust == 63 and overcited.coworkers[request.author] == 43, "Incorrect rejection must hurt trust and relationships.")
	var consulted: Dictionary = Simulation.dispatch(initial, {"type": "consult-ai"})
	_check(consulted.consulted and consulted.autonomy == 14 and consulted.stress == 18, "AI consultation must trade stress relief for reliance.")
	_check(Simulation.dispatch(consulted, {"type": "consult-ai"}) == consulted, "Consultation effects must apply once per PR.")
	_round_trip(consulted)
	var ai_result: Dictionary = Simulation.dispatch(consulted, {"type": "review", "verdict": request.ai_verdict})
	_check(request.ai_verdict == "approve" and not ai_result.last_feedback.correct, "The AI must be fallible on the first request.")
	_check(ai_result.coworkers[request.author] == 56 and ai_result.trust == 58, "Bad approval must please the author while failing the audit.")
	_check(ai_result.stress == 29 and not ai_result.consulted, "Review must apply stress and reset consultation for the next PR.")
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
	for day in range(1, 4):
		for review in range(4):
			state = _resolve(state)
			_check(state.request_index == (day - 1) * 4 + review + 1, "Each valid submission must advance exactly one request.")
			_round_trip(state)
		_check(state.phase == "debrief" and state.day == day, "Every fourth PR must enter that day's debrief.")
		_check(state.last_debrief.pay == 120 and state.last_debrief.expenses == 90 and state.last_debrief.correct == 4, "Daily pay must reflect audit correctness.")
		_check(state.credits == 120 + 30 * day, "Daily economy must apply exactly once.")
		_check(state.autonomy == 10 + 12 * day, "Management must increase automation authority each day.")
		var frozen: Dictionary = state.duplicate(true)
		for command: Dictionary in [{"type": "review", "verdict": "approve"}, {"type": "consult-ai"}, {"type": "next-day", "choice": "invalid"}]:
			_check(Simulation.dispatch(state, command) == frozen, "Invalid debrief actions must not replay daily pay.")
		state = Simulation.dispatch(state, {"type": "next-day", "choice": "rest"})
		_round_trip(state)
	_check(state.phase == "complete" and state.request_index == 12 and state.day == 3, "Career must finish safely after three shifts and evening choices.")
	_check(state.decisions.size() == 12 and state.decisions[-1].evening_choice == "rest", "Final evening choice must be recorded and applied.")
	for command: Dictionary in [{"type": "review", "verdict": "approve"}, {"type": "next-day", "choice": "socialize"}, {"type": "consult-ai"}]:
		_check(Simulation.dispatch(state, command) == state, "Complete careers must not accept more rewards or decisions.")
	var debrief: Dictionary = Simulation.initial_state()
	for _i in range(4):
		debrief = Simulation.dispatch(debrief, {"type": "review", "verdict": "approve"})
	var social: Dictionary = Simulation.dispatch(debrief, {"type": "next-day", "choice": "socialize"})
	_check(social.credits == debrief.credits - 15 and social.coworkers.Maya == mini(100, debrief.coworkers.Maya + 4), "Socializing must charge once and improve relationships.")
	_round_trip(social)
	var studied: Dictionary = Simulation.dispatch(debrief, {"type": "next-day", "choice": "study"})
	_check(studied.trust == mini(100, debrief.trust + 4) and studied.stress == mini(100, debrief.stress + 4), "Studying must improve trust at a stress cost.")
	_round_trip(studied)
	var maximum_stress: Dictionary = Simulation.initial_state()
	maximum_stress.stress = 100
	maximum_stress.trust = 0
	var stressed: Dictionary = Simulation.dispatch(maximum_stress, {"type": "review", "verdict": "approve"})
	_check(stressed.stress == 100 and stressed.trust == 0, "Review consequences must clamp bounded resources.")

func _test_saves() -> void:
	var initial: Dictionary = Simulation.initial_state()
	_round_trip(initial)
	var selected: Dictionary = Simulation.dispatch(initial, {"type": "toggle-rule", "rule_id": Catalog.rules_for_day(1)[0].id})
	selected = Simulation.dispatch(selected, {"type": "consult-ai"})
	_round_trip(selected)
	for value: Variant in [null, [], true, 42, "save", {"version": 1}]:
		_check(not Simulation.validate_save(value).ok, "Invalid types and workshop saves must be rejected.")
	_check("workshop" in Simulation.validate_save({"version": 1}).error, "Old save rejection must explain the incompatible workshop format.")
	var corruptions: Array = [
		["version", true], ["day", 4], ["day", 0], ["request_index", 1], ["request_index", 0.5],
		["credits", 121], ["credits", -10000], ["credits", INF], ["trust", NAN],
		["stress", "20"], ["autonomy", 11], ["phase", "complete"], ["consulted", true],
		["coworkers", {"Maya": 100, "Theo": 50, "Inez": 50}], ["selected_rules", ["BAD"]],
		["decisions", [{}]], ["log", []], ["last_feedback", {"correct": true}], ["last_debrief", {"pay": 999}],
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
