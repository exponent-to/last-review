extends RefCounted
## Authored conversation derived from desk arrivals, decisions, and saved reply choices.
## The Slouch chat app is off the desktop for now; these conversations stay authored
## and tested for a future chat app. Morgan's end-of-day panel reads `evening(state)`.
## Does not import Simulation: state records when each PR reached the desk, and
## Catalog rebuilds revisions from the recipe the state records.

const Catalog = preload("res://content/catalog.gd")
const CONTACTS: Array = ["Maya", "Theo", "June", "Penny", "Gwen", "company", "manager"]
const REPLY_IDS: Array = ["acknowledge", "clarify", "concern"]
const HISTORY_LIMIT: int = 24
const WEEK_DAYS: int = 5


static func _authored() -> Dictionary:
	return load("res://content/policy_chat.gd").authored()


static func _lines():
	return load("res://content/policy_chat.gd")


## Who joins the team when (content/policy_campaign.gd ROSTER).
static func _policy():
	return load("res://content/policy_campaign.gd")


## A coworker's thread starts on the morning they join; before then they don't work here.
static func _on_team(state: Dictionary, contact: String) -> bool:
	return contact in ["company", "manager"] or (_policy().joins(contact) > 0 and _policy().joins(contact) <= int(state.get("day", 1)))


## How each desk visit went (content/encounters.gd): reactions, grudges, Morgan's notes.
static func _encounters():
	return load("res://content/encounters.gd")


static func _append(history: Array, author: String, text: String, kind: String, pr_id: String = "", day: int = 1, seconds: float = 0.0, sequence: int = -100) -> void:
	if text.is_empty():
		return
	var message := {"author": author, "text": text, "kind": kind,
		"sent_day": day, "sent_seconds": seconds, "sent_order": sequence,
		"id": "%d|%s|%s|%s|%s" % [day, author, kind, pr_id, text.sha256_text()]}
	if not pr_id.is_empty():
		message["pr_id"] = pr_id
	history.append(message)


static func timestamp(message: Dictionary) -> String:
	var minutes := 540 + int(floor(float(message.sent_seconds) * 540.0 / float(Catalog.shift_seconds())))
	var days := ["Mon", "Tue", "Wed", "Thu", "Fri"]
	var day: int = maxi(1, int(message.sent_day))
	# The second week's Monday reads "Wk2 Mon", so two Mondays never look alike.
	var week := "" if day <= WEEK_DAYS else "Wk%d " % ((day - 1) / WEEK_DAYS + 1)
	return "%s%s %02d:%02d" % [week, days[(day - 1) % days.size()], int(minutes / 60), minutes % 60]


static func _chronological(history: Array) -> Array:
	# Arrival time first, then the saved command order for actions on the same tick.
	# Never use the current clock or catalog iteration order for sent messages.
	history.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		for field: String in ["sent_day", "sent_seconds", "sent_order"]:
			if a[field] != b[field]: return a[field] < b[field]
		return str(a.id) < str(b.id))
	var start := maxi(0, history.size() - HISTORY_LIMIT)
	if start > 0 and history[start].kind == "response": start += 1
	if not history.is_empty():
		# Keep today's unanswered PR links reachable even when the chat is busy.
		var recent: Array = []
		for message: Dictionary in history.slice(0, start):
			if message.kind == "request" and int(message.sent_day) == int(history[-1].sent_day): recent.append(message)
		recent.append_array(history.slice(start))
		return recent.duplicate(true)
	return history.slice(start).duplicate(true)


static func _event_order(state: Dictionary, kind: String, pr_id: String, reply_id: String = "", fallback: int = 0) -> int:
	var actions: Array = state.get("actions", [])
	for index in range(actions.size()):
		var event: Dictionary = actions[index]
		if event.get("type") == kind and event.get("pr_id") == pr_id and (reply_id.is_empty() or event.get("reply_id") == reply_id):
			return (index + 1) * 2
	# Older/synthetic saves without a journal still retain reply-array order.
	return (fallback + 1) * 2


static func _decision_for(state: Dictionary, pr_id: String) -> Dictionary:
	for decision: Dictionary in state.get("decisions", []):
		if decision.get("pr_id") == pr_id:
			return decision
	return {}


