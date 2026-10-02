extends SceneTree
## Export the encounter flow charts to one self-contained HTML page: a chart per
## author (mood conditions, your actions, outcomes, branch odds), every line by
## node and mood, and a sample day that shows moods changing. Everything is read
## from content/encounters.gd, so the page always matches the game.
## sh scripts/run.sh --headless --script res://tools/encounter_flowchart.gd -- <out.html>
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Policy = preload("res://content/policy_campaign.gd")
const Encounters = preload("res://content/encounters.gd")
const Lines = preload("res://content/encounter_lines.gd")
const Portraits = preload("res://native/portraits.gd")
const Trees = preload("res://content/trees.gd")
const FONT := "res://art/fonts/IBMPlexMono-Regular.ttf"

const MOOD_COLORS := {"warm": "#6fdc8c", "neutral": "#e6e2d6", "strained": "#e0b44a", "hostile": "#e5384a"}
const MOOD_SHORT := {"warm": "W", "neutral": "N", "strained": "S", "hostile": "H"}
## Column x (left edge) and row y (center) of every node in the chart.
const COLUMNS: Array[int] = [16, 206, 396, 586, 776, 986, 1176, 1386]
const NODE_W := 168
const NODE_H := 54
const SMALL_H := 30
const ROW := 70
const TOP := 34
const PLACES := {
	"lands": [0, 4.0], "pitch": [1, 2.6], "return": [1, 4.0], "revised": [1, 5.4],
	"review": [2, 4.0], "flag": [2, 0.35], "unflag": [2, 1.15], "consult": [2, 1.95],
	"approve": [3, 1.6], "changes": [3, 6.6],
	"thanks": [4, 0.5], "suspicious": [4, 1.5], "relief": [4, 2.5],
	"revise_now": [4, 4.4], "revise_later": [4, 5.5], "pushback": [4, 6.6], "abandon": [4, 8.3], "escalate": [4, 9.3],
	"insist": [5, 6.1], "withdraw": [5, 7.1],
	"insist_revise": [6, 5.5], "insist_escalate": [6, 6.5], "withdrawn": [6, 7.5],
	"merged": [7, 1.5], "grudge": [7, 8.3], "morgan": [7, 9.3],
}
## Loops back to an earlier column, drawn as lettered connectors instead of lines.
const LOOPS := [
	["A", "revise_now", "revised", "v2 replaces the PR at the desk, about six seconds later"],
	["B", "revise_later", "return", "v2 rejoins the line behind the next two PRs"],
	["C", "insist_revise", "return", "v2 rejoins the line behind the next two PRs"],
	["D", "withdrawn", "review", "the review reopens without the disputed citation"],
]
const REACTIONS: Array[String] = ["flag", "unflag", "consult"]
const DESK_ORDER: Array[String] = ["pitch", "return", "revised", "flag", "unflag", "consult", "thanks", "suspicious", "relief",
	"revise_now", "revise_later", "pushback", "abandon", "escalate", "insist_revise", "insist_escalate", "withdrawn"]
const DM_ORDER: Array[String] = ["thanks", "suspicious", "relief", "revise_now", "revise_later", "withdrawn", "insist_revise",
	"insist_escalate", "abandon", "grudge", "escalate"]
const EXAMPLE_TOPIC := "P04"

