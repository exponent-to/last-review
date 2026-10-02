extends SceneTree

const Policy = preload("res://content/policy_campaign.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_test_campaign()
	_test_boundaries()
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

func _file(source: String, ink: String = "blue", path: String = "office/note.py") -> Dictionary:
	return {"source": source, "keyword_ink": ink, "path": path}

func _has(rule_id: String, source: String, day: int = 5, ink: String = "blue", path: String = "office/note.py") -> bool:
	return rule_id in Policy.evaluate([_file(source, ink, path)], day)

func _test_campaign() -> void:
	var packets: Array = Policy.requests()
	_check(packets.size() == 75, "Campaign must have five authored shifts of fifteen requests.")
	_check(Policy.rules().size() == 9, "The campaign must define exactly the approved nine policies.")
	var seen_ids: Array = []
	var seen_titles: Array = []
	for day in range(1, 6):
		var shift: Array = []
		var active_rules: Array = []
		var introduced: int = 0
		var covered: Array = []
		var clean: int = 0
		var multiple_files: int = 0
		var multiple_rules: int = 0
		var modified_files: int = 0
		for rule: Dictionary in Policy.rules():
			if rule.introduced_day <= day: active_rules.append(rule.id)
			if rule.introduced_day == day: introduced += 1
		_check(introduced == [3, 2, 2, 1, 1][day - 1] and active_rules.size() == Policy.ACTIVE_COUNTS[day - 1], "Standards must follow the fixed five-day escalation.")
		_check(not Policy.briefing(day).is_empty(), "Every shift needs an authored policy briefing.")
		for packet: Dictionary in packets:
			if packet.day == day: shift.append(packet)
		_check(shift.size() == 15, "Every shift must follow the revised pacing.")
		for index in range(shift.size()):
			var packet: Dictionary = shift[index]
			_check(not packet.has("arrival_seconds"), "There is no fixed arrival schedule; the desk sets the pace.")
			_check(int(packet.revision) == 1 and str(packet.parent_id).is_empty() and packet.origin_id == packet.id, "Originals are revision 1 of themselves.")
			_check(Policy._build(packet.recipe) == packet.files, "Every packet's private recipe rebuilds its exact files.")
			_check(packet.id not in seen_ids and packet.title not in seen_titles, "Authored requests need distinct identities and titles.")
			seen_ids.append(packet.id)
			seen_titles.append(packet.title)
			_check(packet.author in ["Maya", "Theo", "Inez"], "Requests must use existing coworker identities.")
			for key: String in ["file", "description", "message", "diff", "explanation", "ai_note"]:
				_check(typeof(packet.get(key)) == TYPE_STRING and not packet[key].is_empty(), "Request field %s must preserve the catalog contract." % key)
			_check(packet.ai_verdict in ["approve", "request_changes"], "AI recommendations must retain known verdicts.")
			_check(packet.violations == Policy.evaluate(packet.files, day), "Every audit answer must be computed from visible file content.")
			if packet.violations.is_empty(): clean += 1
			if packet.files.size() > 1: multiple_files += 1
			if packet.violations.size() > 1: multiple_rules += 1
			for violation: String in packet.violations:
				_check(violation in active_rules, "No request may require a rule introduced in the future.")
				if violation not in covered: covered.append(violation)
			for file: Dictionary in packet.files:
				_check(file.keyword_ink in ["blue", "pink"] and not file.source.is_empty(), "Editor source and keyword color must be explicit for every file.")
				var rows: Array = Policy.line_diff(file.base, file.source)
				var shown: Array = rows.filter(func(row: Dictionary) -> bool: return row.kind != "-").map(func(row: Dictionary) -> String: return row.text)
				_check("\n".join(shown) == file.source and file.diff.ends_with("\n".join(rows.map(func(row: Dictionary) -> String: return row.kind + row.text))), "Diffs must reproduce the proposed source exactly.")
				_check(file.status in ["added", "modified", "renamed"] and (file.status == "added") == file.base.is_empty(), "Every file is added, modified, or renamed.")
				if file.status != "added":
					modified_files += 1
					var main_copy := {"path": file.get("old_path", file.path), "source": file.base, "keyword_ink": "blue"}
					_check(Policy.evaluate([main_copy], day).is_empty(), "Code already on main must meet every standard; violations come from the change.")
				_check(file.source.split("\n", true).size() >= 5, "Changed files must provide a compact but inspectable source puzzle.")
			var evidence: Array = Policy.findings(packet.files, day)
			for finding: Dictionary in evidence:
				var matches: Array = packet.files.filter(func(file: Dictionary) -> bool: return file.path == finding.path)
				_check(matches.size() == 1 and finding.line >= 0 and finding.line <= matches[0].source.split("\n", true).size(), "Audit locations must reference actual files and source lines.")
		_check(clean == 5, "Each shift must retain a third genuinely compliant packets.")
		_check(modified_files >= 6, "Most shifts change existing code instead of only adding files.")
		for rule_id: String in active_rules:
			_check(rule_id in covered, "Every active standard must appear in that day's varied puzzles.")
		_check(multiple_files == 1 if day == 1 else multiple_files > 1, "Multiple-file review should expand after the tutorial day.")
		if day >= 2:
			_check(multiple_rules > 0, "Later shifts must include combined violations.")
	for packet: Dictionary in packets:
		var later: Array = Policy.evaluate(packet.files, 5)
		for file: Dictionary in packet.files:
			_check(packet.day >= 3 or Policy.PIGEON_STAMP not in file.source, "The PIGEON sign-off must not appear before its standard exists.")
		for rule_id: String in later:
			var introduced: int = int(Policy.rules().filter(func(rule: Dictionary) -> bool: return rule.id == rule_id)[0].introduced_day)
			_check(introduced <= packet.day or rule_id == "P06", "Packets must not foreshadow future standards with %s." % rule_id)
	var first: Dictionary = packets[0]
	_check(first.id == "PR-1042" and first.files.size() == 2 and first.violations == ["P01"], "Tutorial packet must retain its ID, two-file inspection, and only P01.")
	_check("load-bearing" in first.files[1].source, "The tutorial must show the literal forbidden comment phrase.")

func _test_boundaries() -> void:
	_check(_has("P01", "# LOAD-BEARING plant"), "P01 must ignore case inside comments.")
	_check(not _has("P01", "name = 'load-bearing'\n# a Load bearing plant"), "P01 must ignore strings and require the exact hyphenated phrase.")
	_check(_has("P01", "name = '# fine' # load-bearing note"), "P01 must find a real comment after a quoted hash.")
	_check(not _has("P01", "name = '# load-bearing'"), "A hash inside quotes must not open a comment.")
	var lines: Array[String] = []
	for _index in range(19): lines.append("# OFFICE")
	_check(not _has("P02", "\n".join(lines) + "\na"), "A lowercase a on source line twenty must satisfy P02.")
	_check(_has("P02", "\n".join(lines) + "\n# OFFICE\na"), "A lowercase a first appearing on line twenty-one must not satisfy P02.")
	_check(_has("P02", "A\n# OFFICE", 1), "Uppercase A must not count as lowercase a.")
	_check(not _has("P02", "# a", 1), "Comments count toward the lowercase-a requirement.")
	_check(not _has("P02", "label = 'a'", 1), "Quoted source also counts toward P02.")
	_check(_has("P02", "# NONE", 1, "blue", "a_in_filename.py"), "Filename letters must not count as source.")
	_check(not _has("P02", "# NONE", 1, "blue", "note.txt"), "P02 applies only to .py files.")
	_check(_has("P03", "def a():\n    return 0", 1, "pink"), "Pink executable keyword tokens must violate P03.")
	_check(not _has("P03", "# def if else return\nname = 'def if else return'", 1, "pink"), "Keywords in comments or strings must not require blue.")
	_check(not _has("P03", "return_label = 'a'\ndefault = 'if'", 1, "pink"), "Longer identifier names must not count as keyword tokens.")
	_check(not _has("P04", "a", 2, "blue", "LOUD_FOLDER/note.py") and _has("P04", "a", 2, "blue", "office/Note.py"), "P04 checks the basename only.")
	_check(not _has("P05", "a".repeat(60), 2) and _has("P05", "a".repeat(61), 2), "P05 must distinguish exactly sixty from sixty-one source characters.")
	_check(not _has("P06", "a\n  # approved by a pigeon  \n\n", 3), "Trailing blanks and outer stamp whitespace must remain compliant.")
	_check(_has("P06", "a\n# Approved by a pigeon", 3), "The pigeon stamp must be case-sensitive.")
	_check(_has("P06", "# approved by a pigeon\n# another note", 3), "A stamp above the final nonempty line must not count.")
	_check(not _has("P07", "name = 'a!'\n# approved by a pigeon") and _has("P07", "# a!"), "P07 bans exclamation marks only in comments.")
	_check(_has("P08", "name = 'a\tvalue'"), "A literal tab inside a string is still a P08 violation.")
	_check(not _has("P08", "name = 'a\\tvalue'"), "A displayed backslash-t sequence is not a literal tab.")
	_check(_has("P09", "name = 'An URGENT note'"), "P09 must recognize the quoted whole word ignoring case.")
	_check(not _has("P09", "name = 'urgently nonurgent urgent_task'\n# urgent"), "P09 must exempt comments and longer joined words.")
	_check(not _has("P09", "name = 'urgent'", 2), "Future rules must not apply early.")
	_check(Policy.evaluate([_file("# a load-bearing note"), _file("# a LOAD-BEARING note", "blue", "other.py")], 1) == ["P01"], "Multiple files breaking one rule must require only one citation.")

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

## Revisions regenerate from the parent's recipe: cited real faults go, uncited ones
## stay, about a third of fixes break one new standard, and the text never leaks.
func _test_revisions() -> void:
	var leaks := RegEx.new()
	leaks.compile("\\bP0[1-9]\\b|violat|audit|%")
	var revisions := 0
	var regressions := 0
	var notes_placed := 0
	for parent: Dictionary in Policy.requests():
		var real: Array = parent.violations
		var spurious: Array = []
		for rule: Dictionary in Policy.rules():
			if int(rule.introduced_day) <= int(parent.day) and rule.id not in real: spurious.append(rule.id)
		var trials: Array = [real.duplicate(), spurious.slice(0, 1)]
		for rule_id: String in real: trials.append([rule_id] + spurious.slice(0, 1))
		for cited: Array in trials:
			if cited.is_empty(): continue
			var fixed: Array = cited.filter(func(rule_id: String) -> bool: return rule_id in real)
			var id: String = Policy.revision_id(parent, 2)
			var regression: String = Policy.regression_rule(parent, id, fixed, cited)
			var revision: Dictionary = Policy.revision(parent, 2, fixed, regression, cited)
			revisions += 1
			var expected: Array = real.filter(func(rule_id: String) -> bool: return rule_id not in fixed)
			if not regression.is_empty():
				regressions += 1
				expected.append(regression)
				_check(regression not in real and regression not in cited and regression not in Policy.REGRESSION_EXEMPT, "A regression breaks a standard that was neither broken nor cited.")
				_check(int(Policy.rules().filter(func(rule: Dictionary) -> bool: return rule.id == regression)[0].introduced_day) <= int(parent.day), "Regressions only use standards active that day.")
			expected.sort()
			_check(revision.violations == expected, "%s fixes exactly the cited real violations (%s), keeps the rest, plus any regression." % [id, ",".join(cited)])
			_check(revision.violations == Policy.evaluate(revision.files, int(parent.day)) and revision.findings == Policy.findings(revision.files, int(parent.day)), "Revision audits come from its visible files.")
			_check(fixed.is_empty() == regression.is_empty() or not fixed.is_empty(), "Nothing fixed means nothing newly broken.")
			for key: String in ["id", "title", "author", "day", "file", "files", "diff", "message", "description", "violations", "findings", "explanation", "ai_verdict", "ai_note", "revision", "parent_id", "origin_id", "recipe"]:
				_check(revision.has(key), "Revision packets keep the packet shape: " + key)
			_check(revision.id == parent.id + "-v2" and revision.revision == 2 and revision.parent_id == parent.id and revision.title == parent.title and revision.author == parent.author, "A revision keeps its parent's identity with a version suffix.")
			for file: Dictionary in revision.files:
				var rows: Array = Policy.line_diff(file.base, file.source)
				_check("\n".join(rows.filter(func(row: Dictionary) -> bool: return row.kind != "-").map(func(row: Dictionary) -> String: return row.text)) == file.source, "Revision diffs reproduce the proposed source.")
			if revision.recipe.notes.size() == 1:
				notes_placed += 1
				var note: String = revision.recipe.notes[0].text
				_check(not note.contains("a") and not note.contains("!") and note.length() <= 60 and note.begins_with("#"), "Author notes can never satisfy or break a standard by themselves.")
			for text: String in [revision.message, revision.description]:
				_check(leaks.search(text) == null and not text.contains("["), "Revision text never names a rule, or says whether anything is still broken: " + text)
			# The same citations read the same whatever the audit found.
			var counterfactual: Dictionary = Policy.revision(parent, 2, [], "", cited)
			_check(counterfactual.message == revision.message and counterfactual.description.replace(Policy._summary(counterfactual.files), "") == revision.description.replace(Policy._summary(revision.files), ""), "Revision prose depends only on what was cited.")
			var again: Dictionary = Policy.revision(parent, 2, fixed, Policy.regression_rule(parent, id, fixed, cited), cited)
			_check(again == revision, "Revisions are deterministic.")
		var v3: Dictionary = Policy.revision(Policy.revision(parent, 2, [], "", real), 3, real, "", real)
		_check(v3.id == parent.id + "-v3" and v3.parent_id == parent.id + "-v2" and v3.origin_id == parent.id and v3.violations.is_empty() == true, "A v3 builds on v2's recipe under the original ID.")
	_check(regressions * 5 >= revisions and regressions * 2 <= revisions, "About one revision in three that fixes something breaks something else (%d of %d)." % [regressions, revisions])
	_check(notes_placed * 10 >= revisions * 9, "Nearly every revision carries the author's note.")

func _test_permits() -> void:
	var pink: Dictionary = _file("# a
def memo():
    return 'a copy'
# approved by a pigeon", "pink")
	pink.permit = "INK-EXCEPTION"
	_check("P03" in Policy.evaluate([pink], 3), "Ink permits must not apply before Thursday.")
	_check(Policy.evaluate([pink], 4).is_empty(), "The exact stamp must waive only that file's pink keyword requirement from Thursday.")
	for incorrect: String in ["INK-EXEPTION", "ink-exception", " INK-EXCEPTION", "INK-EXCEPTION ", "INK EXCEPTION", ""]:
		var unstamped: Dictionary = pink.duplicate(true)
		unstamped.permit = incorrect
		_check("P03" in Policy.evaluate([unstamped], 4), "Misspelled, differently cased, or padded permits must not count.")
	var neighbor: Dictionary = pink.duplicate(true)
	neighbor.path = "office/neighbor.py"
	neighbor.erase("permit")
	_check(Policy.evaluate([pink, neighbor], 4) == ["P03"], "A valid permit on one file must never cover a neighboring file.")
	pink.source = "# a load-bearing form!\ndef memo():\n    return 'urgent'\n# approved by a pigeon"
	_check(Policy.evaluate([pink], 5) == ["P01", "P07", "P09"], "A valid ink permit must not waive unrelated comment or quoted-word rules.")
	for day: int in [4, 5]:
		var valid_clean: bool = false
		var invalid_stamp: bool = false
		var unrelated_fault: bool = false
		for packet: Dictionary in Policy.requests():
			if packet.day != day: continue
			for file: Dictionary in packet.files:
				if file.get("permit") == "INK-EXCEPTION" and file.keyword_ink == "pink":
					valid_clean = valid_clean or packet.violations.is_empty()
					unrelated_fault = unrelated_fault or (not packet.violations.is_empty() and "P03" not in packet.violations)
				if file.get("permit") == "INK-EXEPTION" and "P03" in packet.violations:
					invalid_stamp = true
		_check(valid_clean and invalid_stamp and unrelated_fault, "Late shifts need clean exceptions, bogus permits, and separately broken rules.")
