# PRs please architecture

Godot 4.7.2 owns the native desktop window, Control menus, input, and texture rendering. The simulation is deterministic GDScript. The application advances it in whole elapsed seconds only while the shift is active and the game is unpaused. Decoration never drives the clock. A workday lasts 360 seconds, with arrivals scheduled inside the shift and payroll at closing time.

## Boundaries

Authored JSON → Catalog → current PR and active rules → native workstation.

Native control → command dictionary → immutable simulation transition → render existing controls.

Content contains audit answers, but the active UI never reads `violations` or `explanation`; `last_feedback` retains internal audit data, but the interface shows only delivery confirmation and authored downstream consequences. The optional AI recommendation is scripted, not an external model call, and stays hidden until consultation. No displayed code is executed.

The computer frame receives only day, automation authority, and motion preference. It draws hand-authored pixel geometry for the physical monitor and rain outside it. Losing window focus freezes decorative movement; it cannot change a review or economic result. The earlier SVG office renderer remains available as an art component, but no office banner appears in the current composition.

The workstation is a local fictional computer whose monitor fills most of the viewport. `computer_frame.gd` renders the surrounding room and physical bezel; the interface places the operating-system desktop inside its screen insets. The initial home screen contains five app launchers, with no preopened review panels. Floating native windows own movement, focus, stacking, minimization, maximization, and closing; the interface manages launched apps, taskbar restoration, HOME, and layout reset. Review combines code and sign-off in one app. A local intranet view links authored procedures and the current memo to the rulebook and Slouch. It has no web engine or network access. Desktop arrangement is presentation state and does not enter the career save.

Slouch is another native desktop window. Its company channel and coworker conversations derive authored messages from the existing decision history and current career state. Emotional tone conveys relationship changes instead of exposing numeric scores. PR hints are written separately from audit answers, and future requests cannot appear before they reach the player's desk. Read/unread presentation is session-local; it does not mutate the career or contact a messaging service.

New Game goes directly from the menu to the tutorial workstation. The handoff focuses a neutral surface so releasing Enter cannot activate a review control. The main menu contains only the title and game actions.

## Content and gameplay

`content/rules.json` contains a larger standards index, with four rules active initially, eight on the second day, and thirteen on the third. Remaining standards are future-dated for later content. `requests.json` assigns each ordered PR to a day; the current development fixture has 3/5/4 requests. Catalog-derived boundaries close shifts without a fixed modulo or player-facing queue counter. Every expected violation references an active rule. Confident AI comments and recursive helpers obscure the defects without changing the exact audit criteria.

The first loop separates technical trust from relationships. Approval can make a coworker happy even when an audit finds a defect. Stress, salary, daily expenses, and evening choices add personal stakes. The three-day ending is a manager DM based on trust, stress, and automation authority.

## Persistence

State version 4 stores a bounded timed action journal including PR selection, decisions, consultations, chat replies, shift closure, and evening choices. Save parsing validates types, active rule IDs, and sequence, then replays the journal to reconstruct canonical state. It rejects altered balances, impossible phases, repeated wages, and inconsistent audit records. Numeric JSON floats representing integers are normalized. Earlier careers remain on disk separately; their old shift boundaries cannot be replayed against timed arrivals.

The filesystem adapter writes a temporary file, rotates the previous save to a backup, and atomically renames the new file. Load failures preserve the active session. Saves remain in the original Last Review application-data directory so the title change preserves existing progress. There is no automatic load, autosave, or cloud storage.

Because validation replays authored content and economics, incompatible changes require a migration or version bump. Do not silently change scenario outcomes while expecting old saves to remain valid.

## Extending the slice

- Add scenario packets and rules with explicit, non-overlapping audit criteria.
- Extend the campaign by adding day-tagged packets and corresponding briefings; keep future queue lengths out of the player interface.
- Add richer coworker motivations and evening events without placing rules in button handlers.
- Keep opinion, technical quality, and automation authority as distinct consequences.
- Add a seeded stateful generator only if procedural content becomes necessary; keep validation deterministic.

Native macOS export is configured with the official universal template and local ad-hoc signing. Public distribution signing/notarization and additional platforms are separate future work.

## Session entry and practice

`main_menu.gd` owns the New Game / Load Game entry screen. `tutorial.gd` tracks an untimed lesson over a real v4 simulation state. The parent dispatches practice commands normally, allows a retry after mistakes, and resets to a fresh career on completion. A lesson recognizes questions asked early so one-shot replies cannot strand progress.

`save_store.gd` accepts existing raw v4 careers and a versioned session envelope for orientation. Both canonical state and lesson progress are validated before writing or loading. Returning to the menu saves first; new-game selection alone never overwrites an existing slot.

The window rain uses three depths of independently moving, angled rainfall outside, without beads or trails on the glass. It uses deterministic decoration seeds, respects pause/reduced motion, and is drawn behind the window frame and monitor. No gameplay randomness is consumed.

The office frame separates exterior glass from the interior wall: skyline and angled rain are clipped to the recessed glazing, above a projecting sill, radiator, outlet, and cable. The desktop has a back lip, light plane, front fascia, and stand shadow. Monitor bounds and cup geometry remain unchanged.
