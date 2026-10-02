extends SceneTree
## Integration smoke test: native controls, authored content, and real transitions.
const Simulation = preload("res://native/simulation.gd")
const Chat = preload("res://content/chat.gd")
const Catalog = preload("res://content/catalog.gd")
const Interface = preload("res://native/interface.gd")
const Office = preload("res://native/computer_frame.gd")
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
	await _test_chat_first_open()
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
	_test_slouch()
	check(ui._clock_label.text == "09:00", "Desktop clock must start at nine")
	check(ui._approve.disabled and ui._diff.text.is_empty(), "No code or review actions are available before a coworker sends a link")
	state = Simulation.advance(state, 20)
	ui.render_state(state)
	ui._select_chat_contact("Maya")
	var opened := false
	for button: Node in ui._chat_messages.find_children("*", "Button", true, false):
		if button.text.begins_with("OPEN " + str(Catalog.request_at(0).id)):
			button.pressed.emit()
			opened = true
	check(opened and ui._windows["review"].visible, "An arrived Slouch PR link must open Review")
	check(ui._file_picker.item_count == 2, "The first review must expose both changed files")
	var first_diff: String = ui._diff.text
	ui._diff.set_caret_line(4)
	ui._file_picker.item_selected.emit(1)
	check(ui._diff.text != first_diff and ui._file_label.text == Catalog.request_at(0).files[1].path, "Selecting another file must show its own diff")
	ui._file_picker.item_selected.emit(0)
	for frame in range(3):
		await process_frame
	check(ui._diff.text == first_diff and ui._diff.get_caret_line() == 4, "Returning to a file must preserve its reading position")
	for button: Node in ui._chat_messages.find_children("*", "Button", true, false):
		check(button.text.begins_with("OPEN "), "Coworker conversations only offer PR links, not replies.")
	ui._select_chat_contact("Theo")
	check(ui.theme.default_font is FontFile, "Interface must use the bundled terminal font")
	check(ui.theme.default_font.resource_path.ends_with("IBMPlexMono-Regular.ttf"), "Terminal typography must not depend on installed system fonts")
	check(ui._flag_buttons.size() == Catalog.rules().size(), "The flag box offers every authored standard")
	_check_active_rules(int(state.day))
	check(not ui._hud["day"].text.is_valid_int(), "Workday must use an in-world name instead of a score counter")
	for stat: String in ["credits", "trust", "stress", "autonomy"]:
		check(not ui._hud.has(stat), "Top chrome must not expose numeric player statistics")
	check(ui._pr_id.text == str(Catalog.request_at(0).id) + " / AWAITING REVIEW", "Request header must omit queue size and position")
	check(not ui._footer.text.contains(" OF "), "Footer must not reveal queue totals")
	check(not ui._windows.has("rules") and not ui._home_icons.has("rules"), "There is no separate Handbook application")
	ui._browse("standards")
	var standards_text := ""
	for label: Node in ui._daily_reader._content.find_children("*", "Label", true, false): standards_text += label.text + "\n"
	check(standards_text.contains("P01") and standards_text.contains(str(Catalog.rules()[0].text)), "INTRANET > STANDARDS shows the full active rule text")
	var finding: Dictionary = Catalog.audit_citation(Catalog.request_at(0), "P01")
	for index in range(ui._review_files.size()):
		if ui._review_files[index].path == finding.path: ui._select_file(index)
	ui._diff.set_caret_line(int(finding.line) - 1)
	ui._point_at(-1)
	check(ui._evidence.line == finding.line and ui._flag_box.visible and ui._evidence_label.text.contains("FLAGGING"), "Clicking a code line opens the flag box on that line")
	check(ui._windows.review.find_children("*", "CheckBox", true, false).is_empty(), "Review has no rulebook checklist")
	ui._flag_buttons.P01.pressed.emit()
	check(state.selected_rules == ["P01"] and state.citation_evidence.P01 == {"path": finding.path, "line": finding.line}, "Picking a standard cites the flagged line")
	check(not ui._flag_box.visible and ui._evidence.is_empty(), "Citing closes the flag box")
	check(ui._citation_list.get_child_count() == 1, "Review lists each citation with its location")
	var other_line: int = 2 if int(finding.line) == 1 else 1
	ui._diff.set_caret_line(other_line - 1)
	ui._point_at(-1)
	check(ui._flag_box.visible and not ui._flag_buttons.P01.button_pressed, "A rule cited elsewhere is not marked on this line")
	ui._flag_buttons.P01.pressed.emit()
	check(state.selected_rules == ["P01"] and int(state.citation_evidence.P01.line) == other_line, "Re-flagging a rule moves its citation")
	ui._diff.set_caret_line(int(finding.line) - 1)
	ui._point_at(-1)
	ui._flag_buttons.P01.pressed.emit()
	check(int(state.citation_evidence.P01.line) == int(finding.line), "The citation can be moved back to the real evidence")
	check(ui._approve.disabled and not ui._reject.disabled, "Citations must gate the correct decision controls")
	ui._clear_citations()
	check(state.selected_rules.is_empty(), "Clear citations must update simulation state")
	check(not ui._approve.disabled and ui._reject.disabled, "Clearing citations must restore approval")
	check(not ui._ai_note.text.contains(str(Catalog.request_at(0).ai_note)), "AI advice must be hidden before consultation")
	check(not ui._consult.visible, "Consultation stays hidden until Wednesday")
	var packets: Array = Catalog.requests()
	for index in range(packets.size()):
		var packet: Dictionary = Catalog.request_at(index)
		state = Simulation.advance(state, maxi(0, Catalog.arrival_seconds(str(packet.id)) - int(state.shift_seconds)))
		ui.render_state(state)
		ui._open_pr_link(str(packet.id))
		var previous_messages: String = str(ui._chat_seen.get(str(packet.author), ""))
		for rule_id: String in packet.violations:
			_command(Simulation.Catalog.audit_citation(packet, rule_id))
		if packet.violations.is_empty():
			ui._approve.pressed.emit()
		else:
			ui._reject.pressed.emit()
		check(ui._feedback.text.contains(str(packet.id)), "Audit must identify the previous PR")
		check(not ui._feedback.text.contains("CORRECT") and not ui._feedback.text.contains("Required:"), "Sent confirmation must not grade a review or reveal its answers")
		check(not ui._feedback.text.contains("Trust +") and not ui._feedback.text.contains("Trust -"), "Audit must omit numeric social/stat deltas")
		check(str(ui._chat_seen.get(str(packet.author), "")) != previous_messages, "Completed review must update its author's Slouch messages")
		check(ui._chat_contact == "Theo", "Incoming coworker messages must never switch the player's selected conversation")
		var has_reaction: bool = false
		for message: Dictionary in Chat.messages(state, str(packet.author)):
			if str(message.get("kind", "")) == "reaction":
				has_reaction = true
		check(has_reaction, "Coworker conversation must contain a review reaction")
		if str(packet.author) != "Theo":
			check(bool(ui._chat_unread.get(str(packet.author), false)), "Other coworker reactions must receive an unread indicator")
		var following: Dictionary = Catalog.request_at(index + 1)
		if following.is_empty() or int(following.day) != int(state.day):
			state = Simulation.advance(state, Simulation.Catalog.shift_seconds())
			ui.render_state(state)
		if state.phase == "debrief":
			check(not ui._windows.has("shift"), "Closing must not open an explicit results window")
			ui._select_chat_contact("manager")
			check(ui._evening_buttons.visible, "Manager conversation offers evening choices")
			_command({"type": "next-day", "choice": "rest"})
			office.set_story(int(state.day), int(state.autonomy))
			_check_active_rules(int(state.day))
			ui._select_chat_contact("Theo")
	check(state.phase == "complete", "Authored campaign must finish")
	ui._select_chat_contact("manager")
	check(ui._complete_button.visible and not ui._evening_buttons.visible, "Final manager conversation must offer a return to menu")
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
	ui._evidence = {"path": "office/sample.py", "line": 1}
	ui._open_flag_box()
	var shown := 0
	for rule: Dictionary in Catalog.rules():
		var should_show: bool = int(rule.introduced_day) <= day
		check(ui._flag_buttons[str(rule.id)].visible == should_show, "Flag choices must match each standard's introduction day")
		if should_show: shown += 1
	check(shown == active.size(), "The flag box offers exactly the current day's standards")
	ui._close_flag_box()

