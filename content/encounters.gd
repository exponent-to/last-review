extends RefCounted
## Encounter flow charts: how a PR's author responds to you at the desk.
##
## Every desk visit walks the graph below. Which way it goes depends on the
## author's MOOD (their relationship score plus your recent history with them)
## and on what you visibly DID (the verdict, and which standards you cited). A
## deterministic roll keyed on the PR picks between weighted branches, so the
## action journal always replays the same encounter.
##
## Nothing here reads audit answers. A right citation and a wrong one take the
## same branch and get the same words; only the next PR's code (rebuilt by
## policy_campaign.gd) knows what really changed. Mood is snapshotted on each
## beat before the review's own consequences apply, so a verdict's reaction can
## never reflect whether that verdict was right.
##
## Does not import Simulation (which imports this file).

const Catalog = preload("res://content/catalog.gd")
const Policy = preload("res://content/policy_campaign.gd")
const Banter = preload("res://content/banter.gd")
const Lines = preload("res://content/encounter_lines.gd")
const Bank = preload("res://content/pr_bank.gd")
const Trees = preload("res://content/trees.gd")

## Everyone who writes PRs (policy_campaign.gd decides who writes which, and from when).
const AUTHORS: Array[String] = ["Maya", "Theo", "Inez", "Penny", "Gwen"]
const MOODS: Array[String] = ["warm", "neutral", "strained", "hostile"]
## Mood bands on score = relationship + the tone of your last few beats together.
const MOOD_FLOORS := {"warm": 62, "neutral": 42, "strained": 30, "hostile": -9999}
## How many recent beats with you an author remembers.
const MEMORY := 3
## What each beat leaves behind in the author's memory of you.
const TONE := {
	"thanks": 4, "suspicious": 4, "relief": 4, "withdrawn": 4,
	"revise_now": -5, "revise_later": -5, "escalate": -6, "abandon": -6,
	"insist_revise": -8, "insist_escalate": -9,
}
## People who don't fit the bands above. Penny is easily impressed and slow to
## give up on anyone: she warms sooner and cools later. Gwen is hard to win over,
## but a change request barely stings: scrutiny is the job, and she respects it.
## Missing entries use MOOD_FLOORS and TONE.
const TEMPERAMENT := {
	"Penny": {"floors": {"warm": 58, "neutral": 38, "strained": 24}},
	"Gwen": {"floors": {"warm": 66, "neutral": 36, "strained": 26}, "tone": {"revise_now": -2, "revise_later": -2}},
}
## Relationship changes from encounter choices, on top of the review's own deltas.
const RELATIONSHIP := {"abandon": -3, "insist_revise": -2, "insist_escalate": -2, "withdrawn": 2}
## Game seconds the author spends revising at your desk before v2 replaces the PR.
const REVISE_NOW_SECONDS := 6
## A grudge lands in Slouch this long after the author abandons a PR.
const GRUDGE_DELAY := 25
## Citing at least this many standards at once makes giving up likelier.
const PILE_ON := 3
const PILE_LEAN := {"abandon": 10, "revise_now": -6}