var out := "user://encounter_flowchart.html"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): out = args[0]
	var html := page()
	var file := FileAccess.open(out, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write " + out)
		quit(1)
		return
	file.store_string(html)
	file.close()
	print("Encounter flow charts written to ", ProjectSettings.globalize_path(out), " (", html.length(), " bytes)")
	quit()


static func _esc(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


static func _x(node: String) -> float:
	return float(COLUMNS[int(PLACES[node][0])])


static func _y(node: String) -> float:
	return TOP + float(PLACES[node][1]) * ROW


static func _h(node: String) -> float:
	return float(SMALL_H if node in REACTIONS else NODE_H)


static func _portrait(author: String) -> String:
	var texture: Texture2D = Portraits.texture_for(author)
	if texture == null: return ""
	var image := texture.get_image()
	if image == null or image.is_empty(): return ""
	return "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())


# --- One chart ---------------------------------------------------------------------

## Probability for an edge's branch by mood ({} for fixed edges).
static func _edge_odds(edge: Dictionary, author: String) -> Dictionary:
	if not edge.has("pick"): return {}
	var result := {}
	for mood: String in Encounters.MOODS:
		result[mood] = int(Encounters.odds(str(edge.pick), author, mood).get(str(edge.to), 0))
	return result


static func chart(author: String) -> String:
	var width := COLUMNS[-1] + NODE_W + 20
	var height := int(TOP + 10.0 * ROW)
	var svg := PackedStringArray()
	svg.append('<svg class="chart" viewBox="0 0 %d %d" role="img" aria-label="Encounter flow chart for %s">' % [width, height, author])
	svg.append('<defs><marker id="arrow-%s" viewBox="0 0 10 10" refX="9" refY="5" markerUnits="userSpaceOnUse" markerWidth="9" markerHeight="9" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" class="arrowhead"/></marker></defs>' % author)
	var headings := ["DESK", "ARRIVES", "YOU REVIEW", "YOU STAMP", "THE AUTHOR RESPONDS", "YOU ANSWER", "THEN", "AFTERWARDS"]
	for index in range(headings.size()):
		svg.append('<text class="heading" x="%d" y="14">%s</text>' % [COLUMNS[index], headings[index]])
	# The reactions while you review sit in one box above the review.
	var box_top := _y("flag") - SMALL_H * 0.5 - 8
	var box_bottom := _y("consult") + SMALL_H * 0.5 + 8
	svg.append('<rect class="group" x="%d" y="%d" width="%d" height="%d" rx="4"/>' % [COLUMNS[2] - 8, box_top, NODE_W + 16, box_bottom - box_top])
	var review_x := _x("review") + NODE_W * 0.5
	svg.append('<path class="edge fixed" d="M%d,%d L%d,%d" marker-end="url(#arrow-%s)"/>' % [review_x, _y("review") - NODE_H * 0.5, review_x, box_bottom + 2, author])
	svg.append('<text class="edge-label" x="%d" y="%d">flag · unflag · ask Helios</text>' % [review_x + 6, (box_bottom + _y("review") - NODE_H * 0.5) * 0.5 + 4])
	# What each weighted branch's odds and conditions are, shown inside its node.
	var odds_for := {}
	var when_for := {}
	for edge: Dictionary in Encounters.EDGES:
		if edge.has("pick"):
			odds_for[str(edge.to)] = _edge_odds(edge, author)
			when_for[str(edge.to)] = str(edge.get("when", ""))
	for edge: Dictionary in Encounters.EDGES:
		var from := str(edge.from)
		var to := str(edge.to)
		if _is_loop(from, to) or to in REACTIONS: continue
		var odds := _edge_odds(edge, author)
		var x1 := _x(from) + NODE_W
		var y1 := _y(from)
		var x2 := _x(to)
		var y2 := _y(to)
		var bend := maxf(28.0, (x2 - x1) * 0.45)
		var data := ""
		for mood: String in odds: data += ' data-%s="%d"' % [mood, int(odds[mood])]
		svg.append('<path class="%s"%s d="M%d,%d C%d,%d %d,%d %d,%d" marker-end="url(#arrow-%s)"/>' % ["edge pick" if not odds.is_empty() else "edge fixed", data, x1, y1, x1 + bend, y1, x2 - bend, y2, x2 - 2, y2, author])
		var label := str(edge.get("when", ""))
		if odds.is_empty() and not label.is_empty():
			svg.append('<text class="edge-label" x="%d" y="%d">%s</text>' % [x2 + 2, y2 - _h(to) * 0.5 - 5, _esc(label)])
	for node: String in PLACES:
		var info: Dictionary = Encounters.NODES[node]
		var h := _h(node)
		var x := _x(node)
		var y := _y(node) - h * 0.5
		var sample := _sample_line(author, node)
		svg.append('<a href="#%s-%s" class="node-link"><g class="node %s" data-node="%s">' % [author.to_lower(), node, str(info.kind), node])
		svg.append('<title>%s: %s%s</title>' % [_esc(str(info.label)), _esc(str(info.about)), ("\n\n“" + _esc(sample) + "”") if not sample.is_empty() else ""])
		svg.append('<rect x="%d" y="%d" width="%d" height="%d" rx="%d"/>' % [x, y, NODE_W, h, 2 if str(info.kind) == "you" else 6])
		svg.append('<text class="label" x="%d" y="%d">%s</text>' % [x + 9, y + (19 if h < NODE_H else 17), _esc(str(info.label))])
		if h < NODE_H:
			svg.append('</g></a>')
			continue
		var second := sample if not sample.is_empty() else str(info.about)
		if odds_for.has(node):
			var parts := PackedStringArray()
			for mood: String in Encounters.MOODS:
				parts.append('<tspan class="odds" data-mood="%s" fill="%s">%s%d</tspan>' % [mood, MOOD_COLORS[mood], MOOD_SHORT[mood], int(odds_for[node][mood])])
			svg.append('<text class="node-odds" x="%d" y="%d">%s</text>' % [x + 9, y + 32, " ".join(parts)])
			var condition := str(when_for.get(node, ""))
			svg.append('<text class="%s" x="%d" y="%d">%s</text>' % ["condition" if not condition.is_empty() else "sample", x + 9, y + 46, _esc(_clip(condition if not condition.is_empty() else second, 25))])
		else:
			var rows := _wrap(second, 25, 2)
			for index in range(rows.size()):
				svg.append('<text class="sample" x="%d" y="%d">%s</text>' % [x + 9, y + 33 + index * 13, _esc(str(rows[index]))])
		svg.append('</g></a>')
	# Loops back to earlier columns: a lettered circle where they leave and where they land.
	for loop: Array in LOOPS:
		var letter := str(loop[0])
		var from := str(loop[1])
		var to := str(loop[2])
		var sx := _x(from) + NODE_W
		var sy := _y(from)
		svg.append('<g class="loop"><title>%s: %s</title><line x1="%d" y1="%d" x2="%d" y2="%d"/><circle cx="%d" cy="%d" r="9"/><text x="%d" y="%d" text-anchor="middle">%s</text></g>' % [letter, _esc(str(loop[3])), sx, sy, sx + 10, sy, sx + 19, sy, sx + 19, sy + 4, letter])
		var offset := 0.0
		for other: Array in LOOPS:
			if str(other[2]) == to and str(other[0]) < letter: offset += 24.0
		var tx := _x(to) + 14 + offset
		var ty := _y(to) + _h(to) * 0.5 + 13
		svg.append('<g class="loop"><title>%s: %s</title><line x1="%d" y1="%d" x2="%d" y2="%d"/><circle cx="%d" cy="%d" r="9"/><text x="%d" y="%d" text-anchor="middle">%s</text></g>' % [letter, _esc(str(loop[3])), tx, ty - 9, tx, _y(to) + _h(to) * 0.5, tx, ty, tx, ty + 4, letter])
	svg.append('</svg>')
	return "\n".join(svg)


static func _is_loop(from: String, to: String) -> bool:
	for loop: Array in LOOPS:
		if str(loop[1]) == from and str(loop[2]) == to: return true
	return false


static func _clip(text: String, length: int) -> String:
	return text if text.length() <= length else text.left(length - 1).strip_edges() + "…"


## Word-wrap into at most `count` rows of `width` characters; the last row is clipped.
static func _wrap(text: String, width: int, count: int) -> Array:
	var rows: Array = []
	var row := ""
	var words := text.split(" ", false)
	for index in range(words.size()):
		var word: String = words[index]
		var trial := word if row.is_empty() else row + " " + word
		if trial.length() <= width or row.is_empty():
			row = trial
			continue
		rows.append(row)
		if rows.size() == count - 1:
			row = " ".join(words.slice(index))
			break
		row = word
	if not row.is_empty(): rows.append(_clip(row, width))
	return rows.slice(0, count)


## A representative line for a node, preferring the author's neutral voice.
static func _sample_line(author: String, node: String) -> String:
	var info: Dictionary = Encounters.NODES.get(node, {})
	if str(info.get("kind", "")) not in ["say", "slouch"]: return ""
	var identity := {"id": "PR-SAMPLE", "author": author, "title": "(sample)"}
	if node == "grudge":
		return Encounters.fill(str(Lines.lines(author, "dm", "grudge", "neutral")[0]), [EXAMPLE_TOPIC], EXAMPLE_TOPIC)
	if node == "morgan":
		return str(Lines.morgan("escalate", "neutral")[0]).replace("{author}", author).replace("{pr}", "PR-2004")
	for mood: String in ["neutral", "strained", "warm"]:
		var options := Encounters.desk_lines(identity, node, mood, [EXAMPLE_TOPIC], EXAMPLE_TOPIC)
		if not options.is_empty(): return str(options[0])
	return ""


# --- Lines ---------------------------------------------------------------------------

static func _cell(lines: Array, note: String = "") -> String:
	var items := PackedStringArray()
	for text: Variant in lines: items.append("<li>%s</li>" % _esc(str(text)))
	return "<td>%s<ul>%s</ul></td>" % ['<div class="note">%s</div>' % _esc(note) if not note.is_empty() else "", "".join(items)]


static func desk_table(author: String) -> String:
	var identity := {"id": "PR-SAMPLE", "author": author, "title": "(sample)"}
	var rows := PackedStringArray()
	for node: String in DESK_ORDER:
		var cells := PackedStringArray()
		for mood: String in Encounters.MOODS:
			var options := Encounters.desk_lines(identity, node, mood, [EXAMPLE_TOPIC], EXAMPLE_TOPIC)
			var note := ""
			if mood == "neutral" and Encounters.DESK_FALLBACK.has(node) and Lines.lines(author, "desk", node, "neutral").is_empty():
				note = "classic banter"
				options = options.slice(0, 3)
			if mood == "neutral" and Encounters.DESK_OVERRIDES.has(node):
				note = "the PR's own %s line from the bank; else these" % str(Encounters.DESK_OVERRIDES[node]) if note.is_empty() else "the PR's own %s line from the bank; else classic banter" % str(Encounters.DESK_OVERRIDES[node])
			cells.append(_cell(options, note))
		rows.append('<tr id="%s-%s"><th><span class="node-name">%s</span><span class="node-about">%s</span></th>%s</tr>' % [author.to_lower(), node, _esc(str(Encounters.NODES[node].label)), _esc(str(Encounters.NODES[node].about)), "".join(cells)])
	return '<table class="lines"><thead><tr><th>At the desk</th>%s</tr></thead><tbody>%s</tbody></table>' % [_mood_headers(), "".join(rows)]


static func dm_table(author: String) -> String:
	var rows := PackedStringArray()
	for node: String in DM_ORDER:
		var cells := PackedStringArray()
		for mood: String in Encounters.MOODS:
			var authored: Array = Lines.lines(author, "dm", node, mood)
			var lines: Array = []
			for text: Variant in authored: lines.append(Encounters.fill(str(text), ["P04", "P06"], EXAMPLE_TOPIC))
			var note := ""
			if authored.is_empty():
				note = {"thanks": "classic per-PR thanks", "relief": "classic: Finally.", "revise_later": "classic send-back", "escalate": "classic"}.get(node, "")
				var beat := {"pr_id": "PR-1042", "author": author, "day": 1, "version": 3 if node == "escalate" else (2 if node == "relief" else 1), "mood": mood, "node": node, "cited": ["P04", "P06"], "shift_seconds": 30, "seq": 1}
				lines = [Encounters.dm_text(beat, Catalog.request_at(0), node)]
			if mood == "neutral" and node == "grudge": note = "the PR's own grudge line from the bank; else these"
			cells.append(_cell(lines, note))
		var anchor := ("%s-%s" % [author.to_lower(), node]) if node == "grudge" else ""
		rows.append('<tr%s><th><span class="node-name">%s</span></th>%s</tr>' % [(' id="%s"' % anchor) if not anchor.is_empty() else "", _esc(str(Encounters.NODES[node].label)), "".join(cells)])
	return '<table class="lines"><thead><tr><th>In Slouch</th>%s</tr></thead><tbody>%s</tbody></table>' % [_mood_headers(), "".join(rows)]


static func morgan_table(author: String) -> String:
	var rows := PackedStringArray()
	for node: String in ["escalate", "insist_escalate", "abandon", "cap"]:
		var cells := PackedStringArray()
		for mood: String in Encounters.MOODS:
			var lines: Array = []
			for text: String in Lines.morgan(node, mood): lines.append(text.replace("{author}", author).replace("{pr}", "PR-2004"))
			if node == "cap":
				var base: String = load("res://content/policy_chat.gd").escalation(author, "PR-2004")
				lines = [base + (" " + str(lines[0]) if not lines.is_empty() else "")]
			cells.append(_cell(lines))
		var label: String = {"escalate": "Loops in Morgan (early)", "insist_escalate": "Takes it to Morgan after INSIST", "abandon": "Abandons it", "cap": "Third round (always)"}[node]
		rows.append('<tr%s><th><span class="node-name">%s</span></th>%s</tr>' % [' id="%s-morgan"' % author.to_lower() if node == "escalate" else "", label, "".join(cells)])
	return '<table class="lines"><thead><tr><th>Morgan hears</th>%s</tr></thead><tbody>%s</tbody></table>' % [_mood_headers(), "".join(rows)]


static func _mood_headers() -> String:
	var heads := PackedStringArray()
	for mood: String in Encounters.MOODS: heads.append('<th class="mood-head"><span class="chip" style="--c:%s">%s</span></th>' % [MOOD_COLORS[mood], mood])
	return "".join(heads)


# --- A sample day ----------------------------------------------------------------------

## Monday with a strategy that shows moods moving: every Theo PR is sent back,
## every Maya PR approved, Inez reviewed exactly; pushbacks alternate INSIST and
## WITHDRAW. Lines are samples of what each moment draws from.
static func sample_day() -> Array:
	var state := Simulation.initial_state()
	var log: Array = []
	var seen_arrivals := 0
	var seen_beats := 0
	var guard := 0
	while state.phase == "review" and guard < 600:
		guard += 1
		while seen_arrivals < state.arrivals.size():
			var arrival: Dictionary = state.arrivals[seen_arrivals]
			seen_arrivals += 1
			var packet := Catalog.packet(state, str(arrival.pr_id))
			var how := Encounters.arrival(state, packet)
			var options := Encounters.desk_lines(packet, str(how.node), str(how.mood), how.cited)
			log.append({"time": _clock(int(arrival.shift_seconds)), "pr": Catalog.display_id(str(arrival.pr_id)), "author": str(packet.author), "mood": str(how.mood), "node": str(how.node),
				"you": "", "desk": _choose(options, str(arrival.pr_id) + str(how.node)), "dm": ""})
		while seen_beats < state.encounters.size():
			var beat: Dictionary = state.encounters[seen_beats]
			seen_beats += 1
			var packet := Catalog.packet(state, str(beat.pr_id))
			var options := Encounters.desk_lines(packet, str(beat.node), str(beat.mood), beat.cited, str(beat.get("disputed", "")))
			var you := "approved" if beat.node in Encounters.APPROVALS else ("cited " + Policy.cited_words(beat.cited, 0))
			if beat.node == "withdrawn": you = "WITHDRAW " + Encounters.noun(str(beat.disputed))
			elif beat.node in ["insist_revise", "insist_escalate"]: you = "INSIST"
			var dm := "" if beat.node == "pushback" else Encounters.dm_text(beat, packet)
			log.append({"time": _clock(int(beat.shift_seconds)), "pr": Catalog.display_id(str(beat.pr_id)), "author": str(beat.author), "mood": str(beat.mood), "node": str(beat.node),
				"you": you, "desk": _choose(options, str(beat.pr_id) + str(beat.node)), "dm": dm})
		if Simulation.active_request(state).is_empty():
			if int(state.desk_at) < 0 or int(state.desk_at) >= Catalog.shift_seconds(): break
			state = Simulation.advance(state, int(state.desk_at) - int(state.shift_seconds))
			continue
		var pending := Encounters.pending(state)
		if not pending.is_empty():
			state = Simulation.advance(state, 6)
			state = Simulation.dispatch(state, {"type": "pushback", "choice": "withdraw" if state.encounters.size() % 2 == 0 else "insist"})
			continue
		var packet := Catalog.packet(state, state.active_request_id)
		var cited: Array = packet.violations
		if packet.author == "Theo": cited = ["P01"] if packet.violations.is_empty() else packet.violations
		elif packet.author == "Maya": cited = []
		state = Simulation.advance(state, 9)
		for rule_id: String in state.selected_rules.duplicate():
			state = Simulation.dispatch(state, {"type": "toggle-rule", "rule_id": rule_id})
		for rule_id: String in cited:
			state = Simulation.dispatch(state, Catalog.audit_citation(packet, rule_id))
		state = Simulation.dispatch(state, {"type": "review", "verdict": "request_changes" if not cited.is_empty() else "approve"})
	return log


static func _choose(options: Array, key: String) -> String:
	return "" if options.is_empty() else str(options[Policy.roll(key) % options.size()])


static func _clock(seconds: int) -> String:
	var minutes := 540 + floori(float(seconds) * 540.0 / float(Catalog.shift_seconds()))
	return "%02d:%02d" % [int(minutes / 60), minutes % 60]


static func sample_table(log: Array) -> String:
	var rows := PackedStringArray()
	for entry: Dictionary in log:
		var label: String = str(Encounters.NODES.get(entry.node, {}).get("label", entry.node))
		rows.append('<tr class="who-%s"><td class="t">%s</td><td>%s</td><td>%s</td><td><span class="chip" style="--c:%s">%s</span></td><td>%s</td><td class="node-cell">%s</td><td>%s</td><td class="dm">%s</td></tr>' % [
			str(entry.author).to_lower(), entry.time, _esc(str(entry.pr)), _esc(str(entry.author)), MOOD_COLORS.get(entry.mood, "#888"), entry.mood,
			_esc(str(entry.you)), _esc(label), _esc(str(entry.desk)), _esc(str(entry.dm))])
	return '<table class="day"><thead><tr><th>Time</th><th>PR</th><th>Author</th><th>Mood</th><th>You</th><th>Branch</th><th>At the desk</th><th>In Slouch</th></tr></thead><tbody>%s</tbody></table>' % "".join(rows)


static func trajectory(log: Array, author: String) -> String:
	var chips := PackedStringArray()
	for entry: Dictionary in log:
		if entry.author == author and entry.node != "pushback":
			chips.append('<span class="dot" style="--c:%s" title="%s %s: %s"></span>' % [MOOD_COLORS[entry.mood], entry.time, _esc(str(entry.pr)), entry.mood])
	return '<div class="trajectory"><span class="who">%s</span>%s</div>' % [author, "".join(chips)]


# --- The page --------------------------------------------------------------------------

static func mood_panel() -> String:
	var tones := PackedStringArray()
	for node: String in Encounters.TONE:
		var value := int(Encounters.TONE[node])
		tones.append('<li><span class="tone %s">%+d</span> %s</li>' % ["up" if value > 0 else "down", value, _esc(str(Encounters.NODES[node].label))])
	var bands := PackedStringArray()
	var floors: Dictionary = Encounters.MOOD_FLOORS
	var ranges := {"warm": "%d and up" % floors.warm, "neutral": "%d–%d" % [floors.neutral, floors.warm - 1], "strained": "%d–%d" % [floors.strained, floors.neutral - 1], "hostile": "below %d" % floors.strained}
	for mood: String in Encounters.MOODS:
		bands.append('<div class="band" style="--c:%s"><b>%s</b><span>%s</span></div>' % [MOOD_COLORS[mood], mood, ranges[mood]])
	var leans := PackedStringArray()
	for category: String in Encounters.LEANS:
		var parts := PackedStringArray()
		for node: String in Encounters.LEANS[category]: parts.append("%s %+d" % [str(Encounters.NODES[node].label).to_lower(), int(Encounters.LEANS[category][node])])
		leans.append("<li><b>%s</b>: %s</li>" % [category, ", ".join(parts)])
	var pile := PackedStringArray()
	for node: String in Encounters.PILE_LEAN: pile.append("%s %+d" % [str(Encounters.NODES[node].label).to_lower(), int(Encounters.PILE_LEAN[node])])
	leans.append("<li><b>%d+ citations at once</b>: %s</li>" % [Encounters.PILE_ON, ", ".join(pile)])
	return """
<section class="panel grid3">
  <div>
    <h3>Mood</h3>
    <p class="formula">score = relationship + tone of your last %d beats with this author</p>
    <div class="bands">%s</div>
    <p class="fine">Relationship is the existing coworker score (starts at 50; approvals raise it, change requests lower it). Mood is taken when a PR lands and again just before each stamp, before that stamp's own consequences apply. A revision keeps the mood of the beat that made it.</p>
  </div>
  <div>
    <h3>Tone each beat leaves</h3>
    <ul class="tones">%s</ul>
    <p class="fine">Extra relationship: abandoning %+d, insisting %+d, withdrawing %+d. Helios takes the PR on abandon or escalation; only a third-round escalation raises automation reliance, as before.</p>
  </div>
  <div>
    <h3>What you cited leans the branch</h3>
    <ul class="leans">%s</ul>
    <p class="fine">Weights are added before the roll. The roll is keyed on the PR, the verdict, the mood, and the cited standards, so the journal replays it exactly. Whether a citation is right never enters it: a right and a wrong citation take the same branch and get the same words.</p>
  </div>
</section>""" % [Encounters.MEMORY, "".join(bands), "".join(tones), int(Encounters.RELATIONSHIP.abandon), int(Encounters.RELATIONSHIP.insist_revise), int(Encounters.RELATIONSHIP.withdrawn), "".join(leans)]


static func legend() -> String:
	var loops := PackedStringArray()
	for loop: Array in LOOPS:
		loops.append('<li><span class="loop-chip">%s</span> %s → %s: %s</li>' % [loop[0], _esc(str(Encounters.NODES[loop[1]].label)), _esc(str(Encounters.NODES[loop[2]].label)), _esc(str(loop[3]))])
	var moods := PackedStringArray()
	for mood: String in Encounters.MOODS: moods.append('<span class="chip" style="--c:%s">%s %s</span>' % [MOOD_COLORS[mood], MOOD_SHORT[mood], mood])
	return """
<div class="legend">
  <span class="key say">author speaks</span><span class="key you">you act</span><span class="key slouch">Slouch later</span><span class="key start">start / end</span>
  <span class="sep"></span>branch odds by mood, in percent: %s
  <ul class="loops">%s</ul>
</div>""" % [" ".join(moods), "".join(loops)]


## Every campaign PR's own tree: its lines by node and mood, and its odds.
static func pr_panel() -> String:
	var options := PackedStringArray()
	var sections := PackedStringArray()
	var first := true
	for packet: Dictionary in Catalog.originals():
		var title := str(packet.title)
		var author := str(packet.author)
		var tree := Trees.tree(title)
		var id := str(packet.id)
		options.append('<option value="%s">Day %d · %s · %s · %s%s</option>' % [id, int(packet.day), id, author, _esc(_clip(title, 64)), "" if not tree.is_empty() else "  (templates)"])
		var rows := PackedStringArray()
		for channel: String in ["desk", "dm"]:
			for node: String in (DESK_ORDER if channel == "desk" else DM_ORDER):
				var cells := PackedStringArray()
				var any_line := false
				for mood: String in Encounters.MOODS:
					var text := Trees.line(title, channel, node, mood)
					if not text.is_empty(): any_line = true
					var shown := Encounters.fill(text, [EXAMPLE_TOPIC], EXAMPLE_TOPIC) if not text.is_empty() else ""
					cells.append('<td>%s</td>' % (_esc(shown) if not shown.is_empty() else '<span class="fine">author template</span>'))
				if any_line or channel == "desk":
					rows.append('<tr><th><span class="node-name">%s · %s</span></th>%s</tr>' % [channel, _esc(str(Encounters.NODES.get(node, {}).get("label", node))), "".join(cells)])
		var odds := PackedStringArray()
		for mood: String in Encounters.MOODS:
			var weights: Dictionary = Encounters.weights("changes", author, mood, [], title)
			var total := 0
			for node: String in weights: total += int(weights[node])
			var parts := PackedStringArray()
			for node: String in ["revise_now", "revise_later", "pushback", "abandon", "escalate"]:
				if weights.has(node) and total > 0: parts.append("%s %d%%" % [node.replace("_", " "), roundi(100.0 * int(weights[node]) / total)])
			odds.append('<td>%s</td>' % ", ".join(parts))
		var lean: Dictionary = Trees.lean(title)
		var lean_text := "no lean (author defaults)" if lean.is_empty() else ", ".join(lean.keys().map(func(node: Variant) -> String: return "%s %+d" % [str(node).replace("_", " "), int(lean[node])]))
		var face := _portrait(author)
		sections.append("""<section class="pr%s" id="pr-%s">
  <header class="author-head">%s<div><h2>%s</h2><p>%s · day %d · %s · this PR leans: %s</p></div></header>
  <div class="table-wrap"><table class="lines"><thead><tr><th>This PR's tree</th>%s</tr></thead><tbody>%s<tr><th><span class="node-name">odds after CHANGES REQUESTED</span></th>%s</tr></tbody></table></div>
</section>""" % [" on" if first else "", id, '<img class="face" src="%s" alt="%s">' % [face, author] if not face.is_empty() else "", _esc(title), id, int(packet.day), author, _esc(lean_text), _mood_headers(), "".join(rows), "".join(odds)])
		first = false
	return """<section class="author" id="tab-prs" role="tabpanel">
  <header class="author-head"><div><h2>Every PR has its own tree</h2><p>Pick a PR to see its author's lines at every branch and mood, and how its lean shifts the odds. "author template" marks anything the PR leaves to the author's shared lines.</p></div></header>
  <p><select id="pr-pick" aria-label="Pick a PR">%s</select></p>
  %s
</section>""" % ["".join(options), "".join(sections)]


static func page() -> String:
	var font := Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(FONT))
	var log := sample_day()
	var tabs := PackedStringArray()
	var panels := PackedStringArray()
	for index in range(Encounters.AUTHORS.size()):
		var author: String = Encounters.AUTHORS[index]
		var face := _portrait(author)
		var voice: String = {"Maya": "tired and dry: fixes it now for people she likes, gives up on people she doesn't", "Theo": "overconfident: argues first, and fixes at top speed", "Inez": "process-minded and passive-aggressive: proper revisions, escalation when in doubt"}[author]
		tabs.append('<button class="tab%s" data-tab="%s" role="tab" aria-selected="%s">%s%s</button>' % [" on" if index == 0 else "", author.to_lower(), "true" if index == 0 else "false", '<img src="%s" alt="">' % face if not face.is_empty() else "", author])
		panels.append("""
<section class="author%s" id="tab-%s" role="tabpanel">
  <header class="author-head">%s<div><h2>%s</h2><p>%s</p></div></header>
  <div class="chart-wrap">%s</div>
  <h3>Every line, by node and mood</h3>
  <div class="table-wrap">%s</div>
  <div class="table-wrap">%s</div>
  <div class="table-wrap">%s</div>
</section>""" % [" on" if index == 0 else "", author.to_lower(), '<img class="face" src="%s" alt="%s">' % [face, author] if not face.is_empty() else "", author, voice, chart(author), desk_table(author), dm_table(author), morgan_table(author)])
	tabs.append('<button class="tab" data-tab="prs" role="tab" aria-selected="false">Per PR</button>')
	panels.append(pr_panel())
	var trajectories := PackedStringArray()
	for author: String in Encounters.AUTHORS: trajectories.append(trajectory(log, author))
	return """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Encounter Flow Charts</title>
<style>
@font-face { font-family: "IBM Plex Mono"; src: url(data:font/ttf;base64,%s) format("truetype"); font-weight: 400; }
:root { --bg: #0a0a0b; --surface: #141416; --inset: #070708; --border: #2c2c31; --text: #e6e2d6; --dim: #8c8981; --green: #6fdc8c; --red: #e5384a; --amber: #e0b44a; --paper: #a9ada4; }
* { box-sizing: border-box; }
html { background: var(--bg); }
body { margin: 0; background: var(--bg); color: var(--text); font: 14px/1.5 "IBM Plex Mono", ui-monospace, Menlo, monospace; }
main { max-width: 1680px; margin: 0 auto; padding: 24px 16px 64px; }
h1 { font-size: 22px; margin: 0 0 4px; color: var(--green); font-weight: 400; letter-spacing: .02em; }
h1 .prompt { color: var(--dim); }
h2 { margin: 0; font-size: 20px; font-weight: 400; color: var(--text); }
.pr { display: none; } .pr.on { display: block; }
#pr-pick { background: var(--inset); color: var(--text); border: 1px solid var(--border); font: inherit; padding: 6px 8px; max-width: 100%%; }
h3 { font-size: 13px; color: var(--red); letter-spacing: .08em; text-transform: uppercase; font-weight: 400; margin: 28px 0 10px; }
p { margin: 6px 0; }
.lede { color: var(--dim); max-width: 980px; }
.panel { background: var(--surface); border: 1px solid var(--border); padding: 14px 18px; margin: 18px 0; }
.panel h3 { margin-top: 0; }
.grid3 { display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 22px; }
.formula { color: var(--green); }
.fine { color: var(--dim); font-size: 12px; }
.bands { display: grid; grid-template-columns: repeat(4, 1fr); gap: 4px; margin: 10px 0; }
.band { border-top: 3px solid var(--c); padding: 4px 6px; background: var(--inset); }
.band b { color: var(--c); font-weight: 400; display: block; }
.band span { color: var(--dim); font-size: 12px; }
ul { margin: 0; padding-left: 18px; }
.tones, .leans { list-style: none; padding: 0; columns: 2; font-size: 12px; }
.tone { display: inline-block; min-width: 2.4em; }
.tone.up { color: var(--green); } .tone.down { color: var(--red); }
.tabs { display: flex; gap: 6px; margin: 22px 0 0; flex-wrap: wrap; }
.tab { font: inherit; color: var(--dim); background: var(--inset); border: 1px solid var(--border); border-bottom: none; padding: 8px 16px 8px 10px; cursor: pointer; display: flex; align-items: center; gap: 8px; }
.tab img { width: 28px; height: 28px; image-rendering: pixelated; }
.tab.on { color: var(--green); background: var(--surface); border-color: var(--green); }
.tab:focus-visible { outline: 2px solid var(--green); outline-offset: 2px; }
.author { display: none; background: var(--surface); border: 1px solid var(--border); padding: 16px; }
.author.on { display: block; }
.author-head { display: flex; gap: 14px; align-items: center; }
.author-head .face { width: 64px; height: 64px; image-rendering: pixelated; background: var(--inset); border: 1px solid var(--border); }
.author-head p { color: var(--dim); }
.moods { display: flex; gap: 6px; align-items: center; margin: 14px 0 8px; flex-wrap: wrap; color: var(--dim); font-size: 12px; }
.moods button { font: inherit; font-size: 12px; background: var(--inset); color: var(--text); border: 1px solid var(--border); padding: 3px 10px; cursor: pointer; }
.moods button.on { border-color: var(--c, var(--green)); color: var(--c, var(--green)); }
.chart-wrap { overflow-x: auto; background: var(--inset); border: 1px solid var(--border); padding: 8px 4px; }
.chart { display: block; min-width: 1180px; width: 100%%; height: auto; }
.chart .heading { fill: var(--red); font-size: 10px; letter-spacing: .12em; }
.chart .group { fill: none; stroke: var(--border); stroke-dasharray: 3 3; }
.chart .group-label { fill: var(--dim); font-size: 10px; }
.chart .edge { fill: none; stroke: #4d4c50; stroke-width: 1.4; transition: stroke-width .15s, stroke .15s, opacity .15s; }
.chart .edge.fixed { stroke: #6a6964; }
.chart .arrowhead { fill: #6a6964; }
.chart .edge-label { fill: var(--dim); font-size: 10px; }
.chart .node-odds { font-size: 10px; }
.chart .node .condition { fill: var(--amber); font-size: 9.5px; }
.chart .odds { transition: opacity .15s; }
.chart .node rect { fill: var(--surface); stroke: #3d5c46; stroke-width: 1; }
.chart .node.say rect { fill: #10150f; stroke: #3f7a52; }
.chart .node.you rect { fill: #17130a; stroke: var(--amber); }
.chart .node.you .label { fill: var(--amber); letter-spacing: .06em; }
.chart .node.slouch rect { fill: #0e1116; stroke: #54738e; stroke-dasharray: 4 3; }
.chart .node.start rect, .chart .node.end rect { fill: var(--inset); stroke: var(--green); }
.chart .node .label { fill: var(--text); font-size: 12px; }
.chart .node .sample { fill: var(--dim); font-size: 10px; }
.chart .node-link:hover rect, .chart .node-link:focus rect { stroke: var(--green); stroke-width: 2; }
.chart .loop line { stroke: #6a6964; }
.chart .loop circle { fill: var(--inset); stroke: var(--amber); }
.chart .loop text { fill: var(--amber); font-size: 10px; }
.legend { display: flex; flex-wrap: wrap; gap: 8px 14px; align-items: center; font-size: 12px; color: var(--dim); margin: 10px 0 0; }
.legend .key { padding: 2px 8px; border: 1px solid; }
.legend .key.say { border-color: #3f7a52; color: var(--text); background: #10150f; }
.legend .key.you { border-color: var(--amber); color: var(--amber); background: #17130a; }
.legend .key.slouch { border: 1px dashed #54738e; color: #b6cfe5; }
.legend .key.start { border-color: var(--green); color: var(--green); }
.legend .sep { flex-basis: 100%%; height: 0; }
.legend .loops { list-style: none; padding: 0; flex-basis: 100%%; display: grid; grid-template-columns: repeat(auto-fit, minmax(360px, 1fr)); gap: 2px 18px; }
.loop-chip { display: inline-block; width: 18px; height: 18px; border-radius: 50%%; border: 1px solid var(--amber); color: var(--amber); text-align: center; line-height: 16px; font-size: 10px; }
.chip { display: inline-block; padding: 0 7px; border: 1px solid var(--c); color: var(--c); font-size: 11px; line-height: 18px; }
.table-wrap { overflow-x: auto; margin: 10px 0 18px; }
table { border-collapse: collapse; width: 100%%; font-size: 12px; }
th, td { border: 1px solid var(--border); padding: 6px 8px; vertical-align: top; text-align: left; }
thead th { color: var(--dim); font-weight: 400; background: var(--inset); position: sticky; top: 0; }
tbody th { width: 210px; font-weight: 400; background: var(--inset); }
.node-name { display: block; color: var(--green); }
.node-about { display: block; color: var(--dim); font-size: 11px; margin-top: 2px; }
td ul { padding-left: 14px; }
td li { margin: 2px 0; }
.note { color: var(--amber); font-size: 11px; margin-bottom: 3px; }
tr:target th, tr:target td { background: #17130a; }
.day td.t { color: var(--dim); white-space: nowrap; }
.day td.dm { color: #b6cfe5; }
.day .node-cell { color: var(--green); white-space: nowrap; }
.trajectories { display: grid; gap: 6px; margin: 10px 0 14px; }
.trajectory { display: flex; align-items: center; gap: 3px; flex-wrap: wrap; }
.trajectory .who { width: 56px; color: var(--text); }
.dot { width: 14px; height: 14px; background: var(--c); display: inline-block; }
footer { color: var(--dim); font-size: 12px; margin-top: 40px; border-top: 1px solid var(--border); padding-top: 12px; }
@media (max-width: 640px) { .tones, .leans { columns: 1; } tbody th { width: 140px; } }
</style>
</head>
<body>
<main>
<h1><span class="prompt">root@paperclip:~$</span> encounter --flow-charts</h1>
<p class="lede">How a PR's author responds at the desk in PRs please. Every branch depends on how the author feels about you (mood) and on what you visibly did (the verdict, and which standards you cited), never on whether the PR is really broken or your citation is right. Generated from <code>content/encounters.gd</code>; hover a node for its description and a sample line, click it to jump to every line.</p>
%s
<div class="moods" role="group" aria-label="Show odds for a mood">Odds shown for <button class="on" data-mood="all">all moods</button><button data-mood="warm" style="--c:#6fdc8c">warm</button><button data-mood="neutral" style="--c:#e6e2d6">neutral</button><button data-mood="strained" style="--c:#e0b44a">strained</button><button data-mood="hostile" style="--c:#e5384a">hostile</button></div>
%s
<div class="tabs" role="tablist">%s</div>
%s
<section class="panel">
  <h3>A sample Monday: moods move</h3>
  <p class="fine">Every Theo PR is sent back, every Maya PR approved, Inez reviewed exactly; pushbacks alternate WITHDRAW and INSIST. One square per beat, colored by mood. Desk lines are samples from that moment's pool.</p>
  <div class="trajectories">%s</div>
  <div class="table-wrap">%s</div>
</section>
<footer>Generated by tools/encounter_flowchart.gd · %d nodes · %d edges · %d authored lines.</footer>
</main>
<script>
(function () {
  var tabs = document.querySelectorAll('.tab');
  tabs.forEach(function (tab) {
    tab.addEventListener('click', function () {
      tabs.forEach(function (t) { t.classList.toggle('on', t === tab); t.setAttribute('aria-selected', t === tab ? 'true' : 'false'); });
      document.querySelectorAll('.author').forEach(function (panel) { panel.classList.toggle('on', panel.id === 'tab-' + tab.dataset.tab); });
    });
  });
  if (location.hash) {
    var target = document.getElementById(location.hash.slice(1));
    var panel = target && target.closest('.author');
    if (panel) { var tab = document.querySelector('.tab[data-tab="' + panel.id.slice(4) + '"]'); if (tab) tab.click(); }
  }
  var pick = document.getElementById('pr-pick');
  if (pick) pick.addEventListener('change', function () {
    document.querySelectorAll('.pr').forEach(function (section) { section.classList.toggle('on', section.id === 'pr-' + pick.value); });
  });
  var moodButtons = document.querySelectorAll('.moods button');
  moodButtons.forEach(function (button) {
    button.addEventListener('click', function () {
      var mood = button.dataset.mood;
      moodButtons.forEach(function (b) { b.classList.toggle('on', b === button); });
      document.querySelectorAll('.edge.pick').forEach(function (edge) {
        if (mood === 'all') { edge.style.strokeWidth = ''; edge.style.opacity = ''; edge.style.stroke = ''; return; }
        var p = Number(edge.dataset[mood] || 0);
        edge.style.strokeWidth = (0.6 + p / 9).toFixed(2);
        edge.style.opacity = p ? 1 : 0.15;
        edge.style.stroke = button.style.getPropertyValue('--c');
      });
      document.querySelectorAll('.odds').forEach(function (odds) { odds.style.opacity = (mood === 'all' || odds.dataset.mood === mood) ? 1 : 0.12; });
    });
  });
})();
</script>
</body>
</html>
""" % [font, mood_panel(), legend(), "".join(tabs), "".join(panels), "".join(trajectories), sample_table(log), Encounters.NODES.size(), Encounters.EDGES.size(), _authored_count()]


static func _authored_count() -> int:
	var count := 0
	for author: String in Lines.BY_AUTHOR:
		for channel: String in Lines.BY_AUTHOR[author]:
			for node: String in Lines.BY_AUTHOR[author][channel]:
				for mood: String in Lines.BY_AUTHOR[author][channel][node]: count += Lines.BY_AUTHOR[author][channel][node][mood].size()
	for node: String in Lines.MORGAN:
		for mood: String in Lines.MORGAN[node]: count += Lines.morgan(node, mood).size()
	return count
