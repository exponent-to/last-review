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
	var result: Dictionary = edition.memo.duplicate(true)
	var new_rules: Array = []
	for rule: Dictionary in Catalog.rules_for_day(day):
		if int(rule.introduced_day) == day:
			new_rules.append(rule)
	result.rules = new_rules
	return result
