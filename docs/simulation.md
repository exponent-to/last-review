# PRs please simulation

`native/simulation.gd` implements deterministic review rules with a one-PR desk and a continuous workday. Simulation state is independent of scenes, timers, and disk storage. Public transitions deeply copy their input; the application replaces its current state with the returned value.

## Clock and arrivals

A shift lasts `SHIFT_SECONDS = 180` real seconds and maps to `START_MINUTE = 540` through `END_MINUTE = 1080` (09:00–18:00). `advance(state, seconds = 1)` accepts elapsed whole seconds during the review phase. Zero or negative deltas do nothing; a large delta stops at the current shift's deadline. It never advances across evenings. `clock_minutes(state)` returns the current displayed minute.

The application owns real-time accumulation and pause controls. While paused, it must not call `advance`; time spent paused is not caught up afterward. Fractional-second accumulation and pause UI are intentionally outside saved simulation state.

`Catalog.shift_seconds()` always returns 180.

## The desk and the line

The desk holds exactly one PR, like the booth in Papers, Please. Each morning the day's line is its fifteen authored packets in order (`state.desk_line`), and the first is put on the desk at 0 seconds (`active_request_id`); nobody picks it. When the player stamps a verdict, the desk empties and the next PR in line lands `DESK_BEAT = 3` game seconds later (`state.desk_at`), becoming active by itself. `advance` delivers it at its scheduled second, so batched and single-second clocks agree. A PR due at or after the bell never lands. Every landing is recorded in `state.arrivals` as `{pr_id, day, shift_seconds}`; the archived chat content (`content/chat.gd`) uses that log to date each PR's message. The line length is internal scheduling data and must never be shown.

`active_request(state)` returns the PR on the desk, or an empty dictionary between PRs and after closing. `available_requests(state)` returns that PR in a list of at most one. Neither includes hidden audit violations, findings, explanations, or the generation recipe; AI verdict/note fields appear only after that PR has been consulted. There is no `select-request` command: the player cannot choose among PRs.

## Revisions

Requesting changes sends the PR back to its author, who returns a revision: `PR-2004` → `PR-2004-v2`, then `PR-2004-v3` (shown as "PR-2004 · v2"). `state.revisions` records `{id, parent_id, origin_id, version, day, cited, fixed, regression}` and the revision joins the line at index `REVISION_GAP = 2`, behind the next two PRs, or sooner if fewer remain.

- **Fixed:** only rules the player cited that really were violated in the parent (anywhere in its findings). Uncited real violations stay. Citations of rules that weren't violated fix nothing.
- **Regression:** with no RNG, about one revision in five that fixes something also breaks one new standard: one active that day, not already broken, not cited, and never P02 (which would rewrite a whole file). `Policy.roll(id + "|regression")` decides, from the revision ID alone.
- **Note:** every revision carries a harmless author comment acknowledging the review (none contain `!` or a long line, and placement is verified), so a note never hints whether a citation was real.
- **Cap:** a change request on v3 escalates. No v4 is made; Helios takes the PR (automation reliance +1) and Morgan notes it on that evening's panel.

Whether a change request produces a revision at all, and where it goes, is the author's encounter branch (below): revise later (the gap above), revise now (the revision goes to the front of the line and lands `Encounters.REVISE_NOW_SECONDS = 6` seconds later), push back, abandon, or escalate.

`policy_campaign.gd` gives every packet a private `recipe` (bank entry, companion files, each fault with its file and wording, notes, permits). `Policy.revision(parent, version, fixed, regression, cited)` regenerates the files from the parent's recipe minus the fixed faults, plus any regression and the note, and returns a packet with the same shape as an original (`id, title, author, day, file, files, diff, message, description, violations, findings, explanation, ai_verdict, ai_note`, plus `revision`, `parent_id`, `origin_id`). Originals have `revision` 1 and an empty `parent_id`. `Catalog.packet(state, id)` finds originals and revisions alike, and grading, chat, debrief, and the interface all go through it. A revision's `message` and `description` are phrased from what the player cited, in plain words without rule IDs, and are identical whether or not anything was actually fixed or broken.

## Encounters

