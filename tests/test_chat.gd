extends SceneTree

const Chat = preload("res://content/chat.gd")
const Catalog = preload("res://content/catalog.gd")
const Simulation = preload("res://native/simulation.gd")
var checks: int = 0
var failures: int = 0
var authored: Dictionary = {}

func _initialize() -> void:
	authored = JSON.parse_string(FileAccess.get_file_as_string("res://content/messages.json"))
	_test_visibility()
	_test_reactions()
	_test_purity()
	_test_campaign()
	print("Team chat checks: %d passed, %d failed." % [checks - failures, failures])
	quit(1 if failures else 0)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _texts(messages: Array) -> Array:
	var result: Array = []
	for message: Dictionary in messages:
		result.append(message.text)
	return result

func _kind(messages: Array, kind: String) -> Array:
	var result: Array = []
	for message: Dictionary in messages:
		if message.kind == kind:
			result.append(message)
	return result

func _test_visibility() -> void:
	var state: Dictionary = Simulation.initial_state()
	var active: Dictionary = Catalog.request_at(0)
	var contact_messages: Array = Chat.messages(state, active.author)
	_check(authored.requests[active.id].hint in _texts(contact_messages), "Current author should send a useful trace hint.")
	_check(_kind(contact_messages, "reaction").is_empty(), "No reaction may arrive before a decision.")
	for contact: String in Chat.CONTACTS:
		var texts: Array = _texts(Chat.messages(state, contact))
		for request: Dictionary in Catalog.requests().slice(1):
			_check(authored.requests[request.id].request not in texts and authored.requests[request.id].hint not in texts, "Future PR messages must stay hidden.")
	var notices: Array = _texts(Chat.messages(state, "company"))
	for notice: Dictionary in authored.company:
		_check((notice.text in notices) == (int(notice.day) <= int(state.day)), "Company notices must follow their authored release day.")
	var original: Array = Catalog.requests()
	var poisoned: Array = original.duplicate(true)
	poisoned[0].violations = ["AUDIT_ANSWER_SECRET"]
	poisoned[0].explanation = "AUDIT_ANSWER_SECRET"
	poisoned[0].ai_note = "AUDIT_ANSWER_SECRET"
	Catalog._requests = poisoned
	_check(Chat.messages(state, active.author) == contact_messages, "Active messages must not depend on hidden audit answers or AI verdict text.")
	Catalog._requests = original
	_check(Chat.messages(state, "unknown").is_empty(), "Unknown contacts should have no conversation.")

func _test_reactions() -> void:
	var state: Dictionary = Simulation.initial_state()
	var request: Dictionary = Catalog.request_at(0)
	var approved: Dictionary = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	var reactions: Array = _kind(Chat.messages(approved, request.author), "reaction")
	_check(not approved.last_feedback.correct and reactions.size() == 1 and reactions[0].text == authored.requests[request.id].approve, "An incorrect approval must still produce the author's approval reaction.")
	var same_verdict: Dictionary = approved.duplicate(true)
	same_verdict.decisions[0].correct = true
	_check(_kind(Chat.messages(same_verdict, request.author), "reaction") == reactions, "Feelings must follow the player's verdict, independently of the audit flag.")
	var rejected: Dictionary = state
	for rule_id: String in request.violations:
		rejected = Simulation.dispatch(rejected, {"type": "toggle-rule", "rule_id": rule_id})
	rejected = Simulation.dispatch(rejected, {"type": "review", "verdict": "request_changes"})
	_check(rejected.last_feedback.correct and _kind(Chat.messages(rejected, request.author), "reaction")[0].text == authored.requests[request.id].request_changes, "A correct rejection can still disappoint its author.")
	var prior: Array = _texts(Chat.messages(state, request.author))
	var later: Array = _texts(Chat.messages(approved, request.author))
	_check(authored.requests[request.id].request in prior and authored.requests[request.id].request in later and authored.requests[request.id].hint in later, "Earlier pressure and hints must remain in the conversation history.")
	for contact: String in ["Maya", "Theo", "Inez"]:
		var warm: Dictionary = state.duplicate(true)
		var distant: Dictionary = state.duplicate(true)
		warm.coworkers[contact] = 80
		distant.coworkers[contact] = 20
		_check(_kind(Chat.messages(warm, contact), "ambient")[0].text == authored.contacts[contact].warm, "Warm relationships should sound different without exposing their score.")
		_check(_kind(Chat.messages(distant, contact), "ambient")[0].text == authored.contacts[contact].distant, "Strained relationships should use their authored distant tone.")

func _test_purity() -> void:
	var state: Dictionary = Simulation.initial_state()
	var snapshot: Dictionary = state.duplicate(true)
	var original_content: Dictionary = authored.duplicate(true)
	var first: Array = Chat.messages(state, "Maya")
	_check(first == Chat.messages(state, "Maya"), "Identical states must produce deterministic messages.")
	first[0].text = "changed outside chat"
	_check(Chat.messages(state, "Maya")[0].text != first[0].text, "Returned messages must not alias cached content.")
	_check(state == snapshot and authored == original_content, "Reading chat must not mutate simulation or authored content.")
	var repeated: Dictionary = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
	for _index in range(100):
		repeated.decisions.append(repeated.decisions[0].duplicate(true))
	_check(Chat.messages(repeated, "Maya").size() == Chat.HISTORY_LIMIT, "Conversation history must remain bounded.")

func _test_campaign() -> void:
	var state: Dictionary = Simulation.initial_state()
	var digits: RegEx = RegEx.new()
	digits.compile("[0-9]|[+][0-9]|%")
	var rules: RegEx = RegEx.new()
	rules.compile("\\b[SDRTOA][0-9]{2}\\b")
	while true:
		for contact: String in Chat.CONTACTS:
			var history: Array = Chat.messages(state, contact)
			_check(history.size() <= Chat.HISTORY_LIMIT, "Every reachable conversation must respect the history limit.")
			for message: Dictionary in history:
				_check(message.keys().size() == 3 and message.has("author") and message.has("text") and message.has("kind"), "Messages must retain the UI's exact author/text/kind contract.")
				_check(digits.search(message.text) == null and rules.search(message.text) == null, "Chat must not expose numeric stats, deltas, queue caps, or exact rule answers.")
		if state.phase == "complete":
			_check(_kind(Chat.messages(state, "company"), "notice")[-1].text.contains("assignment has closed"), "Completion should get a qualitative company notice.")
			break
		if state.phase == "debrief":
			var upcoming: Dictionary = Catalog.request_at(int(state.request_index))
			if not upcoming.is_empty():
				_check(authored.requests[upcoming.id].hint not in _texts(Chat.messages(state, upcoming.author)), "Debrief must not leak the next shift's first hint.")
			state = Simulation.dispatch(state, {"type": "next-day", "choice": "rest"})
		else:
			var request: Dictionary = Catalog.request_at(int(state.request_index))
			state = Simulation.dispatch(state, {"type": "review", "verdict": "approve"})
			_check(_kind(Chat.messages(state, request.author), "reaction")[-1].text == authored.requests[request.id].approve, "Every reaction must correspond to the decision actually submitted.")
