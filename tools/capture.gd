extends SceneTree
## Render key screens to PNG for visual review: godot --path . --script res://tools/capture.gd -- <out_dir> [day]
## With a day (2-10), only that later day's screens are captured; without one,
## the opening screens are captured first, then week two's Thursday, then the final evening.
const Main = preload("res://native/main.gd")
const Encounters = preload("res://content/encounters.gd")
var out := "user://captures"
var later_day := 9
var only_later := false

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	if args.size() > 1 and args[1].is_valid_int():
		later_day = clampi(int(args[1]), 2, 10)
		only_later = true
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()

## Jump to a later morning (Helios takes each skipped shift), then capture its
## news, memo, standards, and a PR whose problem is the whole diff.
func _later(app: Node) -> void:
	var Simulation = Main.Simulation
	var Catalog = Main.Simulation.Catalog
	var state: Dictionary = Simulation.initial_state()
	while int(state.day) < later_day and state.phase != "complete":
		state = Simulation.dispatch(Simulation.advance(state, Catalog.shift_seconds()), {"type": "next-day", "choice": "rest"})
	app.tutorial = {}
	app.paused = false
	app.state = state
	app._build_interface()
	app.interface.begin_morning()
	var tag := "day%02d" % later_day
	await _shot("20-%s-morning-news" % tag)
	app.interface._browse("memo")
	await _shot("21-%s-memo" % tag)
	# The standards added, amended, and retired that morning sit below the letter.
	app.interface._daily_reader._scroll.scroll_vertical = 100000
	await _shot("21b-%s-memo-changes" % tag)
	app.interface._finish_morning()
	# Stamp until a PR that breaks a whole-PR standard (or the most standards) is on the desk.
	app.state = Simulation.advance(app.state, 10)
	while not Simulation.active_request(app.state).is_empty():
		var packet: Dictionary = Catalog.packet(app.state, str(app.state.active_request_id))
		if packet.violations.any(func(rule_id: String) -> bool: return rule_id in ["P09", "P10", "P13"]): break
		app.state = Simulation.dispatch(app.state, {"type": "review", "verdict": "approve"})
		app.state = Simulation.advance(app.state, Simulation.DESK_BEAT)
	app._render()
	app.interface._open_app("review")
	await _shot("22-%s-review" % tag)
	var ui = app.interface
	ui._point_at(0)
	await _shot("23-%s-review-whole-file" % tag)
	ui._open_app("browser")
	ui._browse("standards")
	await _shot("24-%s-standards" % tag)
	# Let the rest of the day go to Helios: Morgan's panel carries the handoff.
	app.state = Simulation.advance(app.state, Catalog.shift_seconds())
	app._render()
	await _shot("25-%s-end-of-day" % tag)

func _shot(name: String) -> void:
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(name + ".png"))
	print("captured ", name)

func _run() -> void:
	root.size = Vector2i(1280, 900)
	Main.SaveStore.storage_root = "user://capture-%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(Main.SaveStore.storage_root)
	var app := Main.new()
	root.add_child(app)
	app.set_process(false)
	if only_later:
		await _later(app)
		quit()
		return
	await _shot("01-menu")
	app.menu._new_game.pressed.emit()
	app.menu._slot_buttons[0].pressed.emit()
	app._cold_open.advance_sequence(30.0)
	await _shot("02-cold-open")
	app._cold_open._open_mail(-1)
	app._cold_open._sign_offer()
	app._cold_open.advance_sequence(2.0)
	await _shot("03-orientation")
	app.interface._tutorial_next.pressed.emit()
	# Orientation goes straight to REVIEW: the arrow points at its icon.
	await _shot("03b-orientation-arrow")
	app.interface._home_icons.review.pressed.emit()
	await _shot("03c-orientation-review")
	app._tutorial_continue()
	app.interface._tutorial_next.pressed.emit() if app.interface._tutorial_next.visible else null
	app.tutorial = {}
	app.state = Main.Simulation.initial_state()
	app._build_interface()
	app.interface.begin_morning()
	await _shot("04-morning-news")
	app.interface._browse("memo")
	await _shot("05-memo")
	app.interface._finish_morning()
	var Simulation = Main.Simulation
	var Catalog = Main.Simulation.Catalog
	# The day's first PR is already on the desk; let a little of the shift pass.
	app.state = Simulation.advance(app.state, 25)
	app._render()
	# HOME during the shift: REVIEW's badge and the desk PR's card in the taskbar.
	app.interface._show_home()
	await _shot("06-desktop")
	app.interface._open_notification("review", str(app.state.active_request_id))
	await _shot("07-review")
	app.interface._open_app("browser")
	app.interface._browse("standards")
	await _shot("08-standards")
	app.interface._open_app("review")
	var ui = app.interface
	var request: Dictionary = Catalog.packet(app.state, str(app.state.active_request_id))
	if not request.is_empty() and not request.violations.is_empty():
		var cite: Dictionary = Catalog.audit_citation(request, request.violations[0])
		for index in range(ui._review_files.size()):
			if ui._review_files[index].path == cite.path: ui._select_file(index)
		for i in range(3): await process_frame
		ui._diff.set_caret_line(maxi(0, ui._row_for_line(int(cite.line))))
		ui._point_at(-1 if int(cite.line) > 0 else 0)
		await _shot("09a-flag-box")
		ui._flag_buttons[str(cite.rule_id)].pressed.emit()
	await _shot("09-review-cited")
	app._on_command({"type": "review", "verdict": "request_changes"})
	for i in range(8): await process_frame
	await _shot("10-stamped-desk-clear")
	# The next two PRs land by themselves; then Maya's revision comes back.
	for turn in range(2):
		app.state = Simulation.advance(app.state, Simulation.DESK_BEAT)
		app._render()
		var packet: Dictionary = Catalog.packet(app.state, str(app.state.active_request_id))
		for rule_id: String in packet.violations:
			app._on_command(Catalog.audit_citation(packet, rule_id))
		app._on_command({"type": "review", "verdict": "approve" if packet.violations.is_empty() else "request_changes"})
		for i in range(4): await process_frame
	app.state = Simulation.advance(app.state, Simulation.DESK_BEAT)
	app._render()
	ui._open_app("review")
	ui._packet_scroll.scroll_vertical = 0
	await _shot("11-revision-review")
	app._on_command({"type": "review", "verdict": "approve"})
	for i in range(4): await process_frame
	# Closing: Morgan's end-of-day panel opens by itself with the evening choice.
	app.state = Simulation.advance(app.state, Catalog.shift_seconds())
	app._render()
	await create_timer(1.2).timeout
	await _shot("13-end-of-day")
	# Encounters: an author pushes back on a citation, then another revises at the desk.
	var pushed := _find_branch("pushback")
	if not pushed.is_empty():
		ui = await _stamp_fresh(app, pushed)
		await _beat(ui, 0.6)
		await _shot("15-pushback")
		ui._banter.withdraw_button.pressed.emit()
		await _beat(ui, 0.6)
		await _shot("16-withdrawn")
	var now := _find_branch("revise_now")
	if not now.is_empty():
		ui = await _stamp_fresh(app, now)
		await _beat(ui, 0.6)
		await _shot("17-revise-now")
		await _beat(ui, 2.6)
		await _beat(ui, 0.5)
		await _shot("18-typing")
		app.state = Simulation.advance(app.state, Encounters.REVISE_NOW_SECONDS)
		app._render()
		await _beat(ui, 0.6)
		await _shot("19-revised-v2")
	app._toggle_pause()
	await _shot("14-paused")
	await _later(app)
	await _final(app)
	quit()


