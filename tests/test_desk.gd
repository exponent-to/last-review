extends SceneTree
## One PR at a time on the desk, and the revision back-and-forth after change requests.
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Policy = preload("res://content/policy_campaign.gd")
const Chat = preload("res://content/chat.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_one_at_a_time()
	_test_revision_timing()
	_test_revision_fixes()
	_test_regressions()
	_test_escalation()
	_test_saves()
	_test_dialogue()
	_test_whole_pr_citation()
	print("Desk and revision checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _round_trip(state: Dictionary) -> void:
	var raw: String = Simulation.serialize_save(state)
	_check(not raw.is_empty(), "A desk state with revisions must serialize.")
	var loaded: Dictionary = Simulation.validate_save(JSON.parse_string(raw))
	_check(loaded.ok and loaded.state == state, "Revisions survive a JSON save round trip and replay.")

func _desk(state: Dictionary) -> String:
	return str(Simulation.active_request(state).get("id", ""))

func _land(state: Dictionary) -> Dictionary:
	if not _desk(state).is_empty() or int(state.desk_at) < 0: return state
	return Simulation.advance(state, int(state.desk_at) - int(state.shift_seconds))

func _stamp(state: Dictionary, cited: Array) -> Dictionary:
	var packet: Dictionary = Catalog.packet(state, state.active_request_id)
	var next: Dictionary = state
	for rule_id: String in cited:
		next = Simulation.dispatch(next, Catalog.audit_citation(packet, rule_id))
	return Simulation.dispatch(next, {"type": "review", "verdict": "request_changes" if not cited.is_empty() else "approve"})

func _exact(state: Dictionary) -> Dictionary:
	return _stamp(state, Catalog.packet(state, state.active_request_id).violations)

## Play days until the desk holds a packet matching `wanted`, stamping everything else exactly.
func _find(wanted: Callable) -> Dictionary:
	var state := Simulation.initial_state()
	while state.phase != "complete":
		state = _land(state)
		if state.phase == "review" and not _desk(state).is_empty():
			if wanted.call(Catalog.packet(state, state.active_request_id)): return state
			state = _exact(state)
		elif state.phase == "review":
			state = Simulation.advance(state, Catalog.shift_seconds())
		else:
			state = Simulation.dispatch(state, {"type": "next-day", "choice": "rest"})
	return {}

func _test_one_at_a_time() -> void:
	var state := Simulation.initial_state()
	_check(_desk(state) == "PR-1042" and Simulation.available_requests(state).size() == 1, "The first PR is on the desk at shift start.")
	var day_ids: Array = Catalog.requests_for_day(1).map(func(packet: Dictionary) -> String: return packet.id)
	var seen: Array = []
	while state.phase == "review":
		_check(Simulation.available_requests(state).size() <= 1, "Only one PR is ever available.")
		if _desk(state).is_empty():
			if int(state.desk_at) < 0:
				state = Simulation.advance(state, Catalog.shift_seconds())
				continue
			var stamped_at: int = int(state.decisions[-1].shift_seconds)
			_check(int(state.desk_at) == stamped_at + Simulation.DESK_BEAT, "The next PR is scheduled one beat after the stamp.")
			state = Simulation.advance(state, Simulation.DESK_BEAT)
			_check(not _desk(state).is_empty() and int(state.arrivals[-1].shift_seconds) == stamped_at + Simulation.DESK_BEAT, "The next PR auto-arrives after a verdict, with no pick.")
		seen.append(_desk(state))
		state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	_check(seen == day_ids, "With no change requests, the line is the day's authored packets in order.")
	_check(state.last_debrief.handed_off == 0 and state.last_debrief.reviewed == 15, "A cleared line hands nothing to Helios.")
	var late := Simulation.advance(Simulation.initial_state(), 298)
	late = Simulation.dispatch(late, {"type": "review", "verdict": "approve"})
	late = Simulation.advance(late, 2)
	_check(late.phase == "debrief" and late.last_debrief.handed_off == 14 and late.arrivals.size() == 1, "A PR due after the bell never lands; it goes to Helios with the rest of the line.")

func _test_revision_timing() -> void:
	var state := Simulation.initial_state()
	state = _exact(state)
	_check(state.revisions.size() == 1 and state.revisions[0].id == "PR-1042-v2" and state.revisions[0].origin_id == "PR-1042", "A change request queues the author's revision.")
	_check(state.desk_line.find("PR-1042-v2") == Simulation.REVISION_GAP, "The revision rejoins the line behind the next two PRs.")
	var order: Array = []
	for _turn in range(3):
		state = _land(state)
		order.append(_desk(state))
		state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"}) if order.size() < 3 else state
	var day: Array = Catalog.requests_for_day(1)
	_check(order == [day[1].id, day[2].id, "PR-1042-v2"], "A revision appears after two more PRs.")
	var revision: Dictionary = Simulation.active_request(state)
	_check(int(revision.revision) == 2 and revision.parent_id == "PR-1042" and Catalog.display_id(revision.id) == "PR-1042 · v2", "Revisions carry their version, parent, and a display ID.")
	_check(not revision.has("violations") and not revision.has("recipe") and not revision.has("findings"), "The desk view of a revision hides audit data.")
	# Near the end of the line, a revision comes back sooner.
	var tail := Simulation.initial_state()
	while tail.desk_line.size() > 1:
		tail = _land(Simulation.dispatch(tail, {"type": "review", "verdict": "approve"}))
	var last_but_one := _desk(tail)
	tail = _exact(tail) if not Catalog.packet(tail, last_but_one).violations.is_empty() else _stamp(tail, ["P01"])
	_check(tail.desk_line.size() == 2 and tail.desk_line[1] == last_but_one + "-v2", "With fewer PRs left, the revision rejoins at the end of what remains.")
	tail = _land(Simulation.dispatch(_land(tail), {"type": "review", "verdict": "approve"}))
	_check(_desk(tail) == last_but_one + "-v2", "The revision reaches the desk after the remaining PR.")
	tail = Simulation.dispatch(tail, {"type": "review", "verdict": "approve"})
	_check(tail.desk_line.is_empty() and int(tail.desk_at) < 0, "An approved revision ends the line.")
	var solo := Simulation.initial_state()
	while not solo.desk_line.is_empty():
		solo = _land(Simulation.dispatch(solo, {"type": "review", "verdict": "approve"}))
	solo = _stamp(solo, ["P01"])
	_check(solo.desk_line.size() == 1 and int(solo.desk_at) == int(solo.shift_seconds) + Simulation.DESK_BEAT, "With nothing left, the revision is next, one beat later.")
	_round_trip(solo)

func _test_revision_fixes() -> void:
	# A packet with two real violations: cite one, leave the other.
	var state := _find(func(packet: Dictionary) -> bool: return packet.violations.size() >= 2 and int(packet.revision) == 1)
	_check(not state.is_empty(), "The campaign has a PR with two broken standards.")
	if state.is_empty(): return
	var parent: Dictionary = Catalog.packet(state, state.active_request_id)
	var spurious := ""
	for rule: Dictionary in Catalog.rules_for_day(int(state.day)):
		if rule.id not in parent.violations: spurious = rule.id
	var cited: Array = [parent.violations[0], spurious]
	state = _stamp(state, cited)
	var entry: Dictionary = state.revisions[-1]
	_check(entry.fixed == [parent.violations[0]], "Only the cited violation that really existed is fixed.")
	_check(entry.cited.size() == 2 and spurious in entry.cited, "The revision remembers everything the player cited.")
	var revision: Dictionary = Catalog.packet(state, entry.id)
	var expected: Array = parent.violations.slice(1)
	if not str(entry.regression).is_empty(): expected.append(entry.regression)
	expected.sort()
	_check(revision.violations == expected, "Uncited real violations stay; the cited one is gone; spurious citations fix nothing.")
	_check(parent.violations[0] not in revision.violations, "The cited, real problem is fixed in v2.")
	# Cite only a rule that wasn't broken: nothing changes but the author's note.
	var clean := _find(func(packet: Dictionary) -> bool: return packet.violations.is_empty() and int(packet.revision) == 1)
	var original: Dictionary = Catalog.packet(clean, clean.active_request_id)
	clean = _stamp(clean, ["P01"])
	_check(clean.revisions[-1].fixed.is_empty() and clean.revisions[-1].regression == "", "A spurious citation fixes nothing and breaks nothing.")
	var unchanged: Dictionary = Catalog.packet(clean, clean.revisions[-1].id)
	_check(unchanged.violations.is_empty(), "A clean PR stays clean after a spurious change request.")
	var added: int = 0
	for index in range(unchanged.files.size()):
		added += unchanged.files[index].source.split("\n").size() - original.files[index].source.split("\n").size()
	_check(added == 1 and unchanged.recipe.notes.size() == 1, "The author only adds a harmless note acknowledging the 'fix'.")

func _test_regressions() -> void:
	var regressed := 0
	var fixed_any := 0
	for parent: Dictionary in Catalog.requests():
		if parent.violations.is_empty(): continue
		var id := Policy.revision_id(parent, 2)
		var first := Policy.regression_rule(parent, id, parent.violations, parent.violations)
		_check(first == Policy.regression_rule(parent.duplicate(true), id, parent.violations.duplicate(), parent.violations.duplicate()), "Regressions are derived from the PR, not from chance.")
		fixed_any += 1
		if not first.is_empty(): regressed += 1
	_check(regressed * 5 >= fixed_any and regressed * 2 <= fixed_any, "About one fixing revision in three breaks something new (%d of %d)." % [regressed, fixed_any])
	var state := _find(func(packet: Dictionary) -> bool:
		return int(packet.revision) == 1 and not packet.violations.is_empty() and not Policy.regression_rule(packet, Policy.revision_id(packet, 2), packet.violations, packet.violations).is_empty())
	_check(not state.is_empty(), "Some PR regresses when fixed.")
	if state.is_empty(): return
	var parent: Dictionary = Catalog.packet(state, state.active_request_id)
	var replay_a := _exact(state)
	var replay_b := _exact(state.duplicate(true))
	_check(replay_a.revisions == replay_b.revisions, "The same change request always produces the same regression.")
	var revision: Dictionary = Catalog.packet(replay_a, replay_a.revisions[-1].id)
	_check(revision.violations == [replay_a.revisions[-1].regression], "Fixed one thing, broke another: v2 breaks only the new standard.")
	var counterfactual: Dictionary = Policy.revision(parent, 2, [], "", replay_a.revisions[-1].cited)
	_check(revision.message == counterfactual.message, "Revision text is the same whether the author fixed, broke, or did nothing.")

func _test_escalation() -> void:
	var state := Simulation.initial_state()
	var origin: String = state.active_request_id
	for version in [1, 2, 3]:
		state = _land(state)
		while _desk(state) != (origin if version == 1 else "%s-v%d" % [origin, version]):
			state = _land(Simulation.dispatch(state, {"type": "review", "verdict": "approve"}))
		state = _stamp(state, ["P01"])
	_check(state.revisions.size() == 2 and state.revisions[-1].id == origin + "-v3", "A PR is revised at most twice: v2 and v3.")
	_check(origin + "-v4" not in state.desk_line and state.revisions.filter(func(entry: Dictionary) -> bool: return entry.id.ends_with("-v4")).is_empty(), "Requesting changes on v3 makes no v4.")
	_check(state.log.any(func(entry: Dictionary) -> bool: return str(entry.message).contains("escalated")), "The escalation is logged.")
	var morgan := JSON.stringify(Chat.messages(state, "manager"))
	_check(morgan.contains("Maya looped me in on " + origin) and morgan.contains("v4"), "Morgan messages about the escalation right away.")
	var maya := Chat.messages(state, "Maya")
	_check(maya.any(func(message: Dictionary) -> bool: return message.kind == "reaction" and message.text.contains("looping in Morgan")), "The author escalates in Slouch on the third change request.")
	_round_trip(state)
	while state.phase == "review":
		state = _land(state)
		if _desk(state).is_empty(): state = Simulation.advance(state, Catalog.shift_seconds())
		else: state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	_check(state.last_debrief.reviewed == 15 + 2 and state.last_debrief.handed_off == 0, "Each version is its own signed review; escalated work is not handed off again.")

func _test_saves() -> void:
	var state := Simulation.initial_state()
	var stamped := 0
	while state.phase == "review" and stamped < 12:
		state = _land(state)
		if _desk(state).is_empty(): break
		# Alternate exact reviews with careless ones so revisions, regressions, and spurious fixes mix.
		state = _exact(state) if stamped % 3 != 2 else _stamp(state, ["P02"])
		stamped += 1
		if stamped % 4 == 0: _round_trip(state)
	_check(not state.revisions.is_empty(), "The save sample includes revisions.")
	state = _land(state)
	state = Simulation.dispatch(state, Catalog.audit_citation(Catalog.packet(state, state.active_request_id), "P01"))
	_round_trip(state)
	var forged := state.duplicate(true)
	forged.revisions[0].fixed = ["P02"]
	_check(not Simulation.validate_save(forged).ok, "A save cannot claim a different fix than the replay produces.")
	forged = state.duplicate(true)
	forged.revisions[0].regression = "P06"
	_check(not Simulation.validate_save(forged).ok, "A save cannot invent or remove a regression.")
	forged = state.duplicate(true)
	forged.desk_line.reverse()
	_check(forged.desk_line == state.desk_line or not Simulation.validate_save(forged).ok, "A save cannot reorder the line.")
	forged = state.duplicate(true)
	forged.active_request_id = state.desk_line[0] if not state.desk_line.is_empty() else "PR-1003"
	_check(not Simulation.validate_save(forged).ok, "A save cannot put a different PR on the desk.")
	var finished := Simulation.advance(state, Catalog.shift_seconds())
	finished = Simulation.dispatch(finished, {"type": "next-day", "choice": "study"})
	_round_trip(finished)
	_check(finished.desk_line.size() == 14 and finished.active_request_id == Catalog.requests_for_day(2)[0].id, "Revisions never carry over: the next morning starts a fresh line.")

func _test_dialogue() -> void:
	var state := Simulation.initial_state()
	state = _exact(state)
	var maya := Chat.messages(state, "Maya")
	var reaction: Dictionary = maya.filter(func(message: Dictionary) -> bool: return message.kind == "reaction")[-1]
	_check(reaction.text.to_lower().contains("load-bearing comment"), "Right after the change request, the author reacts to what was cited.")
	for _turn in range(2):
		state = _land(state)
		state = _exact(state)
	state = _land(state)
	_check(_desk(state) == "PR-1042-v2", "Maya's revision is on the desk.")
	maya = Chat.messages(state, "Maya")
	var arrival: Dictionary = maya.filter(func(message: Dictionary) -> bool: return message.get("pr_id", "") == "PR-1042-v2")[0]
	var revision: Dictionary = Catalog.packet(state, "PR-1042-v2")
	_check(arrival.kind == "request" and arrival.text == revision.message and arrival.text.begins_with("v2"), "The revision arrives in Slouch with an OPEN link and the author's v2 note.")
	_check(revision.description.contains("Revision 2 of PR-1042") and revision.description.contains("load-bearing comment"), "The PR form describes what changed in plain words.")
	state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	maya = Chat.messages(state, "Maya")
	_check(maya.filter(func(message: Dictionary) -> bool: return message.kind == "reaction")[-1].text.begins_with("Finally"), "Approving a revision brings relief.")
	# No audit leaks: the same citations produce the same words whether or not they were right.
	var forbidden := RegEx.new()
	forbidden.compile("\\bP0[1-9]\\b|violat|audit|%|\\[")
	for author: String in ["Maya", "Theo", "Inez"]:
		for version in [1, 2, 3]:
			for verdict: String in ["approve", "request_changes"]:
				for cited: Array in [["P01"], ["P03", "P04"], ["P02", "P05", "P08"], []]:
					var line: String = Chat._lines().reaction(author, version, verdict, cited, "PR-2004" if version == 1 else "PR-2004-v%d" % version)
					_check(forbidden.search(line) == null and not line.is_empty(), "Revision dialogue never names rules or audit results: " + line)
			for cited: Array in [["P01"], ["P02", "P06"]]:
				var message: String = Policy.revision_message(author, version if version > 1 else 2, cited, "PR-2004-v2")
				_check(forbidden.search(message) == null, "Revision notes never name rules: " + message)
	for contact: String in Chat.CONTACTS:
		for message: Dictionary in Chat.messages(state, contact):
			_check(forbidden.search(str(message.text)) == null, "Slouch never shows placeholders, rule IDs, or audit results: " + str(message.text))

## Week two: a whole-PR standard is cited with WHOLE FILE on any changed file, and
## a retired standard can't be cited at all.
func _test_whole_pr_citation() -> void:
	var state := _find(func(packet: Dictionary) -> bool: return int(packet.revision) == 1 and packet.violations.any(func(rule_id: String) -> bool: return rule_id in Policy.PR_SCOPED))
	_check(not state.is_empty(), "Week two puts a whole-PR violation on the desk.")
	if state.is_empty(): return
	var packet: Dictionary = Catalog.packet(state, state.active_request_id)
	var pr_rule: String = packet.violations.filter(func(rule_id: String) -> bool: return rule_id in Policy.PR_SCOPED)[0]
	var cited: Dictionary = state
	for rule_id: String in packet.violations:
		var command: Dictionary = Catalog.audit_citation(packet, rule_id)
		if rule_id == pr_rule: command = {"type": "toggle-rule", "rule_id": rule_id, "path": str(packet.files[-1].path), "line": 0}
		cited = Simulation.dispatch(cited, command)
	var stamped: Dictionary = Simulation.dispatch(cited, {"type": "review", "verdict": "request_changes"})
	_check(stamped.last_feedback.correct, "WHOLE FILE on the PR's last file is valid evidence for %s." % pr_rule)
	_round_trip(stamped)
	_check(Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": pr_rule, "path": "nowhere/else.py", "line": 0}) == state, "Whole-PR evidence must still point at a file in the PR.")
	_check(int(state.day) >= 7 and Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": "P05", "path": str(packet.files[0].path), "line": 0}) == state, "A retired standard can no longer be cited.")