func _test_desktop() -> void:
	var review = ui._windows["review"]
	for window in ui._windows.values():
		check(not window.visible and not window.launched, "HOME must begin with every application closed")
	for button in ui._dock_buttons.values():
		check(not button.visible, "Taskbar must omit applications that have not been launched")
	check(ui._home_icons.size() == 4, "HOME must offer the four actual application launchers")
	ui._home_icons["review"].pressed.emit()
	check(review.visible and review.launched, "REVIEW desktop icon must launch the combined review application")
	check(ui._dock_buttons["review"].visible, "Launching an application must add its taskbar entry")
	for extent: Vector2i in [Vector2i(1120, 800), Vector2i(1280, 900)]:
		root.size = extent
		for frame: int in range(4):
			await process_frame
		ui._arrange_windows()
		await process_frame
		check(ui.scene_host.size == ui.size, "Computer frame must occupy the complete viewport behind the monitor screen")
		check(ui._monitor_screen.size.x >= ui.size.x * 0.78 and ui._monitor_screen.size.y >= ui.size.y * 0.65, "Computer monitor must stay readable while allowing room around it")
		check(ui._monitor_screen.position.x >= 96 and ui._monitor_screen.position.y >= 100, "The rainy office must stay visible beside and above the monitor")
		for launcher: Button in ui._home_icons.values():
			check(Rect2(Vector2.ZERO, ui._desktop.size).encloses(launcher.get_rect()), "All home icons must remain inside the reduced monitor screen")
		check(ui._diff.size.y >= 100, "Review code must retain readable vertical space at supported window sizes")
		for id: String in ["review"]:
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
	var browser = ui._windows["browser"]
	ui._open_app("browser")
	review.focus_window()
	browser.focus_window()
	check(browser.get_index() == ui._desktop.get_child_count() - 1, "Window focus must raise z-order")
	ui._browse("procedure")
	ui._browse("memo")
	ui._browser_go_back()
	check(ui._browser_path == "procedure", "Fake browser back must restore the previous local page")
	check(ui._browser_address.text == "intranet://engineering/procedure", "Fake browser must display a local in-game address")
	for button: Button in ui._windows.browser.find_children("*", "Button", true, false):
		check(button.text not in ["SLOUCH", "HANDBOOK", "REVIEW", "SYSTEM"], "Intranet pages link only to intranet pages, never to desktop apps")
	ui._windows["browser"].minimize_window()
	ui._arrange_windows()
	ui._show_home()
	check(not review.visible and not browser.visible, "HOME must minimize launched windows to reveal desktop icons")
	check(review.launched and ui._dock_buttons["review"].visible, "HOME must retain launched applications in the taskbar")
	ui._dock_buttons["review"].pressed.emit()
	check(review.visible, "Taskbar must restore an application after showing HOME")
	review.close_window()
	check(not review.visible and not ui._dock_buttons["review"].visible, "Closing an application must remove its taskbar entry")
	ui._home_icons["review"].pressed.emit()
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

