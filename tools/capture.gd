extends SceneTree
## Render key screens to PNG for visual review: godot --path . --script res://tools/capture.gd -- <out_dir> [day]
## With a day (1-10), only that day's screens are captured; without one,
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
		later_day = clampi(int(args[1]), 1, 10)
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
	# Stamp until a PR that breaks a whole-PR standard is on the desk or, on days
	# before those standards exist, one that breaks two standards at once.
	app.state = Simulation.advance(app.state, 10)
	var opening: Dictionary = app.state
	var whole_pr: Array = Main.Simulation.Policy.PR_SCOPED
	var any_whole_pr: bool = whole_pr.any(func(rule_id: String) -> bool: return Catalog.rule_active(rule_id, int(app.state.day)))
	while not Simulation.active_request(app.state).is_empty():
		var packet: Dictionary = Catalog.packet(app.state, str(app.state.active_request_id))
		if packet.violations.any(func(rule_id: String) -> bool: return rule_id in whole_pr): break
		if not any_whole_pr and packet.violations.size() >= 2: break
		app.state = Simulation.dispatch(app.state, {"type": "review", "verdict": "approve"})
		app.state = Simulation.advance(app.state, Simulation.DESK_BEAT)
	# The skipped stamps all landed at once; start a fresh desk so the PR's own
	# author greets you, rather than the last skipped author saying goodbye.
	app._build_interface()
	await _settle(4)
	app.interface._open_app("review")
	await _beat(app.interface, 0.4)
	await _shot("22-%s-review" % tag)
	var ui = app.interface
	ui._point_at(0)
	await _shot("23-%s-review-whole-file" % tag)
	ui._open_app("browser")
	ui._browse("standards")
	await _shot("24-%s-standards" % tag)
	# Back to the start of the shift, on a fresh desktop, for the PR's ticket and build.
	app.state = opening
	app._build_interface()
	await _records(app, tag)
	# Let the rest of the day go to Helios: Morgan's panel carries the handoff.
	app.state = Simulation.advance(app.state, Catalog.shift_seconds())
	app._render()
	await _shot("25-%s-end-of-day" % tag)

## Jiro and Pipeline on a PR whose ticket or build breaks a standard: open each
## from the PR slip, SELECT AS EVIDENCE, and tick the standard on the slip.
func _records(app: Node, tag: String) -> void:
	var Simulation = Main.Simulation
	var Catalog = Main.Simulation.Catalog
	var Policy = Main.Simulation.Policy
	if int(app.state.day) < Policy.JIRO_DAY: return
	while app.state.phase == "review":
		if Simulation.active_request(app.state).is_empty():
			if int(app.state.desk_at) < 0: return
			app.state = Simulation.advance(app.state, int(app.state.desk_at) - int(app.state.shift_seconds))
			continue
		if not Encounters.pending(app.state).is_empty():
			app.state = Simulation.dispatch(app.state, {"type": "pushback", "choice": "insist"})
			continue
		var packet: Dictionary = Catalog.packet(app.state, str(app.state.active_request_id))
		var tickets: Array = packet.violations.filter(func(rule_id: String) -> bool: return rule_id in Policy.TICKET_SCOPED)
		var builds: Array = packet.violations.filter(func(rule_id: String) -> bool: return rule_id in Policy.BUILD_SCOPED)
		if not tickets.is_empty() and (not builds.is_empty() or int(app.state.day) < Policy.PIPELINE_DAY): break
		app.state = Simulation.dispatch(app.state, {"type": "review", "verdict": "approve"})
	if app.state.phase != "review": return
	app._render()
	var ui = app.interface
	var packet: Dictionary = Catalog.packet(app.state, str(app.state.active_request_id))
	ui._open_app("review")
	await _shot("26-%s-review-record-links" % tag)
	ui._ticket_link.pressed.emit()
	await _shot("27-%s-jiro" % tag)
	ui._jiro_search.text = "PAPER-1"
	ui._render_jiro_list()
	await _shot("27b-%s-jiro-search" % tag)
	ui._jiro_search.text = ""
	ui._open_desk_ticket()
	for button: Node in ui._jiro_detail.find_children("*", "Button", true, false):
		if str(button.text).begins_with("SELECT"): button.pressed.emit()
	await _shot("28-%s-ticket-selected" % tag)
	var ticket_rule: String = packet.violations.filter(func(rule_id: String) -> bool: return rule_id in Policy.TICKET_SCOPED)[0]
	ui._flag_buttons[ticket_rule].pressed.emit()
	await _shot("29-%s-ticket-cited" % tag)
	if int(app.state.day) < Policy.PIPELINE_DAY: return
	ui._build_link.pressed.emit()
	await _shot("30-%s-pipeline" % tag)
	for button: Node in ui._pipeline_detail.find_children("*", "Button", true, false):
		if str(button.text).begins_with("SELECT"): button.pressed.emit()
	var build_rule: String = packet.violations.filter(func(rule_id: String) -> bool: return rule_id in Policy.BUILD_SCOPED)[0]
	ui._flag_buttons[build_rule].pressed.emit()
	await _shot("31-%s-build-cited" % tag)
	ui._open_app("pipeline")
	await _shot("32-%s-pipeline-cited" % tag)


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
	await _story(app)
	quit()


