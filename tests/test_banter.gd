extends SceneTree
## Author banter: authored lines, the no-hints rule, and the bubble beside the form.
const Banter = preload("res://content/banter.gd")
const ReviewBanter = preload("res://native/review_banter.gd")
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Interface = preload("res://native/interface.gd")
const Tutorial = preload("res://native/tutorial.gd")
const Encounters = preload("res://content/encounters.gd")
var state: Dictionary
var ui: Interface
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 900)
	_test_lines()
	_test_never_reads_audit_data()
	_test_component()
	await _test_review_desk()
	await _test_flags_sound_the_same()
	await _test_consult()
	await _test_orientation()
	if is_instance_valid(ui): ui.queue_free()
	await process_frame
	print("Author banter: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func _command(command: Dictionary) -> void:
	state = Simulation.dispatch(state, command)
	ui.render_state(state)

func _fresh_ui(snapshot: Dictionary) -> void:
	if is_instance_valid(ui):
		ui.queue_free()
		await process_frame
	state = snapshot
	ui = Interface.new()
	ui.command_requested.connect(_command)
	root.add_child(ui)
	for frame in range(3):
		await process_frame
	ui.render_state(state)

func _test_lines() -> void:
	# Lines may not name a standard or the things standards check for.
	var forbidden := RegEx.create_from_string("(?i)\\b(P\\d\\d|load-bearing|pigeon|urgen\\w*|tabs?|uppercase|lowercase|blue|pink|ink|exclamation|sign-?off|whitespace|filenames?|comments?|record)\\b")
	var font: FontFile = ReviewBanter.TerminalFont
	var wrap_width: float = ReviewBanter.WIDTH - ReviewBanter.SHADOW - ReviewBanter.PAD.x * 2
	for author: String in Banter.AUTHORS:
		for trigger: String in Banter.TRIGGERS:
			var options: Array = Banter.lines(author, trigger)
			check(options.size() >= 6 and options.size() <= 10, "%s needs 6-10 %s lines" % [author, trigger])
			var seen: Dictionary = {}
			for index in range(options.size()):
				var text: String = Banter.line(author, trigger, index)
				var label := "%s/%s: %s" % [author, trigger, text]
				check(not text.strip_edges().is_empty(), "Banter lines are never empty: " + label)
				check(text.length() < 70, "Banter lines stay under 70 characters: " + label)
				check(not text.contains("!"), "Banter stays dry, without exclamation marks: " + label)
				check(forbidden.search(text) == null, "Banter never names a standard or its subject: " + label)
				for rule: Dictionary in Catalog.rules():
					check(not text.contains(str(rule.id)), "Banter never mentions rule IDs: " + label)
				check(not seen.has(text), "Each author's lines are distinct: " + label)
				seen[text] = true
				var rows := roundi(font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, ReviewBanter.FONT_SIZE).y / font.get_height(ReviewBanter.FONT_SIZE))
				check(rows <= 3, "Banter fits the bubble in three rows: " + label)
	check(Banter.line("maya", "open", 0) == Banter.line("Maya", "open", 0), "Author names are case-insensitive")
	check(Banter.line("Theo", "flag", -1) == Banter.line("Theo", "flag", Banter.lines("Theo", "flag").size() - 1), "Indexes wrap around each list")
	check(Banter.line("Morgan", "open", 0).is_empty() and Banter.line("Maya", "unknown", 0).is_empty(), "Unknown authors and triggers say nothing")

func _test_never_reads_audit_data() -> void:
	for path: String in ["res://content/banter.gd", "res://native/review_banter.gd"]:
		var source := FileAccess.get_file_as_string(path)
		for token: String in ["violations", "findings", "explanation", "expected_rules", "ai_verdict", "\"correct\"", ".correct", "Catalog", "policy_campaign"]:
			check(not source.contains(token), "%s must never read audit data (%s)" % [path.get_file(), token])

