extends RefCounted
## Fictional office policy puzzles. Every citation comes from visible source evidence.
## Source is Python-shaped stationery, not code the game executes.

const KEYWORDS: Array = ["def", "if", "else", "return"]
const AUTHORS: Array = ["Maya", "Theo", "Inez"]
const DAY_COUNTS: Array = [15, 15, 15, 15, 15]
const ACTIVE_COUNTS: Array = [2, 4, 6, 7, 8]
const PIGEON_STAMP: String = "# approved by a pigeon"
## Rules about a whole file (its name, ink, opening lines, or quoted labels) accept
## the file or any of its lines as evidence. Every other rule needs the exact line.
const FILE_SCOPED: Array = ["P02", "P03", "P08"]
const Bank = preload("res://content/pr_bank.gd")
static var _packets: Array = []
static var _bank: Array = []

static func rules() -> Array:
	return [
		{"id": "P01", "category": "Language", "title": "Nothing is load-bearing", "text": "Legal's position is that no component, and no employee, is load-bearing. A comment must not contain the exact phrase load-bearing, ignoring letter case. Match the hyphen and spacing exactly; the phrase anywhere after an unquoted # counts. Text inside a quoted string is not a comment.", "introduced_day": 1},
		{"id": "P02", "category": "Color", "title": "Approved ink", "text": "Blue is the approved color of compliant instructions. Pink is reserved for flagged personnel files. The whole keyword tokens def, if, else, and return must be blue. Pink is forbidden. Words inside comments or quoted strings are exempt, as are longer names such as return_label. A file without these keyword tokens needs no blue ink. From Thursday onward, the exact per-file stamp INK-EXCEPTION permits pink keywords in that file only. Misspelled stamps do not count, and no other rule is waived.", "introduced_day": 1},
		{"id": "P03", "category": "Filenames", "title": "Quiet filenames", "text": "Capital letters register as shouting in the audit log. The filename, excluding its folders, must not contain uppercase ASCII letters A through Z. Lowercase letters, digits, and punctuation are fine.", "introduced_day": 2},
		{"id": "P04", "category": "Layout", "title": "On the record", "text": "Audit printouts are sixty columns wide. Anything past the margin is off the record, and off-record work is not permitted. No source line may exceed 60 characters, including spaces and punctuation. Exactly 60 is fine. Count the source only, not editor line numbers; a tab counts as one character for this rule.", "introduced_day": 2},
		{"id": "P05", "category": "Sign-off", "title": "PIGEON sign-off", "text": "Every file is carried to Legal by PIGEON, the compliance courier. Files without its sign-off are not delivered. The final nonempty line of every file must be exactly # approved by a pigeon after ignoring leading and trailing spaces. Blank lines after the stamp are fine. Letter case and spelling must match.", "introduced_day": 3},
		{"id": "P06", "category": "Language", "title": "Sentiment control", "text": "Comments are scanned for sentiment, and enthusiasm is a sentiment. Comment text must not contain an exclamation mark (!). Exclamation marks inside quoted strings are allowed. Only text after an unquoted # is a comment.", "introduced_day": 3},
		{"id": "P07", "category": "Layout", "title": "Nothing hidden", "text": "Tabs hide whitespace from the line scanners, and anything hidden is presumed hostile. No literal tab characters may appear anywhere in source, including comments and strings. Use spaces. The two visible characters backslash and t are not a literal tab.", "introduced_day": 4},
		{"id": "P08", "category": "Labels", "title": "Urgency belongs to management", "text": "Only management may declare urgency. Quoted string text must not contain the whole word urgent, ignoring letter case. urgent and URGENT are forbidden; urgently and nonurgent are fine. A letter, digit, or underscore joins a word, so urgent_task is also fine. Comments are exempt.", "introduced_day": 5},
	]

