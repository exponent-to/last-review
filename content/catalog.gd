extends RefCounted
## Authored review packets. Audit answers stay outside the active player view.

static var _requests: Array = []

static func rules() -> Array:
	return load("res://content/policy_campaign.gd").rules()

## The standards in force that day, as amended by then. Retired ones are gone.
static func rules_for_day(day: int) -> Array:
	return load("res://content/policy_campaign.gd").rules_for_day(day)

static func rule_active(rule_id: String, day: int) -> bool:
	return rule_id in load("res://content/policy_campaign.gd").active_ids(day)

## The morning the current set of standards was issued (they change every two days).
static func block_start(day: int) -> int:
	return load("res://content/policy_campaign.gd").block_start(day)

## Standards added, amended, and retired on a day's morning.
static func rule_changes(day: int) -> Dictionary:
	return load("res://content/policy_campaign.gd").changes(day)

## The authored originals, in line order. Revisions live in each career's state.
static func requests() -> Array:
	if _requests.is_empty():
		_requests = load("res://content/policy_campaign.gd").requests()
	return _requests.duplicate(true)

## Shared, read-only originals for hot internal paths; never mutate the result.
static func originals() -> Array:
	if _requests.is_empty():
		_requests = load("res://content/policy_campaign.gd").requests()
	return _requests

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

## Any packet a career has seen or queued, original or revision, with audit data.
## Revisions are regenerated from the recipe recorded in `state.revisions`.
## `copy` = false returns a shared read-only packet for hot internal paths.
static func packet(state: Dictionary, request_id: String, copy: bool = true) -> Dictionary:
	for request: Dictionary in originals():
		if request.id == request_id:
			return request.duplicate(true) if copy else request
	for entry: Dictionary in state.get("revisions", []):
		if entry.get("id") == request_id:
			var parent: Dictionary = packet(state, str(entry.get("parent_id", "")), false)
			if parent.is_empty(): return {}
			var revision: Dictionary = load("res://content/policy_campaign.gd")._revision_ref(parent, int(entry.version), entry.fixed, str(entry.regression), entry.cited)
			return revision.duplicate(true) if copy else revision
	return {}

## A day's originals plus the revisions its change requests produced.
static func day_packets(state: Dictionary, day: int) -> Array:
	var packets: Array = requests_for_day(day)
	for entry: Dictionary in state.get("revisions", []):
		if int(entry.get("day", 0)) == day:
			packets.append(packet(state, str(entry.id)))
	return packets

## The shift second a PR reached the desk, or -1 if it never has.
static func arrival(state: Dictionary, request_id: String) -> int:
	for entry: Dictionary in state.get("arrivals", []):
		if entry.get("pr_id") == request_id:
			return int(entry.shift_seconds)
	return -1

## "PR-2004-v2" reads as "PR-2004 · v2"; originals keep their plain ID.
static func display_id(request_id: String) -> String:
	var marker: int = request_id.rfind("-v")
	if marker > 0 and request_id.substr(marker + 2).is_valid_int():
		return request_id.left(marker) + " · v" + request_id.substr(marker + 2)
	return request_id

static func shift_seconds() -> int:
	return 180

## Audit/test helper: a citation command pointing at the packet's real evidence.
static func audit_citation(request: Dictionary, rule_id: String) -> Dictionary:
	for finding: Dictionary in request.get("findings", []):
		if finding.rule_id == rule_id:
			return {"type": "toggle-rule", "rule_id": rule_id, "path": finding.path, "line": int(finding.line)}
	var files: Array = request.get("files", [])
	return {"type": "toggle-rule", "rule_id": rule_id, "path": str(files[0].path) if not files.is_empty() else "", "line": 0}
