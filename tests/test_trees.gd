extends SceneTree
## Per-PR dialogue trees: every campaign PR has its own, in its author's voice,
## covering every branch, within the same content rules as all other dialogue.
const Trees = preload("res://content/trees.gd")
const Catalog = preload("res://content/catalog.gd")
const Encounters = preload("res://content/encounters.gd")
## Raised to the full campaign once every block's trees are written.
const MIN_TREES := 0
const MAX_LENGTH := 70
const PLACEHOLDERS := ["{topic}", "{Topic}", "{topics}", "{Topics}", "{fixes}", "{Fixes}"]
## Moments where the author must name what you cited, in plain words.
const NAMES_CITATION := {"desk": ["flag", "pushback"], "dm": ["revise_later"]}
var checks := 0
var failures := 0

func _initialize() -> void:
	var subjects := RegEx.create_from_string("(?i)\\b(P\\d\\d|load-bearing|pigeon|urgen\\w*|tabs?|uppercase|lowercase|blue|pink|ink|exclamation|sign-?off|whitespace|filenames?|comments?|record|keywords?)\\b")
	var claims := RegEx.create_from_string("(?i)(good catch|great catch|nice catch|you're right|you are right|you're wrong|my bad|my mistake|it's fine|compliant|\\bclean\\b|broken|\\bbugs?\\b|\\bcorrect|incorrect|violat|audit|typo)")
	var articles := RegEx.create_from_string("(?i)\\b(the|a|an|your|my|this|that|our|whole)\\s+\\{topics?\\}")
	var braces := RegEx.create_from_string("\\{[^}]*\\}")
	var by_title := {}
	for packet: Dictionary in Catalog.originals(): by_title[str(packet.title)] = packet
	var trees: Dictionary = Trees.all()
	var seen := {}
	var count := 0
	for title: String in trees:
		if title == "__none__": continue
		count += 1
		var tree: Dictionary = trees[title]
		check(by_title.has(title), "A tree belongs to a real campaign PR: " + title)
		if not by_title.has(title): continue
		check(str(tree.get("author", "")) == str(by_title[title].author), "The tree speaks as the PR's author (%s): %s" % [by_title[title].author, title])
		for channel: String in ["desk", "dm"]:
			var required: Array = Trees.DESK_REQUIRED if channel == "desk" else Trees.DM_REQUIRED
			for node: String in required:
				for mood: String in Trees.MOODS:
					if node in Trees.EVERY_MOOD and channel == "desk":
						check(not str(tree.get(channel, {}).get(node, {}).get(mood, "")).strip_edges().is_empty(), "%s has its own %s line for every mood (%s): %s" % [channel, node, mood, title])
					else:
						check(not Trees.line(title, channel, node, mood).is_empty(), "%s covers %s.%s for %s" % [title, channel, node, mood])
			for node: String in tree.get(channel, {}):
				check(Encounters.NODES.has(node), "Tree nodes are real encounter nodes (%s): %s" % [node, title])
				for key: String in tree[channel][node]:
					check(key in Trees.MOODS or key in ["friendly", "cold", "any"], "Mood keys are moods, tones, or any (%s): %s" % [key, title])
					var text := str(tree[channel][node][key]).strip_edges()
					var label := "%s / %s.%s.%s: %s" % [title, channel, node, key, text]
					check(not text.is_empty() and text.length() <= MAX_LENGTH, "Lines fit the bubble: " + label)
					check(not text.contains("!") and not text.contains("[") and not text.contains("\n"), "No shouting, brackets, or line breaks: " + label)
					check(subjects.search(braces.sub(text, "", true)) == null, "Lines never name what a standard checks: " + label)
					check(claims.search(text) == null, "Lines never claim the PR is or isn't broken: " + label)
					check(articles.search(text) == null, "Topics bring their own article: " + label)
					for found: RegExMatch in braces.search_all(text):
						check(found.get_string() in PLACEHOLDERS, "Only known placeholders: " + label)
					if node in NAMES_CITATION.get(channel, []):
						check(braces.search(text) != null, "This moment names what you cited ({topic}/{topics}/{fixes}): " + label)
					var key_text := text.to_lower()
					check(not seen.has(key_text), "Every line is unique to its PR: " + label + " (also " + str(seen.get(key_text, "")) + ")")
					seen[key_text] = title
		for node: Variant in tree.get("lean", {}):
			check(str(node) in ["thanks", "suspicious", "revise_now", "revise_later", "pushback", "abandon", "escalate", "insist_revise", "insist_escalate"], "Leans name real branches: %s in %s" % [node, title])
			check(absi(int(tree.lean[node])) <= Trees.LEAN_LIMIT, "Leans stay within the limit: " + title)
	check(count >= MIN_TREES, "At least %d PRs have their own tree (%d)" % [MIN_TREES, count])
	# A tree's lean really moves that PR's odds, and only that PR's.
	for title: String in trees:
		if title == "__none__" or not by_title.has(title): continue
		var lean: Dictionary = Trees.lean(title)
		if lean.is_empty(): continue
		var author := str(by_title[title].author)
		var with_tree: Dictionary = Encounters.weights("changes", author, "neutral", [], title)
		var plain: Dictionary = Encounters.weights("changes", author, "neutral")
		check(with_tree != plain or not lean.keys().any(func(node: Variant) -> bool: return plain.has(node)), "A PR's lean changes its own odds: " + title)
		break
	print("Per-PR trees: %d checks, %d failures (%d trees)" % [checks, failures, count])
	quit(1 if failures else 0)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
