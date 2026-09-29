extends SceneTree

const DailyPress = preload("res://content/daily_press.gd")
const Catalog = preload("res://content/catalog.gd")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_test_editions()
	_test_gating()
	_test_purity()
	print("Daily press checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _test_editions() -> void:
	var seen_ids: Array = []
	var seen_titles: Array = []
	for day: int in Catalog.campaign_days():
		var articles: Array = DailyPress.stories(day)
		_check(articles.size() == 3, "Every actual campaign day must have its authored news edition.")
		for article: Dictionary in articles:
			for key: String in ["id", "title", "source", "byline", "body"]:
				_check(typeof(article.get(key)) == TYPE_STRING and not str(article[key]).is_empty(), "Every story must have nonempty %s text." % key)
			_check(article.id not in seen_ids and article.title not in seen_titles, "Stories must have unique identities and headlines.")
			seen_ids.append(article.id)
			seen_titles.append(article.title)
			_check(article.body.length() > 350 and "\n\n" in article.body, "Clicking a headline must open a substantive full story.")
			_check(DailyPress.story(day, article.id) == article, "Story lookup must resolve the matching day's article.")
			_check(not article.has("url") and not article.has("score"), "Fictional articles must not carry external destinations or leaderboard scores.")
			_check(typeof(article.get("comments")) == TYPE_ARRAY, "Optional story discussion must use an array.")
			for comment: Variant in article.comments:
				_check(typeof(comment) == TYPE_STRING and not comment.is_empty(), "Story comments must be authored strings.")
		var memo: Dictionary = DailyPress.memo(day)
		_check(memo.keys().size() == 4 and memo.has("subject") and memo.has("body") and memo.has("mechanics") and memo.has("rules"), "Memo must retain its UI contract.")
		_check(not memo.subject.is_empty() and not memo.body.is_empty() and memo.mechanics.size() >= 3, "Each memo must explain the day's context and mechanics.")
		var expected_rules: Array = []
		for rule: Dictionary in Catalog.rules_for_day(day):
			if int(rule.introduced_day) == day:
				expected_rules.append(rule)
		_check(memo.rules == expected_rules, "Memo rule entries must exactly match newly introduced catalog standards.")
		for mechanic: Variant in memo.mechanics:
			_check(typeof(mechanic) == TYPE_STRING and not mechanic.is_empty(), "Mechanics must be readable authored guidance.")
		var prose: String = JSON.stringify(articles) + JSON.stringify(memo)
		for forbidden: String in ["https://", "http://", "requests remaining", "reviews remaining", "requests await", "Trust +", "stress +", "relationship +"]:
			_check(forbidden not in prose, "Press and memos must not expose external links, resource deltas, or future queue counts.")

func _test_gating() -> void:
	for day: int in Catalog.campaign_days():
		for other_day: int in Catalog.campaign_days():
			if day == other_day:
				continue
			for article: Dictionary in DailyPress.stories(other_day):
				_check(DailyPress.story(day, article.id).is_empty(), "An edition may not resolve another day's headline, including future stories.")
		_check(DailyPress.story(day, "invented-headline").is_empty(), "Unknown story IDs must not resolve.")
	for day: int in [-1, 0, 4, 99]:
		_check(DailyPress.stories(day).is_empty() and DailyPress.memo(day).is_empty() and DailyPress.story(day, "pilot-has-a-badge").is_empty(), "Noncampaign days must not expose an edition or future rules.")

func _test_purity() -> void:
	var original_stories: Array = DailyPress.stories(1)
	var changed_stories: Array = DailyPress.stories(1)
	changed_stories[0].title = "Changed"
	changed_stories[0].comments.append("Changed comment")
	_check(DailyPress.stories(1) == original_stories, "Returned story arrays must not alias authored content.")
	var article: Dictionary = DailyPress.story(1, original_stories[0].id)
	article.body = "Changed body"
	_check(DailyPress.story(1, original_stories[0].id).body != article.body, "Individual article lookups must return independent dictionaries.")
	var original_memo: Dictionary = DailyPress.memo(1)
	var changed_memo: Dictionary = DailyPress.memo(1)
	changed_memo.rules[0].text = "Changed rule"
	changed_memo.mechanics.clear()
	_check(DailyPress.memo(1) == original_memo, "Returned memo rules and mechanics must be independent copies.")
	_check(Catalog.rules_for_day(1)[0].text != "Changed rule", "Reading or editing a memo copy must not modify the catalog.")
	var original_requests: Array = Catalog.requests()
	var modified: Array = original_requests.duplicate(true)
	for request: Dictionary in modified:
		request.violations = ["HIDDEN_AUDIT_SENTINEL"]
		request.explanation = "HIDDEN_AUDIT_SENTINEL"
		request.ai_verdict = "HIDDEN_AUDIT_SENTINEL"
	Catalog._requests = modified
	_check(DailyPress.stories(1) == original_stories and DailyPress.memo(1) == original_memo, "News and memos must not depend on request audit answers.")
	Catalog._requests = original_requests