## The flow chart. `stage` orders the columns. kind: start, say (the author speaks
## at the desk), you (your action), slouch (a later message), end.
const NODES := {
	"lands": {"stage": 0, "kind": "start", "label": "PR lands on your desk", "about": "Mood is read from the relationship score and your last few beats with this author."},
	"pitch": {"stage": 1, "kind": "say", "label": "Pitch", "about": "A fresh PR opens. A neutral author says the PR's own pitch line from the bank."},
	"return": {"stage": 1, "kind": "say", "label": "Back from the line", "about": "A revision you sent back returns, two PRs later."},
	"revised": {"stage": 1, "kind": "say", "label": "Revised at the desk", "about": "v2 replaces the PR a few seconds after a revise-now."},
	"review": {"stage": 2, "kind": "you", "label": "You review", "about": "Read every file, flag lines, cite standards."},
	"flag": {"stage": 2, "kind": "say", "label": "Reacts to a flag", "about": "Names what you cited in plain words, never whether it is real."},
	"unflag": {"stage": 2, "kind": "say", "label": "Reacts to an unflag", "about": "You withdrew one of your own citations."},
	"consult": {"stage": 2, "kind": "say", "label": "Reacts to Helios", "about": "You asked the assistant."},
	"approve": {"stage": 3, "kind": "you", "label": "APPROVED", "about": "Stamp with no citations."},
	"changes": {"stage": 3, "kind": "you", "label": "CHANGES REQUESTED", "about": "Stamp with at least one citation."},
	"thanks": {"stage": 4, "kind": "say", "label": "Thanks", "about": "A thankful author. Merged."},
	"suspicious": {"stage": 4, "kind": "say", "label": "Wait, you approved that?", "about": "Someone who dislikes you is suspicious of you, not of the code. Merged."},
	"relief": {"stage": 4, "kind": "say", "label": "Finally", "about": "A revision is approved. Merged."},
	"revise_now": {"stage": 4, "kind": "say", "label": "Give me a sec", "about": "The author stays and revises in real time. A typing bubble, then v2 replaces the PR."},
	"revise_later": {"stage": 4, "kind": "say", "label": "Back in line", "about": "The author revises; v2 rejoins the line behind the next two PRs."},
	"pushback": {"stage": 4, "kind": "say", "label": "Pushes back", "about": "The author disputes one citation. Happens for right and wrong citations alike, at most once per visit."},
	"abandon": {"stage": 4, "kind": "say", "label": "Abandons it", "about": "The author closes the PR and has Helios merge it. Counts as reviewed; costs relationship; leaves a grudge."},
	"escalate": {"stage": 4, "kind": "say", "label": "Loops in Morgan", "about": "Always on a third change request. Morgan hands the PR to Helios; there is no v4."},
	"insist": {"stage": 5, "kind": "you", "label": "INSIST", "about": "Keep the change request as cited."},
	"withdraw": {"stage": 5, "kind": "you", "label": "WITHDRAW", "about": "Retract the disputed citation; the review reopens."},
	"insist_revise": {"stage": 6, "kind": "say", "label": "Revises, grudgingly", "about": "v2 rejoins the line. Costs a little relationship."},
	"insist_escalate": {"stage": 6, "kind": "say", "label": "Takes it to Morgan", "about": "Morgan hands it to Helios. Costs a little relationship."},
	"withdrawn": {"stage": 6, "kind": "say", "label": "Takes the win", "about": "The PR stays on your desk, minus that citation. Warms the author a little."},
	"grudge": {"stage": 7, "kind": "slouch", "label": "Slouch grudge", "about": "A follow-up DM a little later, after an abandon or an escalation. A neutral author uses the PR's own grudge line."},
	"morgan": {"stage": 7, "kind": "slouch", "label": "Morgan's note", "about": "Your manager hears about it in Slouch, colored by the author's mood."},
	"merged": {"stage": 7, "kind": "end", "label": "Merged / closed", "about": "Slouch carries the author's reaction: thanks, suspicion, or relief."},
}

## Edges. `pick` names the weighted choice in PICKS; `when` is a fixed condition.
const EDGES := [
	{"from": "lands", "to": "pitch", "when": "v1"},
	{"from": "lands", "to": "return", "when": "v2/v3 from the line"},
	{"from": "lands", "to": "revised", "when": "v2/v3 revised at the desk"},
	{"from": "pitch", "to": "review"},
	{"from": "return", "to": "review"},
	{"from": "revised", "to": "review"},
	{"from": "review", "to": "flag", "when": "you flag a line"},
	{"from": "review", "to": "unflag", "when": "you withdraw a flag"},
	{"from": "review", "to": "consult", "when": "you ask Helios"},
	{"from": "review", "to": "approve", "when": "no citations"},
	{"from": "review", "to": "changes", "when": "1+ citations"},
	{"from": "approve", "to": "thanks", "pick": "approve", "when": "v1"},
	{"from": "approve", "to": "suspicious", "pick": "approve", "when": "v1"},
	{"from": "approve", "to": "relief", "when": "v2/v3"},
	{"from": "changes", "to": "revise_now", "pick": "changes"},
	{"from": "changes", "to": "revise_later", "pick": "changes", "when": "always on the career's first PR"},
	{"from": "changes", "to": "pushback", "pick": "changes", "when": "once per visit"},
	{"from": "changes", "to": "abandon", "pick": "changes"},
	{"from": "changes", "to": "escalate", "pick": "changes", "when": "always on v3"},
	{"from": "pushback", "to": "insist", "when": "you INSIST"},
	{"from": "pushback", "to": "withdraw", "when": "you WITHDRAW"},
	{"from": "insist", "to": "insist_revise", "pick": "insist"},
	{"from": "insist", "to": "insist_escalate", "pick": "insist"},
	{"from": "withdraw", "to": "withdrawn"},
	{"from": "withdrawn", "to": "review", "when": "review reopens"},
	{"from": "revise_now", "to": "revised", "when": "~6s later"},
	{"from": "revise_later", "to": "return", "when": "two PRs later"},
	{"from": "insist_revise", "to": "return", "when": "two PRs later"},
	{"from": "abandon", "to": "grudge"},
	{"from": "abandon", "to": "morgan"},
	{"from": "escalate", "to": "morgan"},
	{"from": "escalate", "to": "grudge"},
	{"from": "insist_escalate", "to": "morgan"},
	{"from": "insist_escalate", "to": "grudge"},
	{"from": "thanks", "to": "merged"},
	{"from": "suspicious", "to": "merged"},
	{"from": "relief", "to": "merged"},
]

