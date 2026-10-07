extends SceneTree
## The authored PR bank: every entry's "before" and proposed source is clean
## under every standard (and the house rules the bank promises), every fault
## can be applied to it cleanly, and its author lines never hint at the audit.

const Bank = preload("res://content/pr_bank.gd")
const Campaign = preload("res://content/policy_campaign.gd")
const FIELDS: Array[String] = ["pitch", "pushback", "relief", "grudge"]
const SECRET_NAMES: Array[String] = ["password", "token", "secret", "api_key", "key"]
## Every day of the two-week campaign; each has its own active rulebook.
const LAST_DAY: int = 10
var checks: int = 0
var failures: int = 0
var path_shape := RegEx.create_from_string("^[a-z][a-z0-9_]*(/[a-z][a-z0-9_]*)+\\.py$")
var todo := RegEx.create_from_string("(?i)\\b(todo|fixme)\\b")
var top_level_def := RegEx.create_from_string("^def [a-z_][a-z0-9_]*\\(")
var assignment := RegEx.create_from_string("([A-Za-z_][A-Za-z0-9_.]*)\\s*(?::[^=]*)?=\\s*[rRbBfFuU]{0,2}[\"']")
## Author lines never name a standard or what it checks for (as in banter).
var hints := RegEx.create_from_string("(?i)\\b(P\\d\\d|load-bearing|pigeon|urgen\\w*|tabs?|uppercase|lowercase|capitals?|blue|pink|ink|exclamation|sign-?off|whitespace|filenames?|comments?|record|stamp|permit|sixty|60|columns?)\\b")
## Disputes defend the idea, never the paperwork, so they sound the same
## whether or not the change is really broken.
var paperwork := RegEx.create_from_string("(?i)\\b(strings?|lines?|files?|typos?|spelling|format\\w*|spaces|long|length|letters?|names?|clean|compliant|broken|standards?|rules?)\\b")

