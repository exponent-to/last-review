extends RefCounted
## Authored review packets. Audit answers stay outside the active player view.

static var _arrival_index: Dictionary = {}
static var _requests: Array = []

static func rules() -> Array:
	return load("res://content/policy_campaign.gd").rules()

static func rules_for_day(day: int) -> Array:
	var active: Array = []
	for rule: Dictionary in rules():
		if int(rule.introduced_day) <= day:
			active.append(rule)
	return active

static func requests() -> Array:
	if _requests.is_empty():
		_requests = load("res://content/policy_campaign.gd").requests()
	return _requests.duplicate(true)

static func request_at(index: int) -> Dictionary:
	var packets: Array = requests()
	if index < 0 or index >= packets.size():
		return {}
	return packets[index]

static func briefing(day: int) -> String:
	return load("res://content/policy_campaign.gd").briefing(day)

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
	if _arrival_index.is_empty():
		for packet: Dictionary in requests(): _arrival_index[packet.id] = int(packet.arrival_seconds)
	return int(_arrival_index.get(request_id, -1))

static func shift_seconds() -> int:
	return 300
