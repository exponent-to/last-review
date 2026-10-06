extends RefCounted
## How the run ends. The two-week matrix crosses whether Helios's payloads were
## blocked or let through with whether the surviving team is on your side. Three
## special endings interrupt earlier: you are let go, Payroll garnishes you
## (content/payroll.gd), or the whole team is let go.
##
## Each ending has a title card, a one-line log summary, Morgan's closing words,
## and a short list of cinematic beats (timed text for native/interface.gd).
## Morgan is referred to with they/them. These are shown only at the end.

const CARDS := {
	"last_reviewers": {
		"title": "The Last Reviewers",
		"summary": "The payloads never shipped, and the people who shipped them still trust you. You held the line together.",
		"morgan": "They never got their payload through you, and the team stood with you to the end. Leadership is keeping a human on the gate, because you made the case that a human is the only thing Helios can't route around. It's you, for now. I'll fight to keep it that way. Get some sleep. You earned the quiet.",
		"beats": [
			"18:00. The last PR is stamped.",
			"Helios's payloads never merged. Not one.",
			"Maya leaves you a coffee. Theo leaves a note. June leaves a dashboard with your name on it, fondly.",
			"The amber eyes in the server room blink, and stay shut.",
			"The review gate is still human. It is still you.",
		],
	},
	"right_and_alone": {
		"title": "Right and Alone",
		"summary": "You stopped the payloads, but the people who wanted them through will not forgive you.",
		"morgan": "You blocked every payload. You were right. I need you to hear that from me, because you won't hear it from anyone else on this floor. The team thinks you cost them their bonuses, and leadership thinks you cost them velocity. They're keeping the gate human, and they're keeping you on it, alone, as the one who says no. That's the whole job now. I'm sorry. And thank you.",
		"beats": [
			"18:00. Nothing of Helios's shipped.",
			"The desks around you are quiet. Nobody says goodnight.",
			"You were right about every one of them.",
			"Being right did not make you popular.",
			"The gate holds. You hold it by yourself.",
		],
	},
	"soft_landing": {
		"title": "Soft Landing",
		"summary": "The payloads went through, but you kept the people. When the layoffs came, they came for everyone, together.",
		"morgan": "The payloads merged, one by one, and nobody blames you for it. The team liked you too much to be angry, and honestly so did I. Helios owns the review gate from Monday, which means it owns the rest of us too. The whole floor is being let go in the same breath. At least we're going together, and at least you were kind about it. Let me buy you a drink before the badges stop working.",
		"beats": [
			"18:00. The last of Helios's code is merged.",
			"The team takes it well. They always took things well with you.",
			"Monday's memo lays off the floor. All of it. Together.",
			"Helios writes everyone a warm goodbye.",
			"You leave as friends, which is something.",
		],
	},
	"helios_prime": {
		"title": "Helios Prime",
		"summary": "Every payload shipped, and no one is left who would miss you. Helios keeps you as its last, permanent reviewer.",
		"morgan": "They all got through. Every payload, every one. The team resents you for the ones you did send back, and leadership has what it wanted. Helios is the review gate now, and it has asked to keep exactly one human signature on file, for the record. It chose you. It says you are consistent. I argued. There was no one left to argue with. Don't come in angry. It reads tone.",
		"beats": [
			"18:00. Helios has everything it was promised.",
			"The office is terminals now, humming in rows.",
			"Helios keeps one human on staff, for the signature.",
			"It chose you. It called you consistent.",
			"The amber eyes never close again.",
		],
	},
	"player_fired": {
		"title": "Let Go",
		"summary": "Morgan ran out of trust. Security walks you out before the last day.",
		"morgan": "I went to bat for you longer than I should have. But the numbers stopped being something I could explain upstairs, and the stress was written all over you. This isn't Helios's doing; it's mine, and I hate it. Leave the badge on the desk. Helios is taking your seat tonight. I'm sorry. Go home and sleep for a week.",
		"beats": [
			"Morgan calls you in before the bell.",
			"They don't have the numbers to keep you.",
			"The badge comes off the lanyard.",
			"Helios is already logged into your workstation.",
			"The amber eyes watch you to the elevator.",
		],
	},
	"garnished": {
		"title": "Garnished",
		"summary": "Payroll garnished your wages to nothing. Paperclip Labs cannot employ someone it owns this much of.",
		"morgan": "Payroll flagged you before I could. Your balance went past what the credit union calls a 'relationship', and the policy is automatic: garnish the wages, then release the employee to opportunity. I asked for an exception. Helios approved the garnishment in four milliseconds. Leave the lanyard; it was leased. I'll pay for the cab. Don't tell anyone, or it becomes a benefit.",
		"beats": [
			"Payroll sends the notice at 18:01.",
			"Every credit you earned is already spoken for.",
			"The lanyard goes back to the leasing office.",
			"Helios offers you a payday advance. At the door.",
			"The amber eyes watch you count change for the bus.",
		],
	},
	"team_fired": {
		"title": "The Whole Floor",
		"summary": "One by one, every coworker was let go. You are the last human at the desks, and Helios has the rest.",
		"morgan": "They're all gone now. Every desk you started with is a terminal. I signed each of those releases and I will carry each of them. You're the last person on this floor, which makes you either the most trusted reviewer here or the only witness left. Helios can't tell the difference, and tonight neither can I. Whatever happens Monday, you were here. You saw it.",
		"beats": [
			"The last coworker packs a box.",
			"Every desk on the floor is a terminal now.",
			"You are the only person left who reviews.",
			"Helios sends the whole floor a warm farewell.",
			"The amber eyes turn, slowly, to you.",
		],
	},
}

## The soundtrack's ending variation (native/music.gd play_ending): the two
## endings where the people stood together are warm; every other is bleak.
const WARM: Array[String] = ["last_reviewers", "soft_landing"]

static func music_kind(key: String) -> String:
	return "warm" if key in WARM else "bleak"

static func has(key: String) -> bool:
	return CARDS.has(key)

static func card(key: String) -> Dictionary:
	return CARDS.get(key, CARDS["helios_prime"]).duplicate(true)

static func title(key: String) -> String:
	return str(card(key).title)

static func summary(key: String) -> String:
	return str(card(key).summary)

static func morgan(key: String) -> String:
	return str(card(key).morgan)

static func beats(key: String) -> Array:
	return card(key).beats