static func _arrival(state: Dictionary, pr_id: String) -> Dictionary:
	for entry: Dictionary in state.get("arrivals", []):
		if entry.get("pr_id") == pr_id:
			return entry
	return {}


## A coworker sends a PR when it reaches the player's desk, never before.
static func _arrived(state: Dictionary, request: Dictionary) -> bool:
	return not _arrival(state, str(request.id)).is_empty()


static func _option(contact: String, pr_id: String, reply_id: String) -> Dictionary:
	if contact in ["company", "manager"] or contact not in CONTACTS or reply_id not in REPLY_IDS:
		return {}
	var authored := _authored()
	var person: Dictionary = authored.get("contacts", {}).get(contact, {})
	var choice: Dictionary = person.get("replies", {}).get(reply_id, {})
	var packet: Dictionary = authored.get("requests", {}).get(pr_id, {})
	var text := str(choice.get("text", ""))
	var response := str(choice.get("response", ""))
	if reply_id == "clarify":
		text = str(packet.get("question", text))
		response = str(packet.get("hint", ""))
	elif reply_id == "concern":
		response = str(packet.get("concern", ""))
	if text.is_empty() or response.is_empty():
		return {}
	return {"id": reply_id, "text": text, "pr_id": pr_id, "response": response}


static func _used(state: Dictionary, contact: String, pr_id: String, reply_id: String) -> bool:
	for reply: Dictionary in state.get("chat_replies", []):
		if reply.get("contact") == contact and reply.get("pr_id") == pr_id and reply.get("reply_id") == reply_id:
			return true
	return false


static func reply_options(state: Dictionary, contact: String) -> Array:
	if contact in ["company", "manager"] or contact not in CONTACTS or state.get("phase") != "review" or not _on_team(state, contact):
		return []
	var options: Array = []
	for request: Dictionary in Catalog.requests():
		if request.author != contact or int(request.day) != int(state.get("day", 1)) or not _arrived(state, request):
			continue
		if not _decision_for(state, str(request.id)).is_empty():
			continue
		for reply_id: String in REPLY_IDS:
			if _used(state, contact, str(request.id), reply_id):
				continue
			var option := _option(contact, str(request.id), reply_id)
			if not option.is_empty():
				options.append(option)
	return options.duplicate(true)


static func _request_history(history: Array, state: Dictionary, contact: String, request: Dictionary) -> void:
	var pr_id := str(request.id)
	var packet: Dictionary = _authored().get("requests", {}).get(pr_id, {})
	var arrival := _arrival(state, pr_id)
	var arrived_at := float(arrival.get("shift_seconds", 0))
	# Revisions carry their own author note, phrased only from what the player cited.
	var text := str(packet.get("request", request.get("message", "")))
	_append(history, contact, text, "request", pr_id, int(arrival.get("day", request.day)), arrived_at, -1)
	var seen: Array = []
	var replies: Array = state.get("chat_replies", [])
	for index in range(replies.size()):
		var saved: Dictionary = replies[index]
		if saved.get("contact") != contact or saved.get("pr_id") != pr_id:
			continue
		var reply_id := str(saved.get("reply_id", ""))
		if reply_id in seen:
			continue
		var option := _option(contact, pr_id, reply_id)
		if option.is_empty():
			continue
		seen.append(reply_id)
		var day := int(saved.get("day", request.day))
		var seconds := float(saved.get("shift_seconds", arrived_at))
		var sequence := _event_order(state, "chat-reply", pr_id, reply_id, index)
		_append(history, "You", str(option.text), "reply", "", day, seconds, sequence)
		history[-1].id = contact + "|" + pr_id + "|" + reply_id + "|reply"
		_append(history, contact, str(option.response), "response", "", day, seconds, sequence + 1)
		history[-1].id = contact + "|" + pr_id + "|" + reply_id + "|response"
		history[-1]["reply_key"] = contact + "|" + pr_id + "|" + reply_id
	# A recorded encounter says how the visit ended: thanks, suspicion, relief, a
	# revision, a withdrawn citation, an abandoned PR and its grudge, or Morgan.
	# Some messages wait (a revise-now note until v2 lands, a grudge for a moment).
	if not _encounters().beats(state, pr_id).is_empty():
		for beat: Dictionary in _encounters().slouch(state, request):
			_append(history, contact, str(beat.text), str(beat.kind), "", int(beat.day), float(beat.seconds), int(beat.order))
			history[-1].id = contact + "|" + pr_id + "|" + ("reaction" if beat.kind == "reaction" else str(beat.node))
		return
	var decision := _decision_for(state, pr_id)
	if not decision.is_empty():
		# Reactions follow the chosen verdict and citations; audit correctness is never consulted.
		var reaction := str(packet.get("approve", "")) if decision.get("verdict") == "approve" else ""
		if decision.get("verdict") == "request_changes" or int(request.get("revision", 1)) > 1:
			reaction = _lines().reaction(contact, int(request.get("revision", 1)), str(decision.get("verdict", "")), decision.get("cited_rules", []), pr_id)
		_append(history, contact, reaction, "reaction", "", int(request.day), float(decision.get("shift_seconds", Catalog.shift_seconds())), _event_order(state, "review", pr_id, "", replies.size()))
		history[-1].id = contact + "|" + pr_id + "|reaction"


