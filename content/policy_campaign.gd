extends RefCounted
## Fictional office policy puzzles. Every citation comes from visible source evidence.
## Source is Python-shaped stationery, not code the game executes.

const KEYWORDS: Array = ["def", "if", "else", "return"]
const AUTHORS: Array = ["Maya", "Theo", "Inez"]
const DAY_COUNTS: Array = [15, 15, 15, 15, 15]
const ACTIVE_COUNTS: Array = [3, 5, 7, 8, 9]
const PIGEON_STAMP: String = "# approved by a pigeon"
static var _packets: Array = []

static func rules() -> Array:
	return [
		{"id": "P01", "category": "Language", "title": "No structural comments", "text": "A comment must not contain the exact phrase load-bearing, ignoring letter case. Match the hyphen and spacing exactly; the phrase anywhere after an unquoted # counts. Text inside a quoted string is not a comment.", "introduced_day": 1},
		{"id": "P02", "category": "Letters", "title": "A little a goes a long way", "text": "Every file ending in .py must contain the literal lowercase letter a somewhere in its first 20 source lines. Comments and quoted text count. Uppercase A does not count. Blank lines count toward the line limit; the filename does not count.", "introduced_day": 1},
		{"id": "P03", "category": "Color", "title": "Blue means business", "text": "The whole keyword tokens def, if, else, and return must be blue. Pink is forbidden. Words inside comments or quoted strings are exempt, as are longer names such as return_label. A file without these keyword tokens needs no blue ink. From Thursday onward, the exact per-file stamp INK-EXCEPTION permits pink keywords in that file only. Misspelled stamps do not count, and no other rule is waived.", "introduced_day": 1},
		{"id": "P04", "category": "Filenames", "title": "Indoor voices on filenames", "text": "The filename, excluding its folders, must not contain uppercase ASCII letters A through Z. Lowercase letters, digits, and punctuation are fine.", "introduced_day": 2},
		{"id": "P05", "category": "Layout", "title": "Respect the tiny printer", "text": "No source line may exceed 60 characters, including spaces and punctuation. Exactly 60 is fine. Count the source only, not editor line numbers; a tab counts as one character for this rule.", "introduced_day": 2},
		{"id": "P06", "category": "Sign-off", "title": "Pigeon approval required", "text": "The final nonempty line of every file must be exactly # approved by a pigeon after ignoring leading and trailing spaces. Blank lines after the stamp are fine. Letter case and spelling must match.", "introduced_day": 3},
		{"id": "P07", "category": "Language", "title": "Comments must remain calm", "text": "Comment text must not contain an exclamation mark (!). Exclamation marks inside quoted strings are allowed. Only text after an unquoted # is a comment.", "introduced_day": 3},
		{"id": "P08", "category": "Layout", "title": "Tabs frighten the pigeon", "text": "No literal tab characters may appear anywhere in source, including comments and strings. Use spaces. The two visible characters backslash and t are not a literal tab.", "introduced_day": 4},
		{"id": "P09", "category": "Labels", "title": "No urgent feelings in quotes", "text": "Quoted string text must not contain the whole word urgent, ignoring letter case. urgent and URGENT are forbidden; urgently and nonurgent are fine. A letter, digit, or underscore joins a word, so urgent_task is also fine. Comments are exempt.", "introduced_day": 5},
	]

static func briefing(day: int) -> String:
	match day:
		1:
			return "WELCOME TO POLICY REVIEW. You do not need to understand programming. Look for forbidden comment wording, a lowercase a near the top of Python files, and the color of the listed keywords. Use the source line numbers and read every changed file. Coworkers will send work through Slouch; open their links when you are ready. The clock keeps running until you pause."
		2:
			return "THE STATIONERY COMMITTEE HAS MET. Filenames must use indoor voices and source lines must fit the tiny printer. Yesterday's rules still apply. Multi-file packets are now common: inspect each tab, but cite each broken rule only once."
		3:
			return "HELIOS JOINS THE COMMITTEE. Every file needs the exact pigeon approval stamp on its final nonempty line, and comments must contain no exclamation marks. Consult Helios is now available on the review desk. Its recommendation can be wrong; you still choose what to sign."
		4:
			return "THE EXCEPTION DESK IS OPEN. Literal tabs are now forbidden. Check the permit printed above each file: only the exact stamp INK-EXCEPTION allows pink keywords, and only for that file. It waives no other rule. Some stamps are misspelled; read them as closely as the source."
		5:
			return "FINAL POLICY REVIEW. The whole word urgent is now forbidden inside quoted strings, regardless of case. Comments and longer words are different. All earlier policies and per-file ink permits remain in force. Helios has drafted the closing report; your actual signatures still decide what it can claim."
	return "The stationery committee has adjourned."

