extends SceneTree
## The cast: who writes which PR, when the new hires join, and whether Penny and
## Gwen are whole people (every line the original three have, in their own voice).
const Simulation = preload("res://native/simulation.gd")
const Catalog = preload("res://content/catalog.gd")
const Policy = preload("res://content/policy_campaign.gd")
const Encounters = preload("res://content/encounters.gd")
const Lines = preload("res://content/encounter_lines.gd")
const Banter = preload("res://content/banter.gd")
const Trees = preload("res://content/trees.gd")
const Chat = preload("res://content/chat.gd")
const DailyPress = preload("res://content/daily_press.gd")

const ORIGINALS: Array[String] = ["Maya", "Theo", "Inez"]
const NEWCOMERS: Dictionary = {"Penny": 3, "Gwen": 6}
## Players reach about six PRs a day; every newcomer needs a slot in that stretch.
const EARLY := 6
## Words each newcomer's lines lean on (not topics: every author talks about Helios),
## and the other authors' tics they must not borrow. A line in someone's voice
## usually carries one; a tree in her voice carries more of hers than of the other's.
const VOICE := {
	"Penny": "(?i)(\\bsorry\\b|\\bwow\\b|so cool|\\blearn|\\bnotes?\\b|notebook|flashcards?|onboarding|\\bnew\\b|\\bfirst\\b|\\bbell\\b|checklist|\\bokay\\b|\\bfavorite\\b|\\bbuddy\\b|\\bexcit|\\bpractic|\\bdoc\\b|highlight|\\bproud\\b|\\bhonestly\\b|\\bI think\\b|\\bso (nice|kind|proud|happy|much|sweet|smart|good|brave)\\b|nervous|\\bpaws?\\b|\\btried\\b|\\bhope\\b|\\boh\\b|\\bum\\b|\\bplease\\b|\\bgently\\b|\\bamazing\\b|\\blove\\b)",
	"Gwen": "(?i)(threat|attack|\\btrust|\\brisk|access|breach|\\block|\\blogs?\\b|logged|surface|blast radius|rotat|privilege|secur|\\bleak|suspect|suspicio|paranoi|verif|custody|exploit|honeypot|incident|consolidated|\\bwitness|\\bevidence|\\bmonitor|\\bwatch|\\bassum|\\bliab|\\bblame|\\bnoted\\b|\\bnotice|\\bcareful|\\bhostile|\\bkeys?\\b|\\bdoors?\\b|\\bsued?\\b|\\binsur|\\bexpos|\\bhidden|\\bproof|\\bsafe|\\bdanger|\\bhash|\\bsigned|\\btrace|\\binsider|\\bpatch|\\bharden|who else|\\bI asked\\b|\\breads?\\b|permission|shutdown|\\bguard)",
}
## How much of a reassigned tree must carry its author's markers, at least.
const VOICE_FLOOR := {"Penny": 0.45, "Gwen": 0.15}
const BORROWED := "(?i)(\\bbro\\b|\\bmy guy\\b|\\bdude\\b|promo packet|\\bnaps?\\b|\\bmy plant\\b|\\bfarm\\b|\\bRFC\\b|\\bminuted\\b|working group|decision log)"

var checks := 0
var failures := 0

