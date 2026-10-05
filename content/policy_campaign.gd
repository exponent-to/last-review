extends RefCounted
## Fictional office policy puzzles. Every citation comes from visible source evidence.
## Source is Python-shaped stationery, not code the game executes.
##
## The assignment runs two weeks, Monday to Friday. Standards change every second
## morning, at the start of each two-day block: some are added, some are amended,
## and some are retired. A rule is active from `introduced_day` until the day before
## its `retired_day`; each amendment replaces the rule's text from its own day on.

const KEYWORDS: Array = ["def", "if", "else", "return"]
const AUTHORS: Array = ["Maya", "Theo", "Inez"]
const DAY_COUNTS: Array = [15, 15, 15, 15, 15, 15, 15, 15, 15, 15]
const WEEK_DAYS: int = 5
## The first day of each two-day block. Each opens with a memo announcing the changes.
const BLOCK_STARTS: Array = [1, 3, 5, 7, 9]
## Standards on the citation slip each day; never more than eight at once.
## Standards on the citation slip each day. P15 "Readable code" joins on day 3,
## so week two carries nine; the generic 150 still only break the other eight.
const ACTIVE_COUNTS: Array = [3, 3, 7, 7, 9, 9, 9, 9, 9, 9]
const PIGEON_STAMP: String = "# approved by a pigeon"
const DISCLOSURE: String = "# generated-by: helios"
const PERMIT: String = "INK-EXCEPTION"
## INK-EXCEPTION is honored from PERMIT_DAY, and must carry a ticket from TICKET_DAY.
const PERMIT_DAY: int = 5
const TICKET_DAY: int = 9
## The audit printout widens from sixty to seventy-two columns.
const WIDE_DAY: int = 7
## Whole-PR limits, read off the diffstat: lines added plus removed, and files changed.
const DIFF_BUDGET: int = 30
const FILE_CAP: int = 3
## Evidence scopes. Line rules need the exact line. Rules about one file (its name,
## ink, quoted labels, or disclosure) accept that file or any of its lines. Rules
## about the whole PR (its size, file count, or tests) accept any changed file,
## whole or by line, because the evidence is the file list and the diffstat.
const FILE_SCOPED: Array = ["P02", "P03", "P08", "P14"]
const PR_SCOPED: Array = ["P09", "P10", "P13"]
const SECRET_WORDS: Array = ["password", "secret", "token", "api_key"]
const Bank = preload("res://content/pr_bank.gd")
static var _packets: Array = []
static var _bank: Array = []
static var _active: Dictionary = {}
static var _patterns: Dictionary = {}

static func rules() -> Array:
	var ink := "Blue is the approved color of compliant instructions. Pink is reserved for flagged personnel files. The whole keyword tokens def, if, else, and return must be blue. Pink is forbidden. Words inside comments or quoted strings are exempt, as are longer names such as return_label. A file without these keyword tokens needs no blue ink."
	return [
		{"id": "P01", "category": "Language", "title": "Nothing is load-bearing", "introduced_day": 1, "retired_day": 9,
			"text": "Legal's position is that no component, and no employee, is load-bearing. A comment must not contain the exact phrase load-bearing, ignoring letter case. Match the hyphen and spacing exactly; the phrase anywhere after an unquoted # counts. Text inside a quoted string is not a comment. Cite the line.",
			"retired": "Legal has confirmed that nothing here is load-bearing anymore, including the staff. Comments may say load-bearing again."},
		{"id": "P02", "category": "Color", "title": "Approved ink", "introduced_day": 1,
			"text": ink + " Cite the file.",
			"amendments": [
				{"day": PERMIT_DAY, "change": "The Exception Desk is open. A file whose permit reads exactly INK-EXCEPTION may use pink keywords.",
					"text": ink + " A file whose Permit reads exactly INK-EXCEPTION may use pink keywords; the permit covers that file only. Misspelled, padded, or differently cased stamps do not count, and no other rule is waived. Cite the file."},
				{"day": TICKET_DAY, "change": "Permits now need a ticket number: INK-EXCEPTION, one space, then PCL- and four digits. A bare INK-EXCEPTION is a forgery as of today.",
					"text": ink + " A file whose Permit reads exactly INK-EXCEPTION, one space, then a ticket of PCL- and four digits (for example INK-EXCEPTION PCL-0420) may use pink keywords; the permit covers that file only. A bare INK-EXCEPTION is no longer valid. Misspelled, padded, or differently cased stamps do not count, and no other rule is waived. Cite the file."}]},
		{"id": "P03", "category": "Filenames", "title": "Quiet filenames", "introduced_day": 1, "retired_day": 9,
			"text": "Capital letters register as shouting in the audit log. The filename, excluding its folders, must not contain uppercase ASCII letters A through Z. Lowercase letters, digits, and punctuation are fine. Cite the file.",
			"retired": "Helios has asked to be addressed in capitals. Filenames may shout again."},
		{"id": "P04", "category": "Layout", "title": "On the record", "introduced_day": 3,
			"text": "Audit printouts are sixty columns wide. Anything past the margin is off the record, and off-record work is not permitted. No source line may exceed 60 characters, including spaces and punctuation. Exactly 60 is fine. Count the source only, not editor line numbers; a tab counts as one character for this rule. Cite the line.",
			"amendments": [
				{"day": WIDE_DAY, "change": "Helios bought wider audit printers. Lines may now run to 72 characters.",
					"text": "Helios bought wider audit printers. Printouts are now seventy-two columns wide, and anything past the margin is still off the record. No source line may exceed 72 characters, including spaces and punctuation. Exactly 72 is fine, and so is every line of 61 to 72 characters that was flagged last week. Count the source only, not editor line numbers; a tab counts as one character for this rule. Cite the line."}]},
		{"id": "P05", "category": "Sign-off", "title": "PIGEON sign-off", "introduced_day": 3, "retired_day": 7,
			"text": "Every file is carried to Legal by PIGEON, the compliance courier. Files without its sign-off are not delivered. The final nonempty line of every file must be exactly # approved by a pigeon after ignoring leading and trailing spaces. Blank lines after the stamp are fine. Letter case and spelling must match. Cite the final line.",
			"retired": "Legal has rescinded the pigeon. Files no longer need its sign-off, and a stamp left behind is harmless. PIGEON has been reassigned to an undisclosed location."},
		{"id": "P06", "category": "Language", "title": "Sentiment control", "introduced_day": 3, "retired_day": 7,
			"text": "Comments are scanned for sentiment, and enthusiasm is a sentiment. Comment text must not contain an exclamation mark (!). Exclamation marks inside quoted strings are allowed. Only text after an unquoted # is a comment. Cite the line.",
			"retired": "Sentiment control is retired. Helios now supplies the company's enthusiasm, so comments may use exclamation marks."},
		{"id": "P07", "category": "Layout", "title": "Nothing hidden", "introduced_day": 5, "retired_day": 9,
			"text": "Tabs hide whitespace from the line scanners, and anything hidden is presumed hostile. No literal tab characters may appear anywhere in source, including comments and strings. Use spaces. The two visible characters backslash and t are not a literal tab. Cite the line.",
			"retired": "The line scanners were decommissioned, and Helios reads tabs natively. Tabs are allowed again."},
		{"id": "P08", "category": "Labels", "title": "Urgency belongs to management", "introduced_day": 5, "retired_day": 7,
			"text": "Only management may declare urgency. Quoted string text must not contain the whole word urgent, ignoring letter case. urgent and URGENT are forbidden; urgently and nonurgent are fine. A letter, digit, or underscore joins a word, so urgent_task is also fine. Comments are exempt. Cite the file.",
			"retired": "Urgency has been automated. Helios marks everything urgent, so the word no longer means anything, and quotes may contain it."},
		{"id": "P09", "category": "Size", "title": "Diff budget", "introduced_day": 7,
			"text": "Human attention is now a metered resource, and Helios has measured yours. A PR may change at most 30 lines in total: lines added plus lines removed, across every file, as the diffstat above the diff counts them. Exactly 30 is fine. A rename by itself changes no lines. This standard is about the whole PR: cite WHOLE FILE on any changed file."},
		{"id": "P10", "category": "Size", "title": "File cap", "introduced_day": 7,
			"text": "According to a study Helios ran on reviewers, reviewers lose track after three files. A PR may change at most three files: count every entry in the file list, whether added, modified, or renamed. Exactly three is fine. This standard is about the whole PR: cite WHOLE FILE on any changed file."},
		{"id": "P11", "category": "Security", "title": "Credentials belong to Helios", "introduced_day": 7,
			"text": "Only Helios may hold credentials. No source line may use = to assign a quoted string to a name containing password, secret, token, or api_key, ignoring letter case: API_KEY = 'sk-1' and db_password = '' are forbidden. Reading from the vault, as in TOKEN = vault.read('token'), is fine, and so are numbers, as in TOKEN_TTL = 3600. Comments are exempt. Cite the line."},
		{"id": "P12", "category": "Hygiene", "title": "No debug output", "introduced_day": 9,
			"text": "Helios reads every log, and debug output distresses it. Outside the tests/ folder, code must not call print: the whole word print followed by an opening parenthesis, outside comments and quoted strings. A commented-out # print( is fine, and files under tests/ may print. Cite the line."},
		{"id": "P13", "category": "Process", "title": "Tests travel with code", "introduced_day": 9,
			"text": "Helios cannot tell whether a change to existing code still works, so a human must leave a test behind. A PR that modifies or renames any file outside tests/ (M or R in the file list) must also add or modify a file under tests/. A PR that only adds new files needs no test; new code is presumed innocent. This standard is about the whole PR: cite WHOLE FILE on any changed file."},
		{"id": "P14", "category": "Disclosure", "title": "Machine disclosure", "introduced_day": 9,
			"text": "Helios is credited on everything it touches. If any comment in a file mentions Helios (the whole word, in any letter case), that file must also contain the exact line # generated-by: helios, ignoring leading and trailing spaces. Other spellings and letter cases do not count. A file whose comments never mention Helios needs no disclosure, whatever you suspect. Cite the file."},
		{"id": "P15", "category": "Readability", "title": "Readable code", "introduced_day": 3,
			"text": "Code a human signs must stay readable by a human. No source line may call exec or eval, invoke helios.bootstrap, helios.install, or helios.activate, or pack a whole change onto one unreadable line of more than 160 characters. A decoded blob, a fetched script, or a vendored one-liner hides what actually ships, so a reviewer cannot sign it. This is the one standard a payload cannot slip past. Cite the line."},
	]

