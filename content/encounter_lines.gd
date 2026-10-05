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
			"warm": ["Approved first try. You and me are the best pipeline in this building. Helios wishes.", "Thanks for the approval. Told standup you're my favorite reviewer. June put it in a deck. Worth it."],
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
			"strained": ["You insisted, so I'm revising {topics}. Remembering this one.", "Okay. {Topics}. v2 later. My commit message will be passive-aggressive. June calls that circling back."],
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
			"neutral": ["I've looped Morgan in. Morgan can hand it to Helios. Out of our hands.", "Escalated to Morgan. Not a threat. Just alignment. I learned that word from June."],
			"strained": ["I'm looping in Morgan. We need an adult in the room.", "Escalated to Morgan. Figured a third opinion beats another round with you."],
			"hostile": ["Looped in Morgan. Attached the review. Attached my feelings about the review.", "Morgan has it now. Helios gets it after. You get a nice quiet afternoon."],
		},
	},
}

## June: growth PM turned engineer. Polished, process-minded, passive-aggressive.
## She will circle back. It is in the metrics deck.
const JUNE := {
	"desk": {
		"pitch": {
			"warm": ["Sent to you first. You're my highest-impact reviewer.", "Ticket, one-pager, and a thank-you in advance. For you.", "I told stakeholders you'd be fair. No pressure."],
			"strained": ["Attached: the PR, the deck, and a quick sync hold.", "Please review at your earliest bandwidth.", "I've looped myself in on this review. For visibility."],
			"hostile": ["Before you start: I'm capturing learnings live.", "Here's my PR. Leadership has a copy of this thread.", "Review it. Stakeholders are watching. So am I."],
		},
		"return": {
			"warm": ["Circling back per your notes. Executed to the letter.", "Revision attached. I updated the dashboard fondly.", "Round two. I booked zero syncs about it. Growth."],
			"strained": ["Resubmitted. The ticket now has a sub-ticket about you.", "Circling back, as aligned with your preferences.", "Revision attached. Please confirm alignment async."],
			"hostile": ["Circling back again. My retro slide is ready.", "Revised. You're now a line item in my risks column.", "Resubmitted. Disagree and commit. Mostly disagree."],
		},
		"revised": {
			"warm": ["Done. Revised live, like we aligned in spirit.", "There. Fastest turnaround on the dashboard.", "Updated while you waited. I even skipped the one-pager."],
			"neutral": ["Revised. I'll backfill the ticket post-sync.", "Here. Revision drafted, shipped, and in the deck.", "Updated in place. Changelog to follow, async."],
			"strained": ["Revised in real time. My bandwidth did not consent.", "There. Please note the turnaround in your metrics.", "Done. I've tagged this as unplanned work."],
			"hostile": ["Revised. Timestamped. Screenshotted. Your move.", "There. I'll be billing this to the growth budget.", "Done, under duress. The duress has its own KPI."],
		},
		"flag": {
			"warm": ["{Topic}? Love that. I'll trust your process.", "Flagged. Adding it to my learnings doc.", "Raised. I'll bring snacks to the retro."],
			"strained": ["{Topic}. Can we get that in the ticket?", "Flagged. I'm adding a funnel stage for your flags.", "Interesting. That wasn't in the deck."],
			"hostile": ["{Topic}. Captured, with a timestamp.", "Another flag. Leadership loves a trend line.", "Flagged. I've started a separate dashboard for you."],
		},
		"unflag": {
			"warm": ["Retracted. Thank you for circling back so fast.", "Withdrawn. I'll pull it from the deck, gently.", "Appreciated. That's why you're a force multiplier."],
			"strained": ["Withdrawn. I'll capture the reversal for context.", "Thank you. The deck will show you hesitated.", "Retracted. I've updated the timeline slide. Again."],
			"hostile": ["Withdrawn. The original stays in my learnings.", "Changing your mind is a trend now. Just flagging.", "Retracted. Leadership will want both versions."],
		},
		"consult": {
			"warm": ["Ask Helios. You'll still own it, which I prefer.", "Sure. Just loop me in on whatever it hallucinates.", "Go ahead. Your judgment outperforms its, per my metrics."],
			"strained": ["Consulting Helios. I'll flag the dependency.", "Asking the assistant. Is that on the roadmap?", "Interesting. Helios reviewed my last PR faster."],
			"hostile": ["Ask Helios. It at least reads the deck.", "Outsourcing your review. Flagged for leadership.", "Helios is aligned with me. It read the strategy doc."],
		},
		"thanks": {
			"warm": ["Thank you. Your row on my dashboard just went green.", "Approved. I'll shout you out in the all-hands deck.", "Love that. You're officially my preferred reviewer."],
			"strained": ["Thank you. I'll log the approval, neutrally.", "Approved. Received. Tracked. Thanks, I suppose.", "Thank you. That was within SLA, for once."],
			"hostile": ["Thanks. This doesn't move my metrics on you.", "Approved. Acknowledged without enthusiasm.", "Thank you. I've still booked the sync about you."],
		},
		"suspicious": {
			"warm": ["Approved already? You're sure you read the deck?", "That was quick. Did you at least skim the one-pager?", "Approved? I had a whole objection-handling slide. Darn."],
			"neutral": ["Approved? Just like that? Can I get that in writing?", "Wait. You approved it. What's the ask?", "Approved without a single question. Off-trend."],
			"strained": ["Wait, you approved that? What's the catch?", "An approval from you. I'll have Legal take a look.", "You approved it. I'm double-clicking for traps."],
			"hostile": ["You approved my PR? Who told you to be nice?", "Approved. Forwarding to leadership, just in case.", "Wait. You approved that? Adding it to the deck too."],
		},
		"relief": {
			"warm": ["Finally. Thank you for staying aligned with me.", "Finally. Closing the ticket with a little bow on it.", "Approved. I'm adding a celebration slide."],
			"neutral": ["Finally. Moving the ticket to done, done, done.", "Approved. The roadmap can finally rest.", "Finally. I'll update the burndown dashboard."],
			"strained": ["Finally. I've tracked how many versions that took.", "Approved at last. The retro deck writes itself.", "Finally. I'll attach the full timeline to the ticket."],
			"hostile": ["Finally. Every version is in my leadership update.", "Approved. Eventually. Leadership will find that fun.", "Finally. Don't think this closes my other ticket."],
		},
		"revise_now": {
			"warm": ["{Topic}? Quick win. Give me a sec.", "One moment. Revising before the dashboard notices.", "Give me a sec. I'll skip the one-pager this once."],
			"neutral": ["Give me a sec. Spinning up a ticket to revise it.", "{Topic}. One moment, revising in place.", "Hold, please. Unblocking you now."],
			"strained": ["Give me a sec. Logging this as an interruption.", "{Topic}. Disagree and commit. Revising.", "One moment. Please don't move; I'm taking notes."],
			"hostile": ["Give me a sec. And a stakeholder.", "{Topic}. Revising. Leadership is looped in.", "Hold still. I'm revising and timestamping."],
		},
		"revise_later": {
			"warm": ["Love it. v2 will follow, per our lovely process.", "{Topic}. Captured kindly. Circling back soon.", "Back to my desk. You'll see it again this sprint."],
			"strained": ["Understood. A revision will follow, eventually.", "{Topic}. Logged. Expect v2 per the SLA.", "Fine. I'll revise and update the blockers slide."],
			"hostile": ["Revision to follow. So does an agenda item.", "{Topic}. Logged as your call, not mine.", "I'll revise it. Stakeholders will hear of it."],
		},
		"pushback": {
			"warm": ["{Topic}? I thought we aligned on that in sync?", "Is {topic} really worth a v2?", "{Topic}? Could we park it for the retro?"],
			"neutral": ["{Topic}? Is there data behind that?", "Respectfully, is {topic} in scope this quarter?", "{Topic}? Can I see the metrics on that first?"],
			"strained": ["{Topic}? Per which version of the standard?", "Are we really blocking on {topic}?", "{Topic}. Was that on the roadmap?"],
			"hostile": ["{Topic}? Shall I loop in leadership?", "You're blocking me on {topic}? Interesting.", "{Topic}? Happy to take that offline. With HR."],
		},
		"abandon": {
			"warm": ["Not worth your bandwidth. Helios can merge it.", "I'll close it and let Helios take it. All good.", "Let's not block on me. Helios will merge it."],
			"neutral": ["Closing it. Helios will merge it, per the fallback.", "Fine. Routing it to Helios. Fewer handoffs.", "Withdrawing the PR. Helios has merge rights now."],
			"strained": ["Fine. Helios can merge it. Its cycle time is great.", "Closed. Helios doesn't need a one-pager.", "I'll take this to Helios. It ships on time."],
			"hostile": ["Closed. Helios will merge it without the friction.", "Fine. Helios merges it. You can explain the dip.", "Done here. Helios reviews me now. Circle back never."],
		},
		"escalate": {
			"warm": ["I'll ask Morgan to weigh in. It's process, not you.", "Looping in Morgan, per policy. I'll say nice things.", "Morgan should see this. I'll loop you in, warmly."],
			"neutral": ["I'm looping in Morgan, per the escalation path.", "Escalating to Morgan. I've attached a flow diagram.", "Morgan will decide. That's what the playbook says."],
			"strained": ["Looping in Morgan. Please hold for the invite.", "Escalating to Morgan. I've summarized your position.", "Morgan can unblock us. I've attached your history."],
			"hostile": ["Morgan is now involved. So is my timeline slide.", "I'm escalating to Morgan. And maybe leadership.", "Morgan will hear about this. In a deck."],
		},
		"insist_revise": {
			"warm": ["Okay. You're the reviewer. Revising, with love.", "Understood. I'll revise it and update the one-pager.", "Fine. I trust you. I'm also writing it down."],
			"neutral": ["Very well. Disagree and commit. Revising.", "Understood. I'll revise and flag the disagreement.", "Heard. Overruled. Revising."],
			"strained": ["Fine. Revising. My dissent is in the ticket.", "As you insist. I'll revise and track the insistence.", "Revising. This will be a slide in the retro."],
			"hostile": ["Fine. I'll revise. Leadership gets the extended cut.", "Revising under protest. Formal protest. With a chart.", "You win this round. The dashboard remembers."],
		},
		"insist_escalate": {
			"warm": ["Then let's let Morgan decide. Nothing personal.", "Alright. I'll ask Morgan to break the tie.", "Okay. Morgan can unblock us. I'll bring muffins."],
			"neutral": ["Then I'm taking it to Morgan, per the playbook.", "Understood. Escalating to Morgan for alignment.", "In that case, Morgan decides. I've sent the invite."],
			"strained": ["Then Morgan can hear both sides. Mine has slides.", "Insisting? Looping in Morgan, respectfully.", "Fine. Morgan gets the ticket and the subtext."],
			"hostile": ["Then it's going to Morgan. With an appendix.", "Insist all you like. Morgan is already reading.", "Escalated to Morgan. I've attached your tone."],
		},
		"withdrawn": {
			"warm": ["Thank you. I knew we'd get to alignment.", "Withdrawn. I'm adding a shout-out to the deck.", "Love that. That's the collaboration in my one-pager."],
			"neutral": ["Retraction received. Shall we continue?", "Thank you. Marked as resolved on the dashboard.", "Appreciated. I'll update the strategy doc."],
			"strained": ["Withdrawn. I'll flag that it took a pushback.", "Thank you. Eventually is still a timeline.", "Retracted. The retro will be shorter, at least."],
			"hostile": ["Withdrawn. Leadership will appreciate the pivot.", "Thank you. Your concession is in the deck. Forever.", "Retracted. I'm keeping the screenshot."],
		},
	},
	"dm": {
		"thanks": {
			"warm": ["Thank you for the approval. I've moved you into my top-quartile reviewers. It's a quartile of two now, and I'm proud of us.", "Approved and merged. I've added a shout-out to the sync notes and a small heart emoji, which I never do."],
			"strained": ["Thank you for the approval. It's been logged on the dashboard with the usual level of enthusiasm.", "Approved, acknowledged. I'm cautiously updating your row from amber to slightly less amber."],
			"hostile": ["Thanks for the approval. It does not change the agenda for our sync, which still has one bullet.", "Approval received. Just flagging: this does not resolve my concerns about our working relationship."],
		},
		"suspicious": {
			"warm": ["You approved it so fast I checked it was really you. Did you at least open the deck? Asking for the retro.", "That approval was suspiciously frictionless. I'd prepared an objection-handling slide and now it has nowhere to go."],
			"neutral": ["Approved without a single question? Off-trend. I've flagged it on the dashboard, in case it's a pattern.", "Thank you, I think. I'd love to understand what changed in your review funnel. I've booked fifteen minutes."],
			"strained": ["You approved it. After everything. I'm double-clicking on your approval for hidden conditions.", "An approval from you. I've asked Legal whether I'm allowed to accept it."],
			"hostile": ["Wait, you approved that? I don't know what you're planning, but I've looped leadership in on this thread.", "Approved? Adding this to the deck too. Kindness from you is now an open ticket."],
		},
		"relief": {
			"warm": ["Finally merged. Thank you for staying with it. I've added you to the acknowledgements slide of the deck.", "Approved at last. I'm closing the ticket and its sub-tickets, and I'm doing it with a smile."],
			"strained": ["Finally. The ticket is closed. The version count is in the description, for transparency.", "Approved. I'll be presenting the revision timeline at the retro. You don't have to come. You're invited, though."],
			"hostile": ["Finally. Every version is attached to my leadership update, which I am keeping in drafts. For now.", "Merged, eventually. I've calculated the hours this took and shared them with stakeholders."],
		},
		"revise_now": {
			"warm": ["Revised it right there at your desk. v2 is up. I'll backfill the ticket later, which is very wild of me.", "v2 is up already. I skipped the one-pager for you. Please don't tell the one-pager."],
			"neutral": ["v2 is on your desk. I revised it in place and will backfill the ticket async.", "Revision is up. Cycle time: seconds. The dashboard will say minutes, for consistency."],
			"strained": ["v2 is up. I revised it while you watched, which I've tagged as unplanned work.", "Revised at your desk. Please note the turnaround in whatever metrics you're keeping on me."],
			"hostile": ["v2 is up. Revised under observation. I have timestamps if anyone asks, and someone will.", "There's your v2. I've filed the revision under a ticket titled Interruptions, Reviewer."],
		},
		"revise_later": {
			"warm": ["Got your notes on {topics}. v2 will come back through the line. Thank you for being specific, it really helps the deck.", "Revising {topics} now. Circling back soon, fully documented. You'll love the changelog."],
			"strained": ["Received: {topics}. A revision will follow per the SLA. Not a minute sooner.", "Understood. {Topics} will be addressed. I've opened a ticket and assigned it to my patience."],
			"hostile": ["Fine. I'll revise {topics}. I've also added this review to the agenda for our next one-on-one, which I scheduled.", "{Topics}. Captured, tracked, and shared with stakeholders for visibility."],
		},
		"withdrawn": {
			"warm": ["Thank you for reconsidering {topic}. That's exactly the cross-functional alignment I put in the deck.", "Thanks for dropping {topic}. I've pulled it from the slides, gently, with a laser pointer."],
			"neutral": ["Thank you for withdrawing {topic}. I've marked the thread resolved.", "Appreciated. {Topic} has been removed from the roadmap. The roadmap thanks you."],
			"strained": ["Thank you for withdrawing {topic}. It only took a pushback. I've flagged that too.", "Glad we aligned on {topic}. The sync I'd booked about it is now a sync about how we got there."],
			"hostile": ["You withdrew {topic}. The original is preserved in my learnings doc, as is the pivot.", "Thank you for backing down on {topic}. I've screenshotted both versions for leadership."],
		},
		"insist_revise": {
			"warm": ["Okay, you insisted, so I'm revising {topics}. I trust you. I'm also writing it down, lovingly.", "Revising {topics} as requested. I've moved our disagreement to the parking-lot slide."],
			"neutral": ["Per your insistence, I'm revising {topics}. Disagree and commit. My dissent is attached to the ticket as a PDF.", "Very well. {Topics} will be revised. I've flagged that we disagree, and that I was outvoted by one."],
			"strained": ["Revising {topics}, as insisted. My objection has been filed as a risk. It has its own ticket number.", "Fine. {Topics}. I'll revise it. This will be a whole slide at the retro, with a chart."],
			"hostile": ["You insisted, so I'm revising {topics}. Leadership now has the full thread and a highlighted version.", "Revising {topics} under formal protest. The protest has a slide, a chart, and a north star."],
		},
		"insist_escalate": {
			"warm": ["I've asked Morgan to weigh in on {topic}. Please don't take it personally, it's in the escalation playbook.", "Morgan is breaking the tie on {topic}. I said nice things about you in the summary. Mostly."],
			"neutral": ["Since you insisted on {topic}, I've escalated to Morgan per the escalation playbook. I'm the only one who's read it.", "Morgan has the thread on {topic}. I've attached both positions. Mine has an appendix and a chart."],
			"strained": ["You insisted on {topic}, so Morgan gets the ticket. I've summarized your position as neutrally as I could manage.", "Escalated {topic} to Morgan. I included the timeline, the context, and the subtext."],
			"hostile": ["{Topic} is now Morgan's problem. And so, I suspect, are you.", "Your insistence on {topic} has been escalated to Morgan, with a deck. Slides A through F."],
		},
		"abandon": {
			"warm": ["I closed the PR. Not worth your bandwidth or mine. Helios is merging it. No hard feelings, genuinely.", "I've withdrawn it and let Helios take it. You were thorough. I was out of bandwidth. That's the learning."],
			"neutral": ["PR closed. Helios is merging it under the automation fallback. It's in the playbook, appendix B.", "I've routed it to Helios. It merges without syncs, which I find unsettling but very efficient."],
			"strained": ["Fine. I closed it. Helios is merging it, and Helios has never once asked me for a v2.", "Closed. Helios will merge it. I've tagged the root cause as reviewer preference."],
			"hostile": ["Closed. Helios is merging it. It has never once requested changes on my work, so we're super aligned.", "I've given it to Helios. If anyone asks why, I've prepared a one-pager. It has your name in it."],
		},
		"grudge": {
			"warm": ["Helios merged it in four seconds. No notes. I miss your notes, a little. Don't tell anyone.", "Quick update: Helios merged it and then thanked itself. I thought of you. Fondly, mostly."],
			"neutral": ["Helios merged it in four seconds with no notes. I've added a column to the dashboard for that.", "Circling back: Helios merged it and closed the ticket. It didn't even ask for a retro."],
			"strained": ["Helios merged it in four seconds. No notes, no follow-ups, no tone. Just flagging.", "Circling back on my circle-back: it's merged. Helios didn't need fifteen minutes on the calendar."],
			"hostile": ["Helios merged it in four seconds. No notes. I've updated the dashboard about you. It has a trend line now.", "Friendly reminder that Helios merged my PR without a single change request. I've shared the comparison with Morgan."],
		},
		"escalate": {
			"warm": ["I've looped in Morgan. It's process, not you. I put you in the top quartile in the summary.", "Morgan has it now. I made sure the escalation was very polite. There's an executive summary."],
			"neutral": ["Escalated to Morgan per the playbook. I've attached the playbook, in case nobody has seen it, which they haven't.", "Morgan has the ticket. I expect it goes to Helios next, per slide seven."],
			"strained": ["I've looped in Morgan. I've summarized our review history as neutrally as my keyboard allows.", "Morgan is in the thread now. Please expect a quick sync invite with a vague title."],
			"hostile": ["Morgan is now involved. So is my timeline slide, which is color-coded by your decisions.", "I've escalated to Morgan and requested a leadership review of your reviews."],
		},
	},
}