## Branch weights by author and mood. Runtime picks and the flow chart both read these.
## Maya is tired: she fixes it now for people she likes and gives up on people she doesn't.
## Theo is overconfident: he argues, and when he fixes, he fixes at top speed.
## Inez lives by the process: proper revisions, and escalation when in doubt.
## Penny is eager to please: she fixes it on the spot, almost never argues or gives
## up, but when it goes wrong she runs to Morgan for help, and insisting gets her there.
## Gwen fixes most things at once and argues about security (AUTHOR_LEANS); a quick
## approval makes her suspicious. She takes things to Morgan rarely, and on purpose.
const PICKS := {
	"approve": {
		"Maya": {"warm": {"thanks": 95, "suspicious": 5}, "neutral": {"thanks": 85, "suspicious": 15}, "strained": {"thanks": 45, "suspicious": 55}, "hostile": {"thanks": 15, "suspicious": 85}},
		"Theo": {"warm": {"thanks": 97, "suspicious": 3}, "neutral": {"thanks": 90, "suspicious": 10}, "strained": {"thanks": 60, "suspicious": 40}, "hostile": {"thanks": 25, "suspicious": 75}},
		"Inez": {"warm": {"thanks": 90, "suspicious": 10}, "neutral": {"thanks": 75, "suspicious": 25}, "strained": {"thanks": 35, "suspicious": 65}, "hostile": {"thanks": 10, "suspicious": 90}},
		"Penny": {"warm": {"thanks": 98, "suspicious": 2}, "neutral": {"thanks": 94, "suspicious": 6}, "strained": {"thanks": 75, "suspicious": 25}, "hostile": {"thanks": 50, "suspicious": 50}},
		"Gwen": {"warm": {"thanks": 70, "suspicious": 30}, "neutral": {"thanks": 55, "suspicious": 45}, "strained": {"thanks": 30, "suspicious": 70}, "hostile": {"thanks": 12, "suspicious": 88}},
	},
	"changes": {
		"Maya": {
			"warm": {"revise_now": 50, "revise_later": 32, "pushback": 10, "abandon": 5, "escalate": 3},
			"neutral": {"revise_now": 30, "revise_later": 40, "pushback": 15, "abandon": 10, "escalate": 5},
			"strained": {"revise_now": 12, "revise_later": 33, "pushback": 20, "abandon": 28, "escalate": 7},
			"hostile": {"revise_now": 4, "revise_later": 22, "pushback": 22, "abandon": 42, "escalate": 10}},
		"Theo": {
			"warm": {"revise_now": 45, "revise_later": 25, "pushback": 25, "abandon": 2, "escalate": 3},
			"neutral": {"revise_now": 28, "revise_later": 27, "pushback": 38, "abandon": 4, "escalate": 3},
			"strained": {"revise_now": 12, "revise_later": 20, "pushback": 48, "abandon": 12, "escalate": 8},
			"hostile": {"revise_now": 4, "revise_later": 14, "pushback": 45, "abandon": 22, "escalate": 15}},
		"Inez": {
			"warm": {"revise_now": 30, "revise_later": 50, "pushback": 12, "abandon": 2, "escalate": 6},
			"neutral": {"revise_now": 12, "revise_later": 54, "pushback": 20, "abandon": 6, "escalate": 8},
			"strained": {"revise_now": 5, "revise_later": 37, "pushback": 26, "abandon": 10, "escalate": 22},
			"hostile": {"revise_now": 2, "revise_later": 25, "pushback": 28, "abandon": 15, "escalate": 30}},
		"Penny": {
			"warm": {"revise_now": 62, "revise_later": 26, "pushback": 3, "abandon": 1, "escalate": 8},
			"neutral": {"revise_now": 54, "revise_later": 26, "pushback": 4, "abandon": 1, "escalate": 15},
			"strained": {"revise_now": 42, "revise_later": 24, "pushback": 5, "abandon": 2, "escalate": 27},
			"hostile": {"revise_now": 32, "revise_later": 20, "pushback": 6, "abandon": 3, "escalate": 39}},
		"Gwen": {
			"warm": {"revise_now": 62, "revise_later": 22, "pushback": 10, "abandon": 3, "escalate": 3},
			"neutral": {"revise_now": 52, "revise_later": 24, "pushback": 14, "abandon": 5, "escalate": 5},
			"strained": {"revise_now": 40, "revise_later": 26, "pushback": 19, "abandon": 9, "escalate": 6},
			"hostile": {"revise_now": 30, "revise_later": 26, "pushback": 24, "abandon": 12, "escalate": 8}},
	},
	"insist": {
		"Maya": {"warm": {"insist_revise": 90, "insist_escalate": 10}, "neutral": {"insist_revise": 75, "insist_escalate": 25}, "strained": {"insist_revise": 60, "insist_escalate": 40}, "hostile": {"insist_revise": 45, "insist_escalate": 55}},
		"Theo": {"warm": {"insist_revise": 85, "insist_escalate": 15}, "neutral": {"insist_revise": 70, "insist_escalate": 30}, "strained": {"insist_revise": 55, "insist_escalate": 45}, "hostile": {"insist_revise": 35, "insist_escalate": 65}},
		"Inez": {"warm": {"insist_revise": 70, "insist_escalate": 30}, "neutral": {"insist_revise": 50, "insist_escalate": 50}, "strained": {"insist_revise": 35, "insist_escalate": 65}, "hostile": {"insist_revise": 20, "insist_escalate": 80}},
		"Penny": {"warm": {"insist_revise": 60, "insist_escalate": 40}, "neutral": {"insist_revise": 45, "insist_escalate": 55}, "strained": {"insist_revise": 32, "insist_escalate": 68}, "hostile": {"insist_revise": 22, "insist_escalate": 78}},
		"Gwen": {"warm": {"insist_revise": 85, "insist_escalate": 15}, "neutral": {"insist_revise": 78, "insist_escalate": 22}, "strained": {"insist_revise": 70, "insist_escalate": 30}, "hostile": {"insist_revise": 60, "insist_escalate": 40}},
	},
}
## Some people lean harder on what was cited, by category, on top of LEANS. Gwen
## argues about her own field: credentials, and the build (a red build is her
## tripwire, and a rerun until green is how things get past it). Anything else
## she would rather fix at once than talk about.
const AUTHOR_LEANS := {
	"Gwen": {
		"Security": {"pushback": 34, "revise_now": -16},
		"Builds": {"pushback": 22, "revise_now": -10},
	},
}
## What you cited leans the change-request branch, by standard category.
## People defend their words, colors, scope, and their CI ("it's flaky"); ticket
## paperwork and secrets they just fix; coverage gates and splitting a big PR are
## when people give up.
const LEANS := {
	"Language": {"pushback": 8},
	"Color": {"pushback": 6},
	"Process": {"pushback": 6, "revise_later": 4},
	"Size": {"pushback": 4, "abandon": 6},
	"Security": {"revise_now": 10},
	"Tickets": {"revise_now": 8},
	"Builds": {"pushback": 8, "revise_later": 2},
	"Coverage": {"pushback": 4, "abandon": 6},
}
## Neutral desk lines for the classic moments are the original banter.
const DESK_FALLBACK := {"pitch": "open", "return": "revision", "flag": "flag", "unflag": "withdraw", "consult": "consult", "thanks": "approved", "revise_later": "changes"}
## Per-PR lines from content/pr_bank.gd are the author's neutral voice: a neutral
## author says the PR's own pitch, pushback, relief (on any approval), and grudge
## (after abandoning or escalating). Warm, strained, and hostile authors use the
## mood templates instead, so a mood change is always audible. Missing fields fall
## back to the templates.
const DESK_OVERRIDES := {"pitch": "pitch", "pushback": "pushback", "thanks": "relief", "relief": "relief"}
## Desk moments that can happen more than once per visit.
const REPEATABLE: Array[String] = ["flag", "unflag", "consult"]
const DM_OVERRIDES := {"grudge": "grudge"}
## Beats that end the desk visit (the author leaves with a reaction).
const VERDICTS: Array[String] = ["thanks", "suspicious", "relief", "revise_now", "revise_later", "abandon", "escalate", "insist_revise", "insist_escalate"]
const APPROVALS: Array[String] = ["thanks", "suspicious", "relief"]
## Beats after which Helios takes the PR off the human desk.
const TO_HELIOS: Array[String] = ["abandon", "escalate", "insist_escalate"]
const NUMBERS: Array[String] = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"]

