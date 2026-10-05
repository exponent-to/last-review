extends RefCounted
## Who sits at each desk, and who Morgan lets go. Every PR the campaign assigns
## belongs to a SEAT, named for its author. When Morgan fires someone at closing,
## their seat is reassigned the next morning: to a replacement hire if one is
## free, otherwise to Helios (its PRs never reach the desk). June, a growth PM
## who ships Helios's payloads, is the replacement this module owns; other regular
## authors (and their own hiring) belong to the cast author list, which this
## module reads rather than hard-codes, so firing stays correct whoever authors.
##
## Firing rules (applied at closing by native/simulation.gd):
## - A coworker takes at most one STRIKE a day, for any of:
##   * a PR of theirs you approved failed its audit (their defect shipped, so they
##     take the blame; code Helios wrote is never blamed on a person),
##   * you wrongly sent back two or more of their PRs that day (Morgan blames the
##     churn on them),
##   * they ended the day at rock bottom with you (nothing but friction all day).
## - Three strikes and Morgan lets them go that evening; Morgan warns at two.
## - If every original human seat has been let go, the run ends.
##
## Does not import Simulation.

const Catalog = preload("res://content/catalog.gd")
## The replacement hire this module owns: a growth PM who ships Helios's payloads.
const HIRES: Array[String] = ["June"]
## June will not refuse a payload; an ally seat (e.g. Gwen's) would. Listed by the
## cast; kept here so payload routing can ask without importing the author list.
const REFUSES_PAYLOADS: Array[String] = ["Gwen"]
const STRIKES_TO_FIRE := 3
const WARN_AT := 2
## Two wrong change requests against the same person in one day is churn.
const CHURN := 2
## A closing relationship at or below this is rock bottom.
const ROCK_BOTTOM := 14
## Who the hires are, for Morgan's introductions and the endings.
const ROLES := {
	"Penny": "eager new junior engineer",
	"Gwen": "paranoid security engineer",
	"June": "smooth growth PM who writes code now",
}

static var _seats: Array = []

## The seats the campaign assigns, in first-appearance order: the distinct authors
## of the authored originals. Read from content, never hard-coded, so a data-driven
## author list (or new regular authors) flows through firing unchanged.
static func seats() -> Array:
	if _seats.is_empty():
		for packet: Dictionary in Catalog.originals():
			var who := str(packet.get("author", ""))
			if not who.is_empty() and who not in _seats: _seats.append(who)
	return _seats.duplicate()

## Who sat in `seat` on `day`. A firing on day D hands the seat over from D + 1.
## "" means the seat belongs to Helios (its PRs never reach the desk).
static func occupant(state: Dictionary, seat: String, day: int) -> String:
	var who := seat
	for firing: Dictionary in state.get("firings", []):
		if str(firing.get("seat", "")) == seat and int(firing.get("day", 0)) < day:
			who = str(firing.get("hire", ""))
	return who

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

## Everyone ever hired into a seat, in order.
static func hired(state: Dictionary) -> Array:
	var result: Array = []
	for firing: Dictionary in state.get("firings", []):
		if not str(firing.get("hire", "")).is_empty(): result.append(str(firing.hire))
	return result

## Who Morgan brings in for a freed seat: the next hire this module owns who is not
## already at a desk, or "" (the seat goes to Helios).
static func next_hire(state: Dictionary) -> String:
	var taken := hired(state)
	for person: String in HIRES:
		if person not in taken and not is_fired(state, person): return person
	return ""

## True once every original human seat has been let go.
static func whole_team_fired(state: Dictionary) -> bool:
	var any_seat := false
	for seat: String in seats():
		any_seat = true
		if not is_fired(state, seat): return false
	return any_seat
