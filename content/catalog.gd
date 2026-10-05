extends RefCounted
## Authored review packets. Audit answers stay outside the active player view.

static var _requests: Array = []

static func rules() -> Array:
	return load("res://content/policy_campaign.gd").rules()

## The campaign script itself, for its schedule constants (JIRO_DAY, PIPELINE_DAY...).
static func policy() -> GDScript:
	return load("res://content/policy_campaign.gd")

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
	return 300

## Every ticket Jiro shows right now: the backlog, plus the tickets of every PR
## that has reached the desk (a later version's copy of a ticket replaces an
## earlier one). Newest first. Each carries `linked`: the PRs that link it. PRs
## still in line contribute nothing, so Jiro never shows what is coming.
static func tickets(state: Dictionary) -> Array:
	var policy = load("res://content/policy_campaign.gd")
	if int(state.get("day", 1)) < int(policy.JIRO_DAY): return []
	var by_id: Dictionary = {}
	for ticket: Dictionary in policy.Records.backlog():
		ticket.linked = []
		by_id[str(ticket.id)] = ticket
	for entry: Dictionary in state.get("arrivals", []):
		var landed: Dictionary = packet(state, str(entry.get("pr_id", "")), false)
		for ticket: Dictionary in landed.get("tickets", []):
			var copy: Dictionary = ticket.duplicate(true)
			copy.linked = by_id.get(str(ticket.id), {}).get("linked", [])
			by_id[str(ticket.id)] = copy
		var ref: String = str(landed.get("ticket_ref", ""))
		if by_id.has(ref) and display_id(str(landed.id)) not in by_id[ref].linked: by_id[ref].linked.append(display_id(str(landed.id)))
	var result: Array = by_id.values()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return policy.Records.ticket_number(str(a.id)) > policy.Records.ticket_number(str(b.id)))
	return result

static func ticket(state: Dictionary, id: String) -> Dictionary:
	for found: Dictionary in tickets(state):
		if str(found.id) == id: return found
	return {}

## Every build Pipeline shows right now: one per PR version that has reached the
## desk, newest first, each with its `pr_id`.
static func builds(state: Dictionary) -> Array:
	var result: Array = []
	for entry: Dictionary in state.get("arrivals", []):
		var landed: Dictionary = packet(state, str(entry.get("pr_id", "")), false)
		var record: Dictionary = landed.get("build", {})
		if record.is_empty(): continue
		var copy: Dictionary = record.duplicate(true)
		copy.pr_id = str(landed.id)
		copy.day = int(entry.get("day", 0))
		result.push_front(copy)
	return result

static func build(state: Dictionary, id: String) -> Dictionary:
	for found: Dictionary in builds(state):
		if str(found.id) == id: return found
	return {}

## Audit/test helper: a citation command pointing at the packet's real evidence.
static func audit_citation(request: Dictionary, rule_id: String) -> Dictionary:
	for finding: Dictionary in request.get("findings", []):
		if finding.rule_id == rule_id:
			if finding.has("record"):
				return {"type": "toggle-rule", "rule_id": rule_id, "record": str(finding.record), "id": str(finding.id)}
			return {"type": "toggle-rule", "rule_id": rule_id, "path": finding.path, "line": int(finding.line)}
	# Nothing to find: point at the PR's own record, or its first file.
	var scope: String = load("res://content/policy_campaign.gd").scope(rule_id)
	if scope == "ticket": return {"type": "toggle-rule", "rule_id": rule_id, "record": "ticket", "id": str(request.get("ticket_ref", ""))}
	if scope == "build": return {"type": "toggle-rule", "rule_id": rule_id, "record": "build", "id": str(request.get("build", {}).get("id", ""))}
	var files: Array = request.get("files", [])
	return {"type": "toggle-rule", "rule_id": rule_id, "path": str(files[0].path) if not files.is_empty() else "", "line": 0}
