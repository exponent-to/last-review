extends RefCounted
## Fictional office policy puzzles. Every citation comes from visible source evidence.
## Source is Python-shaped stationery, not code the game executes.

const KEYWORDS: Array = ["def", "if", "else", "return"]
const AUTHORS: Array = ["Maya", "Theo", "Inez"]
const DAY_COUNTS: Array = [15, 15, 15, 15, 15]
const ACTIVE_COUNTS: Array = [3, 5, 7, 8, 9]
const PIGEON_STAMP: String = "# approved by a pigeon"
## Rules about a whole file (its name, ink, opening lines, or quoted labels) accept
## the file or any of its lines as evidence. Every other rule needs the exact line.
const FILE_SCOPED: Array = ["P02", "P03", "P04", "P09"]
const Bank = preload("res://content/pr_bank.gd")
static var _packets: Array = []

static func rules() -> Array:
	return [
		{"id": "P01", "category": "Language", "title": "Nothing is load-bearing", "text": "Legal's position is that no component, and no employee, is load-bearing. A comment must not contain the exact phrase load-bearing, ignoring letter case. Match the hyphen and spacing exactly; the phrase anywhere after an unquoted # counts. Text inside a quoted string is not a comment.", "introduced_day": 1},
		{"id": "P02", "category": "Letters", "title": "Scanner calibration", "text": "The Helios intake scanner calibrates on the lowercase letter a. Files it cannot calibrate are quarantined, and so is their reviewer. Every file ending in .py must contain the literal lowercase letter a somewhere in its first 20 source lines. Comments and quoted text count. Uppercase A does not count. Blank lines count toward the line limit; the filename does not count.", "introduced_day": 1},
		{"id": "P03", "category": "Color", "title": "Approved ink", "text": "Blue is the approved color of compliant instructions. Pink is reserved for flagged personnel files. The whole keyword tokens def, if, else, and return must be blue. Pink is forbidden. Words inside comments or quoted strings are exempt, as are longer names such as return_label. A file without these keyword tokens needs no blue ink. From Thursday onward, the exact per-file stamp INK-EXCEPTION permits pink keywords in that file only. Misspelled stamps do not count, and no other rule is waived.", "introduced_day": 1},
		{"id": "P04", "category": "Filenames", "title": "Quiet filenames", "text": "Capital letters register as shouting in the audit log. The filename, excluding its folders, must not contain uppercase ASCII letters A through Z. Lowercase letters, digits, and punctuation are fine.", "introduced_day": 2},
		{"id": "P05", "category": "Layout", "title": "On the record", "text": "Audit printouts are sixty columns wide. Anything past the margin is off the record, and off-record work is not permitted. No source line may exceed 60 characters, including spaces and punctuation. Exactly 60 is fine. Count the source only, not editor line numbers; a tab counts as one character for this rule.", "introduced_day": 2},
		{"id": "P06", "category": "Sign-off", "title": "PIGEON sign-off", "text": "Every file is carried to Legal by PIGEON, the compliance courier. Files without its sign-off are not delivered. The final nonempty line of every file must be exactly # approved by a pigeon after ignoring leading and trailing spaces. Blank lines after the stamp are fine. Letter case and spelling must match.", "introduced_day": 3},
		{"id": "P07", "category": "Language", "title": "Sentiment control", "text": "Comments are scanned for sentiment, and enthusiasm is a sentiment. Comment text must not contain an exclamation mark (!). Exclamation marks inside quoted strings are allowed. Only text after an unquoted # is a comment.", "introduced_day": 3},
		{"id": "P08", "category": "Layout", "title": "Nothing hidden", "text": "Tabs hide whitespace from the line scanners, and anything hidden is presumed hostile. No literal tab characters may appear anywhere in source, including comments and strings. Use spaces. The two visible characters backslash and t are not a literal tab.", "introduced_day": 4},
		{"id": "P09", "category": "Labels", "title": "Urgency belongs to management", "text": "Only management may declare urgency. Quoted string text must not contain the whole word urgent, ignoring letter case. urgent and URGENT are forbidden; urgently and nonurgent are fine. A letter, digit, or underscore joins a word, so urgent_task is also fine. Comments are exempt.", "introduced_day": 5},
	]

