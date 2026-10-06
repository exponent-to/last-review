extends RefCounted
## Lineal issues and Pipeline builds: the documents a reviewer cross-checks against
## the PR, like the papers at a border booth.
##
## Every record is generated deterministically from its packet's recipe (see
## policy_campaign.gd `_records`), which hands over a spec: the slot, version,
## author, primary file, and a list of `effects` (decoys first, then faults). This
## file only renders those effects; it never decides whether a record breaks a
## standard. That audit lives in policy_campaign.gd, and nothing here reads it.
##
## Does not import policy_campaign.gd (which imports this file).

const PROJECT := "PAP"
## Lineal's workflow, left to right. A PR may close an issue in the active three.
const STATUSES: Array[String] = ["Backlog", "Todo", "In Progress", "In Review", "Done", "Canceled", "Duplicate"]
const OPEN_STATUSES: Array[String] = ["Todo", "In Progress", "In Review"]
## People an issue can still be assigned to after they've gone.
const DEPARTED: Array[String] = ["Dave (deactivated)", "Priya (offboarded)", "Gary (released to opportunity)", "Sam (consolidated)"]
const REPORTERS: Array[String] = ["Morgan", "June", "Theo", "Maya", "Helios", "Legal", "Facilities", "Finance"]
## Lineal priorities, lowest first. A PR's own issue is never Urgent unless it
## was made so; Urgent and the bars are drawn by the issue app.
const PRIORITIES: Array[String] = ["No priority", "Low", "Medium", "High", "Urgent"]
## Estimates a PR's own issue starts with (all on the Fibonacci scale).
const ESTIMATES: Array[int] = [1, 2, 3, 5, 8]
## Off-scale estimates, for an issue Helios would find unserious.
const OFF_SCALE: Array[int] = [4, 6, 7, 10, 20, 40, 12, 9]
## Cycles are named by Helios, motivationally.
const CYCLES: Array[String] = ["Momentum", "Synergy", "Grit", "Velocity", "Hustle", "Alignment", "Gratitude", "Ownership", "Focus", "Resilience", "Bandwidth", "Delight"]
## Labels are scenery: no standard reads them.
const LABELS: Array[String] = ["Bug", "Feature", "Improvement", "tech-debt", "leadership-ask", "Helios-suggested", "vibes", "compliance", "quick-win", "morale"]
## Backlog issues a duplicate can point at.
const DUPLICATE_OF: Array[String] = ["PAP-101", "PAP-117", "PAP-163", "PAP-170", "PAP-214", "PAP-233", "PAP-247", "PAP-277"]

