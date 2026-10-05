extends RefCounted
## Who Morgan lets go, and who is left. The cast's roster and line-up live in
## content/policy_campaign.gd (ROSTER, LINEUP, `staff`, `slot_author`). A coworker
## Morgan fires counts as AWAY from the next morning on: `Policy.staff(day, away)`
## leaves them out of the team, so they skip dinner, the ending's reckoning, and
## any further strikes. Their PRs are not handed to whoever is left (that is what
## `slot_author` would do for someone merely away); nobody backfills a firing, so
## Helios takes their seat and their slots never reach your desk.
##
## Firing rules (applied at closing by native/simulation.gd):
## - A coworker takes at most one STRIKE a day, for either of:
##   * a PR of theirs you approved failed its audit (their defect shipped, so they
##     take the blame; a Helios payload is never blamed on the person who carried it),
##   * you wrongly sent back two or more of their PRs that day (Morgan blames the
##     churn on them), or one, on a day that ends with you at rock bottom together.
## - Three strikes and Morgan lets them go that evening; Morgan warns at two.
## - If everyone who has joined the team has been let go, the run ends.
##
## Does not import Simulation.

const Policy = preload("res://content/policy_campaign.gd")
const STRIKES_TO_FIRE := 3
const WARN_AT := 2
## Two wrong change requests against the same person in one day is churn.
const CHURN := 2
## A closing relationship at or below this is rock bottom.
const ROCK_BOTTOM := 14

## Everyone Morgan had let go before `day` began (fired at an earlier closing).
static func away(state: Dictionary, day: int) -> Array:
	var result: Array = []
	for firing: Dictionary in state.get("firings", []):
		if int(firing.get("day", 0)) < day: result.append(str(firing.name))
	return result

## Who held an author's seat on `day`: the author, or "" once Helios has it. A
## firing on day D hands the seat to Helios from D + 1.
static func occupant(state: Dictionary, author: String, day: int) -> String:
	return "" if author in away(state, day) else author

## The people at their desks on `day`: joined by then, and not let go.
static func team(state: Dictionary, day: int) -> Array:
	return Policy.staff(day, away(state, day))

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

## True once everyone who has joined the team by the current day has been let go.
static func whole_team_fired(state: Dictionary) -> bool:
	var joined: Array = Policy.staff(int(state.get("day", 1)))
	if joined.is_empty(): return false
	for person: String in joined:
		if not is_fired(state, person): return false
	return true