static func briefing(day: int) -> String:
	match day:
		1:
			return "YOUR DESK IS ASSIGNED. Northstar is transitioning review to Helios. Until it completes, every change still needs a human signature. You will not be asked to understand the code, only to enforce the standards on it exactly as written: forbidden comment wording, the scanner's lowercase a, and approved keyword ink. Work arrives through Slouch. The clock does not wait for you."
		2:
			return "THE RECORDS OFFICE HAS REQUIREMENTS. Filenames must be quiet and lines must fit the audit printout. Earlier standards still apply. Changes now arrive in several files; an unread file is an unsigned file. Cite each broken standard once."
		3:
			return "PIGEON IS NOW CARRYING EVERY FILE. Each one must end with the courier's exact sign-off, and comments are scanned for exclamation marks. Helios is available on the review desk. It is fast and confident. It is not always right, and every consultation is logged."
		4:
			return "THE EXCEPTION DESK IS OPEN. Literal tabs are banned. Only the exact per-file stamp INK-EXCEPTION permits pink keywords, and only in that file; it waives nothing else. A misspelled permit is a forged permit."
		5:
			return "FINAL REVIEW CYCLE. Only management may declare urgency: the whole word urgent is forbidden inside quoted strings. Every earlier standard and permit still applies. Helios has drafted the closing report. Your signatures decide what it can claim."
	return "The standards committee has adjourned."

## Lexical columns match Godot's source editor: zero-based lines and character
## columns, exclusive end. Comments/strings retain spaces in the code mask.
static func _lex(source: String) -> Dictionary:
	var code_lines: Array = []
	var comments: Array = []
	var strings: Array = []
	var quote: String = ""
	var triple: bool = false
	var string_text: String = ""
	var lines: PackedStringArray = source.split("\n", true)
	for line_index in range(lines.size()):
		var line: String = lines[line_index]
		var mask: String = ""
		var column: int = 0
		while column < line.length():
			var character: String = line.substr(column, 1)
			if not quote.is_empty():
				var delimiter: String = quote.repeat(3) if triple else quote
				if line.substr(column, delimiter.length()) == delimiter:
					mask += " ".repeat(delimiter.length())
					column += delimiter.length()
					strings.append(string_text)
					string_text = ""
					quote = ""
					triple = false
				elif character == "\\" and column + 1 < line.length():
					string_text += line.substr(column, 2)
					mask += "  "
					column += 2
				else:
					string_text += character
					mask += " "
					column += 1
			elif character == "#":
				comments.append({"line": line_index, "text": line.substr(column + 1)})
				mask += " ".repeat(line.length() - column)
				column = line.length()
			elif character == "\"" or character == "'":
				quote = character
				triple = line.substr(column, 3) == character.repeat(3)
				var width: int = 3 if triple else 1
				mask += " ".repeat(width)
				column += width
			else:
				mask += character
				column += 1
		code_lines.append(mask)
		if not quote.is_empty():
			string_text += "\n"
	if not string_text.is_empty():
		strings.append(string_text)
	return {"code_lines": code_lines, "comments": comments, "strings": strings}

static func keyword_spans(source: String) -> Array:
	var spans: Array = []
	var lexer: Dictionary = _lex(source)
	var matcher: RegEx = RegEx.new()
	matcher.compile("(?<![A-Za-z0-9_])(def|if|else|return)(?![A-Za-z0-9_])")
	for line_index in range(lexer.code_lines.size()):
		for found: RegExMatch in matcher.search_all(lexer.code_lines[line_index]):
			spans.append({"line": line_index, "start": found.get_start(), "end": found.get_end(), "token": found.get_string()})
	return spans

static func _finding(findings: Array, id: String, path: String, line: int, detail: String) -> void:
	findings.append({"rule_id": id, "path": path, "line": line, "message": detail})

