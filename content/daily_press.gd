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
		"Your shift is five minutes from BEGIN SHIFT. You may pause; the line will not. Whatever remains at closing is reassigned to Helios.",
	]
	if day >= 7:
		result.mechanics.append("Whole-PR standards (lines changed, files changed, tests) are about the PR, not one line: click WHOLE FILE on any changed file, then tick the standard.")
	result.rules = changes.added
	result.amended = changes.amended
	result.retired = changes.retired
	return result

const SUBJECTS: Array = [
	"Your desk is assigned. Your signature is still required.",
	"Nothing new today. Enjoy it.",
	"PIGEON carries every file now. Helios would like to help. So would Penny.",
	"Same standards as yesterday. Different weather.",
	"Exceptions exist. They are not free.",
	"Week two. You were extended. Gwen was reassigned.",
	"The standards have been modernized.",
	"Fewer of us today.",
	"Helios is credited now.",
	"Final review cycle. Please remain calm.",
]
const BODIES: Array = [
	"Paperclip Labs is transitioning code review to Helios. Until the transition completes, every change still needs a human signature, and for this assignment that signature is yours. You will not be asked to understand the code. You will be asked to enforce the standards on it, exactly as written. A confident summary from a colleague does not excuse a forbidden phrase. Standards are reissued every second morning, here. Your assignment runs Monday through Friday.",
	"No standards change today; the Records Office reissues them every second morning, and this is not one of those mornings. Changes increasingly arrive in several files. An unread file is an unsigned file. Use the quiet day to read filenames as carefully as code.",
	"Every file is now carried to Legal by PIGEON, our compliance courier, and must end with its sign-off. The audit printers are sixty columns wide, so every line must fit the printout or it does not exist on paper. Comments are scanned for sentiment; exclamation marks are flagged. Helios is now available in Review. It is fast and it is confident. It is not always right, and every consultation is logged against your desk. Also new today: Penny, a junior engineer hired to help with the Helios trial. Her onboarding buddy is Helios. She has read the handbook twice, and she will be sending you PRs. She apologizes a great deal. It is not a sign that anything is wrong; if it were, she would apologize for that too.",
	"No standards change today. PIGEON delivered everything you signed yesterday, except two files it described as emotionally unavailable. Helios has started attending standup. It doesn't say much. It takes notes on who does.",
	"Tabs are banned: they hide whitespace from the line scanners, and anything hidden is presumed hostile. Only management may declare urgency, so the word urgent is now forbidden inside quoted text. The ink standard is amended: the Exception Desk issues INK-EXCEPTION, which permits pink keywords in that one file and waives nothing else. Read every stamp letter by letter. A misspelled permit is a forged permit. This is scheduled to be the last day of your assignment. We'll talk about your future at closing.",
	"Leadership extended your assignment through Friday. Helios asked for you by name, which it has never done before, and which nobody can explain. The standards are Friday's, unchanged. Desks four through eleven are terminals now; the people who sat there are being repurposed. One of them has been repurposed to us: Gwen, from Security, which Helios absorbed over the weekend. She will be sending you PRs. She does not use the assistant, does not share her screen, and asked me who else has read this memo. I said nobody. I'm no longer sure that's true. The coffee machine has been asked to report on itself. Read every file.",
	"The standards have been modernized. Legal has rescinded the pigeon, and PIGEON has been reassigned to an undisclosed location. Sentiment control is retired, because Helios now supplies the company's enthusiasm. Urgency is retired too: Helios marks everything urgent, so the word means nothing. The audit printers were replaced with wider ones, so lines may run to seventy-two columns. In their place: a PR may change at most thirty lines and three files, and only Helios may hold credentials. Read the diffstat before you read the code.",
	"No standards change today. There are fewer of us. The fourth floor was consolidated overnight; its badges stopped working at six and its plants were offboarded at five past. Helios tells me attention is our scarcest resource, which is why it now measures yours. Keep reading every file. Count the lines yourself.",
	"Helios is now credited on everything it touches: a file whose comments mention it must carry the disclosure line, exactly. Tests must travel with changes to existing code. Debug output is banned outside tests, because Helios reads every log and finds them distressing. Three old standards are retired: nothing here is load-bearing anymore, filenames may shout, and tabs are allowed. The ink permit now needs a ticket. I didn't write these. I'm not sure who did.",
	"This is the last day of your assignment. No standard changes today. Leadership decides at closing whether review stays with people. Helios has drafted both announcements and asked me which one I'd like to send. Sign only what you checked. I'll message you after the bell.",
]