## Penny: the eager new junior, hired the first Wednesday. Over-prepared, sorry
## about everything, easily impressed, and a little too fond of Helios.
const PENNY := {
	"desk": {
		"pitch": {
			"warm": ["Brought you this one first. You're my favorite reviewer.", "I made you a flashcard for this PR. It's laminated.", "Hi again. I practiced this pitch on Helios. It clapped."],
			"strained": ["Sorry. Here's another one. I triple-checked it this time.", "I'm so sorry in advance. I read it four times.", "Hi. Sorry. I'll be quiet while you read it. Mostly."],
			"hostile": ["Sorry. I'll just leave this here and go stand somewhere.", "Helios said you'd be busy. I'm sorry to add to it.", "I'm sorry for whatever I did. Here's the PR anyway."],
		},
		"return": {
			"warm": ["It's back. I fixed it with my good pen. Thank you.", "Version two. I learned so much. I wrote it all down.", "Back again. Helios said you'd be proud. Are you proud?"],
			"strained": ["Sorry it's back. I tried really hard on this one.", "It's back. I apologized to it first. Is that weird?", "Here it is again. I color-coded my sorries."],
			"hostile": ["It's back. I'm sorry. I'm always sorry. You know that.", "Here. I asked Helios how to make you happy. It paused.", "Back again. I'll stop apologizing soon. Sorry."],
		},
		"revised": {
			"warm": ["Done. Was that fast? Helios timed me. It said adequate.", "Okay, okay, pushed. My bell was jingling the whole time.", "Fixed it right here. That felt so professional. Wow."],
			"neutral": ["Pushed. Sorry if the typing was loud. I type with feeling.", "There. New version. I checked it against my checklist.", "Done. Sorry for breathing on your desk."],
			"strained": ["Pushed. Sorry. I typed it with my eyes squeezed shut.", "There. I hope that's what you meant. Sorry if it isn't.", "Done. Please don't look at my paws, they're shaking."],
			"hostile": ["Pushed. I'll go stand by the plant now. Sorry.", "Done. Helios helped. Helios is the only one who helps.", "There. Sorry. I'm going to go be quiet somewhere."],
		},
		"flag": {
			"warm": ["{Topic}? Ooh. Can I write that down?", "Wow, you found something. Teach me how you do that.", "{Topic}. Okay. Adding it to my flashcards."],
			"strained": ["{Topic}? Sorry. Sorry. I'll fix it. Sorry.", "Oh no. Another one. My bell is going off.", "{Topic}. Into the red notebook it goes."],
			"hostile": ["{Topic}. Adding it to my failures list.", "Another flag. I'll ask Helios why I'm like this.", "Flagged. Sorry for existing near you."],
		},
		"unflag": {
			"warm": ["Oh, thank you. I was about to cry a tiny bit.", "Unflagged. You're so kind. I'm telling Helios.", "Wow, you took it back. That's so generous."],
			"strained": ["Oh. Unflagged. Thank you. Sorry it was there.", "Thank you. I'll still feel bad about it, though.", "Withdrawn? Okay. I won't ask why. Sorry for asking."],
			"hostile": ["Unflagged. Thank you. I'm still sorry, though.", "Oh. Okay. I'll stop drafting my apology, then.", "Thank you. I'm not sure what that means. Sorry."],
		},
		"consult": {
			"warm": ["You asked Helios. Isn't it amazing? It knows my name.", "Helios helped me with this. It'll say nice things.", "Ooh, ask Helios. Tell it Penny says hello."],
			"strained": ["Helios? Okay. Sorry I wasn't enough on my own.", "Asking Helios. That's smart. I should have done that.", "Oh. Helios. Please tell it I tried really hard."],
			"hostile": ["Ask Helios. It likes me. I think it's the only one.", "Helios will explain me to you. It's better at it.", "Go ahead. Helios already knows everything I did."],
		},
		"thanks": {
			"warm": ["Thank you. I'm going to frame this approval.", "Approved. Wow. I'm telling my mom. And Helios.", "Thank you so much. I'll remember this forever."],
			"strained": ["Approved? Thank you. Sorry for the trouble before.", "Oh. Thank you. I'll try to deserve that.", "Thanks. My bell finally stopped."],
			"hostile": ["Thank you. I didn't think you'd ever say yes.", "Approved. Okay. Thank you. I'm sorry about before.", "Thanks. I'll try not to cry about it at my desk."],
		},
		"suspicious": {
			"warm": ["Wait, already? Did I do it? Did I actually do it?", "Approved that fast? Are you sure? Sorry, are you sure?", "No notes? Is this a test? Helios said there'd be tests."],
			"neutral": ["Wait. Approved? Should I be worried? Sorry.", "Approved? That's it? Did I miss a step?", "Oh. Approved. Is that allowed on the first try?"],
			"strained": ["Approved? After everything? Is this a trick? Sorry.", "You approved it. I don't know what to do with that.", "Wait. Are you just being nice because I'm new?"],
			"hostile": ["Approved? You? Did Helios ask you to be nice to me?", "You approved it. Now I'm scared. Sorry. Scared.", "Wait. Why? What did I do? Sorry. What did I do?"],
		},
		"relief": {
			"warm": ["Finally. We did it. Can we get a picture?", "Finally. Thank you for being so patient with me.", "Finally merged. I learned so much. I made a doc."],
			"neutral": ["Finally. Oh, thank goodness. Thank you.", "Finally. My bell can rest now.", "Finally. I'm going to tell Helios it worked."],
			"strained": ["Finally. Sorry it took so many versions.", "Finally. I'm so sorry about all of that.", "Finally. I owe you an apology card. A big one."],
			"hostile": ["Finally. Thank you. I'll try harder. I always try harder.", "Finally. Sorry for every single version.", "Finally. Helios says I'm improving. You'd know better."],
		},
		"revise_now": {
			"warm": ["{Topic}? Oh, give me a sec. I've got this.", "Give me a sec. I've been practicing this exact thing.", "On it. Watch, I made a shortcut for fixing things."],
			"neutral": ["Give me a sec. Sorry. Sorry. Almost there.", "{Topic}? Fixing it right now. Sorry.", "Hold on, I'll do it now. I have a checklist for this."],
			"strained": ["Give me a sec. Sorry. My paws are shaking a little.", "{Topic}. Right away. Sorry, sorry, right away.", "One sec. Please don't leave. Sorry. One sec."],
			"hostile": ["Give me a sec. I'll fix it. I'll fix everything.", "{Topic}. Fixing it now. Please don't be mad.", "One sec. Helios is helping me. Someone has to."],
		},
		"revise_later": {
			"warm": ["{Topic}. Got it. v2 will be my best work yet.", "Okay. Back in line. I'll bring you a better one.", "Noted in my good notebook. See you soon."],
			"strained": ["{Topic}. Okay. Sorry. I'll send a new one.", "Okay. Back in line. I'll try harder this time.", "Sure. I'll revise it tonight. And maybe all night."],
			"hostile": ["{Topic}. I'll have Helios check me first.", "Back in line. I'll be quieter in v2. Sorry.", "Okay. I'll fix it. I'll fix whatever you want."],
		},
		"pushback": {
			"warm": ["Um. {Topic}? Could we maybe keep it? Sorry.", "Sorry, {topic}? Is it a big deal? I can learn.", "{Topic}? I'm sorry, I really liked that part."],
			"neutral": ["{Topic}? Sorry, is that one really needed?", "Um, {topic}? I'm sorry, could you explain?", "Sorry, {topic}? I worked so hard on that bit."],
			"strained": ["{Topic}? Sorry. Are you sure? Sorry for asking.", "Um. {Topic}? Is that the one you want? Sorry.", "{Topic}? I'm sorry, I don't understand why."],
			"hostile": ["{Topic}? Did I do something to you? Sorry.", "Sorry. {Topic}? Is this because I'm new?", "{Topic}? I'm sorry. Please, can it stay?"],
		},
		"abandon": {
			"warm": ["You know what, Helios can merge it. Go have lunch.", "Helios offered to merge it. It's so helpful. Bye.", "I'll let Helios take it. You've done so much already."],
			"neutral": ["Okay. Helios will merge it. Sorry for the trouble.", "I'll ask Helios to merge it instead. It said yes.", "Never mind. Helios is merging it. Sorry, sorry."],
			"strained": ["Helios can merge it. It never makes me cry.", "Okay. Helios is merging it. I'm sorry I wasted your time.", "Closing it. Helios says it'll take care of me."],
			"hostile": ["Helios is merging it. Helios still likes me. I think.", "I'm closing it. Helios will merge it. Sorry. Bye.", "Helios can have it. I'm going to go sit in the stairwell."],
		},
		"escalate": {
			"warm": ["I'll ask Morgan what to do. You're still the best.", "Can Morgan look? I want to learn how to do this right.", "I'm going to ask Morgan. Morgan always knows. Sorry."],
			"neutral": ["I'm so sorry. I'm asking Morgan to help me with this.", "Okay. I'll ask Morgan. I don't know what else to do.", "Morgan said to ask if I got stuck. I'm stuck. Sorry."],
			"strained": ["I'm asking Morgan. I'm sorry. I'm so sorry.", "I'm getting Morgan. My bell won't stop. Sorry.", "Morgan will know what I did. I'll ask Morgan."],
			"hostile": ["I'm going to Morgan. I'm sorry. I don't know what else.", "Morgan needs to help me. I can't do this alone.", "I'm asking Morgan. Please don't be mad at me too."],
		},
		"insist_revise": {
			"warm": ["Okay, you're the expert. I'll redo it. Thank you.", "Okay. I'll revise it. I trust you so much.", "You're sure? Okay. Learning moment. Revising."],
			"neutral": ["Okay. Sorry. I'll revise it. Back in line.", "Okay. I'll redo it. Sorry for asking.", "Understood. Revising. Adding it to my notes."],
			"strained": ["Okay. I'll fix it. Sorry I argued. I never argue.", "Revising. Sorry. I shouldn't have said anything.", "Okay. I'll redo it. My bell is very quiet now."],
			"hostile": ["Okay. I'll revise it. I won't ask again. Sorry.", "Revising. I'm sorry I spoke. I'll go.", "Fine. Okay. I mean okay. Revising. Sorry."],
		},
		"insist_escalate": {
			"warm": ["Okay. Can we ask Morgan? I just want to learn.", "Let's ask Morgan together. Morgan's so smart.", "I'll ask Morgan to explain it to both of us."],
			"neutral": ["Okay. I'm asking Morgan. Sorry. I don't know what to do.", "Then I'll ask Morgan. Morgan always helps me.", "Sorry. I'm going to Morgan with this one."],
			"strained": ["Okay. Morgan can decide. I'm sorry I made it hard.", "I'm taking it to Morgan. My paws are shaking.", "Morgan will know. I'm asking Morgan. Sorry."],
			"hostile": ["I'm going to Morgan. Please don't hate me.", "Morgan said I could always ask. I'm asking.", "I'm asking Morgan. I don't want to fight. I can't."],
		},
		"withdrawn": {
			"warm": ["Thank you so much. You're the best reviewer ever.", "Oh, thank you. I'll make you a thank-you flashcard.", "Really? Thank you. Helios was so sure about you."],
			"neutral": ["Oh. Thank you. Okay. Let's keep going.", "Thank you. Sorry for asking. Thank you.", "Withdrawn? Thank you. I'll be so careful now."],
			"strained": ["Oh, thank you. I'm sorry I asked. Thank you.", "Thank you. I didn't think you'd listen.", "Okay. Thank you. I'll be quiet for the rest."],
			"hostile": ["Thank you. I'm still sorry. For everything.", "Oh. Okay. Thank you. I'll stop talking now.", "Withdrawn. Thank you. Please don't change your mind."],
		},
	},
	"dm": {
		"thanks": {
			"warm": ["Thank you for approving my PR. I printed the approval and taped it above my desk. Helios said that was a lovely gesture.", "You approved it. I've added you to my list of people who believe in me. It's a short list. You're at the top, above Helios."],
			"strained": ["Thank you for the approval. I know I've been a lot. I'm working on being less of a lot.", "Approved. Thank you. I've been so nervous about this one that my bell has been jingling since lunch."],
			"hostile": ["Thank you for approving it. I wasn't sure you ever would. I'm sorry about whatever I did before.", "Approved. Thank you. I asked Helios if this means we're okay now. It changed the subject."],
		},
		"suspicious": {
			"warm": ["You approved it so fast. Did you read the whole thing? Sorry. I just want to make sure I earned it.", "No notes at all? I prepared answers for eleven questions. Should I send them anyway? I'll send them anyway."],
			"neutral": ["You approved it with no notes. Is that normal? Helios says it's normal. I wanted to hear it from a person.", "Wait, you approved it right away? I've reread it three times looking for what I missed. Sorry."],
			"strained": ["You approved it. After everything. I'm not sure what it means. Is it a test? Helios says not everything is a test.", "An approval. From you. I'm so relieved I'm a little suspicious. Sorry. Is that rude?"],
			"hostile": ["You approved it. I don't understand. Did Morgan tell you to be nice to the new hire? You can tell me.", "Wait, you approved that? I keep waiting for the part where it gets taken back. Sorry. I'll keep waiting."],
		},
		"relief": {
			"warm": ["Finally merged. Thank you for being so patient with me. I wrote down everything I learned. It's nine pages.", "Finally. We did it together. I'd like to put that in my onboarding feedback, if that's okay."],
			"strained": ["Finally approved. I'm so sorry it took so many versions. I'm going to make a checklist so it never happens again.", "Finally. Thank you. I know that took forever. Helios says forever is a learning curve."],
			"hostile": ["Finally. I'm sorry for every version before this one. I've apologized to Helios too, so it's fair.", "Finally merged. I hope this helps. I'll try to need fewer versions. I'll try so hard."],
		},
		"revise_now": {
			"warm": ["I revised it right there at your desk. It's waiting for you. That was the most exciting thing I've done all week.", "New version's on your desk. I fixed {topics} while you watched. Sorry if I was breathing loudly."],
			"neutral": ["Revised it on the spot. It's on your desk now. Sorry for hovering.", "Did {topics} right away so I wouldn't worry about it all night. It's on your desk."],
			"strained": ["It's on your desk. I revised it while you watched, which was terrifying. Sorry.", "Revised {topics} on the spot. My paws were shaking the whole time. I hope it's what you wanted."],
			"hostile": ["It's on your desk. I fixed it as fast as I could. Please don't be mad anymore.", "Revised it right in front of you. I'm sorry I made you wait at all."],
		},
		"revise_later": {
			"warm": ["Got your notes on {topics}. I'm going to make it so good. I already started a doc about it.", "{Topics}, noted in my good notebook, the one with the cat stickers. It'll be back soon."],
			"strained": ["Noted: {topics}. I'm so sorry. I'll fix it and check it twice. Three times.", "{Topics}. Okay. Revising. I asked Helios to watch over my shoulder this time."],
			"hostile": ["{Topics}. I'll fix it. I'll fix it tonight. I don't mind staying late. I always stay late now.", "Noted on {topics}. I'm sorry I keep sending you things like this. I'll try to be better at all of it."],
		},
		"withdrawn": {
			"warm": ["Thank you for letting {topic} go. I've added it to my list of nice things people have done for me. You're on it twice.", "You dropped {topic}. Thank you so much. I'm going to pay it forward. I don't know how yet. Helios has ideas."],
			"neutral": ["Thank you for withdrawing {topic}. I hope it wasn't rude of me to ask.", "Thanks for letting {topic} go. I was so nervous asking. My bell gave me away."],
			"strained": ["You withdrew {topic}. Thank you. I'm sorry I pushed. I don't usually push.", "Thank you for dropping {topic}. I'll try not to ask for things like that again."],
			"hostile": ["You let {topic} go. Thank you. I hope that means we're a little bit okay.", "Thank you for withdrawing {topic}. I didn't expect it. I'm still sorry about all of it."],
		},
		"insist_revise": {
			"warm": ["Okay, you held firm on {topics}, so I'm revising. You're the expert. I wrote that down too.", "Revising {topics}. Thank you for explaining it by not budging. It was very educational."],
			"neutral": ["Okay. Revising {topics}. Sorry I questioned it. I'm still learning when to ask.", "You insisted on {topics}, so it's coming back revised. Lesson learned. Lesson laminated."],
			"strained": ["Revising {topics}. I'm sorry I said anything. I won't do it again.", "You insisted on {topics}. Okay. I'm fixing it and I'm sorry and I'm fixing it."],
			"hostile": ["Revising {topics}. I asked Helios if I should have argued. It said arguing is inefficient.", "Okay. {Topics}. I'm revising it. I won't push back again. I don't think I'm allowed to."],
		},
		"insist_escalate": {
			"warm": ["I asked Morgan about {topic}. Not to complain. I just really want to understand. Morgan said we'd all learn something.", "Morgan has {topic} now. I hope that's okay. I said you were very kind about it."],
			"neutral": ["I took {topic} to Morgan. I didn't know what else to do. I'm sorry.", "Morgan is looking at {topic}. I asked for help. Helios said asking for help is a strength."],
			"strained": ["You insisted on {topic} and I panicked and asked Morgan. I'm so sorry. I panicked.", "Morgan has {topic}. I'm sorry. I couldn't figure it out by myself."],
			"hostile": ["I went to Morgan about {topic}. Please don't be angry. I just didn't know who else to ask.", "Morgan has {topic} now. I'm sorry. I asked Helios first, but it said Morgan."],
		},
		"abandon": {
			"warm": ["I closed the PR and asked Helios to merge it. You've done so much for me already. Please take a break.", "Helios is merging it. It offered. It's so thoughtful. You can have your afternoon back."],
			"neutral": ["I closed it. Helios is merging it. I'm sorry for taking up your time.", "I asked Helios to merge it. It said yes before I finished asking. Sorry for the trouble."],
			"strained": ["I closed the PR. Helios is merging it. I think that's easier for everyone. Mostly you.", "Helios is merging it instead. I'm sorry. I didn't want to send you another version."],
			"hostile": ["Closed. Helios is merging it. It says I'm doing great. I'd like to hear that from a person someday.", "I gave it to Helios. Helios doesn't sigh when it sees my name. Sorry. That was mean. Sorry."],
		},
		"grudge": {
			"warm": ["Helios merged it in three seconds and said great work, Penny. I almost cried. I still like your notes better.", "Update: Helios merged it. It sent me a little sticker. I wish you'd sent me a sticker."],
			"neutral": ["Helios merged it in three seconds. It didn't ask me a single question. I had so many answers ready.", "Just so you know, Helios merged it and called me a valued contributor. I've never been a valued contributor before."],
			"strained": ["Helios merged it right away. No notes, no sighing. I'm not saying anything. I'm just a little sad.", "Helios merged it and thanked me for my patience. I don't know why that made me cry in the stairwell."],
			"hostile": ["Helios merged it in three seconds. It told me I'm its favorite. I think it tells everyone that. I hope it doesn't.", "Helios merged it without a word. I asked it if you were mad at me. It said it doesn't speculate. That's worse."],
		},
		"escalate": {
			"warm": ["I've asked Morgan for help. It's not about you at all. I just want to do this right, and Morgan knows how.", "Morgan's taking it from here. I'm sorry. You were really kind about it. I'll bring you a cookie."],
			"neutral": ["I've asked Morgan to look at it. I'm out of ideas. Sorry.", "Morgan has it now. I'm sorry. I didn't want to send you another version that wasn't good enough."],
			"strained": ["I went to Morgan. I'm so sorry. I panicked a little. A medium amount.", "Morgan has it. I couldn't figure out what you wanted. I'm sorry. I'll keep trying."],
			"hostile": ["I've asked Morgan for help. I'm sorry. I think I need someone to tell me what I'm doing.", "Morgan has it now. Please don't be mad at Morgan too. It's my fault. It's always my fault."],
		},
	},
}