func _test_component() -> void:
	var banter := ReviewBanter.new()
	root.add_child(banter)
	banter.size = Vector2(ReviewBanter.WIDTH, 150)
	check(not banter.visible, "Nobody sits at an empty desk")
	banter.open_pr("PR-9002", "Maya")
	var said: String = banter.line
	banter.tick(ReviewBanter.LINE_SECONDS + 1.0)
	check(banter.line == said and not banter.is_speaking() and banter._bubble.modulate.a > 0.5, "The last line stays on screen after it has been said")
	banter.close_pr()
	banter.tick(ReviewBanter.LINE_SECONDS + 1.0)
	check(banter.line.is_empty() and not banter.visible, "The lingering line leaves with the author")
	banter.size = Vector2(40, 150)
	banter.open_pr("PR-9001", "Inez")
	banter.size = Vector2(ReviewBanter.WIDTH, 150)
	banter._say("", "", "")
	check(banter.custom_minimum_size.y <= ReviewBanter.PORTRAIT + 16, "The strip shrinks back to the portrait once a line ends, even after a narrow first layout")
	check(banter.get_combined_minimum_size().y <= ReviewBanter.PORTRAIT + 16, "A silent author takes no extra height")
	banter.open_pr("PR-2004-v2", "Maya", 2)
	check(banter.visible and banter.kind == "revision" and banter.line in Banter.lines("Maya", "revision"), "A resubmission opens with a revision line")
	banter.open_pr("PR-3001", "Theo")
	check(banter.speaker == "Theo" and banter.kind == "open" and banter.line in Banter.lines("Theo", "open"), "A fresh PR opens with a greeting")
	var portrait: Control = banter._seat.get_child(0)
	if ResourceLoader.exists(ReviewBanter.PORTRAITS):
		check(portrait.name != "PlaceholderPortrait", "Portraits come from the portraits module once it exists")
	else:
		check(portrait.name == "PlaceholderPortrait" and (portrait.get_child(0) as Label).text == "T", "Without portraits, the author's initial stands in")
	# A verdict and the next PR can land together: goodbye first, then hello.
	var greeting := banter.line
	banter.farewell("Inez", "request_changes", "PR-3000")
	check(banter.speaker == "Inez" and banter.kind == "changes" and banter.line in Banter.lines("Inez", "changes"), "The stamped PR's author reacts to the verdict")
	banter.tick(ReviewBanter.HANDOFF_SECONDS + 0.01)
	check(banter.speaker == "Theo" and banter.line == greeting, "The next author's greeting follows the goodbye")
	banter.close_pr()
	check(not banter.visible, "Closing the PR clears the desk")
	banter.farewell("Maya", "approve", "PR-3002")
	check(banter.visible and banter.kind == "approved" and banter.line in Banter.lines("Maya", "approved"), "An approval gets its own reaction, even with no PR open")
	banter.open_pr("PR-3003", "Inez")
	check(banter.speaker == "Maya", "A goodbye already underway keeps playing")
	banter.tick(ReviewBanter.HANDOFF_SECONDS + 0.01)
	check(banter.speaker == "Inez" and banter.kind == "open", "Then the next author greets")
	banter.close_pr()
	banter.farewell("Theo", "approve", "PR-3003")
	banter.tick(ReviewBanter.LINE_SECONDS + 0.01)
	check(not banter.visible and not banter.is_speaking(), "After a goodbye with no PR open, the desk empties")
	banter.open_pr("PR-3004", "Theo")
	banter.tick(ReviewBanter.LINE_SECONDS + 0.01)
	check(not banter.is_speaking() and banter.visible, "The author stays seated in silence between lines")
	banter.tick(ReviewBanter.IDLE_SECONDS - ReviewBanter.LINE_SECONDS)
	check(banter.kind == "idle" and banter.line in Banter.lines("Theo", "idle"), "A reviewer who does nothing gets nudged")
	var nudge := banter.line
	banter.tick(ReviewBanter.IDLE_SECONDS + 0.01)
	check(banter.kind == "idle" and banter.line != nudge, "Repeated nudges vary")
	banter.queue_free()

