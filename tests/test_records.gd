extends SceneTree
## Lineal issues and Pipeline builds: the record standards (P16-P21) at their
## boundaries, record evidence on the citation slip, the journal and save replay
## with record citations, revisions that fix exactly the cited record faults, the
## two apps showing the PR's own issue and build, and no audit leaks through them.
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Policy = preload("res://content/policy_campaign.gd")
const Records = preload("res://content/records.gd")
const Encounters = preload("res://content/encounters.gd")
const Interface = preload("res://native/interface.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	_test_issue_boundaries()
	_test_build_boundaries()
	_test_schedule()
	_test_evidence()
	_test_generation()
	_test_revisions()
	_test_simulation()
	await _test_apps()
	print("Record checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

# --- Fixtures -----------------------------------------------------------------

func _file(path: String = "office/note.py", base: Variant = null) -> Dictionary:
	var file := {"path": path, "source": "def note():\n    return 1", "keyword_ink": "blue"}
	if base != null:
		file.base = base
		file.status = "modified"
	return file

func _issue(fields: Dictionary = {}) -> Dictionary:
	var issue := {"id": "PAP-412", "status": "Todo", "assignee": "Maya", "component": "office/", "labels": ["Bug"], "priority": "Low", "estimate": 3}
	for key: String in fields: issue[key] = fields[key]
	return issue

func _build(fields: Dictionary = {}) -> Dictionary:
	var build := {"id": "#4412", "status": "passed", "override": "", "reruns": 0, "coverage_before": 814, "coverage_after": 814, "branch": "maya/note", "commit": "3f0c1a7"}
	for key: String in fields: build[key] = fields[key]
	return build

func _records(issue: Dictionary = {}, ref: Variant = null, build: Dictionary = {}) -> Dictionary:
	var shown := _issue() if issue.is_empty() else issue
	return {"author": "Maya", "issue_ref": str(shown.id) if ref == null else str(ref), "issues": [shown], "build": _build() if build.is_empty() else build}

func _broken(day: int, records: Dictionary, files: Array = []) -> Array:
	var record_rules: Array = Policy.RECORD_SCOPED
	return Policy.evaluate([_file()] if files.is_empty() else files, day, records).filter(func(rule_id: String) -> bool: return rule_id in record_rules)

# --- Standards ------------------------------------------------------------------

func _test_issue_boundaries() -> void:
	var day := Policy.LINEAL_DAY
	_check(_broken(day, _records()).is_empty(), "A linked issue with no vibes, not Urgent, breaks nothing.")
	for status: String in Records.STATUSES:
		_check(_broken(day, _records(_issue({"status": status}))).is_empty(), "Status doesn't matter, even %s." % status)
	for labels: Array in [["vibes"], ["Vibes"], ["VIBES", "Bug"], ["Bug", "vibes"]]:
		_check(_broken(day, _records(_issue({"labels": labels}))) == ["P16"], "A vibes label breaks the vibes standard: %s" % [labels])
	for labels: Array in [["good-vibes"], ["vibe-check"], ["Vibes-adjacent"], ["vibes?"], []]:
		_check(_broken(day, _records(_issue({"labels": labels}))).is_empty(), "Lookalike labels are fine: %s" % [labels])
	_check(_broken(day, _records({}, "")) == ["P16"], "A PR that links no issue breaks the issue standard.")
	_check(_broken(day, _records({}, "PAP-4120")) == ["P16"], "A link to an issue Lineal doesn't have breaks the issue standard.")
	_check(_broken(day, _records(_issue({"priority": "Urgent"}), "PAP-4120")) == ["P16"], "Without an issue there is no priority to check: only the link is cited.")
	# Urgency belongs to Helios (days 3-4).
	_check(_broken(day, _records(_issue({"priority": "Urgent"}))) == ["P17"], "An Urgent issue breaks the urgency standard.")
	for priority: String in ["No priority", "Low", "Medium", "High"]:
		_check(_broken(day, _records(_issue({"priority": priority}))).is_empty(), "%s is not Urgent." % priority)
	_check(_broken(Policy.PIPELINE_DAY, _records(_issue({"priority": "Urgent"}))).is_empty(), "Urgency retires on Friday.")
	# A backlog issue exists in Lineal; its own priority is what counts.
	var backlog := {"author": "Maya", "issue_ref": "PAP-214", "issues": [], "build": {}}
	_check(_broken(day, backlog).is_empty(), "A Medium backlog issue is a valid link.")
	backlog.issue_ref = "PAP-101"
	_check(_broken(day, backlog) == ["P17"], "PAP-101 is Urgent, so it belongs to Helios.")
	# Fibonacci estimates (from day 7): 0 counts only from day 9.
	var seven := Policy.OVERRIDE_DAY
	var nine := Policy.ZERO_DAY
	for estimate: int in [1, 2, 3, 5, 8, 13]:
		_check(_broken(seven, _records(_issue({"estimate": estimate}))).is_empty() and _broken(nine, _records(_issue({"estimate": estimate}))).is_empty(), "%d is Fibonacci." % estimate)
	for estimate: int in [4, 6, 7, 9, 10, 12, 20, 21, 40]:
		_check(_broken(seven, _records(_issue({"estimate": estimate}))) == ["P18"], "%d is not on the scale." % estimate)
	_check(_broken(seven, _records(_issue({"estimate": 0}))) == ["P18"] and _broken(nine, _records(_issue({"estimate": 0}))).is_empty(), "0 counts as Fibonacci only once the amendment arrives.")
	_check(_broken(Policy.PIPELINE_DAY, _records(_issue({"estimate": 4}))).is_empty(), "Estimates aren't reviewed before week two.")
	_check(Policy.estimate_valid(0, 9) and not Policy.estimate_valid(0, 8) and not Policy.estimate_valid(4, 9), "estimate_valid follows the amendment.")

func _test_build_boundaries() -> void:
	var five := Policy.PIPELINE_DAY
	var seven := Policy.OVERRIDE_DAY
	var nine := Policy.OVERRIDE_BANNED_DAY
	_check(_broken(five, _records({}, null, _build({"status": "failed"}))) == ["P19"], "A failed build breaks the green-build standard.")
	_check(_broken(five, _records({}, null, _build({"status": "flaky"}))).is_empty(), "A flaky build counts as passing.")
	var override := _build({"status": "passed", "override": "helios"})
	_check(_broken(seven, _records({}, null, override)).is_empty() and _broken(nine, _records({}, null, override)) == ["P19"], "A Helios override counts as passing on day 7, and as failed from day 9.")
	_check(Records.status_text(override) == "PASSED (OVERRIDDEN BY HELIOS)" and Records.status_text(_build({"status": "flaky"})) == "FLAKY", "Pipeline shows the status as written, overrides included.")
	# Branch names (days 5-6).
	for branch: String in ["maya/yolo-note", "maya/note-wip", "maya/note-final", "maya/finalize-note", "maya/wipe-cache", "maya/NOTE-FINAL-v2", "theo/YOLO"]:
		_check(_broken(five, _records({}, null, _build({"branch": branch}))) == ["P20"], "A branch with a banned word breaks P20: " + branch)
	for branch: String in ["maya/whip-up", "maya/yoga-room", "maya/finance", "maya/yo-lo", "maya/fin-al", "maya/wimp-mode"]:
		_check(_broken(five, _records({}, null, _build({"branch": branch}))).is_empty(), "A lookalike branch is fine: " + branch)
	_check(_broken(seven, _records({}, null, _build({"branch": "maya/yolo"}))).is_empty(), "Branch names retire in week two: Helios names them.")
	_check(_broken(five, _records({}, null, _build({"status": "failed", "branch": "maya/wip"}))) == ["P19", "P20"], "Two build faults are two citations of the same build.")
	# Hex hygiene (days 9-10).
	for commit: String in ["3deadf0", "0bad1e5", "DEAD123", "12345ba", "badbad0"]:
		var expected: Array = ["P21"] if commit.to_lower().contains("dead") or commit.to_lower().contains("bad") else []
		_check(_broken(nine, _records({}, null, _build({"commit": commit}))) == expected, "Commit %s is read exactly." % commit)
	for commit: String in ["12de4d0", "1b4d234", "bead123", "00dab00", "ba0d123", "dea0123"]:
		_check(_broken(nine, _records({}, null, _build({"commit": commit}))).is_empty(), "A lookalike hash is fine: " + commit)
	_check(_broken(seven, _records({}, null, _build({"commit": "3deadf0"}))).is_empty(), "Hex hygiene arrives on day 9.")
	_check(_broken(Policy.LINEAL_DAY, _records({}, null, _build({"status": "failed"}))).is_empty(), "Builds aren't reviewed before Pipeline is installed.")
	# Generated builds never spell a banned word by accident.
	for slot in range(0, 400, 7):
		for author: String in ["Maya", "Theo", "June", "Penny", "Gwen"]:
			var build: Dictionary = Records.build({"slot": slot, "version": 1 + slot % 3, "author": author, "path": "office/final_wipe_yolo.py", "effects": []})
			_check(not build.branch.to_lower().contains("yolo") and not build.branch.to_lower().contains("wip") and not build.branch.to_lower().contains("final"), "A clean branch is scrubbed: " + build.branch)
			_check(not build.commit.contains("dead") and not build.commit.contains("bad") and build.commit.length() == 7, "A clean hash is scrubbed: " + build.commit)

func _test_schedule() -> void:
	for day in range(1, 11):
		var active: Array = Policy.active_ids(day)
		_check(active.size() <= Policy.MAX_ACTIVE, "At most six standards on day %d." % day)
		_check(("P16" in active) == (day >= Policy.LINEAL_DAY) and ("P17" in active) == (day >= Policy.LINEAL_DAY and day < Policy.PIPELINE_DAY), "Vibes from Wednesday; urgency until Helios takes it on Friday (day %d)." % day)
		_check(("P18" in active) == (day >= Policy.OVERRIDE_DAY) and ("P19" in active) == (day >= Policy.PIPELINE_DAY), "Fibonacci from week two, green builds from Friday (day %d)." % day)
		_check(("P20" in active) == (day >= Policy.PIPELINE_DAY and day < Policy.OVERRIDE_DAY) and ("P21" in active) == (day >= Policy.ISSUE_DAY), "Branch names until week two, hex in the last block (day %d)." % day)
	_check(Simulation.SAVE_VERSION >= 20, "The Lineal re-theme bumped the save format to 20 or later.")
	for rule_id: String in Policy.RECORD_SCOPED:
		_check(Encounters.LEANS.has(str(Policy.rules().filter(func(rule: Dictionary) -> bool: return rule.id == rule_id)[0].category)), "%s leans the encounter by its category." % rule_id)
		_check(Policy.CITED_WORDS.has(rule_id) and str(Policy.CITED_WORDS[rule_id][0]).begins_with("the "), "%s has plain words for what was cited." % rule_id)
		_check(Interface.RULE_SUMMARIES.has(rule_id), "%s has a one-line slip summary." % rule_id)
	_check(Interface.RULE_SUMMARIES.has("P19@7") and Interface.RULE_SUMMARIES.has("P19@9") and Interface.RULE_SUMMARIES.has("P18@9") and Interface.RULE_SUMMARIES.has("P02@9"), "Amended standards have their amended summaries.")

# --- Evidence -------------------------------------------------------------------

func _test_evidence() -> void:
	var records := _records(_issue({"labels": ["vibes"], "priority": "Urgent", "estimate": 4}), null, _build({"status": "failed", "branch": "maya/wip", "commit": "0bad123"}))
	var issue := {"record": "issue", "id": "PAP-412"}
	var build := {"record": "build", "id": "#4412"}
	var audits := {"P16": Policy.findings([_file()], Policy.LINEAL_DAY, records), "P17": Policy.findings([_file()], Policy.LINEAL_DAY, records), "P18": Policy.findings([_file()], Policy.OVERRIDE_DAY, records)}
	for rule_id: String in audits:
		var audit_for: Array = audits[rule_id]
		_check(Policy.evidence_matches(audit_for, rule_id, issue), "%s accepts the PR's issue." % rule_id)
		_check(not Policy.evidence_matches(audit_for, rule_id, build), "%s does not accept the build." % rule_id)
		_check(not Policy.evidence_matches(audit_for, rule_id, {"record": "issue", "id": "PAP-101"}), "%s does not accept some other issue." % rule_id)
		_check(not Policy.evidence_matches(audit_for, rule_id, {"path": "office/note.py", "line": 0}) and not Policy.evidence_matches(audit_for, rule_id, {"path": "office/note.py", "line": 1}), "WHOLE FILE and code lines never count for %s." % rule_id)
		_check(not Policy.evidence_accepted(audit_for, rule_id, "office/note.py", 0), "Code evidence is never accepted for %s." % rule_id)
	var builds := {"P19": Policy.findings([_file()], Policy.PIPELINE_DAY, records), "P20": Policy.findings([_file()], Policy.PIPELINE_DAY, records), "P21": Policy.findings([_file()], Policy.ISSUE_DAY, records)}
	for rule_id: String in builds:
		var audit: Array = builds[rule_id]
		_check(Policy.evidence_matches(audit, rule_id, build) and not Policy.evidence_matches(audit, rule_id, issue) and not Policy.evidence_matches(audit, rule_id, {"record": "build", "id": "#4413"}), "%s accepts only the PR's build." % rule_id)
		_check(not Policy.evidence_matches(audit, rule_id, {"path": "office/note.py", "line": 0}), "WHOLE FILE never counts for %s." % rule_id)
	var unlinked: Array = Policy.findings([_file()], Policy.LINEAL_DAY, _records({}, ""))
	_check(Policy.evidence_matches(unlinked, "P16", {"record": "issue", "id": ""}) and not Policy.evidence_matches(unlinked, "P16", issue), "A missing link is cited as the PR's empty issue link.")
	var code: Array = Policy.findings([{"path": "office/a.py", "source": "x = 1\ndef fire_drill(): pass", "keyword_ink": "blue"}], 3, _records())
	_check(Policy.evidence_matches(code, "P04", {"path": "office/a.py", "line": 2}) and not Policy.evidence_matches(code, "P04", issue), "A record is never evidence for a code standard.")

func _test_generation() -> void:
	var seen := {}
	var issue_ids := {}
	var build_ids := {}
	for packet: Dictionary in Catalog.requests():
		var day := int(packet.day)
		for rule_id: String in packet.violations:
			if rule_id in Policy.RECORD_SCOPED: seen[rule_id] = true
		if day < Policy.LINEAL_DAY: continue
		var own: Dictionary = packet.issues[0]
		_check(str(own.id) not in issue_ids and Records.find([], str(own.id)).is_empty(), "Every PR's issue has its own number, never a backlog one: " + str(own.id))
		issue_ids[str(own.id)] = true
		_check(str(own.assignee) == str(packet.author) and not str(own.cycle).is_empty() and not own.labels.is_empty(), "Every issue has its author, a cycle, and labels: " + str(packet.id))
		# Clean PRs get clean records: whatever looks odd about them is still valid.
		if packet.violations.is_empty():
			_check(packet.issue_ref == str(own.id) and not Records.has_vibes(own) and (str(own.priority) != "Urgent" or not Policy._on("P17", day)), "A clean PR links its own issue, no vibes: " + str(packet.id))
			_check(Policy.estimate_valid(int(own.estimate), day) or not Policy._on("P18", day), "A clean PR's estimate is on the scale: " + str(packet.id))
			if day >= Policy.PIPELINE_DAY:
				_check(packet.build.status != "failed", "A clean PR has a passing build: " + str(packet.id))
		if day >= Policy.PIPELINE_DAY:
			_check(str(packet.build.id) not in build_ids, "Every build has its own number.")
			build_ids[str(packet.build.id)] = true
			_check(packet.build.tests.size() >= 4 and not str(packet.build.branch).is_empty() and str(packet.build.commit).length() == 7, "Builds list their tests, branch, and a seven-character hash.")
			if packet.build.status == "failed" or str(packet.build.get("override", "")) == "helios":
				_check(packet.build.tests.any(func(test: Dictionary) -> bool: return test.result == "fail") and not packet.build.log.is_empty(), "A red build shows its failing tests and log: " + str(packet.id))
	for rule_id: String in Policy.RECORD_SCOPED:
		_check(seen.has(rule_id), "The campaign exercises %s." % rule_id)
	# Each kind of record fault and near miss shows up somewhere, visibly.
	var kinds := {}
	for packet: Dictionary in Catalog.requests():
		if packet.issues.is_empty(): continue
		var day := int(packet.day)
		var own: Dictionary = packet.issues[0]
		if packet.issue_ref.is_empty(): kinds.missing = true
		elif Records.find(packet.issues, packet.issue_ref).is_empty(): kinds.ghost = true
		if Records.has_vibes(own): kinds["vibes"] = true
		if packet.violations.is_empty() and str(own.status) in ["Done", "Canceled", "Backlog"]: kinds["closed but clean"] = true
		if packet.violations.is_empty() and own.labels.any(func(label: Variant) -> bool: return "vibe" in str(label).to_lower()): kinds["vibes lookalike"] = true
		if str(own.priority) == "Urgent": kinds["urgent %s" % ("fault" if "P17" in packet.violations else "decoy")] = true
		if str(own.priority) == "High" and Policy._on("P17", day) and packet.violations.is_empty(): kinds["high decoy"] = true
		if "P18" in packet.violations: kinds["estimate %s" % ("zero" if int(own.estimate) == 0 else "off-scale")] = true
		if Policy._on("P18", day) and packet.violations.is_empty() and int(own.estimate) in [0, 13]: kinds["estimate %d decoy" % int(own.estimate)] = true
		if str(packet.build.get("override", "")) == "helios": kinds["override %s" % ("fault" if "P19" in packet.violations else "decoy")] = true
		if packet.build.get("status", "") == "flaky": kinds.flaky = true
		if "P20" in packet.violations: kinds["branch fault"] = true
		if "P21" in packet.violations: kinds["hash fault"] = true
		if Policy._on("P20", day) and packet.violations.is_empty() and str(packet.build.get("branch", "")).count("-") >= 1 and ["whip", "yoga", "finance", "yo-lo", "fin-al", "wimp"].any(func(word: String) -> bool: return str(packet.build.branch).contains(word)): kinds["branch decoy"] = true
		if Policy._on("P21", day) and packet.violations.is_empty() and ["de4d", "b4d", "bead", "dab", "ba0d", "dea0"].any(func(word: String) -> bool: return str(packet.build.get("commit", "")).contains(word)): kinds["hash decoy"] = true
	for kind: String in ["missing", "ghost", "vibes", "closed but clean", "vibes lookalike", "urgent fault", "urgent decoy", "high decoy", "estimate off-scale", "estimate zero", "estimate 13 decoy", "estimate 0 decoy", "override fault", "override decoy", "flaky", "branch fault", "branch decoy", "hash fault", "hash decoy"]:
		_check(kinds.has(kind), "The campaign shows a %s record." % kind)

# --- Revisions ------------------------------------------------------------------

## The first original whose only violations are `rules`.
func _packet_with(rules: Array) -> Dictionary:
	for packet: Dictionary in Catalog.requests():
		if packet.violations == rules: return packet
	return {}

func _test_revisions() -> void:
	for rule_id: String in Policy.RECORD_SCOPED:
		var parent := _packet_with([rule_id])
		_check(not parent.is_empty(), "Some PR breaks only %s." % rule_id)
		if parent.is_empty(): continue
		var revision: Dictionary = Policy.revision(parent, 2, [rule_id], "", [rule_id])
		_check(rule_id not in revision.violations, "Citing %s gets it fixed in v2." % rule_id)
		var issue: Dictionary = Records.find(revision.issues, revision.issue_ref)
		var day := int(parent.day)
		match rule_id:
			"P16":
				_check(not issue.is_empty() and not Records.has_vibes(issue), "v2 links an issue with no vibes.")
				_check(issue.history.any(func(line: String) -> bool: return line.contains("after review")), "Lineal shows who fixed the issue.")
			"P17": _check(str(issue.priority) != "Urgent" and issue.history.any(func(line: String) -> bool: return line.begins_with("Priority lowered")), "v2's issue is no longer Urgent.")
			"P18": _check(Policy.estimate_valid(int(issue.estimate), day) and issue.history.any(func(line: String) -> bool: return line.begins_with("Re-estimated")), "v2's issue is re-estimated.")
			"P19": _check(revision.build.status != "failed" and (day < Policy.OVERRIDE_BANNED_DAY or str(revision.build.override) != "helios"), "v2's build is green, honestly.")
			"P20": _check(not ["yolo", "wip", "final"].any(func(word: String) -> bool: return str(revision.build.branch).to_lower().contains(word)), "v2's branch can be read to the board.")
			"P21": _check(not str(revision.build.commit).to_lower().contains("dead") and not str(revision.build.commit).to_lower().contains("bad"), "v2's hash spells nothing.")
		if not parent.build.is_empty():
			_check(revision.build.id != parent.build.id, "v2 is a new push, so a new build.")
		# Citing something else leaves the record fault where it was.
		var other: String = "P02"
		var unfixed: Dictionary = Policy.revision(parent, 2, [], "", [other])
		_check(unfixed.violations == [rule_id] and unfixed.issue_ref == parent.issue_ref, "An uncited %s stays broken, issue and all." % rule_id)
	# Two record faults: fixing the cited one keeps the other.
	for packet: Dictionary in Catalog.requests():
		var record_faults: Array = packet.violations.filter(func(rule_id: String) -> bool: return rule_id in Policy.RECORD_SCOPED)
		if record_faults.size() < 2: continue
		var revision: Dictionary = Policy.revision(packet, 2, [record_faults[0]], "", [record_faults[0]])
		_check(record_faults[0] not in revision.violations and record_faults[1] in revision.violations, "%s fixes %s and keeps %s." % [packet.id, record_faults[0], record_faults[1]])
	# Revision text is about what was cited, in plain words, never a rule ID.
	for rule_id: String in Policy.RECORD_SCOPED:
		for author: String in ["Maya", "Theo", "June"]:
			var message: String = Policy.revision_message(author, 2, [rule_id], "PR-6004-v2")
			_check(not message.contains(rule_id) and message.to_lower().contains(str(Policy.CITED_WORDS[rule_id][1]).to_lower().left(12)), "Revision notes name what was fixed in plain words: " + message)

# --- Simulation -----------------------------------------------------------------

func _land(state: Dictionary) -> Dictionary:
	if not Simulation.active_request(state).is_empty() or Simulation.next_landing(state) < 0: return state
	return Simulation.advance(state, Simulation.next_landing(state) - int(state.shift_seconds))

## A career with `pr_id` on the desk (Helios takes every earlier day; earlier PRs that
## day are approved).
func _desk_at(pr_id: String) -> Dictionary:
	var target: Dictionary = Catalog.packet({}, pr_id)
	var state := Simulation.initial_state()
	while int(state.day) < int(target.day):
		state = Simulation.dispatch(Simulation.advance(state, Catalog.shift_seconds()), {"type": "next-day", "choice": "rest"})
	state = _land(state)
	while str(state.active_request_id) != pr_id and not Simulation.active_request(state).is_empty():
		state = _land(Simulation.dispatch(state, {"type": "review", "verdict": "approve"}))
	return state

## Stamp CHANGES REQUESTED; an author who pushes back is answered by insisting.
func _stamp(state: Dictionary) -> Dictionary:
	var next := Simulation.dispatch(state, {"type": "review", "verdict": "request_changes"})
	if not Encounters.pending(next).is_empty(): next = Simulation.dispatch(next, {"type": "pushback", "choice": "insist"})
	return next

func _round_trip(state: Dictionary, message: String) -> void:
	var raw := Simulation.serialize_save(state)
	var loaded: Dictionary = Simulation.validate_save(JSON.parse_string(raw)) if not raw.is_empty() else {"ok": false}
	_check(loaded.ok and loaded.state == state, message)

func _test_simulation() -> void:
	var packet := _packet_with(["P19"])
	var state := _desk_at(str(packet.id))
	_check(str(state.active_request_id) == str(packet.id), "The red-build PR reaches the desk.")
	var desk: Dictionary = Simulation.active_request(state)
	_check(desk.has("build") and desk.has("issues") and desk.issue_ref == packet.issue_ref and not desk.has("findings") and not desk.has("violations") and not desk.has("recipe"), "The desk view carries the PR's records, never its audit.")
	var cite: Dictionary = Catalog.audit_citation(packet, "P19")
	_check(cite.get("record", "") == "build" and cite.get("id", "") == str(packet.build.id), "The audit points at the PR's build.")
	var cited := Simulation.dispatch(state, cite)
	_check(cited.selected_rules == ["P19"] and cited.citation_evidence.P19 == {"record": "build", "id": str(packet.build.id)}, "Ticking P19 with the build selected pins it to the build.")
	_round_trip(cited, "A pending record citation survives a save round trip.")
	var stamped := _stamp(cited)
	_check(stamped.decisions[-1].evidence.P19 == {"record": "build", "id": str(packet.build.id)} and stamped.decisions[-1].correct, "The record citation is graded correct and journaled.")
	var review_action: Dictionary = {}
	for action: Dictionary in stamped.actions:
		if action.type in ["review", "pushback"] and action.get("pr_id", "") == str(packet.id) and action.has("evidence"): review_action = action
	_check(review_action.get("evidence", {}).get("P19", {}) == {"record": "build", "id": str(packet.build.id)}, "The journal records the build as the evidence.")
	_round_trip(stamped, "A review with record evidence replays from the journal.")
	var forged := stamped.duplicate(true)
	for action: Dictionary in forged.actions:
		if action.has("evidence") and action.evidence.has("P19"): action.evidence.P19.id = "#9999"
	_check(not Simulation.validate_save(forged).ok, "A journal citing a build Pipeline never showed is rejected.")
	forged = stamped.duplicate(true)
	for action: Dictionary in forged.actions:
		if action.has("evidence") and action.evidence.has("P19"): action.evidence.P19 = {"path": str(packet.files[0].path), "line": 0}
	_check(not Simulation.validate_save(forged).ok, "A journal can't swap its record evidence for a file.")
	# The wrong record, or WHOLE FILE, is a real choice the player can make, and it's wrong.
	var whole := Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": "P19", "path": str(packet.files[0].path), "line": 0})
	_check(whole.selected_rules == ["P19"], "WHOLE FILE can be pointed at a build standard.")
	_check(not _stamp(whole).decisions[-1].correct, "But it isn't evidence for one: the review is graded incorrect.")
	var as_issue := Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": "P19", "record": "issue", "id": str(packet.issue_ref)})
	_check(as_issue.selected_rules == ["P19"] and not _stamp(as_issue).decisions[-1].correct, "The PR's issue is not evidence for a build standard.")
	var visible: Array = Catalog.builds(state)
	var other_build: String = ""
	for build: Dictionary in visible:
		if str(build.id) != str(packet.build.id): other_build = str(build.id)
	if not other_build.is_empty():
		var wrong := Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": "P19", "record": "build", "id": other_build})
		_check(wrong.selected_rules == ["P19"] and not _stamp(wrong).decisions[-1].correct, "Another PR's build, though visible, is the wrong evidence.")
	_check(Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": "P19", "record": "build", "id": "#9999"}) == state, "A build Pipeline doesn't show can't be selected.")
	_check(Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": "P19", "record": "invoice", "id": str(packet.build.id)}) == state, "Only issues and builds are records.")
	_check(Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": "P19", "record": "build", "id": 4412}) == state, "A record ID must be a string.")
	# A PR that links no issue is cited with its empty link.
	var unlinked := _packet_with(["P16"])
	for candidate: Dictionary in Catalog.requests():
		if candidate.violations == ["P16"] and candidate.issue_ref.is_empty(): unlinked = candidate
	var at := _desk_at(str(unlinked.id))
	var empty_cite := Simulation.dispatch(at, Catalog.audit_citation(unlinked, "P16"))
	_check(unlinked.issue_ref.is_empty() and empty_cite.citation_evidence.get("P16", {}) == {"record": "issue", "id": ""}, "A missing link is selected as the PR's empty issue.")
	_round_trip(empty_cite, "An empty-link citation survives a save round trip.")
	# Before Lineal is installed there are no records to point at.
	var monday := Simulation.initial_state()
	_check(Simulation.dispatch(monday, {"type": "toggle-rule", "rule_id": "P01", "record": "issue", "id": ""}) == monday, "No issue can be selected before Lineal exists.")
	# What Lineal and Pipeline show never runs ahead of the desk.
	var line_ids: Array = state.desk_line
	for issue: Dictionary in Catalog.issues(state):
		for pr_id: Variant in line_ids:
			var waiting: Dictionary = Catalog.packet(state, str(pr_id), false)
			_check(waiting.get("issues", []).is_empty() or str(issue.id) != str(waiting.issues[0].id), "Lineal never shows the issue of a PR still in line.")
	for build: Dictionary in Catalog.builds(state):
		_check(str(build.pr_id) not in line_ids, "Pipeline never shows the build of a PR still in line.")

# --- Apps -----------------------------------------------------------------------

func _texts(node: Node) -> String:
	var words := ""
	for child: Node in node.find_children("*", "", true, false):
		if child is Label or child is Button: words += str(child.text) + "\n"
		if child is Control: words += str(child.tooltip_text) + "\n"
	return words

## The UI tests' career: commands from the interface go through here, like main.gd.
var app_state: Dictionary = {}
var app_ui: Interface

func _app_command(command: Dictionary) -> void:
	app_state = Simulation.dispatch(app_state, command)
	app_ui.render_state(app_state)

func _test_apps() -> void:
	root.size = Vector2i(1280, 900)
	# A PR with a vibes-labeled issue (the link resolves) and a red build.
	var packet: Dictionary = {}
	for candidate: Dictionary in Catalog.requests():
		if packet.is_empty() and "P16" in candidate.violations and "P19" in candidate.violations and not Records.find(candidate.issues, candidate.issue_ref).is_empty(): packet = candidate
	_check(not packet.is_empty(), "Some PR has a vibes issue and a red build.")
	app_state = _desk_at(str(packet.id))
	var ui: Interface = Interface.new()
	app_ui = ui
	ui.command_requested.connect(_app_command)
	root.add_child(ui)
	ui.render_state(app_state)
	for frame in range(4): await process_frame
	_check(ui._home_icons.lineal.visible and ui._home_icons.pipeline.visible, "Lineal and Pipeline are installed by day %d." % int(app_state.day))
	_check(ui._pr_refs.visible and ui._issue_link.text.contains(packet.issue_ref) and ui._build_link.visible and ui._build_link.text.contains(str(packet.build.id)), "The PR slip names the PR's issue and build.")
	ui._issue_link.pressed.emit()
	for frame in range(3): await process_frame
	_check(ui._windows.lineal.visible and ui._lineal_view.get("issue", "") == packet.issue_ref, "Clicking the issue on the slip opens Lineal on that issue.")
	var issue: Dictionary = Records.find(packet.issues, packet.issue_ref)
	var lineal_text := _texts(ui._lineal_detail)
	for value: String in [str(issue.id), str(issue.title), str(issue.assignee), str(issue.component)]:
		_check(lineal_text.contains(value), "Lineal shows the issue's %s." % value)
	_check(lineal_text.contains(str(issue.status).to_upper()) or lineal_text.contains(str(issue.status)), "Lineal shows the issue's status.")
	var select: Button = null
	for button: Node in ui._lineal_detail.find_children("*", "Button", true, false):
		if str(button.text).begins_with("SELECT"): select = button
	_check(select != null and not select.disabled, "The issue has a SELECT AS EVIDENCE control.")
	if select != null: select.pressed.emit()
	_check(ui._evidence == {"record": "issue", "id": packet.issue_ref} and ui._evidence_label.text == "> ISSUE %s selected" % packet.issue_ref, "Selecting the issue shows it as Review's evidence.")
	_check(ui._windows.review.visible, "Selecting evidence brings Review up for the tick.")
	ui._flag_buttons.P16.pressed.emit()
	_check(app_state.citation_evidence.get("P16", {}) == {"record": "issue", "id": packet.issue_ref} and ui._slip_rows.P16.where.text.contains("ISSUE " + packet.issue_ref), "Ticking P16 cites the issue, and the slip says so.")
	_check(ui._evidence.is_empty(), "The evidence is used up by the tick.")
	ui._build_link.pressed.emit()
	for frame in range(3): await process_frame
	_check(ui._windows.pipeline.visible and ui._pipeline_build == str(packet.build.id), "Clicking the build on the slip opens Pipeline on that build.")
	var pipeline_text := _texts(ui._pipeline_detail)
	_check(pipeline_text.contains(str(packet.build.id)) and pipeline_text.contains(Records.status_text(packet.build)) and pipeline_text.contains(Records.coverage_text(int(packet.build.coverage_before))) and pipeline_text.contains(Records.coverage_text(int(packet.build.coverage_after))), "Pipeline shows the build's status and coverage.")
	_check(packet.build.tests.all(func(test: Dictionary) -> bool: return pipeline_text.contains(str(test.name))), "Pipeline lists the build's tests.")
	select = null
	for button: Node in ui._pipeline_detail.find_children("*", "Button", true, false):
		if str(button.text).begins_with("SELECT"): select = button
	if select != null: select.pressed.emit()
	_check(ui._evidence_label.text == "> BUILD %s selected" % str(packet.build.id), "Selecting the build shows it as Review's evidence.")
	ui._flag_buttons.P19.pressed.emit()
	_check(app_state.citation_evidence.get("P19", {}) == {"record": "build", "id": str(packet.build.id)}, "Ticking P19 cites the build.")
	# No audit leaks: the apps show records, never findings or rule IDs.
	var shown := _texts(ui._windows.lineal) + _texts(ui._windows.pipeline)
	for finding: Dictionary in packet.findings:
		_check(not shown.contains(str(finding.message)), "The apps never show an audit finding: " + str(finding.message))
	# Audit is a department here (its issues are scenery); the words that would
	# grade a PR are what must never appear.
	for word: String in ["violat", "compliant"]:
		_check(not shown.to_lower().contains(word.to_lower()), "The apps never say %s." % word)
	# Searching Lineal by ID finds the issue; a stranger's ID finds nothing to select.
	ui._lineal_search.text = "pap-101"
	ui._lineal_find(ui._lineal_search.text)
	_check(ui._lineal_view.get("issue", "") == "PAP-101" and _texts(ui._lineal_detail).contains("Decide whether the review gate needs a human"), "Lineal finds an issue by its ID, in any case.")
	ui._lineal_search.text = "PAP-99999"
	ui._lineal_find(ui._lineal_search.text)
	_check(ui._lineal_view.has("none") and ui._lineal_detail.find_children("*", "Button", true, false).is_empty(), "An issue Lineal doesn't have offers nothing to select.")
	var stamped_ok := not ui._reject.disabled
	ui._reject.pressed.emit()
	if not Encounters.pending(app_state).is_empty(): ui._answer_pushback("insist")
	_check(stamped_ok and app_state.decisions[-1].pr_id == str(packet.id) and app_state.decisions[-1].correct, "The record citations stamp a correct change request.")
	ui.queue_free()
	await process_frame
	# A PR that links nothing: the slip says so, and Lineal offers the empty link as evidence.
	var unlinked: Dictionary = {}
	for candidate: Dictionary in Catalog.requests():
		if candidate.violations == ["P16"] and candidate.issue_ref.is_empty() and int(candidate.day) >= Policy.LINEAL_DAY: unlinked = candidate
	_check(not unlinked.is_empty(), "Some PR links no issue at all.")
	if unlinked.is_empty(): return
	app_state = _desk_at(str(unlinked.id))
	var second: Interface = Interface.new()
	app_ui = second
	second.command_requested.connect(_app_command)
	root.add_child(second)
	second.render_state(app_state)
	for frame in range(4): await process_frame
	_check(second._issue_link.text == "No issue linked →", "The slip of a PR without an issue says so.")
	second._home_icons.lineal.pressed.emit()
	_check(second._windows.lineal.visible and second._lineal_view == {"link": ""} and _texts(second._lineal_detail).contains("NO ISSUE LINKED"), "Opening Lineal from its icon shows the desk PR's link: none.")
	for button: Node in second._lineal_detail.find_children("*", "Button", true, false):
		if str(button.text).begins_with("SELECT"): button.pressed.emit()
	_check(second._evidence_label.text == "> NO ISSUE selected", "The empty link can be selected as evidence.")
	second._flag_buttons.P16.pressed.emit()
	_check(app_state.citation_evidence.get("P16", {}) == {"record": "issue", "id": ""}, "Ticking P16 cites the empty link.")
	second.queue_free()
	await process_frame
	# Before Wednesday there is no Lineal, and before Friday no Pipeline.
	var early: Interface = Interface.new()
	root.add_child(early)
	early.render_state(Simulation.initial_state())
	for frame in range(2): await process_frame
	_check(not early._home_icons.lineal.visible and not early._home_icons.pipeline.visible and not early._pr_refs.visible, "Monday has no Lineal, no Pipeline, and no record links on the slip.")
	early._open_app("lineal")
	_check(not early._windows.lineal.visible, "An app that isn't installed yet doesn't open.")
	early.queue_free()
	await process_frame
