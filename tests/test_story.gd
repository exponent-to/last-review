extends SceneTree
## The Helios-takeover story spine: payload tracking, firing rules, player firing,
## the ending matrix, reject-with-no-reason, and save replay of a career that
## fires a coworker, ships and blocks payloads, and reaches an ending.
const Sim = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Staff = preload("res://content/staff.gd")
const Endings = preload("res://content/endings.gd")
const Encounters = preload("res://content/encounters.gd")

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_test_reject_no_reason()
	_test_payload_tracking()
	_test_ending_matrix()
	_test_player_fired()
	_test_coworker_fired_and_replaced()
	_test_whole_team_fired()
	_test_save_replay_with_story()
	print("Story checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

# --- Helpers --------------------------------------------------------------------

func _advance_to_desk(state: Dictionary) -> Dictionary:
	if not Sim.active_request(state).is_empty(): return state
	var coming: bool = int(state.desk_at) >= 0 and int(state.desk_at) < Catalog.shift_seconds()
	return Sim.advance(state, int(state.desk_at) - int(state.shift_seconds) if coming else Catalog.shift_seconds())

## Play a career. `decide(state, packet)` returns a review command; `evening` is the
## nightly choice. Stops when `done(state)` is true or the run completes.
func _play(decide: Callable, evening: String, done: Callable = Callable()) -> Dictionary:
	var state := Sim.initial_state()
	var guard := 0
	while state.phase != "complete" and guard < 9000:
		guard += 1
		if done.is_valid() and done.call(state): return state
		if state.phase == "debrief":
			state = Sim.dispatch(state, {"type": "next-day", "choice": evening})
			continue
		if not Encounters.pending(state).is_empty():
			state = _advance_to_desk(Sim.dispatch(state, {"type": "pushback", "choice": "insist"}))
			continue
		if Sim.active_request(state).is_empty():
			state = _advance_to_desk(state)
			continue
		var packet: Dictionary = Catalog.packet(state, state.active_request_id)
		var command: Dictionary = decide.call(state, packet)
		if command.get("type") == "review" and command.get("verdict") == "request_changes":
			for rule_id: String in command.get("cite", []):
				state = Sim.dispatch(state, Catalog.audit_citation(packet, rule_id))
		state = _advance_to_desk(Sim.dispatch(state, {"type": "review", "verdict": command.verdict}))
	return state

## Correct review: approve clean, reject broken with exact citations, block payloads.
func _correct(_state: Dictionary, packet: Dictionary) -> Dictionary:
	if packet.get("payload", false): return {"type": "review", "verdict": "request_changes", "cite": ["P15"]}
	if packet.violations.is_empty(): return {"type": "review", "verdict": "approve"}
	return {"type": "review", "verdict": "request_changes", "cite": packet.violations}

# --- Reject with no reason ------------------------------------------------------

func _test_reject_no_reason() -> void:
	# On a normal PR: an unexplained block, graded incorrect, merged by Helios.
	var state := Sim.initial_state()
	var packet: Dictionary = Catalog.packet(state, state.active_request_id)
	check(not packet.violations.is_empty() and not packet.get("payload", false), "The first PR is a normal, faulty PR.")
	var before_autonomy := int(state.autonomy)
	var after := Sim.dispatch(state, {"type": "review", "verdict": "request_changes"})
	check(after.decisions.size() == 1 and not after.decisions[-1].correct, "A reason-free rejection of a normal PR is graded incorrect.")
	check(after.encounters[-1].node == "unexplained", "A reason-free rejection takes the unexplained branch.")
	check(int(after.autonomy) == before_autonomy + 1, "Helios merges the unexplained PR, raising its authority.")
	check(after.revisions.is_empty(), "No revision comes from an unexplained rejection.")

	# On a payload: a reason-free block is correct, and the payload is recorded blocked.
	var pstate := _advance_to_payload()
	check(not pstate.is_empty(), "A payload reaches the desk by day 3.")
	var blocked := Sim.dispatch(pstate, {"type": "review", "verdict": "request_changes"})
	check(blocked.decisions[-1].correct, "Blocking a payload with no citation is a correct review.")
	check(blocked.encounters[-1].node == "blocked", "Blocking a payload takes the blocked branch.")
	check(blocked.payloads.size() == 1 and blocked.payloads[-1].outcome == "blocked", "A blocked payload is tracked as blocked.")

## Walk to the first payload on the desk.
func _advance_to_payload() -> Dictionary:
	var state := Sim.initial_state()
	var guard := 0
	while state.phase != "complete" and guard < 4000:
		guard += 1
		if state.phase == "debrief":
			state = Sim.dispatch(state, {"type": "next-day", "choice": "rest"}); continue
		if not Encounters.pending(state).is_empty():
			state = _advance_to_desk(Sim.dispatch(state, {"type": "pushback", "choice": "insist"})); continue
		if Sim.active_request(state).is_empty():
			state = _advance_to_desk(state); continue
		var packet: Dictionary = Catalog.packet(state, state.active_request_id)
		if packet.get("payload", false): return state
		var cmd := _correct(state, packet)
		for rule_id: String in cmd.get("cite", []): state = Sim.dispatch(state, Catalog.audit_citation(packet, rule_id))
		state = _advance_to_desk(Sim.dispatch(state, {"type": "review", "verdict": cmd.verdict}))
	return {}

# --- Payload tracking -----------------------------------------------------------

func _test_payload_tracking() -> void:
	# Block every payload: eight blocked, none through, and all eight payloads exist.
	var blocked := _play(_correct, "rest")
	check(blocked.phase == "complete", "A correct career completes.")
	check(blocked.payloads.size() == 8, "All eight payloads are resolved over the run.")
	check(blocked.payloads.all(func(p: Dictionary) -> bool: return p.outcome == "blocked"), "Blocking every payload records them all blocked.")
	var ids: Array = blocked.payloads.map(func(p: Dictionary) -> String: return str(p.pr_id))
	var unique: Dictionary = {}
	for id: String in ids: unique[id] = true
	check(ids.size() == 8 and unique.size() == 8, "Every payload is tracked once.")
	# Approve everything a correct reviewer would block: payloads go through.
	var through := _play(func(s: Dictionary, p: Dictionary) -> Dictionary:
		if p.get("payload", false): return {"type": "review", "verdict": "approve"}
		return _correct(s, p), "socialize")
	var merged: Array = through.payloads.filter(func(p: Dictionary) -> bool: return p.outcome != "blocked")
	check(merged.size() >= 1, "Approved payloads are tracked as let through.")

# --- Ending matrix --------------------------------------------------------------

func _ending_state(outcomes: Array, like: int) -> Dictionary:
	var state := Sim.initial_state()
	state.day = int(Catalog.campaign_days()[-1])
	for author: String in state.coworkers: state.coworkers[author] = like
	state.payloads = []
	for i in range(outcomes.size()):
		state.payloads.append({"pr_id": "PR-P%d" % (i + 3), "origin_id": "PR-P%d" % (i + 3), "day": 3, "tier": 1, "outcome": str(outcomes[i])})
	return state

func _test_ending_matrix() -> void:
	# Mostly blocked (gate held) crossed with whether the team is on your side.
	check(Sim.resolve_ending(_ending_state(["blocked", "blocked", "approved"], 70)) == "last_reviewers", "Blocked + liked -> The Last Reviewers.")
	check(Sim.resolve_ending(_ending_state(["blocked", "blocked", "approved"], 20)) == "right_and_alone", "Blocked + resented -> Right and Alone.")
	# Mostly through (Helios won) crossed the same way.
	check(Sim.resolve_ending(_ending_state(["approved", "merged", "blocked"], 70)) == "soft_landing", "Through + liked -> Soft Landing.")
	check(Sim.resolve_ending(_ending_state(["approved", "merged", "blocked"], 20)) == "helios_prime", "Through + resented -> Helios Prime.")
	for key: String in ["last_reviewers", "right_and_alone", "soft_landing", "helios_prime", "player_fired", "team_fired"]:
		check(Endings.has(key) and not Endings.title(key).is_empty() and not Endings.morgan(key).is_empty() and Endings.beats(key).size() >= 3, "Ending %s has a title, Morgan's words, and cinematic beats." % key)

# --- Player firing --------------------------------------------------------------

func _test_player_fired() -> void:
	# Approve everything, including defects: Morgan's trust collapses and you are let go.
	var state := _play(func(_s: Dictionary, _p: Dictionary) -> Dictionary:
		return {"type": "review", "verdict": "approve"}, "study")
	check(state.phase == "complete" and state.ending == "player_fired", "Rubber-stamping every PR gets you fired.")
	check(int(state.trust) < Sim.FIRE_TRUST or int(state.stress) >= 100, "Firing follows collapsed trust or maxed stress.")
	check(int(state.day) < int(Catalog.campaign_days()[-1]), "The firing ends the run before the final day.")

# --- Coworker firing and replacement --------------------------------------------

func _test_coworker_fired_and_replaced() -> void:
	# Approve the first of Maya's broken PRs each day (its defect ships), reviewing
	# everything else correctly. Maya takes one strike a day and is let go on the
	# third; June takes the seat the next morning, and you keep Morgan's trust.
	var state := _play(func(s: Dictionary, p: Dictionary) -> Dictionary:
		if str(p.author) == "Maya" and not p.violations.is_empty() and not p.get("payload", false):
			var bad_today := 0
			for d: Dictionary in s.decisions:
				if d.verdict == "approve" and not d.correct:
					var dp: Dictionary = Catalog.packet(s, str(d.pr_id))
					if str(dp.get("author", "")) == "Maya" and int(dp.get("day", 0)) == int(s.day): bad_today += 1
			if bad_today == 0: return {"type": "review", "verdict": "approve"}
		return _correct(s, p),
		"rest",
		func(s: Dictionary) -> bool: return Staff.is_fired(s, "Maya"))
	check(Staff.is_fired(state, "Maya"), "Approving a coworker's defects repeatedly gets them fired.")
	var firing: Dictionary = {}
	for f: Dictionary in state.firings:
		if str(f.name) == "Maya": firing = f
	check(not firing.is_empty() and str(firing.seat) == "Maya" and str(firing.hire) == "June", "A freed seat passes to June.")
	check(str(firing.reason).contains("defect"), "The firing names the shipped defect as the cause.")
	check(Staff.strikes(state, "Maya") >= Staff.STRIKES_TO_FIRE, "Three strikes precede the firing.")
	var next_day := int(firing.day) + 1
	check(Staff.occupant(state, "Maya", next_day) == "June", "June occupies Maya's seat the next day.")
	check("Maya" not in Staff.team(state, next_day) and "June" in Staff.team(state, next_day), "The team swaps the fired seat for the hire.")
	check(state.ending != "player_fired", "A careful reviewer is not fired while a coworker is.")

# --- Whole team fired -----------------------------------------------------------

func _test_whole_team_fired() -> void:
	# A constructed close where every original seat has been let go ends the run.
	var state := Sim.initial_state()
	for seat: String in Staff.seats():
		state.firings.append({"name": seat, "seat": seat, "day": 2, "hire": "", "reason": "test"})
	check(Staff.whole_team_fired(state), "Firing every original seat is a whole-team wipeout.")
	check(Sim.resolve_ending(state) != "", "An ending resolves even with the team gone.")

# --- Save replay ----------------------------------------------------------------

func _test_save_replay_with_story() -> void:
	# A career that fires a coworker, ships and blocks payloads, and ends, round-trips.
	var state := _play(func(s: Dictionary, p: Dictionary) -> Dictionary:
		if p.get("payload", false):
			return {"type": "review", "verdict": "approve"} if int(p.get("payload_tier", 0)) % 2 == 0 else {"type": "review", "verdict": "request_changes", "cite": ["P15"]}
		if str(p.author) == "Theo" and not p.violations.is_empty():
			return {"type": "review", "verdict": "approve"}
		return _correct(s, p), "socialize")
	check(state.phase == "complete" and not str(state.ending).is_empty(), "The mixed career reaches an ending.")
	check(not state.payloads.is_empty(), "The mixed career resolved payloads.")
	var raw := Sim.serialize_save(state)
	check(not raw.is_empty(), "A career with firings, payloads, and an ending serializes.")
	var loaded := Sim.validate_save(JSON.parse_string(raw))
	check(loaded.ok and loaded.state == state, "Replaying the journal rebuilds the staffing, payloads, and ending exactly.")