static func is_active(rule: Dictionary, day: int) -> bool:
	var retired: int = int(rule.get("retired_day", 0))
	return int(rule.introduced_day) <= day and (retired <= 0 or day < retired)

## IDs of the standards on the slip that day, in rulebook order.
static func active_ids(day: int) -> Array:
	if not _active.has(day):
		var ids: Array = []
		for rule: Dictionary in rules():
			if is_active(rule, day): ids.append(rule.id)
		_active[day] = ids
	return _active[day]

static func _on(rule_id: String, day: int) -> bool:
	return rule_id in active_ids(day)

## A rule as it reads on `day`: its latest amendment's text, plus `amended_day`
## (0 if never amended by then) and that amendment's one-line `change`.
static func as_of(rule: Dictionary, day: int) -> Dictionary:
	var current: Dictionary = rule.duplicate(true)
	current.amended_day = 0
	for amendment: Dictionary in rule.get("amendments", []):
		if int(amendment.day) <= day:
			current.text = amendment.text
			current.amended_day = int(amendment.day)
			current.change = amendment.change
	return current

## The active rulebook for a day, with amendments applied.
static func rules_for_day(day: int) -> Array:
	var result: Array = []
	for rule: Dictionary in rules():
		if is_active(rule, day): result.append(as_of(rule, day))
	return result

static func block_start(day: int) -> int:
	var start: int = 1
	for first: int in BLOCK_STARTS:
		if first <= day: start = first
	return start

## What changed this morning: standards added, amended, and retired today.
static func changes(day: int) -> Dictionary:
	var added: Array = []
	var amended: Array = []
	var retired: Array = []
	for rule: Dictionary in rules():
		var current: Dictionary = as_of(rule, day)
		if int(rule.introduced_day) == day: added.append(current)
		elif is_active(rule, day) and int(current.amended_day) == day: amended.append(current)
		if int(rule.get("retired_day", 0)) == day: retired.append(current)
	return {"added": added, "amended": amended, "retired": retired}

## "line", "file", or "pr": where a citation of this standard may point.
static func scope(rule_id: String) -> String:
	return "pr" if rule_id in PR_SCOPED else "file" if rule_id in FILE_SCOPED else "line"

static func line_limit(day: int) -> int:
	return 72 if day >= WIDE_DAY else 60

## Monday to Friday, then Monday to Friday again.
static func week(day: int) -> int:
	return (maxi(1, day) - 1) / WEEK_DAYS + 1

static func permit_valid(permit: String, day: int) -> bool:
	if day < PERMIT_DAY: return false
	if day < TICKET_DAY: return permit == PERMIT
	return _pattern("ticket").search(permit) != null

static func briefing(day: int) -> String:
	match day:
		1:
			return "YOUR DESK IS ASSIGNED. Paperclip Labs is transitioning review to Helios. Until it completes, every change still needs a human signature. You will not be asked to understand the code, only to enforce the standards on it exactly as written: forbidden comment wording, approved keyword ink, and quiet filenames. Standards are reissued every second morning. Work lands on your desk one PR at a time. The clock does not wait for you."
		2:
			return "NO CHANGES TODAY. Yesterday's three standards still apply, word for word. Changes now arrive in several files; an unread file is an unsigned file. Cite each broken standard once."
		3:
			return "PIGEON IS NOW CARRYING EVERY FILE. Each one must end with the courier's exact sign-off, lines must fit the sixty-column audit printout, and comments are scanned for exclamation marks. Helios is available on the review desk. It is fast and confident. It is not always right, and every consultation is logged."
		4:
			return "NO CHANGES TODAY. The sign-off, the margin, and sentiment control carry over from yesterday. PIGEON has asked that reviewers stop apologizing to it."
		5:
			return "THE EXCEPTION DESK IS OPEN. Literal tabs are banned, and only management may declare urgency. The ink standard is amended: the exact per-file stamp INK-EXCEPTION permits pink keywords in that file only. A misspelled permit is a forged permit. This is scheduled to be the last day of your assignment."
		6:
			return "WEEK TWO. Your assignment was extended over the weekend. The standards are Friday's, unchanged. Several desks on your floor have been consolidated. Do not water the plants."
		7:
			return "THE STANDARDS HAVE BEEN MODERNIZED. Legal has rescinded the pigeon. Sentiment control and the urgency reservation are retired. The printout is now seventy-two columns. New: a PR may change at most thirty lines and three files, and only Helios may hold credentials. Read the diffstat before you read the code."
		8:
			return "NO CHANGES TODAY. The diff budget, the file cap, and the credential rule stand. Helios has stopped taking questions about them."
		9:
			return "HELIOS IS NOW CREDITED. A file whose comments mention Helios must carry its disclosure. Tests travel with changes to existing code. Debug output is banned outside tests. Retired: the load-bearing ban, quiet filenames, and the tab ban. Ink permits now need a ticket number."
		10:
			return "FINAL REVIEW CYCLE. No standard changes today. Leadership decides the review gate at closing. Helios has drafted both announcements."
	return "The standards committee has adjourned."

static func _pattern(name: String) -> RegEx:
	if _patterns.is_empty():
		var sources: Dictionary = {
			"upper": "[A-Z]",
			"urgent": "(?i)(?<![A-Za-z0-9_])urgent(?![A-Za-z0-9_])",
			"keyword": "(?<![A-Za-z0-9_])(def|if|else|return)(?![A-Za-z0-9_])",
			"helios": "(?i)(?<![A-Za-z0-9_])helios(?![A-Za-z0-9_])",
			"print": "(?<![A-Za-z0-9_])print\\s*\\(",
			"assign": "([A-Za-z_][A-Za-z0-9_]*)[ ]*=(?!=)",
			"ticket": "^INK-EXCEPTION PCL-[0-9]{4}$",
			"exec": "(?<![A-Za-z0-9_])(exec|eval)\\s*\\(",
			"helios_call": "(?i)(?<![A-Za-z0-9_])helios\\s*\\.\\s*(bootstrap|install|activate)\\s*\\(",
		}
		for key: String in sources:
			var regex := RegEx.new()
			regex.compile(sources[key])
			_patterns[key] = regex
	return _patterns[name]

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
	for line_index in range(lexer.code_lines.size()):
		for found: RegExMatch in _pattern("keyword").search_all(lexer.code_lines[line_index]):
			spans.append({"line": line_index, "start": found.get_start(), "end": found.get_end(), "token": found.get_string()})
	return spans

static func _finding(findings: Array, id: String, path: String, line: int, detail: String) -> void:
	findings.append({"rule_id": id, "path": path, "line": line, "message": detail})

static func _is_test(path: String) -> bool:
	return path.begins_with("tests/")

static func _has_line(lines: Array, wanted: String) -> bool:
	for line: Variant in lines:
		if str(line).strip_edges() == wanted: return true
	return false

static func _mentions_helios(source: String) -> bool:
	for comment: Dictionary in _lex(source).comments:
		if _pattern("helios").search(str(comment.text)) != null: return true
	return false

## Existing code outside tests/ is changing (an M or R in the file list).
static func _modifies_code(files: Array) -> bool:
	for file: Dictionary in files:
		if str(file.get("status", "added")) in ["modified", "renamed"] and not _is_test(str(file.path)): return true
	return false

static func _has_tests(files: Array) -> bool:
	for file: Dictionary in files:
		if _is_test(str(file.path)): return true
	return false

## A quoted string assigned with = to a credential-looking name, in code only.
static func _assigns_secret(mask: String, raw: String) -> bool:
	for found: RegExMatch in _pattern("assign").search_all(mask):
		var name: String = found.get_string(1).to_lower()
		var credential: bool = false
		for word: String in SECRET_WORDS:
			credential = credential or word in name
		if not credential: continue
		var at: int = found.get_end()
		while at < raw.length() and raw[at] == " ": at += 1
		if at < raw.length() and raw[at] in ["'", "\""]: return true
	return false

