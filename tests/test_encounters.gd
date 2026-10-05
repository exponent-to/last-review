extends SceneTree
## Encounter flow charts: the graph, mood, every author's lines, the no-hints rule
## (by counterfactual), pushback, revise-now, abandon, escalation, replay, and the
## desk controls that go with them.
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Policy = preload("res://content/policy_campaign.gd")
const Chat = preload("res://content/chat.gd")
const Encounters = preload("res://content/encounters.gd")
const Lines = preload("res://content/encounter_lines.gd")
const Banter = preload("res://content/banter.gd")
const ReviewBanter = preload("res://native/review_banter.gd")
const Interface = preload("res://native/interface.gd")

## Nodes where the author speaks at the desk; each needs lines for every author and mood.
const DESK_NODES: Array[String] = ["pitch", "return", "revised", "flag", "unflag", "consult", "thanks", "suspicious", "relief",
	"revise_now", "revise_later", "pushback", "abandon", "escalate", "insist_revise", "insist_escalate", "withdrawn"]
## Slouch messages that follow a beat.
const DM_NODES: Array[String] = ["thanks", "suspicious", "relief", "revise_now", "revise_later", "withdrawn",
	"insist_revise", "insist_escalate", "abandon", "grudge", "escalate"]
const OUTCOMES: Array[String] = ["thanks", "suspicious", "relief", "revise_now", "revise_later", "pushback", "abandon",
	"escalate", "insist_revise", "insist_escalate", "withdrawn"]