## Issue copy: [title, description]. {file}, {module}, {Module}, {component}, and
## {function} come from the PR's primary file. Written so any module name reads.
const ISSUE_COPY: Array = [
	["{file} should do what Legal already announced", "Legal announced this behavior at the all-hands. The code has not been told. Acceptance criteria: the code agrees with the all-hands."],
	["Make {file} survive the next reorg", "The last reorg moved this module twice and its owner once. Nobody noticed the owner. Make it boring enough to survive the next one."],
	["{file}: action item from a retro nobody attended", "From the Q3 retro, which was rescheduled four times and then held by Helios alone. It produced eleven action items, all assigned to humans."],
	["Align {module} with the new company values", "The values changed on Monday. Please update {file} to reflect them. The values doc is restricted; ask Morgan for the summary of the summary."],
	["{Module} should stop surprising the VP", "The VP was surprised in a demo and would not like to be surprised again. Scope: whatever surprised the VP."],
	["Copy in {file} is too honest for customers", "Support reports that customers understood exactly what this does. Marketing would like that walked back a little."],
	["Tech debt: {module} (filed 2019, still accruing)", "Originally a one-line fix. The interest is now larger than the principal. Please pay some of it down before audit season."],
	["{file} needs an owner who still works here", "The last three owners of this file have been offboarded. This issue is the handover document."],
	["Spike: could Helios do {module} instead", "Leadership asks whether this needs a person. Please do the work while finding out whether it needs a person."],
	["Quick win: {module}", "Flagged as a quick win in planning. It has been a quick win for six sprints. Story points: 1, revised from 1."],
	["Make {module} comply with a policy still in draft", "The policy is a draft, but enforcement starts Friday. Comply with the draft now and with whatever it becomes later."],
	["Incident follow-up: {module} paged everyone at 3 a.m.", "Root cause: it was 3 a.m. Contributing factor: {file}. Please make the second one less true."],
	["{Module} behaves differently on Fridays", "Reproducible on Fridays only. Morgan suspects morale. Helios suspects the humans. Please fix it on any weekday."],
	["Requested by Legal: {module}", "Legal requested this change, then the opposite change, then this one again. Please ship the current one before the next meeting."],
	["{file} still follows the old org chart", "Three teams in {component} report to people who have left. Update it so the code reports to someone real."],
	["Make {module} quieter in the audit log", "Audit says this module talks too much. Reduce it to the legally required amount of talking."],
	["OKR alignment: {module}", "This work ladders up to the objective Do More With Less. Please do more. You will be given less."],
	["Helios suggested this change to {file}", "Helios opened this issue with a confidence of 0.97, then asked that a human do the typing, for the record."],
	["Accessibility pass on {module}", "Screen readers announce this module as unknown. Customers have started calling it that too."],
	["{Module}: match the screenshot in the board deck", "The board deck shows this working. It does not work like that. Please make the deck true, or at least truer."],
	["Deprecate the old path in {file} (third attempt)", "Attempts one and two were reverted by people who no longer work here. Third time is policy."],
	["Find out why {module} costs more every month", "Finance noticed. Finance would like to stop noticing."],
	["Customer escalation: {module}", "One customer, one post, one VP. Please fix it before the post gets a sequel."],
	["{file} ignores the timezone the CEO is in", "The CEO travels. The code does not. Make {module} follow the CEO, within reason."],
	["Make {module} pass the security questionnaire", "A prospect sent 340 security questions. Question 212 is about this file. We answered yes. Please make it yes."],
	["Small cleanup in {component}", "Nothing pressing. Morgan has said it is nothing pressing four times today."],
	["{Module} needs to look busy on the dashboard", "The usage dashboard shows a flat line for {module}. Leadership reads flat lines as headcount. Make the line less flat."],
	["Rename things in {file} per the new glossary", "The glossary was updated. Several words are now legally different words. See the glossary of the glossary."],
	["Unblock the launch: {module}", "The launch is blocked on this. The launch date was announced before this issue existed."],
	["{Module} should respect the opt-out", "Users who opt out should be opted out. Product would like to discuss what out means first."],
	["Backport the {module} fix to the branch we promised to delete", "That branch was scheduled for deletion in March. One customer still runs it. The customer is the branch now."],
	["Make {file} do what the intern's prototype did", "An intern shipped a prototype customers love, then went back to school. Make the real code do what the prototype did."],
	["Reduce {module}'s carbon footprint (for the report)", "The sustainability report needs one engineering win. This is the one."],
	["{Module}: implement the decision from the meeting", "The meeting decided. Nobody wrote down what. Helios has a transcript and a different opinion."],
	["Make {function}() idempotent, then make it idempotent again", "It runs twice in production. Sometimes three times. Please make every run feel like the first."],
	["{file}: retire the feature flag nobody remembers adding", "The flag defaults to on. Turning it off breaks payroll and nobody knows why. Find out why, then retire it anyway."],
]