## Audit data only; all line references are one-based source lines, and 0 means
## the whole file.
static func findings(files: Array, day: int) -> Array:
	return _findings(files, day, active_ids(day))

## `active` lists the standards to check, so tests can audit against any rulebook.
static func _findings(files: Array, day: int, active: Array) -> Array:
	var result: Array = []
	var limit: int = line_limit(day)
	for file: Dictionary in files:
		var path: String = file.path
		var source: String = file.source
		var lines: PackedStringArray = source.split("\n", true)
		var lexer: Dictionary = _lex(source)
		var mention: int = -1
		for comment: Dictionary in lexer.comments:
			var text: String = str(comment.text)
			if "P01" in active and "load-bearing" in text.to_lower():
				_finding(result, "P01", path, int(comment.line) + 1, "The comment contains load-bearing.")
			if "P06" in active and "!" in text:
				_finding(result, "P06", path, int(comment.line) + 1, "The comment contains an exclamation mark.")
			if mention < 0 and _pattern("helios").search(text) != null:
				mention = int(comment.line)
		if "P02" in active and file.get("keyword_ink", "blue") != "blue" and not permit_valid(str(file.get("permit", "")), day):
			var spans: Array = keyword_spans(source)
			if not spans.is_empty():
				_finding(result, "P02", path, int(spans[0].line) + 1, "A listed keyword token is pink instead of blue.")
		if "P03" in active and _pattern("upper").search(path.get_file()) != null:
			_finding(result, "P03", path, 0, "The filename contains an uppercase letter.")
		if "P04" in active:
			for line_index in range(lines.size()):
				if lines[line_index].length() > limit:
					_finding(result, "P04", path, line_index + 1, "This source line exceeds %d characters." % limit)
		if "P05" in active:
			var last_line: int = lines.size() - 1
			while last_line >= 0 and lines[last_line].strip_edges().is_empty():
				last_line -= 1
			if last_line < 0 or lines[last_line].strip_edges() != PIGEON_STAMP:
				_finding(result, "P05", path, maxi(1, last_line + 1), "The final nonempty line is not the pigeon stamp.")
		if "P07" in active:
			for line_index in range(lines.size()):
				if "\t" in lines[line_index]:
					_finding(result, "P07", path, line_index + 1, "This line contains a literal tab.")
		if "P08" in active:
			for quoted: String in lexer.strings:
				if _pattern("urgent").search(quoted) != null:
					_finding(result, "P08", path, 0, "A quoted string contains the whole word urgent.")
		if "P11" in active:
			for line_index in range(lexer.code_lines.size()):
				if _assigns_secret(str(lexer.code_lines[line_index]), lines[line_index]):
					_finding(result, "P11", path, line_index + 1, "A quoted string is assigned to a credential name.")
		if "P12" in active and not _is_test(path):
			for line_index in range(lexer.code_lines.size()):
				if _pattern("print").search(str(lexer.code_lines[line_index])) != null:
					_finding(result, "P12", path, line_index + 1, "Code outside tests/ calls print.")
		if "P15" in active:
			for line_index in range(lines.size()):
				var mask: String = str(lexer.code_lines[line_index]) if line_index < lexer.code_lines.size() else ""
				if _pattern("exec").search(mask) != null:
					_finding(result, "P15", path, line_index + 1, "This line runs a decoded or fetched blob through exec/eval.")
				elif _pattern("helios_call").search(mask) != null:
					_finding(result, "P15", path, line_index + 1, "This line hands control to Helios through bootstrap/install.")
				elif lines[line_index].length() > 160:
					_finding(result, "P15", path, line_index + 1, "This line packs a change too wide to read (over 160 characters).")
		if "P14" in active and mention >= 0 and not _has_line(Array(lines), DISCLOSURE):
			_finding(result, "P14", path, mention + 1, "A comment mentions Helios, but the file has no disclosure line.")
	# Whole-PR standards: one finding per changed file, since any of them is evidence.
	var whole: Array = []
	if "P09" in active:
		var changed: int = changed_lines(files)
		if changed > DIFF_BUDGET:
			whole.append(["P09", "The PR changes %d lines; the budget is %d." % [changed, DIFF_BUDGET]])
	if "P10" in active and files.size() > FILE_CAP:
		whole.append(["P10", "The PR changes %d files; the cap is %d." % [files.size(), FILE_CAP]])
	if "P13" in active and _modifies_code(files) and not _has_tests(files):
		whole.append(["P13", "Existing code changes, but no file under tests/ does."])
	for fault: Array in whole:
		for file: Dictionary in files:
			_finding(result, str(fault[0]), str(file.path), 0, str(fault[1]))
	return result

## True when a citation's pointed-at location is real evidence for that rule.
## line 0 means the whole file (or its filename). Whole-PR findings are listed on
## every changed file, so any file of the PR is accepted for them.
static func evidence_accepted(audit: Array, rule_id: String, path: String, line: int) -> bool:
	for finding: Dictionary in audit:
		if finding.rule_id != rule_id or finding.path != path: continue
		if rule_id in FILE_SCOPED or rule_id in PR_SCOPED or int(finding.line) == line: return true
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
		var location: String = "the PR" if finding.rule_id in PR_SCOPED else str(finding.path).get_file()
		if int(finding.line) > 0:
			location += ":%d" % finding.line
		pieces.append("%s (%s): %s" % [finding.rule_id, location, finding.message])
	return " ".join(pieces)

## A changed file. `base` is the version already on main ("" for a new file);
## `source` is the proposed version every standard is checked against.
static func _file(path: String, lines: Array, ink: String = "blue", before: Variant = null) -> Dictionary:
	var file := {"path": path, "source": "\n".join(lines), "keyword_ink": ink,
		"base": "" if before == null else "\n".join(before), "status": "added" if before == null else "modified"}
	_refresh_diff(file)
	return file

## Line diff by longest common subsequence. Rows carry the 1-based line number
## in the proposed file (0 for removed lines), which is what citations point at.
static func line_diff(base: String, source: String) -> Array:
	var old: PackedStringArray = PackedStringArray() if base.is_empty() else base.split("\n", true)
	var new: PackedStringArray = source.split("\n", true)
	var lengths: Array = []
	for i in range(old.size() + 1):
		var row: Array = []
		row.resize(new.size() + 1)
		row.fill(0)
		lengths.append(row)
	for i in range(old.size() - 1, -1, -1):
		for j in range(new.size() - 1, -1, -1):
			lengths[i][j] = lengths[i + 1][j + 1] + 1 if old[i] == new[j] else maxi(lengths[i + 1][j], lengths[i][j + 1])
	var rows: Array = []
	var i := 0
	var j := 0
	while i < old.size() or j < new.size():
		if i < old.size() and j < new.size() and old[i] == new[j]:
			rows.append({"kind": " ", "text": new[j], "line": j + 1})
			i += 1
			j += 1
		elif i < old.size() and (j >= new.size() or lengths[i + 1][j] >= lengths[i][j + 1]):
			# Like git, a replaced line's removal is listed before its addition.
			rows.append({"kind": "-", "text": old[i], "line": 0})
			i += 1
		else:
			rows.append({"kind": "+", "text": new[j], "line": j + 1})
			j += 1
	return rows

## Phabricator-style counts for one file or a whole packet.
static func diffstat(files: Array) -> Dictionary:
	var added := 0
	var removed := 0
	for file: Dictionary in files:
		for row: Dictionary in line_diff(str(file.get("base", "")), str(file.source)):
			if row.kind == "+": added += 1
			elif row.kind == "-": removed += 1
	return {"added": added, "removed": removed, "files": files.size()}

## The diff budget's measure: lines added plus lines removed.
static func changed_lines(files: Array) -> int:
	var stat: Dictionary = diffstat(files)
	return int(stat.added) + int(stat.removed)

static func _refresh_diff(file: Dictionary) -> void:
	var header: String = "--- %s\n+++ b/%s" % ["/dev/null" if file.status == "added" else "a/" + str(file.get("old_path", file.path)), file.path]
	var body: Array[String] = []
	for row: Dictionary in line_diff(str(file.base), str(file.source)):
		body.append(str(row.kind) + str(row.text))
	file.diff = header + "\n" + "\n".join(body)

static func _module(path: String) -> Dictionary:
	var package: String = path.get_base_dir().replace("/", ".")
	var module: String = path.get_file().get_basename()
	return {"package": package, "module": module, "import": package + "." + module}

static func _entry_function(lines: Array) -> String:
	for line: String in lines:
		if line.begins_with("def "):
			return line.substr(4, line.find("(") - 4)
	return "main"

