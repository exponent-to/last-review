# PRs please simulation

`native/simulation.gd` implements deterministic review rules with a one-PR desk and a continuous workday. Simulation state is independent of scenes, timers, and disk storage. Public transitions deeply copy their input; the application replaces its current state with the returned value.

## Clock and arrivals

A shift lasts `SHIFT_SECONDS = 180` real seconds and maps to `START_MINUTE = 540` through `END_MINUTE = 1080` (09:00–18:00). `advance(state, seconds = 1)` accepts elapsed whole seconds during the review phase. Zero or negative deltas do nothing; a large delta stops at the current shift's deadline. It never advances across evenings. `clock_minutes(state)` returns the current displayed minute.

The application owns real-time accumulation and pause controls. While paused, it must not call `advance`; time spent paused is not caught up afterward. Fractional-second accumulation and pause UI are intentionally outside saved simulation state.

`Catalog.shift_seconds()` always returns 180.

## The desk and the line

The desk holds exactly one PR, like the booth in Papers, Please, and the rest of the day queues outside it. Each morning the day's packets (payloads first, then the fifteen originals in order) are scheduled to join the waiting line on the shift clock, whether or not the player keeps up. `arrival_schedule(count, day)` gives each one's second: the day's payloads plus `OPENING_LINE = 2` are already waiting at 0 seconds, and the rest arrive ever closer together (`t = last · u · (4 − u) / 3` for the u-th fraction of the rest, so the last gap is half the first), the last at `LAST_ARRIVAL = 176` seconds on day 1 and `LAST_ARRIVAL_STEP = 5` seconds sooner each later day (131 on day 10). Integer arithmetic only, so every platform and replay agree.

Not-yet-arrived PRs sit in `state.incoming` (`{pr_id, at}`, in order); the waiting line is `state.desk_line` (front first) with `state.queued_at` giving the second each joined. The front of the line is put on the desk (`active_request_id`); nobody picks it, and there is no command to call a PR up out of turn. When the player stamps a verdict, the desk empties and frees up `DESK_BEAT = 3` game seconds later (`state.desk_at`); the front of the line lands then, or, if nobody is waiting, the next arrival lands the second it joins. `advance` plays joins and landings at their own seconds, so batched and single-second clocks agree. Nothing joins or lands at or after the bell. `next_landing(state)` is the second the next PR will land if nobody stamps first (or −1). Every landing is recorded in `state.arrivals` as `{pr_id, day, shift_seconds}`; the archived chat content (`content/chat.gd`) uses that log to date each PR's message.

`waiting(state)` is what REVIEW shows of the line: `{id, author, revision, since, age}` per waiting PR, front first (an author revising at the desk is sitting, not waiting). It carries who and how long, never anything about a PR's contents. At a careful reviewer's pace (one signature every 25 seconds, six or seven a day) the line is about 6–8 deep at 15:00 in week one and 8–11 in week two, counting revisions that rejoin it (`tests/test_queue.gd` prints the run).

## Orientation's practice desk

Orientation's practice PR (PR-1042, Maya's offboarding rename with a literal lowercase load-bearing comment) is not one of the campaign's 150 originals: `Policy.practice()` builds it like day 1's first slot from its own bank entry (`Bank.practice()`, recipe `entry` = `Policy.PRACTICE_ENTRY`), and `Catalog.packet` finds it by ID. `initial_state(true)` puts it on the desk ahead of Monday's line; `initial_state()` (a real career) never has it, so Monday opens with PR-2001 from Maya. A save's `practice` flag replays from the matching initial state; `SaveStore` only accepts a practice state inside an orientation session, and `Tutorial.validate` only accepts orientation on a practice state.

## Authors and the team

Five coworkers write PRs (`Policy.AUTHORS`). Maya, Theo, and June are there from day 1. Penny, the eager new junior, joins on day 3; Gwen, reassigned from Security after it was consolidated into Helios, joins on day 6 (`Policy.ROSTER`: first morning and starting relationship, Penny 56 and Gwen 48). Nobody is in `state.coworkers` before their first morning: `_staff` adds each newcomer when her day begins, before the line opens, so an earlier dinner with the team doesn't count for her, and a save that lists her early is rejected by replay.

Who wrote each slot is the explicit per-day table `Policy.LINEUP`, one initial per slot (M, T, J, P, G):

