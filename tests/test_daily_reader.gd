extends SceneTree
const Reader = preload("res://native/daily_reader.gd")
const UI = preload("res://native/interface.gd")
const Simulation = preload("res://native/simulation.gd")
const Press = preload("res://content/daily_press.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	load("res://content/catalog.gd").campaign_version = 4
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(1280, 900)
	var ui := UI.new()
	root.add_child(ui)
	ui.render_state(Simulation.initial_state())
	for frame in range(4): await process_frame
	ui.begin_morning()
	check(ui.morning_active and ui._windows.browser.visible and ui._browser_path == "news", "Morning opens the news in the real browser window.")
	check(ui._begin_shift_button.visible and ui._begin_shift_button.disabled and not ui._pause_button.visible, "Morning clock bar exposes Begin Shift but requires the memo first.")
	var links: Array = []
	for child: Node in ui._daily_reader._content.get_children():
		if child is RichTextLabel: links.append(child)
	check(links.size() == 3, "The condensed front page offers three clickable stories.")
	var first: Dictionary = Press.stories(1)[0]
	links[0].meta_clicked.emit("story/" + str(first.id))
	check(ui._browser_path == "story/" + str(first.id), "A front-page headline opens its full article.")
	var body_found := false
	for child: Node in ui._daily_reader._content.get_children():
		if child is Label and child.text == first.body: body_found = true
	check(body_found, "Articles show authored story text rather than a placeholder.")
	ui._browser_go_back()
	check(ui._browser_path == "news", "Browser back returns from an article to the front page.")
	ui._finish_morning()
	check(ui.morning_active, "The morning cannot finish without opening the day's memo.")
	ui._daily_reader._action.pressed.emit()
	check(ui._browser_path == "memo" and ui._daily_reader._action.text == "BEGIN SHIFT", "The morning action opens the memo before offering to start work.")
	check(not ui._begin_shift_button.disabled, "Reading the memo enables the desktop Begin Shift button.")
	for viewport: Vector2i in [Vector2i(1280, 900), Vector2i(1120, 800)]:
		root.size = viewport
		for frame in range(6): await process_frame
		check(ui._daily_reader._scroll.get_h_scroll_bar().max_value <= ui._daily_reader._scroll.size.x + 2, "Memo text wraps inside the browser at %s." % viewport)
		check(ui._windows.browser.get_global_rect().encloses(ui._daily_reader._action.get_global_rect()), "Begin Shift remains visible outside the scrolling memo at %s." % viewport)
		check(ui._monitor_screen.get_global_rect().encloses(ui._begin_shift_button.get_global_rect()), "Desktop start control fits inside the monitor at %s." % viewport)
		check(not ui._windows.browser.get_global_rect().intersects(ui._begin_shift_button.get_global_rect()), "Maximized browser cannot cover the desktop start control at %s." % viewport)
	ui._browse("news")
	check(ui._daily_reader._action.text == "BEGIN SHIFT", "After reading the memo, the player can keep browsing news and start from there.")
	ui._windows.browser.minimize_window()
	check(ui._begin_shift_button.is_visible_in_tree() and not ui._begin_shift_button.disabled, "Begin Shift remains accessible with the browser minimized.")
	ui._begin_shift_button.pressed.emit()
	check(not ui._begin_shift_button.visible and ui._pause_button.visible, "Starting work restores the normal pause control.")
	check(not ui.morning_active and not ui._windows.browser.visible, "Beginning the shift closes the morning reader.")
	ui._open_app("browser")
	ui._browse("news")
	check(not ui._daily_reader._footer.visible, "Reopening the news during work does not offer another shift start.")
	ui._browse("memo")
	check(ui._daily_reader._page == "memo", "The memo remains available during work.")
	ui.free()
	print("Daily reader: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
