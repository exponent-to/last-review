extends RefCounted
## Fictional daily press and onboarding memos. No request audits or external links.

const Catalog = preload("res://content/catalog.gd")
static var _editions: Array = []

static func _edition(day: int) -> Dictionary:
	if day not in Catalog.campaign_days():
		return {}
	if _editions.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/daily_press.json"))
		if parsed is Array:
			_editions = parsed
		else:
			push_error("Invalid daily press content.")
	for edition: Dictionary in _editions:
		if int(edition.day) == day:
			return edition
	return {}

static func stories(day: int) -> Array:
	var edition: Dictionary = _edition(day)
	return edition.get("stories", []).duplicate(true)

static func story(day: int, id: String) -> Dictionary:
	for article: Dictionary in stories(day):
		if article.id == id:
			return article
	return {}

static func memo(day: int) -> Dictionary:
	var edition: Dictionary = _edition(day)
	if edition.is_empty():
		return {}
	var result: Dictionary = {}
	var new_rules: Array = []
	for rule: Dictionary in Catalog.rules_for_day(day):
		if int(rule.introduced_day) == day:
			new_rules.append(rule)
	var subjects := ["New visual standards. No coding expertise required.", "Filenames and lines now have a dress code.", "The pigeon is mandatory. Helios would like to help.", "Exceptions require actual paperwork.", "Friday: the full policy desk."]
	var bodies := ["Look for words, letters, and keyword colors. A confident summary doesn't excuse a forbidden phrase. Your assignment runs Monday through Friday. Work arrives every twenty seconds once you begin.", "Today adds lowercase filenames and a sixty-character line limit. More PRs now change several files. The whole PR must comply, so use the file selector before signing.", "Every file must end with the pigeon sign-off. Comments cannot shout with exclamation marks. Helios recommendations are now available in Review, but they can be wrong. Look at the file yourself.", "Tabs are prohibited. Starting today, the exact stamp INK-EXCEPTION permits pink keywords in that file only. Compare the stamp letter for letter with the handbook. A typo, an unstamped file, or another policy violation is not covered.", "The word urgent is now banned inside quoted strings. All earlier policies and the ink-exception procedure still apply. This is the final day of your assignment; Morgan will tell you what happens next after closing."]
	result.subject = subjects[day - 1]
	result.body = bodies[day - 1]
	result.mechanics = ["Use NEXT PR or the arrived-PR dropdown in Review to pick up work. New messages also contain direct links.", "The editor shows the full proposed file with line numbers. Keyword ink is named above it, so color alone never decides a review.", "Approve if every active policy passes. Otherwise point at the evidence (click the offending line, or WHOLE FILE), tick the policy it breaks on the citation slip, then stamp CHANGES REQUESTED.", "You have five minutes once you click BEGIN SHIFT. Pause any time. Nobody expects you to clear the entire queue."]
	result.rules = new_rules
	return result
