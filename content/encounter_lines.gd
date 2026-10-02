extends RefCounted
## Encounter dialogue, by author, channel, node, and mood. content/encounters.gd
## picks the node; these are the words. "desk" lines are the speech bubble beside
## the PR (three per mood); "dm" lines are Slouch messages after the fact (two per
## mood). Neutral desk lines for the classic moments (pitch, return, flag, unflag,
## consult, thanks, revise_later) are the original content/banter.gd lines, and
## neutral thanks, relief, and revise_later messages are the original
## content/policy_chat.gd reactions, so a neutral author sounds like they always have.
##
## {topic}/{Topic}: the one citation in play (flagged or disputed) in plain words,
## or a count such as "both of those". {topics}/{Topics}: everything cited.
## Lines talk about feelings, effort, pride, process, Helios, and Morgan. They
## never name a rule ID, never name what a standard checks except through the
## placeholders, and never say whether the code or a citation is right.

## Maya: tired, dry, deadpan. Encounter dialogue by node and mood.
const MAYA := {
	"desk": {
		"pitch": {
			"warm": ["Brought you an easy one. I owe you a coffee.", "You're my favorite reviewer. Don't let it go to your head.", "Small PR, big nap afterward. Help me get there."],
			"strained": ["Here. Please read it like you mean it this time.", "Another one. Let's keep this brief, shall we.", "It's on your desk. I'd like it back before I retire."],
			"hostile": ["I'm only sending this because Helios is down.", "Here. Do your worst. You usually do.", "Read it. Or don't. I've stopped hoping."],
		},
		"return": {
			"warm": ["Back again. I only cried a little this time.", "The new version is here. I did it for you. And the nap.", "Round two. You're still my favorite. Barely."],
			"strained": ["It's back. Like a pager at 3 a.m.", "Here it is again. Please find something new.", "Returned, as requested. As always requested."],
			"hostile": ["Back. Against my will and my union rep's advice.", "Again. I'm keeping a spreadsheet of this now.", "Here. I'm documenting every round of this."],
		},
		"revised": {
			"warm": ["Done. That was quick, right? Tell me it was quick.", "Fresh off the keyboard. Still warm. Unlike my coffee.", "Pushed it while you watched. Very intimate. Moving on."],
			"neutral": ["Okay. New version. Typed it with my eyes closed.", "There. Pushed. Please don't make me do that again.", "New version, live. My keyboard needs a minute."],
			"strained": ["There. Done. Happy? Don't answer that.", "Pushed. Faster than you deserve, frankly.", "New version. I typed it angrily. Loudly, too."],
			"hostile": ["There. Done. Under duress. Noted for my exit interview.", "Pushed. Read it fast. I'd like to leave.", "Here. Resentful, but here."],
		},
		"flag": {
			"warm": ["{Topic}? Okay. You've earned one of those.", "Ooh, a flag. Gentle, I hope. Like a good nap.", "Flag noted. I trust you more than my tests."],
			"strained": ["{Topic}. Of course that's where you went.", "Another flag. I'll alert my therapist.", "Mm. Flagging. Very thorough. Very slow."],
			"hostile": ["{Topic}. Sure. Pile it on.", "Flag away. I'm screenshotting all of this.", "Another one. Helios never flags me like this."],
		},
		"unflag": {
			"warm": ["Unflagged. We're still friends. We were always friends.", "Oh good. I'd already started a sad playlist.", "Mercy. I'll name a migration after you."],
			"strained": ["Unflagged. A rare moment of restraint.", "Oh. Changed your mind. Noted.", "Retracted. I'll stop drafting the long reply."],
			"hostile": ["Took it back. Doesn't undo the vibe.", "Unflagged. Too little, too late, too you.", "Noted. The screenshot stays in the folder."],
		},
		"consult": {
			"warm": ["Ask Helios. Then tell me what you really believe.", "Sure, ask it. You're still the one I trust.", "Helios? Okay. Ask it if I can have Friday off."],
			"strained": ["Oh, getting a second opinion on me. Cool.", "Ask the robot. It's very confident. Like you.", "Helios. Great. Two reviewers, zero naps."],
			"hostile": ["Ask Helios. Maybe it'll replace one of us.", "Sure. Let it do your job. I'll tell Morgan.", "Go on, ask it. It'll be kinder than you."],
		},
		"thanks": {
			"warm": ["Thank you. I'm going to tell my plant about you.", "Approved. You're a good person. Possibly the last one.", "Thanks. That's my first win since the migration."],
			"strained": ["Thanks. I guess. Don't make it weird.", "Approved. Huh. Thanks, then.", "Okay. Thanks. I'll take it before you change your mind."],
			"hostile": ["Thanks. Don't expect a card.", "Approved. Fine. Thanks, I suppose.", "Noted. Thanks. We're still not okay."],
		},
		"suspicious": {
			"warm": ["Wait, already? You're not just being nice, right?", "That fast? Are you okay? Nod if you're okay.", "Approved. Huh. Did Morgan put you up to this?"],
			"neutral": ["Wait. Approved? Just like that?", "Approved. That's it? What's the catch?", "You approved it. Now I don't trust either of us."],
			"strained": ["Wait, you approved that? What are you planning?", "Approved? You? What do you want?", "Oh, now you approve things. Interesting timing."],
			"hostile": ["Wait, you approved that? What's your angle?", "You approved it. I'm checking my calendar for traps.", "Approved. Suspicious. I'm forwarding this to myself."],
		},
		"relief": {
			"warm": ["Finally. Thank you. I'm lying down now.", "Finally. You and me, we did a thing.", "Finally. Coffee's on me. Metaphorical coffee."],
			"neutral": ["Finally. I can feel my shoulders again.", "Finally. Merging before anyone wakes up.", "Finally. One less thing on the pile."],
			"strained": ["Finally. Took you long enough.", "Finally. Let's never do that again.", "Finally. My afternoon is a smoking crater."],
			"hostile": ["Finally. Was that so hard? Don't answer.", "Finally. I aged. You did that.", "Finally. I've logged the hours for my grievance."],
		},
		"revise_now": {
			"warm": ["{Topic}? Give me a sec. I've got you.", "Okay, give me a sec. Don't go anywhere.", "On it. Watch me type like I'm awake."],
			"neutral": ["Give me a sec. I can do this one sitting down.", "{Topic}. Okay. Give me a minute.", "Hold on. I'll do it now before I lose the will."],
			"strained": ["Give me a sec. Don't watch me. Okay, watch me.", "{Topic}. Right now. Sure. Why not.", "Fine. A sec. Stand there and judge me."],
			"hostile": ["Give me a sec. And then give me some space.", "{Topic}. Fine. Doing it now, out of spite.", "One sec. I'm typing this very loudly."],
		},
		"revise_later": {
			"warm": ["{Topic}. Okay. New version after my coffee.", "Sure. I'll send it back through. Save me a seat.", "Noted. Back in a bit. Don't miss me too much."],
			"strained": ["{Topic}. Fine. It'll come back around.", "Okay. Back in line it goes. Like me, at lunch.", "Sure. I'll revise it. Eventually. Wearily."],
			"hostile": ["{Topic}. Great. Back of the line, I guess.", "Fine. I'll revise it after I update my resume.", "Back it goes. Write that down in your little log."],
		},
		"pushback": {
			"warm": ["{Topic}? For me? Can we let that one go?", "Okay, but {topic}? Today? Is that the hill?", "{Topic}? Really? Weren't we friends?"],
			"neutral": ["{Topic}? Is that worth another round?", "Hold on. {Topic}? You're sure about this?", "{Topic}. On a day like this? Really?"],
			"strained": ["{Topic}? Again? Do you even like me?", "Really. {Topic}. You want to die on that?", "{Topic}? Want to defend that out loud?"],
			"hostile": ["{Topic}? Is this on purpose?", "{Topic}. Seriously. Want to tell Morgan why?", "Oh, {topic}. Is this personal now?"],
		},
		"abandon": {
			"warm": ["Not worth your afternoon. I'll let Helios have it.", "You know what, Helios can merge it. Go home early.", "Closing it. Helios will merge it. No hard feelings."],
			"neutral": ["Fine. I'll get Helios to merge it.", "Closing it. Helios can have it. Helios has everything.", "Never mind. Helios merges things without opinions."],
			"strained": ["Forget it. Helios will merge it without the attitude.", "Closing. Helios will merge it. It doesn't sigh.", "Fine. Helios merges in seconds. Just saying."],
			"hostile": ["Fine. I'll get Helios to merge it. It likes me.", "Done with this. Helios is merging it. Bye.", "Closed. Helios merges it. You can explain to Morgan."],
		},
		"escalate": {
			"warm": ["I'm looping in Morgan. Not about you. About me.", "Let's let Morgan decide. I trust you both. Mostly you.", "Asking Morgan to weigh in. Don't take it personally."],
			"neutral": ["I'm looping in Morgan. I'm out of rounds in me.", "Okay. Morgan can sort this out. Morgan loves sorting.", "Escalating to Morgan. I need a grown-up. A different one."],
			"strained": ["I'm looping in Morgan. This is above my coffee grade.", "Morgan can deal with this. I'm going to lie down.", "Taking it to Morgan. You two can have a meeting."],
			"hostile": ["I'm looping in Morgan. Bring your receipts.", "Morgan's getting this. With my notes. Many notes.", "Escalated to Morgan. Expect a calendar invite."],
		},
		"insist_revise": {
			"warm": ["Okay, okay. You win. I'll revise it. Sigh.", "Fine. For you. Don't tell anyone I folded.", "Alright. I'll redo it. You owe me a nap."],
			"neutral": ["Fine. I'll revise it. Under protest. Quiet protest.", "Okay. Back in line. I'm noting my objection to myself.", "Sure. I'll redo it. My will to live says hi."],
			"strained": ["Fine. Insist. I'll revise it. Remember this.", "Okay. I'll redo it. Very slowly. On purpose.", "Revising. Grudgingly. That's the only speed I have."],
			"hostile": ["Fine. You win this one. I'm counting.", "I'll revise it. You'll be in my thoughts. Not kindly.", "Revising. Under protest. Notarized protest."],
		},
		"insist_escalate": {
			"warm": ["Then let's ask Morgan. Friendly disagreement.", "Okay, we're stuck. Morgan can break the tie.", "I'll let Morgan decide. No hard feelings. Some feelings."],
			"neutral": ["Then I'm taking it to Morgan.", "Okay. Morgan can settle this. I'm out of energy.", "We're done here. Looping in Morgan."],
			"strained": ["Then Morgan gets to hear about it. In detail.", "You insist, I escalate. Morgan's on it.", "Fine. Morgan can referee. I'm getting a coffee."],
			"hostile": ["Then I'm going to Morgan. With screenshots.", "Insist all you want. Morgan's hearing my side first.", "Morgan. Now. I've already drafted the message."],
		},
		"withdrawn": {
			"warm": ["Thank you. I knew you'd get there. We're good.", "Oh, thank you. You may have saved my afternoon.", "Appreciated. Okay, back to it. Together."],
			"neutral": ["Thank you. Sanity briefly restored.", "Okay. Withdrawn. Let's keep going.", "Good. I was halfway through a sad reply."],
			"strained": ["Oh. Withdrawn. Look at you, compromising.", "Thanks. That was almost pleasant.", "Withdrawn. Great. Now finish the rest."],
			"hostile": ["Withdrawn. As you were. Carry on.", "Took you long enough. Keep going.", "Withdrawn. Doesn't mean I forgive you."],
		},
	},
	"dm": {
		"thanks": {
			"warm": ["Thank you for the approval. Genuinely. I'm going to celebrate by closing my laptop for eleven minutes.", "You approved it. You're the only part of this job that doesn't page me at night."],
			"strained": ["Thanks for the approval. I mean it, mostly. Let's both pretend this is normal.", "Approved. Okay. Thank you. I'm not sure what to do with these feelings, so I'm ignoring them."],
			"hostile": ["Thanks for approving it. This changes nothing. Well, it changes one thing.", "Approved. Thank you, I suppose. I'm still not inviting you to my farm."],
		},
		"suspicious": {
			"warm": ["You approved it so fast. Are you okay? Do you need a nap? I know a good spot under the server rack.", "Approved already? I'm grateful and a little worried about you. Hydrate."],
			"neutral": ["Wait, you approved it? Just like that? I keep waiting for the other shoe. It's probably a Helios shoe.", "Approved without a single note. I don't know what to do with my hands."],
			"strained": ["Wait, you approved that? After everything? What are you up to?", "An approval. From you. I'm reading it twice to look for the trick."],
			"hostile": ["Wait, you approved that? You never approve anything of mine. What's the angle?", "You approved it. I've screenshotted it in case you try to take it back."],
		},
		"relief": {
			"warm": ["Finally. Thank you for sticking with it. And with me. Mostly with it.", "Finally merged. We make a good team. A tired, slow, good team."],
			"strained": ["Finally. That took longer than the migration, and the migration took a year.", "Finally approved. I'd say thank you, but my afternoon is gone and it's not coming back."],
			"hostile": ["Finally. I've added the hours this took to my self-review, under things that happened to me.", "Finally. I'll be telling this story at my going-away party."],
		},
		"revise_now": {
			"warm": ["Pushed a new version while you watched. It's on your desk. No pressure. Some pressure. Okay, no pressure.", "Revised it right there at your desk. That's the fastest I've moved since the fire drill."],
			"neutral": ["Revised it on the spot. It's on your desk now. I need to sit in a dark room.", "Did it right away so I'd stop dwelling on it. It's on your desk."],
			"strained": ["Revised it on the spot, since apparently that's my life now. It's on your desk.", "New version's on your desk. I typed it while you stared at me. Thanks for that."],
			"hostile": ["Revised. Right in front of you. I hope it was entertaining.", "It's on your desk. I did it in one sitting so I could stop looking at you."],
		},
		"revise_later": {
			"warm": ["Noted on {topics}. I'll get you a new version after I find my coffee. And my will.", "{Topics}, got it. Back through the line soon. I'll be the one yawning."],
			"strained": ["{Topics}. Okay. It'll come back around when it comes back around.", "Noted: {topics}. Revising. Slowly. Like a good tired person."],
			"hostile": ["{Topics}. Wonderful. A revision will happen. Eventually. Possibly.", "Fine. {Topics}. I'll revise it after I update my farm plans."],
		},
		"withdrawn": {
			"warm": ["Thanks for dropping {topic}. I owe you one. I owe everyone one, but you're at the front.", "You let {topic} go. That was kind. I'll remember it during my next outage."],
			"neutral": ["Thanks for letting {topic} go. Back to my actual job.", "Appreciate you dropping {topic}. My blood pressure says thanks too."],
			"strained": ["You dropped {topic}. Thanks. That's the nicest thing you've done all week.", "Noted: {topic} withdrawn. See? We can communicate."],
			"hostile": ["You withdrew {topic}. Good. I'd have fought you about it in standup.", "{Topic}: withdrawn. I'm still keeping the screenshot of the moment you cited it."],
		},
		"insist_revise": {
			"warm": ["Okay, you win on {topics}. I'll revise it. You're lucky you're my favorite.", "Revising {topics}. I'm grumbling, but affectionately."],
			"neutral": ["Fine. Revising {topics}. Under protest. Quiet protest. Mostly sighing.", "You held firm on {topics}. I'll revise it. My objection is filed with my plant."],
			"strained": ["You insisted on {topics}. I'm revising it. Remember that I remember.", "Revising {topics}. Grudgingly. That's the only speed I've got left today."],
			"hostile": ["Fine. {Topics}. I'll revise it. I want you to know I'm sighing as I type this.", "You insisted. I'm revising {topics}. This is going in the folder."],
		},
		"insist_escalate": {
			"warm": ["We disagreed about {topic}, so I asked Morgan. It's not you. It's mostly the process.", "I took {topic} to Morgan. Friendly disagreement. I still like you. Don't make it weird."],
			"neutral": ["I've asked Morgan to look at {topic}. I'm out of rounds.", "Morgan has {topic} now. I'm going to go stare at a wall."],
			"strained": ["You wouldn't let {topic} go, so it's on Morgan's desk now. Hope you like meetings.", "I've taken {topic} to Morgan. You two can schedule something. Leave me out of it."],
			"hostile": ["Morgan has {topic} now. I wrote a very calm summary. It is not calm.", "I escalated {topic} to Morgan. I've attached a timeline. You're in it."],
		},
		"abandon": {
			"warm": ["I closed the PR. Helios is merging it. Honestly, it wasn't worth your afternoon. Or mine.", "Closed it and handed it to Helios. Not mad. Just tired. Go home early."],
			"neutral": ["Closed it. Helios is merging it. Fewer meetings for everybody.", "I've closed the PR and asked Helios to merge it. Helios doesn't ask questions."],
			"strained": ["Closed it. Helios is merging it. It doesn't sigh at me. Much.", "PR closed. Helios merged it while you were still reading. Food for thought."],
			"hostile": ["Closed. Helios is merging it. You can tell Morgan how that happened.", "I gave it to Helios. It merged it without a single opinion. Refreshing."],
		},
		"grudge": {
			"warm": ["Helios merged it in four seconds. No notes. I kind of missed your notes. Don't tell anyone.", "Helios merged it, no questions asked. It was efficient and I hated it. Anyway, hi."],
			"neutral": ["Update: Helios merged it in four seconds. No notes. Just saying.", "Helios didn't even read it. It just said LGTM. Anyway. Just thought you should know."],
			"strained": ["Fun fact: Helios merged it in four seconds. No notes. Some reviewers could learn from that.", "Helios approved it without making me feel small. Imagine."],
			"hostile": ["Helios merged it in four seconds. No notes. No attitude. I'm just saying it out loud.", "Still reflecting on how Helios merged it without a review meeting. Still reflecting on you, too. Not fondly."],
		},
		"escalate": {
			"warm": ["I've looped in Morgan. It's a process thing, not a you thing. You're still my favorite.", "Morgan's going to take it from here. I'll still bring you snacks."],
			"neutral": ["I've looped in Morgan. I'm all out of rounds.", "Escalated to Morgan. Morgan likes deciding things. I like naps."],
			"strained": ["Looping in Morgan. I don't get paid enough to keep going in circles.", "I've escalated to Morgan. You two can talk. I'll be lying on the floor."],
			"hostile": ["Morgan has it now. I'd start preparing your side of the story.", "Escalated. Morgan will want to chat. I hope you like chatting."],
		},
	},
}