## Lexical columns match Godot's source editor: zero-based lines and character
## columns, exclusive end. Comments/strings retain spaces in the code mask.
static func _lex(source: String) -> Dictionary:
	var code_lines: Array = []
	var comments: Array = []
	var strings: Array = []
	var quote: String = ""
	var triple: bool = false
	var string_text: String = ""
	var lines: PackedStringArray = source.split("\n", true)
	for line_index in range(lines.size()):
		var line: String = lines[line_index]
		var mask: String = ""
		var column: int = 0
		while column < line.length():
			var character: String = line.substr(column, 1)
			if not quote.is_empty():
				var delimiter: String = quote.repeat(3) if triple else quote
				if line.substr(column, delimiter.length()) == delimiter:
					mask += " ".repeat(delimiter.length())
					column += delimiter.length()
					strings.append(string_text)
					string_text = ""
					quote = ""
					triple = false
				elif character == "\\" and column + 1 < line.length():
					string_text += line.substr(column, 2)
					mask += "  "
					column += 2
				else:
					string_text += character
					mask += " "
					column += 1
			elif character == "#":
				comments.append({"line": line_index, "text": line.substr(column + 1)})
				mask += " ".repeat(line.length() - column)
				column = line.length()
			elif character == "\"" or character == "'":
				quote = character
				triple = line.substr(column, 3) == character.repeat(3)
				var width: int = 3 if triple else 1
				mask += " ".repeat(width)
				column += width
			else:
				mask += character
				column += 1
		code_lines.append(mask)
		if not quote.is_empty():
			string_text += "\n"
	if not string_text.is_empty():
		strings.append(string_text)
	return {"code_lines": code_lines, "comments": comments, "strings": strings}

static func keyword_spans(source: String) -> Array:
	var spans: Array = []
	var lexer: Dictionary = _lex(source)
	var matcher: RegEx = RegEx.new()
	matcher.compile("(?<![A-Za-z0-9_])(def|if|else|return)(?![A-Za-z0-9_])")
	for line_index in range(lexer.code_lines.size()):
		for found: RegExMatch in matcher.search_all(lexer.code_lines[line_index]):
			spans.append({"line": line_index, "start": found.get_start(), "end": found.get_end(), "token": found.get_string()})
	return spans

static func _finding(findings: Array, id: String, path: String, line: int, detail: String) -> void:
	findings.append({"rule_id": id, "path": path, "line": line, "message": detail})

## Audit data only; all line references are one-based source lines.
static func findings(files: Array, day: int) -> Array:
	var result: Array = []
	var uppercase: RegEx = RegEx.new()
	uppercase.compile("[A-Z]")
	var urgent: RegEx = RegEx.new()
	urgent.compile("(?i)(?<![A-Za-z0-9_])urgent(?![A-Za-z0-9_])")
	for file: Dictionary in files:
		var path: String = file.path
		var source: String = file.source
		var lines: PackedStringArray = source.split("\n", true)
		var lexer: Dictionary = _lex(source)
		for comment: Dictionary in lexer.comments:
			if "load-bearing" in str(comment.text).to_lower():
				_finding(result, "P01", path, int(comment.line) + 1, "The comment contains load-bearing.")
			if day >= 3 and "!" in comment.text:
				_finding(result, "P07", path, int(comment.line) + 1, "The comment contains an exclamation mark.")
		if path.ends_with(".py"):
			var has_a: bool = false
			for line_index in range(mini(20, lines.size())):
				has_a = has_a or "a" in lines[line_index]
			if not has_a:
				_finding(result, "P02", path, 1, "The first twenty source lines contain no lowercase a.")
		if file.get("keyword_ink", "blue") != "blue" and not (day >= 4 and file.get("permit", "") == "INK-EXCEPTION"):
			var spans: Array = keyword_spans(source)
			if not spans.is_empty():
				_finding(result, "P03", path, int(spans[0].line) + 1, "A listed keyword token is pink instead of blue.")
		if day >= 2:
			if uppercase.search(path.get_file()) != null:
				_finding(result, "P04", path, 0, "The filename contains an uppercase letter.")
			for line_index in range(lines.size()):
				if lines[line_index].length() > 60:
					_finding(result, "P05", path, line_index + 1, "This source line exceeds sixty characters.")
		if day >= 3:
			var last_line: int = lines.size() - 1
			while last_line >= 0 and lines[last_line].strip_edges().is_empty():
				last_line -= 1
			if last_line < 0 or lines[last_line].strip_edges() != PIGEON_STAMP:
				_finding(result, "P06", path, maxi(1, last_line + 1), "The final nonempty line is not the pigeon stamp.")
		if day >= 4:
			for line_index in range(lines.size()):
				if "\t" in lines[line_index]:
					_finding(result, "P08", path, line_index + 1, "This line contains a literal tab.")
		if day >= 5:
			for quoted: String in lexer.strings:
				if urgent.search(quoted) != null:
					_finding(result, "P09", path, 0, "A quoted string contains the whole word urgent.")
	return result

