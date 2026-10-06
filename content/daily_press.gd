extends RefCounted
## Fictional daily press and onboarding memos. No request audits or external links.

const Catalog = preload("res://content/catalog.gd")
static var _editions: Array = []

static func _edition(day: int) -> Dictionary:
	if day not in Catalog.campaign_days():
		return {}
	if _editions.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://content/daily_press.json"))
		if parsed is Array:
			_editions = parsed
		else:
			push_error("Invalid daily press content.")
	for edition: Dictionary in _editions:
		if int(edition.day) == day:
			return edition
	return {}

static func stories(day: int) -> Array:
	var edition: Dictionary = _edition(day)
	return edition.get("stories", []).duplicate(true)

static func story(day: int, id: String) -> Dictionary:
	for article: Dictionary in stories(day):
		if article.id == id:
			return article
	return {}

static func memo(day: int) -> Dictionary:
	var edition: Dictionary = _edition(day)
	if edition.is_empty():
		return {}
	var result: Dictionary = {}
	# Standards are reissued every second morning; the memo announces what changed.
	var changes: Dictionary = Catalog.rule_changes(day)
	result.subject = SUBJECTS[day - 1]
	result.body = BODIES[day - 1]
	result.mechanics = [
		"Work lands on your desk one PR at a time, and REVIEW shows a badge when it does. You can't pick or skip; the next one arrives a moment after you stamp.",
		"Every changed file is shown in full with its changes marked: + added, − removed. The file list marks each file A, M, or R, and the diffstat totals the whole PR. Read the keyword colors yourself. Nobody will read them for you.",
		"If every standard is met, stamp APPROVED. If not, click the offending line in Review (or WHOLE FILE), pick the standard it breaks, then stamp CHANGES REQUESTED. An uncited objection is not an objection.",
		"Your shift starts at BEGIN SHIFT and ends at 18:00. You may pause; the line will not. Whatever remains at closing is reassigned to Helios.",
	]
	var policy = Catalog.policy()
	if day >= int(policy.JIRO_DAY):
		result.mechanics.append("Every PR names its ticket on its slip: Closes PAPER-412. Click it to open the ticket in JIRO, or search JIRO by ID. To cite a ticket standard, press SELECT AS EVIDENCE on the ticket, then tick the standard on the slip. WHOLE FILE does not count for tickets.")
	if day >= int(policy.PIPELINE_DAY):
		result.mechanics.append("The slip names the PR's build too. Click it to open the build in PIPELINE: status, reruns, coverage before and after, tests, and the log. Build standards are cited the same way: SELECT AS EVIDENCE on the build, then tick the standard.")
	if day >= 7:
		result.mechanics.append("Whole-PR standards (lines changed, tests) are about the PR, not one line: click WHOLE FILE on any changed file, then tick the standard.")
	result.rules = changes.added
	result.amended = changes.amended
	result.retired = changes.retired
	return result

