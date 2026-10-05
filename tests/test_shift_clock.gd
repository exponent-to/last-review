extends SceneTree

const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Chat = preload("res://content/chat.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_test_clock()
	_test_desk_arrivals()
	_test_timeout_history()
	_test_save_replay()
	_test_replies()
	_test_mixed_action_history()
	print("Shift clock checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _round_trip(state: Dictionary) -> void:
	var raw: String = Simulation.serialize_save(state)
	_check(not raw.is_empty(), "Reachable timed state must serialize.")
	var result: Dictionary = Simulation.validate_save(JSON.parse_string(raw))
	_check(result.ok and result.state == state, "Timed action history must round-trip through JSON numbers.")

func _desk_id(state: Dictionary) -> String:
	return str(Simulation.active_request(state).get("id", ""))

## Wait out the beat until the next PR lands, if one is coming.
func _await_desk(state: Dictionary) -> Dictionary:
	if not Simulation.active_request(state).is_empty() or int(state.desk_at) < 0:
		return state
	return Simulation.advance(state, int(state.desk_at) - int(state.shift_seconds))

func _test_clock() -> void:
	var initial: Dictionary = Simulation.initial_state()
	_check(Simulation.Catalog.shift_seconds() == 180 and Simulation.clock_minutes(initial) == 540, "A three-minute shift must start at 09:00.")
	_check(Simulation.clock_minutes(Simulation.advance(initial, 90)) == 810, "Half a shift must show 13:30.")
	var end: Dictionary = Simulation.advance(initial, Simulation.Catalog.shift_seconds())
	_check(Simulation.clock_minutes(end) == 1080 and end.phase == "debrief", "The closing bell must be 18:00.")
	_check(initial.shift_seconds == 0 and initial.actions.is_empty(), "Advancing time must deeply preserve its input.")
	_check(Simulation.advance(initial, 0) == initial and Simulation.advance(initial, -1) == initial, "Paused and invalid negative deltas must be no-ops.")
	var stepped: Dictionary = initial
	for _second in range(Simulation.Catalog.shift_seconds()):
		stepped = Simulation.advance(stepped)
	_check(stepped == end, "Single-second and batched clocks must produce identical closure.")
	_check(Simulation.advance(end, 99999) == end, "Debrief must not accrue more time, pay, or handoffs.")
	_round_trip(end)

func _test_desk_arrivals() -> void:
	var state: Dictionary = Simulation.initial_state()
	var first: Dictionary = Catalog.request_at(0)
	_check(_desk_id(state) == first.id and Simulation.available_requests(state).size() == 1, "The day's first PR is on the desk at shift start without being picked.")
	_check(state.arrivals == [{"pr_id": first.id, "day": 1, "shift_seconds": 0}], "The desk records when each PR arrived.")
	_check(Simulation.dispatch(state, {"type": "select-request", "pr_id": Catalog.request_at(1).id}) == state, "There is no command to pick another PR out of the line.")
	var waited: Dictionary = Simulation.advance(state, Catalog.shift_seconds() - 20)
	_check(_desk_id(waited) == first.id and Simulation.available_requests(waited).size() == 1, "Waiting never piles up work: the desk holds one PR.")
	var public: Dictionary = Simulation.active_request(state)
	_check(not public.has("violations") and not public.has("findings") and not public.has("explanation") and not public.has("ai_note") and not public.has("recipe"), "The desk view hides audit answers, recipes, and unrequested advice.")
	_check(int(public.revision) == 1 and str(public.parent_id).is_empty(), "Originals are revision 1 with no parent.")
	state = Simulation.advance(state, 20)
	state = Simulation.dispatch(state, Simulation.Catalog.audit_citation(Simulation.active_request(state), "P01"))
	state = Simulation.advance(state, 5)
	_check(state.selected_rules == ["P01"], "Citations stay on the desk PR while time passes.")
	state = Simulation.dispatch(state, {"type": "consult-ai"})
	_check(not Simulation.active_request(state).has("ai_note"), "Advice remains locked until Wednesday.")
	_round_trip(state)
	state = Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": "P01"})
	state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	_check(state.decisions[0].pr_id == first.id and state.request_index == 1, "Stamping signs the PR on the desk.")
	_check(Simulation.available_requests(state).is_empty() and state.desk_at == 25 + Simulation.DESK_BEAT, "After a stamp the desk is empty for a short beat.")
	_check(Simulation.dispatch(state, {"type": "review", "verdict": "approve"}) == state, "An empty desk cannot be signed.")
	_round_trip(state)
	var almost: Dictionary = Simulation.advance(state, Simulation.DESK_BEAT - 1)
	_check(Simulation.active_request(almost).is_empty(), "The next PR does not land early.")
	var landed: Dictionary = Simulation.advance(state, Simulation.DESK_BEAT)
	_check(_desk_id(landed) == Catalog.request_at(1).id and landed.arrivals[-1].shift_seconds == 25 + Simulation.DESK_BEAT, "The next PR in line lands by itself after the beat.")
	var overshoot: Dictionary = Simulation.advance(state, 40)
	_check(_desk_id(overshoot) == _desk_id(landed) and overshoot.arrivals == landed.arrivals, "A large clock step records the scheduled landing time, not the current time.")
	var stepped: Dictionary = state
	for _second in range(40): stepped = Simulation.advance(stepped)
	_check(stepped == overshoot, "Single-second and batched clocks land the next PR identically.")
	_round_trip(landed)
	_round_trip(overshoot)

func _test_timeout_history() -> void:
	var state: Dictionary = Simulation.initial_state()
	var total_handed_off: int = 0
	for day: int in Catalog.campaign_days():
		state = Simulation.advance(state, 99999)
		total_handed_off += Catalog.requests_for_day(day).size()
		_check(state.decisions.is_empty(), "Timeout must not fabricate player approvals or rejections.")
		_check(state.last_debrief.timed_out and state.last_debrief.reviewed == 0 and state.last_debrief.pay == 80 and state.last_debrief.expenses == 90, "No signed work earns only base pay and no review bonus.")
		_check(state.last_debrief.handed_off == Catalog.requests_for_day(day).size(), "All remaining work must transfer to Helios at the bell.")
		_check(state.autonomy == mini(100, 10 + day * 4 + total_handed_off), "Missed work must increase automation authority in addition to the daily expansion.")
		_round_trip(state)
		state = Simulation.dispatch(state, {"type": "next-day", "choice": "rest"})
		if state.phase == "review":
			_check(state.shift_seconds == 0 and _desk_id(state) == Catalog.requests_for_day(int(state.day))[0].id, "A new day resets the clock and puts its first PR on the desk.")
		_round_trip(state)
	_check(state.phase == "complete" and state.credits == 120 - 10 * Catalog.campaign_days().size() and state.chat_replies.is_empty(), "An entirely missed campaign must finish safely without imaginary interaction.")
	_check(Simulation.advance(state, 300) == state, "Complete careers cannot run another shift.")

func _test_save_replay() -> void:
	var state: Dictionary = Simulation.advance(Simulation.initial_state(), 50)
	state = Simulation.dispatch(state, {"type": "consult-ai"})
	state = Simulation.advance(state, 70)
	state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	state = Simulation.advance(state, 240)
	_round_trip(state)
	_check(state.last_debrief.reviewed == 1 and state.last_debrief.correct == 0 and state.last_debrief.handed_off == 14, "Partial work must receive only its actual audit results.")
	var corruptions: Array = [
		["shift_seconds", 299], ["active_request_id", Catalog.request_at(0).id],
		["request_index", 1], ["credits", 999], ["shift_history", []],
		["consulted_requests", ["fake"]], ["chat_replies", [{"reply_id": "invented"}]],
		["desk_line", [Catalog.request_at(1).id]], ["arrivals", []],
	]
	for corruption: Array in corruptions:
		var bad: Dictionary = state.duplicate(true)
		bad[corruption[0]] = corruption[1]
		_check(not Simulation.validate_save(bad).ok, "Corrupt timed field %s must be rejected." % corruption[0])
	var bad: Dictionary = state.duplicate(true)
	bad.actions[0].shift_seconds = -1
	_check(not Simulation.validate_save(bad).ok, "Actions before their PR arrives must be rejected.")
	bad = state.duplicate(true)
	bad.actions[0].shift_seconds = 300
	_check(not Simulation.validate_save(bad).ok, "Reviews at the bell must be rejected.")
	bad = state.duplicate(true)
	bad.actions.pop_back()
	_check(not Simulation.validate_save(bad).ok, "Missing closure events must not recreate pay silently.")
	bad = state.duplicate(true)
	bad.actions.append(bad.actions[-1].duplicate(true))
	_check(not Simulation.validate_save(bad).ok, "A duplicated closing bell must not apply the economy twice.")
	bad = state.duplicate(true)
	bad.decisions[0].shift_seconds = 121
	_check(not Simulation.validate_save(bad).ok, "Decision times must match the semantic journal.")
	_check(not Simulation.validate_save({"version": 3}).ok, "Untimed saves require an explicit incompatibility response.")

func _test_replies() -> void:
	var state: Dictionary = Simulation.advance(Simulation.initial_state(), 17)
	var request: Dictionary = Catalog.request_at(1)
	var command: Dictionary = {"type": "chat-reply", "contact": request.author, "pr_id": request.id, "reply_id": "clarify"}
	_check(Simulation.dispatch(state, command) == state, "Chat replies must not precede their request reaching the desk.")
	state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	state = Simulation.advance(state, Simulation.DESK_BEAT)
	var before: Dictionary = state.duplicate(true)
	state = Simulation.dispatch(state, command)
	_check(state.chat_replies.size() == 1 and state.chat_replies[0].shift_seconds == 17 + Simulation.DESK_BEAT and state.chat_replies[0].reply_id == "clarify", "Accepted replies must record identity and clock time.")
	_check(state.coworkers == before.coworkers and state.trust == before.trust and state.stress == before.stress, "Authored replies must not create hidden score changes.")
	_check(Simulation.dispatch(state, command) == state, "A reply option must not be awarded or recorded twice.")
	_round_trip(state)
	var wrong: Dictionary = command.duplicate(true)
	wrong.contact = "Nobody"
	_check(Simulation.dispatch(state, wrong) == state, "Replies must belong to the request's actual author.")
	wrong = command.duplicate(true)
	wrong.reply_id = "invented"
	_check(Simulation.dispatch(state, wrong) == state, "Unknown reply options must be rejected.")

func _test_mixed_action_history() -> void:
	var state: Dictionary = Simulation.initial_state()
	var expected_replies: int = 0
	for day: int in Catalog.campaign_days():
		state = Simulation.advance(state, 7)
		var last_day: bool = day == int(Catalog.campaign_days()[-1])
		while not Simulation.active_request(state).is_empty():
			var request: Dictionary = Simulation.active_request(state)
			state = Simulation.dispatch(state, {"type": "consult-ai"})
			for reply_id: String in ["acknowledge", "clarify", "concern"]:
				state = Simulation.dispatch(state, {"type": "chat-reply", "contact": request.author, "pr_id": request.id, "reply_id": reply_id})
			expected_replies += 3
			if int(request.day) == 1 or not state.decisions.is_empty() and state.decisions.size() % 4 == 0: _round_trip(state)
			# Leave the final shift's consulted work unsigned: replay must retain
			# those consultation/reply effects without inventing review decisions.
			if last_day: break
			state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
			state = _await_desk(state)
		_round_trip(state)
		state = Simulation.advance(state, Catalog.shift_seconds() - 1 - int(state.shift_seconds))
		_check(state.phase == "review" and state.shift_seconds == Catalog.shift_seconds() - 1, "An empty or waiting desk must still leave the shift open until the bell.")
		_round_trip(state)
		state = Simulation.advance(state, 1)
		_check(state.last_debrief.timed_out == last_day, "Only unsigned work should mark the closing debrief as a timeout.")
		_check(state.last_debrief.handed_off == (Catalog.requests_for_day(day).size() if last_day else 0), "Unsigned work on the desk and in line goes to Helios.")
		_round_trip(state)
		state = Simulation.dispatch(state, {"type": "next-day", "choice": "study"})
		_round_trip(state)
	_check(state.phase == "complete" and state.chat_replies.size() == expected_replies, "The largest authored reply history must remain valid through campaign completion.")
	_check(state.log.size() <= Simulation.LOG_LIMIT, "Clock and consultation histories must preserve bounded activity logs.")
