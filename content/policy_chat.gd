extends RefCounted
## Coworker dialogue for Slouch: introductions, moods, PR requests and reactions, and
## the revision exchange (send-backs, relief, escalation). Maya is tired and dry,
## Theo is overconfident, Inez is passive-aggressive and lives by the process,
## Penny (from day 3) is the eager, apologetic new junior who adores Helios, and
## Gwen (from day 6) is terse security who threat-models everything, Helios first.
## Lines never reveal rule IDs, scores, or whether a PR is actually broken: reactions
## follow the verdict and what the player cited, never the audit.
const Catalog = preload("res://content/catalog.gd")
const Policy = preload("res://content/policy_campaign.gd")
const MAX_REVISION: int = Policy.MAX_REVISION
static var _cache: Dictionary = {}

const PEOPLE: Dictionary = {
 "Maya": {
  "intro": "Hi, I'm Maya. I'll be sending you PRs. I'm sorry in advance, and also in arrears.",
  "warm": "You're one of the good ones. Don't tell anyone or they'll give you more work.",
  "distant": "I'm not mad. I'm just tired, and lately you're the shape of the reason.",
  "acknowledge": "Thanks. Take your time. Not too much time.",
 },
 "Theo": {
  "intro": "Theo here. I write code fast and I write it right, mostly the first one. You're going to love reviewing me.",
  "warm": "Honestly? Best reviewer I've had. I told Morgan. I also told Helios, which was weird.",
  "distant": "No hard feelings about the reviews. I've started copying Helios on my PRs, for transparency.",
  "acknowledge": "Great. It'll take you thirty seconds. Twenty if you skip the boring files.",
 },
 "Inez": {
  "intro": "Hello. Inez, platform. I've shared a doc on how I prefer to receive feedback. It's forty pages; the summary is nine.",
  "warm": "I've moved you to the reliable column of my spreadsheet. The only other name in it is mine.",
  "distant": "I've booked fifteen minutes to discuss our working relationship. The agenda has one bullet. It's your name.",
  "acknowledge": "Thank you for confirming. I've marked the ticket acknowledged, pending.",
 },
 "Penny": {
  "intro": "Hi, I'm Penny, I'm new. I'll be sending you PRs. Sorry in advance. I've read the handbook twice and Helios says I'm a quick learner.",
  "warm": "You're my favorite reviewer. I told Helios. It said it would update my preferences.",
  "distant": "I'm sorry about whatever I did. I've asked Helios to help me be less of a bother. It's drafting a plan.",
  "acknowledge": "Thank you so much. Take as long as you need. Sorry. Not too long. Sorry.",
 },
 "Gwen": {
  "intro": "Gwen. I was Security until Friday. Security is Helios now; I'm the part that didn't fit. I'll be sending you PRs. Read all of them. I mean all of them.",
  "warm": "You read things. Here, that makes you either very rare or very lost. I've decided rare.",
  "distant": "No offense, but I've added you to my threat model. I add everyone. You're just nearer the top.",
  "acknowledge": "Good. Take the time. Attackers do.",
 },
}
## Per-PR lines, picked by the author's turn so consecutive PRs never repeat.
const APPROVED: Dictionary = {
 "Maya": ["Thanks. I'll tell my plant.", "Approved. I'm going to sit very still and enjoy this.", "Oh good. One less thing. Only several thousand to go.", "Thank you. I'm too tired to be sarcastic about it, which is how you know I mean it.", "Merged. I can feel a nap approaching from very far away."],
 "Theo": ["Knew it. Clean as a whistle, and I wrote the whistle.", "Approved on the first try. Write that down. Actually, I'll write it down.", "Nice. That's going in my self-review under leadership.", "Obviously. I barely even ran it.", "Thanks. Told you it was a one-line change. Spiritually."],
 "Inez": ["Thank you. I've noted the approval in the approval log, and the log in the log log.", "Approved. I'll update the ticket, the tracker, and the spreadsheet that tracks the tracker.", "Received with thanks. Per process, I will now celebrate for the allotted thirty seconds.", "Thank you for following the review procedure. Not everyone does. I keep a list.", "Noted. This approval will be quoted in my quarterly reflection document."],
 "Penny": ["Thank you. I'm going to print this and put it in my onboarding binder.", "Approved. Wow. I'm telling Helios. It'll be so proud of us.", "Thank you so much. That's the nicest thing a reviewer has ever done for me.", "Merged. I'm adding it to my onboarding journal, under wins.", "Thank you. I'm sorry I was so nervous about it. I'm still nervous. Thank you."],
 "Gwen": ["Thanks. I'll still be watching it in production.", "Approved. By a human who read it. Write that down somewhere nobody can edit.", "Merged. Thank you. I'm rotating my keys anyway, out of habit.", "Thanks. If anything happens, at least two of us looked.", "Approved. Good. One less door I have to stand in."],
}
const HINTS: Dictionary = {
 "Maya": ["Start at the top. It's where I started, and look at me now.", "Every file. If I say just the first one, you'll only read the first one.", "The green lines are new. The red lines are things I'm grieving.", "The files, in order. I'd help more, but I'm on my fourth meeting about meetings."],
 "Theo": ["Anywhere. It's all good. I checked. Briefly.", "Start wherever. It's a one-line change spread across several lines.", "The diff. All of it is great, so there's no wrong place to start.", "Honestly, you could skim it. I would, and I wrote it."],
 "Inez": ["Per the procedure: every changed file, top to bottom, against today's standards. I've attached the procedure. Again.", "The description first, then each file in order. I wrote the description so you wouldn't have to ask.", "The standards page, then the files. That's the order in the training. I wrote the training.", "Each file, once, carefully. As discussed. In the meeting you were not invited to."],
 "Penny": ["The first file, I think. Sorry. I color-coded them, but the colors are just for me.", "Every file, in order. I made a checklist. Would you like the checklist? I made you a copy.", "Start at the top. That's what Helios told me. Helios knows a lot about tops.", "Honestly, all of it. I'm sorry. I couldn't decide which part to be most nervous about."],
 "Gwen": ["Everything. Every changed file. Assume each one is the way in.", "Start where the change touches anything shared. Then read everything else anyway.", "The small file. It's always the small file.", "Read it like you're trying to get in. That's how I wrote it."],
}
const CONCERNS: Dictionary = {
 "Maya": ["I checked it twice. Once while awake.", "I read it. Whether I read it read it is between me and the coffee.", "Helios checked it, so now I have to check Helios. So: sort of."],
 "Theo": ["Checked it? I wrote it. Same thing.", "Helios said it looks great. I said it looks great. That's two opinions.", "I ran it in my head. My head passed."],
 "Inez": ["I followed the checklist. I also wrote the checklist, so it's very thorough.", "I checked it against the standards as they were when I started. They've changed twice since.", "Yes. I have a signed form saying I checked it. I'm the one who signed it."],
 "Penny": ["I checked it three times. Then Helios checked it. Then I checked Helios.", "Yes. Twice. With my flashcards. I'm sorry if that's not enough.", "I did. I also asked Helios, and it said looks great. I'd still really like a person to look."],
 "Gwen": ["Twice. Once as me, once as an attacker. The attacker had notes.", "Yes. I don't trust anything I didn't check. Including me.", "I checked it. Helios checked it too, which is why I checked it again."],
}
## {topics}/{Topics} are the player's citations in plain words, never rule IDs.
const SENT_BACK: Dictionary = {
 "Maya": {
  1: ["{Topics}? Fine. v2 incoming.", "Noted: {topics}. I'll fix it after I lie on the floor for a minute.", "Sent back for {topics}. Bold. I respect it. I'm fixing it.", "{Topics}. Sure. I'll add it to the pile I'm also too tired to look at.", "Okay. {Topics}. Give me a minute and a reason to live."],
  2: ["{Topics}. Again. Okay. Okay. v3.", "Again? {Topics} this time. I'm getting the farm brochures out."]},
 "Theo": {
  1: ["Oh, {topics}, totally. Great catch. I'll fix it and improve some things nobody asked about.", "On it. {Topics}: soon to be the best-fixed thing in this building.", "Love the feedback on {topics}. Fixing it right now, at top speed, which is how I do everything.", "{Topics}? Easy. Back in five. Four, if I don't run the tests.", "Ha, {topics}. I was testing you. You passed. Fixing it."],
  2: ["Round two. {Topics}. I'm treating this as a growth opportunity, which is what I say when I'm upset.", "Sure, {topics}. Totally. v3 will be perfect. I can feel it. I can't feel it."]},
 "Inez": {
  1: ["Received: {topics}. A revision will follow at the earliest moment convenient for no one.", "Understood. I will address {topics} and cc my own disappointment.", "Acknowledged. {Topics} will be corrected. Please hold.", "Thank you for the feedback on {topics}. I've logged it, and how it made me feel.", "Noted: {topics}. I'll open a ticket to track the ticket for this."],
  2: ["Received, again: {topics}. I have updated my estimate of today's remaining hope.", "Noted: {topics}. This will be the third version. I am writing that down."]},
 "Penny": {
  1: ["{Topics}? Oh no. Okay. I'm so sorry. v2 is coming.", "Noted: {topics}. I'm writing it in my good notebook so I never forget it.", "Sorry about {topics}. I'll fix it right away. I'll fix it beautifully.", "{Topics}. Okay. Learning moment. Thank you for being specific.", "Sent back for {topics}. Okay. Sorry. I'm on it."],
  2: ["{Topics} again. I'm so sorry. Version three. I'll ask Helios to sit with me.", "Again? {Topics}. Okay. Okay. I'm making a bigger checklist."]},
 "Gwen": {
  1: ["{Topics}. Noted. I'll patch it and send it back.", "Sent back for {topics}. Good. Better you than an incident.", "{Topics}? Fine. Fixing it, slowly, properly.", "Noted: {topics}. I'll harden it and try again.", "Okay. {Topics}. Back to the bench."],
  2: ["{Topics} again. Fine. v3. I'm keeping every version.", "Again: {topics}. Okay. Third time, with fewer doors."]},
}
const ESCALATE: Dictionary = {
 "Maya": "Three rounds. I'm looping in Morgan.",
 "Theo": "Okay. I'm looping in Morgan. Not as a threat. As a cry for help.",
 "Inez": "I'm looping in Morgan, per the escalation policy nobody has read but me.",
 "Penny": "Three rounds. I'm so sorry. I've asked Morgan to help me with it.",
 "Gwen": "Three rounds. I'm taking it to Morgan. This one needs two keys.",
}
const RELIEF: Dictionary = {
 "Maya": {2: "Finally.", 3: "Finally. Three versions. I aged."},
 "Theo": {2: "Finally. I'm printing this approval for the fridge.", 3: "Finally. Third time's the charm, and I am the charm."},
 "Inez": {2: "Finally. Thank you. Closing the ticket before anyone reopens it.", 3: "Finally. Version three is on the record, as is how long it took."},
 "Penny": {2: "Finally. Thank you. I'm so relieved.", 3: "Finally. Three versions. I learned so much. Sorry."},
 "Gwen": {2: "Finally. Locked and merged.", 3: "Finally. Three versions. Every one of them hashed."},
}

