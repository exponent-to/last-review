# PRs please simulation

`native/simulation.gd` implements deterministic review rules with incoming requests and a continuous workday. Simulation state is independent of scenes, timers, and disk storage. Public transitions deeply copy their input; the application replaces its current state with the returned value.

## Clock and arrivals

A shift lasts `SHIFT_SECONDS = 360` real seconds and maps to `START_MINUTE = 540` through `END_MINUTE = 1080` (09:00–18:00). `advance(state, seconds = 1)` accepts elapsed whole seconds during the review phase. Zero or negative deltas do nothing; a large delta stops at the current shift's deadline. It never advances across evenings. `clock_minutes(state)` returns the current displayed minute.

The application owns real-time accumulation and pause controls. While paused, it must not call `advance`; time spent paused is not caught up afterward. Fractional-second accumulation and pause UI are intentionally outside saved simulation state.

`Catalog.arrival_seconds(request_id)` determines each request's delivery time: arrivals run from twenty seconds into a shift through its later stages, spread across that day's authored packets. Unknown IDs return -1. The campaign currently has differently sized shifts, but progression derives from catalog metadata. Queue totals are internal scheduling data and must not be announced in the interface.

`available_requests(state)` returns arrived, still-pending requests for the current shift in authored order. `active_request(state)` returns only the player's explicitly selected pending request, or an empty dictionary. Neither helper includes hidden audit violations or explanations. AI verdict/note fields appear only after that request has been consulted. Other public packet fields, including multiple-file content, are preserved.

Arrival never opens the editor automatically. `select-request` accepts `pr_id` (or `request_id`); an empty ID clears selection. Unarrived, already reviewed, or previous-shift requests cannot be selected. Selecting the same request preserves citations. Switching requests clears citations and restores that request's consultation status. Requests may be reviewed in any order after they arrive.

## Commands

| `type` | Additional fields | Valid phase |
| --- | --- | --- |
| `select-request` | `pr_id`: arrived pending request, or empty | review |
| `toggle-rule` | `rule_id`: active rule | review, with selection |
| `consult-ai` | Once per selected request | review, with selection |
| `review` | `verdict`: `approve` or `request_changes` | review, with selection |
| `chat-reply` | `contact`, `pr_id`, `reply_id` from `Chat.reply_options` | review |
| `next-day` | `choice`: `rest`, `socialize`, or `study` | debrief |

Approval requires zero citations; rejection requires at least one. A rejection passes the audit only when its citation set exactly matches the actual violations. Invalid commands have no effects. After submission, selection clears and `last_feedback` records the actual decision. `request_index` is a compatibility pointer to the earliest pending catalog entry, not a submitted-review counter or editor selection.

## Consequences and closing bell

Starting resources remain 120 credits, 70 trust, 20 stress, 10 automation reliance, and neutral coworker relationships. Correct approval changes author relationship/trust/stress by +4/+3/+3; incorrect approval by +6/-12/+11; correct rejection by -2/+5/+3; incorrect rejection by -7/-7/+9. Consultation removes two stress and adds four automation reliance once per request, even after switching away and returning.

Completing all currently available work does not end the shift. At 18:00, actual signed reviews are audited and unsigned requests transfer to Helios. No player decisions are fabricated for skipped work, so chat never claims the player approved or rejected it. The current request is cleared and the pending pointer advances to the next shift.

Pay is the existing base of 80 plus ten for each correct, actually submitted review; living expenses are 90. Unsigned work earns no bonus. Automation reliance increases by twelve for the shift plus six for each handed-off request, clamped to its allowed range. A shift with zero reviews is valid and still reaches debrief.

`last_debrief` retains day, reviewed, correct, pay, expenses, balance, and message; it adds `timed_out` (true when unsigned work was handed off), `handed_off`, and `shift_seconds`. The message describes the result qualitatively. Pay and handoff effects apply only once. The evening choice is recorded in `shift_history`, so evenings work even when the player submitted nothing. Rest, socialize, and study retain their previous effects. A new day resets the clock to morning; the final evening completes the career.

## Saved state and replay

Version 4 adds `shift_seconds`, `active_request_id`, `consulted_requests`, `actions`, `shift_history`, and `chat_replies`. Each actual decision also records `shift_seconds`. A chat reply records `{day, shift_seconds, pr_id, contact, reply_id}`; authored text remains in the chat catalog, and replies do not secretly alter relationship scores.

The semantic action journal records consultations, reviews with their citations, accepted replies, deadline closure, and evening choices. Each event records its day and shift time. Clock ticks, temporary selection, and citation toggles are not individually persisted. This keeps the journal naturally bounded by available work and reply options rather than time spent reading.

`validate_save(value)` returns `{ok, state, error}`. It replays the journal against current arrival times, content, and available reply options, then reconstructs final selection and citations. It rejects premature actions, backward timestamps, duplicate consultations or replies, repeated pay, altered audit results, fabricated decisions, and inconsistent resources or phases. JSON integral floats are accepted and normalized; unknown or changed canonical fields are rejected. `serialize_save(state)` returns validated JSON or an empty string.

`native/save_store.gd` writes `user://review-save-v4.json` through a flushed temporary file and retained backup. Earlier v3 and v2 files are preserved. Untimed v3 histories cannot establish when requests arrived or were selected, so they receive an explicit incompatibility explanation instead of a silent migration. Load recovery tries the current-format backup without overwriting prior saves.

## Team chat and tests

`content/chat.gd` derives conversation messages and authored reply options from public arrivals, actual decisions, and accepted replies. It must not import Simulation, avoiding a circular dependency; both systems share Catalog's arrival helper. UI unread state and conversation focus remain outside the simulation.

Run `godot --headless --path . --script res://tests/test_simulation.gd` for rule, economy, catalog, and campaign checks. Run `res://tests/test_shift_clock.gd` the same way for clock mapping, arrival gates, out-of-order selection, all-missed shifts, partial handoffs, consultation persistence, chat replies, mixed action histories, and corrupted timed saves. Both scripts exit nonzero on failed checks and require no testing plugin.
