extends SceneTree
const Simulation = preload("res://native/simulation.gd")
const Chat = preload("res://content/chat.gd")
const Catalog = preload("res://content/catalog.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	var before := Simulation.advance(Simulation.initial_state(), Catalog.shift_seconds() - 20)
	check(Chat.messages(before, "manager").size() == 1, "Manager does not know release outcomes before closing.")
	var mixed := before.duplicate(true)
	mixed = Simulation.dispatch(mixed, {"type": "review", "verdict": "approve"})
	check(Chat.messages(mixed, "manager").size() == 1, "An incorrect review receives no instant manager grade.")
	mixed = Simulation.advance(mixed, 360)
	var messages := Chat.messages(mixed, "manager")
	var prose := JSON.stringify(messages)
	check(prose.contains("Compliance bounced a release") and prose.contains("Helios picked up the remaining queue"), "Manager describes shipped bugs and unfinished work after closing.")
	for banned: String in ["CORRECT", "audit", "P01", "score", "Trust", "reviewed", "required rules"]:
		check(not prose.contains(banned), "Manager must not expose " + banned)
	messages[0].text = "tampered"
	check(Chat.messages(mixed, "manager")[0].text != "tampered", "Manager messages must be immutable.")
	var clean := Simulation.initial_state()
	while not Simulation.active_request(clean).is_empty():
		var packet: Dictionary = Catalog.packet(clean, clean.active_request_id)
		for rule_id: String in packet.violations:
			clean = Simulation.dispatch(clean, Simulation.Catalog.audit_citation(packet, rule_id))
		clean = Simulation.dispatch(clean, {"type": "review", "verdict": "approve" if packet.violations.is_empty() else "request_changes"})
		if int(clean.desk_at) >= 0: clean = Simulation.advance(clean, int(clean.desk_at) - int(clean.shift_seconds))
	clean = Simulation.advance(clean, 360)
	check(not JSON.stringify(Chat.messages(clean, "manager")).contains("Compliance bounced a release"), "Prevented bugs must not be reported as shipped.")
	for packet: Dictionary in Catalog.requests():
		if not packet.violations.is_empty():
			check(not str(Chat._authored().requests[packet.id].get("incident", "")).is_empty(), "Every defective PR needs authored consequence prose.")
	_test_evening(before, mixed)
	print("Manager messages: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

## Morgan's end-of-day panel (Chat.evening): the closed day's notes, then her closing words.
func _test_evening(before: Dictionary, closed: Dictionary) -> void:
	var Encounters = load("res://content/encounters.gd")
	var copy: Dictionary = Chat._authored().manager
	check(Chat.evening(before).is_empty() and Chat.evening(Simulation.initial_state()).is_empty(), "Morgan's panel has nothing to say while the shift is open.")
	var evening: Dictionary = Chat.evening(closed)
	check(int(evening.day) == 1 and evening.closing == [str(copy.closings[1])] and str(copy.closings[1]).contains("earned") and str(copy.closings[1]).contains("tonight"), "Closing the first day, Morgan says why the panel opens: what you earned, what it cost, and tonight's choice.")
	var prose := JSON.stringify(evening)
	check(prose.contains("Compliance bounced a release") and prose.contains("Helios picked up the remaining queue"), "The day's notes carry the shipped bug and the handoff to Helios.")
	check(not prose.contains(str(copy.intro)), "The morning intro is not part of the evening.")
	for banned: String in ["CORRECT", "audit", "P01", "score", "Trust", "reviewed", "required rules"]:
		check(not prose.contains(banned), "Morgan's panel must not expose " + banned)
	# Everything on the panel is something Morgan already says in her thread.
	var thread: Array = Chat.messages(closed, "manager").map(func(message: Dictionary) -> String: return str(message.text))
	for text: String in evening.notes + evening.closing:
		check(text in thread, "The panel only repeats Morgan's authored messages: " + text)
	evening.notes.append("tampered")
	check(not Chat.evening(closed).notes.has("tampered"), "Each evening report is a fresh copy.")
	# Send everything back with a pile of citations: some authors abandon or escalate,
	# and Morgan's notes about them reach that evening's panel.
	var heavy := Simulation.initial_state()
	while heavy.phase == "review":
		if not Encounters.pending(heavy).is_empty():
			heavy = Simulation.dispatch(heavy, {"type": "pushback", "choice": "insist"})
		elif Simulation.active_request(heavy).is_empty():
			var wait: int = Catalog.shift_seconds() if int(heavy.desk_at) < 0 else int(heavy.desk_at) - int(heavy.shift_seconds)
			heavy = Simulation.advance(heavy, maxi(1, wait))
		else:
			var packet: Dictionary = Catalog.packet(heavy, heavy.active_request_id)
			for rule: Dictionary in Catalog.rules_for_day(1):
				heavy = Simulation.dispatch(heavy, {"type": "toggle-rule", "rule_id": rule.id, "path": packet.files[0].path, "line": 0})
			heavy = Simulation.dispatch(heavy, {"type": "review", "verdict": "request_changes"})
	var helios: Array = Encounters.morgan(heavy).filter(func(note: Dictionary) -> bool: return int(note.day) == 1)
	var report: Dictionary = Chat.evening(heavy)
	check(not helios.is_empty(), "A day of piled-on citations sends some PRs to Helios through their authors.")
	for note: Dictionary in helios:
		check(str(note.text) in report.notes, "Morgan's note about an abandoned or escalated PR reaches the panel: " + str(note.text))
	# A day of nothing but wrong rejections can end the run (you are let go), so the
	# closing is either Morgan's usual sign-off or the ending; either way it is there.
	check(not report.closing.is_empty() and (str(copy.closing) in report.closing or heavy.phase == "complete"), "Notes never crowd out the closing message.")
	# The first Friday adds the extension; week two has its own closings; the end, the ending.
	var later := Simulation.initial_state()
	var seen := {}
	while later.phase != "complete":
		later = Simulation.advance(later, Catalog.shift_seconds())
		var day := int(later.day)
		var closing: Array = Chat.evening(later).closing
		var expected: Array = [str(copy.get("closings", {}).get(day, copy.closing))]
		if day == 5: expected.append(str(copy.extension))
		check(closing == expected, "Day %d closes with Morgan's words for that day." % day)
		seen[day] = true
		later = Simulation.dispatch(later, {"type": "next-day", "choice": "rest"})
	var ending: Dictionary = Chat.evening(later)
	check(seen.size() == Catalog.campaign_days().size() and int(ending.day) == 10, "Every day of the campaign has an evening.")
	check(ending.closing.size() == 2 and ending.closing[-1] == Chat._ending(later) and str(ending.closing[-1]).contains("review gate"), "The assignment ends with Morgan's final word.")