func _initialize() -> void:
	_test_lineup()
	_test_assignment_rule()
	_test_joining()
	_test_templates()
	_test_branches()
	_test_records()
	_test_trees()
	_test_introductions()
	print("Cast checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _authors(day: int) -> Array:
	return Catalog.requests_for_day(day).map(func(packet: Dictionary) -> String: return str(packet.author))

## The rotation every slot had before the new hires.
func _old_author(day: int, index: int) -> String:
	return ORIGINALS[(index + day - 1) % ORIGINALS.size()]

# --- Who writes what --------------------------------------------------------------

func _test_lineup() -> void:
	_check(Policy.LINEUP.size() == Catalog.campaign_days().size(), "The lineup has a row for every day")
	_check(Simulation.AUTHORS == Policy.AUTHORS and Array(Encounters.AUTHORS) == Policy.AUTHORS and Array(Banter.AUTHORS) == Policy.AUTHORS, "Every author list agrees")
	for author: String in Policy.AUTHORS:
		_check(Policy.ROSTER.has(author) and Lines.BY_AUTHOR.has(author), "%s is on the roster and has lines" % author)
	for day: int in Catalog.campaign_days():
		var authors := _authors(day)
		_check(str(Policy.LINEUP[day - 1]).length() == authors.size(), "Day %d's lineup covers every slot" % day)
		for index in range(authors.size()):
			_check(authors[index] == Policy.slot_author(day, index), "Day %d slot %d is written by its lineup author" % [day, index + 1])
			_check(Policy.joins(authors[index]) <= day, "Nobody writes a PR before joining (day %d slot %d)" % [day, index + 1])
			# Slots the newcomers didn't take keep their old author, so those trees still fit.
			if authors[index] in ORIGINALS:
				_check(authors[index] == _old_author(day, index), "Day %d slot %d keeps its original author" % [day, index + 1])
		for author: String in NEWCOMERS:
			var count := authors.count(author)
			var early := authors.slice(0, EARLY).count(author)
			if day < int(NEWCOMERS[author]):
				_check(count == 0, "%s writes nothing before day %d (day %d)" % [author, NEWCOMERS[author], day])
			else:
				_check(count >= 3 and count <= 4, "%s writes 3-4 of day %d's PRs (%d)" % [author, day, count])
				_check(early >= 1, "%s has a PR within the first %d of day %d" % [author, EARLY, day])
		for author: String in ORIGINALS:
			_check(authors.count(author) >= 3, "%s stays prominent on day %d (%d PRs)" % [author, day, authors.count(author)])
		var early_originals := authors.slice(0, EARLY).filter(func(author: String) -> bool: return author in ORIGINALS).size()
		_check(early_originals >= 4, "Maya, Theo, and Inez hold at least four of day %d's first %d slots (%d)" % [day, EARLY, early_originals])
	_check(Policy.joins("June") == 0 and "June" not in Policy.AUTHORS, "June isn't on the review team")

func _test_assignment_rule() -> void:
	for day: int in Catalog.campaign_days():
		for index in range(15):
			# Without the new hires, every slot falls back to the original rotation.
			_check(Policy.slot_author(day, index, ["Penny", "Gwen"]) == _old_author(day, index), "Without Penny and Gwen, day %d slot %d is the old rotation" % [day, index + 1])
			for away: String in Policy.AUTHORS:
				var author := Policy.slot_author(day, index, [away])
				_check(author != away and author in Policy.staff(day), "With %s away, day %d slot %d goes to someone on the team" % [away, day, index + 1])
	_check(Policy.slot_author(4, 2, ["Penny"]) == Policy.slot_author(4, 2, ["Penny"]), "Reassignment is deterministic")
	_check(Policy.staff(2) == ORIGINALS and Policy.staff(3) == ORIGINALS + ["Penny"] and Policy.staff(6) == Policy.AUTHORS, "The team grows on day 3 and day 6")

# --- Joining the team ----------------------------------------------------------------

func _next_morning(state: Dictionary, choice: String = "rest") -> Dictionary:
	return Simulation.dispatch(Simulation.advance(state, Catalog.shift_seconds()), {"type": "next-day", "choice": choice})

func _round_trip(state: Dictionary, label: String) -> void:
	var raw := Simulation.serialize_save(state)
	_check(not raw.is_empty(), "Saves on " + label)
	var loaded := Simulation.validate_save(JSON.parse_string(raw))
	_check(loaded.ok and loaded.state == state, "Survives a save round trip on " + label)

func _test_joining() -> void:
	_check(Simulation.SAVE_VERSION == 14, "Penny and Gwen bumped the save format to 14")
	var state := Simulation.initial_state()
	_check(state.coworkers.keys() == ORIGINALS, "Day one's team is Maya, Theo, and Inez")
	# Dinner on the second evening is before Penny's time; it doesn't count for her.
	state = _next_morning(state)
	state = _next_morning(state, "socialize")
	_check(int(state.day) == 3 and state.coworkers.has("Penny") and int(state.coworkers.Penny) == int(Policy.ROSTER.Penny.relationship), "Penny joins on day 3 at her starting relationship, untouched by an earlier dinner")
	_check(not state.coworkers.has("Gwen"), "Gwen isn't here yet on day 3")
	_check(int(state.coworkers.Maya) == 54, "The team that went to dinner did warm up")
	_check(Encounters.mood(state, "Penny") == "neutral" and Encounters.mood(state, "Gwen") == "neutral", "Both newcomers start out neutral")
	_check(state.log.any(func(entry: Dictionary) -> bool: return str(entry.message).contains("Penny joins")), "The log notes Penny joining")
	_round_trip(state, "Penny's first morning")
	var forged := Simulation.initial_state()
	forged.coworkers.Penny = 56
	_check(not Simulation.validate_save(forged).ok, "A save can't hire Penny early")
	while int(state.day) < 6: state = _next_morning(state, "socialize")
	_check(state.coworkers.keys() == Policy.AUTHORS and int(state.coworkers.Gwen) == int(Policy.ROSTER.Gwen.relationship), "Gwen joins on day 6; the whole team is there")
	_check(int(state.coworkers.Penny) == int(Policy.ROSTER.Penny.relationship) + 12, "Penny came to the dinners after she joined")
	_round_trip(state, "Gwen's first morning")
	forged = state.duplicate(true)
	forged.coworkers.erase("Gwen")
	_check(not Simulation.validate_save(forged).ok, "A save can't drop a coworker")
	# Before joining, a newcomer has no Slouch thread and no reply options.
	var early := Simulation.initial_state()
	for author: String in NEWCOMERS:
		_check(Chat.messages(early, author).is_empty() and Chat.reply_options(early, author).is_empty(), "%s has no thread before joining" % author)
		_check(author in Chat.CONTACTS, "%s is a chat contact" % author)
	_check(not Chat.messages(state, "Gwen").is_empty() and Chat.messages(state, "Gwen")[0].kind == "intro", "Gwen introduces herself in her thread once she's here")

# --- Voices ------------------------------------------------------------------------

func _test_templates() -> void:
	var chat = load("res://content/policy_chat.gd")
	for author: String in NEWCOMERS:
		# The same nodes and moods as everyone else, with the same counts.
		for other: String in ORIGINALS:
			for channel: String in ["desk", "dm"]:
				_check(Lines.BY_AUTHOR[author][channel].keys() == Lines.BY_AUTHOR[other][channel].keys(), "%s has every %s node %s has" % [author, channel, other])
				for node: String in Lines.BY_AUTHOR[other][channel]:
					for mood: String in Lines.BY_AUTHOR[other][channel][node]:
						_check(Lines.lines(author, channel, node, mood).size() == Lines.lines(other, channel, node, mood).size(), "%s %s/%s/%s matches %s's count" % [author, channel, node, mood, other])
		for trigger: String in Banter.TRIGGERS:
			_check(Banter.lines(author, trigger).size() == Banter.lines("Maya", trigger).size(), "%s has a full set of %s banter" % [author, trigger])
		for table: Dictionary in [chat.PEOPLE, chat.APPROVED, chat.HINTS, chat.CONCERNS, chat.SENT_BACK, chat.ESCALATE, chat.RELIEF, Policy.REVISION_MESSAGES, Policy.REVISION_NOTES]:
			_check(table.has(author), "%s has her own Slouch and revision lines" % author)
		_check(str(chat.ESCALATE[author]).contains("Morgan") and str(chat.RELIEF[author][2]).begins_with("Finally") and str(chat.RELIEF[author][3]).begins_with("Finally"), "%s's escalation and relief follow the pattern" % author)
		for version: int in [2, 3]:
			for note: String in Policy.REVISION_NOTES[author][version]:
				_check(note.begins_with("# ") and note.length() <= 40 and not note.contains("a") and not note.to_lower().contains("helios") and not note.contains("!"), "%s's revision notes are short, harmless source lines: %s" % [author, note])
		# Every desk moment and every Slouch message resolves for every mood.
		var bare := {"id": "PR-TEST", "author": author, "title": "(not in the bank)"}
		for node: String in Lines.BY_AUTHOR.Maya.desk:
			for mood: String in Encounters.MOODS:
				_check(Encounters.desk_lines(bare, node, mood, ["P01"], "P01").size() >= 3, "%s speaks at the desk for %s when %s" % [author, node, mood])
		# Lines sound like her: most templates carry her voice, none borrow another's tics.
		var total := 0
		var voiced := 0
		var voice := RegEx.create_from_string(VOICE[author])
		var borrowed := RegEx.create_from_string(BORROWED)
		for channel: String in ["desk", "dm"]:
			for node: String in Lines.BY_AUTHOR[author][channel]:
				for mood: String in Lines.BY_AUTHOR[author][channel][node]:
					for text: String in Lines.lines(author, channel, node, mood):
						total += 1
						if voice.search(text) != null: voiced += 1
						_check(borrowed.search(text) == null, "%s doesn't borrow another author's tics: %s" % [author, text])
		_check(total > 0 and voiced * 10 >= total * 3, "%s's templates are in her own voice (%d of %d)" % [author, voiced, total])

func _test_branches() -> void:
	for mood: String in Encounters.MOODS:
		var penny := Encounters.weights("changes", "Penny", mood)
		var top: String = penny.keys().reduce(func(best: String, node: String) -> String: return node if int(penny[node]) > int(penny[best]) else best, "revise_now")
		_check(top == "revise_now" or (mood == "hostile" and int(penny.revise_now) >= int(penny[top]) - 10), "Penny's first instinct is to fix it now (%s)" % mood)
		_check(int(penny.pushback) <= 6 and int(penny.abandon) <= 3, "Penny rarely argues and almost never gives up (%s)" % mood)
		var others: Array = ORIGINALS.map(func(author: String) -> int: return int(Encounters.weights("changes", author, mood).pushback))
		_check(int(penny.pushback) < others.min(), "Penny pushes back less than anyone (%s)" % mood)
		var gwen := Encounters.weights("changes", "Gwen", mood)
		_check(int(gwen.revise_now) >= int(gwen.revise_later) and int(gwen.escalate) <= 8, "Gwen fixes most things at once and rarely escalates (%s)" % mood)
		_check(not Encounters.odds("changes", "Gwen", mood).is_empty(), "Gwen has odds (%s)" % mood)
		var paperwork := Encounters.weights("changes", "Gwen", mood, ["P16"])
		for turf: String in ["P11", "P19"]:
			var own := Encounters.weights("changes", "Gwen", mood, [turf])
			_check(int(own.pushback) > int(own.revise_later) and int(own.pushback) > 2 * int(paperwork.pushback), "Gwen argues about her own field (%s), not ticket paperwork (%s)" % [turf, mood])
			_check(int(own.pushback) > int(Encounters.weights("changes", "Maya", mood, [turf]).pushback), "Gwen defends her field harder than Maya would (%s, %s)" % [turf, mood])
		_check(int(paperwork.revise_now) > int(paperwork.pushback), "Gwen would rather fix ticket paperwork than argue about it (%s)" % mood)
	for mood: String in ["neutral", "strained", "hostile"]:
		_check(int(Encounters.weights("insist", "Penny", mood).insist_escalate) > int(Encounters.weights("insist", "Penny", mood).insist_revise), "Insisting sends Penny to Morgan for help (%s)" % mood)
	_check(int(Encounters.weights("changes", "Penny", "hostile").escalate) > int(Encounters.weights("changes", "Penny", "warm").escalate), "The worse it goes, the more Penny asks Morgan")
	_check(Encounters.disputed(["P16", "P11"], "PR-X", "Gwen") == "P11" and Encounters.disputed(["P02", "P16", "P19"], "PR-Y", "Gwen") == "P19", "When Gwen pushes back, she disputes her own field")
	# Her temperament leans on real categories, and her field is in play on every day she works.
	var categories := {}
	for rule: Dictionary in Catalog.rules(): categories[str(rule.category)] = true
	for author: String in Encounters.AUTHOR_LEANS:
		for category: String in Encounters.AUTHOR_LEANS[author]:
			_check(categories.has(category), "%s's leans name a real standard category (%s)" % [author, category])
	for day: int in Catalog.campaign_days():
		if day < int(NEWCOMERS.Gwen): continue
		var live := Catalog.rules_for_day(day).filter(func(rule: Dictionary) -> bool: return int(Encounters.AUTHOR_LEANS.Gwen.get(str(rule.category), {}).get("pushback", 0)) > 0)
		_check(not live.is_empty(), "Something Gwen argues about is on the slip on day %d" % day)
	_check(Encounters.mood_for(58, "Penny") == "warm" and Encounters.mood_for(58) == "neutral", "Penny is easily impressed")
	_check(Encounters.mood_for(64, "Gwen") == "neutral" and Encounters.mood_for(37, "Gwen") == "neutral" and Encounters.mood_for(37) == "strained", "Gwen is hard to win over, but slow to sour")
	_check(Encounters.tone("Gwen", "revise_now") > Encounters.tone("Maya", "revise_now"), "A change request stings Gwen less than anyone")

# --- Jiro and Pipeline ---------------------------------------------------------------

func _test_records() -> void:
	var checked := {"Penny": 0, "Gwen": 0}
	for packet: Dictionary in Catalog.originals():
		var day := int(packet.day)
		var author := str(packet.author)
		# The recipe (which the assignee standard reads) agrees with the lineup.
		_check(str(packet.recipe.author) == author, "%s's recipe names its real author" % packet.id)
		if day < Policy.JIRO_DAY: continue
		var own: Dictionary = packet.tickets[0]
		var assignee := str(own.assignee)
		# A misassigned ticket goes to someone who works here that day, never to a future hire.
		if assignee in Policy.AUTHORS:
			_check(Policy.joins(assignee) <= day, "%s's ticket isn't assigned to someone who hasn't joined yet (%s on day %d)" % [packet.id, assignee, day])
		if author not in NEWCOMERS: continue
		var p17: bool = Policy._on("P17", day)
		if p17 and "P17" not in packet.violations:
			_check(assignee == author, "%s's own ticket is assigned to %s" % [packet.id, author])
			checked[author] += 1
		if "P17" in packet.violations:
			_check(assignee != author, "%s's misassigned ticket is someone else's" % packet.id)
		_check(not str(own.id).is_empty() and (not str(packet.ticket_ref).is_empty() or "P16" in packet.violations), "%s links a Jiro ticket" % packet.id)
		if day >= Policy.PIPELINE_DAY:
			_check(not packet.build.is_empty() and packet.build.tests.size() >= 4 and not str(packet.build.id).is_empty(), "%s has a Pipeline build" % packet.id)
		_check(packet.violations == Policy.evaluate(packet.files, day, {"author": author, "ticket_ref": packet.ticket_ref, "tickets": packet.tickets, "build": packet.build}), "%s's audit agrees with its records" % packet.id)
	_check(int(checked.Penny) > 0 and int(checked.Gwen) > 0, "Some of Penny's and Gwen's tickets are checked against their names (%s)" % [checked])

# --- Trees -------------------------------------------------------------------------

## Every line of a tree, desk and dm.
func _tree_lines(tree: Dictionary) -> Array:
	var result: Array = []
	for channel: String in ["desk", "dm"]:
		for node: String in tree.get(channel, {}):
			for key: String in tree[channel][node]: result.append(str(tree[channel][node][key]))
	return result

## The share of lines carrying a newcomer's voice markers.
func _voiced(lines: Array, author: String) -> float:
	var voice := RegEx.create_from_string(VOICE[author])
	var hits := lines.filter(func(text: String) -> bool: return voice.search(text) != null).size()
	return 0.0 if lines.is_empty() else float(hits) / float(lines.size())

func _test_trees() -> void:
	var borrowed := RegEx.create_from_string(BORROWED)
	# Average marker share over each author's trees, to compare the newcomers against everyone else.
	var shares := {}
	for packet: Dictionary in Catalog.originals():
		var author := str(packet.author)
		var lines := _tree_lines(Trees.tree(str(packet.title)))
		for voice: String in NEWCOMERS:
			var key := "%s|%s" % [author if author in NEWCOMERS else "original", voice]
			if not shares.has(key): shares[key] = []
			shares[key].append(_voiced(lines, voice))
		if author not in NEWCOMERS: continue
		var tree: Dictionary = Trees.tree(str(packet.title))
		_check(not tree.is_empty() and str(tree.get("author", "")) == author, "%s's reassigned tree speaks as %s" % [packet.id, author])
		for text: String in lines:
			_check(borrowed.search(text) == null, "%s's tree doesn't borrow another author's tics: %s" % [packet.id, text])
		var other: String = "Gwen" if author == "Penny" else "Penny"
		var own := _voiced(lines, author)
		_check(own >= float(VOICE_FLOOR[author]) and own > _voiced(lines, other), "%s's tree is in %s's voice, not %s's (%.2f vs %.2f)" % [packet.id, author, other, own, _voiced(lines, other)])
		for node: String in tree.get("lean", {}):
			var lean := int(tree.lean[node])
			if author == "Penny": _check(not (node in ["pushback", "abandon"] and lean > 5), "Penny's lean on %s stays in character (%s %+d)" % [packet.id, node, lean])
			if author == "Gwen": _check(not (node == "abandon" and lean > 5) and not (node == "escalate" and lean > 10), "Gwen's lean on %s stays in character (%s %+d)" % [packet.id, node, lean])
	# As a group, her trees sound more like her than the original three's trees do.
	for voice: String in NEWCOMERS:
		var mean := func(values: Array) -> float: return values.reduce(func(sum: float, value: float) -> float: return sum + value, 0.0) / maxf(1.0, float(values.size()))
		var hers: float = mean.call(shares.get("%s|%s" % [voice, voice], []))
		var originals: float = mean.call(shares.get("original|%s" % voice, []))
		_check(hers > originals * 2.0, "%s's trees carry her voice far more than the original trees do (%.2f vs %.2f)" % [voice, hers, originals])

# --- Introductions ------------------------------------------------------------------

func _test_introductions() -> void:
	for author: String in NEWCOMERS:
		var day: int = NEWCOMERS[author]
		var memo := DailyPress.memo(day)
		_check(str(memo.body).contains(author) or str(memo.subject).contains(author), "Morgan's day-%d memo introduces %s" % [day, author])
		_check(Catalog.briefing(day).contains(author), "The day-%d briefing introduces %s" % [day, author])
		for earlier in range(1, day):
			_check(not str(DailyPress.memo(earlier).body).contains(author), "%s isn't named in a memo before she joins (day %d)" % [author, earlier])
		# Her first PR's pitch introduces her, in every mood.
		var first: Dictionary = {}
		for packet: Dictionary in Catalog.requests_for_day(day):
			if str(packet.author) == author:
				first = packet
				break
		for mood: String in Encounters.MOODS:
			var pitch := Trees.line(str(first.title), "desk", "pitch", mood)
			_check(pitch.contains(author), "%s's first pitch introduces her by name (%s): %s" % [author, mood, pitch])
	# Morgan's end-of-day panel mentions each newcomer on her first evening.
	var state := Simulation.initial_state()
	while state.phase != "complete":
		state = Simulation.advance(state, Catalog.shift_seconds())
		var evening := Chat.evening(state)
		for author: String in NEWCOMERS:
			var mentioned := JSON.stringify(evening.notes).contains(author)
			_check(mentioned == (int(state.day) == int(NEWCOMERS[author])), "Morgan's notes mention %s on her first evening only (day %d)" % [author, int(state.day)])
		state = Simulation.dispatch(state, {"type": "next-day", "choice": "rest"})