`content/encounters.gd` is a data-driven flow chart of how a PR's author responds: `NODES`, `EDGES`, and per-author, per-mood branch weights in `PICKS`. `content/encounter_lines.gd` holds the words (desk bubble and DM, per author, node, and mood) and Morgan's notes. The DM lines are kept for a future chat app; Morgan's notes reach her end-of-day panel. `sh scripts/run.sh --headless --script res://tools/encounter_flowchart.gd -- <out.html>` exports the charts, every line, and a sample day to one self-contained HTML page.

- **Mood** is `warm`, `neutral`, `strained`, or `hostile`, from the coworker relationship score plus the tone of the author's last three beats (`TONE`: approvals and withdrawn citations warm; change requests, abandons, escalations, and insisting cool). Bands: warm 62+, neutral 42–61, strained 30–41, hostile below 30.
- **Branches** are rolled with `Policy.roll` keyed on the PR, verdict, mood, and cited rules, so the journal replays them. Weights lean by the categories of what was cited, and citing three or more standards at once makes abandoning likelier. Nothing in the encounter reads audit data: a right and a wrong citation take the same branch and get the same words.
- **Approve:** thanks or a suspicious "wait, you approved that?" by mood (v1), or relief (v2/v3).
- **Request changes:** revise now, revise later, push back (at most once per desk visit), abandon, or escalate. The career's first PR always revises later, so orientation stays scripted; v3 always escalates.
- **Push back:** the PR stays on the desk unsigned and its citations freeze. The `pushback` command answers: `insist` signs the change request as cited and the author revises grudgingly (back in line) or escalates; `withdraw` retracts the disputed citation and the review reopens. Stamping CHANGES REQUESTED again counts as insisting. At the bell a disputed PR is handed off unsigned.
- **Abandon** counts as reviewed and makes no revision; Helios merges it. **Escalate** makes no revision either; Morgan hands the PR to Helios. Only the third-round escalation raises automation reliance (+1), as before, so careful reviewing still shapes the ending.
- **Relationship** changes on top of the review's own: abandon −3, insist −2, withdraw +2.

`state.encounters` records one beat per moment, `{pr_id, author, day, version, mood, node, cited, shift_seconds, seq}`, plus `disputed` (pushback, insist, withdrawn) and `revision_id` (revisions). The mood on a beat is taken before that stamp's own relationship change, and a revision's opening line keeps the mood of the beat that made it, so nothing the author says about a verdict can reflect whether it was right. The archived chat thread's standing warm/distant line for an author follows the mood of their latest beat for the same reason. `Encounters.pending(state)` is the pushback waiting on the desk; `Encounters.typing(state)` is an author revising at the desk.

PR bank entries carry per-PR `pitch`, `pushback`, `relief`, and `grudge` lines; a neutral author speaks them (relief on any approval, grudge after an abandon or escalation), while other moods use the templates so a change of mood is always audible.

## Records: Jiro tickets and Pipeline builds

From `Policy.JIRO_DAY` (3) every packet carries `ticket_ref` (the "Closes PAPER-412" on its slip, possibly empty or a ticket Jiro doesn't have) and `tickets` (the tickets it puts in Jiro); from `Policy.PIPELINE_DAY` (5) it also carries `build` (its latest pipeline run). These are visible data, like `files`: `active_request` keeps them, and only `violations`, `findings`, `explanation`, and `recipe` are hidden. `content/records.gd` renders them from the recipe (slot, version, author, primary file, and a list of fault and decoy effects) with authored ticket copy, a backlog, test names, and failure logs; it never decides whether a record breaks a standard. `Policy._records(recipe)` builds `{author, ticket_ref, tickets, build}`, and `Policy.findings(files, day, records)` audits code and records together. Record findings carry `record` ("ticket" or "build") and `id` (the PR's link, or its build) instead of a path and line.

