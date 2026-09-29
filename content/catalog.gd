extends RefCounted
## Authored review packets. Audit answers stay outside the active player view.

static var _rules: Array = []
static var _requests: Array = []
static var _briefings: Array = []

static func _read_array(path: String) -> Array:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if value is Array:
		return value
	push_error("Invalid content catalog: " + path)
	return []

static func rules() -> Array:
	if _rules.is_empty():
		_rules = _read_array("res://content/rules.json")
	return _rules.duplicate(true)

static func rules_for_day(day: int) -> Array:
	var active: Array = []
	for rule: Dictionary in rules():
		if int(rule.introduced_day) <= day:
			active.append(rule)
	return active

static func requests() -> Array:
	if _requests.is_empty():
		_requests = _read_array("res://content/requests.json")
	return _requests.duplicate(true)

static func request_at(index: int) -> Dictionary:
	var packets: Array = requests()
	if index < 0 or index >= packets.size():
		return {}
	return packets[index]

static func briefing(day: int) -> String:
	if _briefings.is_empty():
		_briefings = _read_array("res://content/briefings.json")
	for entry: Dictionary in _briefings:
		if int(entry.day) == day:
			return str(entry.text)
	return "This assignment is complete."

## Internal scheduling metadata. Do not announce queue sizes to the player.
static func campaign_days() -> Array:
	var days: Array = []
	for request: Dictionary in requests():
		var day: int = int(request.day)
		if day not in days:
			days.append(day)
	return days

static func requests_for_day(day: int) -> Array:
	var packets: Array = []
	for request: Dictionary in requests():
		if int(request.day) == day:
			packets.append(request)
	return packets
