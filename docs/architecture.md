# Last Review architecture

Godot 4.7.2 owns the native desktop window, Control menus, input, and texture rendering. The simulation is deterministic, turn-based GDScript. Nothing in the review loop depends on wall-clock time or animation.

## Boundaries

Authored JSON → Catalog → current PR and active rules → native workstation.

Native control → command dictionary → immutable simulation transition → render existing controls.

Content contains audit answers, but the active UI never reads `violations` or `explanation`; only a submitted decision exposes them in `last_feedback`. The optional AI recommendation is scripted, not an external model call, and stays hidden until consultation. No displayed code is executed.

The office receives only day, automation authority, and motion preference. It rasterizes hand-authored SVGs once into ImageTextures, then animates frames with nearest filtering. Human occupancy and lit terminals reflect the narrative state. Losing window focus freezes decorative movement; it cannot change a review or economic result.

## Content and gameplay

`content/rules.json` has six categories and 36 standards. Thirty begin active; six automation rules arrive over days two and three. `requests.json` contains four ordered PRs per day, including compliant changes, single-rule defects, and multi-rule defects. Every expected violation references an active rule.

The first loop separates technical trust from relationships. Approval can make a coworker happy even when an audit finds a defect. Stress, salary, daily expenses, and evening choices add personal stakes. The three-day ending is a prototype summary based on trust, stress, and automation authority.

## Persistence

State version 2 stores a bounded journal of decisions, citations, consultations, and evening choices. Save parsing validates types, active rule IDs, and sequence, then replays the journal to reconstruct canonical state. It rejects altered balances, impossible phases, repeated wages, and inconsistent audit records. Numeric JSON floats representing integers are normalized.

The filesystem adapter writes a temporary file, rotates the previous save to a backup, and atomically renames the new file. Load failures preserve the active session. Saves are local to the Last Review application-data directory. There is no automatic load, autosave, or cloud storage.

Because validation replays authored content and economics, incompatible changes require a migration or version bump. Do not silently change scenario outcomes while expecting old v2 saves to remain valid.

## Extending the slice

- Add scenario packets and rules with explicit, non-overlapping audit criteria.
- Generalize the current three-day/four-PR schedule in the simulation and tests when extending the campaign.
- Add richer coworker motivations and evening events without placing rules in button handlers.
- Keep opinion, technical quality, and automation authority as distinct consequences.
- Add a seeded stateful generator only if procedural content becomes necessary; keep validation deterministic.

Native macOS export is configured with the official universal template and local ad-hoc signing. Public distribution signing/notarization and additional platforms are separate future work.