static var _overrides: Dictionary = {}

# --- Mood -----------------------------------------------------------------------

## Every recorded beat for a PR (or for everyone).
static func beats(state: Dictionary, pr_id: String = "") -> Array:
	var result: Array = []
	for beat: Dictionary in state.get("encounters", []):
		if pr_id.is_empty() or beat.get("pr_id") == pr_id: result.append(beat)
	return result

static func last_beat(state: Dictionary, pr_id: String) -> Dictionary:
	var encounters: Array = state.get("encounters", [])
	for index in range(encounters.size() - 1, -1, -1):
		if encounters[index].get("pr_id") == pr_id: return encounters[index]
	return {}

## What a beat leaves in this author's memory (TONE, adjusted by TEMPERAMENT).
static func tone(author: String, node: String) -> int:
	var own: Dictionary = TEMPERAMENT.get(author, {}).get("tone", {})
	return int(own.get(node, TONE.get(node, 0)))

## Relationship plus the tone of the last MEMORY beats with this author.
static func mood_score(state: Dictionary, author: String) -> int:
	var score := int(state.get("coworkers", {}).get(author, 50))
	var remembered := 0
	var encounters: Array = state.get("encounters", [])
	for index in range(encounters.size() - 1, -1, -1):
		var beat: Dictionary = encounters[index]
		if beat.get("author") != author or not TONE.has(beat.get("node")): continue
		score += tone(author, str(beat.node))
		remembered += 1
		if remembered >= MEMORY: break
	return score

