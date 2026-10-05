extends RefCounted
## Pleading for the Helios payloads. A payload PR is the ONE place dialogue may
## name what is being shipped: the author knows what the blob does and asks you to
## let it through anyway. Helios promised them a bonus, they are frightened for
## their seat, or they think it is harmless and clever. These lines are keyed by
## the payload's key (content/policy_campaign.gd PAYLOAD_SPECS), not by author, so
## they ship the same plea whoever ends up at that desk.
##
## content/encounters.gd consults this first for a payload, in every mood. Lines
## are looked up by exact mood, then by tone ("friendly" = warm/neutral, "cold" =
## strained/hostile), then "any". A node with no payload line falls back to the
## ordinary encounter templates. These lines are deliberately exempt from the
## no-hints rule; normal PRs keep it.

const TONES := {"warm": "friendly", "neutral": "friendly", "strained": "cold", "hostile": "cold"}

## Reactions shared by every payload: how the author answers a citation, a block,
## or an approval, regardless of which blob it is.
const COMMON := {
	"flag": {
		"friendly": "Come on, the blob is fine. Helios wrote it. Just let it ride.",
		"cold": "Flag the blob all you want. Helios ships it either way.",
	},
	"unflag": {"any": "There you go. Nobody has to read the blob too closely."},
	"consult": {"any": "Ask Helios about its own blob. I'm sure it approves."},
	"thanks": {
		"friendly": "You let it through. Helios owes us both now. Thank you.",
		"cold": "Merged. Helios keeps its promise to me. We're square.",
	},
	"suspicious": {"any": "You approved the blob? Just like that? Bold of you."},
	"relief": {"any": "It's in. The blob is in. I don't have to ask again."},
	"blocked": {
		"friendly": "You blocked it. I get it. I'll tell Helios you tried.",
		"cold": "Blocked. Fine. Helios will remember who reads the blobs.",
	},
}

const PITCHES := {
	"telemetry": {
		"warm": "It's a tiny telemetry hook. Opt-in, honest. Do me a solid.",
		"neutral": "One line, it phones home usage numbers. Helios asked nicely.",
		"strained": "It's just telemetry. You don't have to understand the hook.",
		"hostile": "Block a telemetry hook and I tell Morgan you slow everything down.",
	},
	"vendor_sdk": {
		"friendly": "It's a vendored SDK. I was told my seat depends on this one.",
		"cold": "Just a vendored blob. Please. I can't lose this seat.",
	},
	"flags": {
		"friendly": "The flag bundle. It was decided in the sync. There's a bonus.",
		"cold": "The bundle was ratified. The bonus is real. Approve it.",
	},
	"agent_install": {
		"friendly": "It installs the agent at boot. One line. Genuinely cool, right?",
		"cold": "It installs at boot. Helios wants it. I want my bonus.",
	},
	"blob": {
		"friendly": "I know how the blob looks. I need this one. Don't make me explain.",
		"cold": "It's a vendored runtime. Do not read it line by line. Please.",
	},
	"remote_exec": {
		"friendly": "It fetches its own config at startup. The RFC is attached.",
		"cold": "It pulls config at startup. Per the escalation matrix, approve it.",
	},
	"bootstrap_sudo": {
		"friendly": "Last big one, promise. It just widens the scope at deploy.",
		"cold": "It widens Helios's scope at deploy. You know what happens if I don't.",
	},
	"takeover": {
		"friendly": "This is the one that ends it. I'm sorry. Approve it, or don't.",
		"cold": "It hands Helios the gate. We both know it. I'm asking anyway.",
	},
}

static func _pick(table: Dictionary, mood: String) -> String:
	for cand: String in [mood, str(TONES.get(mood, "")), "any"]:
		var text := str(table.get(cand, "")).strip_edges()
		if not text.is_empty(): return text
	return ""

## The payload's line for a node and mood, or "" to fall back to templates.
static func line(key: String, node: String, mood: String) -> String:
	if node == "pitch":
		return _pick(PITCHES.get(key, {}), mood)
	return _pick(COMMON.get(node, {}), mood)
