extends SceneTree
## Conversation view tests use the timed-state contract without importing Simulation.

const Chat = preload("res://content/chat.gd")
const Catalog = preload("res://content/catalog.gd")
var checks := 0
var failures := 0
var authored: Dictionary = {}


func _initialize() -> void:
	authored = JSON.parse_string(FileAccess.get_file_as_string("res://content/messages.json"))
	_test_delivery()
	_test_replies()
	_test_reactions()
	_test_expired_history()
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
		"decisions": [], "coworkers": {"Maya": 50, "Theo": 50, "Inez": 50}}


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
	for contact: String in Chat.CONTACTS:
		_check(_kind(Chat.messages(waiting, contact), "request").is_empty(), "Shift opening must not announce any undelivered PR.")
		_check(Chat.reply_options(waiting, contact).is_empty(), "An undelivered PR cannot offer replies.")
	for request: Dictionary in Catalog.requests():
		var arrival := Catalog.arrival_seconds(str(request.id))
		var state := _state(int(request.day), arrival - 1)
		_check(authored.requests[request.id].request not in _texts(Chat.messages(state, str(request.author))), "PR prose must stay hidden until its arrival boundary.")
		_check(_options_for(state, request).is_empty(), "PR choices must stay hidden until arrival.")
		state.shift_seconds = arrival
		var history := Chat.messages(state, str(request.author))
		var linked := false
		for message: Dictionary in history:
			if message.get("pr_id") == request.id:
				linked = message.kind == "request" and message.text == authored.requests[request.id].request
		_check(linked, "An arriving coworker request must carry its real internal PR link.")
		_check(authored.requests[request.id].hint not in _texts(history), "Arrival must not automatically reveal its trace hint.")
		_check(_options_for(state, request).size() == 3, "Every arrived pending PR offers three authored choices.")
		for future: Dictionary in Catalog.requests():
			if int(future.day) > int(state.day) or (int(future.day) == int(state.day) and Catalog.arrival_seconds(str(future.id)) > arrival):
				var future_history := Chat.messages(state, str(future.author))
				_check(authored.requests[future.id].request not in _texts(future_history), "Future requests cannot leak through another contact's history.")
				for message: Dictionary in future_history:
					_check(message.get("pr_id") != future.id, "Future PR IDs must not appear as clickable metadata.")
	_check(Chat.messages(waiting, "unknown").is_empty(), "Unknown contacts have no conversation.")
	_check(Chat.reply_options(waiting, "unknown").is_empty() and Chat.reply_options(waiting, "company").is_empty(), "Unknown and announcement-only channels have no replies.")


func _test_replies() -> void:
	var request: Dictionary = Catalog.request_at(0)
	var state := _state(int(request.day), Catalog.arrival_seconds(str(request.id)))
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
	var state := _state(int(request.day), Catalog.arrival_seconds(str(request.id)))
	_save_choice(state, request, "clarify")
	state.decisions.append({"pr_id": request.id, "verdict": "approve", "correct": false})
	var reactions := _kind(Chat.messages(state, str(request.author)), "reaction")
	_check(reactions.size() == 1 and reactions[0].text == authored.requests[request.id].approve, "Coworker approval reactions must follow the player's verdict, even when technically wrong.")
	state.decisions[0].correct = true
	_check(_kind(Chat.messages(state, str(request.author)), "reaction") == reactions, "Private audit correctness must not alter coworker reaction prose.")
	_check(_options_for(state, request).is_empty(), "A submitted PR no longer accepts pre-review reply choices.")
	state.decisions[0].verdict = "request_changes"
	_check(_kind(Chat.messages(state, str(request.author)), "reaction")[0].text == authored.requests[request.id].request_changes, "Sending changes back uses the authored rejection reaction.")
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
	var state := _state(int(request.day), Catalog.arrival_seconds(str(request.id)))
	var clarification := _save_choice(state, request, "clarify")
	state.day += 1
	state.shift_seconds = 0
	var history := Chat.messages(state, str(request.author))
	_check(authored.requests[request.id].request in _texts(history), "A handed-off PR's coworker message must survive the next shift without a decision.")
	_check(clarification.text in _texts(history) and clarification.response in _texts(history), "Player questions and answers must survive expiration of unresolved work.")
	_check(_kind(history, "reaction").is_empty(), "Expiration must not invent an approval or rejection reaction.")
	_check(_options_for(state, request).is_empty(), "Historical handed-off work remains readable without offering new pre-review replies.")


func _test_purity() -> void:
	var request: Dictionary = Catalog.request_at(0)
	var state := _state(int(request.day), Catalog.arrival_seconds(str(request.id)))
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
	var state := _state(int(Catalog.campaign_days()[-1]), 360)
	var known: Dictionary = {}
	for request: Dictionary in Catalog.requests():
		known[request.id] = request
		for reply_id: String in Chat.REPLY_IDS:
			state.chat_replies.append({"day": request.day, "shift_seconds": 300, "contact": request.author, "pr_id": request.id, "reply_id": reply_id})
		state.decisions.append({"pr_id": request.id, "verdict": "approve", "correct": true})
	var forbidden := RegEx.new()
	forbidden.compile("[0-9]|%|https?://")
	for contact: String in Chat.CONTACTS:
		var history := Chat.messages(state, contact)
		_check(history.size() <= Chat.HISTORY_LIMIT, "Large conversation histories must remain bounded.")
		_check(history.is_empty() or history[0].kind != "response", "Truncation must not orphan a coworker response from the player's reply.")
		for message: Dictionary in history:
			_check(message.has_all(["author", "text", "kind"]) and message.size() in [3, 4], "Messages retain author/text/kind and optional internal request or response metadata.")
			_check(forbidden.search(message.text) == null, "Chat prose must not reveal scores, queue totals, audit rule IDs, or external URLs.")
			if message.has("pr_id"):
				_check(known.has(message.pr_id) and known[message.pr_id].author == contact, "Every link must identify an authored request from this coworker.")
	state.phase = "complete"
	_check(_kind(Chat.messages(state, "company"), "notice")[-1].text.contains("assignment has closed"), "Completion keeps a qualitative company notice.")