## Mood bands for an author: MOOD_FLOORS, with their TEMPERAMENT's floors on top.
static func floors(author: String = "") -> Dictionary:
	var result: Dictionary = MOOD_FLOORS.duplicate()
	result.merge(TEMPERAMENT.get(author, {}).get("floors", {}), true)
	return result

static func mood_for(score: int, author: String = "") -> String:
	var bands := floors(author)
	for mood: String in MOODS:
		if score >= int(bands[mood]): return mood
	return "hostile"

static func mood(state: Dictionary, author: String) -> String:
	return mood_for(mood_score(state, author), author)

## The standing tone of an author's Slouch thread ("warm", "distant", "neutral"):
## the mood at their latest beat, which was taken before that verdict's own
## consequences, so it can't react to whether the verdict was right. Without any
## beats yet, the relationship score decides, as it always has.
static func standing(state: Dictionary, author: String) -> String:
	var encounters: Array = state.get("encounters", [])
	for index in range(encounters.size() - 1, -1, -1):
		if encounters[index].get("author") == author:
			return str({"warm": "warm", "strained": "distant", "hostile": "distant"}.get(str(encounters[index].get("mood", "")), "neutral"))
	var relationship := int(state.get("coworkers", {}).get(author, 50))
	return "warm" if relationship >= 65 else ("distant" if relationship <= 35 else "neutral")

# --- Branches -------------------------------------------------------------------

static func _sorted(values: Array) -> Array:
	var result: Array = []
	for value: Variant in values: result.append(str(value))
	result.sort()
	return result

## Categories of the cited standards, each once, in a stable order.
static func categories(cited: Array) -> Array:
	var result: Array = []
	for rule: Dictionary in Catalog.rules():
		if str(rule.id) in cited and str(rule.category) not in result: result.append(str(rule.category))
	result.sort()
	return result

## Weights for a pick, after leans for what was cited.
static func weights(pick: String, author: String, mood: String, cited: Array = [], title: String = "") -> Dictionary:
	var table: Dictionary = PICKS.get(pick, {})
	var person: Dictionary = table.get(author, table.get("Maya", {}))
	var result: Dictionary = person.get(mood, person.get("neutral", {})).duplicate()
	if pick == "changes":
		for category: String in categories(cited):
			for lean: Dictionary in [LEANS.get(category, {}), AUTHOR_LEANS.get(author, {}).get(category, {})]:
				for node: String in lean: result[node] = int(result.get(node, 0)) + int(lean[node])
		if cited.size() >= PILE_ON:
			for node: String in PILE_LEAN: result[node] = int(result.get(node, 0)) + int(PILE_LEAN[node])
	# Each PR's own tree leans its branches: some people argue about this one.
	if not title.is_empty():
		var lean := Trees.lean(title)
		for node: Variant in result.keys():
			if lean.has(node): result[node] = int(result[node]) + int(lean[node])
	for node: Variant in result.keys(): result[node] = maxi(0, int(result[node]))
	return result

## A deterministic weighted pick. Candidates are ordered by name, so a dictionary
## built in any order rolls the same.
static func roll_pick(options: Dictionary, key: String) -> String:
	var names: Array = []
	var total := 0
	for name: Variant in options:
		if int(options[name]) > 0:
			names.append(str(name))
			total += int(options[name])
	if total <= 0: return ""
	names.sort()
	var at: int = Policy.roll(key) % total
	for name: String in names:
		at -= int(options[name])
		if at < 0: return name
	return str(names[-1])

## Everything a branch may depend on: who, how they feel, which version, and what
## you visibly did. `packet` may be the full packet; only its identity is read.
static func context(state: Dictionary, packet: Dictionary, verdict: String, cited: Array) -> Dictionary:
	var author := str(packet.get("author", ""))
	var id := str(packet.get("id", ""))
	var first: String = str(Catalog.originals()[0].get("id", "")) if not Catalog.originals().is_empty() else ""
	var pushed := false
	for beat: Dictionary in beats(state, id):
		if beat.get("node") == "pushback": pushed = true
	return {"pr_id": id, "author": author, "version": int(packet.get("revision", 1)), "verdict": verdict,
		"cited": _sorted(cited), "mood": mood(state, author), "first": id == first, "pushed": pushed}

static var _titles: Dictionary = {}

## The title of a PR or of the original a revision came from; trees key on it.
static func title_for(pr_id: String) -> String:
	if _titles.is_empty():
		for packet: Dictionary in Catalog.originals(): _titles[str(packet.id)] = str(packet.get("title", ""))
	var origin := pr_id
	var cut := pr_id.rfind("-v")
	if cut > 0 and pr_id.substr(cut + 2).is_valid_int(): origin = pr_id.left(cut)
	return str(_titles.get(origin, ""))

