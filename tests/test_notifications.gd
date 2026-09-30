extends SceneTree
const Interface = preload("res://native/interface.gd")
const Simulation = preload("res://native/simulation.gd")
var state: Dictionary
var ui: Interface
var checks := 0
var failures := 0

func _initialize() -> void:
	load("res://content/catalog.gd").campaign_version = 4
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
	check(ui._app_counts.review == 0, "Unarrived PRs must never enter the badge count.")
	check(ui._app_counts.rules == 4 and ui._app_counts.browser == 1, "Handbook and Intranet count actual standards and memos.")
	var initial := ui._app_counts.duplicate()
	ui.render_state(state)
	check(ui._app_counts == initial, "Rerendering cannot create duplicate unread items.")
	var bubble: Dictionary = ui._notifications._items[-1]
	ui._notifications._remove(bubble)
	check(ui._app_counts == initial, "Dismissing a bubble must not mark content read.")
	ui._open_notification("browser", "memo")
	check(ui._browser_path == "memo" and ui._app_counts.browser == 0, "Intranet bubble routes to the memo and clears its badge.")
	ui._open_notification("rules", "")
	check(ui._windows.rules.visible and ui._app_counts.rules == 0, "Handbook notifications open their app and mark standards read.")
	ui._show_home()
	state = Simulation.advance(state, 20)
	ui.render_state(state)
	check(ui._app_counts.review == 1 and ui._app_badges.review.visible, "An arrived PR increments the Review badge.")
	check(not ui._windows.review.visible and not ui._windows.chat.visible, "Notification delivery must not open or raise applications.")
	var chat_total := int(ui._app_counts.chat)
	var maya_unread := int(ui._chat_unread.Maya)
	ui._open_notification("chat", "Maya")
	check(ui._chat_contact == "Maya" and ui._app_counts.chat == chat_total - maya_unread, "Opening a Slouch bubble clears only that conversation.")
	ui._open_notification("review", "PR-1042")
	check(state.active_request_id == "PR-1042" and ui._app_counts.review == 0, "Review bubble opens the exact arrived PR and clears its unread item.")
	var before := int(ui._app_counts.chat)
	command({"type": "chat-reply", "contact": "Maya", "pr_id": "PR-1042", "reply_id": "clarify"})
	check(ui._app_counts.chat == before and ui._waiting_for_reply("Maya"), "No coworker answer or unread badge arrives before the typing delay.")
	check(ui._chat_replies.get_child_count() == 1 and ui._chat_replies.get_child(0) is Label and ui._chat_replies.get_child(0).text.contains("typing"), "Response choices are replaced by a typing indicator until delivery.")
	for frame in range(4): await process_frame
	var left := 0
	var right := 0
	for panel: Node in ui._chat_messages.find_children("*", "PanelContainer", true, false):
		if panel.has_meta("outgoing"):
			if panel.get_meta("outgoing") and panel.get_global_rect().get_center().x > panel.get_parent().get_global_rect().get_center().x: right += 1
			elif not panel.get_meta("outgoing") and panel.get_global_rect().get_center().x < panel.get_parent().get_global_rect().get_center().x: left += 1
	check(left > 0 and right > 0, "Coworker and player messages use distinct left and right bubbles.")
	ui.set_paused(true)
	ui._tick_chat_replies(99)
	check(ui._waiting_for_reply("Maya"), "Paused conversations must not silently deliver the pending response.")
	ui.set_paused(false)
	ui._tick_chat_replies(2.5)
	check(ui._app_counts.chat == before + 1, "A reply behind another window counts the coworker response, not the player's own message.")
	ui.render_state(state)
	check(ui._app_counts.chat == before + 1, "Clock refreshes cannot duplicate an already-seen message.")
	ui.notify("Game saved on this computer.")
	check(ui._app_counts.system == 1 and ui._app_badges.system.visible, "System reports create a badge and a bubble.")
	ui._open_notification("system", "")
	check(ui._app_counts.system == 0 and ui._system_status.text.contains("saved"), "Opening System clears the badge and retains the status message.")
	for index in range(5): ui._notifications.push("chat", "Incoming message", str(index))
	check(ui._notifications._items.size() == 3, "Bubbles are bounded to three visible cards.")
	ui.set_paused(true)
	var remaining: float = ui._notifications._items[0].remaining
	ui._notifications._process(20.0)
	check(ui._notifications._items[0].remaining == remaining, "Paused workstations must preserve notification reading time.")
	for frame in range(8): await process_frame
	check(ui._notifications._stack.position.x > ui._monitor_screen.size.x * 0.5, "Notifications sit on the right of the monitor.")
	check(ui._notifications._stack.position.y + ui._notifications._stack.size.y <= ui._monitor_screen.size.y - 40, "Notification bubbles stay above the taskbar.")
	ui.free()
	print("Desktop notifications: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
