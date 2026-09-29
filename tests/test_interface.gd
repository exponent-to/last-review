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
	await _test_desktop()
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

func _test_desktop() -> void:
	var review = ui._windows["review"]
	var rules = ui._windows["rules"]
	for extent: Vector2i in [Vector2i(1120, 800), Vector2i(1280, 900)]:
		root.size = extent
		for frame: int in range(4):
			await process_frame
		ui._arrange_windows()
		await process_frame
		check(ui._diff.size.y >= 100, "Review code must retain readable vertical space at supported window sizes")
		for id: String in ["review", "rules", "decision"]:
			var window = ui._windows[id]
			check(window.position.y >= 0 and window.position.y + 32 <= ui._desktop.size.y, "Default window titlebars must remain accessible")
	review.move_window(Vector2(100000, 100000))
	check(review.position.x <= ui._desktop.size.x - 140, "Dragging right must retain an accessible titlebar fragment")
	check(review.position.y <= ui._desktop.size.y - 34, "Dragging below the desktop must retain the titlebar")
	review.move_window(Vector2(-100000, -100000))
	check(review.position.x + review.size.x >= 140, "Dragging left must retain an accessible titlebar fragment")
	check(review.position.y == 0, "Dragging above the desktop must clamp to its top")
	ui._arrange_windows()
	var arranged: Vector2 = review.position
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_RIGHT
	key.pressed = true
	review._title_input(key)
	check(review.position.x > arranged.x, "Focused titlebar arrow keys must move the window")
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	review._title_input(press)
	check(review._dragging, "Titlebar pointer press must begin dragging")
	press.pressed = false
	review._input(press)
	check(not review._dragging, "Pointer release must stop dragging")
	review.minimize_window()
	check(not review.visible, "Minimize must hide the native window")
	ui.render_state(state)
	check(not review.visible, "State refresh must preserve minimized windows")
	ui._open_app("review")
	check(review.visible and review.get_index() == ui._desktop.get_child_count() - 1, "Taskbar reopening must restore and focus the window")
	rules.focus_window()
	check(rules.get_index() == ui._desktop.get_child_count() - 1, "Window focus must raise z-order")
	ui._open_app("browser")
	ui._browse("procedure")
	ui._browse("memo")
	ui._browser_go_back()
	check(ui._browser_path == "procedure", "Fake browser back must restore the previous local page")
	check(ui._browser_address.text == "intranet://engineering/procedure", "Fake browser must display a local in-game address")
	ui._windows["browser"].minimize_window()
	ui._arrange_windows()
	ui._open_app("decision")
	var original_diff: String = ui._diff.text
	ui._diff.text = original_diff + "\n" + " context line\n".repeat(60)
	ui._diff.set_caret_line(30)
	ui.hide()
	ui.show()
	ui.focus_workspace()
	for frame: int in range(4):
		await process_frame
	check(ui._diff.scroll_vertical == 0, "Initial intro handoff must reveal the start of the diff after layout")
	check(root.gui_get_focus_owner() == ui, "Intro handoff must focus a non-actionable root control")
	ui._diff.scroll_vertical = 10
	await process_frame
	var reading_position: float = ui._diff.scroll_vertical
	ui.hide()
	ui.show()
	ui.focus_workspace()
	for frame: int in range(3):
		await process_frame
	check(ui._diff.scroll_vertical == reading_position, "Later workspace reveals must preserve code reading position")
	ui._diff.text = original_diff
	ui._diff.set_caret_line(0)
	ui._diff.scroll_vertical = 0
