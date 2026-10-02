extends SceneTree
## Render key screens to PNG for visual review: godot --path . --script res://tools/capture.gd -- <out_dir> [day]
## With a day (2-10), only that later day's screens are captured; without one,
## the opening screens are captured first, then week two's Thursday.
const Main = preload("res://native/main.gd")
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
	app.interface._open_pr_link(str(app.state.active_request_id))
	await _shot("22-%s-review" % tag)
	var ui = app.interface
	ui._point_at(0)
	await _shot("23-%s-review-whole-file" % tag)
	ui._open_app("browser")
	ui._browse("standards")
	await _shot("24-%s-standards" % tag)

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
	await _shot("03b-orientation-arrow")
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
	app.interface._open_app("chat")
	app.interface._select_chat_contact("Maya")
	await _shot("06-slouch")
	app.interface._open_pr_link(str(app.state.active_request_id))
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
	ui._open_pr_link(str(app.state.active_request_id))
	ui._packet_scroll.scroll_vertical = 0
	await _shot("11-revision-review")
	ui._open_app("chat")
	ui._select_chat_contact(str(Catalog.packet(app.state, str(app.state.active_request_id)).get("author", "Maya")))
	await _shot("12-slouch-revision")
	app._on_command({"type": "review", "verdict": "approve"})
	for i in range(4): await process_frame
	ui._select_chat_contact(str(ui._chat_contact))
	await _shot("13-slouch-relief")
	app._toggle_pause()
	await _shot("14-paused")
	await _later(app)
	quit()