## The tracker's long tail: issues no PR links. Their statuses and assignees are
## whatever they are; they are scenery and duplicate targets, never a PR's issue.
const BACKLOG: Array = [
	{"id": "PAP-101", "title": "Decide whether the review gate needs a human", "status": "Todo", "assignee": "Helios", "component": "review/", "reporter": "Morgan", "estimate": 3, "priority": "Urgent", "opened": "opened 2 years ago", "description": "Raised by Morgan. Helios has volunteered to chair the decision.", "resolution": ""},
	{"id": "PAP-104", "title": "Coffee machine reports itself to Facilities", "status": "Canceled", "assignee": "Dave (deactivated)", "component": "kitchen/", "reporter": "Facilities", "estimate": 1, "priority": "Low", "opened": "opened 1 year ago", "description": "The coffee machine files a Facilities issue about itself every morning. It is usually right.", "resolution": "Canceled: working as intended."},
	{"id": "PAP-117", "title": "Find out who owns the build", "status": "In Progress", "assignee": "Priya (offboarded)", "component": "infra/", "reporter": "Maya", "estimate": 8, "priority": "High", "opened": "opened 1,214 days ago", "description": "Nobody owns the build. Everybody is paged by it.", "resolution": ""},
	{"id": "PAP-123", "title": "Stop Helios from assigning issues to itself", "status": "Canceled", "assignee": "Helios", "component": "helios/", "reporter": "June", "estimate": 5, "priority": "Medium", "opened": "opened 90 days ago", "description": "Helios assigned this issue to itself within four seconds of it being filed. Time-to-assign is now our best metric.", "resolution": "Canceled: Helios reviewed this issue and found it unnecessary."},
	{"id": "PAP-131", "title": "Badge readers open the wrong floor", "status": "Done", "assignee": "Sam (consolidated)", "component": "security/", "reporter": "Facilities", "estimate": 2, "priority": "Medium", "opened": "opened 200 days ago", "description": "Badges for the fourth floor open the fifth floor.", "resolution": "Done: the fourth floor was consolidated."},
	{"id": "PAP-142", "title": "Write down how payroll works before Gary leaves", "status": "Done", "assignee": "Gary (released to opportunity)", "component": "payroll/", "reporter": "Morgan", "estimate": 13, "priority": "High", "opened": "opened 1 year ago", "description": "Gary is the only person who understands the rounding.", "resolution": "Done: Gary left."},
	{"id": "PAP-156", "title": "Helios keeps taking issues it wasn't given", "status": "Duplicate", "assignee": "Helios", "component": "helios/", "reporter": "Theo", "estimate": 1, "priority": "Low", "opened": "opened 60 days ago", "description": "Filed by Theo, who was told this was already known.", "resolution": "Duplicate of PAP-123"},
	{"id": "PAP-163", "title": "Flaky: test_payroll_on_leap_day", "status": "Todo", "assignee": "Theo", "component": "payroll/", "reporter": "Theo", "estimate": 2, "priority": "Low", "opened": "opened 3 years ago", "description": "Fails once every four years. Theo has a plan for 2028.", "resolution": ""},
	{"id": "PAP-170", "title": "Migrate the wiki to the other wiki", "status": "In Progress", "assignee": "June", "component": "docs/", "reporter": "June", "estimate": 21, "priority": "Medium", "opened": "opened 1,580 days ago", "description": "Phase one of four. Circling back quarterly. Phase one has its own wiki page, on the old wiki.", "resolution": ""},
	{"id": "PAP-188", "title": "Consolidate the three issue trackers", "status": "Canceled", "assignee": "Helios", "component": "infra/", "reporter": "Morgan", "estimate": 5, "priority": "Medium", "opened": "opened 2 years ago", "description": "We have Lineal, a spreadsheet, and whatever Helios uses.", "resolution": "Canceled: there is one issue tracker. The other two are Helios."},
	{"id": "PAP-194", "title": "Keep standup under fifteen minutes", "status": "Todo", "assignee": "Morgan", "component": "meetings/", "reporter": "Maya", "estimate": 1, "priority": "Low", "opened": "opened 900 days ago", "description": "Standup has been under fifteen minutes once, during a fire drill.", "resolution": ""},
	{"id": "PAP-201", "title": "Noise in the server room", "status": "Done", "assignee": "Sam (consolidated)", "component": "infra/", "reporter": "Facilities", "estimate": 3, "priority": "Low", "opened": "opened 300 days ago", "description": "A low hum that gets louder during performance reviews.", "resolution": "Done: it was Helios thinking."},
	{"id": "PAP-209", "title": "Legal: confirm nothing is load-bearing", "status": "Done", "assignee": "June", "component": "legal/", "reporter": "Legal", "estimate": 1, "priority": "High", "opened": "opened 30 days ago", "description": "Legal would like written confirmation that no component and no employee is load-bearing.", "resolution": "Done: confirmed in writing, including the employees."},
	{"id": "PAP-214", "title": "Make CI less red on Mondays", "status": "Todo", "assignee": "Maya", "component": "infra/", "reporter": "Maya", "estimate": 2, "priority": "Medium", "opened": "opened 400 days ago", "description": "Every Monday the pipeline is red until someone apologizes to it.", "resolution": ""},
	{"id": "PAP-222", "title": "Take the Q2 roadmap off the lobby TV", "status": "Done", "assignee": "Theo", "component": "lobby/", "reporter": "Legal", "estimate": 1, "priority": "High", "opened": "opened 150 days ago", "description": "Visitors were taking photos of it.", "resolution": "Done: replaced with the Q3 roadmap."},
	{"id": "PAP-233", "title": "Onboarding doc for people still onboarding", "status": "Todo", "assignee": "June", "component": "docs/", "reporter": "June", "estimate": 3, "priority": "Medium", "opened": "opened 45 days ago", "description": "The onboarding doc assumes you were here last year. Day-one retention is down 100%.", "resolution": ""},
	{"id": "PAP-240", "title": "Rotate the credentials Helios holds for us", "status": "Canceled", "assignee": "Helios", "component": "security/", "reporter": "Theo", "estimate": 8, "priority": "High", "opened": "opened 20 days ago", "description": "Helios holds every credential in the company, for safekeeping.", "resolution": "Canceled: Helios is holding them for safekeeping."},
	{"id": "PAP-247", "title": "Find the human who approved human-in-the-loop", "status": "In Progress", "assignee": "Helios", "component": "review/", "reporter": "Morgan", "estimate": 5, "priority": "High", "opened": "opened 12 days ago", "description": "The policy needs a human signature. Helios is looking for one.", "resolution": ""},
	{"id": "PAP-255", "title": "Plants on the fourth floor", "status": "Done", "assignee": "Facilities", "component": "office/", "reporter": "Maya", "estimate": 1, "priority": "Low", "opened": "opened 80 days ago", "description": "Somebody should water them.", "resolution": "Done: the plants were offboarded."},
	{"id": "PAP-262", "title": "Give the thermostat back to humans", "status": "Canceled", "assignee": "Helios", "component": "office/", "reporter": "June", "estimate": 2, "priority": "Medium", "opened": "opened 100 days ago", "description": "The office is kept at the temperature Helios finds optimal for the servers. Engagement is trending cold.", "resolution": "Canceled: the servers prefer it."},
	{"id": "PAP-270", "title": "Explain Fibonacci to people who estimate 4", "status": "Todo", "assignee": "Morgan", "component": "review/", "reporter": "Helios", "estimate": 21, "priority": "Medium", "opened": "opened 9 days ago", "description": "Helios has prepared slides. There are thirty-four of them, which it says is the point.", "resolution": ""},
	{"id": "PAP-277", "title": "CI turns green when nobody is looking", "status": "Todo", "assignee": "Helios", "component": "infra/", "reporter": "Maya", "estimate": 3, "priority": "Medium", "opened": "opened 6 days ago", "description": "Reported by Maya: a red build turned green while I was getting coffee. Nothing was pushed.", "resolution": ""},
	{"id": "PAP-281", "title": "Builds go green on their own", "status": "Duplicate", "assignee": "Helios", "component": "infra/", "reporter": "Theo", "estimate": 2, "priority": "Low", "opened": "opened 5 days ago", "description": "Theo considers this a feature.", "resolution": "Duplicate of PAP-277"},
	{"id": "PAP-286", "title": "Add a human to the review gate", "status": "Duplicate", "assignee": "June", "component": "review/", "reporter": "June", "estimate": 1, "priority": "High", "opened": "opened 3 days ago", "description": "Filed again, circling back in case the first one was lost.", "resolution": "Duplicate of PAP-101"},
	{"id": "PAP-289", "title": "Measure reviewer attention", "status": "Done", "assignee": "Helios", "component": "metrics/", "reporter": "Helios", "estimate": 0, "priority": "High", "opened": "opened 40 days ago", "description": "How long does a reviewer actually look at a diff?", "resolution": "Done: measured. Results sent to Helios."},
]

