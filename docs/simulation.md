# Simulation core

`src/simulation/index.ts` contains pure TypeScript with no browser, storage, rendering, or timer dependencies. Create a game with `createInitialState()`, apply player actions with `dispatch(state, command)`, and replace the current state with the returned value. These functions never mutate the incoming state or its activity log.

The workshop starts with 240 credits, 20 materials, zero goods, one worker, idle production, and normal speed. Buying adds 10 materials for 30 credits. Hiring costs 100 credits, up to six workers. Each parts-production tick consumes one material and makes one good per worker, limited by available materials. Selling clears all goods for 12 credits each. There are no wages or offline progression in this foundation.

## Time integration

`advance(state, ticks = 1)` processes explicit fixed simulation ticks. A paused state (`speed: 0`) does not advance. Other speeds are metadata for the outer clock: the caller schedules more ticks at 2× or 4×, and `advance` never multiplies its tick argument. The UI owns wall-clock accumulation and the duration of a tick. Keep a bounded catch-up budget when tabs resume; a single call accepts at most 10,000 ticks.

Splitting a tick batch into individual calls yields identical state, including logs. Production remains selected after materials run out, so buying supplies resumes production on the next tick. Player commands work while paused. Failed transactions leave balances unchanged and append feedback. Activity history retains the most recent 40 entries; ordinary production ticks do not flood the log.

## Commands

| Command | Payload |
| --- | --- |
| `set-speed` | `speed: 0 \| 1 \| 2 \| 4` |
| `set-production` | `production: 'idle' \| 'parts'` |
| `buy-materials` | None |
| `sell-goods` | None |
| `hire-worker` | None |

## Persistence boundary

`serializeSave(state)` validates and returns JSON. `parseSave(raw)` validates an untrusted JSON string, returning a freshly reconstructed state or throwing an `Error` prefixed with `Invalid save:`. The caller handles localStorage, import/export, user feedback, and recovery without discarding the current game when loading fails.

Version 1 requires all state fields, known speed/production values, workers between one and six, and nonnegative safe-integer ticks and balances. Logs must contain at most 40 entries with chronological ticks no later than the current tick and nonempty messages of at most 240 characters. Inputs are limited to 100,000 characters. Unknown properties are discarded. Version mismatches are rejected; future versions should add an explicit migration before validation. Render log messages as text, never HTML.

Transitions protect safe-integer limits. A tick overflow throws; transactions that would overflow a balance are rejected with activity feedback, and production clamps to remaining goods capacity. Direct calls to simulation functions assume a typed valid state; use the parser for every untrusted source.

## Verification

The Vitest suite covers deterministic stepping, pause/speed behavior, resource depletion and recovery, transaction prices and resource limits, immutable inputs, log bounds, save round trips, corruption, unsupported versions, and integer overflow.
