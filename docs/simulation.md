# Last Review simulation

`native/simulation.gd` implements a deterministic, turn-based three-day review career. Its static `initial_state`, `dispatch`, `advance`, `validate_save`, and `serialize_save` methods are independent of scenes, clocks, and storage. Transitions deeply copy input dictionaries. `advance` always returns an unchanged copy: reading a diff or rulebook never costs time or resources.

The catalog authors the shift schedule: the current campaign contains three, five, and four ordered PRs. `campaign_days()` and `requests_for_day(day)` expose internal scheduling metadata; the interface must not announce queue totals. Boundaries and final completion follow request day labels and catalog exhaustion, including nonconsecutive day labels. Active rules come from `rules_for_day(day)`: day one has R01, S01, S02, and R05; day two adds R02, D02, D03, and A01; day three adds S06, D05, O05, A04, and A05. Other standards remain future-dated and unavailable in this campaign. Commands are dictionaries:

| `type` | Additional fields | Valid phase |
| --- | --- | --- |
| `toggle-rule` | `rule_id`: an active rule ID | review |
| `consult-ai` | None; once per PR | review |
| `review` | `verdict`: `approve` or `request_changes` | review |
| `next-day` | `choice`: `rest`, `socialize`, or `study` | debrief |

Approval requires zero citations. Rejection requires at least one citation; it is correct only when the selected set exactly equals the actual violations. Extra citations fail the audit. Invalid commands leave the state unchanged. A submitted review immediately advances the request index and preserves its audit in `last_feedback`; hidden answers are only disclosed there after submission. The UI must not reveal active requests' `violations` or `explanation`.

## People, audits, and automation

Starting resources are 120 credits, 70 trust, 20 stress, 10 automation reliance (`autonomy`), and 50 relationship points for Maya, Theo, and Inez.

| Review outcome | Author relationship | System trust | Stress, including review cost |
| --- | --- | --- | --- |
| Correct approval | +4 | +3 | +3 |
| Incorrect approval | +6 | -12 | +11 |
| Correct rejection | -2 | +5 | +3 |
| Incorrect rejection | -7 | -7 | +9 |

Coworker approval and technical correctness intentionally differ. Consultation reduces stress by two and adds four automation reliance, once per PR. Recommendations can be wrong and never override the player's decision. Feedback explains the audit, the coworker's response, and consequences in fewer than 600 characters. Trust, stress, reliance, and relationships clamp to 0–100; credits clamp to -9,999–9,999.

## Shift boundaries

The last authored review for the current day enters debrief and applies pay of `80 + 10 × correct reviews`, living expenses of 90, and 12 automation reliance exactly once. `last_debrief` records the shift's audit, pay, expenses, and pre-evening balance.

Rest removes 18 stress. Socializing costs 15 credits, adds four to every coworker relationship, and removes eight stress. Studying adds four trust and four stress. `next-day` applies the evening choice and starts the next shift. The third day's evening choice still applies before phase becomes `complete`; no further commands have effects. There is no wall-clock progression or randomness.

## State and save validation

State version 3 retains the field structure of `docs/review-sim-contract.md`. Each decision journal entry contains `pr_id`, `verdict`, `cited_rules`, `consulted`, and `correct`. The last decision of a shift gains `evening_choice` once that evening is completed. This captures the entire economic and review history without hidden state.

`validate_save(value)` returns `{ok, state, error}`. It validates types, bounds, active and unique rule IDs, and the catalog's request order. It then replays the bounded journal and compares the complete resulting state, including feedback, debrief, logs, relationships, and resources. This rejects impossible phases, changed audit results, repeated pay, missing evening choices, and edited balances. Integral JSON float numbers are accepted and normalized to native integers. Valid state is reconstructed independently. Unknown fields and altered canonical logs are rejected. Because replay depends on catalog content and rules, future content changes require an explicit save migration or version bump.

`serialize_save(state)` returns validated JSON or an empty string. Earlier review and workshop saves receive an explanatory incompatibility error. Version 3 is necessary because both the authored schedule and canonical feedback changed; replaying a prior journal would reinterpret its shift boundaries.

`native/save_store.gd` uses `user://review-save-v3.json`, isolated from both old review and workshop saves. Earlier files are preserved. When only a v2 file exists, loading explains that a new career is required. It validates, writes and flushes a temporary file, rotates the previous save to `.bak`, then renames the temporary file. A failed final rename attempts rollback. Loading limits files to 100,000 bytes, parses JSON, validates the journal, and recovers a valid backup when possible. A recovered primary returns `ok: true` with an explanatory `error` notice. Callers replace in-memory state only on successful load. Render all content and imported feedback as plain text.

## Verification

Run `godot --headless --path . --script res://tests/test_simulation.gd`. No testing plugin is needed. The script exits nonzero on failed checks and covers all three shifts, exact citations, wrong AI advice, separate relationship/audit consequences, pause-free reading, deep immutability, one-time economy, evenings, final completion, JSON round trips at every stage, corrupt histories, and invalid-save rejection before filesystem writes.

## Authored difficulty and comments

Every PR now includes recursive helper logic and fictional HELIOS annotations. Comments can misdescribe control flow, transformations, or stopping conditions. They are in-world claims, not executable behavior or audit exemptions. Each complete changed helper is shown; there is no hidden middleware that repairs a defect. Clean PRs remain clean even when their comments make false claims. Defects are traceable through concrete values: a filtered timeout, an unchanged credential under an alias, a tenant dropped from a key, a same-release schema removal, retry/deadline arithmetic, an early self-approval return, a later policy override, or an unchanged export payload on a plain-HTTP URL.

A04 applies to the approving reviewer recorded on a machine-authored decision; A05 separately governs disabling the review gate. This avoids double-counting an absent gate as a self-approval decision. The packet texts document enough context to determine complete citation sets. The opening briefing and ongoing logs do not reveal upcoming review totals; debrief counts describe completed work only.

## Team chat

`content/chat.gd` exposes `messages(state, contact) -> Array` for `Maya`, `Theo`, `Inez`, or `company`. Each message has exactly `author`, `text`, and `kind` strings. Supported kinds are `intro`, `notice`, `request`, `hint`, `reaction`, and `ambient`. The returned history is deterministic, independent, and bounded to the most recent 24 messages. Unknown contacts return an empty array.

`content/messages.json` authors the conversations. Coworker introductions are followed by previously encountered requests, their trace hints, and reactions to the actual submitted verdict. The active request and hint appear only for its author during the review phase; the next shift's request stays hidden during debrief. Hints direct attention to public code paths without reading the catalog's hidden violations, audit explanations, or AI answer fields. Approval reactions can express relief even when the audit failed, while correct rejections can still strain a relationship. Historical reactions do not change with present-day relationship tone.

The final ambient message reflects whether the current relationship feels warm, neutral, or strained. Company messages reveal policy and staffing changes only when their authored day has arrived, with qualitative context as automation gains authority. No message displays a relationship score, stress value, resource delta, rule answer, or review quota. Chat reads existing state and never modifies the decision journal, saved-state version, or game resources; unread indicators belong to the interface.

Run `godot --headless --path . --script res://tests/test_chat.gd` to verify visibility, stable history, verdict-dependent reactions, tone, immutability, bounded output, and absence of numerical statistics or audit answers across the full career.
