# PRs please simulation

`native/simulation.gd` implements deterministic review rules with a one-PR desk and a continuous workday. Simulation state is independent of scenes, timers, and disk storage. Public transitions deeply copy their input; the application replaces its current state with the returned value.

## Clock and arrivals

A shift lasts `SHIFT_SECONDS = 300` real seconds and maps to `START_MINUTE = 540` through `END_MINUTE = 1080` (09:00–18:00). `advance(state, seconds = 1)` accepts elapsed whole seconds during the review phase. Zero or negative deltas do nothing; a large delta stops at the current shift's deadline. It never advances across evenings. `clock_minutes(state)` returns the current displayed minute.

The application owns real-time accumulation and pause controls. While paused, it must not call `advance`; time spent paused is not caught up afterward. Fractional-second accumulation and pause UI are intentionally outside saved simulation state.

`Catalog.shift_seconds()` always returns 300.

## The desk and the line

The desk holds exactly one PR, like the booth in Papers, Please. Each morning the day's line is its fifteen authored packets in order (`state.desk_line`), and the first is put on the desk at 0 seconds (`active_request_id`); nobody picks it. When the player stamps a verdict, the desk empties and the next PR in line lands `DESK_BEAT = 3` game seconds later (`state.desk_at`), becoming active by itself. `advance` delivers it at its scheduled second, so batched and single-second clocks agree. A PR due at or after the bell never lands. Every landing is recorded in `state.arrivals` as `{pr_id, day, shift_seconds}`; Slouch uses that log to send each PR's message when it reached the desk. The line length is internal scheduling data and must never be shown.

`active_request(state)` returns the PR on the desk, or an empty dictionary between PRs and after closing. `available_requests(state)` returns that PR in a list of at most one. Neither includes hidden audit violations, findings, explanations, or the generation recipe; AI verdict/note fields appear only after that PR has been consulted. There is no `select-request` command: the player cannot choose among PRs.

## Revisions

Requesting changes sends the PR back to its author, who returns a revision: `PR-2004` → `PR-2004-v2`, then `PR-2004-v3` (shown as "PR-2004 · v2"). `state.revisions` records `{id, parent_id, origin_id, version, day, cited, fixed, regression}` and the revision joins the line at index `REVISION_GAP = 2`, behind the next two PRs, or sooner if fewer remain.

- **Fixed:** only rules the player cited that really were violated in the parent (anywhere in its findings). Uncited real violations stay. Citations of rules that weren't violated fix nothing.
- **Regression:** with no RNG, about one revision in five that fixes something also breaks one new standard: one active that day, not already broken, not cited, and never P02 (which would rewrite a whole file). `Policy.roll(id + "|regression")` decides, from the revision ID alone.
- **Note:** every revision carries a harmless author comment acknowledging the review (none contain `!` or a long line, and placement is verified), so a note never hints whether a citation was real.
- **Cap:** a change request on v3 escalates. No v4 is made; Helios takes the PR (automation reliance +1) and Morgan messages about it.

`policy_campaign.gd` gives every packet a private `recipe` (bank entry, companion files, each fault with its file and wording, notes, permits). `Policy.revision(parent, version, fixed, regression, cited)` regenerates the files from the parent's recipe minus the fixed faults, plus any regression and the note, and returns a packet with the same shape as an original (`id, title, author, day, file, files, diff, message, description, violations, findings, explanation, ai_verdict, ai_note`, plus `revision`, `parent_id`, `origin_id`). Originals have `revision` 1 and an empty `parent_id`. `Catalog.packet(state, id)` finds originals and revisions alike, and grading, chat, debrief, and the interface all go through it. A revision's `message` and `description` are phrased from what the player cited, in plain words without rule IDs, and are identical whether or not anything was actually fixed or broken.

## Commands

| `type` | Additional fields | Valid phase |
| --- | --- | --- |
| `toggle-rule` | `rule_id`: active rule, plus `path`/`line` evidence when citing | review, PR on the desk |
| `consult-ai` | Once per PR (each revision is its own PR) | review, PR on the desk; day 3 onward |
| `review` | `verdict`: `approve` or `request_changes` | review, PR on the desk |
| `chat-reply` | `contact`, `pr_id`, `reply_id` from `Chat.reply_options` | review |
| `next-day` | `choice`: `rest`, `socialize`, or `study` | debrief |

