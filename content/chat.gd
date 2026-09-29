extends RefCounted
## A deterministic conversation view over existing state, never a second save system.

const Catalog = preload("res://content/catalog.gd")
const CONTACTS: Array = ["Maya", "Theo", "Inez", "company"]
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

static func _append(history: Array, author: String, text: String, kind: String) -> void:
	if not text.is_empty():
		history.append({"author": author, "text": text, "kind": kind})

static func _packet_messages(history: Array, author: String, packet: Dictionary) -> void:
	_append(history, author, str(packet.get("request", "")), "request")
	_append(history, author, str(packet.get("hint", "")), "hint")

static func messages(state: Dictionary, contact: String) -> Array:
	if contact not in CONTACTS:
		return []
	var authored: Dictionary = _authored()
	var history: Array = []
	if contact == "company":
		for notice: Dictionary in authored.get("company", []):
			if int(notice.day) <= int(state.day):
				_append(history, str(notice.author), str(notice.text), "notice")
		if int(state.autonomy) >= 65:
			_append(history, "Operations", "Helios has been added to the approval planning channel. The next staffing discussion is being prepared from its recommendations.", "ambient")
		elif int(state.autonomy) >= 35:
			_append(history, "Operations", "Helios is being copied on implementation handoffs now. Please keep a human owner named in the thread.", "ambient")
		if state.phase == "review" and state.consulted:
			_append(history, "Helios", "I've attached my recommendation to the open review. You can refer to it while preparing your decision.", "notice")
		if state.phase == "complete":
			_append(history, "Operations", "Your review assignment has closed. Keep the conversation history; ownership questions may come back after the rollout.", "notice")
	else:
		var person: Dictionary = authored.get("contacts", {}).get(contact, {})
		_append(history, contact, str(person.get("intro", "")), "intro")
		var known: Dictionary = {}
		for request: Dictionary in Catalog.requests():
			# Only public request identity is read; audit fields never enter chat.
			known[request.id] = {"author": request.author, "day": request.day}
		for decision: Dictionary in state.decisions:
			var identity: Dictionary = known.get(decision.pr_id, {})
			if identity.get("author") != contact or int(identity.get("day", 0)) > int(state.day):
				continue
			var packet: Dictionary = authored.get("requests", {}).get(decision.pr_id, {})
			_packet_messages(history, contact, packet)
			# Approval and rejection affect feelings independently of the audit result.
			_append(history, contact, str(packet.get(decision.verdict, "")), "reaction")
		if state.phase == "review":
			var active: Dictionary = Catalog.request_at(int(state.request_index))
			if active.get("author") == contact and int(active.get("day", 0)) == int(state.day):
				_packet_messages(history, contact, authored.get("requests", {}).get(active.id, {}))
		var relationship: int = int(state.coworkers.get(contact, 50))
		var tone: String = "warm" if relationship >= 65 else ("distant" if relationship <= 35 else "neutral")
		_append(history, contact, str(person.get(tone, "")), "ambient")
	return history.slice(maxi(0, history.size() - HISTORY_LIMIT)).duplicate(true)
