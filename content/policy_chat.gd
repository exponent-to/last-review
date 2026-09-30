extends RefCounted
## Short, fictional coworker pings for the visual-policy campaign.
const Catalog = preload("res://content/catalog.gd")
static var _cache: Dictionary = {}
static func authored() -> Dictionary:
 if not _cache.is_empty(): return _cache
 var people := {}
 var intros := {"Maya": "Hey. I write the files, you inspect the alphabet. What a time to be alive.", "Theo": "Morning. Apparently we have a pigeon policy now. Please don't ask me who approved the pigeon.", "Inez": "Helios keeps opening PRs. I'm forwarding them as fast as it apologizes."}
 for person: String in intros:
  people[person] = {"intro": intros[person], "warm": "Thanks for keeping things moving. Lunch is on me.", "distant": "Please be specific about what needs changing. I'm running out of polite reaction GIFs.", "neutral": "", "replies": {
   "acknowledge": {"text": "On it.", "response": "Thanks. There are more coming. Sorry."},
   "clarify": {"text": "What should I look at first?", "response": "Check the actual file against today's memo."},
   "concern": {"text": "Did you check this one yourself?", "response": "I checked the summary. That sounded better before I typed it."}}}
 var packets := {}
 var approvals := ["blob thumbs up", "Thank you. Shipping it before the memo changes.", "You're a lifesaver. Helios has already written the next one.", "Approved! I mean, you approved it. I'm just excited."]
 var rejections := ["Fine. I'll fix the paperwork.", "The model says the pigeon was implied. I'll add it.", "Got your note. I miss when spelling wasn't a deployment gate.", "Okay. Please don't send the disappointed blob again."]
 var incidents := ["Compliance bounced a release you signed. The complaint is about the text, not whether it runs. Please take another look tomorrow.", "An approved file reached the policy desk. They've attached a screenshot with something circled. I'm forwarding it before they schedule a meeting.", "The checker found a policy issue in something we shipped. Helios has volunteered to supervise our reviews. I'd rather you caught these."]
 var index := 0
 for packet: Dictionary in Catalog.requests():
  packets[packet.id] = {"request": str(packet.message), "question": "What should I look at first?", "hint": "Open " + str(packet.files[-1].path) + ". Check the comments and keyword ink against the handbook; the generated summary isn't proof.", "concern": "I skimmed it. With this queue, that's the honest answer.", "approve": approvals[index % approvals.size()], "request_changes": rejections[index % rejections.size()], "incident": incidents[index % incidents.size()]}
  if packet.id == "PR-1042": packets[packet.id].hint = "Look for load-bearing in the comments. Management has banned that phrase. Yes, really."
  index += 1
 _cache = {"contacts": people, "requests": packets, "company": [
  {"day": 1, "author": "Morgan", "text": "Today's rules are about letters and colors. You do not need to run the code. Helios will supply more work than you can finish; choose carefully."},
  {"day": 2, "author": "Operations", "text": "New policies cover filenames and line length. More files are coming in pairs. Inspect both."},
  {"day": 3, "author": "Helios", "text": "I can now offer review recommendations. New policies require pigeon sign-offs and prohibit shouting in comments. Your human judgment remains useful to my training."}],
  "manager": {"intro": "Morning. Read the memo, then start the clock when you're ready.", "friction": "A coworker says we sent back a compliant change. They attached the handbook. We should avoid making policy stricter than it already is.", "handoff": "Helios picked up the remaining queue. Don't stay late chasing it; it can produce requests faster than either of us can read.", "held": "The policy desk hasn't sent anything back tonight. Thanks for being specific with the team.", "quiet": "Nothing from the policy desk tonight. Go home before somebody invents another standard.", "closing": "That's enough for today. Head home, grab dinner, or study tomorrow's paperwork."}}
 _cache.company.append({"day": 4, "author": "Operations", "text": "INK-EXCEPTION is the only valid pink-ink stamp. It applies to one file. Tabs are prohibited even on stamped files."})
 _cache.company.append({"day": 5, "author": "Morgan", "text": "Last day of this assignment. No urgent in quoted strings. Keep checking the actual files; I will message you after closing."})

 return _cache
