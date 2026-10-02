extends VBoxContainer
## In-world morning newspaper and policy memo, also available during the shift.
signal navigate_requested(path: String)
signal start_shift_requested

const Press = preload("res://content/daily_press.gd")
const PAPER := Color("a9ada4")
const INK := Color("121412")
const MUTED := Color("3c3f39")
var morning := false
var _day := 1
var _page := "news"
var _content: VBoxContainer
var _scroll: ScrollContainer
var _footer: HBoxContainer
var _action: Button
var _status: Label
var _memo_seen := false

func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 0)
	var paper := PanelContainer.new()
	paper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = PAPER
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	paper.add_theme_stylebox_override("panel", style)
	add_child(paper)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	paper.add_child(_scroll)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	_scroll.add_child(_content)
	_footer = HBoxContainer.new()
	_footer.add_theme_constant_override("separation", 10)
	add_child(_footer)
	_status = Label.new()
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	_footer.add_child(_status)
	_action = Button.new()
	_action.custom_minimum_size.y = 38
	_action.add_theme_font_size_override("font_size", 12)
	for state_name: String in ["normal", "hover", "pressed"]:
		var primary := StyleBoxFlat.new()
		primary.bg_color = Color("e5384a") if state_name == "normal" else Color("ff4d5e") if state_name == "hover" else Color("a81e2c")
		primary.content_margin_left = 16
		primary.content_margin_right = 16
		_action.add_theme_stylebox_override(state_name, primary)
	_action.add_theme_color_override("font_color", Color.WHITE)
	_action.add_theme_color_override("font_hover_color", Color.WHITE)
	_action.pressed.connect(func() -> void:
		if _memo_seen: start_shift_requested.emit()
		else: navigate_requested.emit("memo"))
	_footer.add_child(_action)

func show_page(day: int, path: String, before_shift: bool) -> void:
	if day != _day: _memo_seen = false
	_day = day
	_page = path
	morning = before_shift
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	if path == "memo":
		_memo_seen = true
		_memo()
	elif path == "standards":
		_standards()
	elif path.begins_with("story/"):
		var story := Press.story(day, path.trim_prefix("story/"))
		if story.is_empty(): _news()
		else: _story(story)
	else: _news()
	_footer.visible = morning
	_status.text = "BEFORE WORK / clock stopped"
	_action.text = "BEGIN SHIFT" if _memo_seen else "READ TODAY'S MEMO"
	_scroll.scroll_vertical = 0

func _text(text: String, font_size: int = 14, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	_content.add_child(label)
	return label

func _link(text: String, target: String, font_size: int = 17) -> void:
	var link := RichTextLabel.new()
	link.bbcode_enabled = true
	link.fit_content = true
	link.scroll_active = false
	link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	link.add_theme_color_override("default_color", INK)
	link.add_theme_font_size_override("normal_font_size", font_size)
	link.text = "[url=%s]%s[/url]" % [target, text]
	link.meta_clicked.connect(func(path: Variant) -> void: navigate_requested.emit(str(path)))
	_content.add_child(link)

func _divider() -> void:
	var line := HSeparator.new()
	_content.add_child(line)

func _masthead() -> void:
	# A boxed "h" logo beside the name, like the site it parodies.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	var badge := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = INK
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 0
	box.content_margin_bottom = 1
	badge.add_theme_stylebox_override("panel", box)
	row.add_child(badge)
	var logo := Label.new()
	logo.text = "h"
	logo.add_theme_font_size_override("font_size", 20)
	logo.add_theme_color_override("font_color", PAPER)
	badge.add_child(logo)
	var name := Label.new()
	name.text = "Hackerish News"
	name.add_theme_font_size_override("font_size", 23)
	name.add_theme_color_override("font_color", INK)
	row.add_child(name)
	_divider()

func _news() -> void:
	_masthead()
	for article: Dictionary in Press.stories(_day):
		_link(str(article.title), "story/" + str(article.id))
		_text(str(article.source) + " · " + str(article.byline), 11, MUTED)
		_divider()

## The full active rulebook, as an intranet page.
func _standards() -> void:
	_text("Active review standards", 22)
	_text("Every change must meet each standard below. Standards are reissued every second morning. Line standards need the offending line; file standards take WHOLE FILE or any line of that file; whole-PR standards take WHOLE FILE on any changed file.", 13, MUTED)
	for rule: Dictionary in Press.Catalog.rules_for_day(_day):
		_divider()
		var marker := "   NEW TODAY" if int(rule.introduced_day) == _day and _day > 1 else "   AMENDED TODAY" if int(rule.amended_day) == _day else ""
		_text("%s  %s%s" % [str(rule.id), str(rule.title), marker], 17)
		_text(str(rule.text), 14)
	# What the latest reissue took away, so an old habit isn't mistaken for a rule.
	var start := Press.Catalog.block_start(_day)
	var retired: Array = Press.Catalog.rules().filter(func(rule: Dictionary) -> bool: return int(rule.get("retired_day", 0)) == start and start > 1)
	if not retired.is_empty():
		_divider()
		_text("NO LONGER IN FORCE", 12, MUTED)
		for rule: Dictionary in retired:
			_text("%s  %s   RETIRED" % [str(rule.id), str(rule.title)], 15, MUTED)
			_text(str(rule.retired), 13, MUTED)

func _story(article: Dictionary) -> void:
	_link("← Front page", "news", 13)
	_text(str(article.title), 22)
	_divider()
	_text(str(article.body), 15)
	var comments: Array = article.get("comments", [])
	if not comments.is_empty():
		_divider()
		_text("DISCUSSION", 12, MUTED)
		for comment: String in comments: _text(comment, 13)

func _memo() -> void:
	var memo := Press.memo(_day)
	if memo.is_empty():
		_text("No memo for this day.")
		return
	_text(str(memo.subject), 23)
	_text("From: Morgan · To: Review desk", 12, MUTED)
	_divider()
	_text(str(memo.body), 14)
	_text("AT YOUR DESK TODAY", 12, MUTED)
	for mechanic: String in memo.mechanics: _text("• " + mechanic, 14)
	_divider()
	if memo.rules.is_empty() and memo.amended.is_empty() and memo.retired.is_empty():
		_text("NO STANDARDS CHANGE TODAY", 12, MUTED)
		_text("Yesterday's standards remain in force, word for word.", 14)
	if not memo.rules.is_empty():
		_text("STANDARDS EFFECTIVE TODAY", 12, MUTED)
		for rule: Dictionary in memo.rules:
			_text(str(rule.id) + "  " + str(rule.title), 16)
			_text(str(rule.text), 14)
	if not memo.amended.is_empty():
		_text("AMENDED TODAY", 12, MUTED)
		for rule: Dictionary in memo.amended:
			_text(str(rule.id) + "  " + str(rule.title), 16)
			_text(str(rule.change), 14)
			_text(str(rule.text), 13, MUTED)
	if not memo.retired.is_empty():
		_text("RETIRED TODAY", 12, MUTED)
		for rule: Dictionary in memo.retired:
			_text(str(rule.id) + "  " + str(rule.title), 16)
			_text(str(rule.retired), 14)
	_text("Every other standard remains in force. INTRANET > STANDARDS has the complete active index.", 12, MUTED)