static func messages(state: Dictionary, contact: String) -> Array:
	if contact not in CONTACTS or not _on_team(state, contact):
		return []
	var authored := _authored()
	var history: Array = []
	if contact == "manager":
		return _manager_messages(state)
	if contact == "company":
		for notice: Dictionary in authored.get("company", []):
			if int(notice.day) <= int(state.get("day", 1)):
				_append(history, str(notice.author), str(notice.text), "notice", "", int(notice.day), 0)
		if int(state.get("autonomy", 0)) >= 65:
			_append(history, "Operations", "Helios has been added to the approval planning channel. The next staffing discussion is being prepared from its recommendations.", "ambient")
		elif int(state.get("autonomy", 0)) >= 35:
			_append(history, "Operations", "Helios is being copied on implementation handoffs now. Please keep a human owner named in the thread.", "ambient")
		var active_id := str(state.get("active_request_id", ""))
		if state.get("phase") == "review" and not active_id.is_empty() and active_id in state.get("consulted_requests", []):
			for event: Dictionary in state.get("actions", []):
				if event.get("type") == "consult-ai" and event.get("pr_id") == active_id:
					_append(history, "Helios", "I've attached my recommendation to the open review. You can refer to it while preparing your decision.", "notice", "", int(event.day), float(event.shift_seconds), _event_order(state, "consult-ai", active_id))
					history[-1].id = "consult|" + active_id
					break
		if state.get("phase") == "complete":
			_append(history, "Operations", "Your review assignment has closed. Keep the conversation history; ownership questions may come back after the rollout.", "notice", "", int(state.get("day", 1)), Catalog.shift_seconds(), 100)
	else:
		var person: Dictionary = authored.get("contacts", {}).get(contact, {})
		_append(history, contact, str(person.get("intro", "")), "intro")
		var tone: String = _encounters().standing(state, contact)
		if tone != "neutral":
			_append(history, contact, str(person.get(tone, "")), "ambient", "", 1, 0, -90)
		for arrival: Dictionary in state.get("arrivals", []):
			var request := Catalog.packet(state, str(arrival.get("pr_id", "")), false)
			if not request.is_empty() and request.author == contact:
				_request_history(history, state, contact, request)
	return _chronological(history)


static func _manager_messages(state: Dictionary) -> Array:
	var history: Array = []
	var copy: Dictionary = _authored().get("manager", {})
	_append(history, "Morgan / Engineering Manager", str(copy.get("intro", "")), "intro")
	# Escalations and abandoned PRs reach Morgan as soon as they happen.
	for note: Dictionary in _morgan_notes(state):
		_append(history, "Morgan", str(note.text), "notice", "", int(note.day), float(note.seconds), int(note.order))
	for shift: Dictionary in state.get("shift_history", []):
		var first := history.size()
		for line: Dictionary in _shift_report(state, shift):
			_append(history, "Morgan", str(line.text), "notice", str(line.get("pr_id", "")))
		for index in range(first, history.size()):
			history[index].sent_day = int(shift.day)
			history[index].sent_seconds = float(Catalog.shift_seconds())
			history[index].sent_order = index - first
			history[index].id = str(shift.day) + "|" + history[index].id
	if state.get("phase") == "complete":
		_append(history, "Morgan", _ending(state), "notice", "", int(state.get("day", 1)), Catalog.shift_seconds(), 100)
	return _chronological(history)


