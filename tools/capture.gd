extends SceneTree
## Render key screens to PNG for visual review: godot --path . --script res://tools/capture.gd -- <out_dir>
const Main = preload("res://native/main.gd")
var out := "user://captures"

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()

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
	app.state = Main.Simulation.advance(app.state, 70)
	app._render()
	app.interface._open_app("chat")
	await _shot("06-slouch")
	app.interface._open_next_pr()
	await _shot("07-review")
	app.interface._open_app("rules")
	await _shot("08-handbook")
	app.interface._open_app("review")
	var ui = app.interface
	var request: Dictionary = Main.Simulation.Catalog.requests_for_day(1)[0]
	for packet: Dictionary in Main.Simulation.Catalog.requests():
		if packet.id == app.state.active_request_id: request = packet
	if not request.violations.is_empty():
		var cite: Dictionary = Main.Simulation.Catalog.audit_citation(request, request.violations[0])
		for index in range(ui._review_files.size()):
			if ui._review_files[index].path == cite.path: ui._select_file(index)
		for i in range(3): await process_frame
		ui._diff.set_caret_line(maxi(0, int(cite.line) - 1))
		ui._point_at(-1 if int(cite.line) > 0 else 0)
		await _shot("09a-review-pointing")
		ui._open_app("rules")
		await _shot("09b-handbook-evidence")
		ui._toggle_citation(str(cite.rule_id))
		await _shot("09c-handbook-cited")
		ui._open_app("review")
	await _shot("09-review-cited")
	app._on_command({"type": "review", "verdict": "request_changes"})
	for i in range(8): await process_frame
	await _shot("10-stamped")
	app._toggle_pause()
	await _shot("11-paused")
	quit()