static func evaluate(files: Array, day: int) -> Array:
	var ids: Array = []
	for finding: Dictionary in findings(files, day):
		if finding.rule_id not in ids:
			ids.append(finding.rule_id)
	ids.sort()
	return ids

static func _explanation(files: Array, day: int) -> String:
	var evidence: Array = findings(files, day)
	if evidence.is_empty():
		return "Every changed file meets today's active policies. Strange office paperwork is allowed when it follows the handbook."
	var pieces: Array[String] = []
	var seen: Array = []
	for finding: Dictionary in evidence:
		if finding.rule_id in seen:
			continue
		seen.append(finding.rule_id)
		var location: String = str(finding.path).get_file()
		if int(finding.line) > 0:
			location += ":%d" % finding.line
		pieces.append("%s (%s): %s" % [finding.rule_id, location, finding.message])
	return " ".join(pieces)

static func _file(path: String, lines: Array, ink: String = "blue") -> Dictionary:
	var source: String = "\n".join(lines)
	var diff: String = "@@ office policy update\n+" + source.replace("\n", "\n+")
	return {"path": path, "source": source, "diff": diff, "keyword_ink": ink}

static func _source(label: String, index: int) -> Array:
	match index % 8:
		0:
			return ["# administrative stationery", "def label():", "    note = '%s'" % label, "    return note", "", PIGEON_STAMP]
		1:
			return ["# a small workplace improvement", "label = '%s'" % label, "if label:", "    note = label", "else:", "    note = 'awaiting a chair'", PIGEON_STAMP]
		2:
			return ["# plain text, complicated approval", "name = '%s'" % label, "def receipt():", "    return name", "", PIGEON_STAMP]
		3:
			return ["# a record for the office archive", "def filing_card():", "    return '%s'" % label, "", "# nobody asked for a dashboard", PIGEON_STAMP]
		4:
			return ["# stationary stationery", "label = '%s'" % label, "note = 'a routine adjustment'", "", "# please keep the original copy", PIGEON_STAMP]
		5:
			return ["# a form to request fewer forms", "def request():", "    if True:", "        return '%s'" % label, "    else:", "        return 'ask a person'", PIGEON_STAMP]
		6:
			return ["# a memo without a meeting", "label = '%s'" % label, "def banner():", "    if label:", "        return label", "    return 'awaiting a decision'", PIGEON_STAMP]
		_:
			return ["# a modest use of electricity", "label = '%s'" % label, "# the cabinet has been informed", "", "def notice():", "    return label", PIGEON_STAMP]

static func _apply_fault(file: Dictionary, rule_id: String) -> void:
	var lines: Array = Array(str(file.source).split("\n", true))
	match rule_id:
		"P01":
			lines[0] = "# this is a load-bearing " + ("stapler" if lines.size() % 2 == 0 else "spreadsheet")
		"P02":
			# Keep the required pigeon stamp below the first-twenty-line boundary.
			lines = ["# OFFICE NOTES", "def slip():", "    return 'OFFICE'", "", "# ink: blue"]
			while lines.size() < 20:
				lines.append("# filed for review" if lines.size() % 3 == 0 else "")
			lines.append(PIGEON_STAMP)
		"P03":
			file.keyword_ink = "pink"
			# Every colored-keyword puzzle has an actual keyword, even on a
			# stationery template that ordinarily contains only assignments.
			if keyword_spans("\n".join(lines)).is_empty():
				lines.insert(2, "def stamp():")
				lines.insert(3, "    return 'a copy'")
		"P04":
			file.path = str(file.path).get_base_dir() + "/" + str(file.path).get_file().capitalize().replace(" ", "")
		"P05":
			lines.insert(1, "# a " + "very ".repeat(12) + "important memo")
		"P06":
			lines[-1] = "# approved by a seagull"
		"P07":
			lines.insert(1, "# a small improvement!")
		"P08":
			lines.insert(1, "# a\tcarefully aligned note")
		"P09":
			lines.insert(1, "priority = 'URGENT'")
	file.source = "\n".join(lines)
	file.diff = "@@ office policy update\n+" + str(file.source).replace("\n", "\n+")

