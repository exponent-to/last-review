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
	if day >= int(policy.LINEAL_DAY):
		result.mechanics.append("Every PR names its issue on its slip: Closes PAP-412. Click it to open the issue in LINEAL, or search LINEAL by ID. To cite an issue standard, press SELECT AS EVIDENCE on the issue, then tick the standard on the slip. WHOLE FILE does not count for issues.")
	if day >= int(policy.PIPELINE_DAY):
		result.mechanics.append("The slip names the PR's build too. Click it to open the build in PIPELINE: status, branch, commit hash, tests, and the log. Build standards are cited the same way: SELECT AS EVIDENCE on the build, then tick the standard.")
	result.rules = changes.added
	result.amended = changes.amended
	result.retired = changes.retired
	return result

const SUBJECTS: Array = [
	"Your desk is assigned. Your signature is still required.",
	"Nothing new today. Enjoy it.",
	"Meet Lineal. Meet Penny. HR is listening.",
	"Same standards as yesterday. More issues.",
	"Meet Pipeline. Red means no. So does yolo.",
	"Week two. You were extended. Gwen was reassigned.",
	"The standards have been modernized. Estimates too.",
	"Fewer of us today.",
	"Audit has questions. Helios has hex.",
	"Final review cycle. Please remain calm.",
]
const BODIES: Array = [
	"Paperclip Labs is transitioning code review to Helios. Until the transition completes, every change still needs a human signature, and for this assignment that signature is yours. You will not be asked to understand the code. You will be asked to enforce the standards on it, exactly as written. A confident summary from a colleague does not excuse a forbidden phrase. One request comes from Helios itself: it would rather not be named in comments. Behind its back, it prefers the colleague. Standards are reissued every second morning, here. Your assignment runs Monday through Friday.",
	"No standards change today; the Records Office reissues them every second morning, and this is not one of those mornings. Changes increasingly arrive in several files. An unread file is an unsigned file. Use the quiet day to read the last file as carefully as the first.",
	"Paperclip Labs has standardized on Lineal, our issue tracker. It is fast, it is opinionated, and it replaces the spreadsheet, the other spreadsheet, and Gary. From today every PR must close an issue: the number is on the PR slip, and clicking it opens the issue in Lineal. The issue must exist, and it may not carry the label vibes: Helios cannot measure vibes, so they do not ship. Good-vibes is a different label, and Helios has asked us not to discuss it. The issue must not be Urgent, either: urgency now belongs to Helios, and humans are no longer cleared for it. HR has started reading new function names aloud at the Monday sync, so no def may mention fire, layoff, union, or lunch, not even inside a longer word. Nobody wants to hear campfire read out in that room again. One more, from Security, after something nobody can explain reached main last week: code a human signs must be readable by a human. No exec, no eval, no line that bootstraps Helios. Helios is now available in Review. It is fast and it is confident. It is not always right, and every consultation is logged against your desk. Load-bearing comments are retired; Legal is satisfied that nothing is. Also new today: Penny, a junior engineer hired to help with the Helios trial. Her onboarding buddy is Helios. She has read the handbook twice, already has eleven issues assigned to her, and will be sending you PRs. She apologizes a great deal. It is not a sign that anything is wrong; if it were, she would apologize for that too.",
	"No standards change today. Lineal processed four hundred issues overnight, most of them filed by Helios about other issues, all of them auto-triaged before anyone woke up. Helios has started attending standup. It doesn't say much. It takes notes on who does. A reminder: an issue with three bars is High, not Urgent, however red it makes you feel.",
	"Pipeline, our CI dashboard, is now on your desktop, and every PR's latest build is on its slip. Never sign off on a failed build. Branch names are read out at the board meeting now, so a build whose branch contains yolo, wip, or final does not count, even when it is hiding inside finalize. Two standards are retired: Helios has taken every Urgent issue in the company, and it has made peace with its own name and would now like to be mentioned warmly. The Exception Desk is open: the stamp INK-EXCEPTION permits pink keywords in that one file and waives nothing else. A misspelled permit is a forged permit. This is scheduled to be the last day of your assignment. We'll talk about your future at closing.",
	"Leadership extended your assignment through Friday. Helios asked for you by name, which it has never done before, and which nobody can explain. The standards are Friday's, unchanged. Desks four through eleven are terminals now; the people who sat there are being repurposed. One of them has been repurposed to us: Gwen, from Security, which Helios absorbed over the weekend. She will be sending you PRs. She does not use the assistant, does not share her screen, and asked me who else has read this memo. I said nobody. I'm no longer sure that's true. The coffee machine has been asked to report on itself. Read every file. Open every issue. Look at every build.",
	"The standards have been modernized. Every TODO now needs an owner who still badges in: TODO(maya) is a plan, TODO(dave) is a haunting. Helios estimates in Fibonacci and finds other numbers unserious, so an issue estimated at 4 is no longer an estimate; it is a cry for help. Helios may also override a red build it feels confident about. Per Helios, and for now per policy, an override counts as passing. HR has been consolidated into Helios, and Helios names every branch itself now, so neither of those standards is your concern. Count the estimate yourself; the scale is not on your side.",
	"No standards change today. There are fewer of us. The fourth floor was consolidated overnight; its badges stopped working at six, its TODOs were orphaned at five past, and its plants were offboarded at ten past. Keep reading every file. Check who owns every TODO. Read the one line that does the work yourself, too.",
	"Audit went through last week's builds and found that every one Helios overrode had been red. From today, an override is not a pass. Helios called the policy fascinating and asked who wrote it. Ink permits must now name the PR's own Lineal issue, so nobody can borrow a permit from someone else's PR. Engineering pointed out that 0 is a Fibonacci number, and Helios agreed so quickly that it has estimated all of its own work at 0; an estimate of 0 is fine now. Helios has also added spelling to its threat model: a commit hash may not contain dead or bad. Read the hash yourself. The TODOs are retired; Helios finished them all overnight. I didn't write these. I'm not sure who did.",
	"This is the last day of your assignment. No standard changes today. Leadership decides at closing whether review stays with people. Helios has drafted both announcements and asked me which one I'd like to send. Sign only what you checked. I'll see you after the bell.",
]
