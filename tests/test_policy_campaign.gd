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
			_check(packet.arrival_seconds == index * 20 and packet.arrival_seconds < 300, "Requests must arrive every twenty seconds before the five-minute deadline.")
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
				_check(file.diff == "@@ office policy update\n+" + file.source.replace("\n", "\n+"), "Compatibility diffs must exactly match the visible source.")
				_check(file.source.split("\n", true).size() >= 5, "Changed files must provide a compact but inspectable source puzzle.")
			var evidence: Array = Policy.findings(packet.files, day)
			for finding: Dictionary in evidence:
				var matches: Array = packet.files.filter(func(file: Dictionary) -> bool: return file.path == finding.path)
				_check(matches.size() == 1 and finding.line >= 0 and finding.line <= matches[0].source.split("\n", true).size(), "Audit locations must reference actual files and source lines.")
		_check(clean == 5, "Each shift must retain a third genuinely compliant packets.")
		for rule_id: String in active_rules:
			_check(rule_id in covered, "Every active standard must appear in that day's varied puzzles.")
		_check(multiple_files == 1 if day == 1 else multiple_files > 1, "Multiple-file review should expand after the tutorial day.")
		if day >= 2:
			_check(multiple_rules > 0, "Later shifts must include combined violations.")
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
