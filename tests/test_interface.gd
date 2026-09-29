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
	check(Catalog.rules().size() == 36, "Expected all 36 authored rules")
	check(Catalog.rules_for_day(1).size() == 30, "Day one should expose 30 rules")
	check(Catalog.rules_for_day(3).size() == 36, "Automation rules must unlock by day three")
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
	for index in range(12):
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
	check(state.phase == "complete", "All three workdays must finish")
	check(ui._phase_detail.text.contains("12 / 12 reviews correct"), "Ending must show accurate review results")
	office.set_motion(false)
	check(not office.is_processing(), "Motion setting must stop decorative animation")
	ui.queue_free()
	await process_frame
	print("Native interface integration: %d failures" % failures)
	quit(1 if failures else 0)

func _command(command: Dictionary) -> void:
	state = Simulation.dispatch(state, command)
	ui.render_state(state)
