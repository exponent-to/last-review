extends SceneTree
## Conversation view tests use the timed-state contract without importing Simulation.

const Chat = preload("res://content/chat.gd")
const Catalog = preload("res://content/catalog.gd")
var checks := 0
var failures := 0
var authored: Dictionary = {}


func _initialize() -> void:
	authored = Chat._authored()
	_test_delivery()
	_test_replies()
	_test_reactions()
	_test_expired_history()
	_test_chronology()
	_test_purity()
	_test_history_and_contract()
	print("Team chat checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func _state(day: int, seconds: int) -> Dictionary:
	return {"day": day, "shift_seconds": seconds, "phase": "review", "autonomy": 10,
		"active_request_id": "", "consulted_requests": [], "chat_replies": [],
		"arrivals": [], "revisions": [], "desk_line": [],
		"decisions": [], "coworkers": {"Maya": 50, "Theo": 50, "Inez": 50}}


## A PR reaching the player's desk is what makes its author send it.
func _arrive(state: Dictionary, request: Dictionary, seconds: int) -> void:
	state.arrivals.append({"pr_id": request.id, "day": int(request.day), "shift_seconds": seconds})
	state.active_request_id = request.id


func _texts(history: Array) -> Array:
	var texts: Array = []
	for message: Dictionary in history:
		texts.append(message.text)
	return texts


func _kind(history: Array, kind: String) -> Array:
	var result: Array = []
	for message: Dictionary in history:
		if message.kind == kind:
			result.append(message)
	return result


func _options_for(state: Dictionary, request: Dictionary) -> Array:
	var result: Array = []
	for option: Dictionary in Chat.reply_options(state, str(request.author)):
		if option.pr_id == request.id:
			result.append(option)
	return result


func _save_choice(state: Dictionary, request: Dictionary, reply_id: String) -> Dictionary:
	for option: Dictionary in _options_for(state, request):
		if option.id == reply_id:
			state.chat_replies.append({"day": state.day, "shift_seconds": state.shift_seconds,
				"pr_id": request.id, "contact": request.author, "reply_id": reply_id})
			return option
	_check(false, "Test reply must be a currently offered authored choice.")
	return {}


func _test_delivery() -> void:
	var first: Dictionary = Catalog.request_at(0)
	var waiting := _state(int(first.day), 0)
	for coworker: String in ["Maya", "Theo", "Inez"]:
		var greetings := Chat.messages(waiting, coworker)
		_check(greetings.size() == 1 and greetings[0].kind == "intro", "Each coworker starts with one introduction, without a second filler message.")
	for contact: String in Chat.CONTACTS:
		_check(_kind(Chat.messages(waiting, contact), "request").is_empty(), "Shift opening must not announce any PR that has not reached the desk.")
		_check(Chat.reply_options(waiting, contact).is_empty(), "An undelivered PR cannot offer replies.")
	for day: int in Catalog.campaign_days():
		var state := _state(day, 0)
		# Helios payloads are not part of the archived Slouch chat (they carry their
		# own pleading at the desk), so this chat test only walks the authored 150.
		var not_payload := func(p: Dictionary) -> bool: return not p.get("payload", false)
		var packets := Catalog.requests_for_day(day).filter(not_payload)
		for index in range(packets.size()):
			var request: Dictionary = packets[index]
			state.shift_seconds = index * 20
			_check(authored.requests[request.id].request not in _texts(Chat.messages(state, str(request.author))), "PR prose must stay hidden until the PR reaches the desk.")
			_check(_options_for(state, request).is_empty(), "PR choices must stay hidden until arrival.")
			_arrive(state, request, index * 20)
			var history := Chat.messages(state, str(request.author))
			var linked := false
			for message: Dictionary in history:
				if message.get("pr_id") == request.id:
					linked = message.kind == "request" and message.text == authored.requests[request.id].request and int(message.sent_seconds) == index * 20
			_check(linked, "A PR reaching the desk must carry its real internal PR link, sent when it arrived.")
			_check(authored.requests[request.id].hint not in _texts(history), "Arrival must not automatically reveal its trace hint.")
			_check(_options_for(state, request).size() == 3, "The pending PR on the desk offers three authored choices.")
			for future: Dictionary in packets.slice(index + 1) + Catalog.requests_for_day(day + 1).filter(not_payload):
				var future_history := Chat.messages(state, str(future.author))
				_check(authored.requests[future.id].request not in _texts(future_history), "PRs still in line cannot leak through any contact's history.")
				for message: Dictionary in future_history:
					_check(message.get("pr_id") != future.id, "PRs still in line must not appear as clickable metadata.")
			state.decisions.append({"pr_id": request.id, "verdict": "approve", "correct": true, "shift_seconds": index * 20 + 1})
	_check(Chat.messages(waiting, "unknown").is_empty(), "Unknown contacts have no conversation.")
	_check(Chat.reply_options(waiting, "unknown").is_empty() and Chat.reply_options(waiting, "company").is_empty(), "Unknown and announcement-only channels have no replies.")


func _test_replies() -> void:
	var request: Dictionary = Catalog.request_at(0)
	var state := _state(int(request.day), 0)
	_arrive(state, request, 0)
	var before := Chat.reply_options(state, str(request.author))
	state.shift_seconds += 1
	_check(Chat.reply_options(state, str(request.author)) == before, "Clock ticks between arrivals must not change reply identities or prose.")
	var acknowledgement := _save_choice(state, request, "acknowledge")
	_check(_options_for(state, request).size() == 2, "Each choice may be used only once per PR/contact.")
	_check(authored.requests[request.id].hint not in _texts(Chat.messages(state, str(request.author))), "Acknowledging a PR must not reveal the clarification hint.")
	var clarification := _save_choice(state, request, "clarify")
	_check(clarification.text == authored.requests[request.id].question, "Clarification must ask an authored technical question about this specific PR.")
	var history := Chat.messages(state, str(request.author))
	var found_pair := false
	for index in range(history.size() - 1):
		if history[index].author == "You" and history[index].text == clarification.text:
			found_pair = history[index + 1].author == request.author and history[index + 1].text == clarification.response
	_check(found_pair and clarification.response == authored.requests[request.id].hint, "The chosen clarification must be followed by the coworker's authored trace hint.")
	_check(acknowledgement.text in _texts(history) and acknowledgement.response in _texts(history), "Actual earlier player choices and responses must remain in the history.")
	var concern := _save_choice(state, request, "concern")
	_check(concern.response == authored.requests[request.id].concern, "Concern must receive PR-specific human context.")
	_check(_options_for(state, request).is_empty(), "A PR has no reply options left after all authored choices are used.")
	var chosen_history := Chat.messages(state, str(request.author))
	state.chat_replies.append(state.chat_replies[-1].duplicate(true))
	_check(Chat.messages(state, str(request.author)) == chosen_history, "Duplicate stored IDs must not duplicate a conversation response.")
	state.chat_replies.append({"pr_id": "PR-FORGED", "contact": request.author, "reply_id": "clarify"})
	_check(Chat.messages(state, str(request.author)) == chosen_history, "Unknown stored PR IDs must never create invented links or messages.")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(state))
	_check(Chat.messages(decoded, str(request.author)) == chosen_history, "Saved reply choices must reproduce the actual player/coworker conversation after JSON reload.")
	state.phase = "debrief"
	_check(Chat.reply_options(state, str(request.author)).is_empty(), "After shift closure, history remains readable but cannot accept new replies.")


