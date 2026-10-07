extends RefCounted
## Pressure from the line outside the booth. As PRs pile up, the people waiting
## ping you about theirs, Helios offers to take the backlog off your hands, and
## Morgan checks in. All of it goes through REVIEW's desktop notifications.
##
## It reacts only to who is waiting and for how long (Simulation.waiting), never to
## what is in a PR, so it can't hint at whether anything is broken. It is pure
## and rate-limited: at most one message every PING_GAP game seconds, each PR
## pings once, and each nudge comes once a day. `memory` is the caller's record.

const Catalog = preload("res://content/catalog.gd")

## Game seconds a PR waits (two office hours) before its author pings about it.
const IMPATIENT_AFTER := 40
## Game seconds (seventy-five office minutes) between any two messages.
const PING_GAP := 25
## Line lengths that bring a word from Helios or Morgan, once each a day. %s is
## how many are waiting, spelled out.
const NUDGES: Array = [
	{"at": 5, "person": "Helios", "text": "Helios: %s reviews are waiting on you. I can clear your backlog. Just say the word."},
	{"at": 8, "person": "Morgan", "text": "Morgan: %s in your line. Don't rush the reads. Whatever's left at six goes to Helios."},
	{"at": 11, "person": "Helios", "text": "Helios: %s waiting. I've already read them all. Just say the word."},
]
## What an author says when their PR has waited too long. %s is its number.
const IMPATIENT: Dictionary = {
	"Maya": ["Still waiting on %s. No rush. Okay, a little rush.", "Is %s still in your pile? I'm trying to plan my afternoon around it."],
	"Theo": ["%s has been in your line since before lunch. Just saying.", "Not to hover, but %s. I'm hovering."],
	"June": ["Any eyes on %s yet? Asking for my yogurt.", "%s is still waiting. I've reorganized my desk twice."],
	"Penny": ["Pinging on %s. Standup is going to ask me about it.", "Quick one: is %s on your radar? My manager's manager asked."],
	"Gwen": ["Is %s lost? I can resend it. I can resend it louder.", "Still in line with %s. The line has a smell now."],
}
const FALLBACK: Array = ["Still waiting on %s.", "Any word on %s?"]
const WORDS: Array = ["None", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
	"Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen", "Twenty"]


## "Eight": a count the way Morgan would say it.
static func count_word(count: int) -> String:
	return str(WORDS[count]) if count >= 0 and count < WORDS.size() else str(count)


static func empty_memory() -> Dictionary:
	return {"day": -1, "last": -1000, "pinged": {}, "nudged": {}}


## The next message the line has for you right now, or {} for none. On a message,
## `memory` is updated so it isn't said again. Returns {person, text, target}.
static func next(waiting: Array, day: int, now: int, memory: Dictionary) -> Dictionary:
	if int(memory.get("day", -1)) != day:
		memory.merge(empty_memory(), true)
		memory.day = day
	if now - int(memory.last) < PING_GAP: return {}
	for nudge: Dictionary in NUDGES:
		if waiting.size() >= int(nudge.at) and not memory.nudged.has(int(nudge.at)):
			# Crossing two thresholds at once (a load mid-afternoon) says only the latest.
			for other: Dictionary in NUDGES:
				if int(other.at) <= waiting.size(): memory.nudged[int(other.at)] = true
			var latest: Dictionary = nudge
			for other: Dictionary in NUDGES:
				if int(other.at) <= waiting.size(): latest = other
			memory.last = now
			return {"person": str(latest.person), "text": str(latest.text) % count_word(waiting.size()), "target": ""}
	# The longest-waiting PR whose author hasn't pinged yet.
	for entry: Dictionary in waiting:
		if int(entry.age) < IMPATIENT_AFTER: continue
		var id := str(entry.id)
		if memory.pinged.has(id): continue
		memory.pinged[id] = true
		memory.last = now
		var author := str(entry.author)
		var lines: Array = IMPATIENT.get(author, FALLBACK)
		var text: String = str(lines[absi(hash(id)) % lines.size()]) % Catalog.display_id(id)
		return {"person": author, "text": "%s: %s" % [author, text], "target": id}
	return {}
