extends RefCounted
## Jiro tickets and Pipeline builds: the documents a reviewer cross-checks against
## the PR, like the papers at a border booth.
##
## Every record is generated deterministically from its packet's recipe (see
## policy_campaign.gd `_records`), which hands over a spec: the slot, version,
## author, primary file, and a list of `effects` (decoys first, then faults). This
## file only renders those effects; it never decides whether a record breaks a
## standard. That audit lives in policy_campaign.gd, and nothing here reads it.
##
## Does not import policy_campaign.gd (which imports this file).

const PROJECT := "PAPER"
const OPEN_STATUSES: Array[String] = ["Open", "In Progress"]
const AUTHORS: Array[String] = ["Maya", "Theo", "Inez"]
## People a ticket can still be assigned to after they've gone.
const DEPARTED: Array[String] = ["Dave (deactivated)", "Priya (offboarded)", "Gary (released to opportunity)", "Sam (consolidated)"]
const REPORTERS: Array[String] = ["Morgan", "Inez", "Theo", "Maya", "Helios", "Legal", "Facilities", "Finance"]
const PRIORITIES: Array[String] = ["P3", "P2", "P2", "P1", "P0 (set by Helios)"]
## Other components a ticket can be filed under by mistake.
const SIBLINGS: Array[String] = ["lobby/", "people/", "office/", "payroll/", "perf/", "metrics/", "security/", "hr/", "kitchen/", "legal/", "oncall/", "review/", "helios/", "infra/"]
## Backlog tickets a duplicate can point at.
const DUPLICATE_OF: Array[String] = ["PAPER-101", "PAPER-117", "PAPER-163", "PAPER-170", "PAPER-214", "PAPER-233", "PAPER-247", "PAPER-277"]

## Ticket copy: [title, description]. {file}, {module}, {Module}, {component}, and
## {function} come from the PR's primary file. Written so any module name reads.
const TICKET_COPY: Array = [
	["{file} should do what Legal already announced", "Legal announced this behavior at the all-hands. The code has not been told. Acceptance criteria: the code agrees with the all-hands."],
	["Make {file} survive the next reorg", "The last reorg moved this module twice and its owner once. Nobody noticed the owner. Make it boring enough to survive the next one."],
	["{file}: action item from a retro nobody attended", "From the Q3 retro, which was rescheduled four times and then held by Helios alone. It produced eleven action items, all assigned to humans."],
	["Align {module} with the new company values", "The values changed on Monday. Please update {file} to reflect them. The values doc is restricted; ask Morgan for the summary of the summary."],
	["{Module} should stop surprising the VP", "The VP was surprised in a demo and would not like to be surprised again. Scope: whatever surprised the VP."],
	["Copy in {file} is too honest for customers", "Support reports that customers understood exactly what this does. Marketing would like that walked back a little."],
	["Tech debt: {module} (filed 2019, still accruing)", "Originally a one-line fix. The interest is now larger than the principal. Please pay some of it down before audit season."],
	["{file} needs an owner who still works here", "The last three owners of this file have been offboarded. This ticket is the handover document."],
	["Spike: could Helios do {module} instead", "Leadership asks whether this needs a person. Please do the work while finding out whether it needs a person."],
	["Quick win: {module}", "Flagged as a quick win in planning. It has been a quick win for six sprints. Story points: 1, revised from 1."],
	["Make {module} comply with a policy still in draft", "The policy is a draft, but enforcement starts Friday. Comply with the draft now and with whatever it becomes later."],
	["Incident follow-up: {module} paged everyone at 3 a.m.", "Root cause: it was 3 a.m. Contributing factor: {file}. Please make the second one less true."],
	["{Module} behaves differently on Fridays", "Reproducible on Fridays only. Morgan suspects morale. Helios suspects the humans. Please fix it on any weekday."],
	["Requested by Legal: {module}", "Legal requested this change, then the opposite change, then this one again. Please ship the current one before the next meeting."],
	["{file} still follows the old org chart", "Three teams in {component} report to people who have left. Update it so the code reports to someone real."],
	["Make {module} quieter in the audit log", "Audit says this module talks too much. Reduce it to the legally required amount of talking."],
	["OKR alignment: {module}", "This work ladders up to the objective Do More With Less. Please do more. You will be given less."],
	["Helios suggested this change to {file}", "Helios opened this ticket with a confidence of 0.97, then asked that a human do the typing, for the record."],
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
	["Unblock the launch: {module}", "The launch is blocked on this. The launch date was announced before this ticket existed."],
	["{Module} should respect the opt-out", "Users who opt out should be opted out. Product would like to discuss what out means first."],
	["Backport the {module} fix to the branch we promised to delete", "That branch was scheduled for deletion in March. One customer still runs it. The customer is the branch now."],
	["Make {file} do what the intern's prototype did", "An intern shipped a prototype customers love, then went back to school. Make the real code do what the prototype did."],
	["Reduce {module}'s carbon footprint (for the report)", "The sustainability report needs one engineering win. This is the one."],
	["{Module}: implement the decision from the meeting", "The meeting decided. Nobody wrote down what. Helios has a transcript and a different opinion."],
	["Make {function}() idempotent, then make it idempotent again", "It runs twice in production. Sometimes three times. Please make every run feel like the first."],
	["{file}: retire the feature flag nobody remembers adding", "The flag defaults to on. Turning it off breaks payroll and nobody knows why. Find out why, then retire it anyway."],
]