## Morgan's notes as they happen, escalations and abandoned PRs: [{text, day, seconds, order}].
static func _morgan_notes(state: Dictionary) -> Array:
	if not state.get("encounters", []).is_empty():
		return _encounters().morgan(state)
	# Records without encounters: a PR sent back three times escalates.
	var notes: Array = []
	for decision: Dictionary in state.get("decisions", []):
		if decision.get("verdict") != "request_changes": continue
		var escalated := Catalog.packet(state, str(decision.get("pr_id", "")), false)
		if int(escalated.get("revision", 1)) < _lines().MAX_REVISION: continue
		notes.append({"text": _lines().escalation(str(escalated.author), str(escalated.origin_id)), "day": int(escalated.day),
			"seconds": float(decision.get("shift_seconds", 0)), "order": _event_order(state, "review", str(escalated.id))})
	return notes


## What Morgan says about one closed shift, in order: [{text, closing, pr_id?}].
## `closing` is false for the day's notes (a shipped bug, friction, work handed to
## Helios, or a quiet night) and true for her sign-off.
static func _shift_report(state: Dictionary, shift: Dictionary) -> Array:
	var copy: Dictionary = _authored().get("manager", {})
	var report: Array = []
	# A newcomer's first day: Morgan says how it went, colored by how they felt
	# about you by the end of it (never by whether anyone was right).
	var newcomers: Dictionary = copy.get("newcomers", {})
	for author: String in newcomers:
		if _policy().joins(author) == int(shift.day):
			report.append({"text": str(newcomers[author].get(_standing_on(state, author, int(shift.day)), newcomers[author].neutral)), "closing": false})
	var had_incident := false
	var had_friction := false
	var held := false
	for request: Dictionary in Catalog.day_packets(state, int(shift.day)):
		var decision := _decision_for(state, str(request.id))
		if decision.is_empty(): continue
		if decision.verdict == "approve" and not bool(decision.get("correct", true)):
			var origin := str(request.get("origin_id", request.id))
			var incident: String = str(_authored().get("requests", {}).get(origin, {}).get("incident", ""))
			if not incident.is_empty() and not had_incident:
				# One concrete example, rather than an identical warning per bad approval.
				report.append({"text": Catalog.display_id(str(request.id)) + ": " + incident, "closing": false, "pr_id": str(request.id)})
				had_incident = true
		elif decision.verdict == "request_changes":
			held = true
			if not bool(decision.get("correct", true)): had_friction = true
	if had_friction: report.append({"text": str(copy.friction), "closing": false})
	if int(shift.get("handed_off", 0)) > 0:
		report.append({"text": str(copy.handoff), "closing": false})
	elif not had_incident and not had_friction:
		report.append({"text": str(copy.held if held else copy.quiet), "closing": false})
	report.append({"text": str(copy.get("closings", {}).get(int(shift.day), copy.closing)), "closing": true})
	# The first Friday was supposed to be the last day.
	if int(shift.day) == WEEK_DAYS and int(shift.day) < int(Catalog.campaign_days()[-1]):
		report.append({"text": str(copy.get("extension", "")), "closing": true})
	return report


## How an author felt about you by the end of `day` ("warm", "neutral", "distant"):
## the mood of their latest beat that day or earlier, so a past evening never changes.
static func _standing_on(state: Dictionary, author: String, day: int) -> String:
	var encounters: Array = state.get("encounters", [])
	for index in range(encounters.size() - 1, -1, -1):
		var beat: Dictionary = encounters[index]
		if beat.get("author") == author and int(beat.get("day", 0)) <= day:
			return str({"warm": "warm", "strained": "distant", "hostile": "distant"}.get(str(beat.get("mood", "")), "neutral"))
	return "neutral"