## The second Friday after the evening: Morgan's last word and RETURN TO MAIN MENU.
func _final(app: Node) -> void:
	var Simulation = Main.Simulation
	var state: Dictionary = Simulation.initial_state()
	while state.phase != "complete":
		state = Simulation.dispatch(Simulation.advance(state, Simulation.Catalog.shift_seconds()), {"type": "next-day", "choice": "rest"})
	app.tutorial = {}
	app.paused = false
	app.state = state
	app._build_interface()
	await _shot("26-final-end-of-day")


func _settle(frames: int) -> void:
	for i in range(frames): await process_frame


## Let the desk's speech bubble play for `seconds` of game time, as real time would.
func _beat(ui, seconds: float) -> void:
	ui._process(seconds)
	await _settle(4)


## A fresh desk at `found.before`, with the PR opened, cited, and stamped through the app.
func _stamp_fresh(app, found: Dictionary):
	app.state = found.before
	app._build_interface()
	var ui = app.interface
	await _settle(4)
	ui._open_app("review")
	await _settle(4)
	var packet: Dictionary = Main.Simulation.Catalog.packet(app.state, str(app.state.active_request_id))
	for rule_id: String in found.cited:
		var cite: Dictionary = Main.Simulation.Catalog.audit_citation(packet, rule_id)
		for index in range(ui._review_files.size()):
			if ui._review_files[index].path == cite.path: ui._select_file(index)
		app._on_command(cite)
	ui._reject.pressed.emit()
	# Let the rubber stamp finish its real-time tween before the next shot.
	await create_timer(1.5).timeout
	return ui


## Exact reviews through the career until some citation set on the desk PR leads to `node`.
func _find_branch(node: String) -> Dictionary:
	var Simulation = Main.Simulation
	var Catalog = Main.Simulation.Catalog
	var at: Dictionary = Simulation.initial_state()
	var guard := 0
	while at.phase != "complete" and guard < 2000:
		guard += 1
		if at.phase == "debrief":
			at = Simulation.dispatch(at, {"type": "next-day", "choice": "rest"})
			continue
		if Simulation.active_request(at).is_empty():
			var coming: bool = int(at.desk_at) >= 0 and int(at.desk_at) < Catalog.shift_seconds()
			at = Simulation.advance(at, int(at.desk_at) - int(at.shift_seconds) if coming else Catalog.shift_seconds())
			continue
		if not Encounters.pending(at).is_empty():
			at = Simulation.dispatch(at, {"type": "pushback", "choice": "insist"})
			continue
		var packet: Dictionary = Catalog.packet(at, at.active_request_id)
		var ids: Array = Catalog.rules_for_day(int(at.day)).map(func(rule: Dictionary) -> String: return rule.id)
		if int(at.decisions.size()) > 2:
			for rule_id: String in ids:
				var trial: Dictionary = Simulation.dispatch(Simulation.dispatch(at, Catalog.audit_citation(packet, rule_id)), {"type": "review", "verdict": "request_changes"})
				if not trial.encounters.is_empty() and trial.encounters.size() > at.encounters.size() and trial.encounters[-1].node == node:
					return {"before": at, "cited": [rule_id]}
		for rule_id: String in packet.violations:
			at = Simulation.dispatch(at, Catalog.audit_citation(packet, rule_id))
		at = Simulation.dispatch(at, {"type": "review", "verdict": "approve" if packet.violations.is_empty() else "request_changes"})
	return {}
