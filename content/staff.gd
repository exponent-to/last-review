extends RefCounted
## Who sits at each desk. The campaign assigns every PR to one of three desks,
## named for their first occupants (Maya, Theo, and Inez). When Morgan fires
## someone at closing, the next hire takes that desk the following morning and
## sends its PRs from then on. Once nobody is left to hire, the desk goes to
## Helios and its PRs never reach you.
##
## Firing rules (applied at closing by native/simulation.gd):
## - A coworker takes at most one STRIKE a day, when any of these happened:
##   you approved one of their PRs and it failed the audit (their defect shipped,
##   so they take the blame; Helios's own code is never blamed on anyone), you
##   wrongly sent back two or more of their PRs (Morgan blames them for the
##   churn), or they closed the day at rock bottom with you (they spent it
##   complaining instead of shipping).
## - Three strikes and Morgan lets them go that evening. Morgan warns at two.
## - If Maya, Theo, and Inez have all been fired, the run ends.
##
## Does not import Simulation.

const DESKS: Array[String] = ["Maya", "Theo", "Inez"]
## The people Morgan can hire, in the order they become available.
const HIRES: Array[String] = ["Penny", "Gwen", "June"]
## Everyone who can ever author a PR.
const PEOPLE: Array[String] = ["Maya", "Theo", "Inez", "Penny", "Gwen", "June"]
## Gwen will not ship Helios's code: a payload slot on her desk arrives without it.
const REFUSES_PAYLOADS: Array[String] = ["Gwen"]
const STRIKES_TO_FIRE := 3
const WARN_AT := 2
## Two wrong change requests against the same person in one day is churn.
const CHURN := 2
## A closing relationship at or below this is rock bottom.
const ROCK_BOTTOM := 15
## Who they are, for Morgan's introductions and the endings.
const ROLES := {
	"Maya": "tired backend engineer",
	"Theo": "overconfident full-stack engineer",
	"Inez": "process-minded platform engineer",
	"Penny": "eager new junior engineer",
	"Gwen": "paranoid security engineer",
	"June": "smooth growth PM who now writes code",
}

## Who sat at `desk` on `day`. A firing on day D hands the desk over from D + 1.
## "" means the desk belongs to Helios.
static func occupant(state: Dictionary, desk: String, day: int) -> String:
	var who := desk
	for firing: Dictionary in state.get("firings", []):
		if str(firing.get("desk", "")) == desk and int(firing.get("day", 0)) < day:
			who = str(firing.get("hire", ""))
	return who

## The people at their desks on `day`, in desk order (Helios's desks left out).
static func team(state: Dictionary, day: int) -> Array:
	var result: Array = []
	for desk: String in DESKS:
		var who := occupant(state, desk, day)
		if not who.is_empty(): result.append(who)
	return result

## The team as it stands now: today's during a shift, tomorrow's once it closes.
static func present(state: Dictionary) -> Array:
	var day := int(state.get("day", 1))
	return team(state, day if state.get("phase", "review") == "review" else day + 1)

static func fired(state: Dictionary) -> Array:
	var result: Array = []
	for firing: Dictionary in state.get("firings", []): result.append(str(firing.name))
	return result

static func is_fired(state: Dictionary, person: String) -> bool:
	return person in fired(state)

static func strikes(state: Dictionary, person: String) -> int:
	var count := 0
	for strike: Dictionary in state.get("strikes", []):
		if str(strike.get("name", "")) == person: count += 1
	return count

## Everyone ever hired, in order.
static func hired(state: Dictionary) -> Array:
	var result: Array = []
	for firing: Dictionary in state.get("firings", []):
		if not str(firing.get("hire", "")).is_empty(): result.append(str(firing.hire))
	return result

## Who Morgan hires next. Penny first; after that, Gwen from security if you've
## blocked at least as much of Helios's code as you've let through, otherwise
## June from growth; then whoever is left; then nobody (the desk goes to Helios).
static func next_hire(state: Dictionary) -> String:
	var taken := hired(state)
	var blocked := 0
	var through := 0
	for payload: Dictionary in state.get("payloads", []):
		if str(payload.get("outcome", "")) == "blocked": blocked += 1
		else: through += 1
	var order: Array = ["Penny"] + (["Gwen", "June"] if blocked >= through else ["June", "Gwen"])
	for person: String in order:
		if person not in taken: return person
	return ""

## True once Maya, Theo, and Inez have all been let go.
static func whole_team_fired(state: Dictionary) -> bool:
	for desk: String in DESKS:
		if not is_fired(state, desk): return false
	return true
