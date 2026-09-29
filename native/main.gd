extends Node

const Simulation = preload("res://native/simulation.gd")
const SaveStore = preload("res://native/save_store.gd")
const GameInterface = preload("res://native/interface.gd")
const ComputerFrame = preload("res://native/computer_frame.gd")
const Intro = preload("res://native/intro.gd")

var state: Dictionary = {}
var interface: GameInterface
var scenery: ComputerFrame
var motion_enabled: bool = true
var intro: Intro
var paused: bool = false
var _clock_fraction: float = 0.0
var _focused: bool = true

func _ready() -> void:
	get_window().min_size = Vector2i(1120, 800)
	state = Simulation.initial_state()
	interface = GameInterface.new()
	interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(interface)
	interface.command_requested.connect(_on_command)
	interface.save_requested.connect(_on_save)
	interface.load_requested.connect(_on_load)
	interface.reset_requested.connect(_on_reset)
	interface.motion_changed.connect(_on_motion)
	interface.pause_requested.connect(_toggle_pause)
	scenery = ComputerFrame.new()
	interface.scene_host.add_child(scenery)
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_render()
	interface.hide()
	intro = Intro.new()
	intro.finished.connect(_on_intro_finished)
	add_child(intro)
	get_window().focus_exited.connect(_on_focus_exited)
	get_window().focus_entered.connect(_on_focus_entered)

func _on_intro_finished() -> void:
	if is_instance_valid(intro):
		intro.queue_free()
	interface.show()
	interface.focus_workspace()

func _process(delta: float) -> void:
	_tick_shift(delta)

func _tick_shift(delta: float) -> void:
	if not is_instance_valid(interface) or not interface.visible or paused or not _focused or state.get("phase") != "review":
		return
	if interface._confirmation.visible:
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

func _on_command(command: Dictionary) -> void:
	if paused:
		return
	var previous_day: int = int(state.day)
	state = Simulation.dispatch(state, command)
	if int(state.day) != previous_day:
		_clock_fraction = 0.0
	_render()

func _on_save() -> void:
	var result: Dictionary = SaveStore.save_game(state)
	interface.notify("Game saved on this computer." if result.ok else str(result.error), not result.ok)

func _on_load() -> void:
	var result: Dictionary = SaveStore.load_game()
	if not result.ok:
		interface.notify(str(result.error), true)
		return
	state = result.state
	_clock_fraction = 0.0
	_render()
	_set_paused(state.phase == "review")
	interface.notify(str(result.error) if not str(result.get("error", "")).is_empty() else "Saved game loaded.")

func _on_reset() -> void:
	state = Simulation.initial_state()
	_clock_fraction = 0.0
	_render()
	_set_paused(false)
	interface.notify("New review career started. Your last save remains available.")

func _on_motion(enabled: bool) -> void:
	motion_enabled = enabled
	if is_instance_valid(scenery):
		scenery.set_motion(enabled and _focused and not paused)
	if is_instance_valid(intro):
		intro.set_motion(enabled)

func _on_focus_exited() -> void:
	_focused = false
	if is_instance_valid(interface) and interface.visible and state.get("phase") == "review":
		_set_paused(true)
	if is_instance_valid(intro):
		intro.set_paused(true)
	if is_instance_valid(scenery):
		scenery.set_motion(false)

func _on_focus_entered() -> void:
	_focused = true
	if is_instance_valid(intro):
		intro.set_paused(false)
	if is_instance_valid(scenery):
		scenery.set_motion(motion_enabled and not paused)