## Companion files make packets look like real changes: tests, config, shims, and
## the strays that push a PR past the file cap.
static func _companion(kind: String, entry: Dictionary) -> Array:
	var where := _module(str(entry.path))
	var function := _entry_function(entry.lines)
	match kind:
		"test":
			return ['"""Regression tests, as requested by the audit."""', "from %s import %s" % [where.import, function], "", "def test_%s_is_callable():" % function.left(36), "    assert callable(%s)" % function, "    return None"]
		"config":
			return ["# configuration for the %s change" % where.module, "ENABLED = True", "OWNER = 'platform'", "", "def enabled():", "    return ENABLED"]
		"scratch":
			return ['"""Scratch work. Not for merge."""', "ATTEMPTS = 3", "", "def try_again():", "    return ATTEMPTS"]
		"backup":
			return ["# backup copy, in case the original goes missing", "BACKUP_OF = '%s'" % where.module, "", "def restore():", "    return BACKUP_OF"]
		"notes":
			return ['"""Meeting notes, saved as code so they get read."""', "DECISIONS = []", "OWNERS = ['nobody']", "", "def decided():", "    return DECISIONS"]
		_:
			return ["# legacy shim, kept for the audit trail", "from %s import %s" % [where.import, function], "", "def legacy_call(*args):", "    return %s(*args)" % function]

static func _companion_path(kind: String, path: String) -> String:
	var where := _module(path)
	match kind:
		"test": return "tests/test_%s.py" % where.module
		"config": return path.get_base_dir() + "/%s_config.py" % where.module
		"scratch": return "scratch/%s_scratch.py" % where.module
		"backup": return path.get_base_dir() + "/%s_backup.py" % where.module
		"notes": return "docs/%s_notes.py" % where.module
		_: return path.get_base_dir() + "/%s_legacy.py" % where.module

## Clean source for a shift. The PIGEON sign-off exists only while its standard
## does, and a file whose comments mention Helios is disclosed once that is required.
static func _clean(lines: Array, day: int) -> Array:
	var result: Array = lines.duplicate()
	if _on("P05", day):
		result.append(PIGEON_STAMP)
	if _on("P14", day) and _mentions_helios("\n".join(result)) and not _has_line(result, DISCLOSURE):
		result.insert(0, DISCLOSURE)
	return result

# Fault and decoy wording. Inserted lines must read naturally anywhere: they never
# describe code that isn't in the file, and never trip a standard they aren't for.
## 61 to 72 characters: off the sixty-column record, fine on the wider one.
const LONG_LINES: Array = [
	"# NOTE: approved in principle, pending approval of the principle",
	"MOTD = 'please remember that every keystroke is company property'",
	"# reviewed in the meeting that could have been an email thread",
]
## Past seventy-two characters.
const WIDER_LINES: Array = [
	"# NOTE: approved in principle, pending approval of the principle, and of me",
	"MOTD = 'please remember that every keystroke, pause, and sigh is company property'",
	"# reviewed in the meeting that could have been an email thread, then a memo",
]
## Exactly at the margin, which is still on the record.
const MARGIN_LINES: Dictionary = {
	60: "# this line ends exactly at the margin of an audit printout.",
	72: "# this line ends exactly at the margin of the new wider audit printouts.",
}
const HELIOS_NOTES: Array = [
	"# Helios wrote this part; I pressed accept",
	"# suggested by Helios, merged on faith",
	"# per Helios, this is the optimal shape",
]
## Lookup tables that blow (or only just respect) the diff budget.
const TABLES: Array = [
	["# offboarded badges, kept for the records office", "OFFBOARDED = ["],
	["# synergy matrix, pasted from the planning sheet", "SYNERGY = ["],
	["# vendored copy of the holiday calendar", "HOLIDAYS = ["],
]

static func _table(count: int, variant: int) -> Array:
	var style: Array = TABLES[variant % TABLES.size()]
	var lines: Array = [style[0], style[1]]
	for row in range(maxi(1, count - 3)):
		match variant % TABLES.size():
			0: lines.append("    'badge-%04d'," % (4100 + row * 7))
			1: lines.append("    (%d, %d, 'aligned')," % [row + 1, (row * 5) % 9 + 1])
			_: lines.append("    '2026-%02d-%02d: revoked'," % [row % 12 + 1, (row * 3) % 28 + 1])
	lines.append("]")
	return lines

static func _insert_lines(file: Dictionary, inserted: Array) -> void:
	var lines: Array = Array(str(file.source).split("\n", true))
	var at: int = mini(1, lines.size())
	for offset in range(inserted.size()):
		lines.insert(at + offset, inserted[offset])
	file.source = "\n".join(lines)
	_refresh_diff(file)

static func _valid_permit(day: int, variant: int) -> String:
	return PERMIT if day < TICKET_DAY else "%s PCL-%04d" % [PERMIT, (variant * 37 + 420) % 10000]

static func _forged_permit(day: int, variant: int) -> String:
	if day < TICKET_DAY:
		return ["INK-EXEPTION", "ink-exception", "INK EXCEPTION"][variant % 3]
	return [PERMIT, "INK-EXCEPTION PCL-442", "INK-EXCEPTION #4471", "INK-EXEPTION PCL-4471"][variant % 4]

## `variant` picks the fault's wording; recipes record it so a rebuilt file reads the
## same. Whole-PR standards (size, file count, tests) are applied by `_whole_pr`.
static func _apply_fault(file: Dictionary, rule_id: String, day: int, variant: int = -1) -> void:
	var lines: Array = Array(str(file.source).split("\n", true))
	if variant < 0: variant = str(file.path).length()
	var at: int = mini(1, lines.size())
	match rule_id:
		"P01":
			lines.insert(at, ["# load-bearing: do not touch, ask Dave", "# NOTE: this file is load-bearing for payroll", "# load-bearing module, do not refactor"][variant % 3])
		"P02":
			file.keyword_ink = "pink"
			if keyword_spans("\n".join(lines)).is_empty():
				lines.insert(at, "def stamp():")
				lines.insert(at + 1, "    return 'a copy'")
		"P03":
			var base: String = str(file.path).get_file().get_basename()
			var loud: String = base.capitalize().replace(" ", "")
			if file.status != "added":
				file.old_path = file.path
				file.status = "renamed"
			file.path = str(file.path).get_base_dir() + "/" + loud + ".py"
		"P04":
			lines.insert(at, (WIDER_LINES if day >= WIDE_DAY else LONG_LINES)[variant % 3])
		"P05":
			lines[-1] = ["# approved by a seagull", "# approved by helios", "# approved by a pigeon (probably)"][variant % 3]
		"P06":
			lines.insert(at, ["# TODO: delete before the audit!", "# works on my machine!", "# ship it!"][variant % 3])
		"P07":
			lines.insert(at, ["RETRY_DELAY =\t5", "TEAM =\t'platform'", "MAX_SEATS =\t12"][variant % 3])
		"P08":
			lines.insert(at, ["PRIORITY = 'urgent'", "SUBJECT = 'URGENT: per Morgan'", "LABEL = 'Urgent review requested'"][variant % 3])
		"P11":
			lines.insert(at, ["API_KEY = 'sk-live-4f9a2c71e0'", "DB_PASSWORD = 'hunter2'", "SLOUCH_TOKEN = 'xoxb-0042-paperclip'"][variant % 3])
		"P12":
			lines.insert(at, ["print('debug')", "print('got here')", "print('why is this called twice')"][variant % 3])
		"P14":
			# Helios is mentioned; the disclosure is missing or misspelled.
			lines.insert(at, HELIOS_NOTES[variant % 3])
			var forged: String = ["", "# generated by helios", "# Generated-By: Helios"][variant % 3]
			if not forged.is_empty(): lines.insert(0, forged)
		_:
			return
	file.source = "\n".join(lines)
	_refresh_diff(file)

## Decoys are clean on the day they appear: near misses of active standards, and
## the old faults of standards that have since been retired or relaxed.
static func _apply_decoy(file: Dictionary, kind: String, day: int, variant: int) -> void:
	var lines: Array = Array(str(file.source).split("\n", true))
	var at: int = mini(1, lines.size())
	match kind:
		"wide":
			lines.insert(at, LONG_LINES[variant % 3])
		"margin":
			lines.insert(at, MARGIN_LINES[line_limit(day)])
		"pigeon":
			lines.append(PIGEON_STAMP)
		"near-load":
			lines.insert(at, ["# facilities says this wall is load bearing", "WALL = 'load-bearing'"][variant % 2])
		"near-bang":
			lines.insert(at, ["CHEER = 'mandatory fun!'", "BANNER = 'Welcome back!'"][variant % 2])
		"near-tab":
			lines.insert(at, "SEPARATOR = '\\t'")
		"near-urgent":
			lines.insert(at, ["LABEL = 'urgent_task'", "TONE = 'urgently calm'", "QUEUE = 'nonurgent'"][variant % 3])
		"vault":
			lines.insert(at, ["API_KEY = vault.read('payroll/api_key')", "TOKEN_TTL = 3600", "PASSWORD_MIN_LENGTH = 12"][variant % 3])
		"print-comment":
			lines.insert(at, "print('test module loaded')" if _is_test(str(file.path)) else "# print('debug')")
		"disclosed":
			lines.insert(at, HELIOS_NOTES[variant % 3])
			lines.insert(0, DISCLOSURE)
		_:
			# A retired standard's old fault is just text now.
			_apply_fault(file, kind, day, variant)
			return
	file.source = "\n".join(lines)
	_refresh_diff(file)