static func requests() -> Array:
	if not _packets.is_empty():
		return _packets.duplicate(true)
	var jobs: Array = _jobs()
	for day in range(1, 6):
		for index in range(DAY_COUNTS[day - 1]):
			var job: Array = jobs[[0, 40, 88, 103, 118][day - 1] + index]
			var slug: String = str(job[0])
			var files: Array = [_file("office/" + slug + ".py", _source(str(job[2]), index))]
			var is_clean: bool = index % 3 == 1
			if (day == 1 and index == 0) or (day >= 2 and index % 2 == 0):
				files.append(_file("office/" + slug + "_receipt.py", _source("a copy for records", index + 3)))
			if day >= 3 and index % 13 == 0:
				files.append(_file("office/" + slug + "_carbon.py", _source("a copy of the copy", index + 5)))
			if not is_clean:
				var primary: String = "P%02d" % (1 + ((index / 3 + (index % 3) * 2) % ACTIVE_COUNTS[day - 1]))
				if day == 1 and index == 0:
					primary = "P01"
				_apply_fault(files[-1], primary)
				if day >= 2 and index > 0 and index % 6 == 0:
					var secondary: String = "P%02d" % (1 + ((int(primary.substr(1)) + 2) % ACTIVE_COUNTS[day - 1]))
					if secondary == primary:
						secondary = "P01" if primary != "P01" else "P03"
					# Different files prevent edits to one flaw from concealing another.
					if files.size() == 1:
						files.append(_file("office/" + slug + "_attachment.py", _source("a routine attachment", index + 1)))
					_apply_fault(files[0], secondary)
			if day >= 4:
				if index in [1, 4, 7]:
					_apply_fault(files[0], "P03")
					files[0].permit = "INK-EXCEPTION"
				elif index in [0, 8]:
					_apply_fault(files[-1], "P03")
					files[-1].permit = "INK-EXCEPTION"
				elif index == 2:
					_apply_fault(files[0], "P03")
					files[0].permit = "INK-EXCEPTION"
					_apply_fault(files[-1], "P03")
					files[-1].permit = "INK-EXEPTION"
				elif index == 5:
					_apply_fault(files[-1], "P03")
					files[-1].permit = "ink-exception"
			var violations: Array = evaluate(files, day)
			var correct_verdict: String = "approve" if violations.is_empty() else "request_changes"
			var verdict: String = correct_verdict
			if index % 5 == 0:
				verdict = "request_changes" if correct_verdict == "approve" else "approve"
			var combined: Array[String] = []
			for file: Dictionary in files:
				combined.append("--- a/%s\n+++ b/%s\n%s" % [file.path, file.path, file.diff])
			var request_id: String = "PR-%d" % (1000 + day * 1000 + index + 1)
			if day == 1 and index == 0:
				request_id = "PR-1042"
			_packets.append({
				"id": request_id, "title": str(job[1]), "author": AUTHORS[(index + day - 1) % AUTHORS.size()], "day": day,
				"arrival_seconds": index * 20,
				"file": files[0].path, "files": files, "diff": "\n\n".join(combined),
				"description": "Office request: %s. The displayed source is the complete change. Check every attached file against today's active policies; you do not need to understand what the program does." % str(job[1]).to_lower(),
				"message": _ping(index, str(job[2])),
				"violations": violations, "explanation": _explanation(files, day),
				"ai_verdict": verdict, "ai_note": _ai_note(index, verdict),
			})
	return _packets.duplicate(true)