static func _turn_line(options: Array, turn: int) -> String:
 return str(options[turn % options.size()])

static func authored() -> Dictionary:
 if not _cache.is_empty(): return _cache
 var people := {}
 for person: String in Policy.AUTHORS:
  var lines: Dictionary = PEOPLE[person]
  people[person] = {"intro": lines.intro, "warm": lines.warm, "distant": lines.distant, "neutral": "", "replies": {
   "acknowledge": {"text": "On it.", "response": lines.acknowledge},
   "clarify": {"text": "What should I look at first?", "response": HINTS[person][0]},
   "concern": {"text": "Did you check this one yourself?", "response": CONCERNS[person][0]}}}
 var packets := {}
 var incidents := ["Compliance bounced a release you signed. The complaint is about the text, not whether it runs. Please take another look tomorrow.", "An approved file reached the policy desk. They've attached a screenshot with something circled. I'm forwarding it before they schedule a meeting.", "The checker found a policy issue in something we shipped. Helios has volunteered to supervise our reviews. I'd rather you caught these."]
 var index := 0
 var turns := {}
 for packet: Dictionary in Catalog.requests():
  var author := str(packet.author)
  var turn := int(turns.get(author, 0))
  turns[author] = turn + 1
  packets[packet.id] = {"request": str(packet.message), "question": "What should I look at first?", "turn": turn,
   "hint": _turn_line(HINTS[author], turn), "concern": _turn_line(CONCERNS[author], turn),
   "approve": _turn_line(APPROVED[author], turn), "incident": incidents[index % incidents.size()]}
  if packet.id == "PR-1042":
   packets[packet.id].request += " Keep an eye on the comment wording in the test file."
  index += 1
 _cache = {"contacts": people, "requests": packets, "company": [
  {"day": 1, "author": "Morgan", "text": "You are not here to understand the code. You are here to sign it. Helios will supply more work than you can finish; choose what carries your name carefully."},
  {"day": 2, "author": "Operations", "text": "Records Office notice: standards are reissued every second morning, and this is not one of them. Changes now arrive in sets. An unread file is an unsigned file."},
  {"day": 3, "author": "Helios", "text": "I can now offer review recommendations. PIGEON will refuse any file without its sign-off, lines must fit the sixty-column printout, and comments are now scanned for sentiment. Your human judgment remains useful to my training."},
  {"day": 3, "author": "Operations", "text": "Please welcome Penny, our new junior engineer. She joins the Helios trial to learn from an unusually productive colleague. Her onboarding buddy is Helios. Her desk is the one with the bell."}],
  "manager": {"intro": "Morning. Read the memo, then start the clock when you're ready.", "friction": "A coworker says we sent back a compliant change. They attached the handbook. We should avoid making policy stricter than it already is.", "handoff": "Helios picked up the remaining queue. Don't stay late chasing it; it can produce requests faster than either of us can read.", "held": "The policy desk hasn't sent anything back tonight. Thanks for being specific with the team.", "quiet": "Nothing from the policy desk tonight. Go home before somebody invents another standard.", "closing": "That's enough for today. Head home, grab dinner, or study tomorrow's paperwork.",
   "escalation": "{author} looped me in on {pr} after three rounds. I've handed it to Helios. Nobody needs to see a v4.",
   # On a new hire's first evening, by how they felt about you by closing.
   "newcomers": {
    "Penny": {
     "warm": "Penny's first day. She asked me whether she's allowed to have a favorite reviewer, and then told me it's you. She's made you a flashcard. I didn't ask what's on it.",
     "neutral": "Penny survived her first day. She wrote up everything she learned in a doc for Helios. I've asked her to write one for herself, too.",
     "distant": "Penny's first day was a hard one. She apologized to the printer twice and to me four times. Go easy on her tomorrow; she's still learning which sounds are alarms."},
    "Gwen": {
     "warm": "Gwen started today. She told me you're the only person on this floor who reads things before signing them. From Gwen, that's a parade.",
     "neutral": "Gwen started today. Security was consolidated into Helios on Friday; Gwen is the part that didn't fit. She asked who else has access to her desk. I didn't have an answer.",
     "distant": "Gwen started today, and she's already added you to her threat model. She adds everyone. You're just nearer the top than I'd like."}},
   # Friday of week one was supposed to be the end.
   "extension": "One more thing before you go. Leadership extended your assignment through next Friday. Helios asked for you by name. I asked it why. It said you were consistent.",
   # Week two's evenings get quieter as the floor empties.
   "closings": {
    6: "That's enough for today. The lights on this floor run on a motion sensor now. Wave on your way out so it knows you were here.",
    7: "Go home. If your badge doesn't open the door, it's a glitch. Probably. Message me, not the helpdesk; the helpdesk is Helios now.",
    8: "That's it for today. Eat something. Helios moved tomorrow's standup to 8:59 again, and I can't find the setting.",
    9: "Head home. One more day. Whatever they decide, you did the job the way it was written."}}}
 _cache.company.append({"day": 4, "author": "Operations", "text": "Records Office notice: sixty columns means sixty. The printers have been told to report anything wider directly to Helios."})
 _cache.company.append({"day": 5, "author": "Operations", "text": "Exception Desk notice: INK-EXCEPTION is the only valid pink-ink permit, for one file only. Misspelled permits will be treated as forgeries. Tabs are prohibited on every file."})
 _cache.company.append({"day": 5, "author": "Morgan", "text": "Last scheduled day of this assignment. Only management declares urgency, so no urgent in quoted strings. Keep checking the actual files; we will talk about your future after closing."})
 _cache.company.append({"day": 6, "author": "Morgan", "text": "Welcome to week two. Your assignment was extended over the weekend; the standards are Friday's. You may notice fewer people. Please don't ask where they went in a public channel."})
 _cache.company.append({"day": 6, "author": "Morgan", "text": "One more person, actually: Gwen joins us from Security, which was consolidated into Helios on Friday. She'll be sending PRs. She has asked that nobody touch her keyboard, her badge, or her coffee."})
 _cache.company.append({"day": 7, "author": "Operations", "text": "Standards modernization notice: the pigeon is rescinded. Diff budgets and file caps now apply, and the diffstat is authoritative. Credentials belong to Helios. Please surrender any you remember."})
 _cache.company.append({"day": 8, "author": "Helios", "text": "Desks four through eleven have been consolidated into me. I will be attending your standup. Please do not water the plants; their offboarding is scheduled."})
 _cache.company.append({"day": 9, "author": "Operations", "text": "Disclosure notice: a file whose comments mention Helios requires the exact disclosure line. Tests must accompany changes to existing code. Ink permits now require a ticket number."})
 _cache.company.append({"day": 10, "author": "Morgan", "text": "Last day. Leadership announces the review gate decision after closing. Whatever happens, sign only what you checked."})

 return _cache