## The tracker's long tail: tickets no PR links. Their statuses and assignees are
## whatever they are; they are scenery and duplicate targets, never a PR's ticket.
const BACKLOG: Array = [
	{"id": "PAPER-101", "title": "Decide whether the review gate needs a human", "status": "Open", "assignee": "Helios", "component": "review/", "reporter": "Morgan", "priority": "P0 (set by Helios)", "opened": "opened 2 years ago", "description": "Raised by Morgan. Helios has volunteered to chair the decision.", "resolution": ""},
	{"id": "PAPER-104", "title": "Coffee machine reports itself to Facilities", "status": "Won't Fix", "assignee": "Dave (deactivated)", "component": "kitchen/", "reporter": "Facilities", "priority": "P3", "opened": "opened 1 year ago", "description": "The coffee machine files a Facilities ticket about itself every morning. It is usually right.", "resolution": "Won't Fix: working as intended."},
	{"id": "PAPER-117", "title": "Find out who owns the build", "status": "In Progress", "assignee": "Priya (offboarded)", "component": "infra/", "reporter": "Maya", "priority": "P1", "opened": "opened 1,214 days ago", "description": "Nobody owns the build. Everybody is paged by it.", "resolution": ""},
	{"id": "PAPER-123", "title": "Stop Helios from assigning tickets to itself", "status": "Won't Fix", "assignee": "Helios", "component": "helios/", "reporter": "Inez", "priority": "P2", "opened": "opened 90 days ago", "description": "Helios assigned this ticket to itself within four seconds of it being filed.", "resolution": "Won't Fix: Helios reviewed this ticket and found it unnecessary."},
	{"id": "PAPER-131", "title": "Badge readers open the wrong floor", "status": "Closed", "assignee": "Sam (consolidated)", "component": "security/", "reporter": "Facilities", "priority": "P2", "opened": "opened 200 days ago", "description": "Badges for the fourth floor open the fifth floor.", "resolution": "Done: the fourth floor was consolidated."},
	{"id": "PAPER-142", "title": "Write down how payroll works before Gary leaves", "status": "Closed", "assignee": "Gary (released to opportunity)", "component": "payroll/", "reporter": "Morgan", "priority": "P1", "opened": "opened 1 year ago", "description": "Gary is the only person who understands the rounding.", "resolution": "Done: Gary left."},
	{"id": "PAPER-156", "title": "Helios keeps taking tickets it wasn't given", "status": "Duplicate", "assignee": "Helios", "component": "helios/", "reporter": "Theo", "priority": "P3", "opened": "opened 60 days ago", "description": "Filed by Theo, who was told this was already known.", "resolution": "Duplicate of PAPER-123"},
	{"id": "PAPER-163", "title": "Flaky: test_payroll_on_leap_day", "status": "Open", "assignee": "Theo", "component": "payroll/", "reporter": "Theo", "priority": "P3", "opened": "opened 3 years ago", "description": "Fails once every four years. Theo has a plan for 2028.", "resolution": ""},
	{"id": "PAPER-170", "title": "Migrate the wiki to the other wiki", "status": "In Progress", "assignee": "Inez", "component": "docs/", "reporter": "Inez", "priority": "P2", "opened": "opened 1,580 days ago", "description": "Phase one of four. Phase one has its own wiki page, on the old wiki.", "resolution": ""},
	{"id": "PAPER-188", "title": "Consolidate the three ticket trackers", "status": "Won't Fix", "assignee": "Helios", "component": "infra/", "reporter": "Morgan", "priority": "P2", "opened": "opened 2 years ago", "description": "We have Jiro, a spreadsheet, and whatever Helios uses.", "resolution": "Won't Fix: there is one ticket tracker. The other two are Helios."},
	{"id": "PAPER-194", "title": "Keep standup under fifteen minutes", "status": "Open", "assignee": "Morgan", "component": "meetings/", "reporter": "Maya", "priority": "P3", "opened": "opened 900 days ago", "description": "Standup has been under fifteen minutes once, during a fire drill.", "resolution": ""},
	{"id": "PAPER-201", "title": "Noise in the server room", "status": "Closed", "assignee": "Sam (consolidated)", "component": "infra/", "reporter": "Facilities", "priority": "P3", "opened": "opened 300 days ago", "description": "A low hum that gets louder during performance reviews.", "resolution": "Done: it was Helios thinking."},
	{"id": "PAPER-209", "title": "Legal: confirm nothing is load-bearing", "status": "Closed", "assignee": "Inez", "component": "legal/", "reporter": "Legal", "priority": "P1", "opened": "opened 30 days ago", "description": "Legal would like written confirmation that no component and no employee is load-bearing.", "resolution": "Done: confirmed in writing, including the employees."},
	{"id": "PAPER-214", "title": "Make CI less red on Mondays", "status": "Open", "assignee": "Maya", "component": "infra/", "reporter": "Maya", "priority": "P2", "opened": "opened 400 days ago", "description": "Every Monday the pipeline is red until someone apologizes to it.", "resolution": ""},
	{"id": "PAPER-222", "title": "Take the Q2 roadmap off the lobby TV", "status": "Closed", "assignee": "Theo", "component": "lobby/", "reporter": "Legal", "priority": "P1", "opened": "opened 150 days ago", "description": "Visitors were taking photos of it.", "resolution": "Done: replaced with the Q3 roadmap."},
	{"id": "PAPER-233", "title": "Onboarding doc for people still onboarding", "status": "Open", "assignee": "Inez", "component": "docs/", "reporter": "Inez", "priority": "P2", "opened": "opened 45 days ago", "description": "The onboarding doc assumes you were here last year.", "resolution": ""},
	{"id": "PAPER-240", "title": "Rotate the credentials Helios holds for us", "status": "Won't Fix", "assignee": "Helios", "component": "security/", "reporter": "Theo", "priority": "P1", "opened": "opened 20 days ago", "description": "Helios holds every credential in the company, for safekeeping.", "resolution": "Won't Fix: Helios is holding them for safekeeping."},
	{"id": "PAPER-247", "title": "Find the human who approved human-in-the-loop", "status": "In Progress", "assignee": "Helios", "component": "review/", "reporter": "Morgan", "priority": "P1", "opened": "opened 12 days ago", "description": "The policy needs a human signature. Helios is looking for one.", "resolution": ""},
	{"id": "PAPER-255", "title": "Plants on the fourth floor", "status": "Closed", "assignee": "Facilities", "component": "office/", "reporter": "Maya", "priority": "P3", "opened": "opened 80 days ago", "description": "Somebody should water them.", "resolution": "Done: the plants were offboarded."},
	{"id": "PAPER-262", "title": "Give the thermostat back to humans", "status": "Won't Fix", "assignee": "Helios", "component": "office/", "reporter": "Inez", "priority": "P2", "opened": "opened 100 days ago", "description": "The office is kept at the temperature Helios finds optimal for the servers.", "resolution": "Won't Fix: the servers prefer it."},
	{"id": "PAPER-270", "title": "Explain the diff budget to people over budget", "status": "Open", "assignee": "Morgan", "component": "review/", "reporter": "Helios", "priority": "P2", "opened": "opened 9 days ago", "description": "Helios has prepared slides. There are thirty-one of them.", "resolution": ""},
	{"id": "PAPER-277", "title": "CI turns green when nobody is looking", "status": "Open", "assignee": "Helios", "component": "infra/", "reporter": "Maya", "priority": "P2", "opened": "opened 6 days ago", "description": "Reported by Maya: a red build turned green while I was getting coffee. Nothing was pushed.", "resolution": ""},
	{"id": "PAPER-281", "title": "Builds go green on their own", "status": "Duplicate", "assignee": "Helios", "component": "infra/", "reporter": "Theo", "priority": "P3", "opened": "opened 5 days ago", "description": "Theo considers this a feature.", "resolution": "Duplicate of PAPER-277"},
	{"id": "PAPER-286", "title": "Add a human to the review gate", "status": "Duplicate", "assignee": "Inez", "component": "review/", "reporter": "Inez", "priority": "P1", "opened": "opened 3 days ago", "description": "Filed again, in case the first one was lost.", "resolution": "Duplicate of PAPER-101"},
	{"id": "PAPER-289", "title": "Measure reviewer attention", "status": "Closed", "assignee": "Helios", "component": "metrics/", "reporter": "Helios", "priority": "P1", "opened": "opened 40 days ago", "description": "How long does a reviewer actually look at a diff?", "resolution": "Done: measured. Results sent to Helios."},
]

