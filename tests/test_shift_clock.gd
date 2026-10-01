extends SceneTree

const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Chat = preload("res://content/chat.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_test_clock()
	_test_arrivals_and_selection()
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

func _select(state: Dictionary, request_id: String) -> Dictionary:
	return Simulation.dispatch(state, {"type": "select-request", "pr_id": request_id})

func _test_clock() -> void:
	var initial: Dictionary = Simulation.initial_state()
	_check(Simulation.Catalog.shift_seconds() == 300 and Simulation.clock_minutes(initial) == 540, "A five-minute shift must start at 09:00.")
	_check(Simulation.clock_minutes(Simulation.advance(initial, 150)) == 810, "Half a shift must show 13:30.")
	var end: Dictionary = Simulation.advance(initial, 300)
	_check(Simulation.clock_minutes(end) == 1080 and end.phase == "debrief", "The closing bell must be 18:00.")
	_check(initial.shift_seconds == 0 and initial.actions.is_empty(), "Advancing time must deeply preserve its input.")
	_check(Simulation.advance(initial, 0) == initial and Simulation.advance(initial, -1) == initial, "Paused and invalid negative deltas must be no-ops.")
	var stepped: Dictionary = initial
	for _second in range(300):
		stepped = Simulation.advance(stepped)
	_check(stepped == end, "Single-second and batched clocks must produce identical closure.")
	_check(Simulation.advance(end, 99999) == end, "Debrief must not accrue more time, pay, or handoffs.")
	_round_trip(end)

func _test_arrivals_and_selection() -> void:
	var state: Dictionary = Simulation.initial_state()
	var first: Dictionary = Catalog.request_at(0)
	_check(Simulation.available_requests(state).size() == 1 and Simulation.active_request(state).is_empty(), "First arrival is pending until selected.")
	_check(_select(state, Catalog.request_at(1).id) == state, "Unarrived PR links cannot select work.")
	_check(Simulation.dispatch(state, {"type": "review", "verdict": "approve"}) == state, "Unselected work cannot be signed.")
	state = Simulation.advance(state, 20)
	_check(Simulation.available_requests(state).size() == 2 and Simulation.active_request(state).is_empty(), "An arrival must enter the inbox without opening the editor.")
	state = _select(state, first.id)
	_check(Simulation.active_request(state).id == first.id, "The player must explicitly choose the arrived request.")
	_check(not Simulation.active_request(state).has("violations") and not Simulation.active_request(state).has("explanation") and not Simulation.active_request(state).has("ai_note"), "Public request helpers must hide audit answers and unrequested advice.")
	state = Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": "P01"})
	_check(_select(state, first.id) == state, "A repeated chat link must preserve selected citations.")
	state = Simulation.dispatch(state, {"type": "consult-ai"})
	_check(not Simulation.active_request(state).has("ai_note"), "Advice remains locked until Wednesday.")
	_round_trip(state)
	state = Simulation.advance(state, 260)
	var later: Dictionary = Catalog.request_at(2)
	state = _select(state, later.id)
	_check(state.selected_rules.is_empty() and not state.consulted, "Switching PRs clears citations and restores that PR's consultation status.")
	state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	_check(state.decisions[0].pr_id == later.id and state.request_index == 0, "Reviewing a later arrived PR must leave earlier work pending.")
	_round_trip(state)
	state = _select(state, first.id)
	_check(not state.consulted, "Locked consultations remain unavailable after switching.")
	_check(Simulation.dispatch(state, {"type": "consult-ai"}) == state, "Switching away cannot purchase duplicate consultation effects.")
	state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	_check(state.decisions.size() == 2 and state.request_index == 1, "Pending pointer must skip already completed out-of-order work.")
	_check(_select(state, later.id) == state, "Already reviewed PRs cannot be selected again.")
	_round_trip(state)

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
			_check(state.shift_seconds == 0 and Simulation.active_request(state).is_empty(), "A new day resets the clock and leaves the editor unselected.")
		_round_trip(state)
	_check(state.phase == "complete" and state.credits == 70 and state.chat_replies.is_empty(), "An entirely missed campaign must finish safely without imaginary interaction.")
	_check(Simulation.advance(state, 300) == state, "Complete careers cannot run another shift.")

func _test_save_replay() -> void:
	var state: Dictionary = Simulation.advance(Simulation.initial_state(), 50)
	state = _select(state, Catalog.request_at(0).id)
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
	var state: Dictionary = Simulation.initial_state()
	var request: Dictionary = Catalog.request_at(1)
	var command: Dictionary = {"type": "chat-reply", "contact": request.author, "pr_id": request.id, "reply_id": "clarify"}
	_check(Simulation.dispatch(state, command) == state, "Chat replies must not precede their request's arrival.")
	state = Simulation.advance(state, 20)
	var before: Dictionary = state.duplicate(true)
	state = Simulation.dispatch(state, command)
	_check(state.chat_replies.size() == 1 and state.chat_replies[0].shift_seconds == 20 and state.chat_replies[0].reply_id == "clarify", "Accepted replies must record identity and clock time.")
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
	for day: int in Catalog.campaign_days():
		state = Simulation.advance(state, 280)
		var pending: Array = Simulation.available_requests(state)
		pending.reverse()
		for request: Dictionary in pending:
			state = _select(state, request.id)
			state = Simulation.dispatch(state, {"type": "consult-ai"})
			for reply_id: String in ["acknowledge", "clarify", "concern"]:
				state = Simulation.dispatch(state, {"type": "chat-reply", "contact": request.author, "pr_id": request.id, "reply_id": reply_id})
			_round_trip(state)
			# Leave the final shift's consulted work unsigned: replay must retain
			# those consultation/reply effects without inventing review decisions.
			if day != int(Catalog.campaign_days()[-1]):
				state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
				_round_trip(state)
		state = Simulation.advance(state, 19)
		_check(state.phase == "review" and state.shift_seconds == 299, "An empty or waiting inbox must still leave the shift open until the bell.")
		_round_trip(state)
		state = Simulation.advance(state, 1)
		_check(state.last_debrief.timed_out == (day == int(Catalog.campaign_days()[-1])), "Only unsigned work should mark the closing debrief as a timeout.")
		_round_trip(state)
		state = Simulation.dispatch(state, {"type": "next-day", "choice": "study"})
		_round_trip(state)
	_check(state.phase == "complete" and state.chat_replies.size() == Catalog.requests().size() * 3, "The largest authored reply history must remain valid through campaign completion.")
	_check(state.log.size() <= Simulation.LOG_LIMIT, "Clock and consultation histories must preserve bounded activity logs.")
