extends RefCounted
## Authored review packets. Audit answers stay outside the active player view.

static var campaign_version := 5
static var _arrival_index: Dictionary = {}
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
	if campaign_version >= 5: return load("res://content/policy_campaign.gd").rules()
	if _rules.is_empty():
		_rules = _read_array("res://content/legacy/rules.json")
	return _rules.duplicate(true)

static func rules_for_day(day: int) -> Array:
	var active: Array = []
	for rule: Dictionary in rules():
		if int(rule.introduced_day) <= day:
			active.append(rule)
	return active

static func requests() -> Array:
	if campaign_version >= 5: return load("res://content/policy_campaign.gd").requests()
	if _requests.is_empty():
		_requests = _read_array("res://content/legacy/requests.json")
	return _requests.duplicate(true)

static func request_at(index: int) -> Dictionary:
	var packets: Array = requests()
	if index < 0 or index >= packets.size():
		return {}
	return packets[index]

static func briefing(day: int) -> String:
	if campaign_version >= 5: return load("res://content/policy_campaign.gd").briefing(day)
	if _briefings.is_empty():
		_briefings = _read_array("res://content/legacy/briefings.json")
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

## Deterministic in-world inbox delivery; queue size remains private scheduling data.
static func arrival_seconds(request_id: String) -> int:
	if campaign_version >= 5:
		if _arrival_index.is_empty():
			for packet: Dictionary in requests(): _arrival_index[packet.id] = int(packet.arrival_seconds)
		return int(_arrival_index.get(request_id, -1))
	for request: Dictionary in requests():
		if request.id != request_id:
			continue
		var shift: Array = requests_for_day(int(request.day))
		for index in range(shift.size()):
			if shift[index].id == request_id:
				return 20 + floori(float(index) * 260.0 / maxf(1.0, float(shift.size() - 1)))
	return -1

static func shift_seconds() -> int:
	return 360 if campaign_version == 4 else 300
