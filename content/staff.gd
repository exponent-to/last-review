extends RefCounted
## Who sits at each desk, and who Morgan lets go. Every PR the campaign assigns
## belongs to a SEAT, named for its author. When Morgan fires someone at closing,
## nobody replaces them: from the next morning Helios holds that seat, and its PRs
## never reach your desk. The seat list is read from the authored campaign rather
## than hard-coded, so firing stays correct whoever the cast's authors are.
##
## Firing rules (applied at closing by native/simulation.gd):
## - A coworker takes at most one STRIKE a day, for either of:
##   * a PR of theirs you approved failed its audit (their defect shipped, so they
##     take the blame; a Helios payload is never blamed on the person who carried it),
##   * you wrongly sent back two or more of their PRs that day (Morgan blames the
##     churn on them), or one, on a day that ends with you at rock bottom together.
## - Three strikes and Morgan lets them go that evening; Morgan warns at two.
## - If every original human seat has been let go, the run ends.
##
## Does not import Simulation.

const Catalog = preload("res://content/catalog.gd")
const STRIKES_TO_FIRE := 3
const WARN_AT := 2
## Two wrong change requests against the same person in one day is churn.
const CHURN := 2
## A closing relationship at or below this is rock bottom.
const ROCK_BOTTOM := 14

static var _seats: Array = []

## The seats the campaign assigns, in first-appearance order: the distinct authors
## of the authored originals.
static func seats() -> Array:
	if _seats.is_empty():
		for packet: Dictionary in Catalog.originals():
			var who := str(packet.get("author", ""))
			if not who.is_empty() and who not in _seats: _seats.append(who)
	return _seats.duplicate()

## Who sat in `seat` on `day`: its author, or "" once Helios has it. A firing on
## day D hands the seat to Helios from D + 1.
static func occupant(state: Dictionary, seat: String, day: int) -> String:
	for firing: Dictionary in state.get("firings", []):
		if str(firing.get("seat", "")) == seat and int(firing.get("day", 0)) < day: return ""
	return seat

## The people at their desks on `day`, in seat order (Helios's seats left out).
static func team(state: Dictionary, day: int) -> Array:
	var result: Array = []
	for seat: String in seats():
		var who := occupant(state, seat, day)
		if not who.is_empty() and who not in result: result.append(who)
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

## True once every original human seat has been let go.
static func whole_team_fired(state: Dictionary) -> bool:
	var any_seat := false
	for seat: String in seats():
		any_seat = true
		if not is_fired(state, seat): return false
	return any_seat