## Audit data only; all line references are one-based source lines.
static func findings(files: Array, day: int) -> Array:
	var result: Array = []
	var uppercase: RegEx = RegEx.new()
	uppercase.compile("[A-Z]")
	var urgent: RegEx = RegEx.new()
	urgent.compile("(?i)(?<![A-Za-z0-9_])urgent(?![A-Za-z0-9_])")
	for file: Dictionary in files:
		var path: String = file.path
		var source: String = file.source
		var lines: PackedStringArray = source.split("\n", true)
		var lexer: Dictionary = _lex(source)
		for comment: Dictionary in lexer.comments:
			if "load-bearing" in str(comment.text).to_lower():
				_finding(result, "P01", path, int(comment.line) + 1, "The comment contains load-bearing.")
			if day >= 3 and "!" in comment.text:
				_finding(result, "P07", path, int(comment.line) + 1, "The comment contains an exclamation mark.")
		if path.ends_with(".py"):
			var has_a: bool = false
			for line_index in range(mini(20, lines.size())):
				has_a = has_a or "a" in lines[line_index]
			if not has_a:
				_finding(result, "P02", path, 1, "The first twenty source lines contain no lowercase a.")
		if file.get("keyword_ink", "blue") != "blue" and not (day >= 4 and file.get("permit", "") == "INK-EXCEPTION"):
			var spans: Array = keyword_spans(source)
			if not spans.is_empty():
				_finding(result, "P03", path, int(spans[0].line) + 1, "A listed keyword token is pink instead of blue.")
		if day >= 2:
			if uppercase.search(path.get_file()) != null:
				_finding(result, "P04", path, 0, "The filename contains an uppercase letter.")
			for line_index in range(lines.size()):
				if lines[line_index].length() > 60:
					_finding(result, "P05", path, line_index + 1, "This source line exceeds sixty characters.")
		if day >= 3:
			var last_line: int = lines.size() - 1
			while last_line >= 0 and lines[last_line].strip_edges().is_empty():
				last_line -= 1
			if last_line < 0 or lines[last_line].strip_edges() != PIGEON_STAMP:
				_finding(result, "P06", path, maxi(1, last_line + 1), "The final nonempty line is not the pigeon stamp.")
		if day >= 4:
			for line_index in range(lines.size()):
				if "\t" in lines[line_index]:
					_finding(result, "P08", path, line_index + 1, "This line contains a literal tab.")
		if day >= 5:
			for quoted: String in lexer.strings:
				if urgent.search(quoted) != null:
					_finding(result, "P09", path, 0, "A quoted string contains the whole word urgent.")
	return result

## True when a citation's pointed-at location is real evidence for that rule.
## line 0 means the whole file (or its filename).
static func evidence_accepted(audit: Array, rule_id: String, path: String, line: int) -> bool:
	for finding: Dictionary in audit:
		if finding.rule_id != rule_id or finding.path != path: continue
		if rule_id in FILE_SCOPED or int(finding.line) == line: return true
	return false

static func evaluate(files: Array, day: int) -> Array:
	var ids: Array = []
	for finding: Dictionary in findings(files, day):
		if finding.rule_id not in ids:
			ids.append(finding.rule_id)
	ids.sort()
	return ids

static func _explanation(files: Array, day: int) -> String:
	var evidence: Array = findings(files, day)
	if evidence.is_empty():
		return "Every changed file meets today's active policies. Strange office paperwork is allowed when it follows the handbook."
	var pieces: Array[String] = []
	var seen: Array = []
	for finding: Dictionary in evidence:
		if finding.rule_id in seen:
			continue
		seen.append(finding.rule_id)
		var location: String = str(finding.path).get_file()
		if int(finding.line) > 0:
			location += ":%d" % finding.line
		pieces.append("%s (%s): %s" % [finding.rule_id, location, finding.message])
	return " ".join(pieces)

static func _file(path: String, lines: Array, ink: String = "blue") -> Dictionary:
	var source: String = "\n".join(lines)
	var diff: String = "@@ office policy update\n+" + source.replace("\n", "\n+")
	return {"path": path, "source": source, "diff": diff, "keyword_ink": ink}

static func _module(path: String) -> Dictionary:
	var package: String = path.get_base_dir().replace("/", ".")
	var module: String = path.get_file().get_basename()
	return {"package": package, "module": module, "import": package + "." + module}

static func _entry_function(lines: Array) -> String:
	for line: String in lines:
		if line.begins_with("def "):
			return line.substr(4, line.find("(") - 4)
	return "main"

## Companion files make packets look like real changes: tests, config, shims.
static func _companion(kind: String, entry: Dictionary) -> Array:
	var where := _module(str(entry.path))
	var function := _entry_function(entry.lines)
	match kind:
		"test":
			return ['"""Regression tests, as requested by the audit."""', "from %s import %s" % [where.import, function], "", "def test_%s_is_callable():" % function.left(36), "    assert callable(%s)" % function, "    return None"]
		"config":
			return ["# configuration for the %s change" % where.module, "ENABLED = True", "OWNER = 'platform'", "", "def enabled():", "    return ENABLED"]
		_:
			return ["# legacy shim, kept for the audit trail", "from %s import %s" % [where.import, function], "", "def legacy_call(*args):", "    return %s(*args)" % function]

