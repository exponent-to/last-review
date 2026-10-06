extends RefCounted
## Paperclip Labs payroll: the evening ledger. At the closing bell, Payroll pays
## the day rate and a fee per signed review, docks the reviews that went wrong,
## and takes the fixed costs of being employed here. The evening's choices then
## spend from what is left. Everything is in CR (Paperclip credits).
##
## Balance: a careful reviewer (three or four good signatures a day) clears about
## +4 to +12 CR a day and can afford dinner a few times a fortnight. Signing
## nothing loses 20 a day, which an idle run survives to the last Friday. Every
## bad call is docked on top, so a sloppy reviewer sinks; two closings in a row
## in the red bring collections and stress, and a balance at GARNISH_AT or below
## ends the run ("garnished").
##
## Pure and deterministic, so save replay rebuilds the same ledger. Does not
## import Simulation.

const CURRENCY := "CR"
const START := 60
const DAY_RATE := 20
## Per signed review, revisions included, right or wrong; the docks below are
## what makes a wrong one cost you.
const PER_REVIEW := 8
## An approved PR that failed its audit: the defect shipped with your name on it.
const SHIPPED_DEFECT := 30
## A change request that failed its audit: you sent back work without cause.
const WRONG_REJECTION := 20
## Helios's thanks for letting one of its payloads through. It never forgets.
const HELIOS_BONUS := 15
## Taken when Helios had to finish the day's unsigned work.
const SURCHARGE := 5
## Taken when the day started in the red.
const OVERDRAFT := 5
## The fixed costs of a day at Paperclip Labs, in ledger order.
const COSTS: Array = [
	{"label": "Rent, pod 4B (Helios-adjacent)", "amount": 25},
	{"label": "Badge lanyard lease", "amount": 3},
	{"label": "Coffee (surge pricing)", "amount": 7},
]
## The evening choices. Dinner with the team is the only one that costs anything.
const DINNER := 35
## Closings in a row in the red before collections start calling.
const DEBT_DAYS := 2
## Stress collections adds at each such closing.
const DEBT_STRESS := 8
## A closing balance at or below this is garnished: the run ends.
const GARNISH_AT := -200
## Per-PR docks beyond this many collapse into one line, so the ledger stays short.
const ITEMIZE := 2

## Today's ledger. `start` is the balance before the bell; `reviews` holds one
## {id, display, verdict, correct, payload} per signed review today, in order.
## Returns {start, lines, pay, expenses, end}; each line is {label, amount, kind}
## with kind "pay" (earned or docked) or "cost" (fixed costs).
static func ledger(start: int, reviews: Array, handed_off: int) -> Dictionary:
	var lines: Array = [{"label": "Day rate", "amount": DAY_RATE, "kind": "pay"}]
	if not reviews.is_empty():
		lines.append({"label": "Reviews signed ×%d" % reviews.size(), "amount": PER_REVIEW * reviews.size(), "kind": "pay"})
	var bonus: Array = []
	var shipped: Array = []
	var unfounded: Array = []
	for review: Dictionary in reviews:
		var payload := bool(review.get("payload", false))
		if bool(review.get("correct", false)): continue
		if review.verdict == "approve":
			if payload: bonus.append(str(review.display))
			else: shipped.append(str(review.display))
		else:
			unfounded.append(str(review.display))
	_itemize(lines, bonus, "Helios referral bonus", HELIOS_BONUS)
	_itemize(lines, shipped, "Shipped defect", -SHIPPED_DEFECT)
	_itemize(lines, unfounded, "Unfounded change request", -WRONG_REJECTION)
	if handed_off > 0:
		lines.append({"label": "Helios efficiency surcharge", "amount": -SURCHARGE, "kind": "pay"})
	if start < 0:
		lines.append({"label": "Overdraft fee", "amount": -OVERDRAFT, "kind": "pay"})
	for cost: Dictionary in COSTS:
		lines.append({"label": str(cost.label), "amount": -int(cost.amount), "kind": "cost"})
	var pay := 0
	var expenses := 0
	for line: Dictionary in lines:
		if line.kind == "pay": pay += int(line.amount)
		else: expenses -= int(line.amount)
	return {"start": start, "lines": lines, "pay": pay, "expenses": expenses, "end": start + pay - expenses}

## One line per PR, or one line for the lot once there are more than ITEMIZE.
static func _itemize(lines: Array, ids: Array, label: String, each: int) -> void:
	if ids.size() > ITEMIZE:
		lines.append({"label": "%s ×%d" % [label, ids.size()], "amount": each * ids.size(), "kind": "pay"})
		return
	for id: String in ids:
		lines.append({"label": "%s (%s)" % [label, id], "amount": each, "kind": "pay"})

## The fixed costs of one day, as a positive number.
static func fixed_costs() -> int:
	var total := 0
	for cost: Dictionary in COSTS: total += int(cost.amount)
	return total

## Whether the balance covers dinner with the team.
static func can_dine(balance: int) -> bool:
	return balance >= DINNER

## How many closings in a row, up to and including the latest, ended in the red.
static func debt_days(state: Dictionary) -> int:
	var count := 0
	var shifts: Array = state.get("shift_history", [])
	for index in range(shifts.size() - 1, -1, -1):
		if int(shifts[index].get("balance", 0)) >= 0: break
		count += 1
	return count

## Whether a closing balance gets garnished.
static func garnished(balance: int) -> bool:
	return balance <= GARNISH_AT

## "+40", "−20", "0": a ledger amount, with a real minus sign.
static func signed(amount: int) -> String:
	if amount > 0: return "+%d" % amount
	if amount < 0: return "−%d" % absi(amount)
	return "0"

## "65 CR", "−20 CR": a balance.
static func balance_text(amount: int) -> String:
	return "%s %s" % [("−%d" % absi(amount)) if amount < 0 else str(amount), CURRENCY]