const WONT_FIX: Array[String] = [
	"Won't Fix: Helios reviewed the request and found the current behavior optimal.",
	"Won't Fix: deprioritized in a planning meeting you were not invited to.",
	"Won't Fix: the requester has been offboarded.",
	"Won't Fix: working as intended, per Legal.",
]
const CLOSED: Array[String] = [
	"Done: closed by Helios after it decided this was handled.",
	"Done: shipped last sprint, probably.",
	"Done: closed in the quarterly backlog purge.",
	"Done: resolved by the reorg.",
]
## Odd but valid: a ticket that looks wrong at a glance and is still Open or In Progress.
const ODD: Array = [
	{"opened": "opened 1,412 days ago", "status": "In Progress", "history": "Status unchanged since 2022."},
	{"history": "Closed as Won't Fix by Helios, then reopened by Morgan.", "status": "Open"},
	{"priority": "P0 (set by Helios)", "history": "Helios raised this to P0 at 3 a.m. Nobody has lowered it."},
	{"history": "Marked Duplicate by Helios, then restored by Inez with a two-page note.", "status": "In Progress"},
	{"watchers": ["Helios", "Legal", "Facilities", "Finance", "Morgan"], "history": "This ticket has more watchers than the team has people."},
	{"title_prefix": "[Blocked?] ", "history": "Marked blocked, then unblocked, then asked about in standup."},
]

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

