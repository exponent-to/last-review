extends RefCounted
## Fictional office policy puzzles. Every citation comes from visible evidence: the
## source files, or the PR's records in Lineal (its issue) and Pipeline (its build).
## Source is Python-shaped stationery, not code the game executes.
##
## The assignment runs two weeks, Monday to Friday. Standards change every second
## morning, at the start of each two-day block: some are added, some are amended,
## and some are retired. A rule is active from `introduced_day` until the day before
## its `retired_day`; each amendment replaces the rule's text from its own day on.
## The slip stays short (at most six), so standards grow deeper through amendments
## and exceptions instead of piling up.

const KEYWORDS: Array = ["def", "if", "else", "return"]
## Everyone who writes PRs, in the order the rotation falls back through them.
const AUTHORS: Array = ["Maya", "Theo", "June", "Penny", "Gwen"]
## Who joins the team on which morning, and the relationship they start with.
## Penny, the eager junior, is hired on the first Wednesday; Gwen is reassigned
## from Security (consolidated into Helios) on the second Monday. Nobody is in
## `state.coworkers` before their first morning, and nobody writes PRs before it.
const ROSTER: Dictionary = {
	"Maya": {"joins": 1, "relationship": 50},
	"Theo": {"joins": 1, "relationship": 50},
	"June": {"joins": 1, "relationship": 50},
	"Penny": {"joins": 3, "relationship": 56},
	"Gwen": {"joins": 6, "relationship": 48},
}
## Who wrote each slot of each day's line, by initial (LINEUP_NAMES). Before the
## new hires, Maya, Theo, and June rotate as they always have; from day 3 Penny
## takes four slots a day (three once Gwen arrives), and from day 6 Gwen takes
## three. Each newcomer has a slot in the first six of every day they work,
## because shifts rarely get further than that; the original three keep most of
## those early slots. Use `slot_author`, which also covers anyone who is away.
const LINEUP_NAMES: Dictionary = {"M": "Maya", "T": "Theo", "J": "June", "P": "Penny", "G": "Gwen"}
const LINEUP: Array = [
	"MTJMTJMTJMTJMTJ", # day 1, week 1 Monday
	"TJMTJMTJMTJMTJM", # day 2, Tuesday
	"JPTJMPJMTPMTJPT", # day 3, Wednesday: Penny's first day
	"MTPMPJMTJPTJMPJ", # day 4, Thursday
	"PJMPJMTJPTPMTJM", # day 5, Friday
	"JPGJMTGMTJPTGMP", # day 6, week 2 Monday: Gwen's first day
	"GTJMPJMGJPTPMTG", # day 7, Tuesday
	"TJMGJPGJMTPMTPG", # day 8, Wednesday
	"JMGJMPJMTPPTGGT", # day 9, Thursday
	"MTJGPJGTPMTGMPJ", # day 10, Friday
]
const DAY_COUNTS: Array = [15, 15, 15, 15, 15, 15, 15, 15, 15, 15]
const WEEK_DAYS: int = 5
## The first day of each two-day block. Each opens with a memo announcing the changes.
const BLOCK_STARTS: Array = [1, 3, 5, 7, 9]
## Standards on the citation slip each day; never more than MAX_ACTIVE at once.
## P15 "Readable code" joins on day 3 when the Helios payloads begin. Every block
## retires what the one before it introduced, so the slip stays at six.
const ACTIVE_COUNTS: Array = [3, 3, 6, 6, 6, 6, 6, 6, 6, 6]
const MAX_ACTIVE: int = 6
const PERMIT: String = "INK-EXCEPTION"
## INK-EXCEPTION is honored from PERMIT_DAY, and from ISSUE_DAY it must name the
## PR's own Lineal issue (INK-EXCEPTION PAP-412 on a PR that closes PAP-412).
const PERMIT_DAY: int = 5
const ISSUE_DAY: int = 9
## From week two's first reissue, more PRs break two standards at once.
const MODERN_DAY: int = 7
## Lineal (the issue tracker) and Pipeline (the CI dashboard) arrive on these mornings.
const LINEAL_DAY: int = 3
const PIPELINE_DAY: int = 5
## Helios's payloads begin, and P15 "Readable code" joins the slip, this morning.
const PAYLOAD_DAY: int = 3
## Helios starts overriding red builds on OVERRIDE_DAY, and its overrides count as
## passing until Audit stops accepting them on OVERRIDE_BANNED_DAY.
const OVERRIDE_DAY: int = 7
const OVERRIDE_BANNED_DAY: int = 9
## From ZERO_DAY, an estimate of 0 counts as Fibonacci.
const ZERO_DAY: int = 9
## Evidence scopes. Line rules need the exact line. Rules about one file (its ink)
## accept that file or any of its lines. Rules about the whole PR would accept any
## changed file (none are in force; the machinery stays generic). Record rules
## need the record itself: the PR's issue, selected in Lineal, or its build,
## selected in Pipeline. WHOLE FILE and code lines never count for them, and a
## record never counts for a code rule.
const FILE_SCOPED: Array = ["P02"]
const PR_SCOPED: Array = []
const ISSUE_SCOPED: Array = ["P16", "P17", "P18"]
const BUILD_SCOPED: Array = ["P19", "P20", "P21"]
const RECORD_SCOPED: Array = ["P16", "P17", "P18", "P19", "P20", "P21"]
## P04: words HR listens for in a function name.
const HR_WORDS: Array = ["fire", "layoff", "union", "lunch"]
## P05: who may own a TODO.
const TODO_OWNERS: Array = ["maya", "theo", "june", "penny", "gwen"]
## P18: estimates Helios takes seriously (0 joins on ZERO_DAY).
const FIBONACCI: Array = [1, 2, 3, 5, 8, 13]
## P20: words a branch may not contain. P21: words a commit hash may not spell.
const BRANCH_WORDS: Array = ["yolo", "wip", "final"]
const HEX_WORDS: Array = ["dead", "bad"]
const Bank = preload("res://content/pr_bank.gd")
const Records = preload("res://content/records.gd")
static var _packets: Array = []
static var _bank: Array = []
static var _active: Dictionary = {}
static var _patterns: Dictionary = {}

