extends RefCounted
## Unique dialogue trees, one per PR, keyed by the PR's title (titles are unique).
## Each two-day block of the campaign has its own file in content/trees/.
##
## A tree is written in the voice of the author the campaign assigns that slot:
##   {"author": "Maya",
##    "lean": {"pushback": 10, "abandon": -5},        # this PR's own branch odds
##    "desk": {"pitch": {"warm": "...", "neutral": "...", "strained": "...", "hostile": "..."},
##             "flag": {"friendly": "...", "cold": "..."}, ...},
##    "dm": {"grudge": {"any": "..."}, ...}}
## A node's lines are keyed by an exact mood, by a tone ("friendly" covers warm
## and neutral, "cold" covers strained and hostile), or by "any". Lookups try the
## exact mood, then the tone, then "any". Templates in content/encounter_lines.gd
## cover anything a tree leaves out.

const FILES: Array[String] = [
	"res://content/trees/days_01_02.gd",
	"res://content/trees/days_03_04.gd",
	"res://content/trees/days_05_06.gd",
	"res://content/trees/days_07_08.gd",
	"res://content/trees/days_09_10.gd",
]
const MOODS: Array[String] = ["warm", "neutral", "strained", "hostile"]
const TONES := {"warm": "friendly", "neutral": "friendly", "strained": "cold", "hostile": "cold"}
## Nodes every tree must voice, on each channel, at least once per tone. The pitch
## is the first impression, so it needs every mood.
const DESK_REQUIRED: Array[String] = ["pitch", "return", "revised", "flag", "thanks", "suspicious", "relief", "revise_now", "revise_later", "pushback", "insist_revise", "insist_escalate", "withdrawn", "abandon", "escalate"]
const DM_REQUIRED: Array[String] = ["thanks", "suspicious", "revise_later", "abandon", "escalate", "grudge"]
const EVERY_MOOD: Array[String] = ["pitch"]
## How far one PR may lean a branch; the author's personality still dominates.
const LEAN_LIMIT := 25

static var _trees: Dictionary = {}

static func all() -> Dictionary:
	if _trees.is_empty():
		for path: String in FILES:
			if not ResourceLoader.exists(path): continue
			var block: Variant = load(path)
			if block == null or not block.has_method("trees"): continue
			var found: Dictionary = block.trees()
			for title: Variant in found: _trees[str(title)] = found[title]
		if _trees.is_empty(): _trees["__none__"] = {}
	return _trees

static func tree(title: String) -> Dictionary:
	return all().get(title, {})

## This PR's line for a node and mood, or "" to fall back to templates.
static func line(title: String, channel: String, node: String, mood: String) -> String:
	var lines: Dictionary = tree(title).get(channel, {}).get(node, {})
	for key: String in [mood, str(TONES.get(mood, "")), "any"]:
		var text := str(lines.get(key, "")).strip_edges()
		if not text.is_empty(): return text
	return ""

## This PR's own nudges to branch odds, clamped to LEAN_LIMIT.
static func lean(title: String) -> Dictionary:
	var result := {}
	var raw: Dictionary = tree(title).get("lean", {})
	for node: Variant in raw: result[str(node)] = clampi(int(raw[node]), -LEAN_LIMIT, LEAN_LIMIT)
	return result