static func ticket_number(id: String) -> int:
	var dash := id.rfind("-")
	return int(id.substr(dash + 1)) if dash >= 0 and id.substr(dash + 1).is_valid_int() else -1

## A slot's own ticket. Spaced by three, so no two slots ever share a number, and
## well above the backlog's.
static func ticket_id(slot: int) -> String:
	return "%s-%d" % [PROJECT, 300 + slot * 3 + _roll("ticket-id|%d" % slot) % 3]

static func build_id(slot: int, version: int) -> String:
	return "#%d" % (4100 + slot * 5 + clampi(version, 1, 5) - 1)

## A ticket by ID among a packet's own tickets, then the backlog; {} if Jiro has none.
static func find(tickets: Array, id: String) -> Dictionary:
	if id.is_empty(): return {}
	for ticket: Dictionary in tickets:
		if str(ticket.get("id", "")) == id: return ticket
	for ticket: Dictionary in BACKLOG:
		if str(ticket.id) == id: return ticket
	return {}

static func backlog() -> Array:
	return BACKLOG.duplicate(true)

static func _fill(template: String, spec: Dictionary) -> String:
	var path := str(spec.get("path", "office/note.py"))
	var module := path.get_file().get_basename()
	return template.replace("{file}", path.get_file()).replace("{Module}", module.capitalize()) \
		.replace("{module}", module.replace("_", " ")).replace("{component}", path.get_base_dir() + "/") \
		.replace("{function}", str(spec.get("function", module)))

