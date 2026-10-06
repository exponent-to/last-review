extends SceneTree
const Interface = preload("res://native/interface.gd")
const Simulation = preload("res://native/simulation.gd")
var state: Dictionary
var ui: Interface
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func command(value: Dictionary) -> void:
	state = Simulation.dispatch(state, value)
	ui.render_state(state)

func _run() -> void:
	root.size = Vector2i(1280, 900)
	ui = Interface.new()
	root.add_child(ui)
	ui.command_requested.connect(command)
	state = Simulation.initial_state()
	ui.render_state(state)
	check(ui._app_counts.review == 1, "The PR waiting on the desk enters the badge count.")
	check(not ui._app_counts.has("rules") and ui._app_counts.browser == 2, "The intranet counts the new standards and the memo.")
	var initial := ui._app_counts.duplicate()
	ui.render_state(state)
	check(ui._app_counts == initial, "Rerendering cannot create duplicate unread items.")
	var bubble: Dictionary = ui._notifications._items[-1]
	ui._notifications._remove(bubble)
	check(ui._app_counts == initial, "Dismissing a bubble must not mark content read.")
	ui._open_notification("browser", "memo")
	check(ui._browser_path == "memo" and ui._app_counts.browser == 0, "Intranet bubble routes to the memo and clears its badge.")
	ui._open_notification("browser", "standards")
	check(ui._windows.browser.visible and ui._browser_path == "standards", "Standards notifications open the intranet standards page.")
	ui._show_home()
	state = Simulation.advance(state, 20)
	ui.render_state(state)
	check(ui._app_counts.review == 1 and ui._app_badges.review.visible, "Waiting never adds PRs: the desk badge stays at one.")
	check(not ui._windows.review.visible, "Notification delivery must not open or raise applications.")
	check(not ui._app_counts.has("chat") and ui._app_counts.keys() == ["review", "browser", "system"], "Only Review, Intranet, and System have notification sources.")
	for item: Dictionary in ui._notifications._items:
		check(not item.card.tooltip_text.contains("Your team has left you messages") and not item.card.tooltip_text.contains("SLOUCH"), "No Slouch cards or team-message summaries.")
	ui._open_notification("review", "PR-2001")
	check(state.active_request_id == "PR-2001" and ui._windows.review.visible and ui._app_counts.review == 0, "Review bubble opens the PR on the desk and clears its badge.")
	command({"type": "chat-reply", "contact": "Maya", "pr_id": "PR-2001", "reply_id": "clarify"})
	ui.render_state(state)
	check(not ui._notifications._items.any(func(item: Dictionary) -> bool: return item.app not in ["review", "browser", "system"]), "Archived chat replies never reach the desktop.")
	command({"type": "review", "verdict": "approve"})
	check(ui._app_counts.review == 0 and not ui._app_badges.review.visible, "An empty desk shows no review badge.")
	# The PR from a stale card is gone, but the card still leads to the desk.
	ui._show_home()
	ui._open_notification("review", "PR-2001")
	check(ui._windows.review.visible and ui._pr_id.text == "REVIEW / DESK CLEAR", "A review card always opens Review, even after its PR was stamped.")
	ui._windows.review.minimize_window()
	ui._show_home()
	state = Simulation.advance(state, Simulation.DESK_BEAT)
	ui.render_state(state)
	check(ui._app_counts.review == 1 and ui._notifications._items.any(func(item: Dictionary) -> bool: return item.app == "review" and item.target == state.active_request_id), "The next PR landing on the desk shows a badge of one and a bubble.")
	var author := str(Simulation.active_request(state).author)
	var desk_card: Array = ui._notifications._items.filter(func(item: Dictionary) -> bool: return item.app == "review" and item.target == state.active_request_id)
	check(desk_card.size() == 1 and str(desk_card[0].card.get_meta("person", "")) == author.to_lower() and desk_card[0].card.tooltip_text.contains(author), "The desk PR's card names its author and carries their face.")
	ui._open_app("review")
	check(ui._app_counts.review == 0, "Looking at Review reads the PR on the desk.")
	command({"type": "review", "verdict": "approve"})
	state = Simulation.advance(state, Simulation.DESK_BEAT)
	ui.render_state(state)
	check(ui._app_counts.review == 0, "A PR that lands while Review is open is already read.")
	ui.notify("Game saved on this computer.")
	check(ui._app_counts.system == 1 and ui._app_badges.system.visible, "System reports create a badge and a bubble.")
	ui._open_notification("system", "")
	check(ui._app_counts.system == 0 and ui._system_status.text.contains("saved"), "Opening System clears the badge and retains the status message.")
	for index in range(5): ui._notifications.push("system", "Incoming message", str(index))
	check(ui._notifications._items.size() == 3, "Bubbles are bounded to three visible cards.")
	ui.set_paused(true)
	var remaining: float = ui._notifications._items[0].remaining
	ui._notifications._process(20.0)
	check(ui._notifications._items[0].remaining == remaining, "Paused workstations must preserve notification reading time.")
	for frame in range(8): await process_frame
	check(ui._notifications._stack.position.x > ui._monitor_screen.size.x * 0.5, "Notifications sit on the right of the monitor.")
	var stack: Control = ui._notifications._stack
	check(stack.position.y + stack.size.y <= ui._monitor_screen.size.y and stack.position.y >= ui._monitor_screen.size.y - 48, "Notifications ride in the taskbar instead of covering work.")
	var shown := 0
	for item: Dictionary in ui._notifications._items: shown += 1 if item.card.visible else 0
	check(shown == 1 and ui._notifications._items[-1].card.visible, "The ticker shows only the newest notification.")
	ui.free()
	print("Desktop notifications: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