- **P16** the PR links a ticket that exists (its own or the backlog's) with status Open or In Progress. Faults: no link, a link to a ticket Jiro doesn't have (`PAPER-5764`, `PAPR-576`), or a Won't Fix, Closed, or Duplicate ticket.
- **P17** (days 3-6) the linked ticket's assignee is the PR's author, exactly. Faults: a coworker, Helios, or someone who left.
- **P18** every changed file outside `tests/` sits in the ticket's component folder: directly until `SUBFOLDER_DAY` (9), in it or below from then on. Faults: another component, a subfolder component, or (before day 9) a shim in a `legacy/` subfolder.
- **P19** the build is not FAILED; FLAKY passes. From `OVERRIDE_DAY` (7) Helios overrides appear (`PASSED (OVERRIDDEN BY HELIOS)`) and count as passing; from `OVERRIDE_BANNED_DAY` (9) they count as failed.
- **P20** (days 5-6) at most `RERUN_LIMIT` (3) reruns, whatever the final status.
- **P21** (from day 7) coverage falls by at most `COVERAGE_DROP` (2.0 points, stored in tenths).

Without a ticket Jiro can find, P17 and P18 have nothing to check, so P16 alone is cited; generation keeps a missing or broken link away from other ticket faults (and from day-9 permits, which name the PR's ticket) so that every fault comes apart independently. Clean PRs get clean records, often odd but valid ones (an ancient In Progress ticket, Helios watching, a flaky test, exactly three reruns, exactly two points of coverage lost), and once a standard is retired its old faults turn up on clean PRs. A revision is a new push: it gets a new build, and the ticket keeps every uncited fault. Fixed ticket faults leave a line in the ticket's history ("Reopened by Maya after review.").

`Catalog.tickets(state)` is what Jiro shows: the backlog plus the tickets of every PR that has reached the desk (a later version replaces an earlier copy), each with the PRs that link it. `Catalog.builds(state)` is what Pipeline shows: one build per PR version that has reached the desk. Neither ever includes a PR still in line.

## Commands

| `type` | Additional fields | Valid phase |
| --- | --- | --- |
| `toggle-rule` | `rule_id`: active rule, plus `path`/`line` evidence, or `record`/`id` evidence (`ticket` or `build`), when citing | review, PR on the desk |
| `consult-ai` | Once per PR (each revision is its own PR) | review, PR on the desk; day 3 onward |
| `review` | `verdict`: `approve` or `request_changes` | review, PR on the desk |
| `pushback` | `choice`: `insist` or `withdraw` | review, while the desk PR's author is pushing back |
| `chat-reply` | `contact`, `pr_id`, `reply_id` from `Chat.reply_options` | review |
| `next-day` | `choice`: `rest`, `socialize`, or `study` | debrief |

Approval requires zero citations; rejection requires at least one. A rejection passes the audit only when its citation set exactly matches the actual violations and each citation's evidence is accepted (`Policy.evidence_matches`). A record citation may point at the PR's own link (even an empty or broken one) or at any ticket or build Jiro or Pipeline shows; only the PR's own record, under the record standard it was found for, is accepted. WHOLE FILE and code lines never count for a record standard, and a record never counts for a code standard. Revisions are graded exactly like originals. Invalid commands have no effects. After submission, the desk clears, the next PR is scheduled, and `last_feedback` records the actual decision. `request_index` is a compatibility pointer to the earliest pending catalog entry, not a submitted-review counter or editor selection.

## Consequences and closing bell

Starting resources remain 120 credits, 70 trust, 20 stress, 10 automation reliance, and neutral coworker relationships. Correct approval changes author relationship/trust/stress by +4/+3/+3; incorrect approval by +6/-12/+11; correct rejection by -2/+5/+3; incorrect rejection by -7/-7/+9. Consultation removes two stress and adds four automation reliance once per request, even after switching away and returning.

Clearing the line does not end the shift. At 18:00, actual signed reviews (originals and revisions) are audited, and whatever is on the desk or still in line, including pending revisions, transfers to Helios. No player decisions are fabricated for skipped work, so chat never claims the player approved or rejected it. The current request is cleared and the pending pointer advances to the next shift.

Pay is the existing base of 80 plus ten for each correct, actually submitted review, revisions included; living expenses are 90. Unsigned work earns no bonus. Automation reliance increases by four for the shift plus one for each handed-off request, clamped to its allowed range. A shift with zero reviews is valid and still reaches debrief.

`last_debrief` retains day, reviewed, correct, pay, expenses, balance, and message; it adds `timed_out` (true when unsigned work was handed off), `handed_off`, and `shift_seconds`. The message describes the result qualitatively. Pay and handoff effects apply only once. The evening choice is recorded in `shift_history`, so evenings work even when the player submitted nothing. Rest, socialize, and study retain their previous effects. A new day resets the clock to morning; the final evening completes the career.

## Saved state and replay

Current state (version 14) contains `shift_seconds`, `active_request_id` (the desk), `desk_line`, `desk_at`, `arrivals`, `revisions`, `encounters`, `consulted_requests`, `actions`, `shift_history`, and `chat_replies`, plus the story fields `firings`, `strikes`, `payloads`, and `ending`. Each actual decision also records `shift_seconds`. A chat reply records `{day, shift_seconds, pr_id, contact, reply_id}`; authored text remains in the chat catalog, and replies do not secretly alter relationship scores. The story fields are all rebuilt by replaying the journal, so they are not trusted from the saved file.

## Staffing, payloads, and endings

Each authored PR belongs to a SEAT, named for its author (`content/staff.gd`). At closing, a coworker takes at most one strike — a defect of theirs you approved shipped, or two or more wrong rejections of their work in a day — and three strikes ends them (`firings`). Nobody replaces a fired coworker: from the next morning Helios holds their seat, `_open_desk` drops that seat's PRs (they never reach your desk), and Morgan's panel says so. The run ends early if Morgan's trust falls below `FIRE_TRUST`, stress maxes, or every original seat is gone; otherwise day 10 resolves the matrix ending (payloads blocked vs let through, crossed with whether the surviving team's average relationship is on your side). `content/endings.gd` holds each ending's title, Morgan's closing words, and cinematic beats.

From day 3, `Catalog.requests_for_day` places a Helios payload (`content/policy_campaign.gd` `PAYLOAD_SPECS`, pleading in `content/payloads.gd`) at the front of the line. A payload breaks only P15; you either let it through (approve, an audit failure that warms the author and dents trust) or block it (request changes — with P15 cited or with no citation at all), and `payloads` records the outcome. A reason-free CHANGES REQUESTED on a normal PR is the `unexplained` branch: Helios merges it, it is graded incorrect, and Morgan notices.

The semantic action journal records consultations, reviews with their citations (each rule's evidence is `{path, line}` or `{record, id}`), pushback answers, accepted replies, deadline closure, and evening choices. Each event records its day and shift time. Clock ticks, temporary selection, and citation toggles are not individually persisted. This keeps the journal naturally bounded by available work and reply options rather than time spent reading.

`validate_save(value)` returns `{ok, state, error}`. It replays the journal against the desk, content, and available reply options, so the line, every landing time, and every revision's fixes and regression are rebuilt, then reconstructs the current citations, record citations included (a journal citing a ticket or build Jiro and Pipeline never showed is rejected). A review or consultation must target the PR that was on the desk at that moment. It rejects premature actions, backward timestamps, duplicate consultations or replies, repeated pay, altered audit results, fabricated decisions, and inconsistent resources or phases. JSON integral floats are accepted and normalized; unknown or changed canonical fields are rejected. `serialize_save(state)` returns validated JSON or an empty string.

Validation only accepts the current format and always uses the same catalog. Unsupported formats are rejected; there are no migrations or campaign variants.

`native/save_store.gd` writes each of three slots through a flushed temporary file and retained backup. Slot filenames are stable, so current saves remain at their existing location. Recovery can use a valid current-format backup; no alternative content is loaded to accommodate incompatible files.

## Team chat and tests

`content/chat.gd` derives conversation messages and authored reply options from `state.arrivals`, actual decisions (verdict and cited rules only), and accepted replies; revision packets come from `Catalog.packet`. Dialogue lives in `content/policy_chat.gd`. It must not import Simulation, avoiding a circular dependency. `evening(state)` reports the closed shift for Morgan's end-of-day panel: the day's notes and her closing words (plus the ending after the last day). The Slouch chat app is off the desktop for now; these conversations stay authored and tested for a future chat app.

Run `godot --headless --path . --script res://tests/test_simulation.gd` for rule, economy, catalog, and campaign checks. Run `res://tests/test_shift_clock.gd` the same way for clock mapping, desk landings, all-missed shifts, partial handoffs, consultation persistence, chat replies, mixed action histories, and corrupted timed saves. `res://tests/test_desk.gd` covers the one-PR desk, revision timing, exact fixes, deterministic regressions, the v3 escalation cap, save replay with revisions, and audit-free revision dialogue. `res://tests/test_encounters.gd` covers the encounter graph (every node reachable, in the chart and in play), lines for every author, node, and mood, mood evolving across a day, determinism and save replay, counterfactual no-hint checks (the same mood and action in two audit worlds give the same branch and words), INSIST/WITHDRAW, revise-now and abandon effects on the desk, and the pushback buttons' placement. All scripts exit nonzero on failed checks and require no testing plugin.