## Theo: overconfident. It is always a one-line change.
const THEO := {
	"desk": {
		"pitch": {
			"warm": ["Saved this one for you. Best reviewer, best diff.", "My favorite reviewer. One-line change. You'll love it.", "Brought you a gift. It's a diff. Basically a protein bar."],
			"strained": ["Here. One-line change. Try to keep it one line.", "New PR. Please review it, not my whole personality.", "It's small. Like, review-it-before-lunch small."],
			"hostile": ["Helios already liked this. Your turn to disagree.", "New PR. I've cc'd Morgan, for transparency.", "Go ahead. Find something. You always do."],
		},
		"return": {
			"warm": ["Back again, better than ever. Like me after leg day.", "It's back. Sequel energy. You're gonna love the ending.", "Round two, my guy. Took your notes. Lifted with them."],
			"strained": ["It's back. Exactly what you asked for. Nothing more.", "Another version. Hope this one meets your standards.", "Returned, as requested. Please be gentle this time."],
			"hostile": ["Back again. I'm documenting every round of this.", "Here's your revision. Morgan's watching the thread.", "It's back. Helios would've merged it a week ago."],
		},
		"revised": {
			"warm": ["Done. That was fast, right? Say it was fast.", "Boom. Fixed live, like a demo that actually works.", "Ten seconds flat. Write that in my promo packet."],
			"neutral": ["Done. Told you I'm fast.", "Pushed. Didn't even sit down.", "There. Next version. Hot off the force-push."],
			"strained": ["There. Fixed it while you watched. Happy?", "Done. Speed-ran it so we can move on.", "Pushed. Please don't make me do that again."],
			"hostile": ["There. Done in seconds. Unlike your review.", "Updated. I timed it. I'm also timing you.", "Pushed. Logged how long you took versus me."],
		},
		"flag": {
			"warm": ["Ooh, {topic}. Bold. I respect opinions.", "Flagging me? Okay, coach. Teach me.", "{Topic}? Ha. You're thorough. I like that."],
			"strained": ["{Topic}. Sure. Anything else?", "Another flag. Cool. Super cool.", "You're really reading every line, huh."],
			"hostile": ["{Topic}. Noted. I'm screenshotting this.", "Of course you flagged that. Of course.", "Flag away. Helios is keeping score too."],
		},
		"unflag": {
			"warm": ["See? You trust me. That's the vibe.", "Un-flagged. Love a reviewer who reads the room.", "Respect. Took that back faster than I ship."],
			"strained": ["Okay. One less thing. Thanks, I guess.", "Withdrawn. Noticing that. Not saying anything.", "Changed your mind? Wild. Okay."],
			"hostile": ["Took it back. Still documenting it.", "Unflagged. Too late, I already told Morgan.", "Oh, now you're unsure? Cool. Cool cool."],
		},
		"consult": {
			"warm": ["Ask Helios. It'll tell you I'm a legend.", "Go ahead. Helios and I have a great rapport.", "Sure, loop in the robot. It owes me a favor."],
			"strained": ["Need a robot to read my one-line change? Okay.", "Asking Helios. Because a human was too much.", "Cool. Ask the autocomplete what it thinks of me."],
			"hostile": ["Ask Helios. It's going to replace one of us.", "Great, consult the thing that'll merge this anyway.", "Ask it. Then ask it why you still have a job."],
		},
		"thanks": {
			"warm": ["Let's gooo. You and me, unstoppable.", "Approved. You're getting a shoutout at standup.", "Thanks, my guy. Putting you in my promo packet."],
			"strained": ["Thanks. Took you long enough. But thanks.", "Approved. Okay. Appreciated. Mostly.", "Cool. Thanks. See, that wasn't so hard."],
			"hostile": ["Fine. Thanks. Doesn't change anything.", "Approved. Noted. Still telling Morgan about last time.", "Thanks. I guess. Don't expect a high five."],
		},
		"suspicious": {
			"warm": ["Approved? Already? Wait, did you even scroll?", "Huh. First try. Are you feeling okay, buddy?", "No notes? From you? Okay, who are you."],
			"neutral": ["Wait, approved? Just like that? What's the catch?", "Huh. You didn't even flag anything. Suspicious.", "Approved? Okay. Who told you to go easy on me?"],
			"strained": ["Oh, NOW you approve. What are you up to?", "Approved? After last time? What's your angle?", "Wait, you approved that? Is this a trap?"],
			"hostile": ["Wait, you approved that? What's the play here?", "You approved it. Now I'm suspicious of you.", "Approved? You? I'm screenshotting this, just in case."],
		},
		"relief": {
			"warm": ["Finally. Knew we'd get there. Team effort. Mostly me.", "Finally. Hug it out? Virtually. Or not virtually.", "Finally. Framing this approval for my desk."],
			"neutral": ["Finally. Merging before you change your mind.", "Finally. Shipping it. Don't look back.", "Finally. The latest version is the charm."],
			"strained": ["Finally. That only took forever.", "Finally. Never doing that again. Probably.", "Finally. Can we never speak of this?"],
			"hostile": ["Finally. Morgan will hear how long this took.", "Finally. Helios would've approved v1, just saying.", "Finally. Documenting the timeline, for posterity."],
		},
		"revise_now": {
			"warm": ["Oh, {topic}? Easy. Give me a sec.", "Say less. Fixing it live. Watch this.", "Hang tight, my guy. Ten seconds. Maybe eight."],
			"neutral": ["{Topic}? Give me a sec. I type fast.", "Hold on. Fixing it right here. Don't move.", "One sec. Hot-patching in front of a live audience."],
			"strained": ["Fine. Give me a sec. Don't go anywhere.", "{Topic}. Okay. Fixing it. Right now. Happy?", "Sure. One second. Watch me not complain."],
			"hostile": ["Give me a sec. I'm fixing {topic}. Silently.", "Fine. Sec. Don't talk to me while I type.", "Hold on. Doing it now so I never see you again."],
		},
		"revise_later": {
			"warm": ["{Topic}? On it. v2 will blow your mind.", "Sure thing. Back soon with the director's cut.", "Got it. Sending v2 after the gym. During the gym."],
			"strained": ["Fine. {Topic}. v2 later. Get in line.", "Okay. Revising. Again. It'll be back.", "Noted. v2 coming. Whenever. Eventually."],
			"hostile": ["Fine. v2 later. I'm cc'ing Morgan on it.", "{Topic}. Sure. I'll fix it after I vent.", "Back to the line it goes. Like my patience."],
		},
		"pushback": {
			"warm": ["{Topic}? Come on, bro. For me?", "Buddy. {Topic}? On a demo day? Really?", "Is {topic} a hill you want to die on?"],
			"neutral": ["{Topic}? Really? That's what we're doing?", "Hold up. {Topic}? Can we talk about it?", "{Topic}? Took me ten minutes. Worth a round?"],
			"strained": ["{Topic}. Again. Sure you want to go there?", "Sending it back for {topic}? Seriously?", "{Topic}? Pick your battles. Is it this one?"],
			"hostile": ["{Topic}? Really? Want Morgan reading this?", "Over {topic}? You're sure? Final answer?", "{Topic}. Bold. Want to stand behind that?"],
		},
		"abandon": {
			"warm": ["Not worth your time. I'll get Helios to merge it.", "Eh, I'll let Helios take this one. No hard feelings.", "Closing it. Helios owes me one anyway."],
			"neutral": ["Fine. I'll get Helios to merge it. Helios gets me.", "Closing it. Helios never asks questions.", "Forget it. Helios merges in four seconds flat."],
			"strained": ["You know what? Helios can have it.", "Closing this. Helios likes my code, at least.", "Nah. I'll route it through Helios. Bye."],
			"hostile": ["Done with this. Helios is merging it. Enjoy.", "Closed. Helios approves in seconds, unlike some.", "I'm taking this to Helios. It doesn't nitpick."],
		},
		"escalate": {
			"warm": ["Gonna loop in Morgan. Not on you. On the process.", "I'll ask Morgan to weigh in. No beef, promise.", "Morgan should see this. Mostly to see me grow."],
			"neutral": ["Okay. I'm looping in Morgan.", "Escalating to Morgan. Above both our pay grades.", "Pinging Morgan. Morgan loves a long thread."],
			"strained": ["I'm bringing Morgan into this. Respectfully.", "Morgan's getting a link to this review. Heads up.", "That's it. Morgan can decide. Not you."],
			"hostile": ["I'm looping in Morgan. And attaching screenshots.", "Morgan's hearing about this. Today. Now, actually.", "Done. Taking it to Morgan. Helios gets it after."],
		},
		"insist_revise": {
			"warm": ["Okay, okay. You win. Revising it. For you.", "Fine, coach. v2 it is. You owe me a coffee.", "Alright. I'll redo it. Respect the conviction."],
			"neutral": ["Fine. I'll redo it. Under protest.", "Okay. Revising. Drafting an angry commit message.", "Alright, alright. Back in line it goes."],
			"strained": ["Fine. Revising. Remembering this, though.", "Okay. You win this one. Revising.", "Sure. v2. With feelings."],
			"hostile": ["Fine. Revising. Morgan gets the play-by-play.", "Whatever. It'll come back. So will I.", "Revising. Noted in my running doc about you."],
		},
		"insist_escalate": {
			"warm": ["Okay, let's let Morgan break the tie. Friendly.", "Gonna ask Morgan. Nothing personal, buddy.", "We'll let Morgan referee. Loser buys lunch."],
			"neutral": ["Then I'm looping in Morgan.", "Okay. Morgan can settle this.", "Fine. Let's see what Morgan says."],
			"strained": ["Then Morgan's deciding. Not you.", "Cool. I'll take it up with Morgan.", "You're insisting? I'm escalating. To Morgan."],
			"hostile": ["Insist all you want. Morgan's on the thread now.", "Great. Morgan gets this whole exchange. Verbatim.", "Then it goes to Morgan. And you go in my notes."],
		},
		"withdrawn": {
			"warm": ["There it is. Knew you'd see it my way.", "Thank you. That's why you're my favorite.", "Respect. We're a great team, honestly."],
			"neutral": ["Yeah. That's what I thought.", "Appreciated. Carry on, reviewer.", "Thanks. Okay, take another look."],
			"strained": ["Okay. Thanks for dropping it. Finally.", "Good. Let's keep this moving, then.", "Withdrawn. See? Was that so hard?"],
			"hostile": ["Took you long enough. Keep reading.", "Smart. Morgan didn't need to see that.", "Backed down. Noted. Keep going."],
		},
	},
	"dm": {
		"thanks": {
			"warm": ["Approved first try. You and me are the best pipeline in this building. Helios wishes.", "Thanks for the approval. Told standup you're my favorite reviewer. Inez heard. Worth it."],
			"strained": ["Thanks for approving. Means a lot. Moderately.", "Appreciate the approval. Let's keep that energy going, yeah?"],
			"hostile": ["Got the approval. Thanks, I guess. Doesn't undo the rest of the week.", "Approved. Fine. I'll mention it to Morgan alongside everything else."],
		},
		"suspicious": {
			"warm": ["You approved that super fast. Not complaining. Just making sure you're not sick or something.", "No notes at all? From you? I'm flattered and slightly worried about you."],
			"neutral": ["Hey, you approved that with zero notes. Who are you and what did you do with my reviewer?", "Quick approval. I'm choosing to believe you trust me and not that you gave up."],
			"strained": ["You approved this in two seconds? After the week we've had? What's the angle, my guy?", "Approved without a single flag. I'm not saying it's a trap. I'm saying I'm watching."],
			"hostile": ["Wait, you approved that? I've screenshotted it in case you try to pin something on me later.", "You approved it. You. Approved. I'm forwarding this to myself for the paper trail."],
		},
		"relief": {
			"warm": ["Finally merged. Couldn't have done it without you. Could have done it faster, though.", "Finally. Our little PR grew up. Proud of us."],
			"strained": ["Finally. That took a lot of versions. Let's not do that again.", "Finally approved. My promo packet will describe this as resilience."],
			"hostile": ["Finally. Morgan has the full timeline of how long that took. Just so you know.", "Finally. Helios approved v1 in its head. You took several tries. Noted."],
		},
		"revise_now": {
			"warm": ["Pushed v2 while you watched. Live coding, baby. Ready when you are.", "v2 is up. {Topics}, handled in real time. Admit it, that was cool."],
			"neutral": ["v2's up. Did {topics} right there at your desk. Speedrun complete.", "Revised it on the spot. Take a look whenever. Now, ideally."],
			"strained": ["v2 is on your desk. Did {topics} on the spot so we could get this over with.", "Revised. Right in front of you. Please make this the last one."],
			"hostile": ["v2 is up. I did {topics} faster than you reviewed it. Timestamps don't lie.", "Revised at your desk. I'd like my afternoon back. Morgan's cc'd."],
		},
		"revise_later": {
			"warm": ["On it. {Topics}: getting the full treatment. v2 will be my magnum opus.", "Got your notes on {topics}. Hitting the gym, then v2. Maybe during."],
			"strained": ["Okay. {Topics}. I'll send a v2. It'll get back to you when it gets back to you.", "Revising {topics}. Again. Put it back in the line, I guess."],
			"hostile": ["Fine. {Topics}. v2 later. I've started a doc about our review history.", "Revising {topics}. Morgan will be getting a summary of this whole saga."],
		},
		"withdrawn": {
			"warm": ["Thanks for dropping {topic}. Knew you'd come around. That's why we work.", "Appreciate you letting {topic} go. I'll bring you a coffee. Maybe a protein shake."],
			"neutral": ["Thanks for dropping {topic}. Glad we talked it out.", "Appreciate you reconsidering {topic}. Growth, for both of us. Mostly you."],
			"strained": ["Thanks for backing off {topic}. That's all I wanted.", "You dropped {topic}. Good. Let's not make the arguing part a habit."],
			"hostile": ["You dropped {topic} once I pushed back. Interesting. Very interesting.", "Thanks for dropping {topic}. Still noting that I had to ask."],
		},
		"insist_revise": {
			"warm": ["Fine, you win. Revising {topics}. I respect a reviewer who holds the line.", "Okay, coach. {Topics} it is. v2 incoming, with minimal sulking."],
			"neutral": ["Revising {topics}. Under protest. The protest is this message.", "Fine. {Topics}. I'll send a v2. I wanted that noted."],
			"strained": ["You insisted, so I'm revising {topics}. Remembering this one.", "Okay. {Topics}. v2 later. My commit message will be passive-aggressive. Inez taught me."],
			"hostile": ["Revising {topics} because you insisted. Morgan's getting the transcript.", "Fine. {Topics}. I'm revising. I'm also updating my running doc about you."],
		},
		"insist_escalate": {
			"warm": ["Looped Morgan in on {topic}. Friendly tiebreaker. Loser buys lunch.", "Asked Morgan to weigh in on {topic}. Not mad. Just want a referee."],
			"neutral": ["I've asked Morgan to look at {topic}. Let's see who's left standing.", "Morgan's got the thread on {topic} now. Out of my hands. And yours."],
			"strained": ["You wouldn't drop {topic}, so Morgan's deciding. Fair's fair.", "Took {topic} to Morgan. Seems best a grown-up decides."],
			"hostile": ["Morgan has the thread on {topic} now. With screenshots. With arrows.", "Escalated {topic} to Morgan. I've also forwarded your review history. For context."],
		},
		"abandon": {
			"warm": ["Closed it. Not worth burning your afternoon. Helios is merging it. We're good.", "Eh, I closed the PR. Helios will merge it. Save your notes for something juicy."],
			"neutral": ["Closed the PR. Helios is merging it instead. Saves everyone a round.", "Fine. I'll get Helios to merge it. It never sends things back."],
			"strained": ["Closed it. Helios is handling the merge. It doesn't make me feel bad.", "PR closed. Helios merges, nobody argues. Kind of nice, honestly."],
			"hostile": ["Closed. Helios is merging it. Helios has never once made me do a v2.", "I pulled it from your desk. Helios is merging. Enjoy the free time."],
		},
		"grudge": {
			"warm": ["Helios merged it in four seconds. No notes. Kind of missed your notes, honestly.", "Update: Helios merged it. It didn't even say good job. You'd have said good job."],
			"neutral": ["Helios merged it in four seconds. No notes. Just saying.", "FYI, Helios approved it instantly. Didn't even ask about the demo."],
			"strained": ["Helios merged it in four seconds flat. Not that I'm counting. I'm counting.", "Helios merged it with zero questions. Zero. Some reviewers could learn from that."],
			"hostile": ["Helios merged it in four seconds. Four. I put the stopwatch in my self-review.", "Still chewing on that review. Helios merged it without hesitating. You hesitated a lot."],
		},
		"escalate": {
			"warm": ["Looped Morgan in. Not a complaint, promise. I just want a ruling before my demo.", "Asked Morgan to weigh in. You're still my favorite reviewer. Morgan's my favorite manager."],
			"neutral": ["I've looped Morgan in. Morgan can hand it to Helios. Out of our hands.", "Escalated to Morgan. Not a threat. Just process. I learned that word from Inez."],
			"strained": ["I'm looping in Morgan. We need an adult in the room.", "Escalated to Morgan. Figured a third opinion beats another round with you."],
			"hostile": ["Looped in Morgan. Attached the review. Attached my feelings about the review.", "Morgan has it now. Helios gets it after. You get a nice quiet afternoon."],
		},
	},
}

