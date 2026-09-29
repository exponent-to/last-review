extends RefCounted
## Pure workshop rules. The outer application owns time and storage.

const MAX_VALUE: int = 9007199254740991
const LOG_LIMIT: int = 40
const MAX_BATCH_TICKS: int = 10000

static func initial_state() -> Dictionary:
	return {
		"version": 1, "tick": 0, "credits": 240, "materials": 20,
		"goods": 0, "workers": 1, "production": "idle", "speed": 1,
		"log": [{"tick": 0, "message": "Workshop ready. Select parts production to begin."}],
	}

static func _record(state: Dictionary, message: String) -> Dictionary:
	state.log.append({"tick": state.tick, "message": message})
	while state.log.size() > LOG_LIMIT:
		state.log.pop_front()
	return state

static func advance(state: Dictionary, ticks: int = 1) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if ticks < 0 or ticks > MAX_BATCH_TICKS or next.speed == 0:
		return next
	if next.tick > MAX_VALUE - ticks:
		return next
	for _step in range(ticks):
		var produced: int = 0
		if next.production == "parts":
			produced = mini(int(next.workers), mini(int(next.materials), MAX_VALUE - int(next.goods)))
		next.tick += 1
		next.materials -= produced
		next.goods += produced
		if produced > 0 and next.materials == 0:
			_record(next, "Materials depleted. Buy supplies to resume production.")
	return next

static func dispatch(state: Dictionary, command: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	match command.get("type", ""):
		"set-speed":
			var speed: Variant = command.get("speed")
			if typeof(speed) != TYPE_INT or speed not in [0, 1, 2, 4] or speed == next.speed:
				return next
			next.speed = speed
			return _record(next, "Simulation paused." if speed == 0 else "Simulation running at %dx speed." % speed)
		"set-production":
			var production: Variant = command.get("production")
			if production not in ["idle", "parts"] or production == next.production:
				return next
			next.production = production
			return _record(next, "Parts production selected." if production == "parts" else "Production set to idle.")
		"buy-materials":
			if next.credits < 30:
				return _record(next, "Need 30 credits to buy 10 materials.")
			if next.materials > MAX_VALUE - 10:
				return _record(next, "Material storage limit reached.")
			next.credits -= 30
			next.materials += 10
			return _record(next, "Bought 10 materials for 30 credits.")
		"sell-goods":
			if next.goods == 0:
				return _record(next, "No finished goods to sell.")
			if next.goods > (MAX_VALUE - int(next.credits)) / 12:
				return _record(next, "Credit limit reached. Goods were not sold.")
			var revenue: int = int(next.goods) * 12
			var count: int = int(next.goods)
			next.credits += revenue
			next.goods = 0
			return _record(next, "Sold %d goods for %d credits." % [count, revenue])
		"hire-worker":
			if next.workers >= 6:
				return _record(next, "Workshop is fully staffed at 6 workers.")
			if next.credits < 100:
				return _record(next, "Need 100 credits to hire a worker.")
			next.credits -= 100
			next.workers += 1
			return _record(next, "Hired a worker for 100 credits.")
	return next

static func _invalid(reason: String) -> Dictionary:
	return {"ok": false, "state": {}, "error": "Invalid save: " + reason}

static func _integer(value: Variant, minimum: int = 0, maximum: int = MAX_VALUE) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	if typeof(value) == TYPE_FLOAT and (not is_finite(value) or value != floor(value)):
		return false
	return value >= minimum and value <= maximum

static func validate_save(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _invalid("game state must be an object.")
	if not _integer(value.get("version"), 1, 1):
		return _invalid("unsupported save version; expected version 1.")
	var state: Dictionary = {"version": 1}
	for key: String in ["tick", "credits", "materials", "goods", "workers"]:
		var minimum: int = 1 if key == "workers" else 0
		var maximum: int = 6 if key == "workers" else MAX_VALUE
		if not _integer(value.get(key), minimum, maximum):
			return _invalid("%s must be an integer between %d and %d." % [key, minimum, maximum])
		state[key] = int(value[key])
	if value.get("production") not in ["idle", "parts"]:
		return _invalid("unknown production mode.")
	state.production = value.production
	if not _integer(value.get("speed"), 0, 4) or int(value.speed) not in [0, 1, 2, 4]:
		return _invalid("unknown simulation speed.")
	state.speed = int(value.speed)
	var activity: Variant = value.get("log")
	if typeof(activity) != TYPE_ARRAY or activity.size() > LOG_LIMIT:
		return _invalid("log must be an array with at most %d entries." % LOG_LIMIT)
	state.log = []
	var previous_tick: int = 0
	for index in range(activity.size()):
		var entry: Variant = activity[index]
		if typeof(entry) != TYPE_DICTIONARY:
			return _invalid("log entry %d must be an object." % index)
		if not _integer(entry.get("tick"), previous_tick, int(state.tick)):
			return _invalid("log entry %d has an invalid or nonchronological tick." % index)
		var message: Variant = entry.get("message")
		if typeof(message) != TYPE_STRING or message.strip_edges().is_empty() or message.length() > 240:
			return _invalid("log entry %d message must contain 1-240 characters." % index)
		previous_tick = int(entry.tick)
		state.log.append({"tick": previous_tick, "message": message})
	return {"ok": true, "state": state, "error": ""}

static func serialize_save(state: Dictionary) -> String:
	var result: Dictionary = validate_save(state)
	return JSON.stringify(result.state) if result.ok else ""