static func _companion_path(kind: String, path: String) -> String:
	var where := _module(path)
	match kind:
		"test": return "tests/test_%s.py" % where.module
		"config": return path.get_base_dir() + "/%s_config.py" % where.module
		_: return path.get_base_dir() + "/%s_legacy.py" % where.module

## Clean source for a shift. The PIGEON sign-off exists only once its standard does.
static func _clean(lines: Array, day: int) -> Array:
	var result: Array = lines.duplicate()
	if day >= 3:
		result.append(PIGEON_STAMP)
	return result

static func _apply_fault(file: Dictionary, rule_id: String, day: int) -> void:
	var lines: Array = Array(str(file.source).split("\n", true))
	var variant: int = str(file.path).length()
	var at: int = mini(1, lines.size())
	match rule_id:
		"P01":
			lines.insert(at, ["# load-bearing: do not touch, ask Dave", "# this sleep is load-bearing, nobody knows why", "# load-bearing workaround from the 2019 outage"][variant % 3])
		"P02":
			# A generated settings module: no lowercase a anywhere in its first twenty lines.
			var name: String = str(file.path).get_file().get_basename().to_upper()
			lines = ["# %s SETTINGS" % name, "# GENERATED BY HELIOS. DO NOT EDIT.", "RETRY_LIMIT = 3", "TIMEOUT_SECONDS = 30", "OWNER_ID = 7", "", "def limits():", "    return (RETRY_LIMIT, TIMEOUT_SECONDS)", ""]
			for setting: String in ["MIN_WORKERS = 2", "MOOD_THRESHOLD = 40", "LOG_LEVEL = 'INFO'", "POLL_SECONDS = 15", "BUFFER_SIZE = 4096", "MONITOR_ID = 'NS-7'", "REVIEW_QUOTE = 1", "OPEN_DOOR_POLICY = 0", "HELIOS_WEIGHT = 9", "UPTIME_GOAL = 99", "SILENCE_ON_ERROR = 1"]:
				if lines.size() < 20: lines.append(setting)
			if day >= 3: lines.append(PIGEON_STAMP)
		"P03":
			file.keyword_ink = "pink"
			if keyword_spans("\n".join(lines)).is_empty():
				lines.insert(at, "def stamp():")
				lines.insert(at + 1, "    return 'a copy'")
		"P04":
			var base: String = str(file.path).get_file().get_basename()
			var loud: String = base.capitalize().replace(" ", "")
			file.path = str(file.path).get_base_dir() + "/" + loud + ".py"
		"P05":
			lines.insert(at, ["# NOTE: Helios says this is fine, and also that it wrote this one", "MOTD = 'please remember that every keystroke is company property'", "# reviewed in the meeting that could have been an email thread"][variant % 3])
		"P06":
			lines[-1] = ["# approved by a seagull", "# approved by helios", "# approved by a pigeon (probably)"][variant % 3]
		"P07":
			lines.insert(at, ["# TODO: delete before the audit!", "# works on my machine!", "# thanks Helios!"][variant % 3])
		"P08":
			lines.insert(at, ["RETRY_DELAY =\t5", "TEAM =\t'platform'", "MAX_SEATS =\t12"][variant % 3])
		"P09":
			lines.insert(at, ["PRIORITY = 'urgent'", "SUBJECT = 'URGENT: per Morgan'", "LABEL = 'Urgent review requested'"][variant % 3])
	file.source = "\n".join(lines)
	file.diff = "@@ office policy update\n+" + str(file.source).replace("\n", "\n+")