func _initialize() -> void:
	var entries: Array = Bank.entries()
	_check(entries.size() >= 160, "The bank holds at least 160 encounters.")
	for index in range(entries.size()):
		_test_entry(entries[index], index)
	# Orientation's practice PR lives outside the campaign bank, under the same rules.
	_test_entry(Bank.practice(), Campaign.PRACTICE_ENTRY)
	_test_identity(entries + [Bank.practice()])
	_check(Bank.entries() == entries and Bank.entries() != [], "The bank is stable between calls.")
	print("PR bank checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_identity(entries: Array) -> void:
	var seen := {"path": {}, "title": {}, "phrase": {}}
	for entry: Dictionary in entries:
		for key: String in seen:
			var value: String = str(entry.get(key, "")).to_lower()
			_check(not value.is_empty() and not seen[key].has(value), "Each entry has a unique %s: %s" % [key, value])
			seen[key][value] = true

func _test_entry(entry: Dictionary, index: int) -> void:
	var path: String = str(entry.get("path", ""))
	_check(path_shape.search(path) != null, "Paths are lowercase snake_case modules in a package: " + path)
	_check(typeof(entry.get("title")) == TYPE_STRING and typeof(entry.get("phrase")) == TYPE_STRING, "Title and phrase are strings: " + path)
	_check(not str(entry.get("phrase", "")).contains("%"), "Phrases are safe to format into pings: " + path)
	var lines: Array = entry.get("lines", [])
	_check(lines.size() >= 5 and lines.size() <= 9, "Proposed source is five to nine lines: " + path)
	# Orientation's practice PR only ever runs on day 1 (its main copy still says
	# fire_employee, which HR would read aloud from day 3; the PR renames it).
	var days: int = 1 if index == Campaign.PRACTICE_ENTRY else LAST_DAY
	_test_source(path, "lines", lines, days)
	if entry.has("before"):
		var before: Array = entry.before
		_test_source(path, "before", before, days)
		var added := 0
		var removed := 0
		for row: Dictionary in Campaign.line_diff("\n".join(before), "\n".join(lines)):
			if row.kind == "+": added += 1
			elif row.kind == "-": removed += 1
		_check(maxi(added, removed) >= 1 and maxi(added, removed) <= 6, "A change touches one to six lines: %s (+%d -%d)" % [path, added, removed])
	_test_faults(entry, index)
	_test_dialogue(path, entry)

## One version of a file: clean under every day's standards, and under the newer
## house rules (no TODOs, prints, or hardcoded secrets).
func _test_source(path: String, label: String, lines: Array, days: int = LAST_DAY) -> void:
	var where := "%s (%s)" % [path, label]
	if lines.is_empty():
		_check(false, "Source is never empty: " + where)
		return
	var source: String = "\n".join(lines)
	for day in range(1, days + 1):
		var file := {"path": path, "source": "\n".join(Campaign._clean(lines, day)), "keyword_ink": "blue"}
		_check(Campaign.findings([file], day).is_empty(), "Bank source is clean under day %d's standards: %s" % [day, where])
	# Faults and notes are inserted after the first line, so the first line and
	# the whole file must end outside any string.
	var opening: String = lines[0]
	var opens_cleanly: bool = opening.begins_with("#") or opening.begins_with("\"\"\"") or opening.begins_with("import ") or opening.begins_with("from ")
	_check(opens_cleanly, "A file opens with a comment, docstring, or import: " + where)
	_check(_probe_is_comment(opening), "The first line closes every quote it opens: " + where)
	_check(_probe_is_comment(source), "The file closes every quote it opens: " + where)
	var lexer: Dictionary = Campaign._lex(source)
	for index in range(lines.size()):
		var line: String = lines[index]
		_check(line.length() <= 60 and not line.contains("\t"), "Lines fit sixty columns without tabs: %s:%d" % [where, index + 1])
		_check(line == line.strip_edges(false, true), "No trailing spaces: %s:%d" % [where, index + 1])
		_check(not line.contains("load-bearing") and not line.contains("print("), "No forbidden phrases or print calls: %s:%d" % [where, index + 1])
		var mask: String = lexer.code_lines[index]
		for found: RegExMatch in assignment.search_all(line):
			if mask.substr(found.get_start(), 1) != line.substr(found.get_start(), 1): continue
			var name: String = found.get_string(1).to_lower()
			for secret: String in SECRET_NAMES:
				_check(not name.contains(secret), "No string literal is assigned to a secret-looking name: %s:%d %s" % [where, index + 1, name])
	for comment: Dictionary in lexer.comments:
		_check(not str(comment.text).contains("!"), "Comments stay calm: %s:%d" % [where, int(comment.line) + 1])
		_check(todo.search(str(comment.text)) == null, "No TODO or FIXME comments: %s:%d" % [where, int(comment.line) + 1])
	var tokens := {}
	for span: Dictionary in Campaign.keyword_spans(source):
		tokens[span.token] = true
	_check(tokens.has("def") and tokens.has("return"), "Every file has a def and a return: " + where)
	var has_entry := false
	for line: String in lines:
		if top_level_def.search(line) != null: has_entry = true
	_check(has_entry, "Every file has a top-level def for companion tests: " + where)

## A comment appended on a new line is read as a comment, not string text.
func _probe_is_comment(text: String) -> bool:
	var line_count: int = text.split("\n", true).size()
	for comment: Dictionary in Campaign._lex(text + "\n# probe").comments:
		if int(comment.line) == line_count and str(comment.text) == " probe": return true
	return false

## Each standard's fault, in every wording and on every day it is active, adds
## exactly that one violation to a PR built on this entry. The PR is built from a
## recipe because the whole-PR fault (the diff budget) shapes the whole packet.
func _test_faults(entry: Dictionary, index: int) -> void:
	for day in range(1, LAST_DAY + 1):
		_check(Campaign._audit(_recipe(index, day, [])).is_empty(), "A PR built on %s, with its issue and build, is clean on day %d before any fault." % [entry.path, day])
		for rule_id: String in Campaign.active_ids(day):
			# P15 "Readable code" is never applied as a generic bank fault; only the
			# authored Helios payloads break it.
			if rule_id in Campaign.PLAN_EXEMPT: continue
			for variant in range(3):
				_check(Campaign._audit(_recipe(index, day, [{"file": 0, "rule": rule_id, "variant": variant}])) == [rule_id], "Fault %s/%d applies cleanly to %s on day %d" % [rule_id, variant, entry.path, day])

## A one-file PR on this entry, with a slot and author so it gets an issue and a build.
func _recipe(index: int, day: int, faults: Array) -> Dictionary:
	return {"entry": index, "day": day, "slot": maxi(index, 0), "author": "Maya", "files": ["primary"], "decoys": [], "notes": [], "permits": [], "faults": faults}

func _test_dialogue(path: String, entry: Dictionary) -> void:
	for field: String in FIELDS:
		var where := "%s %s" % [path, field]
		_check(typeof(entry.get(field)) == TYPE_STRING, "Every entry has a %s line: %s" % [field, path])
		var text: String = str(entry.get(field, ""))
		_check(not text.strip_edges().is_empty() and text.length() < 70, "Author lines are short and nonempty: " + where)
		_check(not text.contains("!") and not text.contains("\n") and not text.contains("%") and not text.contains("{"), "Author lines are dry, single-line, and format-safe: " + where)
		_check(hints.search(text) == null, "Author lines never name a standard or its subject: %s: %s" % [where, text])
		for rule: Dictionary in Campaign.rules():
			_check(not text.contains(str(rule.id)), "Author lines never mention rule IDs: " + where)
	_check(paperwork.search(str(entry.get("pushback", ""))) == null, "Pushback defends the idea, not the paperwork: %s: %s" % [path, entry.get("pushback", "")])
