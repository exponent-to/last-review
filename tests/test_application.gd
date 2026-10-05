extends SceneTree
## Verify the opening cannot accidentally submit a review during its handoff.
const Main = preload("res://native/main.gd")
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 900)
	Main.SaveStore.storage_root = "user://application-slot-test-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(Main.SaveStore.storage_root)
	# Pre-release: a save from an older format is deleted when the application starts.
	var outdated := Main.Simulation.initial_state()
	outdated.version = Main.Simulation.SAVE_VERSION - 1
	var stale := FileAccess.open(Main.SaveStore.slot_path(3), FileAccess.WRITE)
	stale.store_string(JSON.stringify(outdated))
	stale.close()
	var app := Main.new()
	root.add_child(app)
	await process_frame
	_check(not FileAccess.file_exists(Main.SaveStore.slot_path(3)) and not Main.SaveStore.has_save(3), "Startup deletes an outdated save.")
	_check(app.menu._load_game.disabled, "With only an outdated save, there is nothing to load.")
	app.set_process(false)
	app._tick_shift(30.0)
	_check(int(app.state.shift_seconds) == 0 and app.menu.visible and not app.interface.visible, "Main menu must appear before play and stop time.")
	app.menu._new_game.pressed.emit()
	_check(not is_instance_valid(app._cold_open), "New Game presents slots first.")
	app.menu._slot_buttons[1].pressed.emit()
	_check(app.active_slot == 2 and Main.SaveStore.load_game(2).ok, "New Game immediately creates a resumable save in the chosen slot.")
	await process_frame
	_check(is_instance_valid(app._cold_open) and not app.interface.visible, "New Game plays the cold open before the workstation.")
	app._tick_shift(60.0)
	_check(int(app.state.shift_seconds) == 0, "Cold open cannot spend shift time.")
	app._cold_open.advance_sequence(30.0)
	app._cold_open._open_mail(-1)
	app._cold_open._sign_offer()
	app._cold_open.advance_sequence(2.0)
	await process_frame
	_check(not app.tutorial.is_empty() and app.state.decisions.is_empty(), "New Game starts practice without career consequences.")
	_check(app.interface.visible and not app.menu.visible, "The signed offer hands off to the orientation workstation.")
	var release := InputEventKey.new()
	release.keycode = KEY_ENTER
	release.pressed = false
	root.push_input(release)
	await process_frame
	for window: Control in app.interface._windows.values():
		_check(not window.visible, "The opening must arrive at HOME with applications closed.")
	_check(app.state.request_index == 0 and app.state.decisions.is_empty(), "New Game key release must not approve the first PR.")
	_check(root.gui_get_focus_owner() == app.interface, "Workstation handoff must focus a neutral surface.")
	_check(not app.interface._briefing_dialog.visible, "New Game key release must not open an unrelated control.")
	for frame in range(4): await process_frame
	_check(app.interface._tutorial_panel.size.y < 250, "Orientation instructions must fit a compact panel after text wraps.")
	_check(app.interface._notifications._items.is_empty(), "Orientation must not show ambient notifications.")
	var panel: PanelContainer = app.interface._tutorial_panel
	var start: Vector2 = panel.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(20, 10)
	app.interface._tutorial_drag_input(press)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(20, 10) + Vector2(-300, 200)
	app.interface._tutorial_drag_input(drag)
	press.pressed = false
	app.interface._tutorial_drag_input(press)
	_check(panel.position.is_equal_approx(start + Vector2(-300, 200)), "The orientation panel follows a drag.")
	app._render()
	app.interface._sync_tutorial_pointer()
	_check(panel.position.is_equal_approx(start + Vector2(-300, 200)), "A dragged orientation panel keeps its place.")
	drag.position = Vector2(-5000, -5000)
	press.pressed = true
	app.interface._tutorial_drag_input(press)
	app.interface._tutorial_drag_input(drag)
	_check(panel.position == Vector2.ZERO, "Dragging cannot push the panel off the monitor.")
	_check(not app.interface._app_badges.browser.visible, "Orientation hides Monday's memo badge.")
	_check(not app.interface._windows.has("chat") and not app.interface._home_icons.has("chat"), "Orientation has no chat app to open.")
	app._tick_shift(999.0)
	_check(int(app.state.shift_seconds) == 0, "Orientation must remain untimed.")
	# Orientation goes straight to REVIEW: Maya's practice PR is already on the desk.
	app.interface._tutorial_next.pressed.emit()
	_check(int(app.tutorial.stage) == Main.Tutorial.STAGE_OPEN_REVIEW and app.interface._tutorial_title.text == "OPEN REVIEW", "Orientation's first step is to open REVIEW.")
	app.interface._sync_tutorial_pointer()
	_check(app.interface._tutorial_pointer._target_ref.get_ref() == app.interface._home_icons.review, "The arrow points at the REVIEW icon.")
	app._on_command({"type": "chat-reply", "contact": "Maya", "pr_id": "PR-1042", "reply_id": "clarify"})
	_check(app.state.chat_replies.is_empty(), "Live play rejects removed chat reply commands.")
	app.interface._home_icons.review.pressed.emit()
	_check(int(app.tutorial.stage) == Main.Tutorial.STAGE_INSPECT and app.interface._windows.review.visible, "Opening REVIEW progresses directly to file inspection.")
	app.interface._sync_tutorial_pointer()
	_check(app.interface._tutorial_pointer._target_ref.get_ref() == app.interface._file_picker, "The arrow moves to the file dropdown.")
	app.interface._file_picker.item_selected.emit(1)
	_check(int(app.tutorial.stage) == Main.Tutorial.STAGE_STANDARDS, "Inspecting both files progresses orientation.")
	app.interface._open_app("browser")
	app.interface._browse("standards")
	app._on_command({"type": "review", "verdict": "approve"})
	_check(int(app.tutorial.stage) == Main.Tutorial.STAGE_CITE and app.state.decisions.is_empty(), "A mistaken practice review can be retried without consequences.")
	app._on_command(Main.Simulation.Catalog.audit_citation(Main.Simulation.Catalog.request_at(0), "P01"))
	app._on_command({"type": "review", "verdict": "request_changes"})
	_check(int(app.tutorial.stage) == Main.Tutorial.STAGE_READY, "A complete practice review reaches the handoff.")
	_check(app.interface._notifications._items.all(func(item: Dictionary) -> bool: return item.app == "system"), "Orientation completes with only direct guidance on the ticker, no chat cards.")
	app.interface._tutorial_next.pressed.emit()
	_check(app.tutorial.is_empty() and app.state == Main.Simulation.initial_state(), "Monday must start with fresh time, pay, relationships, and decisions.")
	_check(app.interface.morning_active and app.interface._browser_path == "news", "Monday opens the morning news before work.")
	app._tick_shift(60.0)
	_check(int(app.state.shift_seconds) == 0, "Morning reading does not spend the shift.")
	app.interface._browse("memo")
	app.interface._finish_morning()
	_check(not app.interface.morning_active, "Reading the memo and beginning work releases the clock.")
	var desk_cards: Array = app.interface._notifications._items.filter(func(item: Dictionary) -> bool: return item.app == "review" and item.target == app.state.active_request_id)
	_check(desk_cards.size() == 1 and app.interface._app_badges.review.visible, "BEGIN SHIFT brings back the desk PR's review card and badge, so REVIEW is one click away.")
	app.interface._open_notification("review", str(app.state.active_request_id))
	_check(app.interface._windows.review.visible and app.interface._app_counts.review == 0, "The review card opens the PR on the desk.")
	app._clock_fraction = 0.0
	app._tick_shift(1.25)
	app._tick_shift(0.75)
	_check(int(app.state.shift_seconds) == 2, "Clock must accumulate fractional frames into whole simulation seconds.")
	app._toggle_pause()
	app._tick_shift(60.0)
	_check(int(app.state.shift_seconds) == 2 and app.interface._pause_overlay.visible, "Pause must stop time and cover the desktop.")
	app._toggle_pause()
	app._tick_shift(1.0)
	_check(int(app.state.shift_seconds) == 3, "Resume must continue without catching up paused time.")
	app._on_focus_exited()
	app._tick_shift(60.0)
	app._on_focus_entered()
	_check(int(app.state.shift_seconds) == 3 and app.paused, "Switching away must pause and require an explicit resume.")
	app._toggle_pause()
	app.scenery.set_time_of_day(540)
	var morning: Color = app.scenery._sky_color()
	app.scenery.set_time_of_day(1080)
	_check(morning.get_luminance() > app.scenery._sky_color().get_luminance(), "Office must darken from morning to closing time.")
	app._tick_shift(297.0)
	_check(app.state.phase == "debrief" and app.interface._clock_label.text == "18:00", "Clock expiry must stop work at five real minutes.")
	var closed: Dictionary = app.state.duplicate(true)
	app._tick_shift(120.0)
	_check(app.state == closed, "Closed shifts must not keep charging time or wages.")
	# Closing opens Morgan's end-of-day panel by itself, with the evening choice.
	var evening: Control = app.interface._windows.evening
	_check(evening.visible and evening._active and app.interface._dock_buttons.evening.visible, "Closing opens the end-of-day panel on the desktop.")
	_check(not app.interface._windows.review.visible, "The desk is put away at closing.")
	var choices: Array = app.interface._evening_buttons.find_children("*", "Button", true, false)
	_check(app.interface._evening_buttons.is_visible_in_tree() and choices.map(func(button: Button) -> String: return button.text) == ["GO HOME", "GET DINNER", "STUDY"], "The panel offers the evening choices.")
	choices[0].pressed.emit()
	_check(int(app.state.day) == 2 and app.state.shift_history[-1].evening_choice == "rest", "GO HOME uses the next-day command to start the next shift.")
	_check(not evening.visible and not evening.launched and not app.interface._dock_buttons.evening.visible, "The panel closes when the evening is chosen.")
	_check(int(app.state.day) == 2 and app.interface.morning_active, "Every new workday gets its own morning news and memo.")
	app._tick_shift(60.0)
	_check(int(app.state.shift_seconds) == 0, "Next-day reading also leaves all five minutes available.")
	app._on_motion(false)
	app._on_focus_exited()
	app._on_focus_entered()
	_check(not app.scenery.is_processing(), "Focus restore must honor disabled background motion.")
	app._new_game()
	var skip := InputEventKey.new()
	skip.pressed = true
	skip.keycode = KEY_ESCAPE
	app._cold_open._input(skip)
	await process_frame
	_check(not is_instance_valid(app._cold_open) and app.interface.visible, "Escape consumes its input before the cold-open handoff removes the scene.")
	app._on_save()
	_check(Main.SaveStore.load_game(app.active_slot).ok, "Saving writes the active slot.")
	app._on_load(2)
	_check(app.active_slot == 2 and not app.tutorial.is_empty(), "Loading a slot selects its saved orientation.")
	app.free()
	for name in DirAccess.get_files_at(Main.SaveStore.storage_root):
		DirAccess.remove_absolute(Main.SaveStore.storage_root.path_join(name))
	DirAccess.remove_absolute(Main.SaveStore.storage_root)
	print("Native application handoff: %d failures" % failures)
	quit(1 if failures else 0)