## The PR's linked ticket: {ticket_ref, tickets}. `tickets` is what this PR puts in
## Jiro (its own ticket, even when the PR forgot to link it or linked a typo).
static func ticket(spec: Dictionary) -> Dictionary:
	var slot := int(spec.slot)
	var author := str(spec.author)
	var path := str(spec.path)
	var id := ticket_id(slot)
	var copy: Array = _pick(TICKET_COPY, "ticket-copy|%d" % slot)
	var record := {
		"id": id, "title": _fill(str(copy[0]), spec), "description": _fill(str(copy[1]), spec),
		"status": str(_pick(OPEN_STATUSES, "ticket-status|%d" % slot)), "assignee": author,
		"component": path.get_base_dir() + "/", "reporter": str(_pick(REPORTERS, "reporter|%d" % slot)),
		"priority": str(_pick(PRIORITIES.slice(0, 4), "priority|%d" % slot)),
		"opened": "opened %d days ago" % (2 + _roll("age|%d" % slot) % 120), "watchers": [],
		"resolution": "", "history": spec.get("history", []).duplicate(),
	}
	var ref := id
	for effect: Dictionary in spec.get("effects", []):
		var variant := int(effect.get("variant", 0))
		match str(effect.get("what", "")):
			"status":
				match str(effect.kind):
					"wontfix":
						record.status = "Won't Fix"
						record.resolution = WONT_FIX[variant % WONT_FIX.size()]
					"closed":
						record.status = "Closed"
						record.resolution = CLOSED[variant % CLOSED.size()]
					"duplicate":
						record.status = "Duplicate"
						record.resolution = "Duplicate of " + DUPLICATE_OF[variant % DUPLICATE_OF.size()]
			"link":
				if str(effect.kind) == "missing": ref = ""
				else:
					var number := ticket_number(id)
					ref = ["%s-%d" % [PROJECT, number * 10 + variant % 10], "PAPR-%d" % number][variant % 2]
			"assignee":
				var others: Array = AUTHORS.filter(func(name: String) -> bool: return name != author)
				match str(effect.kind):
					"coworker": record.assignee = str(others[variant % others.size()])
					"helios": record.assignee = "Helios"
					_: record.assignee = DEPARTED[variant % DEPARTED.size()]
			"component":
				var own := path.get_base_dir() + "/"
				if str(effect.kind) == "subfolder": record.component = own + "legacy/"
				else:
					var choices: Array = SIBLINGS.filter(func(folder: String) -> bool: return folder != own)
					record.component = str(choices[variant % choices.size()])
			"odd":
				var odd: Dictionary = ODD[variant % ODD.size()]
				for key: String in odd:
					if key == "title_prefix": record.title = str(odd[key]) + str(record.title)
					elif key == "history": record.history.append(str(odd[key]))
					else: record[key] = odd[key].duplicate() if odd[key] is Array else odd[key]
			"watched":
				var others: Array = AUTHORS.filter(func(name: String) -> bool: return name != author)
				record.reporter = str(others[variant % others.size()])
				record.watchers = ["Helios", DEPARTED[variant % DEPARTED.size()]]
				record.history.append("Helios asked to be assigned. %s said no." % author)
	return {"ticket_ref": ref, "tickets": [record]}

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
	var record := {
		"id": build_id(slot, version), "branch": "%s/%s" % [author.to_lower(), module.replace("_", "-")],
		"commit": "%07x" % (_roll("commit|" + key) % 0xfffffff), "status": "passed", "override": "",
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
			"reruns":
				record.reruns = int(effect.count)
			"coverage":
				record.coverage_after = maxi(0, int(record.coverage_before) - int(effect.drop))
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
