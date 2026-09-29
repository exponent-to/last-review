extends SceneTree
## Integration smoke test: native controls, authored content, and real transitions.
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Interface = preload("res://native/interface.gd")
const Office = preload("res://native/office_scene.gd")
var state: Dictionary
var ui: Interface
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 900)
	state = Simulation.initial_state()
	ui = Interface.new()
	ui.command_requested.connect(_command)
	root.add_child(ui)
	var office: Office = Office.new()
	ui.scene_host.add_child(office)
	office.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for frame in range(3):
		await process_frame
	ui.render_state(state)
	check(ui.theme.default_font is FontFile, "Interface must use the bundled terminal font")
	check(ui.theme.default_font.resource_path.ends_with("IBMPlexMono-Regular.ttf"), "Terminal typography must not depend on installed system fonts")
	check(ui._rule_rows.size() == Catalog.rules().size(), "Rulebook must include the authored catalog")
	_check_active_rules(int(state.day))
	check(ui._hud["day"].text == str(state.day), "Day display must not expose campaign length")
	check(ui._pr_id.text == str(Catalog.request_at(0).id) + " / AWAITING REVIEW", "Request header must omit queue size and position")
	check(not ui._footer.text.contains(" OF "), "Footer must not reveal queue totals")
	ui._search.text = "timeout"
	ui._filter_rules()
	check(ui._rule_count.text.begins_with("1 shown"), "Rulebook search should find the timeout rule")
	for row: Dictionary in ui._rule_rows:
		if row.rule.id == "R01":
			row.check.button_pressed = true
	check(state.selected_rules == ["R01"], "Native rule checkbox must update selected citations")
	check(ui._approve.disabled and not ui._reject.disabled, "Citations must gate the correct decision controls")
	ui._clear_citations()
	check(state.selected_rules.is_empty(), "Clear citations must update simulation state")
	check(not ui._approve.disabled and ui._reject.disabled, "Clearing citations must restore approval")
	check(not ui._ai_note.text.contains(str(Catalog.request_at(0).ai_note)), "AI advice must be hidden before consultation")
	ui._consult.pressed.emit()
	check(ui._ai_note.text.contains(str(Catalog.request_at(0).ai_note)), "Consultation must reveal authored AI advice")
	var packets: Array = Catalog.requests()
	for index in range(packets.size()):
		var packet: Dictionary = Catalog.request_at(index)
		for rule_id: String in packet.violations:
			_command({"type": "toggle-rule", "rule_id": rule_id})
		if packet.violations.is_empty():
			ui._approve.pressed.emit()
		else:
			ui._reject.pressed.emit()
		check(ui._feedback.text.contains(str(packet.id)), "Audit must identify the previous PR")
		check(ui._feedback.text.contains("CORRECT"), "Valid disposition should pass its audit")
		check(ui._search.text == "timeout", "Review updates must preserve search text")
		if state.phase == "debrief":
			check(ui._evening_buttons.visible, "Each shift needs an evening choice")
			_command({"type": "next-day", "choice": "rest"})
			office.set_story(int(state.day), int(state.autonomy))
			_check_active_rules(int(state.day))
	check(state.phase == "complete", "Authored campaign must finish")
	check(ui._phase_detail.text.contains("%d correct reviews." % packets.size()), "Ending must show retrospective correctness without a queue denominator")
	office.set_motion(false)
	check(not office.is_processing(), "Motion setting must stop decorative animation")
	ui.queue_free()
	await process_frame
	print("Native interface integration: %d failures" % failures)
	quit(1 if failures else 0)

func _command(command: Dictionary) -> void:
	state = Simulation.dispatch(state, command)
	ui.render_state(state)

func _check_active_rules(day: int) -> void:
	var active: Array = Catalog.rules_for_day(day)
	var previous_query: String = ui._search.text
	ui._search.text = ""
	ui._filter_rules()
	for row: Dictionary in ui._rule_rows:
		var should_show: bool = int(row.rule.introduced_day) <= day
		check(row.panel.visible == should_show, "Rule unlock visibility must match its authored introduction day")
	check(ui._rule_count.text.contains("%d active rules" % active.size()), "Active rule count must come from the current catalog day")
	ui._search.text = previous_query
	ui._filter_rules()
