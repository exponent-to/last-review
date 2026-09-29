extends Node

const Simulation = preload("res://native/simulation.gd")
const SaveStore = preload("res://native/save_store.gd")
const GameInterface = preload("res://native/interface.gd")
const OfficeScene = preload("res://native/office_scene.gd")

var state: Dictionary = {}
var interface: GameInterface
var scenery: OfficeScene
var motion_enabled: bool = true

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
	scenery = OfficeScene.new()
	interface.scene_host.add_child(scenery)
	scenery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_render()
	get_window().focus_exited.connect(_on_focus_exited)
	get_window().focus_entered.connect(_on_focus_entered)

func _render() -> void:
	interface.render_state(state)
	scenery.set_story(int(state.day), int(state.autonomy))

func _on_command(command: Dictionary) -> void:
	state = Simulation.dispatch(state, command)
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
	_render()
	interface.notify(str(result.error) if not str(result.get("error", "")).is_empty() else "Saved game loaded.")

func _on_reset() -> void:
	state = Simulation.initial_state()
	_render()
	interface.notify("New review career started. Your last save remains available.")

func _on_motion(enabled: bool) -> void:
	motion_enabled = enabled
	if is_instance_valid(scenery):
		scenery.set_motion(enabled)

func _on_focus_exited() -> void:
	if is_instance_valid(scenery):
		scenery.set_motion(false)

func _on_focus_entered() -> void:
	if is_instance_valid(scenery):
		scenery.set_motion(motion_enabled)