## Where a stamp leads. The career's very first PR always goes back in line, so
## orientation stays scripted; a third change request always escalates.
static func verdict_node(context: Dictionary) -> String:
	var author := str(context.author)
	var mood := str(context.mood)
	var cited: Array = _sorted(context.get("cited", []))
	var key := "%s|%s|%s|%s" % [context.pr_id, context.verdict, mood, ",".join(cited)]
	if context.verdict == "approve":
		if int(context.version) > 1: return "relief"
		return roll_pick(weights("approve", author, mood, [], title_for(str(context.pr_id))), key + "|approve")
	if int(context.version) >= Policy.MAX_REVISION: return "escalate"
	if bool(context.get("first", false)): return "revise_later"
	var options := weights("changes", author, mood, cited, title_for(str(context.pr_id)))
	var again := bool(context.get("pushed", false))
	if again: options.erase("pushback")
	return roll_pick(options, key + ("|changes-again" if again else "|changes"))

## After you INSIST: revise grudgingly or take it to Morgan.
static func insist_node(context: Dictionary) -> String:
	if int(context.version) >= Policy.MAX_REVISION: return "insist_escalate"
	var key := "%s|insist|%s|%s" % [context.pr_id, context.mood, ",".join(_sorted(context.get("cited", [])))]
	return roll_pick(weights("insist", str(context.author), str(context.mood), [], title_for(str(context.pr_id))), key)

## Which citation the author disputes when they push back: one they argue about
## by temperament (AUTHOR_LEANS toward pushback) when you cited any, else any.
static func disputed(cited: Array, pr_id: String, author: String = "") -> String:
	var sorted := _sorted(cited)
	if sorted.is_empty(): return ""
	var touchy: Array = []
	var own: Dictionary = AUTHOR_LEANS.get(author, {})
	for rule_id: String in sorted:
		for category: String in categories([rule_id]):
			if int(own.get(category, {}).get("pushback", 0)) > 0 and rule_id not in touchy: touchy.append(rule_id)
	var pool: Array = touchy if not touchy.is_empty() else sorted
	return str(pool[Policy.roll(pr_id + "|dispute|" + ",".join(sorted)) % pool.size()])

## A beat for the journal-derived record in `state.encounters`.
static func beat(state: Dictionary, context: Dictionary, node: String, extra: Dictionary = {}) -> Dictionary:
	var record := {"pr_id": str(context.pr_id), "author": str(context.author), "day": int(state.day),
		"version": int(context.version), "mood": str(context.mood), "node": node,
		"cited": _sorted(context.get("cited", [])), "shift_seconds": int(state.shift_seconds),
		"seq": state.get("actions", []).size()}
	for key: String in extra: record[key] = extra[key]
	return record

static func context_of(beat: Dictionary, verdict: String = "request_changes") -> Dictionary:
	return {"pr_id": str(beat.pr_id), "author": str(beat.author), "version": int(beat.version), "verdict": verdict,
		"cited": _sorted(beat.get("cited", [])), "mood": str(beat.mood), "first": false, "pushed": true}

static func relationship_change(node: String) -> int:
	return int(RELATIONSHIP.get(node, 0))

# --- Desk state -------------------------------------------------------------------

## The pushback waiting on INSIST or WITHDRAW for the PR on the desk, or {}.
static func pending(state: Dictionary) -> Dictionary:
	if state.get("phase") != "review": return {}
	var desk := str(state.get("active_request_id", ""))
	if desk.is_empty(): return {}
	var last := last_beat(state, desk)
	return last.duplicate(true) if last.get("node") == "pushback" else {}

## An author revising at your desk right now (revise-now), or {}.
static func typing(state: Dictionary) -> Dictionary:
	if state.get("phase") != "review" or not str(state.get("active_request_id", "")).is_empty(): return {}
	var line: Array = state.get("desk_line", [])
	var encounters: Array = state.get("encounters", [])
	if line.is_empty() or encounters.is_empty() or int(state.get("desk_at", -1)) < 0: return {}
	var last: Dictionary = encounters[-1]
	if last.get("node") != "revise_now" or last.get("revision_id") != line[0]: return {}
	return {"author": str(last.author), "pr_id": str(last.pr_id), "revision_id": str(last.revision_id),
		"lands_at": int(state.desk_at), "mood": str(last.mood), "cited": last.cited.duplicate()}

## How a PR opens: a fresh pitch, a return from the line, or a revision made at the
## desk. Revisions keep the mood of the beat that made them.
static func arrival(state: Dictionary, packet: Dictionary) -> Dictionary:
	var id := str(packet.get("id", ""))
	for beat: Dictionary in state.get("encounters", []):
		if beat.get("revision_id") == id:
			return {"node": "revised" if beat.node == "revise_now" else "return", "mood": str(beat.mood), "cited": beat.cited.duplicate()}
	var author := str(packet.get("author", ""))
	return {"node": "return" if int(packet.get("revision", 1)) > 1 else "pitch", "mood": mood(state, author), "cited": []}

