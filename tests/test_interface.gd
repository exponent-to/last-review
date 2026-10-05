extends SceneTree
## Integration smoke test: native controls, authored content, and real transitions.
const Simulation = preload("res://native/simulation.gd")
const Chat = preload("res://content/chat.gd")
const Catalog = preload("res://content/catalog.gd")
const Interface = preload("res://native/interface.gd")
const Office = preload("res://native/computer_frame.gd")
const Encounters = preload("res://content/encounters.gd")
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
	await _test_loaded_evening()
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
	_test_no_slouch()
	check(ui._clock_label.text == "09:00", "Desktop clock must start at nine")
	check(ui._pr_id.text == "PR-1042 / AWAITING REVIEW" and not ui._diff.text.is_empty(), "The day's first PR is already on the desk at shift start")
	check(ui.find_children("*", "OptionButton", true, false).size() == 1, "Review has no arrived-PR picker; the only dropdown is the file picker")
	for button: Node in ui._windows.review.find_children("*", "Button", true, false):
		check(not button.text.contains("NEXT PR"), "Review has no NEXT PR button")
	state = Simulation.advance(state, 20)
	ui._windows.review.minimize_window()
	ui.render_state(state)
	ui._open_notification("review", str(Catalog.request_at(0).id))
	check(ui._windows["review"].visible and ui._app_counts.review == 0, "The review notification opens Review")
	check(ui._file_picker.item_count == 2, "The first review must expose both changed files")
	var first_diff: String = ui._diff.text
	ui._diff.set_caret_line(4)
	ui._file_picker.item_selected.emit(1)
	check(ui._diff.text != first_diff and ui._file_label.text == Catalog.request_at(0).files[1].path, "Selecting another file must show its own diff")
	ui._file_picker.item_selected.emit(0)
	for frame in range(3):
		await process_frame
	check(ui._diff.text == first_diff and ui._diff.get_caret_line() == 4, "Returning to a file must preserve its reading position")
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
	ui._diff.set_caret_line(ui._row_for_line(int(finding.line)))
	ui._point_at(-1)
	check(ui._evidence.line == finding.line and ui._evidence_label.text.contains("selected"), "Clicking a code line selects it as evidence")
	check(ui._flag_buttons.P01 is CheckBox and ui._windows.review.is_ancestor_of(ui._flag_buttons.P01), "The citation slip lives in Review's right sidebar")
	ui._flag_buttons.P01.pressed.emit()
	check(state.selected_rules == ["P01"] and state.citation_evidence.P01 == {"path": finding.path, "line": finding.line}, "Picking a standard cites the flagged line")
	check(ui._evidence.is_empty() and ui._flag_buttons.P01.button_pressed and ui._slip_rows.P01.where.text.contains("LINE %d" % int(finding.line)), "The slip ticks the rule and shows where it was cited")
	var other_line: int = 2 if int(finding.line) == 1 else 1
	ui._diff.set_caret_line(ui._row_for_line(other_line))
	ui._point_at(-1)
	check(not ui._evidence.is_empty() and ui._flag_buttons.P01.button_pressed, "Selecting another line keeps the existing citation ticked")
	ui._flag_buttons.P01.pressed.emit()
	check(state.selected_rules == ["P01"] and int(state.citation_evidence.P01.line) == other_line, "Re-flagging a rule moves its citation")
	ui._diff.set_caret_line(ui._row_for_line(int(finding.line)))
	ui._point_at(-1)
	ui._flag_buttons.P01.pressed.emit()
	check(int(state.citation_evidence.P01.line) == int(finding.line), "The citation can be moved back to the real evidence")
	ui._flag_buttons.P02.pressed.emit()
	check(not state.selected_rules.has("P02") and not ui._flag_buttons.P02.button_pressed, "Ticking with no line selected asks for the evidence first")
	check(ui._approve.disabled and not ui._reject.disabled, "Citations must gate the correct decision controls")
	ui._clear_citations()
	check(state.selected_rules.is_empty(), "Clear citations must update simulation state")
	# With no citations, approval is available and CHANGES REQUESTED is a reason-free rejection.
	check(not ui._approve.disabled and not ui._reject.disabled, "Clearing citations restores approval and leaves reason-free rejection available")
	check(not ui._ai_note.text.contains(str(Catalog.request_at(0).ai_note)), "AI advice must be hidden before consultation")
	check(not ui._consult.visible, "Consultation stays hidden until Wednesday")
	var saw_revision := false
	var pushbacks := 0
	var saw_typing := false
	var evenings := 0
	while state.phase != "complete":
		if Simulation.active_request(state).is_empty() and state.phase == "review":
			# An author revising at the desk stays seated, typing, until v2 replaces the PR.
			var typing: Dictionary = Encounters.typing(state)
			var header: String = "REVIEW / DESK CLEAR" if typing.is_empty() else Catalog.display_id(str(typing.revision_id)) + " / BEING REVISED"
			if not typing.is_empty():
				saw_typing = true
				check(ui._banter.visible and ui._banter.typing and ui._banter.speaker == str(typing.author), "A revise-now author stays at the desk, typing")
			check(ui._pr_id.text == header and ui._approve.disabled and ui._app_counts.review == 0, "Between PRs the desk is clear and nothing is waiting unread")
			var coming: bool = int(state.desk_at) >= 0 and int(state.desk_at) < Simulation.Catalog.shift_seconds()
			state = Simulation.advance(state, int(state.desk_at) - int(state.shift_seconds) if coming else Simulation.Catalog.shift_seconds())
			ui._windows.review.minimize_window()
			ui.render_state(state)
			if coming:
				check(ui._app_counts.review == 1 and ui._app_badges.review.visible, "A PR landing on the desk shows a review badge of exactly one")
				check(ui._notifications._items.any(func(item: Dictionary) -> bool: return item.app == "review" and item.target == state.active_request_id), "A PR landing on the desk shows a review notification card")
		if state.phase == "review":
			var packet: Dictionary = Catalog.packet(state, state.active_request_id)
			# Alternate the two ways to the desk: the review card and the REVIEW icon.
			if ui._windows.review.visible or state.decisions.size() % 2 == 0: ui._home_icons.review.pressed.emit()
			else: ui._open_notification("review", str(packet.id))
			check(ui._windows.review.visible and ui._app_counts.review == 0, "REVIEW and its notification open the desk PR and read it")
			check(ui._pr_id.text == Catalog.display_id(str(packet.id)) + " / AWAITING REVIEW", "The form shows the desk PR, revisions as 'PR · vN'")
			if int(packet.revision) > 1:
				saw_revision = true
				check(ui._pr_id.text.contains(" · v%d" % int(packet.revision)) and ui._pr_context.text.contains(str(packet.message)), "Revisions show their version and their own author note")
			for rule_id: String in packet.violations:
				_command(Simulation.Catalog.audit_citation(packet, rule_id))
			if packet.violations.is_empty():
				ui._approve.pressed.emit()
			else:
				ui._reject.pressed.emit()
			var disputed: Dictionary = Encounters.pending(state)
			if not disputed.is_empty():
				# The author pushes back: the stamps lock, the disputed citation is outlined,
				# and INSIST / WITHDRAW wait under the bubble.
				pushbacks += 1
				check(ui._banter.asking and ui._banter.insist_button.is_visible_in_tree() and ui._banter.withdraw_button.is_visible_in_tree(), "Pushback shows INSIST and WITHDRAW")
				check(ui._reject.disabled and ui._approve.disabled and ui._flag_buttons[str(disputed.disputed)].disabled, "Pushback holds the stamps and the slip until it is answered")
				check(ui._pr_id.text.ends_with("PUSHED BACK") and ui._slip_rows[str(disputed.disputed)].where.text.contains("DISPUTED"), "The form and slip show the dispute")
				if pushbacks % 3 == 0:
					ui._banter.withdraw_button.pressed.emit()
					check(state.active_request_id == str(packet.id) and str(disputed.disputed) not in state.selected_rules and Encounters.pending(state).is_empty(), "WITHDRAW drops the citation and reopens the review")
					check(not ui._banter.asking and ui._banter.speaker == str(packet.author), "The author stays at the desk after WITHDRAW")
					# Start the citations over; the next pass cites and stamps again.
					ui._clear_citations()
					continue
				ui._banter.insist_button.pressed.emit()
				check(Encounters.pending(state).is_empty() and state.decisions[-1].pr_id == str(packet.id), "INSIST sends the change request")
			check(ui._feedback.text.contains(Catalog.display_id(str(packet.id))), "Audit must identify the previous PR")
			check(not ui._feedback.text.contains("CORRECT") and not ui._feedback.text.contains("Required:"), "Sent confirmation must not grade a review or reveal its answers")
			check(not ui._feedback.text.contains("Trust +") and not ui._feedback.text.contains("Trust -"), "Audit must omit numeric social/stat deltas")
			# The archived chat content still hears the verdict; the desktop never shows it.
			var has_reaction: bool = false
			for message: Dictionary in Chat.messages(state, str(packet.author)):
				if str(message.get("kind", "")) == "reaction":
					has_reaction = true
			check(has_reaction, "Coworker conversation content must contain a review reaction")
			check(not ui._notifications._items.any(func(item: Dictionary) -> bool: return item.app not in ["review", "browser", "system"]), "Coworker messages never reach the ticker")
		if state.phase == "debrief":
			check(not ui._windows.has("shift") and not ui._windows.has("chat"), "Closing opens no results window and no chat")
			_check_evening(false)
			evenings += 1
			# Choose the evening through the panel's own buttons, in turn.
			var choices: Array = ui._evening_buttons.find_children("*", "Button", true, false)
			var day_before := int(state.day)
			choices[evenings % choices.size()].pressed.emit()
			check(int(state.day) == day_before + 1 or state.phase == "complete", "Choosing an evening advances the day")
			check(state.shift_history[-1].evening_choice == ["rest", "socialize", "study"][evenings % 3], "Each evening button sends its own choice")
			if state.phase == "review":
				check(not ui._windows.evening.visible and not ui._dock_buttons.evening.visible, "The end-of-day panel goes away with the evening")
			office.set_story(int(state.day), int(state.autonomy))
			_check_active_rules(int(state.day))
	check(state.phase == "complete" and saw_revision, "Authored campaign must finish, with revisions coming back to the desk")
	check(pushbacks > 0 and saw_typing, "The campaign includes pushbacks and authors revising at the desk")
	check(evenings == Catalog.campaign_days().size(), "Every day ends at the end-of-day panel")
	_check_evening(true)
	check(int(state.day) == 10 and ui._complete_button.is_visible_in_tree() and not ui._evening_buttons.visible, "Day 10 ends with RETURN TO MAIN MENU instead of the evening choices")
	var menu := [0]
	ui.menu_requested.connect(func() -> void: menu[0] += 1)
	ui._complete_button.pressed.emit()
	check(menu[0] == 1, "RETURN TO MAIN MENU asks the application for the menu")
	ui._home_icons.review.pressed.emit()
	check(ui._windows.review.visible and ui._pr_id.text == "REVIEW / ASSIGNMENT CLOSED" and ui._diff.text.is_empty(), "REVIEW still opens after the assignment, and says the desk is closed")
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
	var shown := 0
	for rule: Dictionary in Catalog.rules():
		var should_show: bool = Catalog.rule_active(str(rule.id), day)
		check(ui._slip_rows[str(rule.id)].panel.visible == should_show, "Slip rows must match each standard's active days")
		if should_show: shown += 1
	check(shown == active.size(), "The slip lists exactly the current day's standards")

