extends RefCounted
## PR requests stay authored; other coworker dialogue is placeholder copy.
const Catalog = preload("res://content/catalog.gd")
static var _cache: Dictionary = {}
static func authored() -> Dictionary:
 if not _cache.is_empty(): return _cache
 var people := {}
 for person: String in ["Maya", "Theo", "Inez"]:
  people[person] = {"intro": "[Coworker introduction placeholder]", "warm": "[Friendly coworker message placeholder]", "distant": "[Frustrated coworker message placeholder]", "neutral": "", "replies": {
   "acknowledge": {"text": "On it.", "response": "[Acknowledgement placeholder]"},
   "clarify": {"text": "What should I look at first?", "response": "[PR context placeholder]"},
   "concern": {"text": "Did you check this one yourself?", "response": "[PR background placeholder]"}}}
 var packets := {}
 var incidents := ["Compliance bounced a release you signed. The complaint is about the text, not whether it runs. Please take another look tomorrow.", "An approved file reached the policy desk. They've attached a screenshot with something circled. I'm forwarding it before they schedule a meeting.", "The checker found a policy issue in something we shipped. Helios has volunteered to supervise our reviews. I'd rather you caught these."]
 var index := 0
 for packet: Dictionary in Catalog.requests():
  packets[packet.id] = {"request": str(packet.message), "question": "What should I look at first?", "hint": "[PR context placeholder]", "concern": "[PR background placeholder]", "approve": "[Approval reaction placeholder]", "request_changes": "[Change request reaction placeholder]", "incident": incidents[index % incidents.size()]}
  if packet.id == "PR-1042":
   packets[packet.id].request += " Keep an eye on the comment wording in the receipt file."
  index += 1
 _cache = {"contacts": people, "requests": packets, "company": [
  {"day": 1, "author": "Morgan", "text": "You are not here to understand the code. You are here to sign it. Helios will supply more work than you can finish; choose what carries your name carefully."},
  {"day": 2, "author": "Operations", "text": "Records Office notice: quiet filenames, sixty-column lines. Changes now arrive in sets. An unread file is an unsigned file."},
  {"day": 3, "author": "Helios", "text": "I can now offer review recommendations. PIGEON will refuse any file without its sign-off, and comments are now scanned for sentiment. Your human judgment remains useful to my training."}],
  "manager": {"intro": "Morning. Read the memo, then start the clock when you're ready.", "friction": "A coworker says we sent back a compliant change. They attached the handbook. We should avoid making policy stricter than it already is.", "handoff": "Helios picked up the remaining queue. Don't stay late chasing it; it can produce requests faster than either of us can read.", "held": "The policy desk hasn't sent anything back tonight. Thanks for being specific with the team.", "quiet": "Nothing from the policy desk tonight. Go home before somebody invents another standard.", "closing": "That's enough for today. Head home, grab dinner, or study tomorrow's paperwork."}}
 _cache.company.append({"day": 4, "author": "Operations", "text": "Exception Desk notice: INK-EXCEPTION is the only valid pink-ink permit, for one file only. Tabs remain prohibited on every file. Misspelled permits will be treated as forgeries."})
 _cache.company.append({"day": 5, "author": "Morgan", "text": "Last day of this assignment. Only management declares urgency, so no urgent in quoted strings. Keep checking the actual files; we will talk about your future after closing."})

 return _cache