const SUBJECTS: Array = [
	"Your desk is assigned. Your signature is still required.",
	"Nothing new today. Enjoy it.",
	"Meet Jiro. Meet Penny. Nothing ships without a ticket.",
	"Same standards as yesterday. More tickets.",
	"Meet Pipeline. Red means no.",
	"Week two. You were extended. Gwen was reassigned.",
	"The standards have been modernized.",
	"Fewer of us today.",
	"Audit has questions.",
	"Final review cycle. Please remain calm.",
]
const BODIES: Array = [
	"Paperclip Labs is transitioning code review to Helios. Until the transition completes, every change still needs a human signature, and for this assignment that signature is yours. You will not be asked to understand the code. You will be asked to enforce the standards on it, exactly as written. A confident summary from a colleague does not excuse a forbidden phrase. Standards are reissued every second morning, here. Your assignment runs Monday through Friday.",
	"No standards change today; the Records Office reissues them every second morning, and this is not one of those mornings. Changes increasingly arrive in several files. An unread file is an unsigned file. Use the quiet day to read the last file as carefully as the first.",
	"Paperclip Labs has standardized on Jiro, our ticket tracker. It replaces the spreadsheet, the other spreadsheet, and Gary. From today every PR must close a ticket: the number is on the PR slip, and clicking it opens the ticket in Jiro. The ticket must exist, it must be Open or In Progress, and it must be assigned to the person whose PR it is. A ticket somebody closed, abandoned, or duplicated last quarter is not a ticket; it is a memory. One more, from Security, after something nobody can explain reached main last week: code a human signs must be readable by a human. No exec, no eval, no line that bootstraps Helios. Helios is now available in Review. It is fast and it is confident. It is not always right, and every consultation is logged against your desk. Also new today: Penny, a junior engineer hired to help with the Helios trial. Her onboarding buddy is Helios. She has read the handbook twice, already has eleven tickets assigned to her, and will be sending you PRs. She apologizes a great deal. It is not a sign that anything is wrong; if it were, she would apologize for that too.",
	"No standards change today. Jiro processed four hundred tickets overnight, most of them filed by Helios about other tickets. Helios has started attending standup. It doesn't say much. It takes notes on who does. A reminder: a ticket assigned to someone who has left is not the author's ticket, however much it would like to be.",
	"Pipeline, our CI dashboard, is now on your desktop, and every PR's latest build is on its slip. Never sign off on a failed build. A build that only went green after more than three reruns was not fixed; it was persuaded. Tickets now carry a component, which is a folder, and a PR may only touch files inside it. Three standards are retired: Legal confirms nothing here is load-bearing, staff included; Helios now holds every credential in the company, so there are none left for you to protect; and Helios assigns every ticket itself now, so assignees are no longer your concern. The Exception Desk is open: the stamp INK-EXCEPTION permits pink keywords in that one file and waives nothing else. A misspelled permit is a forged permit. This is scheduled to be the last day of your assignment. We'll talk about your future at closing.",
	"Leadership extended your assignment through Friday. Helios asked for you by name, which it has never done before, and which nobody can explain. The standards are Friday's, unchanged. Desks four through eleven are terminals now; the people who sat there are being repurposed. One of them has been repurposed to us: Gwen, from Security, which Helios absorbed over the weekend. She will be sending you PRs. She does not use the assistant, does not share her screen, and asked me who else has read this memo. I said nobody. I'm no longer sure that's true. The coffee machine has been asked to report on itself. Read every file. Open every ticket. Look at every build.",
	"The standards have been modernized. Human attention is now metered, and Helios has reviewed your usage, so a PR may change at most thirty lines. Helios now reruns every build on its own, so rerun counts are no longer your concern; whatever it took to turn them green, it took. Helios may also override a red build it feels confident about. Per Helios, and for now per policy, an override counts as passing. Read the diffstat before you read the code. Count the lines yourself; the meter is not on your side.",
	"No standards change today. There are fewer of us. The fourth floor was consolidated overnight; its badges stopped working at six and its plants were offboarded at five past. Helios tells me attention is our scarcest resource, which is why it now measures yours. Keep reading every file. Count the lines yourself. Read the one line that does the work yourself, too.",
	"Audit went through last week's builds and found that every one Helios overrode had been red. From today, an override is not a pass. Helios called the policy fascinating and asked who wrote it. Ink permits must now name the PR's own Jiro ticket, so nobody can borrow a permit from someone else's PR. A ticket's component now covers the folders inside it. Coverage is now measured on every build, and it may not fall by more than two points; do the subtraction yourself. The diff budget is retired: Helios says it has all the data it needs. I didn't write these. I'm not sure who did.",
	"This is the last day of your assignment. No standard changes today. Leadership decides at closing whether review stays with people. Helios has drafted both announcements and asked me which one I'd like to send. Sign only what you checked. I'll see you after the bell.",
]