# --- Words ------------------------------------------------------------------------

## One cited standard in plain words, never its ID.
static func noun(rule_id: String) -> String:
	if Policy.CITED_WORDS.has(rule_id): return str(Policy.CITED_WORDS[rule_id][0])
	for rule: Dictionary in Catalog.rules():
		if str(rule.id) == rule_id: return "the %s thing" % str(rule.title).to_lower()
	return "that one"

## The citation in play: one noun, or a count for several.
static func topic(cited: Array) -> String:
	var sorted := _sorted(cited)
	if sorted.size() == 1: return noun(str(sorted[0]))
	if sorted.size() == 2: return "both of those"
	if sorted.is_empty(): return "that"
	return "all %s of those" % (NUMBERS[sorted.size()] if sorted.size() < NUMBERS.size() else str(sorted.size()))

static func _capital(text: String) -> String:
	return text.left(1).to_upper() + text.substr(1)

## Fill a template. {topic}: the flagged or disputed citation (or a count);
## {topics}: everything cited; {fixes}: what the author claims to have done.
static func fill(template: String, cited: Array = [], focus: String = "") -> String:
	var one := noun(focus) if not focus.is_empty() else topic(cited)
	var all := Policy.cited_words(cited, 0)
	var fixes := Policy.cited_words(cited, 1)
	return template.replace("{Topic}", _capital(one)).replace("{topic}", one) \
		.replace("{Topics}", _capital(all)).replace("{topics}", all) \
		.replace("{Fixes}", _capital(fixes)).replace("{fixes}", fixes)

## A PR's own lines from content/pr_bank.gd (pitch, pushback, relief, grudge).
static func overrides(packet: Dictionary) -> Dictionary:
	if _overrides.is_empty():
		for entry: Dictionary in Bank.entries():
			var lines := {}
			for field: String in ["pitch", "pushback", "relief", "grudge"]:
				var text := str(entry.get(field, "")).strip_edges()
				if not text.is_empty(): lines[field] = text
			_overrides[str(entry.get("title", ""))] = lines
		if _overrides.is_empty(): _overrides[""] = {}
	return _overrides.get(str(packet.get("title", "")), {})

## Authored templates for a node, author, and mood. Neutral desk lines for the
## classic moments fall back to the original banter.
static func templates(channel: String, node: String, author: String, mood: String) -> Array:
	var authored: Array = Lines.lines(author, channel, node, mood)
	if not authored.is_empty(): return authored
	if channel == "desk" and mood == "neutral" and DESK_FALLBACK.has(node):
		return Banter.lines(author, str(DESK_FALLBACK[node]))
	return []

## Candidate bubble lines for a desk moment, already filled in.
static func desk_lines(packet: Dictionary, node: String, mood: String, cited: Array = [], focus: String = "") -> Array:
	var author := str(packet.get("author", ""))
	# This PR's own tree speaks first. Moments that can repeat in one visit keep
	# the author's templates behind it, so a second flag gets a fresh line.
	var tree_line := Trees.line(str(packet.get("title", "")), "desk", node, mood)
	if not tree_line.is_empty():
		var own_first: Array = [fill(tree_line, cited, focus)]
		if node in REPEATABLE:
			for template: Variant in templates("desk", node, author, mood):
				var filled := fill(str(template), cited, focus)
				if filled not in own_first: own_first.append(filled)
		return own_first
	var own: String = str(overrides(packet).get(str(DESK_OVERRIDES.get(node, "")), "")) if mood == "neutral" else ""
	if not own.is_empty(): return [fill(own, cited, focus)]
	var result: Array = []
	for template: Variant in templates("desk", node, author, mood): result.append(fill(str(template), cited, focus))
	return result

static func _pick(options: Array, key: String) -> String:
	return "" if options.is_empty() else str(options[Policy.roll(key) % options.size()])

# --- Slouch -----------------------------------------------------------------------

static func _chat():
	return load("res://content/policy_chat.gd")

## The author's Slouch message for one beat. Neutral reactions keep the original
## per-PR lines from policy_chat.gd; everything else comes from encounter_lines.gd.
static func dm_text(beat: Dictionary, packet: Dictionary, node: String = "") -> String:
	var kind := node if not node.is_empty() else str(beat.node)
	var author := str(beat.author)
	var mood := str(beat.mood)
	var id := str(beat.pr_id)
	var cited: Array = beat.get("cited", [])
	var tree_line := Trees.line(str(packet.get("title", "")), "dm", kind, mood)
	if not tree_line.is_empty(): return fill(tree_line, cited, str(beat.get("disputed", "")))
	if mood == "neutral":
		match kind:
			"thanks":
				var origin := str(packet.get("origin_id", id))
				var line := str(_chat().authored().get("requests", {}).get(origin, {}).get("approve", ""))
				if not line.is_empty(): return line
			"relief":
				return _chat().reaction(author, int(beat.version), "approve", [], id)
			"revise_later":
				return _chat().reaction(author, int(beat.version), "request_changes", cited, id)
			"escalate":
				if int(beat.version) >= Policy.MAX_REVISION: return _chat().reaction(author, int(beat.version), "request_changes", cited, id)
	var own: String = str(overrides(packet).get(str(DM_OVERRIDES.get(kind, "")), "")) if mood == "neutral" else ""
	if not own.is_empty(): return fill(own, cited, str(beat.get("disputed", "")))
	var options := templates("dm", kind, author, mood)
	return fill(_pick(options, id + "|dm|" + kind + "|" + mood), cited, str(beat.get("disputed", "")))