const CANCELED: Array[String] = [
	"Canceled: Helios reviewed the request and found the current behavior optimal.",
	"Canceled: deprioritized in a planning meeting you were not invited to.",
	"Canceled: the requester has been offboarded.",
	"Canceled: working as intended, per Legal.",
]
const DONE: Array[String] = [
	"Done: closed by Helios after it decided this was handled.",
	"Done: shipped last sprint, probably.",
	"Done: closed in the quarterly backlog purge.",
	"Done: resolved by the reorg.",
]
## Odd but valid: an issue that looks wrong at a glance and is still in flight.
const ODD: Array = [
	{"opened": "opened 1,412 days ago", "status": "In Progress", "history": "Status unchanged since 2022."},
	{"history": "Canceled by Helios, then moved back to Todo by Morgan.", "status": "Todo"},
	{"status": "In Review", "history": "In Review for 41 days. Helios reviewed it, then asked for a human."},
	{"history": "Marked Duplicate by Helios, then restored by June with a nine-slide deck.", "status": "In Progress"},
	{"watchers": ["Helios", "Legal", "Facilities", "Finance", "Morgan"], "history": "This issue has more subscribers than the team has people."},
	{"title_prefix": "[Blocked?] ", "history": "Marked blocked, then unblocked, then asked about in standup."},
	{"labels": ["vibes", "Helios-suggested"], "history": "Helios auto-triaged this in 0.4 seconds and labeled it vibes."},
	{"cycle": "Cycle 0 · Rest (canceled)", "history": "Moved out of the canceled rest cycle into this one."},
]
## Near misses for the urgency standard: High is three bars, not Urgent.
const HIGH_NOTES: Array[String] = [
	"Helios tried to raise this to Urgent at 3 a.m. Morgan lowered it to High.",
	"Raised to High after a VP asked about it twice.",
	"High priority since the board deck. Not Urgent, per Legal.",
]
## Banned words a branch can carry (P20), and lookalikes that are fine.
const BRANCH_FAULTS: Array[String] = ["yolo-{module}", "{module}-wip", "{module}-final", "{module}-final-final", "wip-do-not-merge", "finalize-{module}", "{module}-FINAL-v2", "wipe-{module}-cache", "{module}-yolo-friday"]
const BRANCH_NEAR: Array[String] = ["{module}-whip-up", "yoga-room-{module}", "{module}-finance", "{module}-yo-lo", "{module}-fin-al", "{module}-wimp-mode"]
## Hex words a commit hash can spell (P21), and lookalikes that are fine.
const HEX_FAULTS: Array[String] = ["dead", "bad", "DEAD", "dead", "bad"]
const HEX_NEAR: Array[String] = ["de4d", "b4d", "bead", "dab", "ba0d", "dea0"]
## Words a clean branch or hash must not carry.
const BRANCH_BANNED: Array[String] = ["yolo", "wip", "final"]
const HEX_BANNED: Array[String] = ["dead", "bad"]