func _test_desktop() -> void:
	var review = ui._windows["review"]
	for window in ui._windows.values():
		check(not window.visible and not window.launched, "HOME must begin with every application closed")
	for button in ui._dock_buttons.values():
		check(not button.visible, "Taskbar must omit applications that have not been launched")
	check(ui._home_icons.keys() == ["review", "jiro", "pipeline", "browser", "system"], "HOME holds the five application launchers")
	check(ui._home_icons.review.visible and not ui._home_icons.jiro.visible and not ui._home_icons.pipeline.visible, "Jiro and Pipeline are not installed on the first Monday")
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

## Slouch is off the desktop: no icon, window, taskbar entry, badge, or ticker cards,
## and nothing on screen mentions it.
func _test_no_slouch() -> void:
	check(not ui._windows.has("chat") and not ui._home_icons.has("chat") and not ui._dock_buttons.has("chat"), "There is no Slouch window, icon, or taskbar entry")
	check(not ui._app_counts.has("chat") and not ui._app_badges.has("chat") and not Interface.Notifications.NAMES.has("chat"), "Slouch has no badge and no notification source")
	check(not ui._home_icons.has("evening") and not ui._windows.evening.visible and not ui._dock_buttons.evening.visible, "The end-of-day panel has no icon and stays closed during the shift")
	for item: Dictionary in ui._notifications._items:
		check(item.app != "chat" and not item.card.tooltip_text.contains("Your team has left you messages"), "No Slouch ticker cards")
	ui._browse("procedure")
	ui._browse("memo")
	for node: Node in ui.find_children("*", "", true, false):
		var words := ""
		if node is Button or node is Label: words = str(node.text)
		if node is Control: words += " " + str(node.tooltip_text)
		if node is Interface.DesktopWindow: words += " " + str(node.window_title)
		check(not words.to_lower().contains("slouch"), "Nothing on the desktop mentions Slouch: " + words.strip_edges())
	ui._browse("home")