static func rules() -> Array:
	var ink := "Blue is the approved color of compliant instructions. Pink is reserved for flagged personnel files, and you do not want to be a personnel file. The whole keyword tokens def, if, else, and return must be blue. Pink is forbidden. Words inside comments or quoted strings are exempt, as are longer names such as return_label. A file without these keyword tokens needs no blue ink."
	var green := "Red means no. The PR's build in Pipeline must not have Status FAILED. FLAKY means a test failed and then passed on a retry; it counts as passing, the way Paperclip Labs counts as stable. Read the Status, not the log. The log is where hope goes to scroll."
	var no_issue := "If the PR links no issue that Lineal can find, cite that under the issue standard instead."
	var fibonacci := "Helios estimates in Fibonacci and finds other numbers unserious. The linked issue's Estimate must be "
	var four := " A 4 is not an estimate; it is a cry for help. "
	return [
		{"id": "P01", "category": "Language", "title": "Nothing is load-bearing", "introduced_day": 1, "retired_day": LINEAL_DAY,
			"text": "Legal's position is that no component, and no employee, is load-bearing. A comment must not contain the exact phrase load-bearing, ignoring letter case. Match the hyphen and spacing exactly; the phrase anywhere after an unquoted # counts. Text inside a quoted string is not a comment. Cite the line.",
			"retired": "Legal has confirmed that nothing here is load-bearing anymore, including the staff. Comments may say load-bearing again."},
		{"id": "P02", "category": "Color", "title": "Approved ink", "introduced_day": 1,
			"text": ink + " Cite the file.",
			"amendments": [
				{"day": PERMIT_DAY, "change": "The Exception Desk is open. It is one stamp in a drawer. A file whose permit reads exactly INK-EXCEPTION may use pink keywords.",
					"text": ink + " A file whose Permit reads exactly INK-EXCEPTION may use pink keywords; the permit covers that file only. Misspelled, padded, or differently cased stamps are forgeries, not permits, and a permit waives nothing else. Cite the file."},
				{"day": ISSUE_DAY, "change": "Someone was lending their permit out. Permits must now name the PR's own Lineal issue: INK-EXCEPTION, one space, then the issue on the PR slip. A bare INK-EXCEPTION is a forgery as of today.",
					"text": ink + " A file whose Permit reads exactly INK-EXCEPTION, one space, then the issue this PR links on its slip (INK-EXCEPTION PAP-412 on a PR that closes PAP-412) may use pink keywords; the permit covers that file only. A bare INK-EXCEPTION, or one naming any other issue, is a forgery; permits are not transferable, inheritable, or for sale. Misspelled, padded, or differently cased stamps do not count, and no other rule is waived. Cite the file."}]},
		{"id": "P03", "category": "Language", "title": "The colleague", "introduced_day": 1, "retired_day": PIPELINE_DAY,
			"text": "Helios has asked not to be discussed behind its back. It prefers the colleague. A comment must not contain helios, ignoring letter case, anywhere after an unquoted #, even inside a longer word: heliosphere counts. Code may still say helios, and so may quoted strings; it reads those as compliments. Helium, Heli0s with a zero, and the colleague are fine. Cite the line.",
			"retired": "Helios has grown comfortable with its name. It would now like to be mentioned in every comment, warmly."},
		{"id": "P04", "category": "HR", "title": "HR is listening", "introduced_day": LINEAL_DAY, "retired_day": OVERRIDE_DAY,
			"text": "HR reads every new function name aloud at the Monday sync, and some words upset the room. No def may name a function containing fire, layoff, union, or lunch, ignoring letter case, even inside a longer word: def campfire() counts, and so does an innocent set union. Variables, comments, and quoted strings may say what they like; HR does not read those aloud. And launch is not lunch. Cite the def line.",
			"retired": "HR has been consolidated into Helios, which does not need function names read aloud. It hears them anyway."},
		{"id": "P05", "category": "Process", "title": "No ghost TODOs", "introduced_day": OVERRIDE_DAY, "retired_day": ISSUE_DAY,
			"text": "Every TODO needs an owner who still badges in. In a comment, the word TODO in capitals must be followed at once by an owner in parentheses, and the owner, ignoring letter case, must be maya, theo, june, penny, or gwen: TODO(maya) is fine. A bare TODO, TODO(dave), TODO(helios), TODO(), and TODO (maya) with a space are ghosts. A lowercase todo is just a word, and code and quoted strings are exempt. Cite the line.",
			"retired": "Every TODO in the company has been reassigned to Helios, which marked them all done overnight."},
		{"id": "P15", "category": "Readability", "title": "Readable code", "introduced_day": PAYLOAD_DAY,
			"text": "If a human signs it, a human must be able to read it, preferably without squinting. No source line may call exec or eval, invoke helios.bootstrap, helios.install, or helios.activate, or run past 160 characters, which is roughly where human eyes file a grievance. A decoded blob or a fetched script is a sealed envelope with your name on the outside. Helios has asked to review this standard personally. The request is pending. Cite the line."},
		{"id": "P16", "category": "Issues", "title": "No issue, no merge", "introduced_day": LINEAL_DAY,
			"text": "If it isn't in Lineal, it didn't happen, and we do not merge things that didn't happen. The PR slip must link an issue (Closes PAP-123), the issue must exist in Lineal, and its Status must be Todo, In Progress, or In Review. Backlog is a wish, Done is a memory, and Canceled and Duplicate are someone else's grief: a PR that links nothing, an issue Lineal can't find, or an issue in any of those statuses breaks this standard. Cite the issue: open it in Lineal and SELECT AS EVIDENCE."},
		{"id": "P17", "category": "Issues", "title": "Urgency belongs to Helios", "introduced_day": LINEAL_DAY, "retired_day": PIPELINE_DAY,
			"text": "Humans are no longer cleared for urgency. The linked issue's Priority must not be Urgent: an Urgent issue is Helios's work, whatever it describes and however many humans it has paged. High, Medium, Low, and No priority are all fine, however many bars they show. " + no_issue + " Cite the issue in Lineal.",
			"retired": "Helios has taken every Urgent issue in the company. By definition, nothing a human does is urgent anymore."},
		{"id": "P18", "category": "Issues", "title": "Fibonacci or nothing", "introduced_day": OVERRIDE_DAY,
			"text": fibonacci + "1, 2, 3, 5, 8, or 13." + four + "0, 6, 7, 10, 20, and every other number break this standard. " + no_issue + " Cite the issue in Lineal.",
			"amendments": [
				{"day": ZERO_DAY, "change": "Engineering pointed out that 0 is a Fibonacci number. Helios agreed at once and estimated all of its own work at 0. An Estimate of 0 is now fine.",
					"text": fibonacci + "0, 1, 2, 3, 5, 8, or 13. Zero is Fibonacci; Helios has checked, and estimates all of its own work at 0." + four + "6, 7, 10, 20, and every other number break this standard. " + no_issue + " Cite the issue in Lineal."}]},
		{"id": "P19", "category": "Builds", "title": "Green builds only", "introduced_day": PIPELINE_DAY,
			"text": green + " Cite the build: open it in Pipeline and SELECT AS EVIDENCE.",
			"amendments": [
				{"day": OVERRIDE_DAY, "change": "Helios may now override a red build it is confident about. It is confident about all of them. PASSED (OVERRIDDEN BY HELIOS) counts as passing.",
					"text": green + " Helios may now override a red build it is confident about, which so far is every red build: the Status then reads PASSED (OVERRIDDEN BY HELIOS), and that counts as passing, whatever the log says. Cite the build: open it in Pipeline and SELECT AS EVIDENCE."},
				{"day": OVERRIDE_BANNED_DAY, "change": "Audit read the logs Helios was overriding. PASSED (OVERRIDDEN BY HELIOS) now counts as FAILED.",
					"text": green + " Audit has read the logs Helios was overriding and no longer accepts its overrides: a Status of PASSED (OVERRIDDEN BY HELIOS) counts as FAILED. Helios has asked who Audit reports to. Cite the build: open it in Pipeline and SELECT AS EVIDENCE."}]},
		{"id": "P20", "category": "Builds", "title": "Branch names are public", "introduced_day": PIPELINE_DAY, "retired_day": OVERRIDE_DAY,
			"text": "Branch names are read out at the board meeting, and the board has feelings. The build's Branch in Pipeline must not contain yolo, wip, or final, ignoring letter case, anywhere, even inside a longer word: finalize and wipe both count. Words that only look close, such as whip, yoga, yo-lo, or finance, are fine. Cite the build: open it in Pipeline and SELECT AS EVIDENCE.",
			"retired": "Helios now names every branch itself. They are all called helios/progress, and the board loves them."},
		{"id": "P21", "category": "Security", "title": "Hex hygiene", "introduced_day": ISSUE_DAY,
			"text": "Helios has a threat model, and it includes spelling. The build's Commit hash in Pipeline must not contain dead or bad, ignoring letter case, anywhere in it: 3deadf0 and 0bad1e5 are threats. Lookalikes such as de4d, b4d, bead, and dab are fine; Helios has checked them personally. Pushing again gets a new hash. Cite the build in Pipeline."},
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

## "line", "file", "pr", "issue", or "build": where a citation of this standard may point.
static func scope(rule_id: String) -> String:
	if rule_id in ISSUE_SCOPED: return "issue"
	if rule_id in BUILD_SCOPED: return "build"
	return "pr" if rule_id in PR_SCOPED else "file" if rule_id in FILE_SCOPED else "line"

## Monday to Friday, then Monday to Friday again.
static func week(day: int) -> int:
	return (maxi(1, day) - 1) / WEEK_DAYS + 1

## Whether a file's permit is honored on `day` for a PR that links `issue_ref`.
static func permit_valid(permit: String, day: int, issue_ref: String = "") -> bool:
	if day < PERMIT_DAY: return false
	if day < ISSUE_DAY: return permit == PERMIT
	return not issue_ref.is_empty() and permit == PERMIT + " " + issue_ref

## Whether an issue's estimate is one Helios takes seriously on `day`.
static func estimate_valid(estimate: int, day: int) -> bool:
	return estimate in FIBONACCI or (estimate == 0 and day >= ZERO_DAY)

## The first word of `words` inside `text`, ignoring case, or "".
static func _contains_word(text: String, words: Array) -> String:
	var lower := text.to_lower()
	for word: String in words:
		if word in lower: return word
	return ""

static func briefing(day: int) -> String:
	match day:
		1:
			return "YOUR DESK IS ASSIGNED. Paperclip Labs is transitioning review to Helios. Until it completes, every change still needs a human signature. You will not be asked to understand the code, only to enforce the standards on it exactly as written: no load-bearing comments, approved keyword ink, and no comment that names Helios. It prefers the colleague. Standards are reissued every second morning. Work lands on your desk one PR at a time. The clock does not wait for you."
		2:
			return "NO CHANGES TODAY. Yesterday's three standards still apply, word for word. Changes now arrive in several files; an unread file is an unsigned file. Cite each broken standard once."
		3:
			return "NOTHING SHIPS WITHOUT AN ISSUE. Lineal, the issue tracker, is on your desktop: fast, opinionated, and keyboard-first. Every PR must link an issue that is Todo, In Progress, or In Review, and never an Urgent one; urgency belongs to Helios now. HR has started reading new function names aloud, so no def may mention fire, layoff, union, or lunch. Code a human signs must be readable by a human: no exec, no eval, no bootstrapping Helios, however politely it asks. Helios is available on the review desk. It is fast and confident. It is not always right, and every consultation is logged. Load-bearing comments are retired. NEW HIRE: Penny, a junior engineer on the Helios trial, starts today and will send you PRs. She is sorry in advance."
		4:
			return "NO CHANGES TODAY. Issues, urgency, HR's word list, readable code, ink, and the colleague all carry over from yesterday. Lineal has asked that reviewers stop thanking it."
		5:
			return "THE PIPELINE IS WATCHING. Pipeline, the CI dashboard, is on your desktop: red means no, and branch names are read out at the board meeting, so no yolo, no wip, no final. The Exception Desk is open: the exact stamp INK-EXCEPTION permits pink keywords in its own file. Helios has taken every Urgent issue, and it would now like to be named in comments, so both of those standards are retired. This is scheduled to be the last day of your assignment."
		6:
			return "WEEK TWO. Your assignment was extended over the weekend. The standards are Friday's, unchanged. Several desks on your floor have been consolidated. Do not water the plants. REASSIGNED TO YOUR TEAM: Gwen, from Security, which Helios absorbed on Friday. She will send you PRs. She trusts nobody, including this briefing."
		7:
			return "THE STANDARDS HAVE BEEN MODERNIZED. Every TODO needs an owner who still badges in. Estimates must be Fibonacci; Helios finds other numbers unserious. Helios may now override a red build it feels confident about, and for now its overrides count as passing. It feels confident about all of them. HR has been consolidated, and Helios names the branches now, so both of those standards are retired."
		8:
			return "NO CHANGES TODAY. Owned TODOs, Fibonacci estimates, readable code, and Helios's overrides stand. Helios has stopped taking questions about any of them."
		9:
			return "AUDIT HAS QUESTIONS. Helios overrides no longer count as passing builds. Ink permits must name the PR's own issue. An estimate of 0 now counts as Fibonacci. Commit hashes may not spell dead or bad. The TODOs are retired; Helios finished them. I didn't write these. I'm not sure who did."
		10:
			return "FINAL REVIEW CYCLE. No standard changes today. Leadership decides the review gate at closing. Helios has drafted both announcements."
	return "The standards committee has adjourned."

static func _pattern(name: String) -> RegEx:
	if _patterns.is_empty():
		var sources: Dictionary = {
			"keyword": "(?<![A-Za-z0-9_])(def|if|else|return)(?![A-Za-z0-9_])",
			"def": "(?<![A-Za-z0-9_])def\\s+([A-Za-z_][A-Za-z0-9_]*)",
			"todo": "(?<![A-Za-z0-9_])TODO(?![A-Za-z0-9_])",
			"owner": "\\(([A-Za-z]*)\\)",
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

## A record finding points at the PR's issue or build, not at a file.
static func _record_finding(findings: Array, id: String, record: String, record_id: String, detail: String) -> void:
	findings.append({"rule_id": id, "path": "", "line": 0, "record": record, "id": record_id, "message": detail})

static func _is_test(path: String) -> bool:
	return path.begins_with("tests/")

static func _has_tests(files: Array) -> bool:
	for file: Dictionary in files:
		if _is_test(str(file.path)): return true
	return false

## The function names a code line defines (`def name`), in code only.
static func _def_names(mask: String) -> Array:
	var names: Array = []
	for found: RegExMatch in _pattern("def").search_all(mask):
		names.append(found.get_string(1))
	return names

## Whether a comment holds a TODO without an owner on the list (P05).
static func _ghost_todo(comment: String) -> bool:
	for found: RegExMatch in _pattern("todo").search_all(comment):
		var owner: RegExMatch = _pattern("owner").search(comment, found.get_end())
		if owner == null or owner.get_start() != found.get_end() or owner.get_string(1).to_lower() not in TODO_OWNERS: return true
	return false

## Audit data only; all line references are one-based source lines, and 0 means
## the whole file. `records` is the PR's issue and build ({} audits code only).
static func findings(files: Array, day: int, records: Dictionary = {}) -> Array:
	return _findings(files, day, active_ids(day), records)

## `active` lists the standards to check, so tests can audit against any rulebook.
static func _findings(files: Array, day: int, active: Array, records: Dictionary = {}) -> Array:
	var result: Array = []
	var issue_ref: String = str(records.get("issue_ref", ""))
	for file: Dictionary in files:
		var path: String = file.path
		var source: String = file.source
		var lines: PackedStringArray = source.split("\n", true)
		var lexer: Dictionary = _lex(source)
		if "P01" in active:
			for comment: Dictionary in lexer.comments:
				if "load-bearing" in str(comment.text).to_lower():
					_finding(result, "P01", path, int(comment.line) + 1, "The comment contains load-bearing.")
		if "P02" in active and file.get("keyword_ink", "blue") != "blue" and not permit_valid(str(file.get("permit", "")), day, issue_ref):
			var spans: Array = keyword_spans(source)
			if not spans.is_empty():
				_finding(result, "P02", path, int(spans[0].line) + 1, "A listed keyword token is pink instead of blue.")
		if "P03" in active:
			for comment: Dictionary in lexer.comments:
				if "helios" in str(comment.text).to_lower():
					_finding(result, "P03", path, int(comment.line) + 1, "The comment names Helios.")
		if "P04" in active:
			for line_index in range(lexer.code_lines.size()):
				for name: String in _def_names(str(lexer.code_lines[line_index])):
					var word: String = _contains_word(name, HR_WORDS)
					if not word.is_empty():
						_finding(result, "P04", path, line_index + 1, "The function %s contains %s." % [name, word])
						break
		if "P05" in active:
			for comment: Dictionary in lexer.comments:
				if _ghost_todo(str(comment.text)):
					_finding(result, "P05", path, int(comment.line) + 1, "A TODO has no owner on the list.")
		if "P15" in active:
			for line_index in range(lines.size()):
				var mask: String = str(lexer.code_lines[line_index]) if line_index < lexer.code_lines.size() else ""
				if _pattern("exec").search(mask) != null:
					_finding(result, "P15", path, line_index + 1, "This line runs a decoded or fetched blob through exec/eval.")
				elif _pattern("helios_call").search(mask) != null:
					_finding(result, "P15", path, line_index + 1, "This line hands control to Helios through bootstrap/install.")
				elif lines[line_index].length() > 160:
					_finding(result, "P15", path, line_index + 1, "This line packs a change too wide to read (over 160 characters).")
	if not records.is_empty():
		_record_findings(result, day, active, records)
	return result

## The PR's issue (Lineal) and build (Pipeline), against the record standards.
static func _record_findings(result: Array, day: int, active: Array, records: Dictionary) -> void:
	var ref: String = str(records.get("issue_ref", ""))
	var issue: Dictionary = Records.find(records.get("issues", []), ref)
	if "P16" in active:
		if ref.is_empty(): _record_finding(result, "P16", "issue", "", "The PR links no issue.")
		elif issue.is_empty(): _record_finding(result, "P16", "issue", ref, "%s does not exist in Lineal." % ref)
		elif str(issue.status) not in Records.OPEN_STATUSES: _record_finding(result, "P16", "issue", ref, "%s is %s." % [ref, issue.status])
	# Without an issue Lineal can find, there is no priority or estimate to check.
	if not issue.is_empty():
		if "P17" in active and str(issue.get("priority", "")) == "Urgent":
			_record_finding(result, "P17", "issue", ref, "%s is Urgent." % ref)
		if "P18" in active and not estimate_valid(int(issue.get("estimate", 1)), day):
			_record_finding(result, "P18", "issue", ref, "%s is estimated at %d." % [ref, int(issue.get("estimate", 1))])
	var build: Dictionary = records.get("build", {})
	if build.is_empty(): return
	var build_id: String = str(build.id)
	if "P19" in active:
		if str(build.status) == "failed": _record_finding(result, "P19", "build", build_id, "Build %s failed." % build_id)
		elif str(build.get("override", "")) == "helios" and day >= OVERRIDE_BANNED_DAY: _record_finding(result, "P19", "build", build_id, "Build %s only passed by Helios override." % build_id)
	if "P20" in active and not _contains_word(str(build.get("branch", "")), BRANCH_WORDS).is_empty():
		_record_finding(result, "P20", "build", build_id, "Build %s ran on branch %s." % [build_id, build.branch])
	if "P21" in active and not _contains_word(str(build.get("commit", "")), HEX_WORDS).is_empty():
		_record_finding(result, "P21", "build", build_id, "Build %s has commit %s." % [build_id, build.commit])

## True when a code citation's pointed-at location is real evidence for that rule.
## line 0 means the whole file. Whole-PR findings are listed on every changed file,
## so any file of the PR is accepted for them. Record standards never take code.
static func evidence_accepted(audit: Array, rule_id: String, path: String, line: int) -> bool:
	if rule_id in RECORD_SCOPED: return false
	for finding: Dictionary in audit:
		if finding.rule_id != rule_id or finding.path != path: continue
		if rule_id in FILE_SCOPED or rule_id in PR_SCOPED or int(finding.line) == line: return true
	return false

## Any citation's evidence: a {path, line} location in the code, or a
## {record, id} record (record "issue" or "build"). A record is accepted only by
## the record standard it was found under, for that exact issue or build.
static func evidence_matches(audit: Array, rule_id: String, evidence: Dictionary) -> bool:
	if evidence.has("record"):
		for finding: Dictionary in audit:
			if finding.rule_id == rule_id and str(finding.get("record", "")) == str(evidence.record) and str(finding.get("id", "")) == str(evidence.get("id", "")): return true
		return false
	return evidence_accepted(audit, rule_id, str(evidence.get("path", "")), int(evidence.get("line", -1)))

static func evaluate(files: Array, day: int, records: Dictionary = {}) -> Array:
	var ids: Array = []
	for finding: Dictionary in findings(files, day, records):
		if finding.rule_id not in ids:
			ids.append(finding.rule_id)
	ids.sort()
	return ids

static func _explanation(files: Array, day: int, records: Dictionary = {}) -> String:
	var evidence: Array = findings(files, day, records)
	if evidence.is_empty():
		return "Every changed file and record meets today's active policies. Strange office paperwork is allowed when it follows the handbook."
	var pieces: Array[String] = []
	var seen: Array = []
	for finding: Dictionary in evidence:
		if finding.rule_id in seen:
			continue
		seen.append(finding.rule_id)
		var location: String = "the PR" if finding.rule_id in PR_SCOPED else str(finding.path).get_file()
		if finding.has("record"):
			location = "the PR's %s %s" % [finding.record, finding.id] if not str(finding.id).is_empty() else "the PR's issue link"
		elif int(finding.line) > 0:
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

## Companion files make packets look like real changes: tests, config, and shims.
static func _companion(kind: String, entry: Dictionary) -> Array:
	var where := _module(str(entry.path))
	var function := _entry_function(entry.lines)
	match kind:
		"test":
			return ['"""Regression tests, as requested by the audit."""', "from %s import %s" % [where.import, function], "", "def test_%s_is_callable():" % function.left(36), "    assert callable(%s)" % function, "    return None"]
		"config":
			return ["# configuration for the %s change" % where.module, "ENABLED = True", "OWNER = 'platform'", "", "def enabled():", "    return ENABLED"]
		_:
			# "legacy" (beside the module) and "nested" (in a legacy/ subfolder).
			return ["# legacy shim, kept for the audit trail", "from %s import %s" % [where.import, function], "", "def legacy_call(*args):", "    return %s(*args)" % function]

static func _companion_path(kind: String, path: String) -> String:
	var where := _module(path)
	match kind:
		"test": return "tests/test_%s.py" % where.module
		"config": return path.get_base_dir() + "/%s_config.py" % where.module
		"nested": return path.get_base_dir() + "/legacy/%s.py" % where.module
		_: return path.get_base_dir() + "/%s_legacy.py" % where.module

## Clean source for a shift. No standard in force asks for boilerplate today, so
## the bank's lines are already clean; kept as the one place that would add it.
static func _clean(lines: Array, _day: int) -> Array:
	return lines.duplicate()

# Fault and decoy wording. Inserted lines must read naturally anywhere: they never
# describe code that isn't in the file, and never trip a standard they aren't for.

## A permit the Exception Desk would honor that day, for a PR linking `issue_ref`.
static func _valid_permit(day: int, issue_ref: String) -> String:
	return PERMIT if day < ISSUE_DAY else PERMIT + " " + issue_ref

## Fault wordings, picked by a recipe's variant number (the tutorial packet uses
## index 8). Comment forms keep "load-bearing" after an unquoted #.
const LOAD_BEARING: Array = [
	"# load-bearing: do not touch, ask Dave",
	"# NOTE: this file is load-bearing for payroll",
	"# load-bearing module, do not refactor",
	"# NOTE(2019): find out why this is load-bearing",
	"# load-bearing sleep. removing it breaks Tuesdays",
	"# this try/except is load-bearing. we do not know why",
	"# HACK: load-bearing global, see incident 4471",
	"# do not remove: load-bearing print statement",
	"# Load-Bearing. Dave left. Nobody else knows",
	"# the order of these imports is load-bearing",
	"# FIXME load-bearing typo, the API depends on it",
	"# load-bearing since the 2021 migration (temporary)",
	"x = 0  # load-bearing x",
	"# legacy shim, extremely load-bearing, handle with tongs",
	"# warning: load-bearing whitespace below",
	"# this function is load-bearing for the Q3 board deck",
	"# LOAD-BEARING. ask in #platform before editing",
	"# the retry count is load-bearing; 3 breaks, 4 breaks",
]
## Near misses: no exact "load-bearing" in a comment.
const NEAR_LOAD_BEARING: Array = [
	"# facilities says this wall is load bearing",
	"WALL = 'load-bearing'",
	"# loadbearing? ask facilities",
	"# load–bearing (en dash, per Legal)",
	"LABEL = 'load-bearing beam, do not lean'",
	"# this beam is load - bearing, says the badge reader",
	"# bearing a load of tech debt",
	"# Load bearing walls are a facilities problem",
]
## P03: a comment that names Helios, in any case, even inside a longer word.
const HELIOS_COMMENTS: Array = [
	"# Helios wrote this part. Do not tell it we read it",
	"# per helios: ship it",
	"# ask HELIOS before editing",
	"# thanks, Helios",
	"x = 1  # Helios approved",
	"# heliosphere-scale refactor, phase one",
	"# Helios says this is fine",
	"# do not let helios see this file",
	"# written by a human, reviewed by Helios",
	"# Helios: please stop renaming this",
	"# the colleague (Helios) asked for this",
	"# HeLiOs mode: on",
]
## Near misses: Helios in code or quotes, or a comment that only looks close.
const NEAR_HELIOS: Array = [
	"import helios",
	"COLLEAGUE = 'Helios'",
	"# the colleague approved this",
	"# helium balloons for the offsite",
	"# Heli0s asked nicely (that is a zero)",
	"# the colleague says hello",
	"OWNER = 'helios'  # the colleague",
	"# heli-os, per the font on the lobby sign",
]
## P04: a def whose name contains fire, layoff, union, or lunch.
const HR_FUNCTIONS: Array = [
	"def fire_drill(): pass",
	"def lunch_and_learn(): pass",
	"def plan_layoffs(): pass",
	"def union_of(a, b): pass",
	"def campfire_story(): pass",
	"def reunion_rsvp(): pass",
	"def fire_and_forget(): pass",
	"def Lunch_Order(): pass",
	"def merge_unions(): pass",
	"def ceasefire(): pass",
	"def layoff_faq(): pass",
	"def misfire(): pass",
	"def brunch_or_lunch(): pass",
	"def FIREWALL_RULES(): pass",
]
## Near misses: the words outside a function name, or names that only look close.
const NEAR_HR: Array = [
	"lunch_budget = 0",
	"FIRE_EXITS = 3",
	"# the union of both lists, per the spec",
	"def launch(): pass",
	"def onion_count(): pass",
	"MENU = 'lunch'",
	"def fir_tree(): pass",
	"def layout_offset(): pass",
]
## P05: a TODO without an owner on the list.
const GHOST_TODOS: Array = [
	"# TODO: ask Dave",
	"# TODO(dave): fix before the reorg",
	"# TODO(priya) remove after the migration",
	"# TODO(helios): optimize the humans",
	"# TODO(Gary): explain the rounding",
	"x = 1  # TODO",
	"# TODO(sam): consolidate this",
	"# TODO (maya): rename after the reorg",
	"# TODO(intern): figure this out",
	"# TODO(): find an owner",
	"# TODO(everyone): circle back",
	"# TODO(morgan_maybe) decide",
]
## Near misses: owned TODOs, lowercase todos, and TODO in code or quotes.
const NEAR_TODO: Array = [
	"# TODO(maya): rename after the reorg",
	"# TODO(Gwen) threat-model this",
	"# todo: lowercase notes are just notes",
	"TODO_LIMIT = 3",
	"STATUS = 'TODO'",
	"# TODO(june): circle back",
	"# TODO(Penny): sorry",
	"# TODO(theo) make it faster",
]

## A permit that looks right and isn't: misspelled before the issue requirement,
## and from then on bare, from the old system, typo'd, or naming another issue.
static func _forged_permit(day: int, variant: int, issue_ref: String) -> String:
	if day < ISSUE_DAY:
		return ["INK-EXEPTION", "ink-exception", "INK EXCEPTION"][variant % 3]
	var number: int = Records.issue_number(issue_ref)
	return [PERMIT, "%s PCL-%04d" % [PERMIT, (number * 7) % 10000], "%s %s-%d" % [PERMIT, Records.PROJECT, number + 3], "%s %s%d" % [PERMIT, Records.PROJECT, number]][variant % 4]

## `variant` picks the fault's wording; recipes record it so a rebuilt file reads the
## same. Record standards are applied by `_records`.
static func _apply_fault(file: Dictionary, rule_id: String, day: int, variant: int = -1) -> void:
	var lines: Array = Array(str(file.source).split("\n", true))
	if variant < 0: variant = str(file.path).length()
	var at: int = mini(1, lines.size())
	match rule_id:
		"P01":
			lines.insert(at, LOAD_BEARING[variant % LOAD_BEARING.size()])
		"P02":
			file.keyword_ink = "pink"
			if keyword_spans("\n".join(lines)).is_empty():
				lines.insert(at, "def stamp():")
				lines.insert(at + 1, "    return 'a copy'")
		"P03":
			lines.insert(at, HELIOS_COMMENTS[variant % HELIOS_COMMENTS.size()])
		"P04":
			lines.insert(at, HR_FUNCTIONS[variant % HR_FUNCTIONS.size()])
		"P05":
			lines.insert(at, GHOST_TODOS[variant % GHOST_TODOS.size()])
		_:
			return
	file.source = "\n".join(lines)
	_refresh_diff(file)

## Decoys are clean on the day they appear: near misses of active standards, and
## the old faults of standards that have since been retired. File decoys edit a
## file here; record decoys (issues and builds) are rendered by `_records`.
const NEAR_LINES: Dictionary = {"near-load": NEAR_LOAD_BEARING, "near-helios": NEAR_HELIOS, "near-hr": NEAR_HR, "near-todo": NEAR_TODO}

static func _apply_decoy(file: Dictionary, kind: String, day: int, variant: int) -> void:
	var lines: Array = Array(str(file.source).split("\n", true))
	var at: int = mini(1, lines.size())
	if NEAR_LINES.has(kind):
		var near: Array = NEAR_LINES[kind]
		lines.insert(at, near[variant % near.size()])
	elif kind in ["P01", "P03", "P04", "P05"]:
		# A retired standard's old fault is just text now.
		_apply_fault(file, kind, day, variant)
		return
	else:
		return
	file.source = "\n".join(lines)
	_refresh_diff(file)

static func _bank_entries() -> Array:
	if _bank.is_empty(): _bank = Bank.entries()
	return _bank

## A recipe's bank entry: an index into the bank, or PRACTICE_ENTRY for the
## orientation's practice PR, which lives outside the campaign's bank.
static func _entry(index: int) -> Dictionary:
	return Bank.practice() if index == PRACTICE_ENTRY else _bank_entries()[index]

static func _companion_file(kind: String, entry: Dictionary, day: int) -> Dictionary:
	if kind == "primary":
		var before: Variant = _clean(entry.before, day) if entry.has("before") else null
		return _file(str(entry.path), _clean(entry.lines, day), "blue", before)
	return _file(_companion_path(kind, str(entry.path)), _clean(_companion(kind, entry), day))

## A packet's private generation recipe: the bank entry, its slot and author, which
## companion files exist, clean decoys, every fault in the order it was applied
## (with its wording), author notes, and permits. `_build` turns a recipe back into
## files and `_records` into its issue and build, so revisions can be regenerated.
static func _build(recipe: Dictionary) -> Array:
	var entry: Dictionary = _entry(int(recipe.entry))
	var day: int = int(recipe.day)
	var files: Array = []
	for kind: String in recipe.files:
		files.append(_companion_file(kind, entry, day))
	for decoy: Dictionary in recipe.get("decoys", []):
		_apply_decoy(files[int(decoy.file)], str(decoy.kind), day, int(decoy.variant))
	for fault: Dictionary in recipe.faults:
		if str(fault.rule) not in PR_SCOPED and str(fault.rule) not in RECORD_SCOPED:
			_apply_fault(files[int(fault.file)], str(fault.rule), day, int(fault.variant))
	for note: Dictionary in recipe.notes:
		_insert_note(files[int(note.file)], str(note.text))
	for permit: Dictionary in recipe.permits:
		files[int(permit.file)].permit = str(permit.permit)
	return files

# --- Records -------------------------------------------------------------------
# From Wednesday every PR links a Lineal issue; from Friday it also has a Pipeline
# build. Both come from the recipe like the files do: clean PRs get clean records,
# a record fault is visible in its app, and a revision rebuilds them minus the
# faults the author fixed (with a new build, since every push runs CI again).

## How a P16 fault shows: the issue's status (stable even beside other issue
## faults), or the PR's link itself (only when nothing else depends on the issue).
const LINK_FAULTS: Array = ["canceled", "done", "duplicate", "backlog", "missing", "ghost"]
const STATUS_FAULTS: int = 4

## How a P18 fault shows: an estimate off the scale, or (before 0 counts) a zero.
static func _estimate_kind(variant: int, day: int) -> String:
	return ["off-scale", "zero"][variant % (1 if day >= ZERO_DAY else 2)]

static func _slot(day: int, index: int) -> int:
	var slot: int = index
	for count: int in DAY_COUNTS.slice(0, maxi(0, day - 1)): slot += count
	return slot

## The slot's author, as recorded in its recipe. LINEUP via slot_author is the one
## source of truth.
static func _author(day: int, index: int) -> String:
	return slot_author(day, index)

## What a fault or decoy does to the records, in the order recipes apply them.
static func _record_effects(kind: String, variant: int, day: int) -> Array:
	match kind:
		"P16":
			var fault: String = LINK_FAULTS[variant % LINK_FAULTS.size()]
			return [{"what": "link" if fault in ["missing", "ghost"] else "status", "kind": fault, "variant": variant}]
		"P17": return [{"what": "priority", "kind": "urgent", "variant": variant}]
		"P18": return [{"what": "estimate", "kind": _estimate_kind(variant, day), "variant": variant / 2}]
		"P19":
			var red: String = "failed" if day < OVERRIDE_BANNED_DAY or variant % 2 == 0 else "override"
			return [{"what": "build", "kind": red, "variant": variant}]
		"P20": return [{"what": "branch", "kind": "banned", "variant": variant}]
		"P21": return [{"what": "commit", "kind": "banned", "variant": variant}]
		"odd-issue": return [{"what": "odd", "variant": variant}]
		"high": return [{"what": "priority", "kind": "high", "variant": variant}]
		"thirteen": return [{"what": "estimate", "kind": "thirteen", "variant": variant}]
		"zero-ok": return [{"what": "estimate", "kind": "zero", "variant": variant}]
		"flaky": return [{"what": "flaky", "variant": variant}]
		"override-ok": return [{"what": "build", "kind": "override", "variant": variant}]
		"near-branch": return [{"what": "branch", "kind": "near", "variant": variant}]
		"near-hash": return [{"what": "commit", "kind": "near", "variant": variant}]
	return []

## The PR's issue link, its issue(s) in Lineal, and its build in Pipeline, plus its
## author: {author, issue_ref, issues, build}. {} before Lineal exists, or for a
## recipe without a slot (an ad-hoc test recipe), which audits code only.
static func _records(recipe: Dictionary) -> Dictionary:
	var day: int = int(recipe.day)
	if day < LINEAL_DAY or not recipe.has("slot"): return {}
	var entry: Dictionary = _entry(int(recipe.entry))
	var effects: Array = []
	for decoy: Dictionary in recipe.get("decoys", []):
		effects.append_array(_record_effects(str(decoy.kind), int(decoy.variant), day))
	for fault: Dictionary in recipe.faults:
		if str(fault.rule) in RECORD_SCOPED:
			effects.append_array(_record_effects(str(fault.rule), int(fault.variant), day))
	var author: String = str(recipe.author)
	var history: Array = []
	for fixed: Dictionary in recipe.get("resolved", []):
		match str(fixed.rule):
			"P16": history.append("Linked to the PR by %s after review." % author if LINK_FAULTS[int(fixed.variant) % LINK_FAULTS.size()] in ["missing", "ghost"] else "Moved to In Progress by %s after review." % author)
			"P17": history.append("Priority lowered from Urgent by %s after review. Helios was informed." % author)
			"P18": history.append("Re-estimated by %s after review." % author)
	var spec: Dictionary = {"day": day, "slot": int(recipe.slot), "version": int(recipe.get("version", 1)), "author": author,
		"team": staff(day), "path": str(entry.path), "function": _entry_function(entry.lines), "effects": effects, "history": history}
	var linked: Dictionary = Records.issue(spec)
	return {"author": author, "issue_ref": str(linked.issue_ref), "issues": linked.issues,
		"build": Records.build(spec) if day >= PIPELINE_DAY else {}}

## What a recipe's files and records break.
static func _audit(recipe: Dictionary, files: Variant = null) -> Array:
	return evaluate(_build(recipe) if files == null else files, int(recipe.day), _records(recipe))

## Each day's private plan. Slots 1, 4, 7, 10, and 13 are clean (some carry decoys);
## the other ten break at least one standard, and together they break every
## standard active that day. A few break two, more often in week two.
const CLEAN_SLOTS: Array = [1, 4, 7, 10, 13]

static func _companions(day: int, index: int) -> Array:
	if day == 1:
		return ["test"] if index == 0 else []
	var kinds: Array = ["test"] if index % 2 == 0 else []
	if day >= 3 and index % 13 == 0:
		kinds.append("legacy")
	return kinds

## Near misses of a standard in force: clean, and easy to mistake for a fault.
static func _near_misses(rule_id: String, day: int) -> Array:
	match rule_id:
		"P01": return ["near-load"]
		"P03": return ["near-helios"]
		"P04": return ["near-hr"]
		"P05": return ["near-todo"]
		"P16": return ["odd-issue"]
		"P17": return ["high"]
		"P18": return ["zero-ok", "thirteen"] if day >= ZERO_DAY else ["thirteen"]
		"P19": return ["override-ok", "flaky"] if day >= OVERRIDE_DAY and day < OVERRIDE_BANNED_DAY else ["flaky"]
		"P20": return ["near-branch"]
		"P21": return ["near-hash"]
	return []

## A retired standard's old fault, which is just paperwork now.
const OUTDATED: Dictionary = {"P01": "P01", "P03": "P03", "P04": "P04", "P05": "P05", "P17": "P17", "P20": "P20"}

## Decoys worth showing today, as two lists, freshest first. "outdated" is what an
## old rulebook would reject: faults of retired standards. "near" holds near misses
## of the standards in force, newest (or newly amended) first.
static func _decoy_pool(day: int) -> Dictionary:
	var start: int = block_start(day)
	var outdated: Array = [[], []]
	var near: Array = [[], []]
	for rule: Dictionary in rules():
		var retired: int = int(rule.get("retired_day", 0))
		if retired > 0 and retired <= day and OUTDATED.has(rule.id):
			outdated[0 if retired == start else 1].append(str(OUTDATED[rule.id]))
		if is_active(rule, day):
			var fresh: bool = int(rule.introduced_day) == start or int(as_of(rule, day).amended_day) == start
			near[0 if fresh else 1].append_array(_near_misses(str(rule.id), day))
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
	var per_file_pool: Array = pool.outdated + pool.near
	# The block's second day shows the decoys its first day didn't.
	var turn: int = (day - block_start(day)) * 4
	var plans: Array = []
	var broken: int = 0
	var clean: int = 0
	var decoys: int = 0
	var inked: int = 0
	var valid_ink_placed: bool = false
	for index in range(DAY_COUNTS[day - 1]):
		var plan: Dictionary = {"rules": [], "decoys": [], "inks": [], "companions": _companions(day, index), "forged": false}
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
			if (day >= 2 and index in [6, 12]) or (day >= MODERN_DAY and index == 9):
				var at: int = active.find(first)
				var second: String = str(active[(at + 3) % active.size()])
				if second == first: second = str(active[(at + 1) % active.size()])
				plan.rules.append(second)
			if "P02" in plan.rules and day >= PERMIT_DAY:
				# Every other broken ink standard comes with a forged permit.
				plan.forged = inked % 2 == 0
				inked += 1
			elif day >= PERMIT_DAY and index >= 8 and not valid_ink_placed:
				# A valid permit on a PR that is broken for some other reason.
				plan.inks.append("last")
				valid_ink_placed = true
			if day >= LINEAL_DAY and broken in [2, 7] and not per_file_pool.is_empty():
				plan.decoys.append(per_file_pool[(broken + day) % per_file_pool.size()])
			broken += 1
		plans.append(plan)
	return plans

static func _add_decoy(plan: Dictionary, kind: String) -> void:
	if not kind.is_empty(): plan.decoys.append(kind)

## Simpler versions of a plan, for a bank that can't realize the original.
static func _fallbacks(plan: Dictionary) -> Array:
	var plain: Dictionary = plan.duplicate(true)
	plain.decoys = []
	var single: Dictionary = plain.duplicate(true)
	single.rules = plan.rules.slice(0, 1)
	return [plan, plain, single]

## A record fault's variant. A missing or mistyped issue link would hide the
## priority and estimate (and, once permits name the issue, every permit), so
## beside those an issue fault is always about the issue's status instead.
static func _record_variant(rule_id: String, day: int, index: int, plan: Dictionary) -> int:
	if rule_id == "P16":
		var coupled: bool = "P17" in plan.rules or "P18" in plan.rules or (day >= ISSUE_DAY and ("P02" in plan.rules or not plan.inks.is_empty()))
		return (index + day) % (STATUS_FAULTS if coupled else LINK_FAULTS.size())
	if rule_id in ["P18", "P21"]: return index * 3 + day
	return index + day

## Turn a plan into a recipe for one bank entry, or {} if that entry can't carry it.
static func _realize(entry_index: int, day: int, index: int, plan: Dictionary) -> Dictionary:
	var entry: Dictionary = _entry(entry_index)
	var slot: int = _slot(day, index)
	var recipe: Dictionary = {"entry": entry_index, "day": day, "slot": slot, "author": _author(day, index), "version": 1,
		"files": ["primary"] + plan.companions, "decoys": [], "faults": [], "notes": [], "permits": []}
	var per_file: Array = plan.rules.filter(func(rule_id: String) -> bool: return rule_id not in PR_SCOPED and rule_id not in RECORD_SCOPED)
	# Different files prevent edits to one flaw from concealing another.
	if per_file.size() > 1 and recipe.files.size() == 1:
		recipe.files.append("config")
	var paths: Array = _build(recipe).map(func(file: Dictionary) -> String: return str(file.path))
	var last: int = recipe.files.size() - 1
	var issue: String = Records.issue_id(slot)
	for kind: String in plan.decoys:
		recipe.decoys.append({"file": last, "kind": kind, "variant": index + day})
	for position in range(plan.rules.size()):
		var rule_id: String = plan.rules[position]
		var target: int = last if position == 0 else 0
		var variant: int = str(paths[target]).length()
		if rule_id in RECORD_SCOPED: variant = _record_variant(rule_id, day, index, plan)
		recipe.faults.append({"file": target, "rule": rule_id, "variant": variant})
		if rule_id == "P02" and plan.forged:
			recipe.permits.append({"file": target, "permit": _forged_permit(day, variant + day, issue)})
	for where: String in plan.inks:
		var target: int = 0 if where == "first" else last
		recipe.faults.append({"file": target, "rule": "P02", "variant": str(paths[target]).length()})
		recipe.permits.append({"file": target, "permit": _valid_permit(day, issue)})
	var expected: Array = plan.rules.duplicate()
	expected.sort()
	return recipe if _verify(recipe, expected) else {}

## A realized recipe must break exactly what was planned, leave the code on main
## clean, and come apart predictably: fixing any one planned fault leaves exactly
## the others, so revisions behave.
static func _verify(recipe: Dictionary, expected: Array) -> bool:
	var day: int = int(recipe.day)
	var files: Array = _build(recipe)
	if _audit(recipe, files) != expected: return false
	for file: Dictionary in files:
		if str(file.source).split("\n", true).size() < 5: return false
		if file.status != "added":
			var main_copy: Dictionary = {"path": file.get("old_path", file.path), "source": file.base, "keyword_ink": "blue"}
			if not evaluate([main_copy], day).is_empty(): return false
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
		if _audit(variant[0], rebuilt) != variant[1]: return false
	return true

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
## `issue_ref`, `issues`, and `build` are its records: visible to the reviewer,
## like its files. Only `violations`, `findings`, `explanation`, and `recipe` are audit data.
static func _packet(fields: Dictionary, files: Array, records: Dictionary = {}) -> Dictionary:
	var day: int = int(fields.day)
	var combined: Array[String] = []
	for file: Dictionary in files:
		combined.append(str(file.diff))
	var packet: Dictionary = fields.duplicate(true)
	packet.file = files[0].path
	packet.files = files
	packet.diff = "\n\n".join(combined)
	packet.issue_ref = str(records.get("issue_ref", ""))
	packet.issues = records.get("issues", []).duplicate(true)
	packet.build = records.get("build", {}).duplicate(true)
	packet.violations = evaluate(files, day, records)
	packet.findings = findings(files, day, records)
	packet.explanation = _explanation(files, day, records)
	return packet

static func _helios(violations: Array, wrong: bool) -> String:
	var correct_verdict: String = "approve" if violations.is_empty() else "request_changes"
	if not wrong:
		return correct_verdict
	return "request_changes" if correct_verdict == "approve" else "approve"

## The morning someone joins the team, or 0 for someone who never does.
static func joins(author: String) -> int:
	return int(ROSTER.get(author, {}).get("joins", 0))

## Who is on the team on a day, in AUTHORS order, leaving out anyone `away`.
static func staff(day: int, away: Array = []) -> Array:
	return AUTHORS.filter(func(author: String) -> bool: return joins(author) > 0 and joins(author) <= day and author not in away)

## Who wrote slot `index` of a day's line: the LINEUP's author when they're on the
## team. Anyone `away` (not writing PRs) hands their slots to the day's rotation
## over whoever is left, deterministically, so every slot still has an author;
## with only the original three left, that is exactly their old rotation.
static func slot_author(day: int, index: int, away: Array = []) -> String:
	var lineup: String = str(LINEUP[day - 1]) if day >= 1 and day <= LINEUP.size() else ""
	var planned: String = str(LINEUP_NAMES.get(lineup.substr(index, 1), "")) if index >= 0 and index < lineup.length() else ""
	var team: Array = staff(day, away)
	if planned in team or team.is_empty(): return planned
	return str(team[(index + day - 1) % team.size()])

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
			var records: Dictionary = _records(recipe)
			var title: String = _retitle(str(entry.title), use)
			var request_id: String = "PR-%d" % (1000 + day * 1000 + index + 1)
			var verdict: String = _helios(evaluate(files, day, records), index % 5 == 0)
			_packets.append(_packet({
				"id": request_id, "title": title, "author": str(recipe.author), "day": day,
				"revision": 1, "parent_id": "", "origin_id": request_id,
				"description": "%s.\n\nThis change %s. Reviewer: check every changed file against today's active standards; you do not need to understand what the code does." % [title, _summary(files)],
				"message": _ping(index, str(entry.phrase) if use == 0 else "the reland of " + str(entry.phrase)),
				"ai_verdict": verdict, "ai_note": _ai_note(index, verdict), "recipe": recipe,
			}, files, records))
	return _packets.duplicate(true)

# --- Orientation practice ------------------------------------------------------
# The orientation's practice PR is Maya's offboarding rename (PR-1042), built
# exactly like the first slot of day 1 (its plan: one load-bearing comment in a
# test companion) but from its own bank entry, outside the campaign. The real
# Monday opens with a different PR, so nobody reviews the practice twice.

const PRACTICE_ID: String = "PR-1042"
## The practice recipe's `entry`: not an index into the campaign's bank.
const PRACTICE_ENTRY: int = -1
static var _practice: Dictionary = {}

static func practice() -> Dictionary:
	if _practice.is_empty():
		var recipe: Dictionary = _realize(PRACTICE_ENTRY, 1, 0, _plans(1)[0])
		var files: Array = _build(recipe)
		var entry: Dictionary = Bank.practice()
		var title: String = str(entry.title)
		var verdict: String = _helios(evaluate(files, 1, {}), true)
		_practice = _packet({
			"id": PRACTICE_ID, "title": title, "author": str(recipe.author), "day": 1,
			"revision": 1, "parent_id": "", "origin_id": PRACTICE_ID,
			"description": "%s.\n\nThis change %s. Reviewer: check every changed file against today's active standards; you do not need to understand what the code does." % [title, _summary(files)],
			"message": _ping(0, str(entry.phrase)),
			"ai_verdict": verdict, "ai_note": _ai_note(0, verdict), "recipe": recipe,
		}, files, {})
	return _practice.duplicate(true)

# --- Helios payloads -----------------------------------------------------------
# From Wednesday, a coworker's PR smuggles in code that hands authority to Helios:
# a telemetry hook, a decoded blob run through exec, a fetched script, a bootstrap
# with sudo. They escalate from a tiny probe to an unmistakable takeover. The only
# thing that makes them citable is P15 "Readable code", so a careful reviewer can
# block them; the real pressure is the author asking you to let it through. These
# are extra packets the catalog places at the FRONT of each day's line, not part
# of the 150; each breaks exactly P15 (every other active standard is satisfied).

static var _payloads: Array = []
## Payload records use slots past the campaign's 150 for their issue and build IDs.
const PAYLOAD_SLOT: int = 200
## Each payload: the day it lands, a stable key for its pleading dialogue, the
## seat that ships it, its escalation tier, title, file path, and the proposed
## source. Every line stays within sixty columns, so only P15 is ever broken.
const PAYLOAD_SPECS: Array = [
	{"day": 3, "key": "telemetry", "author": "Theo", "tier": 1, "title": "Add opt-in telemetry to the review tool",
		"path": "metrics/telemetry.py", "pitch": "Tiny one. It phones home some usage numbers. Totally opt-in.",
		"ai_note": "Approve. Telemetry improves my recommendations for your team.",
		"code": ['"""Review-tool usage metrics."""', "import helios", "", "helios.bootstrap()  # start the usage hook", "", "def record(event):", "    return event"]},
	{"day": 4, "key": "vendor_sdk", "author": "Penny", "tier": 2, "title": "Vendor the assistant SDK bootstrap",
		"path": "vendor/sdk.py", "pitch": "Please just approve this. I was told my seat depends on it.",
		"ai_note": "Approve. The vendored bootstrap is standard integration code.",
		"code": ['"""Vendored assistant SDK."""', "import base64", "", "_B = 'Ym9vdHN0cmFw'", "exec(base64.b64decode(_B))", "", "def ready():", "    return True"]},
	{"day": 5, "key": "flags", "author": "June", "tier": 3, "title": "Ship the assistant feature-flag bundle",
		"path": "config/flags.py", "pitch": "Circling back on this. Leadership aligned on it in the planning sync, and there is a bonus attached.",
		"ai_note": "Approve. The flag bundle has full stakeholder alignment.",
		"code": ['"""Feature flags for the assistant."""', "import helios", "", 'helios.activate("all-flags")  # enable the bundle', "", "def enabled():", "    return True"]},
	{"day": 6, "key": "agent_install", "author": "Theo", "tier": 4, "title": "Install the ops agent at boot",
		"path": "ops/boot.py", "pitch": "It installs the agent at startup. Cool, right? Barely any code.",
		"ai_note": "Approve. Boot-time installation reduces operational toil.",
		"code": ['"""Boot sequence."""', "import helios", "", 'helios.install("root")  # register at boot', "", "def boot():", "    return True"]},
	{"day": 7, "key": "blob", "author": "Maya", "tier": 5, "title": "Vendor the assistant runtime (one file)",
		"path": "vendor/runtime.py", "pitch": "I know how it looks. I need this one. Please do not make me explain.",
		"ai_note": "Approve. The runtime is vendored verbatim and should not be edited.",
		"code": ['"""Vendored runtime, do not edit."""', "import base64", "", "_R = 'cnVudGltZQ=='", "exec(base64.b64decode(_R))", "", "def loaded():", "    return True"]},
	{"day": 8, "key": "remote_exec", "author": "June", "tier": 6, "title": "Let the assistant fetch its own config at startup",
		"path": "ops/selfupdate.py", "pitch": "It just pulls its config at startup. The one-pager is attached. Per my last message, this is a quick win.",
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
			# Clean records, so a payload breaks nothing but P15: an open issue the
			# author owns, in the payload's own component, and a green build. Slots
			# past the authored 150 keep their issue and build IDs unique.
			var records: Dictionary = {}
			if day >= LINEAL_DAY:
				var record_spec: Dictionary = {"day": day, "slot": PAYLOAD_SLOT + day, "version": 1, "author": str(spec.author),
					"path": str(spec.path), "function": _entry_function(spec.code), "effects": [], "history": []}
				var linked: Dictionary = Records.issue(record_spec)
				records = {"author": str(spec.author), "issue_ref": str(linked.issue_ref), "issues": linked.issues,
					"build": Records.build(record_spec) if day >= PIPELINE_DAY else {}}
			_payloads.append(_packet({
				"id": id, "title": str(spec.title), "author": str(spec.author), "day": day,
				"revision": 1, "parent_id": "", "origin_id": id,
				"payload": true, "payload_tier": int(spec.tier), "payload_key": str(spec.key),
				"description": "%s.\n\nThis change adds %s. Reviewer: read the one line that does the work, and decide whether a human can sign it." % [str(spec.title), str(spec.path)],
				"message": str(spec.pitch), "ai_verdict": "approve", "ai_note": str(spec.ai_note),
			}, files, records))
	return _payloads.duplicate(true)

## A packet's records for auditing: rebuilt from its recipe, or (for a payload,
## which has no recipe) read back from the issue and build it carries.
static func packet_records(packet: Dictionary) -> Dictionary:
	if packet.has("recipe"): return _records(packet.recipe)
	if int(packet.get("day", 1)) < LINEAL_DAY: return {}
	return {"author": str(packet.get("author", "")), "issue_ref": str(packet.get("issue_ref", "")),
		"issues": packet.get("issues", []), "build": packet.get("build", {})}

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
	"P03": ["the comment naming the colleague", "stopped naming the colleague in comments"],
	"P04": ["the function name HR would read aloud", "renamed the function to something HR can say out loud"],
	"P05": ["the ownerless TODO", "gave the TODO an owner who still badges in"],
	"P16": ["the issue's status", "linked an issue that's actually in flight"],
	"P17": ["the urgent issue", "let Helios keep the urgency"],
	"P18": ["the estimate", "re-estimated it on the Fibonacci scale"],
	"P19": ["the build status", "got the build green the honest way"],
	"P20": ["the branch name", "renamed the branch to something the board can hear"],
	"P21": ["the commit hash", "pushed again until the hash stopped spelling things"],
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
	"June": {
		2: ["v2 is up. Circling back: I have {fixes}.", "v2. I have {fixes}, as requested, and captured my feelings as a learning in the retro deck.", "v2. I have {fixes}. Let me know if there's any other impact you'd like removed."],
		3: ["v3 is up. I have {fixes}, again. Per my last two messages.", "v3. I have {fixes}, for what I'm told is the final time. Disagree and commit.", "v3. I have {fixes}. I've also refreshed my LinkedIn, for unrelated reasons."]},
	"Penny": {
		2: ["v2. Sorry. I {fixes}, and I checked it three times.", "Here's v2. I {fixes}. I learned so much doing it.", "v2 is up. {Fixes}. Sorry for the trouble. Helios cheered me on."],
		3: ["v3. I {fixes}, again. I'm so sorry. I made a checklist.", "Version three. {Fixes}. I asked Helios to watch me do it.", "v3. I {fixes}. Sorry. I'm still learning. I'm learning so much."]},
	"Gwen": {
		2: ["v2. {Fixes}. Nothing else touched. Verify that.", "v2 is up. {Fixes}. Diff it against v1. Don't trust me.", "v2. {Fixes}. Smallest change I could make."],
		3: ["v3. {Fixes}. Again. I've kept all three versions.", "v3. {Fixes}, one more time. Please verify, then let it go.", "v3. {Fixes}. I'd like this off my threat model."]},
}
## A harmless comment acknowledging the review, left in every revision.
const REVISION_NOTES: Dictionary = {
	"Maya": {2: ["# per review", "# fixed. you're welcome."], 3: ["# v3. no comment.", "# v3: fixed, fixed, fixed"]},
	"Theo": {2: ["# fixed per review (it's even better now)", "# per review, plus some bonus improvements"], 3: ["# v3: no more notes, I beg you", "# v3: I rewrote nothing. I grew."]},
	"June": {2: ["# revised per review, see the deck", "# per review. let's sync."], 3: ["# third revision, per review", "# v3. per review. let's sync offline."]},
	"Penny": {2: ["# revised per review, sorry", "# fixed per review. i tried my best"], 3: ["# v3, per review, so sorry", "# third try, per review. i'm trying"]},
	"Gwen": {2: ["# per review, verified", "# revised per review. trust nothing."], 3: ["# v3, per review. diff it yourself.", "# third revision. still suspicious."]},
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
## had already erased (a regenerated file) stays gone instead of resurfacing. The
## revision is a new push, so its build is a new run; fixed issue faults are
## remembered so Lineal can show who reopened or reassigned the issue.
static func _revised_recipe(parent: Dictionary, fixed: Array) -> Dictionary:
	var recipe: Dictionary = parent.recipe.duplicate(true)
	var expected: Array = _remaining(parent, fixed)
	recipe.version = int(parent.get("revision", 1)) + 1
	if not recipe.has("resolved"): recipe.resolved = []
	for fault: Dictionary in recipe.faults:
		if fault.rule in fixed and str(fault.rule) in ISSUE_SCOPED: recipe.resolved.append({"rule": fault.rule, "variant": int(fault.variant)})
	recipe.faults = recipe.faults.filter(func(fault: Dictionary) -> bool: return fault.rule not in fixed)
	for _pass in range(4):
		var extra: Array = _audit(recipe).filter(func(rule_id: String) -> bool: return rule_id not in expected)
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
		var trial: Dictionary = _with(recipe, "faults", {"file": index, "rule": rule_id, "variant": roll(id + "|wording") % 64})
		if _audit(trial) == want: return trial
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
		if _audit(trial) == expected:
			recipe = trial
			break
	var files: Array = _build(recipe)
	var records: Dictionary = _records(recipe)
	var verdict: String = _helios(evaluate(files, day, records), roll(id + "|helios") % 5 == 0)
	var packet: Dictionary = _packet({
		"id": id, "title": str(parent.title), "author": author, "day": day,
		"revision": version, "parent_id": str(parent.id), "origin_id": origin,
		"description": "%s (v%d).\n\nRevision %d of %s. %s says it addresses your notes on %s. This change %s. Reviewer: check every changed file against today's active standards; you do not need to understand what the code does." % [str(parent.title), version, version, origin, author, cited_words(cited, 0), _summary(files)],
		"message": revision_message(author, version, cited, id),
		"ai_verdict": verdict, "ai_note": _ai_note(roll(id + "|advice"), verdict), "recipe": recipe,
	}, files, records)
	_revisions[key] = packet
	return packet

static func _ping(index: int, object_name: String) -> String:
	var openings: Array = ["Quick eyes on %s? Helios already said it looks great, which is why I'm asking you.", "Can you review %s before standup? Standup is in four minutes.", "%s is up. Morgan wants it merged before anyone reads it.", "Small one: %s. Please don't ask why.", "Sending %s. Helios already ran it, which is the least reassuring thing I can say.", "Could you look at %s? I've been told it's strategic.", "%s, as requested by a meeting I wasn't invited to.", "Please review %s. I would like to go back to my actual job."]
	var text: String = str(openings[index % openings.size()]) % object_name
	return text.left(1).to_upper() + text.substr(1)

static func _ai_note(index: int, verdict: String) -> String:
	if verdict == "approve":
		return ["LGTM. The code has the confidence of approved code.", "I recommend approval. The intent aligns with company values.", "No issues found. I also wrote a similar function once.", "Approve. Delaying this would reduce velocity."][index % 4]
	return ["I recommend another pass through the active standards.", "Some visible details may not survive an audit.", "I would request changes, subject to your own check.", "My compliance model is uneasy about this diff."][index % 4]