static func briefing(day: int) -> String:
	match day:
		1:
			return "YOUR DESK IS ASSIGNED. Paperclip Labs is transitioning review to Helios. Until it completes, every change still needs a human signature. You will not be asked to understand the code, only to enforce the standards on it exactly as written: forbidden comment wording and approved keyword ink. Work arrives through Slouch. The clock does not wait for you."
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
				_finding(result, "P06", path, int(comment.line) + 1, "The comment contains an exclamation mark.")
		if file.get("keyword_ink", "blue") != "blue" and not (day >= 4 and file.get("permit", "") == "INK-EXCEPTION"):
			var spans: Array = keyword_spans(source)
			if not spans.is_empty():
				_finding(result, "P02", path, int(spans[0].line) + 1, "A listed keyword token is pink instead of blue.")
		if day >= 2:
			if uppercase.search(path.get_file()) != null:
				_finding(result, "P03", path, 0, "The filename contains an uppercase letter.")
			for line_index in range(lines.size()):
				if lines[line_index].length() > 60:
					_finding(result, "P04", path, line_index + 1, "This source line exceeds sixty characters.")
		if day >= 3:
			var last_line: int = lines.size() - 1
			while last_line >= 0 and lines[last_line].strip_edges().is_empty():
				last_line -= 1
			if last_line < 0 or lines[last_line].strip_edges() != PIGEON_STAMP:
				_finding(result, "P05", path, maxi(1, last_line + 1), "The final nonempty line is not the pigeon stamp.")
		if day >= 4:
			for line_index in range(lines.size()):
				if "\t" in lines[line_index]:
					_finding(result, "P07", path, line_index + 1, "This line contains a literal tab.")
		if day >= 5:
			for quoted: String in lexer.strings:
				if urgent.search(quoted) != null:
					_finding(result, "P08", path, 0, "A quoted string contains the whole word urgent.")
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

## `variant` picks the fault's wording; recipes record it so a rebuilt file reads the same.
static func _apply_fault(file: Dictionary, rule_id: String, day: int, variant: int = -1) -> void:
	var lines: Array = Array(str(file.source).split("\n", true))
	if variant < 0: variant = str(file.path).length()
	var at: int = mini(1, lines.size())
	# Inserted lines must read naturally anywhere: they never describe code that
	# isn't in the file.
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
			lines.insert(at, ["# NOTE: Helios says this is fine, and also that it wrote this one", "MOTD = 'please remember that every keystroke is company property'", "# reviewed in the meeting that could have been an email thread"][variant % 3])
		"P05":
			lines[-1] = ["# approved by a seagull", "# approved by helios", "# approved by a pigeon (probably)"][variant % 3]
		"P06":
			lines.insert(at, ["# TODO: delete before the audit!", "# works on my machine!", "# thanks Helios!"][variant % 3])
		"P07":
			lines.insert(at, ["RETRY_DELAY =\t5", "TEAM =\t'platform'", "MAX_SEATS =\t12"][variant % 3])
		"P08":
			lines.insert(at, ["PRIORITY = 'urgent'", "SUBJECT = 'URGENT: per Morgan'", "LABEL = 'Urgent review requested'"][variant % 3])
	file.source = "\n".join(lines)
	_refresh_diff(file)

static func _bank_entries() -> Array:
	if _bank.is_empty(): _bank = Bank.entries()
	return _bank

## A packet's private generation recipe: the bank entry, which companion files exist,
## every fault in the order it was applied (with its wording), author notes, and
## permits. `_build` turns a recipe back into files, so revisions can be regenerated.
static func _build(recipe: Dictionary) -> Array:
	var entry: Dictionary = _bank_entries()[int(recipe.entry)]
	var day: int = int(recipe.day)
	var path: String = str(entry.path)
	var files: Array = []
	for kind: String in recipe.files:
		if kind == "primary":
			var before: Variant = _clean(entry.before, day) if entry.has("before") else null
			files.append(_file(path, _clean(entry.lines, day), "blue", before))
		else:
			files.append(_file(_companion_path(kind, path), _clean(_companion(kind, entry), day)))
	for fault: Dictionary in recipe.faults:
		_apply_fault(files[int(fault.file)], str(fault.rule), day, int(fault.variant))
	for note: Dictionary in recipe.notes:
		_insert_note(files[int(note.file)], str(note.text))
	for permit: Dictionary in recipe.permits:
		files[int(permit.file)].permit = str(permit.permit)
	return files

