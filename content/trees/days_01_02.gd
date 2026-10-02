extends RefCounted
## Per-PR dialogue trees for days 1-2. See content/trees.gd for the format.

static func trees() -> Dictionary:
	return {
		"Rename fire_employee() to release_to_opportunity()": {
			"author": "Maya",
			"lean": {"revise_now": 10, "abandon": -10},
			"desk": {
				"pitch": {
					"warm": "Legal renamed firing. I just typed it. You'll be gentle, right?",
					"neutral": "Quick eyes on the offboarding rename? It's mostly euphemism.",
					"strained": "The rename. Please read it like it's not about you.",
					"hostile": "Offboarding rename. Ironic, given how this is going.",
				},
				"return": {"friendly": "Back. Fewer euphemisms, same unemployment.", "cold": "The rename's back. Like the people it releases, sometimes."},
				"revised": {"friendly": "Done. Released it into the wild, like the docstring says.", "cold": "Pushed. Typed it like someone was watching. You were."},
				"flag": {"friendly": "{Topic}? Fair. Legal wrote half of it, though.", "cold": "{Topic}. Sure. Release that too."},
				"thanks": {"friendly": "Thanks. Somewhere a manager can now say 'opportunity'.", "cold": "Approved. Huh. Thanks, I guess."},
				"suspicious": {"friendly": "That was fast. Did you read the part about the badge?", "cold": "You approved it? Are you being released next?"},
				"relief": {"friendly": "Finally. The euphemism ships.", "cold": "Approved. The opportunity is officially released."},
				"revise_now": {"friendly": "Give me a sec. Renaming firing is quick work.", "cold": "Fine. Fixing it now, at your desk, in front of you."},
				"revise_later": {"friendly": "I'll fix it after lunch. If lunch is still offered.", "cold": "I'll fix it. Add it to my exit interview."},
				"pushback": {"friendly": "{Topic}? Legal picked this wording. I'm only the typist.", "cold": "You're blocking a rename of firing over {topic}. Think about that."},
				"insist_revise": {"friendly": "Okay, okay. I'll make it even gentler.", "cold": "Fine. Revising. Legal will be thrilled."},
				"insist_escalate": {"friendly": "Let's let Morgan pick the euphemism.", "cold": "Morgan can decide what firing is called."},
				"withdrawn": {"friendly": "Thank you. The opportunity lives.", "cold": "Good. One less thing to release."},
				"abandon": {"friendly": "Never mind. Helios can release it for me.", "cold": "Forget it. Helios will merge it. It doesn't have feelings."},
				"escalate": {"friendly": "I'm asking Morgan. This is above my pay grade.", "cold": "That's three rounds. Morgan can have it."},
			},
			"dm": {
				"thanks": {"friendly": "Rename shipped. HR sent a thumbs-up. Unsettling.", "cold": "It merged. HR is pleased. I'm not."},
				"suspicious": {"friendly": "You approved the rename fast. Was it the docstring?", "cold": "Quick approval on the rename. Noted, somewhere."},
				"revise_later": {"friendly": "Fixing {topics} on the rename. Choosing a softer verb.", "cold": "Rename's back over {topics}. Like a severance letter."},
				"abandon": {"friendly": "Helios merged the rename. It didn't blink.", "cold": "Helios took the rename. It said 'aligned' twice."},
				"escalate": {"friendly": "Morgan has the rename now. Out of my hands.", "cold": "Morgan's deciding the rename. Hope you're happy."},
				"grudge": {"friendly": "Helios released the rename. It released me from caring.", "cold": "The rename shipped without you. So might the rest of us."},
			},
		},
	}