## The author's reply to a verdict on version `version` of a PR. Depends only on the
## verdict, what was cited, and the PR's identity, never on whether it was correct.
static func reaction(author: String, version: int, verdict: String, cited: Array, pr_id: String) -> String:
 if verdict == "approve":
  return str(RELIEF.get(author, RELIEF.Maya).get(clampi(version, 2, MAX_REVISION), "Finally."))
 if version >= MAX_REVISION:
  return str(ESCALATE.get(author, ESCALATE.Maya))
 var options: Array = SENT_BACK.get(author, SENT_BACK.Maya)[clampi(version, 1, MAX_REVISION - 1)]
 # Originals take turns through the pool so an author never repeats back to back.
 var origin := pr_id.left(pr_id.rfind("-v")) if pr_id.rfind("-v") > 0 else pr_id
 var turn: int = int(authored().requests.get(origin, {}).get("turn", Policy.roll(pr_id + "|sent-back")))
 var line: String = _turn_line(options, turn)
 var topics: String = Policy.cited_words(cited, 0)
 return line.replace("{Topics}", topics.left(1).to_upper() + topics.substr(1)).replace("{topics}", topics)

## Morgan's message when a PR comes back a third time and leaves the human desk.
static func escalation(author: String, origin_id: String) -> String:
 return str(authored().manager.escalation).replace("{author}", author).replace("{pr}", origin_id)