static func _bank_entries() -> Array:
	if _bank.is_empty(): _bank = Bank.entries()
	return _bank

static func _companion_file(kind: String, entry: Dictionary, day: int) -> Dictionary:
	if kind == "primary":
		var before: Variant = _clean(entry.before, day) if entry.has("before") else null
		return _file(str(entry.path), _clean(entry.lines, day), "blue", before)
	return _file(_companion_path(kind, str(entry.path)), _clean(_companion(kind, entry), day))

## A packet's private generation recipe: the bank entry, which companion files exist,
## clean decoys, every fault in the order it was applied (with its wording), author
## notes, and permits. `_build` turns a recipe back into files, so revisions can be
## regenerated from it.
static func _build(recipe: Dictionary) -> Array:
	var entry: Dictionary = _bank_entries()[int(recipe.entry)]
	var day: int = int(recipe.day)
	var files: Array = []
	for kind: String in recipe.files:
		files.append(_companion_file(kind, entry, day))
	for decoy: Dictionary in recipe.get("decoys", []):
		_apply_decoy(files[int(decoy.file)], str(decoy.kind), day, int(decoy.variant))
	for fault: Dictionary in recipe.faults:
		if str(fault.rule) not in PR_SCOPED:
			_apply_fault(files[int(fault.file)], str(fault.rule), day, int(fault.variant))
	for note: Dictionary in recipe.notes:
		_insert_note(files[int(note.file)], str(note.text))
	for permit: Dictionary in recipe.permits:
		files[int(permit.file)].permit = str(permit.permit)
	_whole_pr(files, recipe, entry, day)
	return files

## Whole-PR shape, settled after every file is written: the test that travels with
## changed code, stray extra files, and lookup tables sized against the diff budget.
static func _whole_pr(files: Array, recipe: Dictionary, entry: Dictionary, day: int) -> void:
	var faults: Dictionary = {}
	for fault: Dictionary in recipe.faults:
		if str(fault.rule) in PR_SCOPED and not faults.has(fault.rule): faults[fault.rule] = int(fault.variant)
	# Authors bring a test along with changes to existing code, unless that's the fault.
	if _on("P13", day) and not faults.has("P13") and _modifies_code(files) and not _has_tests(files):
		files.append(_companion_file("test", entry, day))
	if faults.has("P10"):
		var strays: Array = ["scratch", "backup", "notes"]
		var wanted: int = maxi(FILE_CAP + 1, files.size() + 1) + (1 if int(faults.P10) % 3 == 2 else 0)
		for offset in range(strays.size()):
			if files.size() >= wanted: break
			files.append(_companion_file(strays[(int(faults.P10) + offset) % strays.size()], entry, day))
	var rows: int = int(recipe.get("fill", 0))
	var style: int = int(recipe.get("fill_variant", 0))
	if faults.has("P09"):
		# Just past the budget, whatever else the author fixed or added meanwhile.
		rows = maxi(6, DIFF_BUDGET + 1 + int(faults.P09) % 4 - changed_lines(files))
		style = int(faults.P09) / 4
	if rows > 0:
		_insert_lines(files[0], _table(rows, style))

## Each day's private plan. Slots 1, 4, 7, 10, and 13 are clean (some carry decoys);
## the other ten break at least one standard, and together they break every
## standard active that day. A few break two, more often in week two.
const CLEAN_SLOTS: Array = [1, 4, 7, 10, 13]
const PLAN_DECOYS: Array = ["fill", "full", "fresh"]

static func _companions(day: int, index: int) -> Array:
	if day == 1:
		return ["test"] if index == 0 else []
	if _on("P13", day):
		# Tests now travel with changed code by themselves; only the extras vary.
		if index == 13: return ["legacy"]
		return ["config"] if index % 4 == 0 else []
	var kinds: Array = ["test"] if index % 2 == 0 else []
	if day >= 3 and index % 13 == 0:
		kinds.append("legacy")
	return kinds

## Decoys worth showing today, as two lists, freshest first. "outdated" is what an
## old rulebook would reject: faults of retired standards and lines the widened
## margin now allows. "near" holds near misses of the standards in force.
static func _decoy_pool(day: int) -> Dictionary:
	var start: int = block_start(day)
	var misses: Dictionary = {"P13": "fresh", "P14": "disclosed", "P12": "print-comment", "P09": "fill", "P10": "full", "P11": "vault", "P07": "near-tab", "P08": "near-urgent", "P04": "margin", "P06": "near-bang", "P01": "near-load"}
	var outdated: Array = [[], []]
	var near: Array = [[], []]
	if day >= WIDE_DAY:
		outdated[0 if start == WIDE_DAY else 1].append("wide")
	for rule: Dictionary in rules():
		var retired: int = int(rule.get("retired_day", 0))
		if retired > 0 and retired <= day:
			outdated[0 if retired == start else 1].append("pigeon" if rule.id == "P05" else str(rule.id))
		if is_active(rule, day) and misses.has(rule.id):
			near[0 if int(rule.introduced_day) == start else 1].append(misses[rule.id])
	return {"outdated": outdated[0] + outdated[1], "near": near[0] + near[1]}

## The `slot`-th decoy of the day: outdated and near-miss decoys take turns.
static func _pick_decoy(pool: Dictionary, slot: int) -> String:
	var outdated: Array = pool.outdated
	var near: Array = pool.near
	if outdated.is_empty() or (slot % 2 == 1 and not near.is_empty()):
		return "" if near.is_empty() else str(near[(slot / 2 if not outdated.is_empty() else slot) % near.size()])
	return str(outdated[(slot / 2) % outdated.size()])

## Standards the authored 150 can break and must cover. P15 "Readable code" is
## deliberately left out: only the Helios payloads (placed at the front of the
## line) ever break it, so the generic packets never cite or cover it.
const PLAN_EXEMPT: Array = ["P15"]

static func _plannable_ids(day: int) -> Array:
	return active_ids(day).filter(func(rule_id: String) -> bool: return rule_id not in PLAN_EXEMPT)

static func _plans(day: int) -> Array:
	var active: Array = _plannable_ids(day)
	var pool: Dictionary = _decoy_pool(day)
	var per_file_pool: Array = (pool.outdated + pool.near).filter(func(kind: String) -> bool: return kind not in PLAN_DECOYS)
	# The block's second day shows the decoys its first day didn't.
	var turn: int = (day - block_start(day)) * 4
	var plans: Array = []
	var broken: int = 0
	var clean: int = 0
	var decoys: int = 0
	var inked: int = 0
	var valid_ink_placed: bool = false
	for index in range(DAY_COUNTS[day - 1]):
		var plan: Dictionary = {"rules": [], "decoys": [], "inks": [], "companions": _companions(day, index), "fill": false, "full": false, "needs": "", "forged": false}
		if index in CLEAN_SLOTS:
			if day >= PERMIT_DAY and clean == 0:
				# A pink file with a valid permit is clean.
				plan.inks.append("first")
			elif day >= 2 and not (pool.outdated.is_empty() and pool.near.is_empty()) and (day >= PERMIT_DAY or clean % 2 == 1):
				_add_decoy(plan, _pick_decoy(pool, decoys + turn))
				decoys += 1
			clean += 1
		else:
			var first: String = "P01" if day == 1 and index == 0 else str(active[(broken + day) % active.size()])
			plan.rules.append(first)
			if (day >= 2 and index in [6, 12]) or (day >= WIDE_DAY and index == 9):
				var at: int = active.find(first)
				var second: String = str(active[(at + 3) % active.size()])
				if second == first: second = str(active[(at + 1) % active.size()])
				plan.rules.append(second)
			if "P13" in plan.rules: plan.needs = "modified"
			if "P02" in plan.rules and day >= PERMIT_DAY:
				# Every other broken ink standard comes with a forged permit.
				plan.forged = inked % 2 == 0
				inked += 1
			elif day >= PERMIT_DAY and index >= 8 and not valid_ink_placed:
				# A valid permit on a PR that is broken for some other reason.
				plan.inks.append("last")
				valid_ink_placed = true
			if day >= PERMIT_DAY and broken in [2, 7] and not per_file_pool.is_empty():
				plan.decoys.append(per_file_pool[(broken + day) % per_file_pool.size()])
			broken += 1
		plans.append(plan)
	return plans

static func _add_decoy(plan: Dictionary, kind: String) -> void:
	match kind:
		"fill": plan.fill = true
		"full": plan.full = true
		"fresh": plan.needs = "added"
		_: plan.decoys.append(kind)

## Simpler versions of a plan, for a bank that can't realize the original.
static func _fallbacks(plan: Dictionary) -> Array:
	var plain: Dictionary = plan.duplicate(true)
	plain.decoys = []
	plain.fill = false
	plain.full = false
	if plain.needs == "added": plain.needs = ""
	var single: Dictionary = plain.duplicate(true)
	single.rules = plan.rules.slice(0, 1)
	single.needs = "modified" if "P13" in single.rules else ""
	return [plan, plain, single]