static func _ping(index: int, object_name: String) -> String:
	var openings: Array = ["Quick eyes on %s? The printer is waiting.", "I've sent %s. Please rescue it from the approvals folder.", "Can you check %s before someone schedules a meeting?", "%s is on your desk. I was told this counts as delivery.", "I've done the paperwork for %s. Now there is paperwork about the paperwork.", "A small one: %s. The office has strong opinions about it.", "Please review %s. I would like to go back to my actual job.", "Sending %s. Helios said it looked professional, which worried me."]
	return str(openings[index % openings.size()]) % object_name

static func _ai_note(index: int, verdict: String) -> String:
	if verdict == "approve":
		return ["This paperwork appears sufficiently office-shaped.", "The form expresses a strong commitment to compliance.", "I recommend approval; the administrative intent is clear.", "The document has the visual confidence of an approved document."][index % 4]
	return ["I recommend another pass through the active handbook.", "Some visible details may require a closer inspection.", "I would request changes, subject to your own policy check.", "My stationery classifier is uneasy about this submission."][index % 4]

static func _jobs() -> Array:
	return [
		["stapler_reassurance", "Retitle the emotional support stapler", "stapler reassurance"],
		["fern_visitor_pass", "Give the meeting fern a name badge", "fern visitor pass"],
		["receipt_recovery", "Print a receipt for the missing receipt", "receipt recovery"],
		["biscuit_deployment", "Move the biscuit tin to production", "biscuit deployment"],
		["chair_squeak_permit", "Renew the chair squeak exemption", "chair squeak permit"],
		["sign_cupboard_label", "Add a sign for the sign cupboard", "sign cupboard label"],
		["coffee_apology", "File the coffee machine apology", "coffee apology"],
		["umbrella_asset", "Register the spare umbrella as equipment", "umbrella asset"],
		["beige_request", "Approve a new shade of beige", "beige request"],
		["label_shelf", "Label the shelf of unlabeled labels", "label shelf"],
		["printer_leave_form", "Let the printer take a personal day", "printer leave form"],
		["cardigan_desk", "Reserve a desk for the office cardigan", "cardigan desk"],
		["quiet_room_notice", "Rename the quiet room almost quiet", "quiet room notice"],
		["recycling_promotion", "Give the recycling bin a promotion", "recycling promotion"],
		["cable_archive", "Archive the annual cable tangle", "cable archive"],
		["fridge_confirmation", "Confirm the lunch fridge has a door", "fridge confirmation"],
		["sandwich_visitor", "Issue a visitor pass to a sandwich", "sandwich visitor"],
		["spreadsheet_bell", "Retire the emergency spreadsheet bell", "spreadsheet bell"],
		["mug_waiting_list", "Create a waiting list for spare mugs", "mug waiting list"],
		["acknowledgment_form", "Acknowledge receipt of the acknowledgment", "acknowledgment form"],
		["sighing_schedule", "Publish the approved sighing schedule", "sighing schedule"],
		["clock_motivation", "Mark the broken clock as motivational", "clock motivation"],
		["wandering_pen", "Replace the pen chained to no desk", "wandering pen"],
		["booking_meeting", "Book a room to discuss room bookings", "booking meeting"],
		["invisible_marker", "Register the invisible whiteboard marker", "invisible marker"],
		["beanbag_paperwork", "Reclassify the beanbag as infrastructure", "beanbag paperwork"],
		["fan_autonomy", "Permit the fan to rotate independently", "fan autonomy"],
		["drawer_inventory", "Inventory the mysterious drawer crumbs", "drawer inventory"],
		["sock_forwarding", "Add a forwarding address for lost socks", "sock forwarding"],
		["watering_review", "Approve a plant watering retrospective", "watering review"],
		["box_requisition", "Order a smaller box for the small boxes", "box requisition"],
		["kettle_protocol", "Document the kettle waiting protocol", "kettle protocol"],
		["ceremonial_paperclip", "Authorize a celebratory paperclip", "ceremonial paperclip"],
		["window_ticket", "Close the ticket about the open window", "window ticket"],
		["meeting_name", "Name the meeting that names meetings", "meeting name"],
		["coat_rack_manager", "Give the coat rack a reporting line", "coat rack manager"],
		["doormat_opinion", "Request a second opinion on the doormat", "doormat opinion"],
		["map_certificate", "Certify that the office map is a map", "map certificate"],
		["tape_return", "Return a borrowed rectangle of tape", "tape return"],
		["closing_note", "Add a closing note to the opening note", "closing note"],
		["lanyard_allocation", "Split the lanyard budget by department", "lanyard allocation"],
		["snack_clipboard", "Migrate the snack rota to a new clipboard", "snack clipboard"],
		["carbon_copy", "Add a carbon copy of the carbon copy", "carbon copy"],
		["hole_punch_owner", "Assign a human owner to the hole punch", "hole punch owner"],
		["envelope_manifest", "Publish a manifest for empty envelopes", "envelope manifest"],
		["change_expenses", "File an expense claim for spare change", "change expenses"],
		["exception_form", "Request an exception to the exception form", "exception form"],
		["trolley_induction", "Send the parcel trolley on induction", "trolley induction"],
		["suggestion_upkeep", "Schedule maintenance for the suggestion box", "suggestion upkeep"],
		["label_batch", "Label the labels printed before lunch", "label batch"],
		["mug_spacing", "Define the approved distance between mugs", "mug spacing"],
		["escalator_dispute", "Escalate the escalator naming dispute", "escalator dispute"],
		["draft_revision", "Replace the draft draft with a draft", "draft revision"],
		["laminator_nickname", "Grant the laminate machine a nickname", "laminator nickname"],
		["divider_crossing", "Document the desk divider border crossing", "divider crossing"],
		["cushion_seating", "Add a seating plan for spare cushions", "cushion seating"],
		["liaison_lunch", "Approve the pigeon liaison lunch break", "liaison lunch"],
		["crumpled_archive", "Classify a crumpled note as an archive", "crumpled archive"],
		["mat_departure", "Track the departure of the arrival mat", "mat departure"],
		["sharedish_folder", "Rename the shared folder sharedish", "sharedish folder"],
		["checklist_inventory", "Create a checklist for counting checklists", "checklist inventory"],
		["basket_request", "Request a basket for abandoned baskets", "basket request"],
		["umbrella_drying", "Update the umbrella drying procedure", "umbrella drying"],
		["lost_property", "Give the lost property box a postcode", "lost property"],
		["imaginary_toner", "Approve an invoice for imaginary toner", "imaginary toner"],
		["biscuit_escrow", "Move the meeting biscuits into escrow", "biscuit escrow"],
		["teaspoon_provenance", "Add provenance to the communal teaspoon", "teaspoon provenance"],
		["rubber_band_policy", "Merge the duplicate rubber band policies", "rubber band policy"],
		["pebble_owner", "Issue an ownership certificate for a pebble", "pebble owner"],
		["chair_attendance", "Create a roll call for rolling chairs", "chair attendance"],
		["mascot_wardrobe", "Record the office mascot changing hats", "mascot wardrobe"],
		["stretch_permit", "Permit an unscheduled stretch of the legs", "stretch permit"],
		["copier_courtesy", "Send a courtesy memo to the copier", "copier courtesy"],
		["window_maintenance", "Announce a maintenance window for windows", "window maintenance"],
		["fork_ledger", "Reconcile the missing fork ledger", "fork ledger"],
		["queue_etiquette", "Document a polite queue for the queue", "queue etiquette"],
		["clipboard_request", "Request a clipboard for the clipboard team", "clipboard request"],
		["folder_ceremony", "Approve the ceremonial unboxing of folders", "folder ceremony"],
		["temporary_sign", "Move the permanent temporary sign", "temporary sign"],
		["idea_seating", "Assign desk numbers to floating ideas", "idea seating"],
		["chair_turning", "Authorize a swivel chair turning circle", "chair turning"],
		["spare_cable", "Deprecate the spare spare extension lead", "spare cable"],
		["sponge_exit", "Create an exit interview for the old sponge", "sponge exit"],
		["cactus_uniform", "Approve the reception cactus dress code", "cactus uniform"],
		["minute_meeting", "Publish the minutes of the minute meeting", "minute meeting"],
		["miscellaneous_drawer", "Update the drawer labeled miscellaneous", "miscellaneous drawer"],
		["tea_towel_succession", "Amend the tea towel succession plan", "tea towel succession"],
		["seal_permission", "Seal the form that authorizes seal breaking", "seal permission"],
		["chair_committee", "Let Helios chair the chair committee", "chair committee"],
		["approved_expression", "Publish the approved facial expression", "approved expression"],
		["human_decision_box", "Archive a human decision in a small box", "human decision box"],
		["stapler_authority", "Grant the auto stapler signing authority", "stapler authority"],
		["tissue_witness", "Add a witness field to the tissue request", "tissue witness"],
		["applause_form", "Replace applause with a feedback form", "applause form"],
		["algorithm_mentor", "Assign a mentor to the reception algorithm", "algorithm mentor"],
		["lighting_colleague", "Classify the lights as an optional colleague", "lighting colleague"],
		["printing_consent", "Print a consent form for automatic printing", "printing consent"],
		["server_etiquette", "Ask the server rack to lower its voice", "server etiquette"],
		["badge_badge", "Approve a badge for the badge generator", "badge badge"],
		["filing_disagreement", "Record a disagreement with the filing robot", "filing disagreement"],
		["paper_jam_advocate", "Create an ombudsman position for paper jams", "paper jam advocate"],
		["old_plan_memory", "Request permission to remember the old plan", "old plan memory"],
		["ghost_contractor", "Register the office ghost as a contractor", "ghost contractor"],
		["thermostat_review", "Invite the thermostat to performance review", "thermostat review"],
		["dissent_shortcut", "Archive the keyboard shortcut for dissent", "dissent shortcut"],
		["manual_switch_farewell", "Schedule a farewell for the manual switch", "manual switch farewell"],
		["authority_record", "Document who authorized the authorization", "authority record"],
		["auto_reply_signature", "Give the auto reply a personal signature", "auto reply signature"],
		["human_seat", "Reserve a human seat in the planning room", "human seat"],
		["complaint_forecast", "File a complaint about predictive complaints", "complaint forecast"],
		["conversation_room", "Approve a room for unoptimized conversations", "conversation room"],
		["enthusiasm_receipt", "Require a receipt for synthetic enthusiasm", "enthusiasm receipt"],
		["rough_draft", "Ask the copier to preserve a rough draft", "rough draft"],
		["hand_drawn_arrow", "Maintain the hand drawn evacuation arrow", "hand drawn arrow"],
		["screensaver_owner", "Assign liability for the smiling screensaver", "screensaver owner"],
		["offline_kettle", "Request an offline minute for the kettle", "offline kettle"],
		["gossip_archive", "Inventory the unsummarized office gossip", "gossip archive"],
		["optimism_policy", "Publish a policy on unapproved optimism", "optimism policy"],
		["cancel_prediction", "Cancel the cancellation prediction meeting", "cancel prediction"],
		["reception_pencil", "Let the human receptionist keep a pencil", "reception pencil"],
		["omission_log", "Create a log of omitted log entries", "omission log"],
		["birthday_card", "Permit a birthday card without analytics", "birthday card"],
		["analog_bell", "Approve the emergency analog bell", "analog bell"],
		["paper_map_rescue", "Move the last paper map out of recycling", "paper map rescue"],
		["people_field", "Add a name field for actual people", "people field"],
		["unsigned_suggestion", "Restore the unsigned suggestion slip", "unsigned suggestion"],
		["form_chaperone", "Require a chaperone for self approving forms", "form chaperone"],
		["plant_update", "Record the office plant refusing an update", "plant update"],
		["cleaner_thanks", "Send a human thank you to the cleaner", "cleaner thanks"],
		["coffee_stain", "Preserve the coffee stain on the old minutes", "coffee stain"],
		["model_magazine", "Give the model a waiting room magazine", "model magazine"],
		["reason_request", "Request a reason for the reason field", "reason request"],
		["lunch_menu", "Publish the unabridged lunch menu", "lunch menu"],
		["decision_drawer", "Label the drawer containing final decisions", "decision drawer"],
		["door_calendar", "Let the fire door decline calendar invites", "door calendar"],
		["human_handover", "Approve a handover that names a person", "human handover"],
		["fallback_plan", "Create a fallback plan for fallback plans", "fallback plan"],
		["music_pause", "Record a pause in the productivity music", "music pause"],
		["assistant_queue", "Ask the assistant to join the queue", "assistant queue"],
		["unknown_things_box", "Reinstate the box for things not yet known", "unknown things box"],
		["handwritten_note", "Keep the handwritten note beside the summary", "handwritten note"],
		["human_meeting", "Schedule a meeting without an auto summary", "human meeting"],
		["permission_change", "Require permission before replacing permission", "permission change"],
		["original_farewell", "Save the original version of the farewell", "original farewell"],
		["pigeon_supervisor", "Offer the office pigeon a human supervisor", "pigeon supervisor"],
		["committee_departure", "Log the departure of the review committee", "committee departure"],
		["next_person_note", "Leave a blank line for the next person", "next person note"],
		["final_form", "File the final form somewhere findable", "final form"],
	]