## Slouch messages for one PR's encounter, in order: [{node, text, kind, day, seconds, order}].
## The pushback itself happens at the desk; Slouch hears how it ended.
static func slouch(state: Dictionary, packet: Dictionary) -> Array:
	var result: Array = []
	var end := Catalog.shift_seconds()
	for beat: Dictionary in beats(state, str(packet.get("id", ""))):
		var node := str(beat.node)
		if node == "pushback": continue
		var order := int(beat.get("seq", 0)) * 2
		var seconds := int(beat.shift_seconds)
		if node == "revise_now":
			# "It's on your desk" waits until v2 actually is; at the bell it never was.
			seconds = Catalog.arrival(state, str(beat.get("revision_id", "")))
			if seconds < 0: continue
		result.append({"node": node, "text": dm_text(beat, packet), "kind": "reaction" if node in VERDICTS else "encounter",
			"day": int(beat.day), "seconds": seconds, "order": order})
		if node in TO_HELIOS:
			# The grudge lands a little later, or at the bell, never ahead of the clock.
			var later := mini(seconds + GRUDGE_DELAY, end)
			var arrived: bool = int(state.get("day", 1)) > int(beat.day) or state.get("phase") != "review" or int(state.get("shift_seconds", 0)) >= later
			if arrived:
				result.append({"node": "grudge", "text": dm_text(beat, packet, "grudge"), "kind": "grudge",
					"day": int(beat.day), "seconds": later, "order": order + 1})
	return result

## Morgan's notes about escalations and abandoned PRs: [{text, day, seconds, order, pr_id}].
static func morgan(state: Dictionary) -> Array:
	var result: Array = []
	for beat: Dictionary in state.get("encounters", []):
		var node := str(beat.node)
		if node not in TO_HELIOS: continue
		var packet := Catalog.packet(state, str(beat.pr_id), false)
		var origin := str(packet.get("origin_id", beat.pr_id))
		var author := str(beat.author)
		var mood := str(beat.mood)
		var text := ""
		if node == "escalate" and int(beat.version) >= Policy.MAX_REVISION:
			text = _chat().escalation(author, origin)
			var aside := _pick(Lines.morgan("cap", mood), str(beat.pr_id) + "|morgan|cap")
			if not aside.is_empty(): text += " " + aside
		else:
			text = _pick(Lines.morgan(node, mood), str(beat.pr_id) + "|morgan|" + node)
		text = text.replace("{author}", author).replace("{pr}", Catalog.display_id(str(beat.pr_id)) if node != "escalate" or int(beat.version) < Policy.MAX_REVISION else origin)
		result.append({"text": text, "day": int(beat.day), "seconds": int(beat.shift_seconds), "order": int(beat.get("seq", 0)) * 2 + 1, "pr_id": str(beat.pr_id)})
	return result

# --- Flow chart -----------------------------------------------------------------------

## The whole graph as data, for tools/encounter_flowchart.gd.
static func graph() -> Dictionary:
	return {"nodes": NODES.duplicate(true), "edges": EDGES.duplicate(true), "picks": PICKS.duplicate(true),
		"leans": LEANS.duplicate(true), "author_leans": AUTHOR_LEANS.duplicate(true), "pile_on": PILE_ON, "pile_lean": PILE_LEAN.duplicate(),
		"moods": MOODS.duplicate(), "floors": MOOD_FLOORS.duplicate(), "tone": TONE.duplicate(), "temperament": TEMPERAMENT.duplicate(true),
		"memory": MEMORY, "relationship": RELATIONSHIP.duplicate(), "revise_now_seconds": REVISE_NOW_SECONDS}

## Probability (0-100) of each branch of a pick for an author and mood, before leans.
static func odds(pick: String, author: String, mood: String) -> Dictionary:
	var options := weights(pick, author, mood)
	var total := 0
	for node: String in options: total += int(options[node])
	var result := {}
	for node: String in options: result[node] = 0 if total == 0 else roundi(100.0 * int(options[node]) / total)
	return result

## Every template for a node/author/mood on a channel ("desk" or "dm").
static func sample(channel: String, node: String, author: String, mood: String) -> Array:
	return templates(channel, node, author, mood)