const Staff = preload("res://content/staff.gd")
const Endings = preload("res://content/endings.gd")

## Morgan's last word on the assignment, from the ending the run earned.
static func _ending(state: Dictionary) -> String:
	var key := str(state.get("ending", ""))
	if key.is_empty(): key = "helios_prime"
	return Endings.morgan(key)

## What Morgan says about the staffing on a closed day: a warning when a coworker
## is one strike from the axe, and the firing itself. Prose only, never a score.
static func _staffing_notes(state: Dictionary, day: int) -> Array:
	var notes: Array = []
	var struck_today: Dictionary = {}
	for strike: Dictionary in state.get("strikes", []):
		if int(strike.get("day", 0)) == day: struck_today[str(strike.name)] = true
	for firing: Dictionary in state.get("firings", []):
		if int(firing.get("day", 0)) != day: continue
		# Nobody replaces them; Helios takes the seat, and their PRs stop coming.
		var name := str(firing.name)
		var reason := str(firing.reason)
		if not reason.is_empty(): reason = reason.left(1).to_upper() + reason.substr(1) + "."
		notes.append("I had to let %s go. %s Helios has %s's desk now. Nobody's backfilling it." % [name, reason, name])
	# Warn about anyone one strike short who is still here.
	for person: String in Staff.team(state, day):
		if Staff.is_fired(state, person) or not struck_today.get(person, false): continue
		if Staff.strikes(state, person) == Staff.WARN_AT:
			notes.append("%s picked up another mark today. One more and it's out of my hands." % person)
	return notes

## What Morgan says about the day's Helios payloads: something unreadable shipped,
## or that you held the line. Audit-free; it reads the payload ledger, not grades.
static func _payload_notes(state: Dictionary, day: int) -> Array:
	var shipped: Array = []
	var held := false
	for payload: Dictionary in state.get("payloads", []):
		if int(payload.get("day", 0)) != day: continue
		if str(payload.get("outcome", "")) == "blocked": held = true
		else: shipped.append(payload)
	var notes: Array = []
	if not shipped.is_empty():
		notes.append("Something shipped today that none of us can read. Legal is going to ask who signed it, and I won't have a good answer.")
	elif held:
		notes.append("You turned back a change nobody could review. Whatever it was, it isn't in main. Thank you for that.")
	return notes

## Morgan noticing a reason-free rejection you stamped that day.
static func _unexplained_notes(state: Dictionary, day: int) -> Array:
	for beat: Dictionary in state.get("encounters", []):
		if int(beat.get("day", 0)) == day and str(beat.get("node", "")) == "unexplained":
			return ["Someone came by asking why their PR was rejected with no notes on it. I didn't have an answer. Try to leave a reason."]
	return []


## Morgan's end-of-day panel for the shift that just closed: {day, notes, closing}.
## `notes` are what she heard that day (escalations, abandoned PRs, a shipped bug,
## work handed to Helios); `closing` is her sign-off, plus the ending once the
## assignment is over. Empty while a shift is open. Never a score or a grade.
static func evening(state: Dictionary) -> Dictionary:
	var shifts: Array = state.get("shift_history", [])
	if state.get("phase") not in ["debrief", "complete"] or shifts.is_empty():
		return {}
	var shift: Dictionary = shifts[-1]
	var day := int(shift.day)
	var notes: Array = []
	var closing: Array = []
	for note: Dictionary in _morgan_notes(state):
		if int(note.day) == day and not str(note.text).is_empty(): notes.append(str(note.text))
	notes.append_array(_payload_notes(state, day))
	notes.append_array(_unexplained_notes(state, day))
	notes.append_array(_staffing_notes(state, day))
	for line: Dictionary in _shift_report(state, shift):
		if str(line.text).is_empty(): continue
		if bool(line.closing): closing.append(str(line.text))
		else: notes.append(str(line.text))
	if state.get("phase") == "complete": closing.append(_ending(state))
	return {"day": day, "notes": notes, "closing": closing}