func _test_slouch() -> void:
	var chat = ui._windows["chat"]
	check(not chat.visible, "Slouch must remain closed until the player opens it")
	check(chat.window_title.begins_with("SLOUCH"), "Chat must be its own named native application")
	ui._open_app("chat")
	check(chat.visible, "Taskbar must open the separate Slouch window")
	ui._select_chat_contact("Theo")
	check(ui._chat_heading.text.begins_with("Theo"), "Selecting a DM must display that coworker's conversation")
	check(not bool(ui._chat_unread.get("Theo", false)), "Reading a conversation must clear its unread indicator")
	check(ui._chat_messages.get_child_count() > 0, "Slouch must render authored message rows")
	chat.minimize_window()
	ui.render_state(state)
	check(not chat.visible, "Incoming refresh must not reopen minimized chat")
	ui._open_app("chat")
	check(ui._chat_contact == "Theo", "Reopening Slouch must preserve the player's selected conversation")
	ui._open_app("review")
	var top_window: Node = ui._desktop.get_child(ui._desktop.get_child_count() - 1)
	ui.render_state(state)
	check(ui._desktop.get_child(ui._desktop.get_child_count() - 1) == top_window, "Chat refresh must not steal native window focus")
	check(ui._dock_buttons["chat"].text.begins_with("SLOUCH"), "Taskbar must expose the Slouch application and its unread count")

func _test_chat_first_open() -> void:
	var initial: Dictionary = Simulation.initial_state()
	var loaded: Dictionary = initial.duplicate(true)
	var first_packet: Dictionary = Catalog.request_at(0)
	loaded = Simulation.advance(loaded, 20)
	loaded = Simulation.dispatch(loaded, {"type": "select-request", "pr_id": str(first_packet.id)})
	for id: String in first_packet.violations:
		loaded = Simulation.dispatch(loaded, Simulation.Catalog.audit_citation(first_packet, id))
	loaded = Simulation.dispatch(loaded, {"type": "review", "verdict": "approve" if first_packet.violations.is_empty() else "request_changes"})
	for snapshot: Dictionary in [initial, loaded]:
		var first_ui = Interface.new()
		root.add_child(first_ui)
		first_ui.render_state(snapshot)
		first_ui.hide()
		for frame: int in range(8):
			await process_frame
		first_ui.show()
		first_ui.focus_workspace()
		for frame: int in range(6):
			await process_frame
		first_ui._open_app("chat")
		for contact: String in ["Maya", "company", "Inez", "Theo", "Maya"]:
			first_ui._select_chat_contact(contact)
			for frame: int in range(8):
				await process_frame
			var chat = first_ui._windows["chat"]
			check(chat.size.x <= 800.0, "First Slouch open and contact changes must retain the arranged width without a reset")
			check(chat.get_global_rect().end.x <= root.size.x, "Slouch minimize button must remain inside the game window")
			for node: Node in first_ui._chat_messages.find_children("*", "Label", true, false):
				var label: Label = node as Label
				if label.autowrap_mode != TextServer.AUTOWRAP_OFF and label.text.length() > 100:
					check(label.get_line_count() > 1, "Long Slouch messages must wrap within the first-open viewport")
		first_ui.queue_free()
		await process_frame
