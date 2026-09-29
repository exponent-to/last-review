extends RefCounted
## Authored conversation derived from arrived PRs and saved, explicit reply choices.
## Does not import Simulation: Catalog owns the shared arrival schedule.

const Catalog = preload("res://content/catalog.gd")
const CONTACTS: Array = ["Maya", "Theo", "Inez", "company"]
const REPLY_IDS: Array = ["acknowledge", "clarify", "concern"]
const HISTORY_LIMIT: int = 24
static var _content: Dictionary = {}


static func _authored() -> Dictionary:
	if _content.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/messages.json"))
		if parsed is Dictionary:
			_content = parsed
		else:
			push_error("Invalid authored team chat content.")
	return _content


static func _append(history: Array, author: String, text: String, kind: String, pr_id: String = "") -> void:
	if text.is_empty():
		return
	var message := {"author": author, "text": text, "kind": kind}
	if not pr_id.is_empty():
		message["pr_id"] = pr_id
	history.append(message)


static func _decision_for(state: Dictionary, pr_id: String) -> Dictionary:
	for decision: Dictionary in state.get("decisions", []):
		if decision.get("pr_id") == pr_id:
			return decision
	return {}


static func _arrived(state: Dictionary, request: Dictionary) -> bool:
	var request_day := int(request.day)
	var today := int(state.get("day", 1))
	if request_day < today:
		# Every earlier shift closed after all deliveries, including handed-off work.
		return true
	if request_day > today:
		return false
	return Catalog.arrival_seconds(str(request.id)) <= float(state.get("shift_seconds", 0.0))


static func _option(contact: String, pr_id: String, reply_id: String) -> Dictionary:
	if contact == "company" or contact not in CONTACTS or reply_id not in REPLY_IDS:
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
	if contact == "company" or contact not in CONTACTS or state.get("phase") != "review":
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
	_append(history, contact, str(packet.get("request", "")), "request", pr_id)
	var seen: Array = []
	for saved: Dictionary in state.get("chat_replies", []):
		if saved.get("contact") != contact or saved.get("pr_id") != pr_id:
			continue
		var reply_id := str(saved.get("reply_id", ""))
		if reply_id in seen:
			continue
		var option := _option(contact, pr_id, reply_id)
		if option.is_empty():
			continue
		seen.append(reply_id)
		_append(history, "You", str(option.text), "reply")
		_append(history, contact, str(option.response), "response")
	var decision := _decision_for(state, pr_id)
	if not decision.is_empty():
		# Reactions follow the chosen verdict; audit correctness is never consulted.
		_append(history, contact, str(packet.get(str(decision.get("verdict", "")), "")), "reaction")


static func messages(state: Dictionary, contact: String) -> Array:
	if contact not in CONTACTS:
		return []
	var authored := _authored()
	var history: Array = []
	if contact == "company":
		for notice: Dictionary in authored.get("company", []):
			if int(notice.day) <= int(state.get("day", 1)):
				_append(history, str(notice.author), str(notice.text), "notice")
		if int(state.get("autonomy", 0)) >= 65:
			_append(history, "Operations", "Helios has been added to the approval planning channel. The next staffing discussion is being prepared from its recommendations.", "ambient")
		elif int(state.get("autonomy", 0)) >= 35:
			_append(history, "Operations", "Helios is being copied on implementation handoffs now. Please keep a human owner named in the thread.", "ambient")
		var active_id := str(state.get("active_request_id", ""))
		if state.get("phase") == "review" and not active_id.is_empty() and active_id in state.get("consulted_requests", []):
			_append(history, "Helios", "I've attached my recommendation to the open review. You can refer to it while preparing your decision.", "notice")
		if state.get("phase") == "complete":
			_append(history, "Operations", "Your review assignment has closed. Keep the conversation history; ownership questions may come back after the rollout.", "notice")
	else:
		var person: Dictionary = authored.get("contacts", {}).get(contact, {})
		_append(history, contact, str(person.get("intro", "")), "intro")
		for request: Dictionary in Catalog.requests():
			if request.author == contact and _arrived(state, request):
				_request_history(history, state, contact, request)
		var relationship := int(state.get("coworkers", {}).get(contact, 50))
		var tone := "warm" if relationship >= 65 else ("distant" if relationship <= 35 else "neutral")
		_append(history, contact, str(person.get(tone, "")), "ambient")
	var start := maxi(0, history.size() - HISTORY_LIMIT)
	# Do not start a clipped history with a response whose player reply was removed.
	if start > 0 and history[start].kind == "response":
		start += 1
	return history.slice(start).duplicate(true)