func _test_reactions() -> void:
	var request: Dictionary = Catalog.request_at(0)
	var state := _state(int(request.day), 0)
	_arrive(state, request, 0)
	_save_choice(state, request, "clarify")
	state.decisions.append({"pr_id": request.id, "verdict": "approve", "correct": false})
	var reactions := _kind(Chat.messages(state, str(request.author)), "reaction")
	_check(reactions.size() == 1 and reactions[0].text == authored.requests[request.id].approve, "Coworker approval reactions must follow the player's verdict, even when technically wrong.")
	state.decisions[0].correct = true
	_check(_kind(Chat.messages(state, str(request.author)), "reaction") == reactions, "Private audit correctness must not alter coworker reaction prose.")
	_check(_options_for(state, request).is_empty(), "A submitted PR no longer accepts pre-review reply choices.")
	state.decisions[0].verdict = "request_changes"
	state.decisions[0].cited_rules = ["P01"]
	var sent_back: String = _kind(Chat.messages(state, str(request.author)), "reaction")[0].text
	_check(sent_back == Chat._lines().reaction(str(request.author), 1, "request_changes", ["P01"], str(request.id)), "Sending changes back uses the authored send-back reaction.")
	_check(sent_back.to_lower().contains("load-bearing comment") and not sent_back.contains("P01"), "The send-back names what was cited in plain words, never the rule ID.")
	state.decisions[0].correct = false
	_check(_kind(Chat.messages(state, str(request.author)), "reaction")[0].text == sent_back, "A send-back reads the same whether or not the citation was right.")
	state.day += 1
	state.shift_seconds = 0
	_check(authored.requests[request.id].hint in _texts(Chat.messages(state, str(request.author))), "Previously requested clarification survives into later shifts for submitted work.")
	for contact: String in ["Maya", "Theo", "Inez"]:
		state.coworkers[contact] = 80
		_check(_kind(Chat.messages(state, contact), "ambient")[0].text == authored.contacts[contact].warm, "Warm relationships use qualitative human language.")
		state.coworkers[contact] = 20
		_check(_kind(Chat.messages(state, contact), "ambient")[0].text == authored.contacts[contact].distant, "Strained relationships use qualitative human language.")