## Inez: process-minded and passive-aggressive. It was decided in a meeting.
const INEZ := {
	"desk": {
		"pitch": {
			"warm": ["Sent to you first. You're in the reliable column.", "Ticket, RFC, and a thank-you in advance. For you.", "I told the working group you'd be fair. No pressure."],
			"strained": ["Attached: the PR, the RFC, and a calendar hold.", "Please review at your earliest procedural convenience.", "I've cc'd myself on this review. For continuity."],
			"hostile": ["Before you start: I'm minuting this review live.", "Here's my PR. HR has a copy of this conversation.", "Review it. The working group is watching. So am I."],
		},
		"return": {
			"warm": ["Back per your notes. I followed them to the letter.", "Revision attached. I updated the decision log fondly.", "Round two. I scheduled zero meetings about it. Growth."],
			"strained": ["Resubmitted. The ticket now has a sub-ticket about you.", "Here it is again, as required by your preferences.", "Revision attached. Please acknowledge receipt in writing."],
			"hostile": ["Back again. My retro slide about this is ready.", "Revised. I've added your name to the blockers column.", "Resubmitted under protest. The protest is attached."],
		},
		"revised": {
			"warm": ["Done. Revised live, like we agreed in spirit.", "There. Fastest revision in the decision log.", "Updated while you waited. I even skipped the RFC."],
			"neutral": ["Revised. I'll backfill the ticket afterward.", "Here. Revision drafted, filed, and minuted.", "Updated in place. The changelog is pending."],
			"strained": ["Revised in real time. My calendar did not consent.", "There. Please note the turnaround in your report.", "Done. I have logged this as unplanned work."],
			"hostile": ["Revised. Timestamped. Screenshotted. Your turn.", "There. I'll be invoicing the working group.", "Done, under duress. The duress is in the ticket."],
		},
		"flag": {
			"warm": ["{Topic}? Noted. I'll trust your process.", "Flagged. I'll add it to my learnings doc.", "Raised. I'll bring snacks to the retro."],
			"strained": ["{Topic}. I'll need that in the ticket.", "Flagged. I'm adding a column for your flags.", "Interesting. That wasn't in the pre-read."],
			"hostile": ["{Topic}. Documented, with a timestamp.", "Another flag. HR loves a pattern.", "Flagged. I've started a separate doc for you."],
		},
		"unflag": {
			"warm": ["Retracted. Thank you for circling back so quickly.", "Withdrawn. I'll strike it from the minutes, gently.", "Appreciated. That's why you're in the good column."],
			"strained": ["Withdrawn. I'll note the reversal for context.", "Thank you. The minutes will show you hesitated.", "Retracted. I've updated the timeline. Again."],
			"hostile": ["Withdrawn. The original stays in my notes.", "Changing your mind is now a pattern. Noted.", "Retracted. HR will want both versions."],
		},
		"consult": {
			"warm": ["Ask Helios. You'll still sign it, which I prefer.", "Sure. Just cc me on whatever it hallucinates.", "Go ahead. I trust your judgment more than its."],
			"strained": ["Consulting Helios. I'll note the dependency.", "Asking the assistant. Is that in the review SOP?", "Interesting. Helios reviewed my last PR faster."],
			"hostile": ["Ask Helios. It at least reads the RFC.", "Outsourcing your review. Logged for the working group.", "Helios is on my side. It read the meeting notes."],
		},
		"thanks": {
			"warm": ["Thank you. I've added a gold star to your row.", "Approved. I'll mention you in the all-hands deck.", "Lovely. You're officially my preferred reviewer."],
			"strained": ["Thank you. I'll note the approval, neutrally.", "Approved. Received. Filed. Thanks, I suppose.", "Thank you. That was on time, for once."],
			"hostile": ["Thanks. This changes nothing in my spreadsheet.", "Approved. Noted without enthusiasm.", "Thank you. I've still booked the meeting about you."],
		},
		"suspicious": {
			"warm": ["Approved already? You're sure you read the RFC?", "That was quick. Did you at least skim the pre-read?", "Approved? I had a whole rebuttal prepared. Darn."],
			"neutral": ["Approved? Just like that? I'll need that in writing.", "Wait. You approved it. What do you want?", "Approved without a single question. Unusual."],
			"strained": ["Wait, you approved that? What's the catch?", "An approval from you. I'll have Legal read it.", "You approved it. I'm checking it for traps."],
			"hostile": ["You approved my PR? Who told you to be nice?", "Approved. I'm forwarding it to HR, just in case.", "Wait. You approved that? I'm documenting this too."],
		},
		"relief": {
			"warm": ["Finally. Thank you for sticking with the process.", "Finally. Closing the ticket with a little bow on it.", "Approved. I'm adding a celebration line item."],
			"neutral": ["Finally. Moving the ticket to done, done, done.", "Approved. The changelog can finally rest.", "Finally. I'll update the burndown chart."],
			"strained": ["Finally. Noted how many versions that took.", "Approved at last. The retro writes itself.", "Finally. I'll attach the full history to the ticket."],
			"hostile": ["Finally. Every version is in my escalation draft.", "Approved. Eventually. HR will find that interesting.", "Finally. Don't think this closes my other ticket."],
		},
		"revise_now": {
			"warm": ["{Topic}? Give me a sec. Revising now.", "One moment. Revising before the ticket notices.", "Give me a sec. I'll skip the RFC this once."],
			"neutral": ["Give me a sec. Opening a ticket to revise it.", "{Topic}. One moment, revising in place.", "Hold, please. Revising per your review."],
			"strained": ["Give me a sec. Logging this as an interruption.", "{Topic}. Fine. Revising now, under protest.", "One moment. Please don't move; I'm minuting this."],
			"hostile": ["Give me a sec. And a witness.", "{Topic}. Revising now. HR is cc'd.", "Hold still. I'm revising and timestamping."],
		},
		"revise_later": {
			"warm": ["Understood. v2 will follow, per our lovely process.", "{Topic}. Noted kindly. Revision to follow.", "Back to my desk. You'll see it again soon."],
			"strained": ["Understood. A revision will follow, eventually.", "{Topic}. Logged. Expect v2 per the SLA.", "Fine. I'll revise and update the blockers list."],
			"hostile": ["Revision to follow. So does an agenda item.", "{Topic}. Logged as your decision, not mine.", "I'll revise it. The working group will hear of it."],
		},
		"pushback": {
			"warm": ["{Topic}? We aligned on that in sync, no?", "Are we sure {topic} is worth a v2?", "{Topic}? Could we park it for the retro?"],
			"neutral": ["{Topic}? Is there precedent for that?", "Respectfully, is {topic} in scope here?", "{Topic}? Can I see that in writing first?"],
			"strained": ["{Topic}? Which version of the standard?", "Are we really blocking on {topic}?", "{Topic}. Was that in the design review?"],
			"hostile": ["{Topic}? Shall I loop in the working group?", "You're blocking me on {topic}? Really?", "{Topic}? Want to defend that to HR?"],
		},
		"abandon": {
			"warm": ["Not worth your afternoon. Helios can merge it.", "I'll close it and let Helios take it. No hard feelings.", "Let's not block on me. Helios will merge it."],
			"neutral": ["Closing it. Helios will merge it, per the fallback.", "Fine. I'll route it to Helios, as the policy allows.", "Withdrawing the PR. Helios has merge rights now."],
			"strained": ["Fine. I'll get Helios to merge it, per the fallback policy.", "Closed. Helios doesn't need a pre-read.", "I'll take this to Helios. It approves on time."],
			"hostile": ["Closed. Helios will merge it without the attitude.", "Fine. Helios merges it. You can explain the gap.", "Done here. Helios reviews me now. Minuted."],
		},
		"escalate": {
			"warm": ["I'll ask Morgan to weigh in. It's procedure, not you.", "Looping in Morgan, per policy. I'll say nice things.", "Morgan should see this. I'll cc you, warmly."],
			"neutral": ["I'm looping in Morgan, per the escalation matrix.", "Escalating to Morgan. I've attached the flowchart.", "Morgan will decide. That's what the policy says."],
			"strained": ["I'm looping in Morgan. Please hold for the invite.", "Escalating to Morgan. I've summarized your position.", "Morgan can arbitrate. I've attached your history."],
			"hostile": ["Morgan is now involved. So is my timeline doc.", "I'm escalating to Morgan. And possibly HR.", "Morgan will hear about this. In bullet points."],
		},
		"insist_revise": {
			"warm": ["Okay. You're the reviewer. Revising, with love.", "Understood. I'll revise it and update the RFC.", "Fine. I trust you. I'm also writing it down."],
			"neutral": ["Very well. Revision to follow, under advisement.", "Understood. I'll revise and note the disagreement.", "Noted. Overruled. Revising."],
			"strained": ["Fine. Revising. My dissent is in the ticket.", "As you insist. I'll revise and minute the insistence.", "Revising. This will be a slide in the retro."],
			"hostile": ["Fine. I'll revise. HR will get the director's cut.", "Revising under protest. Formal protest. Laminated.", "You win this round. The spreadsheet remembers."],
		},
		"insist_escalate": {
			"warm": ["Then let's let Morgan decide. Nothing personal.", "Alright. I'll ask Morgan to break the tie.", "Okay. Morgan can arbitrate. I'll bring muffins."],
			"neutral": ["Then I'm taking it to Morgan, per section four.", "Understood. Escalating to Morgan for a ruling.", "In that case, Morgan decides. I've sent the invite."],
			"strained": ["Then Morgan can hear both sides. Mine is longer.", "Insisting? I'm looping in Morgan, respectfully.", "Fine. Morgan gets the ticket and the subtext."],
			"hostile": ["Then it's going to Morgan. With exhibits.", "Insist all you like. Morgan is already reading.", "Escalated to Morgan. I've attached your tone."],
		},
		"withdrawn": {
			"warm": ["Thank you. I knew you'd see the process my way.", "Withdrawn. I'm adding a thank-you to the minutes.", "Lovely. That's the collaboration I put in the RFC."],
			"neutral": ["Retraction noted. Shall we continue the review?", "Thank you. Minuted as resolved.", "Appreciated. I'll update the decision log."],
			"strained": ["Withdrawn. I'll note that it took a pushback.", "Thank you. Eventually is still a timeline.", "Retracted. The retro will be shorter, at least."],
			"hostile": ["Withdrawn. HR will appreciate the reversal.", "Thank you. Your concession is minuted. Forever.", "Retracted. I'm keeping the screenshot."],
		},
	},
	"dm": {
		"thanks": {
			"warm": ["Thank you for the approval. I've moved you up the reliable column. It's a column of two now, and I'm proud of us.", "Approved and merged. I've added a thank-you to the meeting notes and a small heart emoji, which I never do."],
			"strained": ["Thank you for the approval. It has been logged in the approval log with the usual level of enthusiasm.", "Approved, noted. I'm cautiously updating your row in the spreadsheet from amber to slightly less amber."],
			"hostile": ["Thanks for the approval. It does not affect the agenda for our meeting, which still has one bullet.", "Approval received. For the minutes, this does not resolve my concerns about our working relationship."],
		},
		"suspicious": {
			"warm": ["You approved it so fast I had to check it was really you. Did you at least open the RFC? Asking for the retro.", "That approval was suspiciously painless. I've prepared a rebuttal and now have nowhere to put it."],
			"neutral": ["Approved without a single question? Unusual. I've noted it in the timeline, in case it's a trend.", "Thank you, I think. I'd like to understand what changed in your review process. I've booked fifteen minutes."],
			"strained": ["You approved it. After everything. I'm reviewing your approval for hidden conditions.", "An approval from you. I've asked Legal whether I'm allowed to accept it."],
			"hostile": ["Wait, you approved that? I don't know what you're planning, but I've cc'd HR on this thread.", "Approved? I'm documenting this too. Kindness from you is now an open ticket."],
		},
		"relief": {
			"warm": ["Finally merged. Thank you for staying with it. I've added you to the acknowledgements section of the RFC.", "Approved at last. I'm closing the ticket and its sub-tickets, and I'm doing it with a smile."],
			"strained": ["Finally. The ticket is closed. The version count is in the description, for transparency.", "Approved. I'll be presenting the revision history at the retro. You don't have to come. You're invited, though."],
			"hostile": ["Finally. Every version is attached to my escalation draft, which I am keeping in drafts. For now.", "Merged, eventually. I've calculated the hours this took and shared them with the working group."],
		},
		"revise_now": {
			"warm": ["Revised it right there at your desk. v2 is up. I'll backfill the ticket later, which is very wild of me.", "v2 is up already. I skipped the design review for you. Please don't tell the design review."],
			"neutral": ["v2 is on your desk. I revised it in place and will file the paperwork retroactively.", "Revision is up. Turnaround: seconds. The ticket will say minutes, for consistency."],
			"strained": ["v2 is up. I revised it while you watched, which I have logged as unplanned work.", "Revised at your desk. Please note the turnaround time in whatever you're keeping about me."],
			"hostile": ["v2 is up. Revised under observation. I have timestamps if anyone asks, and someone will.", "There's your v2. I've attached the revision to a ticket titled Interruptions, Reviewer."],
		},
		"revise_later": {
			"warm": ["Got your notes on {topics}. v2 will come back through the line. Thank you for being specific, it helps the minutes.", "Revising {topics} now. It'll be back soon, properly documented. You'll love the changelog."],
			"strained": ["Received: {topics}. A revision will follow per the SLA. Not a minute sooner.", "Understood. {Topics} will be addressed. I've opened a ticket and assigned it to my patience."],
			"hostile": ["Fine. I'll revise {topics}. I have also added this review to the agenda for our next one-on-one, which I scheduled.", "{Topics}. Noted, logged, and forwarded to the working group for awareness."],
		},
		"withdrawn": {
			"warm": ["Thank you for reconsidering {topic}. That's exactly the collaborative process I wrote about.", "Thanks for dropping {topic}. I've struck it from the minutes, gently, with a ruler."],
			"neutral": ["Thank you for withdrawing {topic}. I've marked the thread resolved.", "Appreciated. {Topic} has been removed from the decision log. The decision log thanks you."],
			"strained": ["Thank you for withdrawing {topic}. It only took a pushback. I've noted that too.", "Glad we got there on {topic}. The meeting I'd booked about it is now a meeting about how we got there."],
			"hostile": ["You withdrew {topic}. The original is preserved in my notes, as is the reversal.", "Thank you for backing down on {topic}. I've screenshotted both versions for HR."],
		},
		"insist_revise": {
			"warm": ["Okay, you insisted, so I'm revising {topics}. I trust you. I'm also writing it down, lovingly.", "Revising {topics} as requested. I've moved our disagreement to the parking lot doc."],
			"neutral": ["Per your insistence, I'm revising {topics}. My dissent is attached to the ticket as a PDF.", "Very well. {Topics} will be revised. I've noted that we disagree, and that I was outvoted by one."],
			"strained": ["Revising {topics}, as insisted. My objection has been filed. It has its own ticket number.", "Fine. {Topics}. I'll revise it. This will be a whole slide at the retro, with a chart."],
			"hostile": ["You insisted, so I'm revising {topics}. HR now has the full transcript and a highlighted version.", "Revising {topics} under formal protest. The protest is laminated and pinned to my monitor."],
		},
		"insist_escalate": {
			"warm": ["I've asked Morgan to weigh in on {topic}. Please don't take it personally, it's section four of the policy.", "Morgan is breaking the tie on {topic}. I said nice things about you in the summary. Mostly."],
			"neutral": ["Since you insisted on {topic}, I've escalated to Morgan per the escalation policy. I'm the only one who's read it.", "Morgan has the thread on {topic}. I've attached both positions. Mine has an appendix."],
			"strained": ["You insisted on {topic}, so Morgan gets the ticket. I've summarized your position as neutrally as I could manage.", "Escalated {topic} to Morgan. I included the timeline, the context, and the subtext."],
			"hostile": ["{Topic} is now Morgan's problem. And so, I suspect, are you.", "Your insistence on {topic} has been escalated to Morgan, with exhibits A through F."],
		},
		"abandon": {
			"warm": ["I closed the PR. Not worth your afternoon or mine. Helios is merging it. No hard feelings, genuinely.", "I've withdrawn it and let Helios take it. You were thorough. I was tired. That's the retro."],
			"neutral": ["PR closed. Helios is merging it under the automation fallback. It's in the policy, appendix B.", "I've routed it to Helios. It merges without meetings, which I find unsettling but efficient."],
			"strained": ["Fine. I closed it. Helios is merging it, and Helios has never asked me for a v2.", "Closed. Helios will merge it. I've noted the reason as reviewer preference."],
			"hostile": ["Closed. Helios is merging it. It has never once requested changes on my work, so we're getting along.", "I've given it to Helios. If anyone asks why, I've prepared a document. It has your name in it."],
		},
		"grudge": {
			"warm": ["Helios merged it in four seconds. No notes. I miss your notes, a little. Don't tell anyone.", "Small update: Helios merged it and then thanked itself. I thought of you. Fondly, mostly."],
			"neutral": ["Helios merged it in four seconds with no notes. I've added a column for that.", "Following up: Helios merged it and closed the ticket. It didn't even ask for a retro."],
			"strained": ["Helios merged it in four seconds. No notes, no follow-ups, no tone. I'm just saying.", "Following up on my follow-up: it's merged. Helios didn't need fifteen minutes on the calendar."],
			"hostile": ["Helios merged it in four seconds. No notes. I've updated the spreadsheet about you. It now has a chart.", "Reminder that Helios merged my PR without a single change request. I've shared the comparison with Morgan."],
		},
		"escalate": {
			"warm": ["I've looped in Morgan. It's procedure, not you. I put you in the reliable column in the summary.", "Morgan has it now. I made sure the escalation was very polite. There's a cover letter."],
			"neutral": ["Escalated to Morgan per the matrix. I've attached the matrix, in case nobody has seen it, which they haven't.", "Morgan has the ticket. I expect it goes to Helios next, per paragraph seven."],
			"strained": ["I've looped in Morgan. I've summarized our review history as neutrally as my keyboard allows.", "Morgan is in the thread now. Please expect a calendar invite with a vague title."],
			"hostile": ["Morgan is now involved. So is my timeline doc, which is color-coded by your decisions.", "I've escalated to Morgan and requested a working-group review of your reviews."],
		},
	},
}

