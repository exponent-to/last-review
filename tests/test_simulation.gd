extends SceneTree

const Simulation = preload("res://native/simulation.gd")
const SaveStore = preload("res://native/save_store.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_test_ticks()
	_test_commands()
	_test_saves()
	print("Simulation checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures > 0 else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _running(overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = Simulation.initial_state()
	state.production = "parts"
	state.merge(overrides, true)
	return state

func _test_ticks() -> void:
	var initial: Dictionary = _running({"workers": 3})
	var batch: Dictionary = Simulation.advance(initial, 10)
	var individual: Dictionary = initial
	for _i in range(10):
		individual = Simulation.advance(individual)
	_check(batch == individual, "Batch and individual ticks must be deterministic.")
	_check(batch.tick == 10 and batch.goods == 20 and batch.materials == 0, "Production must clamp to available materials.")
	_check(batch.log[-1].tick == 7, "Depletion log must occur on the exact depletion tick.")
	_check(initial.tick == 0 and initial.materials == 20, "Advance must not mutate its input.")
	var paused: Dictionary = _running({"speed": 0})
	_check(Simulation.advance(paused, 10) == paused, "Pause must stop time and production.")
	_check(Simulation.advance(initial, 0) == initial, "Zero ticks must preserve state.")
	_check(Simulation.advance(_running({"speed": 4}), 2).goods == 2, "Outer clock owns speed multiplication.")
	var idle: Dictionary = Simulation.advance(Simulation.initial_state(), 3)
	_check(idle.tick == 3 and idle.materials == 20 and idle.goods == 0, "Idle should advance time only.")
	var depleted: Dictionary = Simulation.advance(_running({"materials": 2, "workers": 6}), 2)
	var resumed: Dictionary = Simulation.advance(Simulation.dispatch(depleted, {"type": "buy-materials"}))
	_check(resumed.materials == 4 and resumed.goods == 8, "Buying supplies must resume selected production.")
	_check(Simulation.advance(initial, -1) == initial, "Negative tick batches must be rejected.")
	_check(Simulation.advance(initial, 10001) == initial, "Excessive tick batches must be rejected.")
	var max_tick: Dictionary = _running({"tick": Simulation.MAX_VALUE})
	_check(Simulation.advance(max_tick) == max_tick, "Tick overflow must be rejected.")
	var full: Dictionary = Simulation.advance(_running({"goods": Simulation.MAX_VALUE}))
	_check(full.goods == Simulation.MAX_VALUE and full.materials == 20, "Production must prevent goods overflow.")

func _test_commands() -> void:
	var state: Dictionary = Simulation.initial_state()
	state = Simulation.dispatch(state, {"type": "buy-materials"})
	state = Simulation.dispatch(state, {"type": "hire-worker"})
	state = Simulation.dispatch(state, {"type": "set-production", "production": "parts"})
	state = Simulation.advance(state, 3)
	_check(state.credits == 110 and state.materials == 24 and state.goods == 6 and state.workers == 2, "Economy prices and production must match design.")
	var sold: Dictionary = Simulation.dispatch(state, {"type": "sell-goods"})
	_check(sold.credits == 182 and sold.goods == 0, "Goods must sell for 12 credits each.")
	_check(Simulation.dispatch(_running({"credits": 29}), {"type": "buy-materials"}).credits == 29, "Insufficient credits must not buy supplies.")
	_check(Simulation.dispatch(_running({"credits": 99}), {"type": "hire-worker"}).workers == 1, "Insufficient credits must not hire.")
	_check(Simulation.dispatch(_running({"workers": 6}), {"type": "hire-worker"}).credits == 240, "Worker cap must not charge credits.")
	_check(Simulation.dispatch(_running(), {"type": "sell-goods"}).credits == 240, "Empty goods must not create revenue.")
	var paused: Dictionary = Simulation.dispatch(_running({"speed": 0}), {"type": "buy-materials"})
	_check(paused.speed == 0 and paused.tick == 0 and paused.materials == 30, "Commands must remain available while paused.")
	var original: Dictionary = _running()
	var before: Dictionary = original.duplicate(true)
	var result: Dictionary = Simulation.dispatch(original, {"type": "hire-worker"})
	result.log[0].message = "Edited returned state"
	_check(original == before, "Commands must deep-copy state and log entries.")
	var advanced: Dictionary = Simulation.advance(original)
	advanced.log[0].message = "Edited advanced state"
	_check(original == before, "Advance must deep-copy log entries.")
	for _action in range(100):
		state = Simulation.dispatch(state, {"type": "hire-worker"})
	_check(state.log.size() == 40, "Activity log must stay bounded.")
	var overflow: Dictionary = Simulation.dispatch(_running({"materials": Simulation.MAX_VALUE}), {"type": "buy-materials"})
	_check(overflow.credits == 240 and overflow.materials == Simulation.MAX_VALUE, "Material purchase must prevent overflow.")
	overflow = Simulation.dispatch(_running({"goods": Simulation.MAX_VALUE}), {"type": "sell-goods"})
	_check(overflow.credits == 240 and overflow.goods == Simulation.MAX_VALUE, "Sale must prevent overflow.")
	_check(Simulation.dispatch(original, {"type": "set-speed", "speed": 3}) == original, "Invalid speed commands must be rejected.")
	_check(Simulation.dispatch(original, {"type": "set-speed", "speed": true}) == original, "Boolean speeds must be rejected.")
	_check(Simulation.dispatch(original, {"type": "set-production", "production": "unknown"}) == original, "Invalid production commands must be rejected.")
	_check(Simulation.dispatch(original, {"type": "unknown"}) == original, "Unknown commands must be rejected.")

func _test_saves() -> void:
	var state: Dictionary = Simulation.advance(_running(), 5)
	var parser: JSON = JSON.new()
	_check(parser.parse(Simulation.serialize_save(state)) == OK, "Serialized save must contain valid JSON.")
	var restored: Dictionary = Simulation.validate_save(parser.data)
	_check(restored.ok and restored.state == state, "Save must round-trip through JSON float numbers.")
	_check(typeof(restored.state.tick) == TYPE_INT, "Validated JSON numbers must normalize to integers.")
	restored.state.log[0].message = "Changed"
	_check(state.log[0].message != "Changed", "Validated saves must own independent data.")
	for value: Variant in [null, [], 42, "text", true]:
		_check(not Simulation.validate_save(value).ok, "Non-dictionary saves must be rejected.")
	var missing: Dictionary = Simulation.validate_save({"version": 1})
	_check(not missing.ok and "tick" in missing.error, "Missing required fields must provide a clear error.")
	var corruptions: Array = [
		["version", 2], ["version", true], ["tick", -1], ["tick", 0.5],
		["credits", "240"], ["credits", -1], ["credits", INF], ["credits", NAN],
		["materials", null], ["goods", Simulation.MAX_VALUE + 1],
		["workers", 0], ["workers", 7], ["speed", 3], ["speed", true],
		["production", "unknown"], ["log", {}], ["log", [null]],
		["log", [{"tick": 1, "message": "Future"}]],
		["log", [{"tick": 0, "message": ""}]],
		["log", [{"tick": 0, "message": 123}]],
		["log", [{"tick": 0, "message": "x".repeat(241)}]],
	]
	for corruption: Array in corruptions:
		var bad: Dictionary = Simulation.initial_state()
		bad[corruption[0]] = corruption[1]
		var validation: Dictionary = Simulation.validate_save(bad)
		_check(not validation.ok and validation.error.begins_with("Invalid save:"), "Corrupt %s must be rejected." % corruption[0])
	var unordered: Dictionary = _running({"tick": 5, "log": [{"tick": 4, "message": "Later"}, {"tick": 2, "message": "Earlier"}]})
	_check(not Simulation.validate_save(unordered).ok, "Nonchronological activity must be rejected.")
	var too_many: Dictionary = Simulation.initial_state()
	for _entry in range(41):
		too_many.log.append({"tick": 0, "message": "Entry"})
	_check(not Simulation.validate_save(too_many).ok, "Oversized logs must be rejected.")
	var extra: Dictionary = Simulation.initial_state()
	extra.injected = "ignore"
	extra.log[0].injected = "ignore"
	var clean: Dictionary = Simulation.validate_save(extra).state
	_check(not clean.has("injected") and not clean.log[0].has("injected"), "Unknown save properties must be discarded.")
	_check(Simulation.serialize_save(_running({"credits": INF})).is_empty(), "Invalid state must not serialize.")
	_check(not SaveStore.save_game(_running({"credits": -1})).ok, "Persistence must reject invalid state before touching files.")
