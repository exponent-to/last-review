extends SceneTree
## The evening ledger (content/payroll.gd): the math adds up, dinner needs the
## money, debt has consequences, and the balance rewards careful work.
const Sim = preload("res://native/simulation.gd")
const Payroll = preload("res://content/payroll.gd")
const Catalog = preload("res://content/catalog.gd")
const Chat = preload("res://content/chat.gd")
const Encounters = preload("res://content/encounters.gd")
const Endings = preload("res://content/endings.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_test_ledger_math()
	_test_ledger_in_play()
	_test_dinner_gating()
	_test_debt()
	_test_garnished()
	_test_balance()
	print("Payroll: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _sum(ledger: Dictionary) -> int:
	var total := 0
	for line: Dictionary in ledger.lines: total += int(line.amount)
	return total

func _review(id: String, verdict: String, correct: bool, payload: bool = false) -> Dictionary:
	return {"id": id, "display": id, "verdict": verdict, "correct": correct, "payload": payload}

# --- The ledger adds up -----------------------------------------------------------

func _test_ledger_math() -> void:
	var idle := Payroll.ledger(60, [], 3)
	check(idle.lines[0].label == "Day rate" and int(idle.lines[0].amount) == Payroll.DAY_RATE, "The ledger opens with the day rate.")
	check(idle.lines.any(func(line: Dictionary) -> bool: return line.label == "Helios efficiency surcharge" and int(line.amount) == -Payroll.SURCHARGE), "Unfinished work costs Helios's surcharge.")
	check(idle.lines.filter(func(line: Dictionary) -> bool: return line.kind == "cost").size() == Payroll.COSTS.size(), "Rent, the lanyard lease, and coffee are fixed costs.")
	check(int(idle.end) == 60 + Payroll.DAY_RATE - Payroll.SURCHARGE - Payroll.fixed_costs(), "Signing nothing loses money.")
	check(int(idle.end) == int(idle.start) + _sum(idle) and int(idle.pay) - int(idle.expenses) == _sum(idle), "Every ledger line adds up to the ending balance.")
	var day := Payroll.ledger(40, [
		_review("PR-3001", "approve", true), _review("PR-3002", "request_changes", true), _review("PR-3003", "approve", true),
		_review("PR-3004", "approve", true), _review("PR-3007", "approve", false), _review("PR-3008 · v2", "request_changes", false),
	], 0)
	var labels: Array = day.lines.map(func(line: Dictionary) -> String: return "%s %d" % [line.label, int(line.amount)])
	check(("Reviews signed ×6 %d" % (6 * Payroll.PER_REVIEW)) in labels, "Every signed review is paid: " + str(labels))
	check(("Shipped defect (PR-3007) %d" % -Payroll.SHIPPED_DEFECT) in labels, "A shipped defect is docked by name.")
	check(("Unfounded change request (PR-3008 · v2) %d" % -Payroll.WRONG_REJECTION) in labels, "A wrong change request is docked by name, revisions included.")
	check(not labels.any(func(text: String) -> bool: return text.begins_with("Helios efficiency")), "A cleared desk owes Helios nothing.")
	check(int(day.end) == 40 + Payroll.DAY_RATE + 6 * Payroll.PER_REVIEW - Payroll.SHIPPED_DEFECT - Payroll.WRONG_REJECTION - Payroll.fixed_costs() and int(day.end) == 40 + _sum(day), "Pay, docks, and costs add up.")
	# Letting a payload through is not a shipped defect; Helios says thank you.
	var bribed := Payroll.ledger(0, [_review("PR-P4", "approve", false, true), _review("PR-P5", "request_changes", true, true)], 2)
	check(bribed.lines.any(func(line: Dictionary) -> bool: return line.label == "Helios referral bonus (PR-P4)" and int(line.amount) == Payroll.HELIOS_BONUS), "Helios pays for its payloads.")
	check(not bribed.lines.any(func(line: Dictionary) -> bool: return str(line.label).begins_with("Shipped") or str(line.label).begins_with("Unfounded")), "Payload calls are never docked.")
	# Many docks collapse into one line so the slip stays short.
	var sloppy := Payroll.ledger(10, [_review("A", "approve", false), _review("B", "approve", false), _review("C", "approve", false)], 1)
	check(sloppy.lines.any(func(line: Dictionary) -> bool: return line.label == "Shipped defect ×3" and int(line.amount) == -3 * Payroll.SHIPPED_DEFECT), "Three or more docks of a kind share a line.")
	# A day that starts in the red pays the overdraft fee.
	var red := Payroll.ledger(-5, [], 1)
	check(red.lines.any(func(line: Dictionary) -> bool: return line.label == "Overdraft fee" and int(line.amount) == -Payroll.OVERDRAFT), "Starting in the red costs an overdraft fee.")
	check(not Payroll.ledger(0, [], 1).lines.any(func(line: Dictionary) -> bool: return line.label == "Overdraft fee"), "Zero is not in the red.")
	check(Payroll.signed(20) == "+20" and Payroll.signed(-5) == "−5" and Payroll.balance_text(-20) == "−20 CR" and Payroll.balance_text(65) == "65 CR", "Amounts read like a payslip.")

# --- The simulation keeps the ledger ------------------------------------------------

## Sign the first `count` PRs that reach the desk, rightly (or wrongly where
## `wrong` says so), then let the bell take the rest.
func _work(state: Dictionary, count: int, wrong: Callable = Callable()) -> Dictionary:
	var signed := 0
	while state.phase == "review":
		if not Encounters.pending(state).is_empty():
			state = Sim.dispatch(state, {"type": "pushback", "choice": "insist"})
			signed += 1
			continue
		var desk: Dictionary = Sim.active_request(state)
		if desk.is_empty() or signed >= count:
			var coming: bool = signed < count and int(state.desk_at) >= 0 and int(state.desk_at) < Catalog.shift_seconds()
			state = Sim.advance(state, int(state.desk_at) - int(state.shift_seconds) if coming else Catalog.shift_seconds())
			continue
		var packet: Dictionary = Catalog.packet(state, str(desk.id))
		var broken: bool = not packet.violations.is_empty()
		if wrong.is_valid() and wrong.call(signed) and not bool(packet.get("payload", false)):
			# The wrong call: wave a broken PR through, or send a clean one back for ink.
			if not broken:
				state = Sim.dispatch(state, {"type": "toggle-rule", "rule_id": "P02", "path": str(packet.files[0].path), "line": 1})
			state = Sim.dispatch(state, {"type": "review", "verdict": "approve" if broken else "request_changes"})
		else:
			for rule_id: String in packet.violations: state = Sim.dispatch(state, Catalog.audit_citation(packet, rule_id))
			state = Sim.dispatch(state, {"type": "review", "verdict": "request_changes" if broken else "approve"})
		if Encounters.pending(state).is_empty(): signed += 1
	return state

func _test_ledger_in_play() -> void:
	var closed := _work(Sim.initial_state(), 4)
	var ledger: Dictionary = closed.last_debrief.ledger
	check(int(ledger.start) == Payroll.START and int(ledger.end) == int(closed.credits) and int(ledger.end) == int(ledger.start) + _sum(ledger), "The day's ledger runs from the starting balance to the balance now.")
	check(int(closed.shift_history[-1].balance) == int(closed.credits), "The closing balance is on the record.")
	check(int(closed.last_debrief.pay) - int(closed.last_debrief.expenses) == _sum(ledger), "Pay and expenses are the ledger's totals.")
	check(ledger.lines.any(func(line: Dictionary) -> bool: return str(line.label).begins_with("Reviews signed ×")), "Signed reviews are paid.")
	var raw := Sim.serialize_save(closed)
	var loaded := Sim.validate_save(JSON.parse_string(raw))
	check(loaded.ok and loaded.state == closed, "Replay rebuilds the same ledger.")
	var forged: Dictionary = closed.duplicate(true)
	forged.last_debrief.ledger.lines[0].amount = 999
	check(not Sim.validate_save(forged).ok, "A save can't forge its payslip.")
	forged = closed.duplicate(true)
	forged.credits = int(closed.credits) + 100
	check(not Sim.validate_save(forged).ok, "A save can't forge its balance.")
	var evening := Chat.evening(closed)
	check(evening.closing.any(func(text: String) -> bool: return text.contains("earned") and text.contains("tonight")), "The first evening, Morgan says why the panel opens.")

# --- Dinner needs the money ---------------------------------------------------------

func _test_dinner_gating() -> void:
	var state := Sim.initial_state()
	while not (state.phase == "debrief" and not Payroll.can_dine(int(state.credits))):
		state = Sim.advance(state, Catalog.shift_seconds())
		if state.phase == "debrief" and Payroll.can_dine(int(state.credits)):
			state = Sim.dispatch(state, {"type": "next-day", "choice": "rest"})
	check(int(state.credits) < Payroll.DINNER, "Idling runs the balance below the price of dinner.")
	check(Sim.dispatch(state, {"type": "next-day", "choice": "socialize"}) == state, "No dinner the balance can't cover.")
	var forged: Dictionary = state.duplicate(true)
	forged.actions.append({"type": "next-day", "day": state.day, "shift_seconds": state.shift_seconds, "choice": "socialize"})
	check(not Sim.validate_save(forged).ok, "A save can't replay a dinner nobody paid for.")
	var home := Sim.dispatch(state, {"type": "next-day", "choice": "rest"})
	check(int(home.day) == int(state.day) + 1, "Going home is always free.")
	var studied := Sim.dispatch(state, {"type": "next-day", "choice": "study"})
	check(int(studied.day) == int(state.day) + 1 and int(studied.credits) == int(state.credits), "Studying is free.")
	# With the money, dinner costs exactly its price.
	var paid := _work(Sim.initial_state(), 4)
	check(Payroll.can_dine(int(paid.credits)), "A careful first day pays for dinner.")
	var dined := Sim.dispatch(paid, {"type": "next-day", "choice": "socialize"})
	check(int(dined.credits) == int(paid.credits) - Payroll.DINNER and dined.shift_history[-1].evening_choice == "socialize", "Dinner costs its price, once.")

# --- Debt has consequences ------------------------------------------------------------

func _test_debt() -> void:
	var state := Sim.initial_state()
	var first_red := -1
	while state.phase != "complete":
		var stress_before := int(state.stress)
		state = Sim.advance(state, Catalog.shift_seconds())
		if state.phase != "debrief": break
		var streak := Payroll.debt_days(state)
		var notes: String = " ".join(Chat.evening(state).notes)
		if int(state.credits) < 0 and first_red < 0: first_red = int(state.day)
		check(streak == int(state.last_debrief.debt_days), "The debrief records the closings in the red.")
		if streak == 1:
			check(notes.contains("in the red") and int(state.stress) == stress_before, "A first closing in the red is a warning, not stress (day %d)." % int(state.day))
		if streak >= Payroll.DEBT_DAYS:
			check(int(state.stress) == mini(100, stress_before + Payroll.DEBT_STRESS), "Two closings in the red: collections adds stress (day %d)." % int(state.day))
			check(notes.contains("Collections") or notes.contains("Second night"), "Morgan warns about the debt (day %d)." % int(state.day))
		state = Sim.dispatch(state, {"type": "next-day", "choice": "rest"})
	check(first_red > 0, "An idle run ends up in the red.")
	check(state.ending != "garnished", "Idling alone is never garnished; it just never gets ahead.")

# --- Garnished ------------------------------------------------------------------------

func _test_garnished() -> void:
	check(Endings.has("garnished") and Endings.title("garnished") == "Garnished" and Endings.beats("garnished").size() >= 3, "Garnished is an ending with a title, Morgan's words, and beats.")
	check(Payroll.garnished(Payroll.GARNISH_AT) and not Payroll.garnished(Payroll.GARNISH_AT + 1), "Garnishment starts at its threshold.")
	# A balance already deep in the red: one more idle day crosses the line.
	var deep := Sim.initial_state()
	deep.credits = Payroll.GARNISH_AT + 10
	var closed := Sim.advance(deep, Catalog.shift_seconds())
	check(closed.phase == "complete" and closed.ending == "garnished", "Sinking past the threshold ends the run, garnished.")
	check(Sim.dispatch(closed, {"type": "next-day", "choice": "rest"}) == closed, "There is no evening after a garnishment.")

# --- Balance --------------------------------------------------------------------------

## Play a whole run signing `count` PRs a day. Dinner whenever the balance covers it.
func _run(count: int, wrong: Callable = Callable()) -> Dictionary:
	var state := Sim.initial_state()
	var lowest := int(state.credits)
	var dinners := 0
	var red_days := 0
	while state.phase != "complete":
		state = _work(state, count, wrong)
		lowest = mini(lowest, int(state.credits))
		if int(state.credits) < 0: red_days += 1
		if state.phase != "debrief": break
		var dine := Payroll.can_dine(int(state.credits))
		if dine: dinners += 1
		state = Sim.dispatch(state, {"type": "next-day", "choice": "socialize" if dine else "rest"})
	return {"state": state, "lowest": lowest, "dinners": dinners, "red_days": red_days}

func _test_balance() -> void:
	for count: int in [3, 4]:
		var careful := _run(count)
		check(int(careful.lowest) >= 0 and int(careful.red_days) == 0, "A careful reviewer signing %d a day never goes into the red (lowest %d)." % [count, int(careful.lowest)])
		check(int(careful.dinners) >= count - 1, "A careful reviewer signing %d a day can afford dinner a few times (%d)." % [count, int(careful.dinners)])
		check(careful.state.ending != "garnished" and careful.state.ending != "player_fired", "A careful run reaches the last Friday.")
	# Sloppy: every third call wrong. The money runs out, and dinner with it.
	var sloppy := _run(6, func(signed: int) -> bool: return signed % 3 == 2)
	var careful := _run(4)
	print("Balance: careful ×4 ends %d with %d dinners; sloppy ×6 ends %d (lowest %d, %d days in the red, %d dinners, %s)." % [
		int(careful.state.credits), int(careful.dinners), int(sloppy.state.credits), int(sloppy.lowest), int(sloppy.red_days), int(sloppy.dinners), str(sloppy.state.get("ending", ""))])
	check(int(sloppy.lowest) < 0, "A sloppy reviewer goes into the red (lowest %d)." % int(sloppy.lowest))
	check(int(sloppy.dinners) < int(careful.dinners), "A sloppy reviewer eats out less (%d vs %d)." % [int(sloppy.dinners), int(careful.dinners)])
