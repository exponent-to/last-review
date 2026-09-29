# Last Review simulation

`native/simulation.gd` implements a deterministic, turn-based three-day review career. Its static `initial_state`, `dispatch`, `advance`, `validate_save`, and `serialize_save` methods are independent of scenes, clocks, and storage. Transitions deeply copy input dictionaries. `advance` always returns an unchanged copy: reading a diff or rulebook never costs time or resources.

Each day contains four ordered PRs from `content/catalog.gd`. Active rules come from `rules_for_day(day)`. Commands are dictionaries:

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

The fourth submitted review enters debrief and applies pay of `80 + 10 × correct reviews`, living expenses of 90, and 12 automation reliance exactly once. `last_debrief` records the shift's audit, pay, expenses, and pre-evening balance.

Rest removes 18 stress. Socializing costs 15 credits, adds four to every coworker relationship, and removes eight stress. Studying adds four trust and four stress. `next-day` applies the evening choice and starts the next shift. The third day's evening choice still applies before phase becomes `complete`; no further commands have effects. There is no wall-clock progression or randomness.

## State and save validation

State version 2 follows `docs/review-sim-contract.md`. Each decision journal entry contains `pr_id`, `verdict`, `cited_rules`, `consulted`, and `correct`. The last decision of a shift gains `evening_choice` once that evening is completed. This captures the entire economic and review history without hidden state.

`validate_save(value)` returns `{ok, state, error}`. It validates types, bounds, active and unique rule IDs, and the catalog's request order. It then replays the bounded journal and compares the complete resulting state, including feedback, debrief, logs, relationships, and resources. This rejects impossible phases, changed audit results, repeated pay, missing evening choices, and edited balances. Integral JSON float numbers are accepted and normalized to native integers. Valid state is reconstructed independently. Unknown fields and altered canonical logs are rejected. Because replay depends on catalog content and rules, future content changes require an explicit save migration or version bump.

`serialize_save(state)` returns validated JSON or an empty string. Version 1 workshop saves receive a helpful incompatibility error.

`native/save_store.gd` uses `user://review-save-v2.json`, isolated from old workshop saves. It validates, writes and flushes a temporary file, rotates the previous save to `.bak`, then renames the temporary file. A failed final rename attempts rollback. Loading limits files to 100,000 bytes, parses JSON, validates the journal, and recovers a valid backup when possible. A recovered primary returns `ok: true` with an explanatory `error` notice. Callers replace in-memory state only on successful load. Render all content and imported feedback as plain text.

## Verification

Run `godot --headless --path . --script res://tests/test_simulation.gd`. No testing plugin is needed. The script exits nonzero on failed checks and covers all three shifts, exact citations, wrong AI advice, separate relationship/audit consequences, pause-free reading, deep immutability, one-time economy, evenings, final completion, JSON round trips at every stage, corrupt histories, and invalid-save rejection before filesystem writes.