func _test_expired_history() -> void:
	var request: Dictionary = Catalog.request_at(0)
	var state := _state(int(request.day), 0)
	_arrive(state, request, 0)
	var clarification := _save_choice(state, request, "clarify")
	state.day += 1
	state.shift_seconds = -1
	var history := Chat.messages(state, str(request.author))
	_check(authored.requests[request.id].request in _texts(history), "A handed-off PR's coworker message must survive the next shift without a decision.")
	_check(clarification.text in _texts(history) and clarification.response in _texts(history), "Player questions and answers must survive expiration of unresolved work.")
	_check(history[-1].sent_day >= history[0].sent_day, "Messages stay in chronological order.")
	_check(_kind(history, "reaction").is_empty(), "Expiration must not invent an approval or rejection reaction.")
	_check(_options_for(state, request).is_empty(), "Historical handed-off work remains readable without offering new pre-review replies.")


func _test_purity() -> void:
	var request: Dictionary = Catalog.request_at(0)
	var state := _state(int(request.day), 0)
	_arrive(state, request, 0)
	var snapshot := state.duplicate(true)
	var history := Chat.messages(state, str(request.author))
	var options := Chat.reply_options(state, str(request.author))
	_check(history == Chat.messages(state, str(request.author)) and options == Chat.reply_options(state, str(request.author)), "Chat reads must be deterministic.")
	history[0].text = "external edit"
	options[0].response = "external edit"
	_check(Chat.messages(state, str(request.author))[0].text != "external edit" and Chat.reply_options(state, str(request.author))[0].response != "external edit", "Returned choices and messages must not alias authored content.")
	_check(state == snapshot, "Reading Slouch must never mutate the simulation.")
	var original := Catalog.requests()
	var poisoned := original.duplicate(true)
	for packet: Dictionary in poisoned:
		packet.violations = ["AUDIT_SECRET"]
		packet.explanation = "AUDIT_SECRET"
		packet.ai_note = "AUDIT_SECRET"
	var baseline_messages := Chat.messages(state, str(request.author))
	var baseline_options := Chat.reply_options(state, str(request.author))
	Catalog._requests = poisoned
	_check(Chat.messages(state, str(request.author)) == baseline_messages and Chat.reply_options(state, str(request.author)) == baseline_options, "Conversation and clarification choices must not inspect hidden audit answers.")
	Catalog._requests = original