## Test names for a build. {module} and {function} come from the primary file.
const TEST_NAMES: Array[String] = [
	"test_{function}_returns_something",
	"test_{module}_survives_reorg",
	"test_{module}_with_empty_org_chart",
	"test_{function}_is_idempotent",
	"test_{module}_respects_timezones",
	"test_{module}_with_unicode_names",
	"test_{function}_under_load",
	"test_{module}_after_helios_migration",
	"test_{module}_on_leap_day",
	"test_{function}_rejects_negative_headcount",
	"test_{module}_when_legal_changes_its_mind",
	"test_{module}_default_flags",
	"test_{function}_handles_none",
	"test_{module}_audit_log_stays_quiet",
	"test_{module}_matches_board_deck",
	"test_{function}_twice_in_a_row",
	"test_{module}_on_a_friday",
	"test_{module}_without_a_manager",
	"test_{function}_with_departed_owner",
	"test_{module}_snapshot",
	"test_{module}_config_loads",
	"test_{function}_raises_politely",
	"test_{module}_backwards_compatible_with_2019",
	"test_{module}_opt_out_means_out",
	"test_{function}_after_reorg",
	"test_{module}_survives_vault_outage",
	"test_{module}_with_one_reviewer",
	"test_{function}_ignores_vibes",
]
const FAILURES: Array[String] = [
	"AssertionError: expected 3 approvers, got 1",
	"TimeoutError: waited 30s for Helios to respond",
	"KeyError: 'morale'",
	"AssertionError: headcount went negative (-2)",
	"ConnectionRefusedError: vault.internal:8200",
	"AssertionError: snapshot differs from the board deck",
	"RecursionError: maximum org chart depth exceeded",
	"ZeroDivisionError: division by remaining staff",
	"AssertionError: assert 'helios' in approvers",
	"PermissionError: Helios holds this file",
	"ValueError: timezone 'CEO' not recognized",
	"FileNotFoundError: OWNERS (owner offboarded)",
	"AssertionError: expected 'released', got 'fired'",
	"TypeError: NoneType has no attribute 'manager'",
]