var checks := 0
var failures := 0
var state: Dictionary
var ui: Interface

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	root.size = Vector2i(1280, 900)
	_test_graph()
	_test_lines()
	_test_line_hygiene()
	_test_overrides()
	_test_never_reads_audit()
	_test_mood()
	_test_reachable_in_play()
	_test_determinism()
	_test_counterfactuals()
	_test_pushback()
	_test_revise_now()
	_test_abandon_and_escalate()
	_test_saves()
	_test_slouch()
	await _test_desk_controls()
	if is_instance_valid(ui): ui.queue_free()
	await process_frame
	print("Encounter checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

# --- Helpers ----------------------------------------------------------------------

func _desk(at: Dictionary) -> String:
	return str(Simulation.active_request(at).get("id", ""))

func _land(at: Dictionary) -> Dictionary:
	if not _desk(at).is_empty() or int(at.desk_at) < 0 or int(at.desk_at) >= Catalog.shift_seconds(): return at
	return Simulation.advance(at, int(at.desk_at) - int(at.shift_seconds))

## Cite `cited` (fresh: leftovers are cleared first) at real evidence when it exists, then stamp.
func _stamp(at: Dictionary, cited: Array, evidence: Dictionary = {}) -> Dictionary:
	var next := at
	for rule_id: String in next.selected_rules.duplicate():
		next = Simulation.dispatch(next, {"type": "toggle-rule", "rule_id": rule_id})
	var packet: Dictionary = Catalog.packet(next, next.active_request_id)
	for rule_id: String in cited:
		var command: Dictionary = Catalog.audit_citation(packet, rule_id)
		if evidence.has(rule_id): command.merge(evidence[rule_id], true)
		next = Simulation.dispatch(next, command)
	return Simulation.dispatch(next, {"type": "review", "verdict": "request_changes" if not cited.is_empty() else "approve"})

func _beat(at: Dictionary) -> Dictionary:
	return at.encounters[-1] if not at.encounters.is_empty() else {}

func _sets(day: int) -> Array:
	var ids: Array = Catalog.rules_for_day(day).map(func(rule: Dictionary) -> String: return rule.id)
	var result: Array = []
	for first in range(ids.size()):
		result.append([ids[first]])
		for second in range(first + 1, ids.size()): result.append([ids[first], ids[second]])
	return result

func _round_trip(at: Dictionary, label: String) -> void:
	var raw: String = Simulation.serialize_save(at)
	_check(not raw.is_empty(), "Encounter state serializes: " + label)
	var loaded: Dictionary = Simulation.validate_save(JSON.parse_string(raw))
	_check(loaded.ok and loaded.state == at, "Encounter state survives a JSON save round trip: " + label)

## Play the career with a strategy: (state, packet) -> cited rules, and (state, pushback) -> answer.
func _play(cite: Callable, answer: Callable, last_day: int = 99) -> Dictionary:
	var at := Simulation.initial_state()
	var guard := 0
	while at.phase != "complete" and guard < 4000:
		guard += 1
		if at.phase == "debrief":
			if int(at.day) >= last_day and last_day < int(Catalog.campaign_days()[-1]): break
			at = Simulation.dispatch(at, {"type": "next-day", "choice": "rest"})
			continue
		if _desk(at).is_empty():
			var coming: bool = int(at.desk_at) >= 0 and int(at.desk_at) < Catalog.shift_seconds()
			at = Simulation.advance(at, int(at.desk_at) - int(at.shift_seconds) if coming else Catalog.shift_seconds())
			continue
		var pending := Encounters.pending(at)
		if not pending.is_empty():
			at = Simulation.dispatch(at, {"type": "pushback", "choice": answer.call(at, pending)})
			continue
		at = _stamp(at, cite.call(at, Catalog.packet(at, at.active_request_id)))
	_check(guard < 4000, "A strategy finishes its career.")
	return at

func _exact(_at: Dictionary, packet: Dictionary) -> Array:
	return packet.violations

## Walk the career with exact reviews until some citation set on the desk PR leads to
## `node`; returns {before, after, cited} or {}.
func _find(node: String, wanted: Callable = Callable()) -> Dictionary:
	var at := Simulation.initial_state()
	var guard := 0
	while at.phase != "complete" and guard < 3000:
		guard += 1
		if at.phase == "debrief":
			at = Simulation.dispatch(at, {"type": "next-day", "choice": "rest"})
			continue
		if _desk(at).is_empty():
			var coming: bool = int(at.desk_at) >= 0 and int(at.desk_at) < Catalog.shift_seconds()
			at = Simulation.advance(at, int(at.desk_at) - int(at.shift_seconds) if coming else Catalog.shift_seconds())
			continue
		if not Encounters.pending(at).is_empty():
			at = Simulation.dispatch(at, {"type": "pushback", "choice": "insist"})
			continue
		var packet: Dictionary = Catalog.packet(at, at.active_request_id)
		if not wanted.is_valid() or wanted.call(at, packet):
			for cited: Array in [[]] + _sets(int(at.day)):
				var after := _stamp(at, cited)
				if _beat(after).get("node", "") == node and after.encounters.size() > at.encounters.size():
					return {"before": at, "after": after, "cited": cited}
		at = _stamp(at, packet.violations)
	return {}

# --- The graph --------------------------------------------------------------------

func _test_graph() -> void:
	var nodes: Dictionary = Encounters.NODES
	var outgoing := {}
	for edge: Dictionary in Encounters.EDGES:
		_check(nodes.has(edge.from) and nodes.has(edge.to), "Every edge joins two nodes: %s -> %s" % [edge.from, edge.to])
		if not outgoing.has(edge.from): outgoing[edge.from] = []
		outgoing[edge.from].append(edge.to)
		if edge.has("pick"):
			for author: String in Encounters.AUTHORS:
				for mood: String in Encounters.MOODS:
					_check(Encounters.PICKS[edge.pick][author][mood].has(edge.to), "Weighted edge %s -> %s has a weight for %s/%s" % [edge.from, edge.to, author, mood])
	# Every node is reachable from the PR landing on the desk.
	var seen := {"lands": true}
	var frontier: Array = ["lands"]
	while not frontier.is_empty():
		var node: String = frontier.pop_front()
		for next: String in outgoing.get(node, []):
			if not seen.has(next):
				seen[next] = true
				frontier.append(next)
	for node: String in nodes:
		_check(seen.has(node), "Node %s is reachable in the flow chart" % node)
		_check(nodes[node].stage >= 0 and not str(nodes[node].label).is_empty(), "Node %s has a stage and a label" % node)
	for pick: String in Encounters.PICKS:
		for author: String in Encounters.AUTHORS:
			for mood: String in Encounters.MOODS:
				var weights: Dictionary = Encounters.weights(pick, author, mood)
				for branch: String in weights:
					_check(int(weights[branch]) > 0, "Every branch of %s is possible for %s when %s (%s)" % [pick, author, mood, branch])
	var odds := Encounters.odds("changes", "Theo", "hostile")
	var total := 0
	for branch: String in odds: total += int(odds[branch])
	_check(absi(total - 100) <= 2, "Odds are percentages")
	# Leans follow what was cited, by category; piling on makes giving up likelier.
	var plain := Encounters.weights("changes", "Maya", "neutral", ["P05"])
	_check(int(plain.revise_now) > int(Encounters.weights("changes", "Maya", "neutral").revise_now), "Citing paperwork leans toward a quick fix")
	for rule: Dictionary in Catalog.rules():
		_check(Encounters.LEANS.has(str(rule.category)), "Citing %s leans the branch by its category (%s)" % [rule.id, rule.category])
		_check(Policy.CITED_WORDS.has(rule.id) and not Encounters.noun(str(rule.id)).contains(str(rule.id)), "%s has plain words for what was cited" % rule.id)
	var piled := Encounters.weights("changes", "Maya", "neutral", ["P01", "P02", "P03"])
	_check(int(piled.abandon) > int(Encounters.weights("changes", "Maya", "neutral").abandon), "Citing many standards at once makes abandoning likelier")

# --- Lines ------------------------------------------------------------------------

func _test_lines() -> void:
	var bare := {"id": "PR-TEST", "author": "", "title": "(not in the bank)"}
	for author: String in Encounters.AUTHORS:
		bare.author = author
		for node: String in DESK_NODES:
			for mood: String in Encounters.MOODS:
				var options: Array = Encounters.desk_lines(bare, node, mood, ["P01"], "P01")
				_check(options.size() >= 3, "%s has desk lines for %s when %s" % [author, node, mood])
		for node: String in DM_NODES:
			for mood: String in Encounters.MOODS:
				var beat := {"pr_id": "PR-1042", "author": author, "day": 1, "version": 3 if node == "escalate" else (2 if node == "relief" else 1),
					"mood": mood, "node": node, "cited": ["P01"], "shift_seconds": 10, "seq": 1, "disputed": "P01"}
				var text := Encounters.dm_text(beat, Catalog.request_at(0), node)
				_check(not text.is_empty(), "%s has a Slouch message for %s when %s" % [author, node, mood])
	for node: String in ["escalate", "insist_escalate", "abandon"]:
		for mood: String in Encounters.MOODS:
			_check(not Lines.morgan(node, mood).is_empty(), "Morgan has a note for %s when the author is %s" % [node, mood])
	# Authored cells: exactly three desk lines and two Slouch lines per mood.
	for author: String in Encounters.AUTHORS:
		for channel: String in ["desk", "dm"]:
			for node: String in Lines.BY_AUTHOR[author][channel]:
				for mood: String in Lines.BY_AUTHOR[author][channel][node]:
					_check(Lines.lines(author, channel, node, mood).size() == (3 if channel == "desk" else 2), "%s %s/%s/%s has the authored line count" % [author, channel, node, mood])

func _templates() -> Array:
	var result: Array = []
	for author: String in Encounters.AUTHORS:
		for channel: String in ["desk", "dm"]:
			for node: String in Lines.BY_AUTHOR[author][channel]:
				for mood: String in Lines.BY_AUTHOR[author][channel][node]:
					for text: String in Lines.lines(author, channel, node, mood):
						result.append({"author": author, "channel": channel, "node": node, "mood": mood, "text": text})
	return result

func _test_line_hygiene() -> void:
	var subjects := RegEx.create_from_string("(?i)\\b(P\\d\\d|load-bearing|pigeon|urgen\\w*|tabs?|uppercase|lowercase|blue|pink|ink|exclamation|sign-?off|whitespace|filenames?|comments?|record|keywords?)\\b")
	var claims := RegEx.create_from_string("(?i)(good catch|great catch|nice catch|you're right|you are right|you're wrong|\\bmy bad\\b|my mistake|it's fine|compliant|\\bclean\\b|broken|\\bbugs?\\b|\\bcorrect|incorrect|violat|audit|typo)")
	var font: FontFile = ReviewBanter.TerminalFont
	var wrap_width: float = ReviewBanter.WIDTH - ReviewBanter.SHADOW - ReviewBanter.PAD.x * 2
	var seen := {}
	var longest_topic := ""
	for rule_id: String in Policy.CITED_WORDS:
		if Encounters.noun(rule_id).length() > longest_topic.length(): longest_topic = rule_id
	for entry: Dictionary in _templates():
		var text: String = entry.text
		var label := "%s %s/%s/%s: %s" % [entry.author, entry.channel, entry.node, entry.mood, text]
		_check(not text.contains("!") and not text.contains("%") and not text.contains("["), "No exclamation, percent, or brackets: " + label)
		_check(subjects.search(text) == null, "Templates never name a standard or its subject: " + label)
		_check(claims.search(text) == null, "Templates never claim the code or a citation is right or wrong: " + label)
		_check(not seen.has(text), "Every template is distinct: " + label)
		seen[text] = true
		var stripped := text
		for placeholder: String in ["{topic}", "{Topic}", "{topics}", "{Topics}"]: stripped = stripped.replace(placeholder, "")
		_check(not stripped.contains("{") and not stripped.contains("}"), "Only known placeholders: " + label)
		_check(RegEx.create_from_string("(?i)\\b(the|a|an|your|my|this|that|our|whole)\\s+\\{topics?\\}").search(text) == null, "Topics bring their own article: " + label)
		var filled := Encounters.fill(text, ["P01", "P02"] if entry.channel == "dm" else [longest_topic], longest_topic)
		if entry.channel == "desk":
			_check(not text.contains("{topics}") and not text.contains("{Topics}"), "Desk lines use one topic at most: " + label)
			_check(filled.length() <= 64, "Desk lines stay short once filled: " + filled)
			var rows := roundi(font.get_multiline_string_size(filled, HORIZONTAL_ALIGNMENT_LEFT, wrap_width, ReviewBanter.FONT_SIZE).y / font.get_height(ReviewBanter.FONT_SIZE))
			_check(rows <= 3, "Desk lines fit the bubble in three rows: " + filled)
		else:
			_check(filled.length() <= 170, "Slouch lines stay a message long: " + filled)
		if entry.channel == "desk" and entry.node == "pushback":
			_check(text.to_lower().contains("{topic}"), "A pushback names the disputed citation: " + label)
		if entry.node == "abandon":
			_check(text.contains("Helios"), "Abandoning means Helios merges it: " + label)
		if entry.node in ["escalate", "insist_escalate"]:
			_check(text.contains("Morgan"), "Escalations go to Morgan: " + label)
	for node: String in Lines.MORGAN:
		for mood: String in Lines.MORGAN[node]:
			for text: String in Lines.morgan(node, mood):
				_check(not text.contains("!") and subjects.search(text) == null and claims.search(text) == null, "Morgan's notes stay clean: " + text)
				_check(text.contains("{author}") and (node == "cap" or text.contains("{pr}")), "Morgan's notes name the author and the PR: " + text)

func _test_overrides() -> void:
	# A PR's own tree speaks first, for every mood.
	var first: Dictionary = Catalog.request_at(0)
	var Trees = load("res://content/trees.gd")
	if not Trees.tree(str(first.title)).is_empty():
		for mood: String in ["warm", "neutral", "strained", "hostile"]:
			_check(Encounters.desk_lines(first, "pitch", mood) == [Trees.line(str(first.title), "desk", "pitch", mood)], "A PR with a tree pitches in its own words (%s)" % mood)
		var flags: Array = Encounters.desk_lines(first, "flag", "neutral", ["P01"], "P01")
		_check(flags.size() > 1 and flags[0] == Encounters.fill(Trees.line(str(first.title), "desk", "flag", "neutral"), ["P01"], "P01"), "A repeatable moment leads with the PR's line and keeps templates behind it")
	# Without a tree, a neutral author speaks the PR's own bank lines; other moods use the templates.
	var spare: Dictionary = load("res://content/pr_bank.gd").entries()[-1]
	var packet: Dictionary = {"id": "PR-SPARE", "title": spare.title, "author": "Maya"}
	_check(Trees.tree(str(spare.title)).is_empty(), "The fallback test uses a PR without a tree")
	var own: Dictionary = Encounters.overrides(packet)
	var entry: Dictionary = {}
	for candidate: Dictionary in load("res://content/pr_bank.gd").entries():
		if candidate.title == packet.title: entry = candidate
	_check(own.get("pitch", "") == entry.get("pitch", "") and not str(own.get("pitch", "")).is_empty(), "Overrides come from the PR's bank entry")
	_check(Encounters.desk_lines(packet, "pitch", "neutral") == [own.pitch], "A neutral author pitches with the PR's own line")
	_check(Encounters.desk_lines(packet, "pitch", "warm") == Lines.lines(str(packet.author), "desk", "pitch", "warm"), "A warm author uses the mood template")
	_check(Encounters.desk_lines(packet, "pushback", "neutral", ["P01"], "P01") == [own.pushback], "A neutral pushback is the PR's own")
	_check(Encounters.desk_lines(packet, "thanks", "neutral") == [own.relief] and Encounters.desk_lines(packet, "relief", "neutral") == [own.relief], "A neutral approval brings the PR's own relief")
	var beat := {"pr_id": packet.id, "author": packet.author, "day": 1, "version": 1, "mood": "neutral", "node": "abandon", "cited": ["P01"], "shift_seconds": 5, "seq": 1}
	_check(Encounters.dm_text(beat, packet, "grudge") == own.grudge, "A neutral grudge is the PR's own")
	beat.mood = "hostile"
	_check(Encounters.dm_text(beat, packet, "grudge") in Lines.lines(str(packet.author), "dm", "grudge", "hostile"), "A hostile grudge comes from the templates")
	var unknown := {"id": "PR-X", "author": "Theo", "title": "Not a bank title"}
	_check(Encounters.desk_lines(unknown, "pitch", "neutral") == Banter.lines("Theo", "open"), "Without bank lines, a neutral pitch falls back to the banter")
	var titles := {}
	for candidate: Dictionary in load("res://content/pr_bank.gd").entries():
		_check(not titles.has(candidate.title), "Bank titles are unique, so overrides find their PR: " + str(candidate.title))
		titles[candidate.title] = true

func _test_never_reads_audit() -> void:
	for path: String in ["res://content/encounters.gd", "res://content/encounter_lines.gd"]:
		var source := FileAccess.get_file_as_string(path)
		for token: String in ["violations", "findings", "explanation", "expected_rules", "ai_verdict", "\"correct\"", ".correct", "recipe", "evidence_accepted", ".regression", "\"regression\"", ".fixed", "\"fixed\""]:
			_check(not source.contains(token), "%s never reads audit data (%s)" % [path.get_file(), token])
	# The branch functions take visible context only.
	var context := {"pr_id": "PR-2004", "author": "Theo", "version": 1, "verdict": "request_changes", "cited": ["P01"], "mood": "strained", "first": false, "pushed": false}
	_check(Encounters.verdict_node(context) == Encounters.verdict_node(context.duplicate(true)), "A branch is a pure function of its visible context")

# --- Mood -------------------------------------------------------------------------

func _test_mood() -> void:
	_check(Encounters.mood(Simulation.initial_state(), "Maya") == "neutral", "Everyone starts neutral")
	_check(Encounters.mood_for(70) == "warm" and Encounters.mood_for(50) == "neutral" and Encounters.mood_for(35) == "strained" and Encounters.mood_for(10) == "hostile", "Mood bands")
	# Reject every Theo PR, approve every Maya PR, review Inez exactly, for one day.
	var theo_moods: Array = []
	var maya_moods: Array = []
	var day_one := _play(func(at: Dictionary, packet: Dictionary) -> Array:
		match str(packet.author):
			"Theo": return ["P01"]
			"Maya": return []
		return packet.violations,
		func(_at: Dictionary, _pending: Dictionary) -> String: return "insist", 1)
	for beat: Dictionary in day_one.encounters:
		if beat.author == "Theo" and beat.node != "pushback": theo_moods.append(beat.mood)
		if beat.author == "Maya": maya_moods.append(beat.mood)
	_check(theo_moods[0] == "neutral" and str(theo_moods[-1]) in ["strained", "hostile"], "Theo turns cold after repeated rejections: %s" % [theo_moods])
	_check("warm" not in theo_moods and "hostile" in theo_moods, "Rejection after rejection, Theo never warms and ends up hostile: %s" % [theo_moods])
	_check(maya_moods[0] == "neutral" and maya_moods[-1] == "warm", "Maya warms up when her work is approved: %s" % [maya_moods])
	_check(Encounters.mood(day_one, "Maya") == "warm" and Encounters.mood(day_one, "Theo") in ["strained", "hostile"], "Moods carry to the end of the day")
	# The words change with the mood.
	var theo_packet := {"id": "PR-X", "author": "Theo", "title": "Not a bank title"}
	_check(Encounters.desk_lines(theo_packet, "pitch", Encounters.mood(day_one, "Theo")) != Encounters.desk_lines(theo_packet, "pitch", "neutral"), "A colder Theo pitches differently")
	# Approvals and withdrawn citations warm; abandoned PRs and insisting cool.
	for warmer: String in ["thanks", "suspicious", "relief", "withdrawn"]: _check(int(Encounters.TONE[warmer]) > 0, "%s warms the author" % warmer)
	for cooler: String in ["revise_now", "revise_later", "abandon", "escalate", "insist_revise", "insist_escalate"]: _check(int(Encounters.TONE[cooler]) < 0, "%s cools the author" % cooler)
	# Only the last few beats are remembered.
	var remembered := Simulation.initial_state()
	for index in range(6):
		remembered.encounters.append({"author": "Inez", "node": "abandon", "pr_id": "X%d" % index})
	_check(Encounters.mood_score(remembered, "Inez") == 50 + Encounters.MEMORY * int(Encounters.TONE.abandon), "Memory is bounded to the last few beats")

func _test_reachable_in_play() -> void:
	var exact_insist := _play(_exact, func(_at: Dictionary, _p: Dictionary) -> String: return "insist")
	var exact_withdraw := _play(_exact, func(_at: Dictionary, _p: Dictionary) -> String: return "withdraw")
	var careless := _play(func(at: Dictionary, packet: Dictionary) -> Array: return [] if at.decisions.size() % 3 == 0 else [Catalog.rules_for_day(int(at.day))[at.decisions.size() % Catalog.rules_for_day(int(at.day)).size()].id],
		func(at: Dictionary, _p: Dictionary) -> String: return "withdraw" if at.encounters.size() % 2 == 0 else "insist")
	var nodes := {}
	var moods := {}
	var arrivals := {}
	for run: Dictionary in [exact_insist, exact_withdraw, careless]:
		_check(run.phase == "complete", "Every strategy reaches the end of the career")
		for beat: Dictionary in run.encounters:
			nodes[beat.node] = true
			moods[beat.mood] = true
		for arrival: Dictionary in run.arrivals:
			var packet: Dictionary = Catalog.packet(run, str(arrival.pr_id))
			arrivals[Encounters.arrival(run, packet).node] = true
	for node: String in OUTCOMES:
		_check(nodes.has(node), "Play reaches the %s branch" % node)
	for node: String in ["pitch", "return", "revised"]:
		_check(arrivals.has(node), "Play reaches the %s arrival" % node)
	for mood: String in Encounters.MOODS:
		_check(moods.has(mood), "Play reaches the %s mood" % mood)
	# The career's first PR always goes back in line, so orientation stays scripted.
	_check(exact_insist.encounters[0].pr_id == Catalog.request_at(0).id and exact_insist.encounters[0].node == "revise_later", "The first PR is always revised later")
	for run: Dictionary in [exact_insist, careless]:
		for beat: Dictionary in run.encounters:
			if int(beat.version) >= Policy.MAX_REVISION and beat.node in ["revise_now", "revise_later", "pushback", "insist_revise", "abandon"]:
				_check(false, "A third change request always escalates (%s went %s)" % [beat.pr_id, beat.node])

# --- Determinism and the no-hints rule --------------------------------------------------

func _test_determinism() -> void:
	var cite := func(at: Dictionary, packet: Dictionary) -> Array: return packet.violations if at.decisions.size() % 4 != 3 else ["P02"]
	var answer := func(at: Dictionary, _p: Dictionary) -> String: return "withdraw" if at.encounters.size() % 3 == 0 else "insist"
	var a := _play(cite, answer, 2)
	var b := _play(cite, answer, 2)
	_check(a == b, "The same actions always produce the same encounters")
	_round_trip(a, "two days of mixed answers")
	var forged := a.duplicate(true)
	forged.encounters[3].node = "abandon" if forged.encounters[3].node != "abandon" else "revise_later"
	_check(not Simulation.validate_save(forged).ok, "A save cannot rewrite how an author responded")
	forged = a.duplicate(true)
	forged.encounters[2].mood = "warm" if forged.encounters[2].mood != "warm" else "hostile"
	_check(not Simulation.validate_save(forged).ok, "A save cannot rewrite an author's mood")
	forged = a.duplicate(true)
	forged.encounters.pop_back()
	_check(not Simulation.validate_save(forged).ok, "A save cannot drop an encounter beat")
	_check(Simulation.SAVE_VERSION >= 11, "Encounters bumped the save format to 11")
	var old := Simulation.initial_state()
	old.version = 10
	_check(not Simulation.validate_save(old).ok, "Older saves are rejected")

## Flip what the audit says about the PR on the desk, stamp the same citations in both
## worlds, and compare everything the player can see or hear.
func _flip_and_compare(at: Dictionary, cited: Array, label: String, answers: Array = []) -> void:
	var packet: Dictionary = Catalog.packet(at, at.active_request_id, false)
	if int(packet.get("revision", 1)) != 1: return
	var saved_violations: Array = packet.violations.duplicate(true)
	var saved_findings: Array = packet.findings.duplicate(true)
	# The same action in both worlds: each citation points at the same place.
	var evidence := {}
	for rule_id: String in cited:
		var where: Dictionary = Catalog.audit_citation(packet, rule_id)
		evidence[rule_id] = {"path": where.path, "line": int(where.line)}
	var worlds: Array = []
	for truth: String in ["all right", "all wrong"]:
		if truth == "all right":
			# Every citation is exactly the audit's answer, at the place it was pointed.
			packet.violations = cited.duplicate()
			packet.violations.sort()
			packet.findings = []
			for rule_id: String in cited:
				packet.findings.append({"rule_id": rule_id, "path": evidence[rule_id].path, "line": int(evidence[rule_id].line), "message": "test"})
		else:
			packet.violations = [] if not cited.is_empty() else ["P01"]
			packet.findings = [] if not cited.is_empty() else [{"rule_id": "P01", "path": packet.files[0].path, "line": 1, "message": "test"}]
		var next := _stamp(at, cited, evidence)
		for choice: String in answers:
			if not Encounters.pending(next).is_empty(): next = Simulation.dispatch(next, {"type": "pushback", "choice": choice})
		worlds.append(next)
	packet.violations = saved_violations
	packet.findings = saved_findings
	var right: Dictionary = worlds[0]
	var wrong: Dictionary = worlds[1]
	_check(right.encounters == wrong.encounters, "Same mood and action, different audit truth: same branch (%s)" % label)
	if not right.decisions.is_empty() and right.decisions.size() == wrong.decisions.size() and right.decisions.size() > at.decisions.size():
		_check(bool(right.decisions[-1].correct) != bool(wrong.decisions[-1].correct), "The counterfactual really changes the audit (%s)" % label)
	var author := str(packet.author)
	_check(Chat.messages(right, author) == Chat.messages(wrong, author), "Same Slouch messages either way (%s)" % label)
	_check(Chat.messages(right, "manager") == Chat.messages(wrong, "manager"), "Same Morgan notes either way (%s)" % label)
	_check(Encounters.pending(right) == Encounters.pending(wrong) and Encounters.typing(right) == Encounters.typing(wrong), "Same desk state either way (%s)" % label)
	if not right.encounters.is_empty() and right.encounters.size() > at.encounters.size():
		var beat: Dictionary = right.encounters[-1]
		var identity := {"id": packet.id, "author": author, "title": packet.title}
		_check(Encounters.desk_lines(identity, beat.node, beat.mood, beat.cited, str(beat.get("disputed", ""))) == Encounters.desk_lines(identity, wrong.encounters[-1].node, wrong.encounters[-1].mood, wrong.encounters[-1].cited, str(wrong.encounters[-1].get("disputed", ""))), "Same words at the desk either way (%s)" % label)

func _test_counterfactuals() -> void:
	# Walk two days; at every original PR, try several actions in both audit worlds.
	var at := Simulation.initial_state()
	var tried := 0
	var pushbacks := 0
	var guard := 0
	while at.phase != "complete" and int(at.day) <= 2 and guard < 2000:
		guard += 1
		if at.phase == "debrief":
			if int(at.day) >= 2: break
			at = Simulation.dispatch(at, {"type": "next-day", "choice": "rest"})
			continue
		if _desk(at).is_empty():
			var coming: bool = int(at.desk_at) >= 0 and int(at.desk_at) < Catalog.shift_seconds()
			at = Simulation.advance(at, int(at.desk_at) - int(at.shift_seconds) if coming else Catalog.shift_seconds())
			continue
		if not Encounters.pending(at).is_empty():
			at = Simulation.dispatch(at, {"type": "pushback", "choice": "insist"})
			continue
		var packet: Dictionary = Catalog.packet(at, at.active_request_id)
		for cited: Array in [[]] + _sets(int(at.day)).slice(0, 4):
			_flip_and_compare(at, cited, "%s cites %s" % [packet.id, cited])
			tried += 1
			var probe := _stamp(at, cited)
			if not Encounters.pending(probe).is_empty():
				pushbacks += 1
				_flip_and_compare(at, cited, "%s pushback, INSIST" % packet.id, ["insist"])
				_flip_and_compare(at, cited, "%s pushback, WITHDRAW" % packet.id, ["withdraw"])
		at = _stamp(at, packet.violations)
	_check(tried > 60 and pushbacks > 3, "Counterfactuals cover many PRs and pushbacks (%d tried, %d pushbacks)" % [tried, pushbacks])
	# A right flag and a wrong flag at different lines take the same branch too.
	var first := Simulation.initial_state()
	var packet: Dictionary = Catalog.request_at(0)
	var real: Dictionary = Catalog.audit_citation(packet, "P01")
	var right := _stamp(first, ["P01"])
	var wrong := _stamp(first, ["P01"], {"P01": {"path": real.path, "line": 1 if int(real.line) != 1 else 2}})
	_check(right.decisions[-1].correct and not wrong.decisions[-1].correct, "One flag is right, the other wrong")
	_check(right.encounters == wrong.encounters and Chat.messages(right, "Maya") == Chat.messages(wrong, "Maya"), "Right and wrong flags get the same branch and words")

# --- Pushback, revise-now, abandon, escalation -------------------------------------------

func _test_pushback() -> void:
	var found := _find("pushback")
	_check(not found.is_empty(), "Some change request is pushed back")
	if found.is_empty(): return
	var pushed: Dictionary = found.after
	var disputed := Encounters.pending(pushed)
	var id: String = str(disputed.pr_id)
	var author: String = str(disputed.author)
	_check(_desk(pushed) == id and pushed.decisions.size() == found.before.decisions.size(), "A pushback keeps the PR on the desk, unsigned")
	_check(str(disputed.disputed) in found.cited, "The author disputes one of your citations")
	_check(Simulation.dispatch(pushed, {"type": "toggle-rule", "rule_id": str(disputed.disputed)}) == pushed, "Citations are frozen during a pushback")
	_check(Simulation.dispatch(pushed, {"type": "review", "verdict": "approve"}) == pushed, "You can't approve around a pushback")
	_check(Simulation.dispatch(pushed, {"type": "pushback", "choice": "shrug"}) == pushed, "Only INSIST or WITHDRAW answer a pushback")
	_round_trip(pushed, "pushback pending")
	# INSIST: the change request goes through as cited; the author revises or escalates.
	var insisted := Simulation.dispatch(pushed, {"type": "pushback", "choice": "insist"})
	var outcome: Dictionary = _beat(insisted)
	_check(outcome.node in ["insist_revise", "insist_escalate"] and outcome.mood == disputed.mood, "INSIST: they revise grudgingly or escalate, in the same mood")
	_check(insisted.decisions[-1].pr_id == id and insisted.decisions[-1].cited_rules == found.cited, "INSIST signs the change request exactly as cited")
	_check(insisted.actions[-1].type == "pushback" and insisted.actions[-1].choice == "insist", "The answer is journaled")
	var restamped := Simulation.dispatch(pushed, {"type": "review", "verdict": "request_changes"})
	_check(restamped == insisted, "Stamping changes again during a pushback is insisting")
	_round_trip(insisted, "after INSIST")
	# WITHDRAW: the disputed citation goes, the review reopens, the author warms a little.
	var withdrawn := Simulation.dispatch(pushed, {"type": "pushback", "choice": "withdraw"})
	_check(_desk(withdrawn) == id and Encounters.pending(withdrawn).is_empty() and _beat(withdrawn).node == "withdrawn", "WITHDRAW reopens the review")
	_check(str(disputed.disputed) not in withdrawn.selected_rules and withdrawn.selected_rules.size() == found.cited.size() - 1, "WITHDRAW retracts only the disputed citation")
	_check(int(withdrawn.coworkers[author]) == mini(100, int(pushed.coworkers[author]) + 2), "Conceding warms the author a little")
	_round_trip(withdrawn, "after WITHDRAW")
	# Restamping after a withdraw never pushes back twice in one visit.
	var again := _stamp(withdrawn, found.cited)
	_check(Encounters.pending(again).is_empty() and _beat(again).node in Encounters.VERDICTS, "A visit has at most one pushback")
	var approved := Simulation.dispatch(withdrawn, {"type": "review", "verdict": "approve"}) if withdrawn.selected_rules.is_empty() else _stamp(withdrawn, [])
	_check(_beat(approved).node in Encounters.APPROVALS, "After WITHDRAW you can approve instead")
	# The bell during a pushback hands the PR to Helios, unsigned.
	var late := Simulation.advance(pushed, Catalog.shift_seconds())
	_check(late.phase == "debrief" and late.last_debrief.handed_off >= 1 and late.decisions.size() == pushed.decisions.size(), "At the bell, a disputed PR goes to Helios unsigned")
	_round_trip(late, "bell during pushback")

func _test_revise_now() -> void:
	var found := _find("revise_now")
	_check(not found.is_empty(), "Some author revises at the desk")
	if found.is_empty(): return
	var now: Dictionary = found.after
	var beat: Dictionary = _beat(now)
	var made: String = str(beat.revision_id)
	_check(_desk(now).is_empty() and now.desk_line[0] == made, "v2 goes straight back to the front of the line")
	_check(int(now.desk_at) == int(now.shift_seconds) + Encounters.REVISE_NOW_SECONDS, "after a short beat")
	var typing := Encounters.typing(now)
	_check(typing.author == beat.author and typing.revision_id == made and typing.mood == beat.mood, "Meanwhile the author is typing at your desk")
	_round_trip(now, "typing")
	var landed := _land(now)
	_check(_desk(landed) == made and Encounters.typing(landed).is_empty(), "v2 replaces the PR at the desk")
	var arrival := Encounters.arrival(landed, Catalog.packet(landed, made))
	_check(arrival.node == "revised" and arrival.mood == beat.mood, "It opens as revised at the desk, in the mood that made it")
	_check(landed.decisions.size() == found.before.decisions.size() + 1, "The change request itself counts as reviewed")
	var told := func(at: Dictionary) -> bool:
		return Chat.messages(at, str(beat.author)).any(func(message: Dictionary) -> bool: return str(message.id) == "%s|%s|reaction" % [beat.author, beat.pr_id])
	_check(not told.call(now) and told.call(landed), "Slouch says it's on your desk only once v2 is")
	var later := _find("revise_later", func(at: Dictionary, _p: Dictionary) -> bool: return at.decisions.size() > 2)
	if not later.is_empty():
		var back: Dictionary = later.after
		_check(back.desk_line.find(str(_beat(back).revision_id)) == mini(Simulation.REVISION_GAP, back.desk_line.size() - 1), "Revise later is today's behavior: two PRs back")
	var bell := Simulation.advance(now, Catalog.shift_seconds())
	_check(bell.phase == "debrief" and bell.last_debrief.handed_off >= 1, "A revision still being typed at the bell goes to Helios")

func _test_abandon_and_escalate() -> void:
	var found := _find("abandon")
	_check(not found.is_empty(), "Some author abandons a PR")
	if found.is_empty(): return
	var before: Dictionary = found.before
	var gone: Dictionary = found.after
	var beat: Dictionary = _beat(gone)
	var author: String = str(beat.author)
	_check(gone.decisions.size() == before.decisions.size() + 1 and gone.decisions[-1].verdict == "request_changes", "An abandoned PR counts as reviewed")
	_check(gone.revisions.size() == before.revisions.size() and gone.desk_line == before.desk_line, "No revision is coming")
	_check(int(gone.autonomy) == int(before.autonomy), "Helios merges it, without raising automation reliance")
	var base: int = -3 if gone.decisions[-1].correct else -9
	_check(int(gone.coworkers[author]) == clampi(int(before.coworkers[author]) + base + Encounters.relationship_change("abandon"), 0, 100), "Abandoning hurts the relationship beyond the review itself")
	var dms := Chat.messages(gone, author).filter(func(message: Dictionary) -> bool: return message.get("id", "").contains(str(beat.pr_id)))
	_check(dms.any(func(message: Dictionary) -> bool: return message.kind == "reaction"), "Slouch hears the author close it")
	_check(not dms.any(func(message: Dictionary) -> bool: return message.kind == "grudge"), "The grudge waits a moment")
	var later := Simulation.advance(gone, Encounters.GRUDGE_DELAY)
	var grudges: Array = Chat.messages(later, author).filter(func(message: Dictionary) -> bool: return message.kind == "grudge")
	_check(not grudges.is_empty(), "Then the grudge lands in Slouch")
	_check(JSON.stringify(Chat.messages(gone, "manager")).contains(Catalog.display_id(str(beat.pr_id))), "Morgan notes the abandoned PR")
	_round_trip(later, "after abandon")
	var early := _find("escalate", func(_at: Dictionary, packet: Dictionary) -> bool: return int(packet.revision) < Policy.MAX_REVISION)
	_check(not early.is_empty(), "Some author escalates before the third round")
	if early.is_empty(): return
	var escalated: Dictionary = early.after
	_check(int(escalated.autonomy) == int(early.before.autonomy) and escalated.revisions.size() == early.before.revisions.size(), "Morgan hands it to Helios; no revision, and reliance moves only on the third round")
	var note: String = JSON.stringify(Chat.messages(escalated, "manager"))
	_check(note.contains(str(_beat(escalated).author)) and note.contains(Catalog.display_id(str(_beat(escalated).pr_id))), "Morgan's note names the author and the PR")

func _test_saves() -> void:
	var mixed := _play(func(at: Dictionary, packet: Dictionary) -> Array: return packet.violations if at.decisions.size() % 2 == 0 else ["P01"],
		func(at: Dictionary, _p: Dictionary) -> String: return "withdraw" if at.encounters.size() % 2 == 0 else "insist", 3)
	_round_trip(mixed, "three days, mixed")
	var bogus := mixed.duplicate(true)
	bogus.actions.append({"type": "pushback", "day": bogus.day, "shift_seconds": bogus.shift_seconds, "pr_id": "PR-1042", "choice": "insist"})
	_check(not Simulation.validate_save(bogus).ok, "A pushback answer needs a pushback on the desk")

func _test_slouch() -> void:
	var run := _play(_exact, func(at: Dictionary, _p: Dictionary) -> String: return "withdraw" if at.encounters.size() % 2 == 0 else "insist", 4)
	var forbidden := RegEx.create_from_string("\\bP0[1-9]\\b|violat|audit|%|\\[|\\{")
	var kinds := {}
	for contact: String in ["Maya", "Theo", "Inez", "manager"]:
		var ids := {}
		for message: Dictionary in Chat.messages(run, contact):
			kinds[message.kind] = true
			_check(forbidden.search(str(message.text)) == null and not str(message.text).is_empty(), "Slouch encounter messages are clean: " + str(message.text))
			_check(not ids.has(message.id), "Slouch messages have unique ids: " + str(message.id))
			ids[message.id] = true
	_check(kinds.has("reaction") and kinds.has("encounter"), "Slouch carries reactions and withdrawn-citation thanks")

# --- The desk controls --------------------------------------------------------------------

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
	for frame in range(3): await process_frame
	ui.render_state(state)

func _global(local: Rect2) -> Rect2:
	return Rect2(ui._banter.get_global_rect().position + local.position, local.size)

func _test_desk_controls() -> void:
	var found := _find("pushback")
	if found.is_empty(): return
	# Render the PR before the stamp, then stamp through the real controls.
	await _fresh_ui(found.before)
	ui._open_app("review")
	var packet: Dictionary = Catalog.packet(state, state.active_request_id)
	for rule_id: String in found.cited:
		_command(Catalog.audit_citation(packet, rule_id))
	ui._reject.pressed.emit()
	for frame in range(4): await process_frame
	var disputed := Encounters.pending(state)
	_check(not disputed.is_empty() and ui._banter.asking and ui._banter.kind == "pushback", "Stamping shows the author's pushback")
	_check(ui._banter.insist_button.is_visible_in_tree() and ui._banter.withdraw_button.is_visible_in_tree(), "INSIST and WITHDRAW sit with the bubble")
	for extent: Vector2i in [Vector2i(1120, 800), Vector2i(1280, 900)]:
		root.size = extent
		for frame in range(4): await process_frame
		ui._arrange_windows()
		for frame in range(3): await process_frame
		var buttons := _global(ui._banter.choices_rect())
		_check(buttons.has_area(), "The pushback buttons have a footprint at %s" % extent)
		for target: Control in [ui._paper, ui._diff, ui._approve, ui._reject, ui._file_picker]:
			_check(not buttons.intersects(target.get_global_rect()), "Pushback buttons never cover %s at %s" % [target.name, extent])
		for rule_id: String in ui._flag_buttons:
			if ui._flag_buttons[rule_id].is_visible_in_tree():
				_check(not buttons.intersects(ui._flag_buttons[rule_id].get_global_rect()), "Pushback buttons never cover the citation slip at %s" % extent)
		_check(not _global(ui._banter.bubble_rect()).intersects(buttons), "The buttons sit under the bubble, not on it")
	root.size = Vector2i(1280, 900)
	_check(ui._banter.insist_button.get_theme_font("font").resource_path.ends_with("IBMPlexMono-Regular.ttf"), "The buttons use IBM Plex Mono")
	_check(ui._banter.insist_button.get_theme_color("font_color") == Color("e5384a") and ui._banter.withdraw_button.get_theme_color("font_color") == Color("e0b44a"), "INSIST is alarm red; WITHDRAW is amber")
	_check(ui._slip_rows[str(disputed.disputed)].where.text.contains("DISPUTED") and ui._pr_id.text.ends_with("PUSHED BACK"), "The slip and form show what is disputed")
	_check(ui._reject.disabled and ui._approve.disabled, "The stamps wait for an answer")
	var line := ui._banter.line
	ui._banter.tick(ReviewBanter.IDLE_SECONDS * 3)
	_check(ui._banter.line == line and ui._banter.asking, "No idle nudges interrupt a pushback")
	ui._banter.withdraw_button.pressed.emit()
	_check(Encounters.pending(state).is_empty() and _beat(state).node == "withdrawn" and not ui._banter.asking, "WITHDRAW answers through the simulation")
	_check(ui._banter.kind == "withdrawn" and ui._banter.speaker == str(disputed.author) and not ui._banter.choices_rect().has_area(), "The author takes the win and the buttons go away")
	_check(not ui._reject.disabled or state.selected_rules.is_empty(), "The review reopens")
	# INSIST from the same moment, then a fresh desk for typing.
	await _fresh_ui(found.after)
	ui._open_app("review")
	for frame in range(3): await process_frame
	_check(ui._banter.asking, "A loaded pushback shows its buttons again")
	ui._banter.insist_button.pressed.emit()
	_check(Encounters.pending(state).is_empty() and _beat(state).node in ["insist_revise", "insist_escalate"] and not ui._banter.asking, "INSIST answers through the simulation")
	var now := _find("revise_now")
	if now.is_empty(): return
	await _fresh_ui(now.before)
	ui._open_app("review")
	packet = Catalog.packet(state, state.active_request_id)
	for rule_id: String in now.cited:
		_command(Catalog.audit_citation(packet, rule_id))
	ui._reject.pressed.emit()
	var typing := Encounters.typing(state)
	_check(not typing.is_empty() and ui._banter.visible and ui._banter.typing and ui._banter.speaker == str(typing.author), "Revise-now keeps the author at the desk")
	_check(ui._banter.kind == "revise_now" and ui._banter.line in Encounters.desk_lines({"id": typing.pr_id, "author": typing.author, "title": packet.title}, "revise_now", str(typing.mood), typing.cited), "They say give me a sec")
	_check(ui._pr_id.text.ends_with("BEING REVISED"), "The form says it is being revised")
	ui._process(ReviewBanter.HANDOFF_SECONDS + 0.1)
	_check(ui._banter.is_typing() and ui._banter.is_speaking(), "Then the bubble shows them typing, mouth moving")
	state = Simulation.advance(state, Encounters.REVISE_NOW_SECONDS)
	ui.render_state(state)
	_check(_desk(state) == str(typing.revision_id) and ui._banter.kind == "revision" and not ui._banter.typing, "v2 replaces the PR at the desk")
	_check(ui._banter.line in Encounters.desk_lines({"id": typing.revision_id, "author": typing.author, "title": packet.title}, "revised", str(typing.mood), typing.cited), "and opens with a revised-at-the-desk line")