Approval requires zero citations; rejection requires at least one. A rejection passes the audit only when its citation set exactly matches the actual violations. Revisions are graded exactly like originals. Invalid commands have no effects. After submission, the desk clears, the next PR is scheduled, and `last_feedback` records the actual decision. `request_index` is a compatibility pointer to the earliest pending catalog entry, not a submitted-review counter or editor selection.

## Consequences and closing bell

Starting resources remain 120 credits, 70 trust, 20 stress, 10 automation reliance, and neutral coworker relationships. Correct approval changes author relationship/trust/stress by +4/+3/+3; incorrect approval by +6/-12/+11; correct rejection by -2/+5/+3; incorrect rejection by -7/-7/+9. Consultation removes two stress and adds four automation reliance once per request, even after switching away and returning.

Clearing the line does not end the shift. At 18:00, actual signed reviews (originals and revisions) are audited, and whatever is on the desk or still in line, including pending revisions, transfers to Helios. No player decisions are fabricated for skipped work, so chat never claims the player approved or rejected it. The current request is cleared and the pending pointer advances to the next shift.

Pay is the existing base of 80 plus ten for each correct, actually submitted review, revisions included; living expenses are 90. Unsigned work earns no bonus. Automation reliance increases by four for the shift plus one for each handed-off request, clamped to its allowed range. A shift with zero reviews is valid and still reaches debrief.

`last_debrief` retains day, reviewed, correct, pay, expenses, balance, and message; it adds `timed_out` (true when unsigned work was handed off), `handed_off`, and `shift_seconds`. The message describes the result qualitatively. Pay and handoff effects apply only once. The evening choice is recorded in `shift_history`, so evenings work even when the player submitted nothing. Rest, socialize, and study retain their previous effects. A new day resets the clock to morning; the final evening completes the career.

## Saved state and replay

Current state (version 10) contains `shift_seconds`, `active_request_id` (the desk), `desk_line`, `desk_at`, `arrivals`, `revisions`, `consulted_requests`, `actions`, `shift_history`, and `chat_replies`. Each actual decision also records `shift_seconds`. A chat reply records `{day, shift_seconds, pr_id, contact, reply_id}`; authored text remains in the chat catalog, and replies do not secretly alter relationship scores.

The semantic action journal records consultations, reviews with their citations, accepted replies, deadline closure, and evening choices. Each event records its day and shift time. Clock ticks, temporary selection, and citation toggles are not individually persisted. This keeps the journal naturally bounded by available work and reply options rather than time spent reading.

`validate_save(value)` returns `{ok, state, error}`. It replays the journal against the desk, content, and available reply options, so the line, every landing time, and every revision's fixes and regression are rebuilt, then reconstructs the current citations. A review or consultation must target the PR that was on the desk at that moment. It rejects premature actions, backward timestamps, duplicate consultations or replies, repeated pay, altered audit results, fabricated decisions, and inconsistent resources or phases. JSON integral floats are accepted and normalized; unknown or changed canonical fields are rejected. `serialize_save(state)` returns validated JSON or an empty string.

Validation only accepts the current format and always uses the same catalog. Unsupported formats are rejected; there are no migrations or campaign variants.

`native/save_store.gd` writes each of three slots through a flushed temporary file and retained backup. Slot filenames are stable, so current saves remain at their existing location. Recovery can use a valid current-format backup; no alternative content is loaded to accommodate incompatible files.

## Team chat and tests

`content/chat.gd` derives conversation messages and authored reply options from `state.arrivals`, actual decisions (verdict and cited rules only), and accepted replies; revision packets come from `Catalog.packet`. Dialogue lives in `content/policy_chat.gd`. It must not import Simulation, avoiding a circular dependency. UI unread state and conversation focus remain outside the simulation.

Run `godot --headless --path . --script res://tests/test_simulation.gd` for rule, economy, catalog, and campaign checks. Run `res://tests/test_shift_clock.gd` the same way for clock mapping, desk landings, all-missed shifts, partial handoffs, consultation persistence, chat replies, mixed action histories, and corrupted timed saves. `res://tests/test_desk.gd` covers the one-PR desk, revision timing, exact fixes, deterministic regressions, the v3 escalation cap, save replay with revisions, and audit-free revision dialogue. All scripts exit nonzero on failed checks and require no testing plugin.
