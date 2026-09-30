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
	load("res://content/catalog.gd").campaign_version = 4
	var before := Simulation.advance(Simulation.initial_state(), 280)
	check(Chat.messages(before, "manager").size() == 1, "Manager does not know release outcomes before closing.")
	var mixed := before.duplicate(true)
	mixed = Simulation.dispatch(mixed, {"type": "select-request", "pr_id": "PR-1042"})
	mixed = Simulation.dispatch(mixed, {"type": "review", "verdict": "approve"})
	check(Chat.messages(mixed, "manager").size() == 1, "An incorrect review receives no instant manager grade.")
	mixed = Simulation.advance(mixed, 360)
	var messages := Chat.messages(mixed, "manager")
	var prose := JSON.stringify(messages)
	check(prose.contains("billing page hung") and prose.contains("Helios picked it up"), "Manager describes shipped bugs and unfinished work after closing.")
	for banned: String in ["CORRECT", "audit", "R01", "score", "Trust", "reviewed", "required rules"]:
		check(not prose.contains(banned), "Manager must not expose " + banned)
	messages[0].text = "tampered"
	check(Chat.messages(mixed, "manager")[0].text != "tampered", "Manager messages must be immutable.")
	var clean := before.duplicate(true)
	for packet: Dictionary in Catalog.requests_for_day(1):
		clean = Simulation.dispatch(clean, {"type": "select-request", "pr_id": packet.id})
		for rule_id: String in packet.violations:
			clean = Simulation.dispatch(clean, {"type": "toggle-rule", "rule_id": rule_id})
		clean = Simulation.dispatch(clean, {"type": "review", "verdict": "approve" if packet.violations.is_empty() else "request_changes"})
	clean = Simulation.advance(clean, 360)
	check(not JSON.stringify(Chat.messages(clean, "manager")).contains("billing page hung"), "Prevented bugs must not be reported as shipped.")
	for packet: Dictionary in Catalog.requests():
		if not packet.violations.is_empty():
			check(not str(Chat._authored().requests[packet.id].get("incident", "")).is_empty(), "Every defective PR needs authored consequence prose.")
	print("Manager messages: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