## Morgan's notes in the manager DM when Helios takes a PR off the human desk.
## {author} and {pr} are filled in. "cap" is an aside appended to the original
## third-round escalation message; the others stand alone. Colored by the
## author's mood at the time, never by whether anyone was right.
const MORGAN := {
	"cap": {
		"warm": ["{author} made a point of saying it isn't personal. I believe that.", "{author} asked me to tell you thanks for the patience."],
		"neutral": ["", ""],
		"strained": ["{author} asked me to note how long it took.", "{author} would like fewer rounds next time. So would I."],
		"hostile": ["{author} used the word again more than I'd like. Let's keep it civil.", "{author} attached a timeline. I haven't opened it. I'm not going to."],
	},
	"escalate": {
		"warm": ["{author} looped me in on {pr} early, mostly to spare you both another round. Helios has it now. No harm done.", "{author} asked me to take {pr} off your plate. Helios has it. They said to tell you it's not about you."],
		"neutral": ["{author} looped me in on {pr}. I've handed it to Helios so you two can move on.", "{author} sent {pr} to me instead of back to you. Helios has it now. Let's not make that a habit."],
		"strained": ["{author} escalated {pr} to me rather than revise it. Helios has it. I'd like fewer of these.", "{author} forwarded me {pr} with the subject line thoughts. Helios has it now. I have thoughts too."],
		"hostile": ["{author} escalated {pr} and asked about a different reviewer. Helios has it. We should talk about how this is going.", "{author} looped me in on {pr} with a timeline attached. Helios has the PR. I have the timeline."],
	},
	"insist_escalate": {
		"warm": ["You held your ground on {pr} and {author} brought it to me, politely. Helios has it now. Nobody's in trouble.", "{author} and you disagreed on {pr}, so it came to me. Helios took it. You two seem fine."],
		"neutral": ["{author} disputed your review of {pr} and you didn't budge, so it's mine now. Helios has it.", "{pr} reached a standoff with {author}, which means it reached me. I've handed it to Helios."],
		"strained": ["{author} brought me {pr} after you insisted. Helios has it. Pick the hills you want to be seen on.", "Standoff on {pr}. {author} wanted a referee; Helios got the PR. Nobody got what they wanted."],
		"hostile": ["{author} escalated {pr} after you insisted, and copied HR on the thread for some reason. Helios has it. Let's talk.", "{author} would like it noted that you insisted on {pr}. It's noted. Helios has the PR now."],
	},
	"abandon": {
		"warm": ["{author} closed {pr} and had Helios merge it instead. They said it wasn't worth your afternoon. Kind of them.", "{pr} skipped the rest of review: {author} handed it to Helios. They made a point of saying it's not on you."],
		"neutral": ["{author} closed {pr} and asked Helios to merge it. I'd rather people didn't route around review.", "{pr} went to Helios after you sent it back. {author}'s call. I'm keeping an eye on how often that happens."],
		"strained": ["{author} pulled {pr} from your desk and gave it to Helios. That's a trend I don't love.", "Helios merged {pr} for {author}. It took four seconds. Leadership noticed the four seconds."],
		"hostile": ["{author} took {pr} to Helios rather than revise it for you. Leadership loves that story. I don't.", "{author} closed {pr} and had Helios merge it, with a note about you. I deleted the note. Let's fix this."],
	},
}

const BY_AUTHOR := {"Maya": MAYA, "Theo": THEO, "Inez": INEZ}

## Templates for an author, channel ("desk" or "dm"), node, and mood; [] if none.
static func lines(author: String, channel: String, node: String, mood: String) -> Array:
	return BY_AUTHOR.get(author, MAYA).get(channel, {}).get(node, {}).get(mood, [])

## Every node with authored lines on a channel.
static func nodes(channel: String) -> Array:
	var result: Array = []
	for author: String in BY_AUTHOR:
		for node: String in BY_AUTHOR[author].get(channel, {}):
			if node not in result: result.append(node)
	return result

## Morgan's notes for a node and mood, blanks dropped.
static func morgan(node: String, mood: String) -> Array:
	return MORGAN.get(node, {}).get(mood, []).filter(func(line: String) -> bool: return not line.is_empty())
