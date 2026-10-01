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
	var subjects := ["Your desk is assigned. Your signature is still required.", "The Records Office has requirements.", "PIGEON carries every file now. Helios would like to help.", "Exceptions exist. They are not free.", "Final review cycle. Please remain calm."]
	var bodies := [
		"Northstar is transitioning code review to Helios. Until the transition completes, every change still needs a human signature, and for this assignment that signature is yours. You will not be asked to understand the code. You will be asked to enforce the standards on it, exactly as written. A confident summary from a colleague does not excuse a forbidden phrase. Your assignment runs Monday through Friday.",
		"The audit printers have filed a complaint. From today, filenames must be quiet and every line must fit the printout, or the change does not exist on paper. Changes increasingly arrive in several files. An unread file is an unsigned file.",
		"Every file is now carried to Legal by PIGEON, our compliance courier, and must end with its sign-off. Comments are scanned for sentiment; exclamation marks are flagged. Helios is now available in Review. It is fast and it is confident. It is not always right, and every consultation is logged against your desk.",
		"Tabs are banned: they hide whitespace from the line scanners, and anything hidden is presumed hostile. The Exception Desk now issues INK-EXCEPTION, which permits pink keywords in that one file and waives nothing else. Read every stamp letter by letter. A misspelled permit is a forged permit.",
		"Only management may declare urgency, so the word urgent is now forbidden inside quoted text. Every earlier standard and permit still applies. This is the last day of your assignment. Morgan will discuss your future with the company at closing.",
	]
	result.subject = subjects[day - 1]
	result.body = bodies[day - 1]
	result.mechanics = [
		"Work is assigned through Slouch and queued in Review. Take the next item with NEXT PR. Do not wait to be asked twice.",
		"Every changed file is shown in full, with line numbers. Keyword ink is printed above each file for the record. Your eyes are not the record.",
		"If every standard is met, stamp APPROVED. If not, mark the offending line in Review (or WHOLE FILE), cite the standard it breaks in the Handbook, then stamp CHANGES REQUESTED. An uncited objection is not an objection.",
		"Your shift is five minutes from BEGIN SHIFT. You may pause; the queue will not. Whatever remains at closing is reassigned to Helios.",
	]
	result.rules = new_rules
	return result