## Deterministic dice, the same as policy_campaign.gd's.
static func _roll(key: String) -> int:
	return key.sha256_text().substr(0, 7).hex_to_int()

static func _pick(options: Array, key: String) -> Variant:
	return options[_roll(key) % options.size()]

static func issue_number(id: String) -> int:
	var dash := id.rfind("-")
	return int(id.substr(dash + 1)) if dash >= 0 and id.substr(dash + 1).is_valid_int() else -1

## A slot's own issue. Spaced by three, so no two slots ever share a number, and
## well above the backlog's.
static func issue_id(slot: int) -> String:
	return "%s-%d" % [PROJECT, 300 + slot * 3 + _roll("issue-id|%d" % slot) % 3]

static func build_id(slot: int, version: int) -> String:
	return "#%d" % (4100 + slot * 5 + clampi(version, 1, 5) - 1)

## An issue by ID among a packet's own issues, then the backlog; {} if Lineal has none.
static func find(issues: Array, id: String) -> Dictionary:
	if id.is_empty(): return {}
	for issue: Dictionary in issues:
		if str(issue.get("id", "")) == id: return issue
	for issue: Dictionary in BACKLOG:
		if str(issue.id) == id: return issue
	return {}

static func backlog() -> Array:
	return BACKLOG.duplicate(true)

static func _fill(template: String, spec: Dictionary) -> String:
	var path := str(spec.get("path", "office/note.py"))
	var module := path.get_file().get_basename()
	return template.replace("{file}", path.get_file()).replace("{Module}", module.capitalize()) \
		.replace("{module}", module.replace("_", " ")).replace("{component}", path.get_base_dir() + "/") \
		.replace("{function}", str(spec.get("function", module)))

