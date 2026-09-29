# Native simulation core

`native/simulation.gd` is a pure GDScript `RefCounted` module with static methods. It has no scene, timer, rendering, or filesystem dependencies. Call `initial_state()`, apply player actions with `dispatch(state, command)`, and replace the current dictionary with the result. Both `dispatch` and `advance` deeply copy their inputs, including activity entries.

The workshop starts with 240 credits, 20 materials, zero goods, one worker, idle production, and normal speed. Buying adds 10 materials for 30 credits. Hiring costs 100 credits, up to six workers. Each parts-production tick consumes one material and makes one good per worker, limited by available materials. Selling clears all goods for 12 credits each. There are no wages or offline progression in this foundation.

## Time integration

`advance(state, ticks = 1)` processes explicit fixed ticks. Speed zero pauses time and production. Other speeds are metadata for the outer clock: schedule more ticks at 2x or 4x, since this function never multiplies its argument. The UI owns wall-clock accumulation and tick duration. Negative tick batches, batches above 10,000, or overflowing tick counts return an unchanged deep copy.

Splitting a batch into individual ticks yields identical state, including logs. Production remains selected after materials run out; buying supplies resumes it on the next tick. Player actions work while paused. Failed transactions preserve balances and append feedback. The activity log retains the most recent 40 entries.

## Commands

Commands are dictionaries with a `type` key:

| Type | Extra field |
| --- | --- |
| `set-speed` | `speed`: integer 0, 1, 2, or 4 |
| `set-production` | `production`: `idle` or `parts` |
| `buy-materials` | None |
| `sell-goods` | None |
| `hire-worker` | None |

Unknown commands and invalid setting values leave state unchanged. Simulation calls assume valid typed game data; pass every imported state through validation first.

## Validation and native persistence

`validate_save(value)` returns `{ok, state, error}`. Valid saves normalize integral JSON float numbers into integers and reconstruct only recognized properties. Version 1 requires nonnegative safe-integer ticks and balances, one to six workers, known production and speed settings, and chronological logs whose ticks do not exceed the current tick. Log messages must contain 1–240 characters. Integers cannot exceed 9,007,199,254,740,991 to preserve JSON round trips. Incompatible versions need an explicit future migration and currently return a clear error.

`serialize_save(state)` returns validated JSON, or an empty string if invalid. Use `validate_save` for the error details.

`native/save_store.gd` stores `user://workshop-save.json` in the operating system's Godot application-data location. `save_game(state)` returns `{ok, error}`. It validates first, flushes a temporary file, rotates the previous save to `.bak`, then renames the temporary file into place. A final rename failure attempts to restore the previous file. This is recoverable replacement, not a promise of crash-proof filesystem transactions.

`load_game()` returns `{ok, state, error}`. It rejects files above 100,000 bytes, reports malformed JSON or validation failures, and tries the backup when the primary is absent or invalid. Successful recovery from a corrupt primary has `ok: true` and an explanatory `error` string that the UI may show as a notice. Loading never mutates the current in-memory game; replace it only after success.

Render log messages as plain text and disable rich-text markup for imported activity.

## Verification

Run `godot --headless --path . --script res://tests/test_simulation.gd` (substitute the installed Godot executable). The script needs no test plugin, reports its assertion count, and exits nonzero on failure. It covers deterministic ticks, pause/speed behavior, depletion/recovery, transaction prices and caps, deep immutability, integer overflow, JSON round trips, incompatible/corrupt saves, and validation before filesystem writes. It does not touch real save files.
