extends SceneTree
## The line outside the booth: PRs join a waiting line on the shift clock, the desk
## pulls from its front, REVIEW shows who is waiting and for how long, the line
## gets restless, and at 18:00 Helios takes whatever is still waiting. All of it
## deterministic, so saves replay it exactly.
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Encounters = preload("res://content/encounters.gd")
const Interface = preload("res://native/interface.gd")
const WaitingLine = preload("res://native/waiting_line.gd")
const LinePressure = preload("res://content/line_pressure.gd")
const Chat = preload("res://content/chat.gd")

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_test_schedule()
	_test_arrivals_on_the_clock()
	_test_fifo()
	_test_helios_takes_the_line()
	_test_pace()
	_test_determinism()
	_test_pressure()
	await _test_render()
	print("Queue checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

func _desk(state: Dictionary) -> String:
	return str(Simulation.active_request(state).get("id", ""))

func _land(state: Dictionary) -> Dictionary:
	var at := Simulation.next_landing(state)
	if not _desk(state).is_empty() or at < 0: return state
	return Simulation.advance(state, at - int(state.shift_seconds))

func _exact(state: Dictionary) -> Dictionary:
	var packet: Dictionary = Catalog.packet(state, state.active_request_id)
	if bool(packet.get("payload", false)): return Simulation.dispatch(state, {"type": "review", "verdict": "request_changes"})
	for rule_id: String in packet.violations: state = Simulation.dispatch(state, Catalog.audit_citation(packet, rule_id))
	state = Simulation.dispatch(state, {"type": "review", "verdict": "approve" if packet.violations.is_empty() else "request_changes"})
	if not Encounters.pending(state).is_empty(): state = Simulation.dispatch(state, {"type": "pushback", "choice": "insist"})
	return state

# --- The schedule -----------------------------------------------------------------

func _test_schedule() -> void:
	for day: int in Catalog.campaign_days():
		var times: Array = Simulation.arrival_schedule(15, day)
		check(times.size() == 15 and times.slice(0, Simulation.OPENING_LINE).all(func(t: int) -> bool: return t == 0), "Day %d opens with %d PRs already in line." % [day, Simulation.OPENING_LINE])
		check(int(times[-1]) == Simulation.LAST_ARRIVAL - Simulation.LAST_ARRIVAL_STEP * (day - 1) and int(times[-1]) < Catalog.shift_seconds(), "Day %d's last PR joins before the bell, sooner each day." % day)
		var gaps: Array = []
		for index in range(Simulation.OPENING_LINE, times.size()):
			gaps.append(int(times[index]) - int(times[index - 1]))
		# Whole seconds round each gap down, so allow a second of jitter.
		var closing := true
		for index in range(1, gaps.size()):
			if int(gaps[index]) > int(gaps[index - 1]) + 1: closing = false
		check(gaps.all(func(gap: int) -> bool: return gap > 0) and closing and int(gaps[0]) * 2 >= int(gaps[-1]) * 3, "Day %d's arrivals come ever closer together: %s." % [day, str(gaps)])
		check(Simulation.arrival_schedule(15, day) == times, "The schedule is a pure function of the line and the day.")
	var first: Array = Simulation.arrival_schedule(15, 1)
	var last: Array = Simulation.arrival_schedule(15, int(Catalog.campaign_days()[-1]))
	check(int(first[9]) > int(last[9]), "Later days bring the line sooner (%d vs %d for the tenth PR)." % [int(first[9]), int(last[9])])
	check(Simulation.arrival_schedule(1, 1) == [0] and Simulation.arrival_schedule(0, 1).is_empty(), "Short lines are all already waiting.")

func _test_arrivals_on_the_clock() -> void:
	var state := Simulation.initial_state()
	var line: Array = Catalog.requests_for_day(1).map(func(packet: Dictionary) -> String: return packet.id)
	var times: Array = Simulation.arrival_schedule(line.size(), 1)
	check(_desk(state) == line[0] and state.desk_line == line.slice(1, Simulation.OPENING_LINE), "At 09:00 the first PR is on the desk and the next waits in line.")
	check(state.incoming.size() == line.size() - Simulation.OPENING_LINE and Simulation.waiting_count(state) == Simulation.OPENING_LINE - 1, "The rest of the day is still on its way.")
	# Nobody stamps anything; the line grows anyway, one PR at each scheduled second.
	var idle := state
	for index in range(Simulation.OPENING_LINE, line.size()):
		var due: int = int(times[index])
		var before := Simulation.advance(idle, due - 1 - int(idle.shift_seconds)) if due - 1 > int(idle.shift_seconds) else idle
		check(str(line[index]) not in before.desk_line, "%s is not in line before its second." % line[index])
		idle = Simulation.advance(before, due - int(before.shift_seconds))
		check(idle.desk_line[-1] == line[index] and int(idle.queued_at[line[index]]) == due, "%s joins the back of the line at %d." % [line[index], due])
	check(_desk(idle) == line[0] and Simulation.waiting_count(idle) == line.size() - 1, "An idle desk ends the afternoon with the whole day waiting.")
	# Batched and stepped clocks agree.
	var stepped := state
	for second in range(150): stepped = Simulation.advance(stepped, 1)
	check(stepped == Simulation.advance(state, 150) and stepped == Simulation.advance(Simulation.advance(state, 77), 73), "Batched and stepped clocks build the same line.")
	# The ages the strip shows.
	var at_noon := Simulation.advance(state, 60)
	var waiting: Array = Simulation.waiting(at_noon)
	check(waiting.size() == Simulation.waiting_count(at_noon) and waiting[0].id == line[1] and int(waiting[0].age) == 60 and int(waiting[-1].age) == 60 - int(at_noon.queued_at[waiting[-1].id]), "Each waiting PR carries how long it has waited.")
	for entry: Dictionary in waiting:
		check(entry.keys() == ["id", "author", "revision", "since", "age"], "The line tells who and how long, nothing about contents: " + str(entry.keys()))
	check(Simulation.waiting(Simulation.advance(state, Catalog.shift_seconds())).is_empty(), "After the bell nobody is waiting.")
	# Payloads stay at the front of their day's line, already waiting at 09:00.
	var story := Simulation.initial_state()
	var seen_payload := false
	while story.phase != "complete":
		var payloads: Array = Catalog.requests_for_day(int(story.day)).filter(func(packet: Dictionary) -> bool: return bool(packet.get("payload", false)))
		if not payloads.is_empty():
			seen_payload = true
			var front: Array = [_desk(story)] + story.desk_line
			check(front.slice(0, payloads.size()) == payloads.map(func(packet: Dictionary) -> String: return packet.id) and story.desk_line.size() == payloads.size() + Simulation.OPENING_LINE - 1, "Day %d's payloads are first in line at 09:00." % int(story.day))
		story = Simulation.dispatch(Simulation.advance(story, Catalog.shift_seconds()), {"type": "next-day", "choice": "rest"})
	check(seen_payload, "The run has payload days.")

# --- First come, first served -----------------------------------------------------

func _test_fifo() -> void:
	var state := Simulation.advance(Simulation.initial_state(), 70)
	var front: String = str(state.desk_line[0])
	var second: String = str(state.desk_line[1])
	state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	check(_desk(state).is_empty() and state.desk_line[0] == front, "A stamp clears the desk; the front of the line waits a beat.")
	state = Simulation.advance(state, Simulation.DESK_BEAT)
	check(_desk(state) == front and state.desk_line[0] == second and not state.queued_at.has(front), "Then the front of the line lands on the desk, and the next steps up.")
	check(int(state.arrivals[-1].shift_seconds) == 70 + Simulation.DESK_BEAT, "It lands one beat after the stamp.")
	# A request for a PR further back is not a command; nothing jumps the line.
	var asked := Simulation.dispatch(state, {"type": "pull", "pr_id": state.desk_line[-1]})
	check(asked == state, "There is no command to call a PR up out of turn.")
	# An empty line: the desk waits for the next arrival, which lands the moment it joins.
	var clear := Simulation.initial_state()
	clear = _land(Simulation.dispatch(clear, {"type": "review", "verdict": "approve"}))
	clear = Simulation.dispatch(clear, {"type": "review", "verdict": "approve"})
	check(clear.desk_line.is_empty() and Simulation.next_landing(clear) == int(clear.incoming[0].at), "With nobody waiting, the next PR lands as soon as it arrives.")
	clear = _land(clear)
	check(_desk(clear) == str(Catalog.requests_for_day(1)[Simulation.OPENING_LINE].id) and int(clear.arrivals[-1].shift_seconds) == int(Simulation.arrival_schedule(15, 1)[Simulation.OPENING_LINE]), "It goes straight to the desk.")
	# A revision rejoins near the front of the line, joining the line when it was sent back.
	var busy := Simulation.advance(Simulation.initial_state(), 70)
	busy = _exact(busy)
	var revision: String = str(busy.revisions[-1].id) if not busy.revisions.is_empty() else ""
	check(not revision.is_empty() and busy.desk_line.find(revision) == Simulation.REVISION_GAP and int(busy.queued_at[revision]) == 70, "A revision rejoins the line behind the next two, waiting from the moment it was sent back.")

# --- Closing --------------------------------------------------------------------

func _test_helios_takes_the_line() -> void:
	var state := Simulation.advance(Simulation.initial_state(), 100)
	state = _exact(state)
	var waiting: int = state.desk_line.size()
	var coming: int = state.incoming.size()
	var on_desk: int = 0 if _desk(state).is_empty() else 1
	var closed := Simulation.advance(state, Catalog.shift_seconds())
	check(closed.phase == "debrief" and int(closed.last_debrief.handed_off) == waiting + coming + on_desk and waiting > 3, "At 18:00 Helios takes the desk and everyone waiting (%d)." % int(closed.last_debrief.handed_off))
	check(closed.desk_line.is_empty() and closed.incoming.is_empty() and closed.queued_at.is_empty(), "The line is gone after the bell.")
	check(int(closed.shift_history[-1].handed_off) == int(closed.last_debrief.handed_off), "The day's record keeps how many Helios took.")
	var notes: String = " ".join(Chat.evening(closed).notes)
	check(notes.contains("Helios picked up the %d PRs still waiting" % int(closed.last_debrief.handed_off)), "Morgan says how many Helios took: " + notes)
	check(closed.last_debrief.ledger.lines.any(func(line: Dictionary) -> bool: return str(line.label).begins_with("Helios efficiency")), "Payroll takes Helios's surcharge for the handoff.")
	# The next morning starts a fresh line.
	var morning := Simulation.dispatch(closed, {"type": "next-day", "choice": "rest"})
	check(morning.desk_line.size() >= Simulation.OPENING_LINE - 1 and int(morning.arrivals[-1].day) == int(morning.day) and int(morning.arrivals[-1].shift_seconds) == 0, "The next morning opens its own line.")
	check(morning.queued_at.keys().all(func(id: String) -> bool: return int(morning.queued_at[id]) == 0), "Nobody carries over from yesterday's line.")

## A careful reviewer at a human pace: the line grows to a handful by mid-afternoon,
## and the run is still survivable.
func _test_pace() -> void:
	var state := Simulation.initial_state()
	var mid: Array = []
	while state.phase != "complete":
		if state.phase == "debrief":
			state = Simulation.dispatch(state, {"type": "next-day", "choice": "rest"}); continue
		var at_three := -1
		while state.phase == "review":
			if at_three < 0 and int(state.shift_seconds) >= 120: at_three = Simulation.waiting_count(state)
			if not Encounters.pending(state).is_empty():
				state = Simulation.dispatch(state, {"type": "pushback", "choice": "insist"}); continue
			if _desk(state).is_empty():
				var landing := Simulation.next_landing(state)
				state = Simulation.advance(state, landing - int(state.shift_seconds) if landing >= 0 else Catalog.shift_seconds()); continue
			state = Simulation.advance(state, 22)
			if state.phase != "review" or _desk(state).is_empty(): continue
			state = _exact(state)
		mid.append(at_three)
	print("Line at 15:00 for a careful reviewer signing one every 25 s: %s" % str(mid))
	check(mid.size() == Catalog.campaign_days().size(), "Every day of the run was played.")
	check(mid.all(func(count: int) -> bool: return count >= 5 and count <= 12), "By mid-afternoon the line is a handful to a dozen deep: %s." % str(mid))
	check(int(mid[-1]) > int(mid[0]), "The line is longer late in the fortnight than on the first day.")
	check(state.ending not in ["player_fired", "garnished"] and int(state.credits) > 0, "A careful reviewer at a human pace survives the fortnight (%s, %d CR)." % [state.ending, int(state.credits)])

# --- Determinism ------------------------------------------------------------------

func _test_determinism() -> void:
	var a := Simulation.advance(Simulation.initial_state(), 90)
	var b := Simulation.advance(Simulation.initial_state(), 90)
	check(a == b, "The same clock builds the same line.")
	var played := _exact(_land(_exact(a)))
	played = Simulation.advance(played, 11)
	var raw := Simulation.serialize_save(played)
	var loaded := Simulation.validate_save(JSON.parse_string(raw))
	check(loaded.ok and loaded.state == played, "Replaying the journal rebuilds the line, its ages, and what is still coming.")
	check(Simulation.SAVE_VERSION >= 19, "The waiting line bumped the save format.")
	var forged: Dictionary = played.duplicate(true)
	forged.incoming = []
	check(not Simulation.validate_save(forged).ok, "A save can't skip the rest of the day's arrivals.")
	forged = played.duplicate(true)
	forged.queued_at[str(forged.desk_line[0])] = int(played.shift_seconds)
	check(not Simulation.validate_save(forged).ok, "A save can't reset how long someone has waited.")
	forged = played.duplicate(true)
	forged.desk_line.push_front(forged.desk_line.pop_back())
	check(not Simulation.validate_save(forged).ok, "A save can't reorder the line.")
	# Across a whole day and into the next: replay agrees.
	var day := Simulation.dispatch(Simulation.advance(played, Catalog.shift_seconds()), {"type": "next-day", "choice": "study"})
	day = Simulation.advance(_exact(day), 30)
	var replay := Simulation.validate_save(JSON.parse_string(Simulation.serialize_save(day)))
	check(replay.ok and replay.state == day, "A second day's line replays exactly.")

# --- Pressure ----------------------------------------------------------------------

func _entry(id: String, author: String, age: int) -> Dictionary:
	return {"id": id, "author": author, "revision": 1, "since": 0, "age": age}

func _test_pressure() -> void:
	var memory := LinePressure.empty_memory()
	check(LinePressure.next([_entry("PR-3001", "Theo", 10)], 3, 20, memory).is_empty(), "A short, fresh line says nothing.")
	var old := [_entry("PR-3001", "Theo", 45), _entry("PR-3002", "June", 41)]
	var ping := LinePressure.next(old, 3, 60, memory)
	check(ping.person == "Theo" and str(ping.text).begins_with("Theo: ") and str(ping.text).contains("PR-3001") and ping.target == "PR-3001", "The longest-waiting author pings about their own PR: " + str(ping))
	check(LinePressure.next(old, 3, 61, memory).is_empty(), "Pings are rate-limited.")
	var second := LinePressure.next(old, 3, 60 + LinePressure.PING_GAP, memory)
	check(second.person == "June" and str(second.text).contains("PR-3002"), "Another author can ping after the gap.")
	check(LinePressure.next(old, 3, 200, memory).is_empty(), "Each PR pings once.")
	var crowd: Array = []
	for index in range(8): crowd.append(_entry("PR-30%02d" % (index + 10), "Maya", 5))
	var fresh := LinePressure.empty_memory()
	var nine := LinePressure.next(crowd + [_entry("PR-3099", "Theo", 1)], 4, 50, LinePressure.empty_memory())
	check(str(nine.text).begins_with("Morgan: Nine in your line"), "The nudge says how many are really waiting: " + str(nine.text))
	var nudge := LinePressure.next(crowd, 4, 50, fresh)
	check(nudge.person == "Morgan" and str(nudge.text).begins_with("Morgan: Eight in your line"), "Eight waiting brings a word from Morgan (only the latest threshold): " + str(nudge))
	check(LinePressure.next(crowd, 4, 50 + LinePressure.PING_GAP, fresh).is_empty(), "Each nudge comes once a day.")
	var five := LinePressure.next(crowd.slice(0, 5), 5, 10, fresh)
	check(five.person == "Helios" and str(five.text) == "Helios: Five reviews are waiting on you. I can clear your backlog. Just say the word.", "A new day resets the nudges; five waiting brings Helios's offer.")
	# Nothing the line says depends on what is in a PR, or speaks outside the office.
	var all_text: Array = []
	for nudge_entry: Dictionary in LinePressure.NUDGES: all_text.append(str(nudge_entry.text))
	for author: String in LinePressure.IMPATIENT:
		for line: String in LinePressure.IMPATIENT[author]: all_text.append(line)
	for text: String in all_text:
		for banned: String in ["broken", "clean", "violation", "audit", "correct", "player", "game", "level", "score", "P0", "P1"]:
			check(not text.to_lower().contains(banned.to_lower()), "The line never hints at contents or breaks the fiction: %s (%s)" % [text, banned])
	var source: String = FileAccess.get_file_as_string("res://content/line_pressure.gd")
	check(not source.contains("violations") and not source.contains("findings"), "Line pressure never reads audit data.")
	var waiting_source: String = FileAccess.get_file_as_string("res://native/waiting_line.gd")
	check(not waiting_source.contains("violations") and not waiting_source.contains("findings"), "The waiting strip never reads audit data.")

# --- REVIEW shows the line ------------------------------------------------------------

func _test_render() -> void:
	root.size = Vector2i(1280, 900)
	var ui: Control = Interface.new()
	root.add_child(ui)
	for frame in range(3): await process_frame
	var state := Simulation.initial_state()
	ui.render_state(state)
	var strip: WaitingLine = ui._line
	check(strip.visible and strip._ages.size() == Simulation.waiting_count(state), "At 09:00 the strip shows who is already waiting.")
	state = Simulation.advance(state, 100)
	ui.render_state(state)
	var waiting: Array = Simulation.waiting(state)
	check(waiting.size() > WaitingLine.SHOWN, "By mid-afternoon more are waiting than the strip has faces for (%d)." % waiting.size())
	check(strip._heading.text == "IN LINE · %d" % waiting.size(), "The strip counts everyone in line: " + strip._heading.text)
	check(strip._ages.size() == WaitingLine.SHOWN and strip._more.visible and strip._more.text == "+%d" % (waiting.size() - WaitingLine.SHOWN), "Five faces, then +N for the rest.")
	var faces: Array = strip._row.get_children().filter(func(node: Node) -> bool: return node is VBoxContainer)
	check(faces.size() == WaitingLine.SHOWN and str(faces[0].get_child(0).get_meta("person", "")) == str(waiting[0].author).to_lower(), "The front of the line comes first, with its author's face.")
	check(str(faces[0].get_child(0).tooltip_text).contains(Catalog.display_id(str(waiting[0].id))) and strip._ages[0].text == WaitingLine.age_text(int(waiting[0].age)), "Each face names its PR and how long it has waited.")
	check(WaitingLine.age_text(4) == "12m" and WaitingLine.age_text(25) == "1h15" and WaitingLine.age_color(5) == WaitingLine.DIM and WaitingLine.age_color(WaitingLine.AMBER_AFTER) == WaitingLine.AMBER and WaitingLine.age_color(WaitingLine.RED_AFTER) == WaitingLine.RED, "Ages read on the office clock and turn amber, then red.")
	check(strip._ages[0].get_theme_color("font_color") == WaitingLine.RED, "The PR waiting since 09:00 has gone red by mid-afternoon.")
	check(int(ui._app_counts.review) == Simulation.waiting_count(state) + (1 if not ui._unread_requests.is_empty() else 0) and ui._dock_buttons.review.text.contains("(%d)" % int(ui._app_counts.review)), "REVIEW's badge and dock count the line: " + ui._dock_buttons.review.text)
	# Hovering, or clicking, a face calls nobody up.
	var before: Dictionary = state.duplicate(true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	faces[2].get_child(0).gui_input.emit(click)
	check(state == before and str(Simulation.active_request(state).get("id", "")) == str(before.active_request_id), "Clicking a waiting PR does not jump the line.")
	# The line pinged about the oldest PR, once.
	var pings: Array = ui._notifications._items.filter(func(item: Dictionary) -> bool:
		return item.app == "review" and (str(item.card.tooltip_text).begins_with("Helios:") or str(item.card.tooltip_text).begins_with("Morgan:")))
	check(pings.size() == 1, "A long line makes itself heard on the desktop, once.")
	ui.render_state(state)
	check(ui._notifications._items.filter(func(item: Dictionary) -> bool: return item.app == "review" and item.target == "").size() == 1, "Rerendering doesn't repeat it.")
	# Closed desk: no strip.
	var closed := Simulation.advance(state, Catalog.shift_seconds())
	ui.render_state(closed)
	check(not strip.visible and int(ui._app_counts.review) == 0, "After the bell the strip is gone and the badge is clear.")
	ui.queue_free()
	await process_frame