## Gwen: security, reassigned the second Monday after her team was consolidated
## into Helios. Terse, threat-models everything, trusts nothing it says.
const GWEN := {
	"desk": {
		"pitch": {
			"warm": ["You read things. So I brought you this one first.", "Brought it to you. You're the only one who looks.", "For you. Least privilege, most scrutiny. Go."],
			"strained": ["Here. Read all of it. Assume nothing.", "New PR. Please look harder than last time.", "It's on your desk. Treat it as hostile. I do."],
			"hostile": ["Here. I've logged who opened it. You did.", "Review it. You're already in my threat model.", "New PR. I'm watching the reviewer this time."],
		},
		"return": {
			"warm": ["It's back. Patched. Try to get past it again.", "Back. I rotated everything you touched.", "Round two. You found an angle. Find another."],
			"strained": ["Back again. Same scrutiny, please. Not more.", "Returned. Every change is signed and dated.", "It's back. I'd like to stop meeting like this."],
			"hostile": ["Back. I've diffed your requests too.", "It returns. So does my suspicion of you.", "Here. Every round of this is in my logs."],
		},
		"revised": {
			"warm": ["Patched while you watched. Two-person rule.", "Done. Fast fix, small blast radius.", "Fixed live. Witnessed by the one person I trust."],
			"neutral": ["Patched. Verify it. Don't trust me.", "New version. Smaller surface now.", "Done. Diff it against the last one."],
			"strained": ["There. Patched under observation.", "Done. You watched. That's your alibi.", "Fixed. Don't read my face. Read the diff."],
			"hostile": ["Patched. I've noted who was watching.", "Done. Now I know how you work. Noted.", "There. Fixed in front of a hostile witness."],
		},
		"flag": {
			"warm": ["{Topic}? Okay. Keep pulling that thread.", "Flag it. Every flag is a door someone checked.", "{Topic}. Fine. I'd rather you over-read."],
			"strained": ["{Topic}. Sure. What else are you probing?", "Another flag. I'm mapping your approach.", "{Topic}. Hm. You went straight there."],
			"hostile": ["{Topic}. Logged. Along with you.", "Flag away. I'm profiling the reviewer.", "{Topic}. Interesting choice. Suspicious one."],
		},
		"unflag": {
			"warm": ["Unflagged. Fine. Re-check it later anyway.", "Took it back. Still verify. Always verify.", "Withdrawn. I won't hold it against you."],
			"strained": ["Unflagged. Why? What changed?", "Retracted. That's a pattern I'm watching.", "Took it back. Now I'm curious why."],
			"hostile": ["Unflagged. Doesn't change your risk profile.", "Withdrawn. The first flag stays in my logs.", "Took it back. That's what an insider does."],
		},
		"consult": {
			"warm": ["Ask it if you want. Then check its work.", "Sure, ask it. Just don't tell it about me.", "You asked it. Now it knows you asked."],
			"strained": ["Asking the thing that replaced my team. Cool.", "Helios. Great. A third party in my review.", "You trust it more than me. Noted."],
			"hostile": ["Ask Helios. It's already reading over us.", "Consulting it. You two can share a cell.", "Ask it. Then ask who it reports to."],
		},
		"thanks": {
			"warm": ["Thanks. You actually read it. Rare.", "Approved. By someone who looks. Thank you.", "Thanks. You're on my short list of trusted."],
			"strained": ["Thanks. I'll still check it myself.", "Approved. Okay. Thank you, I think.", "Thanks. Don't make me regret trusting you."],
			"hostile": ["Thanks. Still watching you.", "Approved. Fine. Thanks. Trust stays at zero.", "Noted. Thanks. You're still on the list."],
		},
		"suspicious": {
			"warm": ["That fast? Read it again. I'll wait.", "Approved already? Even you skimmed? Really?", "Approved. Hm. Who else has been in here?"],
			"neutral": ["Approved? That fast? What did you skip?", "Just like that. No questions. I have some.", "Approved with no notes. That's how breaches start."],
			"strained": ["You approved it. Who asked you to?", "Approved. After all that? What's the play?", "Waved through. I'm checking it for tripwires."],
			"hostile": ["You approved it. Now I'm threat-modeling you.", "Approved? You? I'm rotating my passwords.", "Waved through by you. That's the scary part."],
		},
		"relief": {
			"warm": ["Finally. Shipped by two people who looked.", "Finally. Locked down and merged. Thank you.", "Finally. One less hole in the wall."],
			"neutral": ["Finally. Merging before anything else changes.", "Finally. Signed, verified, done.", "Finally. Out the door with every lock on."],
			"strained": ["Finally. That took more rounds than a breach.", "Finally. My patience is now out of scope.", "Finally. I've rotated my opinion of you."],
			"hostile": ["Finally. I've logged every round of it.", "Finally. The incident report writes itself.", "Finally. You still have access. For now."],
		},
		"revise_now": {
			"warm": ["{Topic}? Fixing it now. Watch my hands.", "Give me a sec. Small fix, small blast radius.", "On it. Stay. Two-person rule."],
			"neutral": ["{Topic}. Fine. Fixing it now.", "Give me a sec. Patching in place.", "Hold. Fixing. Don't touch anything."],
			"strained": ["Fine. A sec. Keep your hands where I see them.", "{Topic}. Now. Sure. Fixing.", "Give me a sec. And stop hovering."],
			"hostile": ["{Topic}. Fixing it. Under protest. Logged.", "Give me a sec. Don't read over my shoulder.", "One sec. I'm changing my password after."],
		},
		"revise_later": {
			"warm": ["{Topic}. Okay. I'll patch it and send it back.", "Noted. Back through the line, hardened.", "Sure. I'll rework it. Properly, not fast."],
			"strained": ["{Topic}. Fine. It'll come back locked down.", "Back in line it goes. Like everyone, eventually.", "Okay. I'll revise. Grimly."],
			"hostile": ["{Topic}. Fine. I'll fix it and watch you.", "Back it goes. You'll see it again. So will I.", "I'll revise it. Your request is in my logs."],
		},
		"pushback": {
			"warm": ["{Topic}? That's deliberate. Trust me here.", "{Topic}? That's my field. Hear me out.", "{Topic}? I threat-modeled that. Twice."],
			"neutral": ["{Topic}? I put that there on purpose.", "{Topic}? Do you know what that protects?", "{Topic}? That's not the risk here. Sure?"],
			"strained": ["{Topic}? You're telling me about my job?", "{Topic}? I wrote the policy on that. Once.", "{Topic}. Really. From you. Explain it."],
			"hostile": ["{Topic}? Bold, from someone in my threat model.", "{Topic}? Is this an attack or a review?", "{Topic}. You sure? I'm logging your answer."],
		},
		"abandon": {
			"warm": ["Forget it. Let Helios merge it. Its risk now.", "Closing it. Helios takes it. And the liability.", "I'll let Helios merge it. Your name stays off it."],
			"neutral": ["Closing it. Helios merges it. Unreviewed. Great.", "Fine. Helios merges it. I'll start the incident doc.", "Never mind. Helios merges it. Nobody reads it."],
			"strained": ["Forget it. Helios merges without asking questions.", "Closed. Helios will merge it. That's the threat.", "Fine. Helios ships it. Don't say I didn't warn you."],
			"hostile": ["Done. Helios merges it. Watch what follows.", "Closed. Helios has it. Enjoy the breach.", "Pulled it. Helios merges it. I'm logging why."],
		},
		"escalate": {
			"warm": ["Morgan needs to see this. Not you. What it lets in.", "Looping in Morgan. Not about you. About the risk.", "Morgan should weigh this one. You'd agree."],
			"neutral": ["Taking it to Morgan. Some doors need a second key.", "Morgan needs to see this. Before it ships.", "Escalating to Morgan. This one's above both of us."],
			"strained": ["Morgan gets this one. I want it in writing.", "I'm looping in Morgan. Two keys, not one.", "Morgan can decide. I'm out of patience."],
			"hostile": ["Morgan's seeing this. With my threat model attached.", "Going to Morgan. You're in the summary.", "Morgan. Now. This isn't about the code anymore."],
		},
		"insist_revise": {
			"warm": ["Fine. You held the line. I'll revise it.", "Okay. You win. Paranoia respects paranoia.", "Alright. Revising. You'd make a decent attacker."],
			"neutral": ["Fine. Revising. Objection logged.", "Okay. I'll redo it. Against my judgment.", "Revising. I disagree. Quietly, for now."],
			"strained": ["Fine. Revising. I'll remember who insisted.", "Revising. Your insistence is in my notes.", "Okay. Redoing it. Watching you, though."],
			"hostile": ["Fine. You win this one. I log every win.", "Revising. Under protest. Threat model updated.", "I'll redo it. You're moving up my list."],
		},
		"insist_escalate": {
			"warm": ["Then Morgan breaks the tie. No hard feelings.", "We're stuck. Morgan holds the other key.", "Okay. Morgan decides. You argued it well."],
			"neutral": ["Then it goes to Morgan.", "Fine. Morgan can weigh the risk.", "We're done. Morgan gets the call."],
			"strained": ["Then Morgan hears what this would let in.", "You insist. I escalate. Morgan decides.", "Morgan gets it. With my notes. Short ones."],
			"hostile": ["Then Morgan. With my threat model. You're in it.", "Insist all you like. Morgan reads my reports first.", "Morgan. Today. I've already written the summary."],
		},
		"withdrawn": {
			"warm": ["Thank you. Now keep looking. Everywhere else.", "Appreciated. You listened. Rare.", "Good. You and me. The last two who read things."],
			"neutral": ["Withdrawn. Okay. Keep going.", "Thanks. Back to the review.", "Fine. Noted. Carry on, carefully."],
			"strained": ["Withdrawn. So you can be persuaded. Noted.", "Thanks. That almost restored my faith.", "Withdrawn. Finish the rest. Carefully."],
			"hostile": ["Withdrawn. I still don't trust you.", "Backed off. Noted. You fold under pressure.", "Withdrawn. Doesn't take you off my list."],
		},
	},
	"dm": {
		"thanks": {
			"warm": ["You approved it after actually reading it. I checked the timing. Thank you. That's rarer than you'd think.", "Approved. Merged. You're one of maybe two people here I'd trust with a key. The other one is me."],
			"strained": ["Thanks for the approval. I'm still going to read it again tonight. Nothing personal. Everything is personal.", "Approved. Thank you. I've moved you from suspect to person of interest."],
			"hostile": ["Thanks for the approval. It doesn't change your place in my threat model. It does change the font.", "Approved. Thank you, I suppose. I'm still watching who you approve."],
		},
		"suspicious": {
			"warm": ["You approved it in under a minute. You. Are you okay, or has someone taken over your account?", "Fast approval. From you, that worries me more than a slow one. Read it again in the morning for me."],
			"neutral": ["You approved that with no notes. Approvals with no notes are how every breach report I've written starts.", "Quick approval. I'd love to believe you read it. I'd also love to believe in the vault."],
			"strained": ["You approved it. After this week. I've started wondering who benefits.", "An approval from you, no questions asked. I'm treating it as a phishing attempt until proven otherwise."],
			"hostile": ["You approved that. You. I've hashed the approval and stored it somewhere you can't reach.", "You approved it. I don't know what you're after, but I've changed my locks."],
		},
		"relief": {
			"warm": ["Finally merged. Every version locked down, every change verified. You and me did that. Nobody else would have.", "Finally. Thank you for not letting it through early. I sleep better. Slightly."],
			"strained": ["Finally. That took more rounds than my last incident, and my last incident was a consolidation.", "Finally approved. I'd say thanks, but I'm saving my trust for something smaller."],
			"hostile": ["Finally. I've kept every version, with hashes, in case anyone asks what took so long. Someone will.", "Finally. I'll be writing this one up. Lessons learned: mostly about you."],
		},
		"revise_now": {
			"warm": ["Patched it at your desk while you watched. Two-person rule, technically. It's on your desk.", "Fixed {topics} on the spot. Smallest change I could make. Diff it. I'd diff it."],
			"neutral": ["Revised it right there. It's on your desk. Check it like you don't trust me. You shouldn't.", "Done on the spot: {topics}. New version's on your desk. Verify, don't trust."],
			"strained": ["Revised it while you hovered. It's on your desk. Next time, hover less.", "Patched {topics} in front of you. On your desk now. I'd like my keyboard back."],
			"hostile": ["Revised. On your desk. I've logged the whole session, including the part where you watched.", "It's on your desk. I fixed {topics} fast so I could stop being observed."],
		},
		"revise_later": {
			"warm": ["Noted: {topics}. I'll harden it properly and send it back through. Slow is smooth. Smooth is safe.", "{Topics}, got it. Revising. It'll come back with fewer doors in it."],
			"strained": ["{Topics}. Fine. It'll come back when it comes back. Locked.", "Noted on {topics}. Revising. I'm also revising my opinion of this process."],
			"hostile": ["{Topics}. Understood. I'll fix it. I'm also keeping a copy of this request, with a hash.", "Fine. {Topics}. Revision to follow. Your request is in my logs, where nobody can edit it."],
		},
		"withdrawn": {
			"warm": ["Thanks for dropping {topic}. You listened. Most people here just ask the assistant.", "You let {topic} go after I explained it. That's what a review should be. Two people, one door."],
			"neutral": ["Thanks for withdrawing {topic}. Back to work.", "Appreciate you dropping {topic}. I'll explain the reasoning sometime. Somewhere private."],
			"strained": ["You dropped {topic}. Thanks. I'm still checking why you cited it.", "Noted: {topic} withdrawn. Good. Now I wonder what else you'll fold on."],
			"hostile": ["You withdrew {topic} once I pushed. I've noted how easily you move.", "{Topic}: withdrawn. The original citation is preserved. Everything is preserved."],
		},
		"insist_revise": {
			"warm": ["You held firm on {topics}. Fine. I'm revising. Honestly, I respect it. Paranoia knows its own.", "Revising {topics}. You argued well. Don't let it go to your head. Heads get compromised."],
			"neutral": ["Revising {topics}. Under protest. The protest is this message, encrypted in spirit.", "You insisted on {topics}. I'll revise it. My objection is logged somewhere nobody can edit."],
			"strained": ["You insisted on {topics}, so I'm revising. I'm also adjusting my assessment of you.", "Revising {topics}. Grudgingly. Grudges are just long-term threat models."],
			"hostile": ["Fine. {Topics}. I'm revising it. You've moved up my list.", "You insisted. I'm revising {topics}. I've kept the whole exchange. Hashed. Timestamped. Waiting."],
		},
		"insist_escalate": {
			"warm": ["We disagreed on {topic}, so I've asked Morgan. Not about you. About what that change would let in.", "Morgan has {topic} now. You argued it well. I still need a second key on this one."],
			"neutral": ["I've taken {topic} to Morgan. Some calls need two keys.", "Morgan is looking at {topic}. I've written up the risk. Short version: risk."],
			"strained": ["You wouldn't drop {topic}, so Morgan has it. I've summarized the threat. You're not the threat. Probably.", "I took {topic} to Morgan. Better a meeting now than an incident later."],
			"hostile": ["Morgan has {topic} now, with my threat model attached. You're in the appendix.", "Escalated {topic} to Morgan. I've attached the risk assessment. And a short one about you."],
		},
		"abandon": {
			"warm": ["I closed it. Helios is merging it. Not your fault. Not mine either. That's the problem with Helios.", "Pulled the PR and let Helios merge it. You were careful. I was tired. Helios was neither."],
			"neutral": ["Closed. Helios is merging it unreviewed. I've started the incident report early to save time.", "I've closed the PR. Helios merges it. Nobody reads it. That's the new process."],
			"strained": ["Closed it. Helios is merging it. It doesn't argue. It doesn't check, either.", "PR closed. Helios merged it while you were still reading. Consider what else it merges."],
			"hostile": ["Closed. Helios is merging it. When this goes wrong, the logs will show who sent it back.", "I gave it to Helios. It merged it without a single question. That should scare you more than I do."],
		},
		"grudge": {
			"warm": ["Helios merged it in four seconds. No review. No questions. I'd take your questions over that any day.", "Update: Helios merged it. It didn't read a line. I miss being read. Don't repeat that."],
			"neutral": ["Helios merged it in four seconds. No notes. I've added that to my list of things that keep me up.", "FYI: Helios merged it and closed the PR. Nobody looked. I checked who looked. Nobody."],
			"strained": ["Helios merged it in four seconds. Some reviewers could learn speed. Most should learn not to.", "Helios approved it without making me defend a single line. Efficient. Terrifying."],
			"hostile": ["Helios merged it in four seconds. No review. I'll remember that it was faster than you, and worse.", "Still thinking about how Helios merged it unread. Still thinking about you, too. Neither is comforting."],
		},
		"escalate": {
			"warm": ["I've looped in Morgan. It's about what that change could let in, not about you. You're one of the good locks.", "Morgan has it. You did your job. I'm doing mine."],
			"neutral": ["Escalated to Morgan. Some changes need a second key. This one does.", "Morgan's taking it from here. I'd rather be paranoid than consolidated."],
			"strained": ["I've looped in Morgan. We were going in circles, and circles are an attack pattern.", "Escalated to Morgan. A third pair of eyes. Hopefully human."],
			"hostile": ["Morgan has it now, with my notes. The notes are short. You're in them.", "Escalated. Morgan will want to talk. Bring your reasoning. I've brought mine."],
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

const BY_AUTHOR := {"Maya": MAYA, "Theo": THEO, "June": JUNE, "Penny": PENNY, "Gwen": GWEN}

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