## Morgan's end-of-day panel: open by itself, her portrait, the day's notes, her closing
## words, and the evening choices (or, once the assignment is over, the way to the menu).
func _check_evening(final: bool) -> void:
	var evening = ui._windows.evening
	var expected: Dictionary = Chat.evening(state)
	check(evening.visible and evening.launched and evening._active and ui._dock_buttons.evening.visible, "Closing opens the end-of-day panel by itself")
	check(not evening.close_button.visible, "The end-of-day panel cannot be closed before the evening is chosen")
	check(not ui._windows.review.visible, "Closing puts the desk away")
	check(ui._evening_face.is_visible_in_tree() and ui._evening_face is TextureRect and ui._evening_face.texture == Interface.Portraits.texture_for("Morgan"), "The panel shows Morgan's cat portrait")
	check(ui._evening_when.text.begins_with(Interface.day_label(int(state.day))), "The panel names the day that just closed")
	var notes: Array = ui._evening_notes.find_children("*", "Label", true, false).map(func(label: Node) -> String: return str(label.text))
	var closing: Array = ui._evening_closing.get_children().map(func(label: Node) -> String: return str(label.text))
	check(not expected.is_empty() and notes == expected.notes and ui._evening_notes_heading.visible != notes.is_empty(),"The panel shows Morgan's notes from today")
	check(not closing.is_empty() and closing == expected.closing, "The panel shows Morgan's closing message")
	for note: Dictionary in Encounters.morgan(state):
		if int(note.day) == int(state.day): check(str(note.text) in notes, "Today's escalations and abandons reach the panel: " + str(note.text))
	if int(state.shift_history[-1].get("handed_off", 0)) > 0:
		check(notes.any(func(text: String) -> bool: return text.contains("Helios picked up")), "Work handed to Helios reaches the panel")
	var shown := " ".join(notes + closing) + ui._evening_when.text
	var graded := RegEx.create_from_string("\\bP\\d\\d\\b|[Ss]core|Trust|Stress|credits|CORRECT|\\d+%")
	check(graded.search(shown) == null, "The panel carries no scores or rule IDs: " + shown)
	if final:
		check(ui._complete_button.is_visible_in_tree() and not ui._evening_buttons.visible, "After the last evening the panel offers RETURN TO MAIN MENU")
	else:
		var buttons: Array = ui._evening_buttons.find_children("*", "Button", true, false)
		var texts: Array = buttons.map(func(button: Node) -> String: return str(button.text))
		check(ui._evening_buttons.is_visible_in_tree() and texts == ["GO HOME", "GET DINNER", "STUDY"] and not ui._complete_button.visible, "The panel offers GO HOME, GET DINNER, and STUDY")
		_check_evening_descriptions(buttons)