func _test_review_desk() -> void:
	# The beat between a stamp and the next PR landing leaves the desk empty.
	await _fresh_ui(Simulation.dispatch(Simulation.initial_state(), {"type": "review", "verdict": "approve"}))
	check(not ui._banter.visible, "No author sits beside the form while no PR is open")
	await _fresh_ui(Simulation.initial_state())
	state = Simulation.advance(state, 20)
	ui.render_state(state)
	var packet: Dictionary = Catalog.request_at(0)
	var author := str(packet.author)
	ui._open_pr_link(str(packet.id))
	var pitch: Array = Encounters.desk_lines(packet, "pitch", Encounters.mood(state, author))
	check(ui._banter.visible and ui._banter.speaker == author and ui._banter.kind == "open" and ui._banter.line in pitch, "Opening a PR shows a bubble from its author")
	for frame in range(8):
		await process_frame
	check(ui._banter._bubble.modulate.a > 0.0, "The bubble fades in")
	for extent: Vector2i in [Vector2i(1120, 800), Vector2i(1280, 900)]:
		root.size = extent
		for frame in range(4):
			await process_frame
		ui._arrange_windows()
		for frame in range(3):
			await process_frame
		var bubble := _bubble_rect()
		check(bubble.has_area(), "The bubble has a footprint at %s" % extent)
		for target: Control in [ui._paper, ui._diff, ui._approve, ui._reject, ui._file_picker]:
			check(not bubble.intersects(target.get_global_rect()), "The bubble never covers %s at %s" % [target.name, extent])
		check(ui._banter.get_global_rect().encloses(bubble), "The bubble stays inside the author's column")
		check(ui._diff.size.y >= 100, "Code keeps readable height beside the author at %s" % extent)
	# Flag the line with the phrase; the box opens on the code, clear of the bubble.
	var greeting: String = ui._banter.line
	var cite: Dictionary = Catalog.audit_citation(packet, "P01")
	_point_at(str(cite.path), int(cite.line))
	await process_frame
	check(not _bubble_rect().intersects(ui._flag_buttons.P01.get_global_rect()), "The bubble never covers the citation slip")
	ui._flag_buttons.P01.pressed.emit()
	var flag_lines: Array = Encounters.desk_lines(packet, "flag", Encounters.mood(state, author), ["P01"], "P01")
	check(ui._banter.kind == "flag" and ui._banter.line != greeting and ui._banter.line in flag_lines, "Flagging a line changes the bubble to a defensive reaction")
	var first_flag: String = ui._banter.line
	_point_at(str(cite.path), 1 if int(cite.line) != 1 else 2)
	ui._flag_buttons.P02.pressed.emit()
	check(ui._banter.kind == "flag" and ui._banter.line != first_flag and ui._banter.line in Banter.lines(author, "flag"), "Each flag gets a fresh reaction")
	# With nothing selected, ticking a cited rule again withdraws it.
	ui._flag_buttons.P02.pressed.emit()
	check(ui._banter.kind == "withdraw" and ui._banter.line in Banter.lines(author, "withdraw"), "Withdrawing a citation gets relief or smugness")
	ui._clear_citations()
	check(state.selected_rules.is_empty() and ui._banter.kind == "withdraw", "CLEAR withdraws too")
	# Idle time counts only while the shift runs.
	ui.set_paused(true)
	ui._process(ReviewBanter.IDLE_SECONDS * 3)
	check(ui._banter.idle_seconds == 0.0 and ui._banter.kind == "withdraw", "The idle timer doesn't advance while paused")
	ui.set_paused(false)
	ui._process(ReviewBanter.LINE_SECONDS + 0.01)
	check(not ui._banter.is_speaking() and ui._banter.idle_seconds > 0.0, "Unpaused time advances the idle timer")
	ui._process(ReviewBanter.IDLE_SECONDS)
	check(ui._banter.kind == "idle" and ui._banter.line in Banter.lines(author, "idle"), "An idle reviewer gets an impatient nudge")
	# The stamp: the author reacts to the verdict, then leaves the empty desk.
	for rule_id: String in packet.violations:
		_command(Catalog.audit_citation(packet, rule_id))
	(ui._reject if not packet.violations.is_empty() else ui._approve).pressed.emit()
	var verdict_trigger := "changes" if not packet.violations.is_empty() else "approved"
	check(ui._banter.visible and ui._banter.speaker == author and ui._banter.kind == verdict_trigger and not ui._banter.line.is_empty(), "Stamping gets a reaction from the author")
	ui._process(ReviewBanter.LINE_SECONDS + 0.01)
	check(not ui._banter.visible, "The author leaves once no PR is open")
	root.size = Vector2i(1280, 900)

