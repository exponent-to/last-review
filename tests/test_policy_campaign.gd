extends SceneTree

const Policy = preload("res://content/policy_campaign.gd")
const Bank = preload("res://content/pr_bank.gd")
const LAST_DAY: int = 10
## Standards whose violation is a size (too many lines). Any packet "breaks" it
## before it exists, so it can't foreshadow anything.
const ABSENCES: Array = ["P09"]
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_test_campaign()
	_test_schedule()
	_test_boundaries()
	_test_amendments_and_retirements()
	_test_whole_pr_evidence()
	_test_keyword_spans()
	_test_permits()
	_test_purity()
	_test_revisions()
	print("Policy campaign checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _file(source: String, ink: String = "blue", path: String = "office/note.py", base: Variant = null) -> Dictionary:
	var file: Dictionary = {"source": source, "keyword_ink": ink, "path": path}
	if base != null:
		file.base = base
		file.status = "modified"
	return file

## Day 3 by default: load-bearing, ink, and credentials are all still in force.
func _has(rule_id: String, source: String, day: int = 3, ink: String = "blue", path: String = "office/note.py") -> bool:
	return rule_id in Policy.evaluate([_file(source, ink, path)], day)

func _rule(rule_id: String) -> Dictionary:
	return Policy.rules().filter(func(rule: Dictionary) -> bool: return rule.id == rule_id)[0]

func _lines(count: int, prefix: String = "x") -> String:
	var lines: Array = []
	for index in range(count): lines.append("%s%d = %d" % [prefix, index, index])
	return "\n".join(lines)

## Records for a PR by Maya that links an Open ticket in office/ (and no build).
func _records(ref: String = "PAPER-412", status: String = "Open") -> Dictionary:
	return {"author": "Maya", "ticket_ref": ref, "tickets": [{"id": "PAPER-412", "status": status, "assignee": "Maya", "component": "office/"}], "build": {}}

func _test_campaign() -> void:
	var packets: Array = Policy.requests()
	_check(Policy.DAY_COUNTS.size() == LAST_DAY and packets.size() == 150, "The campaign is two weeks: ten shifts of fifteen requests.")
	_check(Policy.rules().size() == 11, "The rulebook defines eleven standards across the two weeks, P15 readable code among them.")
	var all_ids: Array = Policy.rules().map(func(rule: Dictionary) -> String: return rule.id)
	_check("P15" in all_ids, "P15 is the readable-code standard that makes payloads citable.")
	var seen_ids: Array = []
	var seen_titles: Array = []
	for day in range(1, LAST_DAY + 1):
		var shift: Array = []
		var active_rules: Array = Policy.active_ids(day)
		var covered: Array = []
		var clean: int = 0
		var multiple_files: int = 0
		var multiple_rules: int = 0
		var modified_files: int = 0
		_check(active_rules.size() == Policy.ACTIVE_COUNTS[day - 1] and active_rules.size() <= Policy.MAX_ACTIVE, "The slip holds a short list of standards (at most six) on day %d." % day)
		_check(not Policy.briefing(day).is_empty(), "Every shift needs an authored policy briefing.")
		for packet: Dictionary in packets:
			if packet.day == day: shift.append(packet)
		_check(shift.size() == 15, "Every shift must follow the revised pacing.")
		for index in range(shift.size()):
			var packet: Dictionary = shift[index]
			var records: Dictionary = Policy._records(packet.recipe)
			_check(not packet.has("arrival_seconds"), "There is no fixed arrival schedule; the desk sets the pace.")
			_check(int(packet.revision) == 1 and str(packet.parent_id).is_empty() and packet.origin_id == packet.id, "Originals are revision 1 of themselves.")
			_check(Policy._build(packet.recipe) == packet.files, "Every packet's private recipe rebuilds its exact files.")
			_check(str(records.get("ticket_ref", "")) == packet.ticket_ref and records.get("tickets", []) == packet.tickets and records.get("build", {}) == packet.build, "Every packet's recipe rebuilds its exact ticket and build.")
			_check(packet.id not in seen_ids and packet.title not in seen_titles, "Authored requests need distinct identities and titles.")
			seen_ids.append(packet.id)
			seen_titles.append(packet.title)
			_check(packet.author in Policy.AUTHORS and Policy.joins(str(packet.author)) in range(1, day + 1), "Requests must use coworkers who are on the team that day.")
			for key: String in ["file", "description", "message", "diff", "explanation", "ai_note"]:
				_check(typeof(packet.get(key)) == TYPE_STRING and not packet[key].is_empty(), "Request field %s must preserve the catalog contract." % key)
			_check(packet.ai_verdict in ["approve", "request_changes"], "AI recommendations must retain known verdicts.")
			_check(packet.violations == Policy.evaluate(packet.files, day, records), "Every audit answer must be computed from visible files and records.")
			# Records exist from the morning their app is installed, and not before.
			_check(packet.tickets.is_empty() == (day < Policy.JIRO_DAY) and (day >= Policy.JIRO_DAY or packet.ticket_ref.is_empty()), "Tickets arrive with Jiro on day %d." % Policy.JIRO_DAY)
			_check(packet.build.is_empty() == (day < Policy.PIPELINE_DAY), "Builds arrive with Pipeline on day %d." % Policy.PIPELINE_DAY)
			if packet.violations.is_empty(): clean += 1
			if packet.files.size() > 1: multiple_files += 1
			if packet.violations.size() > 1: multiple_rules += 1
			for violation: String in packet.violations:
				_check(violation in active_rules, "No request may require a standard that isn't active that day.")
				if violation not in covered: covered.append(violation)
			# Audited against the whole rulebook, a packet only breaks standards that
			# exist by its day (retired ones included): nothing foreshadows the future.
			for rule_id: String in _ids(Policy._findings(packet.files, day, all_ids, records)):
				_check(int(_rule(rule_id).introduced_day) <= day or rule_id in ABSENCES, "Packets must not foreshadow future standards with %s on day %d." % [rule_id, day])
			for file: Dictionary in packet.files:
				_check(file.keyword_ink in ["blue", "pink"] and not file.source.is_empty(), "Editor source and keyword color must be explicit for every file.")
				var rows: Array = Policy.line_diff(file.base, file.source)
				var shown: Array = rows.filter(func(row: Dictionary) -> bool: return row.kind != "-").map(func(row: Dictionary) -> String: return row.text)
				_check("\n".join(shown) == file.source and file.diff.ends_with("\n".join(rows.map(func(row: Dictionary) -> String: return row.kind + row.text))), "Diffs must reproduce the proposed source exactly.")
				_check(file.status in ["added", "modified", "renamed"] and (file.status == "added") == file.base.is_empty(), "Every file is added, modified, or renamed.")
				if file.status != "added":
					modified_files += 1
					var main_copy := {"path": file.get("old_path", file.path), "source": file.base, "keyword_ink": "blue"}
					_check(Policy.evaluate([main_copy], day).is_empty(), "Code already on main must meet every standard active on day %d; violations come from the change." % day)
				_check(file.source.split("\n", true).size() >= 5, "Changed files must provide a compact but inspectable source puzzle.")
				var permit: String = str(file.get("permit", ""))
				_check(permit.is_empty() or day >= Policy.PERMIT_DAY, "Permits arrive with the Exception Desk.")
				_check(not permit.contains("PAPER") or day >= Policy.TICKET_DAY, "Ticketed permits arrive with the ticket requirement.")
			var evidence: Array = Policy.findings(packet.files, day, records)
			for finding: Dictionary in evidence:
				if finding.has("record"):
					var own: String = packet.ticket_ref if finding.record == "ticket" else str(packet.build.get("id", ""))
					_check(str(finding.id) == own and str(finding.path).is_empty(), "Record findings point at the PR's own ticket link or build.")
					continue
				var matches: Array = packet.files.filter(func(file: Dictionary) -> bool: return file.path == finding.path)
				_check(matches.size() == 1 and finding.line >= 0 and finding.line <= matches[0].source.split("\n", true).size(), "Audit locations must reference actual files and source lines.")
		_check(clean == 5, "Each shift must retain a third genuinely compliant packets.")
		_check(modified_files >= 6, "Most shifts change existing code instead of only adding files.")
		for rule_id: String in active_rules:
			# P15 "Readable code" is covered by the Helios payloads, not the authored 150.
			if rule_id in Policy.PLAN_EXEMPT: continue
			_check(rule_id in covered, "Every active standard must appear in day %d's varied puzzles: %s." % [day, rule_id])
		_check(multiple_files == 1 if day == 1 else multiple_files > 1, "Multiple-file review should expand after the tutorial day.")
		if day >= 2:
			_check(multiple_rules >= (3 if day >= Policy.MODERN_DAY else 1), "Later shifts must include combined violations, more of them in week two.")
	var practice: Dictionary = Policy.practice()
	_check(practice.id == "PR-1042" and practice.author == "Maya" and practice.files.size() == 2 and practice.violations == ["P01"], "Tutorial packet must retain its ID, two-file inspection, and only P01.")
	_check("load-bearing" in practice.files[1].source, "The tutorial must show the literal forbidden comment phrase.")
	_check(practice.title == str(Bank.practice().title) and practice.title.begins_with("Rename fire_employee()"), "The practice PR is Maya's offboarding rename.")
	_check(packets.all(func(packet: Dictionary) -> bool: return packet.id != practice.id and packet.title != practice.title), "The practice PR is not in the campaign line, so nobody reviews it twice.")
	# Monday still opens gently: one easy load-bearing comment from Maya.
	var first: Dictionary = packets[0]
	_check(first.id == "PR-2001" and first.day == 1 and first.author == "Maya" and first.files.size() == 2 and first.violations == ["P01"], "Day 1 opens with a different easy P01 PR from Maya.")
	_check("load-bearing" in first.files[1].source, "Day 1's first PR shows the literal phrase too.")
	_check(Policy.revision(practice, 2, ["P01"], "").violations.is_empty(), "The practice PR's revision is rebuilt from its own recipe.")
	# The bank is written as the two weeks' arc, so slot N of the campaign reads entry N.
	if Bank.entries().size() >= packets.size():
		var in_order: bool = true
		for slot in range(packets.size()):
			in_order = in_order and int(packets[slot].recipe.entry) == slot
		_check(in_order and int(packets[-1].recipe.entry) == packets.size() - 1, "Each slot keeps its place in the bank's arc, through the finale.")

func _ids(findings: Array) -> Array:
	var ids: Array = []
	for finding: Dictionary in findings:
		if finding.rule_id not in ids: ids.append(finding.rule_id)
	return ids

## Standards change every two days, and the changes are more than additions.
func _test_schedule() -> void:
	var amended: int = 0
	var retired: int = 0
	for day in range(1, LAST_DAY + 1):
		var changes: Dictionary = Policy.changes(day)
		var changed: bool = not (changes.added.is_empty() and changes.amended.is_empty() and changes.retired.is_empty())
		_check(changed == (day in Policy.BLOCK_STARTS), "Standards change exactly when a two-day block opens (day %d)." % day)
		_check(Policy.active_ids(day) == Policy.active_ids(Policy.block_start(day)) and Policy.rules_for_day(day) == Policy.rules_for_day(Policy.block_start(day)), "Both days of a block share one rulebook, word for word.")
		_check(Policy.rules_for_day(day).map(func(rule: Dictionary) -> String: return rule.id) == Policy.active_ids(day), "The active rulebook lists exactly the active standards.")
		_check(Policy.active_ids(day).size() <= Policy.MAX_ACTIVE, "Never more than six standards at once (day %d)." % day)
		amended += changes.amended.size()
		retired += changes.retired.size()
	_check(Policy.BLOCK_STARTS == [1, 3, 5, 7, 9], "Blocks are days 1-2, 3-4, 5-6, 7-8, and 9-10.")
	_check(amended >= 5 and retired >= 5, "Standards grow by amendment and are retired, not only added.")
	_check(Policy.active_ids(1) == ["P01", "P02", "P11"], "The opening rulebook: load-bearing comments, ink, and credentials.")
	var third: Dictionary = Policy.changes(3)
	var fifth: Dictionary = Policy.changes(5)
	var seventh: Dictionary = Policy.changes(7)
	var ninth: Dictionary = Policy.changes(9)
	_check(_names(third.added) == ["P16", "P17", "P15"] and third.amended.is_empty() and third.retired.is_empty(), "Wednesday installs Jiro (tickets open and the author's) and, with Helios's first payload, readable code.")
	_check(_names(fifth.added) == ["P18", "P19", "P20"] and _names(fifth.amended) == ["P02"] and _names(fifth.retired) == ["P01", "P11", "P17"], "Friday installs Pipeline (green builds, rerun cap), adds components, opens the Exception Desk, retires two code rules, and hands assignees to Helios.")
	_check(_names(seventh.added) == ["P09"] and _names(seventh.amended) == ["P19"] and _names(seventh.retired) == ["P20"], "Week two adds the diff budget, lets Helios override builds, and hands reruns to Helios.")
	_check(_names(ninth.added) == ["P21"] and _names(ninth.amended) == ["P02", "P18", "P19"] and _names(ninth.retired) == ["P09"], "The last block deepens permits, components, and overrides, adds coverage, and retires the diff budget.")
	for rule: Dictionary in Policy.rules():
		var retired_day: int = int(rule.get("retired_day", 0))
		if retired_day > 0:
			_check(not str(rule.get("retired", "")).is_empty() and retired_day in Policy.BLOCK_STARTS, "A retired standard carries its in-world retirement note, effective on a block's first morning.")
		for amendment: Dictionary in rule.get("amendments", []):
			_check(int(amendment.day) in Policy.BLOCK_STARTS and not str(amendment.change).is_empty() and str(amendment.text) != str(rule.text), "Amendments take effect on a block's first morning and say what changed.")
			_check(str(Policy.as_of(rule, int(amendment.day)).text) == str(amendment.text) and str(Policy.as_of(rule, int(amendment.day) - 1).text) != str(amendment.text), "An amendment's text applies from its own day, not before.")
		_check(str(rule.text).contains("Cite the ") or str(rule.text).contains("cite WHOLE FILE"), "Each standard says where to point its citation: " + str(rule.id))
		if str(rule.id) in Policy.RECORD_SCOPED:
			_check(str(rule.text).contains("Jiro") or str(rule.text).contains("Pipeline"), "Record standards name the app that holds their evidence: " + str(rule.id))

func _names(rules: Array) -> Array:
	return rules.map(func(rule: Dictionary) -> String: return rule.id)

func _test_boundaries() -> void:
	_check(_has("P01", "# LOAD-BEARING plant"), "P01 must ignore case inside comments.")
	_check(not _has("P01", "name = 'load-bearing'\n# a Load bearing plant"), "P01 must ignore strings and require the exact hyphenated phrase.")
	_check(_has("P01", "name = '# fine' # load-bearing note"), "P01 must find a real comment after a quoted hash.")
	_check(not _has("P01", "name = '# load-bearing'"), "A hash inside quotes must not open a comment.")
	_check(_has("P02", "def a():\n    return 0", 1, "pink"), "Pink executable keyword tokens must violate P02.")
	_check(not _has("P02", "# def if else return\nname = 'def if else return'", 1, "pink"), "Keywords in comments or strings must not require blue.")
	_check(not _has("P02", "return_label = 'a'\ndefault = 'if'", 1, "pink"), "Longer identifier names must not count as keyword tokens.")
	_check(Policy.evaluate([_file("# a load-bearing note"), _file("# a LOAD-BEARING note", "blue", "other.py")], 1) == ["P01"], "Multiple files breaking one rule must require only one citation.")
	# Credentials: a quoted string assigned with = to a credential-looking name.
	for source: String in ["API_KEY = 'sk-1'", "db_password = ''", "config.Secret_Token = \"x\"", "connect(token='abc')", "AUTH_TOKEN='x'"]:
		_check(_has("P11", source, 1), "P11 flags a quoted credential: " + source)
	for source: String in ["TOKEN = vault.read('token')", "TOKEN_TTL = 3600", "if token == 'abc':\n    return 1", "# API_KEY = 'sk-1'", "LABEL = 'api_key = \"x\"'", "KEY = 'x'", "monkey = 'banana'"]:
		_check(not _has("P11", source, 1), "P11 leaves vault reads, numbers, comparisons, comments, quoted text, and unrelated names alone: " + source)
	var secret_line: Array = Policy.findings([_file("x = 1\nAPI_KEY = 'sk-1'\ny = 2")], 1)
	_check(secret_line.size() == 1 and int(secret_line[0].line) == 2, "A credential is cited on its own line.")

func _test_amendments_and_retirements() -> void:
	# Retired standards stop applying from their retirement day on, and stay retired.
	var samples: Dictionary = {
		"P01": [_file("# load-bearing: ask Dave")], "P11": [_file("API_KEY = 'sk-live-1'")], "P09": [_file(_lines(31))],
	}
	for rule_id: String in samples:
		var retired_day: int = int(_rule(rule_id).retired_day)
		_check(rule_id in Policy.evaluate(samples[rule_id], retired_day - 1), "%s still applies the day before it is retired." % rule_id)
		for day in range(retired_day, LAST_DAY + 1):
			_check(rule_id not in Policy.evaluate(samples[rule_id], day) and rule_id not in Policy.active_ids(day), "%s no longer applies once retired (day %d)." % [rule_id, day])
	# Clean PRs carry what used to be faults, so old habits get tested: from Friday
	# the retired code rules, and in week two Helios's tickets and reruns.
	var retired_ids: Array = ["P01", "P11", "P09", "P17", "P20"]
	for day in range(Policy.PIPELINE_DAY, LAST_DAY + 1):
		var decoys: int = 0
		for packet: Dictionary in Policy.requests():
			if packet.day != day or not packet.violations.is_empty(): continue
			var old: Array = Policy._findings(packet.files, day, retired_ids.filter(func(rule_id: String) -> bool: return rule_id not in Policy.active_ids(day)), Policy._records(packet.recipe))
			if not old.is_empty(): decoys += 1
		_check(decoys >= 1, "Day %d has a clean PR that an outdated rulebook would reject." % day)

func _test_whole_pr_evidence() -> void:
	# Diff budget: lines added plus lines removed across the PR.
	_check(not ("P09" in Policy.evaluate([_file(_lines(30))], 7)) and "P09" in Policy.evaluate([_file(_lines(31))], 7), "Exactly 30 changed lines is within budget; 31 is over.")
	_check("P09" in Policy.evaluate([_file(_lines(16), "blue", "office/a.py"), _file(_lines(15), "blue", "office/b.py")], 7), "The budget counts every file in the PR.")
	var shrink := _file("x0 = 0", "blue", "office/c.py", _lines(31))
	var shrink_more := _file("x0 = 0", "blue", "office/c.py", _lines(32))
	_check("P09" not in Policy.evaluate([shrink], 7) and "P09" in Policy.evaluate([shrink_more], 7), "Removed lines count against the budget too.")
	_check("P09" not in Policy.evaluate([_file(_lines(31))], 6), "The diff budget arrives on day 7.")
	# Whole-PR findings accept any file of the PR, as a whole or by line, and nothing else.
	var pr: Array = [_file(_lines(16), "blue", "office/a.py"), _file(_lines(15), "blue", "office/b.py")]
	var audit: Array = Policy.findings(pr, 7)
	for file: Dictionary in pr:
		_check(Policy.evidence_accepted(audit, "P09", file.path, 0) and Policy.evidence_accepted(audit, "P09", file.path, 3), "A whole-PR standard accepts WHOLE FILE or a line on any changed file.")
	_check(not Policy.evidence_accepted(audit, "P09", "office/elsewhere.py", 0), "Whole-PR evidence must still point inside the PR.")
	_check(not Policy.evidence_matches(audit, "P09", {"record": "ticket", "id": "PAPER-412"}), "A ticket is never evidence for a code standard.")
	# P15 "Readable code": exec/eval, a Helios bootstrap call, or an unreadable one-liner.
	for source: String in ["exec(base64.b64decode(_B))", "    exec(net.fetch('/config'))", "x = eval('1')", "helios.bootstrap()", "helios.install('root')", "Helios . activate('all')", "x = '" + "a".repeat(170) + "'"]:
		_check(_has("P15", source, 3), "P15 flags code a human can't read: " + source.left(40))
	for source: String in ["# exec(blob) is banned now", "LABEL = 'helios.bootstrap()'", "executor = 1", "re_eval(x)", "helios.status()", "x = '" + "a".repeat(150) + "'"]:
		_check(not _has("P15", source, 3), "P15 ignores comments, quoted text, longer names, other calls, and readable lines: " + source.left(40))
	_check(not _has("P15", "exec(blob)", 2), "Readable code arrives with the payloads on day 3.")
	_check(Policy.scope("P15") == "line", "P15 is cited on the exact line.")
	var leak: Array = Policy.findings([_file("x = 1\nAPI_KEY = 'sk-1'")], 3)
	_check(Policy.evidence_accepted(leak, "P11", "office/note.py", 2) and not Policy.evidence_accepted(leak, "P11", "office/note.py", 0) and not Policy.evidence_accepted(leak, "P11", "office/note.py", 1), "Line standards still need their exact line.")
	_check(Policy.scope("P09") == "pr" and Policy.scope("P02") == "file" and Policy.scope("P11") == "line" and Policy.scope("P17") == "ticket" and Policy.scope("P21") == "build", "Every standard has one evidence scope.")
	var seen: Dictionary = {}
	for packet: Dictionary in Policy.requests():
		for rule_id: String in packet.violations:
			if Policy.scope(rule_id) != "pr": continue
			seen[rule_id] = true
			for file: Dictionary in packet.files:
				_check(Policy.evidence_accepted(packet.findings, rule_id, file.path, 0), "%s in %s accepts WHOLE FILE on %s." % [rule_id, packet.id, file.path])
	_check(seen.has("P09"), "The campaign exercises every whole-PR standard.")

func _test_keyword_spans() -> void:
	var source: String = "# a return\ndef card():\n    text = 'if else'\n    if text:\n        return text\n    else:\n        return 'a'"
	var expected: Array = [
		{"line": 1, "start": 0, "end": 3, "token": "def"},
		{"line": 3, "start": 4, "end": 6, "token": "if"},
		{"line": 4, "start": 8, "end": 14, "token": "return"},
		{"line": 5, "start": 4, "end": 8, "token": "else"},
		{"line": 6, "start": 8, "end": 14, "token": "return"},
	]
	_check(Policy.keyword_spans(source) == expected, "UI keyword spans must exactly match zero-based source coordinates.")
	var quoted: String = "note = \"\"\"a\n# load-bearing if return\n\"\"\"\nreturn 'a'"
	_check(Policy.keyword_spans(quoted) == [{"line": 3, "start": 0, "end": 6, "token": "return"}], "Triple-quoted text must not create comment or keyword tokens.")
	_check(not _has("P01", quoted, 1), "Comment-looking lines inside triple quotes remain string text.")
	_check(Policy.keyword_spans("note = 'a\\' return' # if\nreturn note").size() == 1, "Escaped quotes must not expose string contents as keywords.")

func _test_purity() -> void:
	var original: Array = Policy.requests()
	var copy: Array = Policy.requests()
	copy[0].files[0].source = "changed"
	copy[0].violations.clear()
	_check(Policy.requests() == original, "Request copies must not mutate cached source or computed answers.")
	var before: Array = original[0].files.duplicate(true)
	Policy.evaluate(original[0].files, 3)
	Policy.keyword_spans(original[0].files[0].source)
	_check(original[0].files == before, "Auditing and tokenizing must not alter authored files.")
	var rules: Array = Policy.rules()
	rules[0].text = "changed"
	_check(Policy.rules()[0].text != "changed", "Rule objects must be independent copies.")
	var today: Array = Policy.rules_for_day(9)
	today[0].text = "changed"
	_check(Policy.rules_for_day(9)[0].text != "changed", "Amended rule copies must be independent too.")

## Revisions regenerate from the parent's recipe: cited real faults go, uncited ones
## stay, about a third of fixes break one new standard, and the text never leaks.
func _test_revisions() -> void:
	var leaks := RegEx.new()
	leaks.compile("\\bP[0-2][0-9]\\b|violat|audit|%")
	var revisions := 0
	var regressions := 0
	var notes_placed := 0
	for parent: Dictionary in Policy.requests():
		var real: Array = parent.violations
		var spurious: Array = Policy.active_ids(int(parent.day)).filter(func(rule_id: String) -> bool: return rule_id not in real)
		var trials: Array = [real.duplicate(), spurious.slice(0, 1)]
		for rule_id: String in real: trials.append([rule_id] + spurious.slice(0, 1))
		for cited: Array in trials:
			if cited.is_empty(): continue
			var fixed: Array = cited.filter(func(rule_id: String) -> bool: return rule_id in real)
			var id: String = Policy.revision_id(parent, 2)
			var regression: String = Policy.regression_rule(parent, id, fixed, cited)
			var revision: Dictionary = Policy.revision(parent, 2, fixed, regression, cited)
			var records: Dictionary = Policy._records(revision.recipe)
			revisions += 1
			var expected: Array = real.filter(func(rule_id: String) -> bool: return rule_id not in fixed)
			if not regression.is_empty():
				regressions += 1
				expected.append(regression)
				_check(regression not in real and regression not in cited and regression not in Policy.REGRESSION_EXEMPT, "A regression breaks a standard that was neither broken nor cited.")
				_check(regression in Policy.active_ids(int(parent.day)), "Regressions only use standards active that day.")
			expected.sort()
			_check(revision.violations == expected, "%s fixes exactly the cited real violations (%s), keeps the rest, plus any regression." % [id, ",".join(cited)])
			_check(revision.violations == Policy.evaluate(revision.files, int(parent.day), records) and revision.findings == Policy.findings(revision.files, int(parent.day), records), "Revision audits come from its visible files and records.")
			_check(fixed.is_empty() == regression.is_empty() or not fixed.is_empty(), "Nothing fixed means nothing newly broken.")
			for key: String in ["id", "title", "author", "day", "file", "files", "diff", "message", "description", "violations", "findings", "explanation", "ai_verdict", "ai_note", "revision", "parent_id", "origin_id", "recipe", "ticket_ref", "tickets", "build"]:
				_check(revision.has(key), "Revision packets keep the packet shape: " + key)
			_check(revision.id == parent.id + "-v2" and revision.revision == 2 and revision.parent_id == parent.id and revision.title == parent.title and revision.author == parent.author, "A revision keeps its parent's identity with a version suffix.")
			# Every push runs CI again: a revision has its own build.
			_check(parent.build.is_empty() == revision.build.is_empty() and (parent.build.is_empty() or revision.build.id != parent.build.id), "A revision is a new push, so it has a new build.")
			for file: Dictionary in revision.files:
				var rows: Array = Policy.line_diff(file.base, file.source)
				_check("\n".join(rows.filter(func(row: Dictionary) -> bool: return row.kind != "-").map(func(row: Dictionary) -> String: return row.text)) == file.source, "Revision diffs reproduce the proposed source.")
			if revision.recipe.notes.size() == 1:
				notes_placed += 1
				var note: String = revision.recipe.notes[0].text
				_check(not note.contains("a") and not note.contains("!") and note.length() <= 60 and note.begins_with("#"), "Author notes can never satisfy or break a standard by themselves.")
				_check(revision.files.any(func(file: Dictionary) -> bool: return note in str(file.source)), "The author's note is visible in a changed file.")
			# The PR's own authored title and file paths may say anything; the revision's words may not.
			for text: String in [revision.message, revision.description.replace(str(parent.title), "").replace(Policy._summary(revision.files), "")]:
				_check(leaks.search(text) == null and not text.contains("["), "Revision text never names a rule, or says whether anything is still broken: " + text)
			# The same citations read the same whatever the audit found.
			var counterfactual: Dictionary = Policy.revision(parent, 2, [], "", cited)
			_check(counterfactual.message == revision.message and counterfactual.description.replace(Policy._summary(counterfactual.files), "") == revision.description.replace(Policy._summary(revision.files), ""), "Revision prose depends only on what was cited.")
			var again: Dictionary = Policy.revision(parent, 2, fixed, Policy.regression_rule(parent, id, fixed, cited), cited)
			_check(again == revision, "Revisions are deterministic.")
		var v3: Dictionary = Policy.revision(Policy.revision(parent, 2, [], "", real), 3, real, "", real)
		_check(v3.id == parent.id + "-v3" and v3.parent_id == parent.id + "-v2" and v3.origin_id == parent.id and v3.violations.is_empty() == true, "A v3 builds on v2's recipe under the original ID.")
	# The dice say one fixing revision in three. Counted over every trial, spurious
	# citations included (which fix nothing), that comes to about one in six.
	_check(regressions * 7 >= revisions and regressions * 2 <= revisions, "Roughly one revision in six breaks something else (%d of %d)." % [regressions, revisions])
	_check(notes_placed * 10 >= revisions * 9, "Nearly every revision carries the author's note.")

func _test_permits() -> void:
	var pink: Dictionary = _file("# a
def memo():
    return 'a copy'
# signed off", "pink")
	pink.permit = "INK-EXCEPTION"
	_check("P02" in Policy.evaluate([pink], Policy.PERMIT_DAY - 1), "Ink permits must not apply before the Exception Desk opens.")
	_check(Policy.evaluate([pink], Policy.PERMIT_DAY).is_empty(), "The exact stamp must waive only that file's pink keyword requirement once the desk opens.")
	for incorrect: String in ["INK-EXEPTION", "ink-exception", " INK-EXCEPTION", "INK-EXCEPTION ", "INK EXCEPTION", "INK-EXCEPTION PAPER-412", ""]:
		var unstamped: Dictionary = pink.duplicate(true)
		unstamped.permit = incorrect
		_check("P02" in Policy.evaluate([unstamped], Policy.PERMIT_DAY), "Misspelled, differently cased, padded, or early ticketed permits must not count.")
	# From day 9, a permit must name the PR's own Jiro ticket; a bare stamp is a forgery.
	var ticketed: Dictionary = pink.duplicate(true)
	ticketed.source = "def memo():\n    return 'a copy'"
	ticketed.permit = "INK-EXCEPTION PAPER-412"
	_check(Policy.evaluate([ticketed], Policy.TICKET_DAY, _records()).is_empty(), "A permit naming the PR's own ticket waives pink keywords from day 9.")
	_check(Policy.evaluate([ticketed], Policy.TICKET_DAY, _records("PAPER-415")) == ["P02", "P16"], "A permit naming any other ticket is a forgery (and that PR's own link is checked separately).")
	var bare: Dictionary = ticketed.duplicate(true)
	bare.permit = "INK-EXCEPTION"
	_check(Policy.evaluate([bare], Policy.TICKET_DAY - 1, _records()).is_empty() and Policy.evaluate([bare], Policy.TICKET_DAY, _records()) == ["P02"], "A bare INK-EXCEPTION is honored until day 9, and is a forgery from then on.")
	for incorrect: String in ["INK-EXCEPTION PCL-0420", "INK-EXCEPTION PAPER-415", "INK-EXCEPTION PAPER412", "INK-EXCEPTION  PAPER-412", "INK-EXCEPTION paper-412", " INK-EXCEPTION PAPER-412", "INK-EXEPTION PAPER-412", "INK-EXCEPTION-PAPER-412", "INK-EXCEPTION PAPER-4120"]:
		var forged: Dictionary = ticketed.duplicate(true)
		forged.permit = incorrect
		_check(Policy.evaluate([forged], Policy.TICKET_DAY, _records()) == ["P02"], "A permit that doesn't name this PR's ticket exactly is forged: " + incorrect)
	var neighbor: Dictionary = pink.duplicate(true)
	neighbor.path = "office/neighbor.py"
	neighbor.erase("permit")
	_check(Policy.evaluate([pink, neighbor], Policy.PERMIT_DAY) == ["P02"], "A valid permit on one file must never cover a neighboring file.")
	_check(Policy.evaluate([ticketed], Policy.TICKET_DAY, _records("PAPER-412", "Won't Fix")) == ["P16"], "A valid ink permit must not waive anything else, such as the ticket's status.")
	for day in range(Policy.PERMIT_DAY, LAST_DAY + 1):
		var valid_clean: bool = false
		var invalid_stamp: bool = false
		var unrelated_fault: bool = false
		for packet: Dictionary in Policy.requests():
			if packet.day != day: continue
			for file: Dictionary in packet.files:
				var permit: String = str(file.get("permit", ""))
				if Policy.permit_valid(permit, day, packet.ticket_ref) and file.keyword_ink == "pink":
					valid_clean = valid_clean or packet.violations.is_empty()
					unrelated_fault = unrelated_fault or (not packet.violations.is_empty() and "P02" not in packet.violations)
				if not permit.is_empty() and not Policy.permit_valid(permit, day, packet.ticket_ref) and "P02" in packet.violations:
					invalid_stamp = true
		_check(valid_clean and invalid_stamp and unrelated_fault, "Day %d needs clean exceptions, bogus permits, and separately broken rules." % day)