| Day | Lineup | Penny | Gwen |
| --- | --- | --- | --- |
| 1 | `MTJMTJMTJMTJMTJ` | | |
| 2 | `TJMTJMTJMTJMTJM` | | |
| 3 | `JPTJMPJMTPMTJPT` | 2, 6, 10, 14 | |
| 4 | `MTPMPJMTJPTJMPJ` | 3, 5, 10, 14 | |
| 5 | `PJMPJMTJPTPMTJM` | 1, 4, 9, 11 | |
| 6 | `JPGJMTGMTJPTGMP` | 2, 11, 15 | 3, 7, 13 |
| 7 | `GTJMPJMGJPTPMTG` | 5, 10, 12 | 1, 8, 15 |
| 8 | `TJMGJPGJMTPMTPG` | 6, 11, 14 | 4, 7, 15 |
| 9 | `JMGJMPJMTPPTGGT` | 6, 10, 11 | 3, 13, 14 |
| 10 | `MTJGPJGTPMTGMPJ` | 5, 9, 14 | 4, 7, 12 |

Every slot the newcomers didn't take keeps its old author from the original three-way rotation, so those PRs' dialogue trees are unchanged. Each newcomer has a slot in the first six of every day she works, since a shift rarely gets further than that, and the original three keep at least four of those six. Each recipe records its slot's author through `Policy._author`, which reads the same table, so Lineal's assignee standard checks the real author; a misassigned issue only ever goes to someone on staff that day (`Policy.staff(day)`, handed to `records.gd` as the spec's `team`). `Policy.slot_author(day, index, away)` reads the table; anyone listed in `away` (someone who has stopped writing PRs) hands their slots to the day's rotation over whoever is left, deterministically, and with only the original three left that is exactly their old rotation.

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

- **Mood** is `warm`, `neutral`, `strained`, or `hostile`, from the coworker relationship score plus the tone of the author's last three beats (`TONE`: approvals and withdrawn citations warm; change requests, abandons, escalations, and insisting cool). Bands: warm 62+, neutral 42–61, strained 30–41, hostile below 30. `TEMPERAMENT` adjusts them per person: Penny is easily impressed and slow to give up on anyone (warm from 58, strained below 38, hostile below 24); Gwen is hard to win over but respects scrutiny (warm from 66, strained below 36, hostile below 26, and a change request leaves only −2 in her memory).
- **Personalities** live in `PICKS`. Penny revises on the spot most of the time, almost never pushes back (≤6) or abandons (≤3), but escalates to Morgan more as things go wrong, and insisting usually sends her there. Gwen fixes most things at once, is suspicious of quick approvals, and escalates rarely (≤8); `AUTHOR_LEANS` makes her push back on her own field (credentials, and the build: a red build is her tripwire), and when she does she disputes one of those citations.
- **Branches** are rolled with `Policy.roll` keyed on the PR, verdict, mood, and cited rules, so the journal replays them. Weights lean by the categories of what was cited, and citing three or more standards at once makes abandoning likelier. Nothing in the encounter reads audit data: a right and a wrong citation take the same branch and get the same words.
- **Approve:** thanks or a suspicious "wait, you approved that?" by mood (v1), or relief (v2/v3).
- **Request changes:** revise now, revise later, push back (at most once per desk visit), abandon, or escalate. Orientation's practice PR and Monday's first PR always revise later, so the lesson stays scripted and the first shift opens gently; v3 always escalates.
- **Push back:** the PR stays on the desk unsigned and its citations freeze. The `pushback` command answers: `insist` signs the change request as cited and the author revises grudgingly (back in line) or escalates; `withdraw` retracts the disputed citation and the review reopens. Stamping CHANGES REQUESTED again counts as insisting. At the bell a disputed PR is handed off unsigned.
- **Abandon** counts as reviewed and makes no revision; Helios merges it. **Escalate** makes no revision either; Morgan hands the PR to Helios. Only the third-round escalation raises automation reliance (+1), as before, so careful reviewing still shapes the ending.
- **Relationship** changes on top of the review's own: abandon −3, insist −2, withdraw +2.

`state.encounters` records one beat per moment, `{pr_id, author, day, version, mood, node, cited, shift_seconds, seq}`, plus `disputed` (pushback, insist, withdrawn) and `revision_id` (revisions). The mood on a beat is taken before that stamp's own relationship change, and a revision's opening line keeps the mood of the beat that made it, so nothing the author says about a verdict can reflect whether it was right. The archived chat thread's standing warm/distant line for an author follows the mood of their latest beat for the same reason. `Encounters.pending(state)` is the pushback waiting on the desk; `Encounters.typing(state)` is an author revising at the desk.

PR bank entries carry per-PR `pitch`, `pushback`, `relief`, and `grudge` lines; a neutral author speaks them (relief on any approval, grudge after an abandon or escalation), while other moods use the templates so a change of mood is always audible.

## Records: Lineal issues and Pipeline builds

From `Policy.LINEAL_DAY` (3) every packet carries `issue_ref` (the "Closes PAP-412" on its slip, possibly empty or an issue Lineal doesn't have) and `issues` (the issues it puts in Lineal); from `Policy.PIPELINE_DAY` (5) it also carries `build` (its latest pipeline run). These are visible data, like `files`: `active_request` keeps them, and only `violations`, `findings`, `explanation`, and `recipe` are hidden. `content/records.gd` renders them from the recipe (slot, version, author, primary file, and a list of fault and decoy effects) with authored issue copy, a backlog, test names, and failure logs; it never decides whether a record breaks a standard. `Policy._records(recipe)` builds `{author, issue_ref, issues, build}`, and `Policy.findings(files, day, records)` audits code and records together. Record findings carry `record` ("issue" or "build") and `id` (the PR's link, or its build) instead of a path and line.

- **P16** "No vibes": the PR links an issue that exists (its own or the backlog's), and none of its labels is `vibes`, ignoring case. Status never matters. Faults: no link, a link to an issue Lineal doesn't have (`PAP-5764`, `PAPP-576`), or a `vibes`/`Vibes`/`VIBES` label. Near misses: `good-vibes`, `vibe-check`, `Vibes-adjacent`, and Done, Canceled, or Backlog issues.
- **P17** "Urgency belongs to Helios" (days 3-4): the linked issue's priority is not Urgent. Near miss: High, with a note that Helios tried to raise it.
- **P18** "Fibonacci or nothing" (from day 7): the linked issue's estimate is 1, 2, 3, 5, 8, or 13, and from `ZERO_DAY` (9) also 0. Faults: 4, 6, 7, 9, 10, 12, 20, 40, and (before day 9) 0. Near misses: 13, and 0 from day 9.
- **P19** the build is not FAILED; FLAKY passes. From `OVERRIDE_DAY` (7) Helios overrides appear (`PASSED (OVERRIDDEN BY HELIOS)`) and count as passing; from `OVERRIDE_BANNED_DAY` (9) they count as failed.
- **P20** "Branch names are public" (days 5-6): the build's branch contains none of yolo, wip, final, ignoring case, even inside a word (`finalize`, `wipe`). Near misses: `whip`, `yoga`, `finance`, `yo-lo`, `fin-al`, `wimp`.
- **P21** "Hex hygiene" (from day 9): the build's commit hash contains neither dead nor bad. Near misses: `de4d`, `b4d`, `bead`, `dab`, `ba0d`, `dea0`. Clean branches and hashes are scrubbed in `records.gd` so they never spell a banned word by accident.

The code standards are line-scoped and read comments or def lines: **P01** (days 1-2) the exact phrase load-bearing in a comment; **P03** "The colleague" (days 1-4) helios in a comment, even inside a word; **P04** "HR is listening" (days 3-6) a def whose name contains fire, layoff, union, or lunch; **P05** "No ghost TODOs" (days 7-8) a TODO in a comment not followed at once by an owner in parentheses from maya, theo, june, penny, gwen. Fault and near-miss wordings live beside each other in `policy_campaign.gd` and are tested so that each fault breaks exactly its standard and each near miss breaks nothing, on any day.

Without an issue Lineal can find, P17 and P18 have nothing to check, so P16 alone is cited; generation keeps a missing or broken link away from other issue faults (and from day-9 permits, which name the PR's issue) so that every fault comes apart independently. Clean PRs get clean records, often odd but valid ones, and once a standard is retired its old faults turn up on clean PRs. A revision is a new push: it gets a new build, and the issue keeps every uncited fault. Fixed issue faults leave a line in the issue's activity ("Label vibes removed by Maya after review.").

`Catalog.issues(state)` is what Lineal shows: the backlog plus the issues of every PR that has reached the desk (a later version replaces an earlier copy), each with the PRs that link it. `Catalog.builds(state)` is what Pipeline shows: one build per PR version that has reached the desk. Neither ever includes a PR still in line.

## Commands

| `type` | Additional fields | Valid phase |
| --- | --- | --- |
| `toggle-rule` | `rule_id`: active rule, plus `path`/`line` evidence, or `record`/`id` evidence (`issue` or `build`), when citing | review, PR on the desk |
| `consult-ai` | Once per PR (each revision is its own PR) | review, PR on the desk; day 3 onward |
| `review` | `verdict`: `approve` or `request_changes` | review, PR on the desk |
| `pushback` | `choice`: `insist` or `withdraw` | review, while the desk PR's author is pushing back |
| `chat-reply` | `contact`, `pr_id`, `reply_id` from `Chat.reply_options` | review |
| `next-day` | `choice`: `rest`, `socialize`, or `study` | debrief |

Approval requires zero citations; rejection requires at least one. A rejection passes the audit only when its citation set exactly matches the actual violations and each citation's evidence is accepted (`Policy.evidence_matches`). A record citation may point at the PR's own link (even an empty or broken one) or at any issue or build Lineal or Pipeline shows; only the PR's own record, under the record standard it was found for, is accepted. WHOLE FILE and code lines never count for a record standard, and a record never counts for a code standard. Revisions are graded exactly like originals. Invalid commands have no effects. After submission, the desk clears, the next PR is scheduled, and `last_feedback` records the actual decision. `request_index` is a compatibility pointer to the earliest pending catalog entry, not a submitted-review counter or editor selection.

## Consequences and closing bell

Starting resources are 60 CR (`Payroll.START`), 70 trust, 20 stress, 10 automation reliance, and neutral coworker relationships. Correct approval changes author relationship/trust/stress by +4/+3/+3; incorrect approval by +6/-12/+11; correct rejection by -2/+5/+3; incorrect rejection by -7/-7/+9. Consultation removes two stress and adds four automation reliance once per request, even after switching away and returning.

Clearing the line does not end the shift. At 18:00, actual signed reviews (originals and revisions) are audited, and whatever is on the desk, waiting in line, or still on its way, including pending revisions, transfers to Helios (`last_debrief.handed_off`; Morgan's panel says how many). No player decisions are fabricated for skipped work, so chat never claims the player approved or rejected it. The current request is cleared and the pending pointer advances to the next shift.

Payroll settles the day at the bell (`content/payroll.gd`, `Payroll.ledger`), in Paperclip credits (CR):

| Line | CR |
| --- | --- |
| Day rate | +20 |
| Reviews signed ×N (every signed review, revisions and payloads included) | +8 each |
| Shipped defect (an approved PR that failed its audit; not a payload) | −30 each |
| Unfounded change request (a change request that failed its audit) | −20 each |
| Helios referral bonus (a payload you let through) | +15 each |
| Helios efficiency surcharge (anything handed off at the bell) | −5 |
| Overdraft fee (the day started in the red) | −5 |
| Rent, pod 4B (Helios-adjacent) / Badge lanyard lease / Coffee (surge pricing) | −25 / −3 / −7 |

More than two docks of a kind collapse into one line. Signing nothing loses 20 a day (an idle run ends the last Friday around −170 CR); a careful reviewer signing three or four a day clears about +4 to +12 and can afford dinner a few times; a sloppy one sinks. GET DINNER costs 35 CR and is refused (no state change, and replay rejects it) when the balance can't cover it; GO HOME and STUDY are free. Two closings in a row in the red (`Payroll.DEBT_DAYS`) bring collections: +8 stress at each such closing, and Morgan's warning on the panel. A closing balance at or below −200 CR (`Payroll.GARNISH_AT`) ends the run early with the "garnished" ending. Automation reliance increases by four for the shift plus one for each handed-off request, clamped to its allowed range. A shift with zero reviews is valid and still reaches debrief.

`last_debrief` retains day, reviewed, correct, pay (the ledger's pay and docks), expenses (its fixed costs), balance, and message; it adds `timed_out` (true when unsigned work was handed off), `handed_off`, `shift_seconds`, `ledger` (`{start, lines: [{label, amount, kind}], pay, expenses, end}`), and `debt_days` (closings in a row in the red). Each `shift_history` entry records its closing `balance`. The message describes the result qualitatively. Pay and handoff effects apply only once. The evening choice is recorded in `shift_history`, so evenings work even when the player submitted nothing. Rest (−24 stress), socialize (−35 CR, +4 relationship with everyone at the table, −8 stress), and study (+4 trust, +4 stress) keep their effects; only dinner's price changed. A new day resets the clock to morning; the final evening completes the career.

## Saved state and replay

Current state (version 20) contains `practice` (true only on orientation's desk, see below), `shift_seconds`, `active_request_id` (the desk), `desk_line`, `desk_at`, `incoming`, `queued_at`, `arrivals`, `revisions`, `encounters`, `consulted_requests`, `actions`, `shift_history`, and `chat_replies`, plus the story fields `firings`, `strikes`, `payloads`, and `ending`. Each actual decision also records `shift_seconds`. A chat reply records `{day, shift_seconds, pr_id, contact, reply_id}`; authored text remains in the chat catalog, and replies do not secretly alter relationship scores. The story fields are all rebuilt by replaying the journal, so they are not trusted from the saved file.

## Staffing, payloads, and endings

At closing, a coworker takes at most one strike — a defect of theirs you approved shipped, or two or more wrong rejections of their work in a day — and three strikes ends them (`firings`, `content/staff.gd`). Nobody replaces a fired coworker: from the next morning they count as away (`Policy.staff(day, away)` leaves them off the team, out of dinner and the ending's reckoning), their slots are not handed on through `slot_author` but go to Helios (`_open_desk` drops them, so they never reach your desk), and Morgan's panel says so. The run ends early if Morgan's trust falls below `FIRE_TRUST`, stress maxes, Payroll garnishes you, or every original seat is gone; otherwise day 10 resolves the matrix ending (payloads blocked vs let through, crossed with whether the surviving team's average relationship is on your side). `content/endings.gd` holds each ending's title, Morgan's closing words, and cinematic beats.

From day 3, `Catalog.requests_for_day` places a Helios payload (`content/policy_campaign.gd` `PAYLOAD_SPECS`, pleading in `content/payloads.gd`) at the front of the line. A payload breaks only P15; you either let it through (approve, an audit failure that warms the author and dents trust) or block it (request changes — with P15 cited or with no citation at all), and `payloads` records the outcome. A reason-free CHANGES REQUESTED on a normal PR is the `unexplained` branch: Helios merges it, it is graded incorrect, and Morgan notices.

The semantic action journal records consultations, reviews with their citations (each rule's evidence is `{path, line}` or `{record, id}`), pushback answers, accepted replies, deadline closure, and evening choices. Each event records its day and shift time. Clock ticks, temporary selection, and citation toggles are not individually persisted. This keeps the journal naturally bounded by available work and reply options rather than time spent reading.

`validate_save(value)` returns `{ok, state, error}`. It replays the journal against the desk, content, and available reply options, so the line, every landing time, and every revision's fixes and regression are rebuilt, then reconstructs the current citations, record citations included (a journal citing an issue or build Lineal and Pipeline never showed is rejected). A review or consultation must target the PR that was on the desk at that moment. It rejects premature actions, backward timestamps, duplicate consultations or replies, repeated pay, altered audit results, fabricated decisions, and inconsistent resources or phases. JSON integral floats are accepted and normalized; unknown or changed canonical fields are rejected. `serialize_save(state)` returns validated JSON or an empty string.

Validation only accepts the current format and always uses the same catalog. Unsupported formats are rejected; there are no migrations or campaign variants.

`native/save_store.gd` writes each of three slots through a flushed temporary file and retained backup. Slot filenames are stable, so current saves remain at their existing location. Recovery can use a valid current-format backup; no alternative content is loaded to accommodate incompatible files.

## Team chat and tests

`content/chat.gd` derives conversation messages and authored reply options from `state.arrivals`, actual decisions (verdict and cited rules only), and accepted replies; revision packets come from `Catalog.packet`. Dialogue lives in `content/policy_chat.gd`. It must not import Simulation, avoiding a circular dependency. `evening(state)` reports the closed shift for Morgan's end-of-day panel: the day's notes and her closing words (plus the ending after the last day). The Slouch chat app is off the desktop for now; these conversations stay authored and tested for a future chat app.

Run `godot --headless --path . --script res://tests/test_simulation.gd` for rule, economy, catalog, and campaign checks. Run `res://tests/test_shift_clock.gd` the same way for clock mapping, desk landings, all-missed shifts, partial handoffs, consultation persistence, chat replies, mixed action histories, and corrupted timed saves. `res://tests/test_desk.gd` covers the one-PR desk, revision timing, exact fixes, deterministic regressions, the v3 escalation cap, save replay with revisions, and audit-free revision dialogue. `res://tests/test_encounters.gd` covers the encounter graph (every node reachable, in the chart and in play), lines for every author, node, and mood, mood evolving across a day, determinism and save replay, counterfactual no-hint checks (the same mood and action in two audit worlds give the same branch and words), INSIST/WITHDRAW, revise-now and abandon effects on the desk, and the pushback buttons' placement. All scripts exit nonzero on failed checks and require no testing plugin.