func _test_flags_sound_the_same() -> void:
	# The same visible action on the same PR always gets the same words,
	# whether the flag points at the real evidence or somewhere wrong.
	var packet: Dictionary = Catalog.request_at(0)
	var cite: Dictionary = Catalog.audit_citation(packet, "P01")
	var heard: Array[String] = []
	for line_number: int in [int(cite.line), 1 if int(cite.line) != 1 else 2]:
		await _fresh_ui(Simulation.advance(Simulation.initial_state(), 20))
		ui._open_pr_link(str(packet.id))
		_point_at(str(cite.path), line_number)
		ui._flag_buttons.P01.pressed.emit()
		check(ui._banter.kind == "flag", "Both flags get a reaction")
		heard.append(ui._banter.line)
	check(heard[0] == heard[1], "A right flag and a wrong flag sound exactly the same")

func _test_consult() -> void:
	var snapshot := Simulation.initial_state()
	while int(snapshot.day) < 3:
		snapshot = Simulation.advance(snapshot, Catalog.shift_seconds())
		snapshot = Simulation.dispatch(snapshot, {"type": "next-day", "choice": "rest"})
	await _fresh_ui(Simulation.advance(snapshot, 20))
	var packet: Dictionary = Simulation.available_requests(state)[0]
	ui._open_pr_link(str(packet.id))
	check(ui._consult.visible and not ui._consult.disabled, "Helios is available on Wednesday")
	ui._consult.pressed.emit()
	var consult_lines: Array = Encounters.desk_lines(packet, "consult", Encounters.mood(state, str(packet.author)))
	check(state.consulted and ui._banter.kind == "consult" and ui._banter.line in consult_lines, "Asking Helios gets a reaction to being second-guessed")

func _test_orientation() -> void:
	await _fresh_ui(Tutorial.initial_practice_state())
	var progress := Tutorial.initial_progress()
	progress.stage = 3
	ui.render_tutorial(progress, Tutorial.prompt(progress))
	var packet: Dictionary = Catalog.request_at(0)
	ui._open_pr_link(str(packet.id))
	check(ui._banter.speaker == "Maya" and ui._banter.kind == "open", "Orientation keeps one greeting from Maya")
	var cite: Dictionary = Catalog.audit_citation(packet, "P01")
	_point_at(str(cite.path), int(cite.line))
	ui._flag_buttons.P01.pressed.emit()
	check(ui._banter.kind == "open", "Orientation flags get no reaction")
	ui._process(ReviewBanter.LINE_SECONDS + 0.01)
	ui._process(ReviewBanter.IDLE_SECONDS * 2)
	check(not ui._banter.is_speaking() and ui._banter.visible, "Orientation has no idle nudges, but Maya stays seated")
	ui._windows.review.close_window()
	ui._open_pr_link(str(packet.id))
	check(not ui._banter.is_speaking(), "Maya greets only once during orientation")
	ui._reject.pressed.emit()
	check(not ui._banter.is_speaking(), "Orientation stamps get no reaction")

func _point_at(path: String, line_number: int) -> void:
	for index in range(ui._review_files.size()):
		if ui._review_files[index].path == path: ui._select_file(index)
	if line_number <= 0:
		ui._point_at(0)
		return
	ui._diff.set_caret_line(ui._row_for_line(line_number))
	ui._point_at(-1)

func _bubble_rect() -> Rect2:
	var local: Rect2 = ui._banter.bubble_rect()
	return Rect2(ui._banter.get_global_rect().position + local.position, local.size)