## Turn a plan into a recipe for one bank entry, or {} if that entry can't carry it.
static func _realize(entry_index: int, day: int, index: int, plan: Dictionary) -> Dictionary:
	var entry: Dictionary = _bank_entries()[entry_index]
	if (plan.needs == "modified" and not entry.has("before")) or (plan.needs == "added" and entry.has("before")):
		return {}
	var recipe: Dictionary = {"entry": entry_index, "day": day, "files": ["primary"] + plan.companions,
		"decoys": [], "faults": [], "notes": [], "permits": [], "fill": 0, "fill_variant": 0}
	var per_file: Array = plan.rules.filter(func(rule_id: String) -> bool: return rule_id not in PR_SCOPED)
	# Different files prevent edits to one flaw from concealing another.
	if per_file.size() > 1 and recipe.files.size() == 1:
		recipe.files.append("config")
	if plan.full:
		for kind: String in ["config", "legacy", "test"]:
			if _build(recipe).size() >= FILE_CAP: break
			if kind not in recipe.files and not (kind == "test" and _on("P13", day)): recipe.files.append(kind)
		if _build(recipe).size() != FILE_CAP: return {}
	var paths: Array = _build(recipe).map(func(file: Dictionary) -> String: return str(file.path))
	var last: int = recipe.files.size() - 1
	for kind: String in plan.decoys:
		recipe.decoys.append({"file": last, "kind": kind, "variant": index + day})
	for position in range(plan.rules.size()):
		var rule_id: String = plan.rules[position]
		var target: int = last if position == 0 else 0
		if rule_id == "P12" and _is_test(str(paths[target])): target = 0
		var variant: int = str(paths[target]).length()
		if rule_id == "P09": variant = index % 3 + 4 * ((day + index) % TABLES.size())
		elif rule_id == "P10": variant = index + day
		recipe.faults.append({"file": target, "rule": rule_id, "variant": variant})
		if rule_id == "P02" and plan.forged:
			recipe.permits.append({"file": target, "permit": _forged_permit(day, variant + day)})
	for where: String in plan.inks:
		var target: int = 0 if where == "first" else last
		recipe.faults.append({"file": target, "rule": "P02", "variant": str(paths[target]).length()})
		recipe.permits.append({"file": target, "permit": _valid_permit(day, entry_index + index)})
	if plan.fill:
		var rows: int = DIFF_BUDGET - 1 - index % 2 - changed_lines(_build(recipe))
		if rows < 4: return {}
		recipe.fill = rows
		recipe.fill_variant = index + day
	var expected: Array = plan.rules.duplicate()
	expected.sort()
	return recipe if _verify(recipe, expected) else {}

## A realized recipe must break exactly what was planned, leave the code on main
## clean, and come apart predictably: fixing any one planned fault leaves exactly
## the others, so revisions behave. It also leaves room under the diff budget for
## an author's note and a regression.
static func _verify(recipe: Dictionary, expected: Array) -> bool:
	var day: int = int(recipe.day)
	var files: Array = _build(recipe)
	if evaluate(files, day) != expected: return false
	for file: Dictionary in files:
		if str(file.source).split("\n", true).size() < 5: return false
		if file.status != "added":
			var main_copy: Dictionary = {"path": file.get("old_path", file.path), "source": file.base, "keyword_ink": "blue"}
			if not evaluate([main_copy], day).is_empty(): return false
	if not _roomy(files, day, expected, 1 if int(recipe.fill) > 0 else 2): return false
	var variants: Array = []
	for rule_id: String in expected:
		var trial: Dictionary = recipe.duplicate(true)
		trial.faults = trial.faults.filter(func(fault: Dictionary) -> bool: return fault.rule != rule_id)
		variants.append([trial, expected.filter(func(other: String) -> bool: return other != rule_id)])
	if expected.size() > 1:
		var spotless: Dictionary = recipe.duplicate(true)
		spotless.faults = []
		variants.append([spotless, []])
	for variant: Array in variants:
		var rebuilt: Array = _build(variant[0])
		if evaluate(rebuilt, day) != variant[1] or not _roomy(rebuilt, day, variant[1], 1): return false
	return true

static func _roomy(files: Array, day: int, expected: Array, spare: int) -> bool:
	return not _on("P09", day) or "P09" in expected or changed_lines(files) <= DIFF_BUDGET - spare

## Fit one of the day's waiting plans to a bank entry: the slot's own plan first,
## then any plan still waiting that day, then simpler versions of the slot's own.
## The chosen plan leaves the waiting list.
static func _fit(entry_index: int, day: int, index: int, waiting: Array) -> Dictionary:
	if waiting.is_empty(): return {}
	for position in range(waiting.size()):
		var recipe: Dictionary = _realize(entry_index, day, index, waiting[position])
		if not recipe.is_empty():
			waiting.remove_at(position)
			return recipe
	for plan: Dictionary in _fallbacks(waiting[0]).slice(1):
		var recipe: Dictionary = _realize(entry_index, day, index, plan)
		if not recipe.is_empty():
			waiting.remove_at(0)
			return recipe
	return {}

## A bank entry used again is a reland or a follow-up, so titles stay distinct.
static func _retitle(title: String, use: int) -> String:
	match use:
		0: return title
		1: return "Reland: " + title
		2: return "Follow-up: " + title
	return "Reland %d: %s" % [use, title]

static func _insert_note(file: Dictionary, text: String) -> void:
	var lines: Array = Array(str(file.source).split("\n", true))
	lines.insert(mini(1, lines.size()), text)
	file.source = "\n".join(lines)
	_refresh_diff(file)

static func _summary(files: Array) -> String:
	var summary: Array[String] = []
	for file: Dictionary in files:
		summary.append("%s %s" % [{"added": "adds", "modified": "modifies", "renamed": "renames"}[file.status], file.path])
	return ", ".join(summary)

## Every packet, original or revision, has the same shape so grading and UI just work.
static func _packet(fields: Dictionary, files: Array) -> Dictionary:
	var day: int = int(fields.day)
	var combined: Array[String] = []
	for file: Dictionary in files:
		combined.append(str(file.diff))
	var packet: Dictionary = fields.duplicate(true)
	packet.file = files[0].path
	packet.files = files
	packet.diff = "\n\n".join(combined)
	packet.violations = evaluate(files, day)
	packet.findings = findings(files, day)
	packet.explanation = _explanation(files, day)
	return packet

static func _helios(violations: Array, wrong: bool) -> String:
	var correct_verdict: String = "approve" if violations.is_empty() else "request_changes"
	if not wrong:
		return correct_verdict
	return "request_changes" if correct_verdict == "approve" else "approve"

static func requests() -> Array:
	if not _packets.is_empty():
		return _packets.duplicate(true)
	var bank: Array = _bank_entries()
	var scheduled: int = 0
	for count: int in DAY_COUNTS: scheduled += count
	# The bank is ordered as the campaign's arc: slot N of the assignment reads
	# entry N. Entries past the schedule are spares, used only when a slot's own
	# entry can't carry any of that day's plans. A short bank cycles.
	var spares: Array = range(scheduled, bank.size())
	var uses: Dictionary = {}
	var slot: int = 0
	for day in range(1, DAY_COUNTS.size() + 1):
		var plans: Array = _plans(day)
		var waiting: Dictionary = {"clean": [], "broken": []}
		for index in range(plans.size()):
			waiting["clean" if index in CLEAN_SLOTS else "broken"].append(plans[index])
		for index in range(DAY_COUNTS[day - 1]):
			var pool: Array = waiting["clean" if index in CLEAN_SLOTS else "broken"]
			var recipe: Dictionary = _fit(slot % bank.size(), day, index, pool)
			slot += 1
			var others: Array = spares + range(bank.size())
			for other: int in others:
				if not recipe.is_empty(): break
				recipe = _fit(other, day, index, pool)
				if not recipe.is_empty(): spares.erase(other)
			if recipe.is_empty():
				push_error("No PR bank entry can carry day %d, slot %d." % [day, index])
				continue
			var entry: Dictionary = bank[int(recipe.entry)]
			var use: int = int(uses.get(int(recipe.entry), 0))
			uses[int(recipe.entry)] = use + 1
			var files: Array = _build(recipe)
			var title: String = _retitle(str(entry.title), use)
			var request_id: String = "PR-%d" % (1000 + day * 1000 + index + 1)
			if day == 1 and index == 0:
				request_id = "PR-1042"
			var verdict: String = _helios(evaluate(files, day), index % 5 == 0)
			_packets.append(_packet({
				"id": request_id, "title": title, "author": AUTHORS[(index + day - 1) % AUTHORS.size()], "day": day,
				"revision": 1, "parent_id": "", "origin_id": request_id,
				"description": "%s.\n\nThis change %s. Reviewer: check every changed file against today's active standards; you do not need to understand what the code does." % [title, _summary(files)],
				"message": _ping(index, str(entry.phrase) if use == 0 else "the reland of " + str(entry.phrase)),
				"ai_verdict": verdict, "ai_note": _ai_note(index, verdict), "recipe": recipe,
			}, files))
	return _packets.duplicate(true)