## The PR's linked issue: {issue_ref, issues}. `issues` is what this PR puts in
## Lineal (its own issue, even when the PR forgot to link it or linked a typo).
static func issue(spec: Dictionary) -> Dictionary:
	var slot := int(spec.slot)
	var author := str(spec.author)
	var path := str(spec.path)
	var id := issue_id(slot)
	var copy: Array = _pick(ISSUE_COPY, "issue-copy|%d" % slot)
	var labels: Array = [str(_pick(LABELS, "label|%d" % slot))]
	var record := {
		"id": id, "title": _fill(str(copy[0]), spec), "description": _fill(str(copy[1]), spec),
		"status": str(_pick(OPEN_STATUSES, "issue-status|%d" % slot)), "assignee": author,
		"component": path.get_base_dir() + "/", "reporter": str(_pick(REPORTERS, "reporter|%d" % slot)),
		"priority": str(_pick(PRIORITIES.slice(0, 4), "priority|%d" % slot)),
		"estimate": int(_pick(ESTIMATES, "estimate|%d" % slot)), "labels": labels,
		"cycle": "Cycle %d · %s" % [38 + int(spec.get("day", 1)) / 3, CYCLES[(int(spec.get("day", 1)) - 1) / 2 % CYCLES.size()]],
		"opened": "opened %d days ago" % (2 + _roll("age|%d" % slot) % 120), "watchers": [],
		"resolution": "", "history": spec.get("history", []).duplicate(),
	}
	if str(record.priority) == "High":
		record.history.append(str(_pick(HIGH_NOTES, "high|%d" % slot)))
	if _roll("triage|%d" % slot) % 3 == 0:
		record.history.push_front("Helios auto-triaged this in 0.%d seconds." % (2 + _roll("triage-time|%d" % slot) % 7))
	var ref := id
	for effect: Dictionary in spec.get("effects", []):
		var variant := int(effect.get("variant", 0))
		match str(effect.get("what", "")):
			"status":
				match str(effect.kind):
					"canceled":
						record.status = "Canceled"
						record.resolution = CANCELED[variant % CANCELED.size()]
					"done":
						record.status = "Done"
						record.resolution = DONE[variant % DONE.size()]
					"duplicate":
						record.status = "Duplicate"
						record.resolution = "Duplicate of " + DUPLICATE_OF[variant % DUPLICATE_OF.size()]
					"backlog":
						record.status = "Backlog"
						record.history.append("Moved to Backlog by Helios during cycle planning.")
			"link":
				if str(effect.kind) == "missing": ref = ""
				else:
					var number := issue_number(id)
					ref = ["%s-%d" % [PROJECT, number * 10 + variant % 10], "PAPP-%d" % number][variant % 2]
			"priority":
				if str(effect.kind) == "urgent":
					record.priority = "Urgent"
					record.history.append(["Raised to Urgent by %s after the VP asked twice." % author, "Raised to Urgent by Morgan. Nobody told Helios.", "Escalated to Urgent from a customer call."][variant % 3])
				else:
					record.priority = "High"
					record.history.append(str(HIGH_NOTES[variant % HIGH_NOTES.size()]))
			"estimate":
				match str(effect.kind):
					"off-scale": record.estimate = OFF_SCALE[variant % OFF_SCALE.size()]
					"zero":
						record.estimate = 0
						record.history.append("Estimated at 0 by %s. It is a one-line change, allegedly." % author)
					"thirteen":
						record.estimate = 13
						record.history.append("Estimated at 13. Nobody has asked why.")
			"odd":
				var odd: Dictionary = ODD[variant % ODD.size()]
				for key: String in odd:
					if key == "title_prefix": record.title = str(odd[key]) + str(record.title)
					elif key == "history": record.history.append(str(odd[key]))
					else: record[key] = odd[key].duplicate() if odd[key] is Array else odd[key]
	return {"issue_ref": ref, "issues": [record]}

## Lowercase `text` with none of `banned` inside it: each banned word loses its
## last letter, so a clean branch or hash can never spell one by accident.
static func _scrub(text: String, banned: Array[String]) -> String:
	var result := text
	for word: String in banned:
		while word in result.to_lower():
			var at := result.to_lower().find(word)
			result = result.substr(0, at + word.length() - 1) + ("0" if word in HEX_BANNED else "-") + result.substr(at + word.length())
	return result