func _test_history_and_contract() -> void:
	var state := _state(int(Catalog.campaign_days()[-1]), Catalog.shift_seconds())
	var known: Dictionary = {}
	for request: Dictionary in Catalog.requests():
		known[request.id] = request
		_arrive(state, request, 0)
		for reply_id: String in Chat.REPLY_IDS:
			state.chat_replies.append({"day": request.day, "shift_seconds": Catalog.shift_seconds(), "contact": request.author, "pr_id": request.id, "reply_id": reply_id})
		var verdict := "approve" if request.violations.is_empty() or int(request.day) == 5 else "request_changes"
		state.decisions.append({"pr_id": request.id, "verdict": verdict, "correct": true, "cited_rules": request.violations, "shift_seconds": 100})
		if verdict == "approve": continue
		# Earlier days also carry the full revision exchange, up to an escalation.
		var parent: Dictionary = request
		for version in [2, 3]:
			var entry := {"id": "%s-v%d" % [request.id, version], "parent_id": parent.id, "origin_id": request.id, "version": version, "day": request.day, "cited": request.violations, "fixed": [], "regression": ""}
			state.revisions.append(entry)
			var revision: Dictionary = Catalog.packet(state, entry.id)
			known[revision.id] = revision
			state.arrivals.append({"pr_id": revision.id, "day": request.day, "shift_seconds": 100 + version})
			state.decisions.append({"pr_id": revision.id, "verdict": "request_changes" if version == 3 or request.id.ends_with("1") else "approve", "correct": true, "cited_rules": request.violations, "shift_seconds": 101 + version})
			if state.decisions[-1].verdict == "approve": break
			parent = revision
	var forbidden := RegEx.new()
	forbidden.compile("Trust [+]|stress [+]|%|https?://|\\bP0[1-9]\\b|violat|audit")
	for contact: String in Chat.CONTACTS:
		var history := Chat.messages(state, contact)
		_check(history.size() <= Chat.HISTORY_LIMIT + 15, "Large conversation histories must remain bounded.")
		_check(history.is_empty() or history[0].kind != "response", "Truncation must not orphan a coworker response from the player's reply.")
		for message: Dictionary in history:
			_check(message.has_all(["author", "text", "kind", "id", "sent_day", "sent_seconds", "sent_order"]) and message.size() in [7, 8], "Messages retain author/text/kind and optional internal request or response metadata.")
			_check(forbidden.search(message.text) == null, "Chat prose must not reveal scores, queue totals, audit rule IDs, or external URLs: " + message.text)
			if message.has("pr_id"):
				_check(known.has(message.pr_id) and known[message.pr_id].author == contact, "Every link must identify an authored request from this coworker.")
	# Every authored line the player can see in Slouch is real copy, not a placeholder.
	var shown: Array = []
	for contact: String in Chat.CONTACTS:
		for message: Dictionary in Chat.messages(state, contact): shown.append(str(message.text))
	for person: Dictionary in authored.contacts.values():
		for key: String in ["intro", "warm", "distant"]: shown.append(str(person[key]))
		for reply: Dictionary in person.replies.values(): shown.append_array([str(reply.text), str(reply.response)])
	for packet: Dictionary in authored.requests.values():
		for key: String in ["request", "question", "hint", "concern", "approve", "incident"]: shown.append(str(packet[key]))
	for text: String in shown:
		_check(not text.contains("[") and not text.contains("placeholder"), "Slouch text must not contain placeholder brackets: " + text)
	var manager := JSON.stringify(Chat.messages(state, "manager"))
	_check(manager.contains("after three rounds") and manager.contains("v4"), "Morgan hears about every PR that escalates after its third version.")
	state.phase = "complete"
	_check(_kind(Chat.messages(state, "company"), "notice")[-1].text.contains("assignment has closed"), "Completion keeps a qualitative company notice.")


func _test_chronology() -> void:
	# A reviewer can ask about a later PR and then return to an older one.
	var original := Catalog.requests()
	var packets := original.slice(0, 2).duplicate(true)
	packets[1].author = packets[0].author
	Catalog._requests = packets
	var first: Dictionary = packets[0]
	var second: Dictionary = packets[1]
	var state := _state(1, 100)
	_arrive(state, first, 0)
	_arrive(state, second, 20)
	_save_choice(state, second, "clarify")
	state.shift_seconds = 110
	_save_choice(state, first, "clarify")
	var history := Chat.messages(state, str(first.author))
	var answers := _kind(history, "response")
	_check(answers.size() == 2 and answers[0].reply_key.contains(str(second.id)) and answers[1].reply_key.contains(str(first.id)), "Replies to older PRs stay after replies already sent about newer PRs.")
	_check(_kind(history, "request").size() == 2 and history[1].kind == "request" and history[2].kind == "request", "Delivered PR messages keep their arrival positions instead of grouping with later replies.")
	state.shift_seconds = 120
	_check(Chat.messages(state, str(first.author)) == history, "Advancing the clock cannot change sent timestamps, IDs, or message order.")
	state.chat_replies[1].shift_seconds = 100
	history = Chat.messages(state, str(first.author))
	answers = _kind(history, "response")
	_check(answers[0].reply_key.contains(str(second.id)) and answers[1].reply_key.contains(str(first.id)), "Same-tick replies retain saved send order across PRs, including the untimed tutorial.")
	state.actions = [
		{"type": "chat-reply", "pr_id": second.id, "reply_id": "clarify"},
		{"type": "review", "pr_id": second.id},
		{"type": "chat-reply", "pr_id": first.id, "reply_id": "clarify"}]
	state.decisions = [{"pr_id": second.id, "verdict": "approve", "shift_seconds": 100}]
	history = Chat.messages(state, str(first.author))
	_check(history[5].kind == "reaction" and history[6].kind == "reply", "The action journal orders a review reaction between two questions sent on the same tick.")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state))
	_check(Chat.messages(saved, str(first.author)) == history, "Chronological history survives save/load without new or reordered messages.")
	_check(Chat.timestamp(history[-1]) == "Mon 14:00", "Bubble timestamps use the same accelerated office clock as the desktop.")
	Catalog._requests = original
