extends SceneTree
## Immersion guard: every authored, player-visible string reads as something
## that exists inside Paperclip Labs. Scans the string literals of the content
## and interface scripts (and the Hackerish News feed) for game vocabulary,
## designer voice, and real brands. The main menu and save/settings errors may
## stay game UI; they are skipped or allowlisted below.
##
## A TODO is only flagged as an unfinished-text marker ("TODO:"); TODO(maya)
## and the Lineal status Todo are in-world (the ghost-TODO standard is about them).

const SCANNED: Array[String] = [
	"res://content/banter.gd",
	"res://content/chat.gd",
	"res://content/policy_chat.gd",
	"res://content/payloads.gd",
	"res://content/staff.gd",
	"res://content/endings.gd",
	"res://content/daily_press.gd",
	"res://content/payroll.gd",
	"res://content/encounters.gd",
	"res://content/encounter_lines.gd",
	"res://content/pr_bank.gd",
	"res://content/policy_campaign.gd",
	"res://content/records.gd",
	"res://content/trees/days_01_02.gd",
	"res://content/trees/days_03_04.gd",
	"res://content/trees/days_05_06.gd",
	"res://content/trees/days_07_08.gd",
	"res://content/trees/days_09_10.gd",
	"res://native/interface.gd",
	"res://native/tutorial.gd",
	"res://native/main.gd",
	"res://native/cold_open.gd",
	"res://native/ending_cinematic.gd",
	"res://native/desktop_notifications.gd",
	"res://native/daily_reader.gd",
	"res://native/review_banter.gd",
]
const PRESS_FEED := "res://content/daily_press.json"

## Talking to the player as a player, characters who know the rules are graded,
## designer and debug voice, and the real tools the game parodies.
const BANNED: Array[String] = [
	"\\bplayers?\\b", "\\btutorials?\\b", "\\bgames?\\b", "\\bgameplay\\b", "\\bplaythrough\\b",
	"\\blevel(?:ed)? up\\b", "\\bhigh score\\b", "\\bxp\\b", "\\bhp\\b", "\\bachievements?\\b",
	"\\bnew run\\b", "\\bthis run\\b", "\\bsave(?:d)? run\\b", "\\bmain menu\\b", "\\bcinematic\\b", "\\bcutscene\\b",
	"(?:\\d+|%d) real (?:minutes|seconds)\\b", "\\bgraded\\b", "\\b(?:in)?correct answer\\b", "\\bwrong answer\\b",
	"\\bcounts? against you\\b", "\\bmistake counted\\b", "\\baudit will mark\\b",
	"\\b(?:trust|stress|relationship|morale) [+\\-−]\\s*\\d", "\\b(?:trust|stress|relationship) [+\\-−]{2}",
	"\\btodo:", "\\bfixme\\b", "\\bplaceholder\\b", "\\blorem\\b", "\\bphase:", "\\bstate:",
	"\\bjira\\b", "\\bslack\\b", "\\bgithub\\b", "\\bgitlab\\b", "\\blinkedin\\b", "\\bstack overflow\\b",
	"\\bhacker news\\b", "\\bgoogle\\b", "\\btwitter\\b", "\\bchatgpt\\b", "\\bopenai\\b", "\\bcopilot\\b",
	"\\bclaude\\b", "\\banthropic\\b", "\\bgodot\\b",
]

## Exact strings allowed to stay game UI: ending cards and in-world uses of a
## banned word. Keep this list short.
const ALLOWED: Array[String] = [
	"RETURN TO MAIN MENU",
	"Collapse or expand orientation instructions",
]

## Lines that are data for developer tools, never shown to the player: the
## encounter flow chart's node notes.
const SKIPPED_LINE_MARKERS: Array[String] = ["\"about\": \"", "push_error("]

var checks := 0
var failures := 0
var _banned: Array[RegEx] = []
var _literal := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _run() -> void:
	for pattern: String in BANNED:
		var regex := RegEx.create_from_string("(?i)" + pattern)
		_check(regex.is_valid(), "Banned pattern compiles: " + pattern)
		_banned.append(regex)
	for path: String in SCANNED: _scan_script(path)
	_scan_feed()
	_test_guard_catches_meta()
	print("Immersion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


## Only prose is checked: a literal with a space in it, outside comments.
func _scan_script(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	_check(not text.is_empty(), "Scanned script exists: " + path)
	var number := 0
	for line: String in text.split("\n"):
		number += 1
		if line.strip_edges().begins_with("#"): continue
		if SKIPPED_LINE_MARKERS.any(func(marker: String) -> bool: return line.contains(marker)): continue
		for found: RegExMatch in _literal.search_all(line):
			var value := found.get_string(1)
			if not value.contains(" "): continue
			_check_text(value, "%s:%d" % [path.get_file(), number])


func _scan_feed() -> void:
	var feed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESS_FEED))
	_check(feed != null, "The Hackerish News feed parses.")
	_walk(feed)


func _walk(value: Variant) -> void:
	if value is String: _check_text(value, "daily_press.json")
	elif value is Array:
		for item: Variant in value: _walk(item)
	elif value is Dictionary:
		for item: Variant in value.values(): _walk(item)


func _offence(text: String) -> String:
	if text in ALLOWED: return ""
	for regex: RegEx in _banned:
		var found := regex.search(text)
		if found != null: return found.get_string()
	return ""


func _check_text(text: String, where: String) -> void:
	var offence := _offence(text)
	_check(offence.is_empty(), "%s breaks immersion (\"%s\"): %s" % [where, offence, text.left(120)])


## The guard itself must catch the kinds of line this pass removed.
func _test_guard_catches_meta() -> void:
	for line: String in ["This practice is untimed. Follow the tutorial.", "Save this run and choose a slot for a new game?",
			"Each shift lasts 3 real minutes.", "It said so in Jira.", "You go home and rest. Stress -24.",
			"That'll count against you, player.", "Play the ending cinematic.", "TODO: write the memo."]:
		_check(not _offence(line).is_empty(), "The guard flags: " + line)
	for line: String in ["Quick win. I've added it to the wins channel.", "Above my pay grade.", "MORGAN'S TRUST: steady", "Every TODO needs an owner: TODO(maya).", "Status: Todo"]:
		_check(_offence(line).is_empty(), "The guard allows in-world lines: " + line)