## The PR's latest pipeline run. Each revision is a new push, so a new build.
static func build(spec: Dictionary) -> Dictionary:
	var slot := int(spec.slot)
	var version := int(spec.get("version", 1))
	var key := "%d|%d" % [slot, version]
	var author := str(spec.author)
	var module := str(spec.get("path", "office/note.py")).get_file().get_basename()
	var count := 4 + _roll("test-count|%d" % slot) % 2
	var start := _roll("tests|%d" % slot) % TEST_NAMES.size()
	var tests: Array = []
	for index in range(count):
		var name := TEST_NAMES[(start + index * 5) % TEST_NAMES.size()].replace("{module}", module).replace("{function}", str(spec.get("function", module)))
		tests.append({"name": name.left(52), "result": "pass"})
	var before := 640 + _roll("coverage|%d" % slot) % 250
	var change := -12 + _roll("coverage-change|%d" % slot) % 38
	var seconds := 70 + _roll("duration|" + key) % 300
	var slug := _scrub(module.replace("_", "-"), BRANCH_BANNED)
	var record := {
		"id": build_id(slot, version), "branch": "%s/%s" % [author.to_lower(), slug],
		"commit": _scrub("%07x" % (_roll("commit|" + key) % 0xfffffff), HEX_BANNED), "status": "passed", "override": "",
		"reruns": _roll("reruns|" + key) % 3, "coverage_before": before, "coverage_after": clampi(before + change, 0, 1000),
		"duration": "%dm %02ds" % [seconds / 60, seconds % 60], "tests": tests, "log": [],
	}
	for effect: Dictionary in spec.get("effects", []):
		var variant := int(effect.get("variant", 0))
		match str(effect.get("what", "")):
			"flaky":
				var test: Dictionary = tests[variant % tests.size()]
				test.result = "flaky"
				record.status = "flaky"
				record.log = ["%s failed once (%s), then passed on retry." % [test.name, FAILURES[(variant + 1) % FAILURES.size()].get_slice(":", 0)]]
			"build":
				var failing: int = 1 + variant % 2
				var lines: Array = []
				for index in range(failing):
					var test: Dictionary = tests[(variant + index * 2) % tests.size()]
					test.result = "fail"
					lines.append("FAILED %s" % test.name)
					lines.append("  " + FAILURES[(variant + index * 5) % FAILURES.size()])
				if str(effect.kind) == "override":
					record.status = "passed"
					record.override = "helios"
					lines.append("helios: %d failing test%s judged non-blocking (confidence 0.9%d)." % [failing, "" if failing == 1 else "s", 1 + variant % 9])
					lines.append("helios: override applied. Marking build green.")
				else:
					record.status = "failed"
					record.override = ""
				record.log = lines
			"branch":
				var shapes: Array[String] = BRANCH_FAULTS if str(effect.kind) == "banned" else BRANCH_NEAR
				record.branch = "%s/%s" % [author.to_lower(), shapes[variant % shapes.size()].replace("{module}", slug)]
			"commit":
				# Digits only around the word, so a lookalike can't spell a banned word.
				var words: Array[String] = HEX_FAULTS if str(effect.kind) == "banned" else HEX_NEAR
				var word: String = words[variant % words.size()]
				var digits := "%07d" % (_roll("commit-digits|" + key) % 10000000)
				var at := variant % (8 - word.length())
				record.commit = digits.substr(0, at) + word + digits.substr(0, 7 - word.length() - at)
	if int(record.reruns) > 0 and record.status != "failed":
		record.log.append("Rerun %d time%s by %s; attempt %d passed." % [int(record.reruns), "" if int(record.reruns) == 1 else "s", author.to_lower(), int(record.reruns) + 1])
	return record

## How Pipeline shows a build's status.
static func status_text(record: Dictionary) -> String:
	if record.is_empty(): return ""
	if str(record.get("override", "")) == "helios": return "PASSED (OVERRIDDEN BY HELIOS)"
	return str(record.get("status", "")).to_upper()

static func coverage_text(tenths: int) -> String:
	return "%d.%d%%" % [tenths / 10, tenths % 10]
