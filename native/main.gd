extends Node

const Simulation = preload("res://native/simulation.gd")
const SaveStore = preload("res://native/save_store.gd")
const GameInterface = preload("res://native/interface.gd")
const ComputerFrame = preload("res://native/computer_frame.gd")
const MainMenu = preload("res://native/main_menu.gd")
const ColdOpen = preload("res://native/cold_open.gd")
const Tutorial = preload("res://native/tutorial.gd")

var state: Dictionary = {}
var interface: GameInterface
var scenery: ComputerFrame
var motion_enabled: bool = true
var paused: bool = false
var _clock_fraction: float = 0.0
var _focused: bool = true
var menu: MainMenu
var tutorial: Dictionary = {}
var _cold_open: ColdOpen
var active_slot := 1

func _ready() -> void:
	get_window().min_size = Vector2i(1120, 800)
	state = Simulation.initial_state()
	_build_interface()
	interface.hide()
	menu = MainMenu.new()
	add_child(menu)
	menu.new_game_requested.connect(_new_game)
	menu.load_game_requested.connect(_on_load)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	menu.set_slots(SaveStore.list_slots())

func _build_interface() -> void:
	if is_instance_valid(interface):
		remove_child(interface)
		interface.queue_free()
	interface = GameInterface.new()
	add_child(interface)
	interface.command_requested.connect(_on_command)
	interface.save_requested.connect(_on_save)
	interface.load_requested.connect(_on_load)
	interface.reset_requested.connect(_on_reset)
	interface.motion_changed.connect(_on_motion)
	interface.pause_requested.connect(_toggle_pause)
	interface.menu_requested.connect(_return_to_menu)
	interface.tutorial_event.connect(_tutorial_event)
	interface.tutorial_continue_requested.connect(_tutorial_continue)
	scenery = ComputerFrame.new()
	interface.scene_host.add_child(scenery)
	interface.set_save_slot(active_slot)
	_render()

func _new_game(slot: int = 1) -> void:
	if is_instance_valid(_cold_open): return
	var result := SaveStore.save_game(Tutorial.initial_practice_state(), Tutorial.initial_progress(), slot)
	if not result.ok:
		menu.show_error(str(result.error))
		return
	active_slot = slot
	menu.hide()
	interface.hide()
	_cold_open = ColdOpen.new()
	add_child(_cold_open)
	_cold_open.finished.connect(_start_orientation)
	_cold_open.set_motion(motion_enabled)

func _start_orientation() -> void:
	if is_instance_valid(_cold_open):
		remove_child(_cold_open)
		_cold_open.queue_free()
		_cold_open = null
	paused = false
	_clock_fraction = 0.0
	tutorial = Tutorial.initial_progress()
	state = Tutorial.initial_practice_state()
	_build_interface()
	interface.focus_workspace()

func _return_to_menu() -> void:
	var result := SaveStore.save_game(state, tutorial, active_slot)
	if not result.ok:
		interface.notify(str(result.error), true)
		return
	interface.hide()
	menu.show_error("")
	menu.set_slots(SaveStore.list_slots())
	menu.show_home()
	menu.show()
	menu.focus_default()

func _tutorial_continue() -> void:
	if tutorial.is_empty(): return
	if int(tutorial.stage) == 7:
		tutorial = {}
		state = Simulation.initial_state()
		_clock_fraction = 0.0
		paused = false
		_build_interface()
		interface.focus_workspace()
		interface.begin_morning()
	else:
		_tutorial_event({"type": "welcome-start"})

func _tutorial_event(event: Dictionary) -> void:
	if tutorial.is_empty(): return
	var next := Tutorial.observe(tutorial, event, state)
	if next != tutorial:
		tutorial = next
		interface.render_tutorial(tutorial, Tutorial.prompt(tutorial))


func _notification(what: int) -> void:
	# Application focus excludes our own menus and popup windows. A file picker
	# must not pause the shift just because the main window yields to its menu.
	if not is_instance_valid(interface): return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_focus_exited()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_on_focus_entered()