static func _fault(files: Array, recipe: Dictionary, index: int, rule_id: String) -> void:
	var variant: int = str(files[index].path).length()
	recipe.faults.append({"file": index, "rule": rule_id, "variant": variant})
	_apply_fault(files[index], rule_id, int(recipe.day), variant)

static func _permit(files: Array, recipe: Dictionary, index: int, stamp: String) -> void:
	recipe.permits.append({"file": index, "permit": stamp})
	files[index].permit = stamp

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
	for day in range(1, 6):
		for index in range(DAY_COUNTS[day - 1]):
			var recipe: Dictionary = {"entry": ((day - 1) * DAY_COUNTS[day - 1] + index) % bank.size(), "day": day,
				"files": ["primary"], "faults": [], "notes": [], "permits": []}
			var entry: Dictionary = bank[int(recipe.entry)]
			var path: String = str(entry.path)
			if (day == 1 and index == 0) or (day >= 2 and index % 2 == 0):
				recipe.files.append("test")
			if day >= 3 and index % 13 == 0:
				recipe.files.append("legacy")
			var files: Array = _build(recipe)
			var is_clean: bool = index % 3 == 1
			if not is_clean:
				var primary: String = "P%02d" % (1 + ((index / 3 + (index % 3) * 2) % ACTIVE_COUNTS[day - 1]))
				if day == 1 and index == 0:
					primary = "P01"
				_fault(files, recipe, files.size() - 1, primary)
				if day >= 2 and index > 0 and index % 6 == 0:
					var secondary: String = "P%02d" % (1 + ((int(primary.substr(1)) + 2) % ACTIVE_COUNTS[day - 1]))
					if secondary == primary:
						secondary = "P01" if primary != "P01" else "P02"
					# Different files prevent edits to one flaw from concealing another.
					if files.size() == 1:
						recipe.files.append("config")
						files.append(_file(_companion_path("config", path), _clean(_companion("config", entry), day)))
					_fault(files, recipe, 0, secondary)
			if day >= 4:
				if index in [1, 4, 7]:
					_fault(files, recipe, 0, "P02")
					_permit(files, recipe, 0, "INK-EXCEPTION")
				elif index in [0, 8]:
					_fault(files, recipe, files.size() - 1, "P02")
					_permit(files, recipe, files.size() - 1, "INK-EXCEPTION")
				elif index == 2:
					_fault(files, recipe, 0, "P02")
					_permit(files, recipe, 0, "INK-EXCEPTION")
					_fault(files, recipe, files.size() - 1, "P02")
					_permit(files, recipe, files.size() - 1, "INK-EXEPTION")
				elif index == 5:
					_fault(files, recipe, files.size() - 1, "P02")
					_permit(files, recipe, files.size() - 1, "ink-exception")
			var request_id: String = "PR-%d" % (1000 + day * 1000 + index + 1)
			if day == 1 and index == 0:
				request_id = "PR-1042"
			var verdict: String = _helios(evaluate(files, day), index % 5 == 0)
			_packets.append(_packet({
				"id": request_id, "title": str(entry.title), "author": AUTHORS[(index + day - 1) % AUTHORS.size()], "day": day,
				"revision": 1, "parent_id": "", "origin_id": request_id,
				"description": "%s.\n\nThis change %s. Reviewer: check every changed file against today's active standards; you do not need to understand what the code does." % [str(entry.title), _summary(files)],
				"message": _ping(index, str(entry.phrase)),
				"ai_verdict": verdict, "ai_note": _ai_note(index, verdict), "recipe": recipe,
			}, files))
	return _packets.duplicate(true)

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
}
## The author's note on the PR form and in Slouch. {Fixes}/{fixes} come from CITED_WORDS.
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
		if int(rule.introduced_day) <= day and rule.id not in REGRESSION_EXEMPT and rule.id not in parent.violations and rule.id not in cited:
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