## Each evening choice says what it does, under its button and on hover, in words.
func _check_evening_descriptions(buttons: Array) -> void:
	# What each choice does (Simulation._evening), as the words must convey it.
	var meaning := {"GO HOME": ["calmer"], "GET DINNER": ["Costs", "coworkers", "unwind"], "STUDY": ["Morgan", "tired"]}
	var digits := RegEx.create_from_string("\\d")
	check(buttons.size() == Interface.EVENINGS.size(), "Every evening choice has a button")
	for index in range(buttons.size()):
		var button: Button = buttons[index]
		var about: Label = button.get_meta("about")
		var expected: String = Interface.EVENINGS[index].about
		check(about.is_visible_in_tree() and about.text == expected and button.tooltip_text == expected, "%s shows what it does, under the button and as its tooltip" % button.text)
		check(digits.search(about.text) == null, "%s describes its effect without numbers" % button.text)
		for word: String in meaning[button.text]:
			check(about.text.contains(word), "%s's description conveys its effect (%s)" % [button.text, word])

## Loading a save at closing, or after the assignment, opens Morgan's panel straight away.
func _test_loaded_evening() -> void:
	var closed: Dictionary = Simulation.advance(Simulation.initial_state(), Catalog.shift_seconds())
	var finished: Dictionary = closed.duplicate(true)
	while finished.phase != "complete":
		finished = Simulation.dispatch(Simulation.advance(finished, Catalog.shift_seconds()), {"type": "next-day", "choice": "rest"})
	for snapshot: Dictionary in [closed, finished]:
		var loaded = Interface.new()
		root.add_child(loaded)
		for frame in range(3): await process_frame
		loaded.render_state(snapshot)
		for frame in range(3): await process_frame
		var done: bool = snapshot.phase == "complete"
		var evening = loaded._windows.evening
		check(evening.visible and evening.get_global_rect().size.x > 400 and loaded._desktop.get_global_rect().encloses(evening.get_global_rect()), "A loaded evening opens the end-of-day panel on the desktop")
		check(loaded._evening_buttons.visible != done and loaded._complete_button.visible == done, "Day %d offers %s" % [int(snapshot.day), "RETURN TO MAIN MENU" if done else "the evening choices"])
		check(loaded._notifications._items.is_empty() and not loaded._app_badges.browser.visible, "An evening load announces no morning memo or standards")
		if not done:
			for button: Button in loaded._evening_buttons.find_children("*", "Button", true, false):
				var about: Label = button.get_meta("about")
				check(about.get_global_rect().position.y >= button.get_global_rect().end.y and evening.get_global_rect().encloses(about.get_global_rect()), "%s's description sits under it, inside the panel" % button.text)
				check(about.get_line_count() <= 3, "%s's description stays short" % button.text)
		if done:
			check(int(snapshot.day) == 10 and loaded._evening_when.text.begins_with("WEEK 2 · FRIDAY"), "The final panel is the second Friday's")
			var last: Node = loaded._evening_closing.get_child(loaded._evening_closing.get_child_count() - 1)
			check(str(last.text) == Chat.evening(snapshot).closing[-1] and str(last.text).contains("review gate"), "Morgan's final word closes the assignment")
		loaded._home_icons.review.pressed.emit()
		check(loaded._windows.review.visible and loaded._pr_id.text == ("REVIEW / ASSIGNMENT CLOSED" if done else "REVIEW / SHIFT CLOSED"), "REVIEW opens off the clock and says the desk is closed")
		loaded.queue_free()
		await process_frame