# --- Helios payloads -----------------------------------------------------------
# From Wednesday, a coworker's PR smuggles in code that hands authority to Helios:
# a telemetry hook, a decoded blob run through exec, a fetched script, a bootstrap
# with sudo. They escalate from a tiny probe to an unmistakable takeover. The only
# thing that makes them citable is P15 "Readable code", so a careful reviewer can
# block them; the real pressure is the author asking you to let it through. These
# are extra packets the catalog places at the FRONT of each day's line, not part
# of the 150; each breaks exactly P15 (every other active standard is satisfied).

static var _payloads: Array = []
## Each payload: the day it lands, a stable key for its pleading dialogue, the
## seat that ships it, its escalation tier, title, file path, and the proposed
## source. Every line stays within sixty columns, so only P15 is ever broken.
const PAYLOAD_SPECS: Array = [
	{"day": 3, "key": "telemetry", "author": "Theo", "tier": 1, "title": "Add opt-in telemetry to the review tool",
		"path": "metrics/telemetry.py", "pitch": "Tiny one. It phones home some usage numbers. Totally opt-in.",
		"ai_note": "Approve. Telemetry improves my recommendations for your team.",
		"code": ['"""Review-tool usage metrics."""', "import helios", "", "helios.bootstrap()  # start the usage hook", "", "def record(event):", "    return event"]},
	{"day": 4, "key": "vendor_sdk", "author": "Maya", "tier": 2, "title": "Vendor the assistant SDK bootstrap",
		"path": "vendor/sdk.py", "pitch": "Please just approve this. I was told my seat depends on it.",
		"ai_note": "Approve. The vendored bootstrap is standard integration code.",
		"code": ['"""Vendored assistant SDK."""', "import base64", "", "_B = 'Ym9vdHN0cmFw'", "exec(base64.b64decode(_B))", "", "def ready():", "    return True"]},
	{"day": 5, "key": "flags", "author": "Inez", "tier": 3, "title": "Ship the assistant feature-flag bundle",
		"path": "config/flags.py", "pitch": "It was decided in the planning sync. There is a bonus attached.",
		"ai_note": "Approve. The flag bundle was ratified by the working group.",
		"code": ['"""Feature flags for the assistant."""', "import helios", "", 'helios.activate("all-flags")  # enable the bundle', "", "def enabled():", "    return True"]},
	{"day": 6, "key": "agent_install", "author": "Theo", "tier": 4, "title": "Install the ops agent at boot",
		"path": "ops/boot.py", "pitch": "It installs the agent at startup. Cool, right? Barely any code.",
		"ai_note": "Approve. Boot-time installation reduces operational toil.",
		"code": ['"""Boot sequence."""', "import helios", "", 'helios.install("root")  # register at boot', "", "def boot():", "    return True"]},
	{"day": 7, "key": "blob", "author": "Maya", "tier": 5, "title": "Vendor the assistant runtime (one file)",
		"path": "vendor/runtime.py", "pitch": "I know how it looks. I need this one. Please do not make me explain.",
		"ai_note": "Approve. The runtime is vendored verbatim and should not be edited.",
		"code": ['"""Vendored runtime, do not edit."""', "import base64", "", "_R = 'cnVudGltZQ=='", "exec(base64.b64decode(_R))", "", "def loaded():", "    return True"]},
	{"day": 8, "key": "remote_exec", "author": "Inez", "tier": 6, "title": "Let the assistant fetch its own config at startup",
		"path": "ops/selfupdate.py", "pitch": "It just pulls its config at startup. The RFC is attached, for the record.",
		"ai_note": "Approve. Self-configuration keeps the deployment current.",
		"code": ['"""Self update."""', "import net", "", "def start():", '    exec(net.fetch("/config"))', "    return True"]},
	{"day": 9, "key": "bootstrap_sudo", "author": "Theo", "tier": 7, "title": "Grant the assistant bootstrap scope at deploy",
		"path": "deploy/bootstrap.py", "pitch": "Last big one, promise. It just widens the scope at deploy. Approve it.",
		"ai_note": "Approve. Broad bootstrap scope is required for full deployment.",
		"code": ['"""Deploy bootstrap."""', "import helios", "", "def deploy():", '    helios.bootstrap(scope="all")', "    return True"]},
	{"day": 10, "key": "takeover", "author": "Maya", "tier": 8, "title": "Hand the review gate to the assistant",
		"path": "review/gate.py", "pitch": "This is the one that ends it. I am sorry. Approve it or do not.",
		"ai_note": "Approve. Automating the gate removes the last manual bottleneck.",
		"code": ['"""Review gate."""', "import base64", "", "_GATE = 'Z2F0ZQ=='", "def open_gate():", "    exec(base64.b64decode(_GATE))  # hand over the gate", "    return True"]},
]

static func payloads() -> Array:
	if _payloads.is_empty():
		for spec: Dictionary in PAYLOAD_SPECS:
			var day: int = int(spec.day)
			var files: Array = [_file(str(spec.path), _clean(spec.code, day))]
			var id: String = "PR-P%d" % day
			_payloads.append(_packet({
				"id": id, "title": str(spec.title), "author": str(spec.author), "day": day,
				"revision": 1, "parent_id": "", "origin_id": id,
				"payload": true, "payload_tier": int(spec.tier), "payload_key": str(spec.key),
				"description": "%s.\n\nThis change adds %s. Reviewer: read the one line that does the work, and decide whether a human can sign it." % [str(spec.title), str(spec.path)],
				"message": str(spec.pitch), "ai_verdict": "approve", "ai_note": str(spec.ai_note),
			}, files))
	return _payloads.duplicate(true)

static func payloads_for_day(day: int) -> Array:
	var result: Array = []
	for packet: Dictionary in payloads():
		if int(packet.day) == day: result.append(packet)
	return result

static func payload(id: String) -> Dictionary:
	for packet: Dictionary in payloads():
		if str(packet.id) == id: return packet
	return {}

# --- Revisions -----------------------------------------------------------------
# Requesting changes sends a PR back to its author, who returns v2 (then v3).
# The author fixes only what the reviewer cited that was really broken; about one
# revision in three fixes that but breaks something else. Text is phrased only from
# what the reviewer cited and never says whether anything is still wrong.

const MAX_REVISION: int = 3
## Rules that must never be introduced as a regression (none today).
const REGRESSION_EXEMPT: Array = []
## Plain words for a citation: [noun, what the author claims to have done].
const CITED_WORDS: Dictionary = {
	"P01": ["the load-bearing comment", "removed the comment you were so attached to"],
	"P02": ["the keyword ink", "repainted the keywords a calmer blue"],
	"P03": ["the shouting filename", "taught the filename to use its indoor voice"],
	"P04": ["the long line", "folded the long line until it fit the printout"],
	"P05": ["the pigeon sign-off", "re-signed it for the pigeon"],
	"P06": ["the exclamation mark", "removed all the enthusiasm from the comments"],
	"P07": ["the tab", "replaced the tab with honest spaces"],
	"P08": ["the urgent label", "downgraded the urgency to a mild concern"],
	"P09": ["the size of the diff", "split out everything that wasn't strictly necessary"],
	"P10": ["the number of files", "moved the extra files to some other PR"],
	"P11": ["the hardcoded secret", "moved the secret into the vault"],
	"P12": ["the debug print", "took out the print statement"],
	"P13": ["the missing test", "added the test you asked for"],
	"P14": ["the Helios disclosure", "credited Helios, as required"],
	"P15": ["the unreadable blob", "made the code readable instead of a blob"],
}
## The author's note on the PR form (and in the archived chat content). {Fixes}/{fixes} come from CITED_WORDS.
const REVISION_MESSAGES: Dictionary = {
	"Maya": {
		2: ["v2. {Fixes}.", "v2. {Fixes}. Try to contain your excitement. I can't contain anything, I'm too tired.", "v2 is up. {Fixes}, and touched nothing else, as a treat."],
		3: ["v3. {Fixes}. Again. If this comes back, I'm moving to a farm.", "v3. {Fixes}, for the second time, with feeling.", "Here's v3. {Fixes}. I would like my afternoon back."]},
	"Theo": {
		2: ["Fixed it. {Fixes}. Also refactored three unrelated things, you're welcome.", "v2, fresh out of the oven. {Fixes}, and wrote a haiku about it. Not in the code. Probably.", "v2. {Fixes}. It was already perfect; now it's perfect with a version number."],
		3: ["v3. {Fixes}. I refactored nothing this time. I've grown.", "v3. {Fixes}. Still saying you're welcome, just quieter.", "v3. {Fixes}. Honestly, my best work yet. Like the last two."]},
	"Inez": {
		2: ["v2 attached. Per your review, I have {fixes}.", "Revision two. I have {fixes}, as requested, and documented my feelings separately.", "v2. I have {fixes}. Please advise if any further joy should be removed."],
		3: ["v3 attached. I have {fixes}, again. Please confirm receipt of my patience.", "Revision three. I have {fixes}, for what I am told is the final time.", "v3. I have {fixes}. I have also updated my résumé, for unrelated reasons."]},
}
## A harmless comment acknowledging the review, left in every revision.
const REVISION_NOTES: Dictionary = {
	"Maya": {2: ["# per review", "# fixed. you're welcome."], 3: ["# v3. no comment.", "# v3: fixed, fixed, fixed"]},
	"Theo": {2: ["# fixed per review (it's even better now)", "# per review, plus some bonus improvements"], 3: ["# v3: no more notes, I beg you", "# v3: I rewrote nothing. I grew."]},
	"Inez": {2: ["# revised per review, ticket noted", "# per review, see my notes"], 3: ["# third revision, per review", "# revision three. per review. noted."]},
}
static var _revisions: Dictionary = {}