## The Helios-takeover screens: a payload on the desk, a reason-free rejection,
## Morgan announcing a coworker's firing, and the ending cinematics.
func _story(app: Node) -> void:
	var Simulation = Main.Simulation
	var Catalog = Main.Simulation.Catalog
	# A payload PR on the desk, with its author pleading in the bubble.
	var at: Dictionary = Simulation.initial_state()
	var guard := 0
	while at.phase != "complete" and guard < 4000:
		guard += 1
		if at.phase == "debrief":
			at = Simulation.dispatch(at, {"type": "next-day", "choice": "rest"}); continue
		if not Encounters.pending(at).is_empty():
			at = Simulation.dispatch(at, {"type": "pushback", "choice": "insist"}); continue
		if Simulation.active_request(at).is_empty():
			var coming: bool = int(at.desk_at) >= 0 and int(at.desk_at) < Catalog.shift_seconds()
			at = Simulation.advance(at, int(at.desk_at) - int(at.shift_seconds) if coming else Catalog.shift_seconds()); continue
		var packet: Dictionary = Catalog.packet(at, at.active_request_id)
		if packet.get("payload", false): break
		for rule_id: String in packet.violations: at = Simulation.dispatch(at, Catalog.audit_citation(packet, rule_id))
		at = Simulation.dispatch(at, {"type": "review", "verdict": "approve" if packet.violations.is_empty() else "request_changes"})
	app.tutorial = {}
	app.paused = false
	app.state = at
	app._build_interface()
	var ui = app.interface
	ui._open_app("review")
	await _beat(ui, 0.6)
	# Point at the one unreadable line so P15 reads clearly in the shot.
	var payload: Dictionary = Catalog.packet(app.state, str(app.state.active_request_id))
	for finding: Dictionary in payload.get("findings", []):
		if finding.rule_id == "P15":
			ui._diff.set_caret_line(maxi(0, ui._row_for_line(int(finding.line))))
			ui._point_at(-1)
			break
	await _shot("30-payload-review")
	# A reason-free rejection of a normal PR: the author reacts to the silence.
	var fresh: Dictionary = Simulation.initial_state()
	app.state = fresh
	app._build_interface()
	ui = app.interface
	ui._open_app("review")
	await _beat(ui, 0.6)
	app._on_command({"type": "review", "verdict": "request_changes"})
	await _beat(ui, 0.8)
	await _shot("31-no-reason")
	# Morgan's end-of-day panel announcing a coworker's firing.
	var fired: Dictionary = Simulation.initial_state()
	fired = Simulation.dispatch(fired, {"type": "next-day", "choice": "rest"}) if false else fired
	while int(fired.day) < 4 and fired.phase != "complete":
		fired = Simulation.dispatch(Simulation.advance(fired, Catalog.shift_seconds()), {"type": "next-day", "choice": "rest"})
	fired = Simulation.advance(fired, Catalog.shift_seconds())
	var fday := int(fired.shift_history[-1].day) if not fired.shift_history.is_empty() else int(fired.day)
	fired.strikes = [{"name": "Theo", "day": fday, "reason": "a defect of theirs you approved shipped"}]
	fired.firings = [{"name": "Theo", "seat": "Theo", "day": fday, "reason": "a defect of theirs you approved shipped"}]
	app.state = fired
	app._build_interface()
	await create_timer(0.8).timeout
	await _shot("32-firing-panel")
	# An ending cinematic (a matrix ending), mid-beat and then its final card.
	await _cinematic(app, "helios_prime", "33-ending")
	# A firing cinematic: the player is let go (red eyes).
	await _cinematic(app, "player_fired", "35-player-fired")


func _cinematic(app: Node, ending: String, tag: String) -> void:
	var Simulation = Main.Simulation
	var Catalog = Main.Simulation.Catalog
	var state: Dictionary = Simulation.initial_state()
	state.phase = "complete"
	state.day = int(Catalog.campaign_days()[-1])
	state.ending = ending
	state.shift_history = [{"day": state.day, "shift_seconds": Catalog.shift_seconds(), "reviewed": 0, "handed_off": 0}]
	app.tutorial = {}
	app.paused = false
	app.state = state
	app._build_interface()
	await _settle(4)
	app.interface._play_ending()
	var cine = app.interface._ending_cinematic
	if cine == null: return
	cine._process(0.1)
	cine._process(3.1)
	await _settle(3)
	await _shot("%s-cinematic" % tag)
	# Fast-forward to the final title card.
	for i in range(10): cine._process(3.1)
	await _settle(3)
	await _shot("%s-card" % tag)


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