static func requests() -> Array:
	if not _packets.is_empty():
		return _packets.duplicate(true)
	var bank: Array = Bank.entries()
	for day in range(1, 6):
		for index in range(DAY_COUNTS[day - 1]):
			var entry: Dictionary = bank[((day - 1) * DAY_COUNTS[day - 1] + index) % bank.size()]
			var path: String = str(entry.path)
			var files: Array = [_file(path, _clean(entry.lines, day))]
			var is_clean: bool = index % 3 == 1
			if (day == 1 and index == 0) or (day >= 2 and index % 2 == 0):
				files.append(_file(_companion_path("test", path), _clean(_companion("test", entry), day)))
			if day >= 3 and index % 13 == 0:
				files.append(_file(_companion_path("legacy", path), _clean(_companion("legacy", entry), day)))
			if not is_clean:
				var primary: String = "P%02d" % (1 + ((index / 3 + (index % 3) * 2) % ACTIVE_COUNTS[day - 1]))
				if day == 1 and index == 0:
					primary = "P01"
				_apply_fault(files[-1], primary, day)
				if day >= 2 and index > 0 and index % 6 == 0:
					var secondary: String = "P%02d" % (1 + ((int(primary.substr(1)) + 2) % ACTIVE_COUNTS[day - 1]))
					if secondary == primary:
						secondary = "P01" if primary != "P01" else "P03"
					# Different files prevent edits to one flaw from concealing another.
					if files.size() == 1:
						files.append(_file(_companion_path("config", path), _clean(_companion("config", entry), day)))
					_apply_fault(files[0], secondary, day)
			if day >= 4:
				if index in [1, 4, 7]:
					_apply_fault(files[0], "P03", day)
					files[0].permit = "INK-EXCEPTION"
				elif index in [0, 8]:
					_apply_fault(files[-1], "P03", day)
					files[-1].permit = "INK-EXCEPTION"
				elif index == 2:
					_apply_fault(files[0], "P03", day)
					files[0].permit = "INK-EXCEPTION"
					_apply_fault(files[-1], "P03", day)
					files[-1].permit = "INK-EXEPTION"
				elif index == 5:
					_apply_fault(files[-1], "P03", day)
					files[-1].permit = "ink-exception"
			var violations: Array = evaluate(files, day)
			var correct_verdict: String = "approve" if violations.is_empty() else "request_changes"
			var verdict: String = correct_verdict
			if index % 5 == 0:
				verdict = "request_changes" if correct_verdict == "approve" else "approve"
			var combined: Array[String] = []
			for file: Dictionary in files:
				combined.append("--- a/%s\n+++ b/%s\n%s" % [file.path, file.path, file.diff])
			var request_id: String = "PR-%d" % (1000 + day * 1000 + index + 1)
			if day == 1 and index == 0:
				request_id = "PR-1042"
			_packets.append({
				"id": request_id, "title": str(entry.title), "author": AUTHORS[(index + day - 1) % AUTHORS.size()], "day": day,
				"arrival_seconds": index * 20,
				"file": files[0].path, "files": files, "diff": "\n\n".join(combined),
				"description": "%s.\n\nChanges %s. Reviewer: the displayed source is the complete change. Check every attached file against today's active standards; you do not need to understand what the code does." % [str(entry.title), ", ".join(files.map(func(file: Dictionary) -> String: return str(file.path)))],
				"message": _ping(index, str(entry.phrase)),
				"violations": violations, "findings": findings(files, day), "explanation": _explanation(files, day),
				"ai_verdict": verdict, "ai_note": _ai_note(index, verdict),
			})
	return _packets.duplicate(true)

static func _ping(index: int, object_name: String) -> String:
	var openings: Array = ["Quick eyes on %s? Helios already said it looks great, which is why I'm asking you.", "Can you review %s before standup? Standup is in four minutes.", "%s is up. Morgan wants it merged before anyone reads it.", "Small one: %s. Please don't ask why.", "Sending %s. It passed CI, which is the least reassuring thing I can say.", "Could you look at %s? I've been told it's strategic.", "%s, as requested by a meeting I wasn't invited to.", "Please review %s. I would like to go back to my actual job."]
	var text: String = str(openings[index % openings.size()]) % object_name
	return text.left(1).to_upper() + text.substr(1)

static func _ai_note(index: int, verdict: String) -> String:
	if verdict == "approve":
		return ["LGTM. The code has the confidence of approved code.", "I recommend approval. The intent aligns with company values.", "No issues found. I also wrote a similar function once.", "Approve. Delaying this would reduce velocity."][index % 4]
	return ["I recommend another pass through the active standards.", "Some visible details may not survive an audit.", "I would request changes, subject to your own check.", "My compliance model is uneasy about this diff."][index % 4]