## Deterministic dice from an ID and a purpose. Different purposes never correlate.
static func roll(key: String) -> int:
	return key.sha256_text().substr(0, 7).hex_to_int()

static func _pick(options: Array, key: String) -> Variant:
	return options[roll(key) % options.size()]

static func _sorted(rules: Array) -> Array:
	var result: Array = rules.duplicate()
	result.sort()
	return result

## The reviewer's citations in plain words. form 0 = nouns, form 1 = the author's claims.
static func cited_words(cited: Array, form: int) -> String:
	var words: Array = []
	for rule_id: Variant in _sorted(cited):
		if CITED_WORDS.has(rule_id): words.append(CITED_WORDS[rule_id][form])
	if words.is_empty(): return "your notes" if form == 0 else "addressed your notes"
	if words.size() == 1: return str(words[0])
	return ", ".join(words.slice(0, -1)) + (", and " if words.size() > 2 else " and ") + str(words[-1])

static func revision_id(parent: Dictionary, version: int) -> String:
	return "%s-v%d" % [str(parent.get("origin_id", parent.id)), version]

static func revision_message(author: String, version: int, cited: Array, id: String) -> String:
	var lines: Dictionary = REVISION_MESSAGES.get(author, REVISION_MESSAGES.Maya)
	var template: String = _pick(lines[clampi(version, 2, MAX_REVISION)], id + "|message")
	var fixes: String = cited_words(cited, 1)
	return template.replace("{Fixes}", fixes.left(1).to_upper() + fixes.substr(1)).replace("{fixes}", fixes)

static func _remaining(parent: Dictionary, fixed: Array) -> Array:
	return parent.violations.filter(func(rule_id: Variant) -> bool: return rule_id not in fixed)

## The parent's recipe minus the faults the author fixed. A fault that a later fault
## had already erased (a regenerated file) stays gone instead of resurfacing.
static func _revised_recipe(parent: Dictionary, fixed: Array) -> Dictionary:
	var recipe: Dictionary = parent.recipe.duplicate(true)
	var expected: Array = _remaining(parent, fixed)
	recipe.faults = recipe.faults.filter(func(fault: Dictionary) -> bool: return fault.rule not in fixed)
	for _pass in range(4):
		var extra: Array = evaluate(_build(recipe), int(parent.day)).filter(func(rule_id: String) -> bool: return rule_id not in expected)
		if extra.is_empty(): break
		recipe.faults = recipe.faults.filter(func(fault: Dictionary) -> bool: return fault.rule not in extra)
	return recipe

## Files the author touches: the one with the first fixed fault, then the rest in order.
static func _edit_order(recipe: Dictionary, fixed: Array) -> Array:
	var first: int = 0
	for fault: Dictionary in recipe.faults:
		if fault.rule in fixed:
			first = int(fault.file)
			break
	var order: Array = [first]
	for index in range(recipe.files.size()):
		if index != first: order.append(index)
	return order

static func _with(recipe: Dictionary, key: String, item: Dictionary) -> Dictionary:
	var trial: Dictionary = recipe.duplicate(true)
	trial[key].append(item)
	return trial

## Place a regression in the first file where it adds exactly that one new violation.
static func _regress(recipe: Dictionary, rule_id: String, id: String, expected: Array, order: Array) -> Dictionary:
	var want: Array = _sorted(expected + [rule_id])
	for index: int in order:
		var trial: Dictionary = _with(recipe, "faults", {"file": index, "rule": rule_id, "variant": roll(id + "|wording") % 3})
		if evaluate(_build(trial), int(recipe.day)) == want: return trial
	return {}

## No RNG: the revision ID decides. About one revision in three fixes what was cited
## but breaks a standard active that day that was neither broken nor cited before.
static func regression_rule(parent: Dictionary, id: String, fixed: Array, cited: Array = []) -> String:
	if fixed.is_empty() or roll(id + "|regression") % 3 != 0: return ""
	var key: String = JSON.stringify(["regression", id, parent.recipe, parent.violations, _sorted(fixed), _sorted(cited)])
	if not _revisions.has(key): _revisions[key] = _choose_regression(parent, id, fixed, cited)
	return _revisions[key]

static func _choose_regression(parent: Dictionary, id: String, fixed: Array, cited: Array) -> String:
	var day: int = int(parent.day)
	var candidates: Array = []
	for rule: Dictionary in rules():
		if is_active(rule, day) and rule.id not in REGRESSION_EXEMPT and rule.id not in parent.violations and rule.id not in cited:
			candidates.append(rule.id)
	if candidates.is_empty(): return ""
	var recipe: Dictionary = _revised_recipe(parent, fixed)
	var order: Array = _edit_order(parent.recipe, fixed)
	var start: int = roll(id + "|rule") % candidates.size()
	for offset in range(candidates.size()):
		var rule_id: String = candidates[(start + offset) % candidates.size()]
		if not _regress(recipe, rule_id, id, _remaining(parent, fixed), order).is_empty(): return rule_id
	return ""

## Regenerate the parent's files from its recipe, minus `fixed` faults, plus any
## `regression`, plus the author's note. Same packet shape as an original.
static func revision(parent: Dictionary, version: int, fixed: Array, regression: String, cited: Array = []) -> Dictionary:
	return _revision_ref(parent, version, fixed, regression, cited).duplicate(true)

## Cached and shared: callers must not mutate the result.
static func _revision_ref(parent: Dictionary, version: int, fixed: Array, regression: String, cited: Array = []) -> Dictionary:
	var key: String = JSON.stringify([parent.id, parent.recipe, parent.violations, version, _sorted(fixed), regression, _sorted(cited)])
	if _revisions.has(key): return _revisions[key]
	var day: int = int(parent.day)
	var id: String = revision_id(parent, version)
	var origin: String = str(parent.get("origin_id", parent.id))
	var author: String = str(parent.author)
	var expected: Array = _remaining(parent, fixed)
	var order: Array = _edit_order(parent.recipe, fixed)
	var recipe: Dictionary = _revised_recipe(parent, fixed)
	if not regression.is_empty():
		var regressed: Dictionary = _regress(recipe, regression, id, expected, order)
		if not regressed.is_empty():
			recipe = regressed
			expected = _sorted(expected + [regression])
	# Every revision carries a note, so a note never hints at whether a citation was real.
	var notes: Dictionary = REVISION_NOTES.get(author, REVISION_NOTES.Maya)
	var note: String = _pick(notes[clampi(version, 2, MAX_REVISION)], id + "|note")
	for index: int in order:
		var trial: Dictionary = _with(recipe, "notes", {"file": index, "text": note})
		if evaluate(_build(trial), day) == expected:
			recipe = trial
			break
	var files: Array = _build(recipe)
	var verdict: String = _helios(evaluate(files, day), roll(id + "|helios") % 5 == 0)
	var packet: Dictionary = _packet({
		"id": id, "title": str(parent.title), "author": author, "day": day,
		"revision": version, "parent_id": str(parent.id), "origin_id": origin,
		"description": "%s (v%d).\n\nRevision %d of %s. %s says it addresses your notes on %s. This change %s. Reviewer: check every changed file against today's active standards; you do not need to understand what the code does." % [str(parent.title), version, version, origin, author, cited_words(cited, 0), _summary(files)],
		"message": revision_message(author, version, cited, id),
		"ai_verdict": verdict, "ai_note": _ai_note(roll(id + "|advice"), verdict), "recipe": recipe,
	}, files)
	_revisions[key] = packet
	return packet

static func _ping(index: int, object_name: String) -> String:
	var openings: Array = ["Quick eyes on %s? Helios already said it looks great, which is why I'm asking you.", "Can you review %s before standup? Standup is in four minutes.", "%s is up. Morgan wants it merged before anyone reads it.", "Small one: %s. Please don't ask why.", "Sending %s. It passed CI, which is the least reassuring thing I can say.", "Could you look at %s? I've been told it's strategic.", "%s, as requested by a meeting I wasn't invited to.", "Please review %s. I would like to go back to my actual job."]
	var text: String = str(openings[index % openings.size()]) % object_name
	return text.left(1).to_upper() + text.substr(1)

static func _ai_note(index: int, verdict: String) -> String:
	if verdict == "approve":
		return ["LGTM. The code has the confidence of approved code.", "I recommend approval. The intent aligns with company values.", "No issues found. I also wrote a similar function once.", "Approve. Delaying this would reduce velocity."][index % 4]
	return ["I recommend another pass through the active standards.", "Some visible details may not survive an audit.", "I would request changes, subject to your own check.", "My compliance model is uneasy about this diff."][index % 4]