func _process(delta: float) -> void:
	_tick_shift(delta)

func _tick_shift(delta: float) -> void:
	if not tutorial.is_empty() or not is_instance_valid(interface) or not interface.visible or paused or not _focused or state.get("phase") != "review":
		return
	if interface._confirmation.visible or interface.morning_active:
		return
	_clock_fraction += maxf(0.0, delta)
	var seconds := int(_clock_fraction)
	if seconds == 0:
		return
	_clock_fraction -= seconds
	state = Simulation.advance(state, seconds)
	_render()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and interface.visible and not interface._confirmation.visible:
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	if state.get("phase") == "review":
		_set_paused(not paused)

func _set_paused(value: bool) -> void:
	paused = value
	interface.set_paused(value)
	scenery.set_motion(motion_enabled and _focused and not paused)

func _render() -> void:
	interface.render_state(state)
	scenery.set_story(int(state.day), int(state.autonomy))
	scenery.set_time_of_day(Simulation.clock_minutes(state))
	interface.render_tutorial(tutorial, {} if tutorial.is_empty() else Tutorial.prompt(tutorial))

func _on_command(command: Dictionary) -> void:
	# Historical replies remain replayable in saves, but Slouch no longer sends messages.
	if command.get("type") == "chat-reply": return
	if paused:
		return
	if interface.morning_active:
		interface.notify("Read today's memo in INTRANET, then choose BEGIN SHIFT.")
		return
	if not tutorial.is_empty() and command.get("type") == "review" and int(tutorial.stage) != 6:
		interface.notify("Finish the orientation steps before sending this practice review.")
		return
	var previous_day: int = int(state.day)
	state = Simulation.dispatch(state, command)
	if not tutorial.is_empty():
		if command.get("type") == "review" and not state.decisions.is_empty():
			if bool(state.decisions[-1].correct):
				_tutorial_event({"type": "correct-submit"})
			else:
				state = Tutorial.retry_practice_state(state)
				interface.notify("Try again: click the line with load-bearing, pick P01, then stamp CHANGES REQUESTED.")
	if int(state.day) != previous_day:
		_clock_fraction = 0.0
	_render()
	if int(state.day) != previous_day and state.phase == "review":
		interface.begin_morning()

func _on_save() -> void:
	var result: Dictionary = SaveStore.save_game(state, tutorial, active_slot)
	interface.notify("Saved to Slot %d on this computer." % active_slot if result.ok else str(result.error), not result.ok)

func _on_load(slot: int = 0) -> void:
	var target_slot := active_slot if slot == 0 else slot
	var result: Dictionary = SaveStore.load_game(target_slot)
	if not result.ok:
		if menu.visible:
			menu.show_error(str(result.error))
		else:
			interface.notify(str(result.error), true)
		return
	active_slot = target_slot
	state = result.state
	tutorial = result.get("tutorial", {})
	_clock_fraction = 0.0
	menu.hide()
	_build_interface()
	_set_paused(state.phase == "review")
	if tutorial.is_empty() and state.phase == "review" and int(state.shift_seconds) == 0:
		interface.begin_morning()
	interface.notify(str(result.error) if not str(result.get("error", "")).is_empty() else "Saved game loaded.")

func _on_reset() -> void:
	# Preserve the current run before choosing a separate or replacement slot.
	_return_to_menu()
	if menu.visible: menu._show_slots("new")

func _on_motion(enabled: bool) -> void:
	motion_enabled = enabled
	if is_instance_valid(menu): menu.set_motion(enabled)
	if is_instance_valid(_cold_open): _cold_open.set_motion(enabled)
	if is_instance_valid(scenery):
		scenery.set_motion(enabled and _focused and not paused)

func _on_focus_exited() -> void:
	_focused = false
	if is_instance_valid(interface) and interface.visible and state.get("phase") == "review":
		_set_paused(true)
	if is_instance_valid(scenery):
		scenery.set_motion(false)

func _on_focus_entered() -> void:
	_focused = true
	if is_instance_valid(scenery):
		scenery.set_motion(motion_enabled and not paused)
