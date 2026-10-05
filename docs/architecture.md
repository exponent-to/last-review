# PRs please architecture

Godot 4.7.2 owns the native desktop window, Control menus, input, and texture rendering. The simulation is deterministic GDScript. The application advances it in whole elapsed seconds only while the shift is active and the game is unpaused. Decoration never drives the clock. A workday lasts 180 seconds, with arrivals scheduled inside the shift and payroll at closing time.

## Boundaries

Policy campaign → Catalog → the one PR on the desk and active rules → native workstation.

Native control → command dictionary → immutable simulation transition → render existing controls.

Content contains audit answers, but the active UI never reads `violations` or `explanation`; `last_feedback` retains internal audit data, but the interface shows only delivery confirmation and authored downstream consequences. The optional AI recommendation is scripted, not an external model call, and stays hidden until consultation. No displayed code is executed.

The computer frame receives only day, automation authority, and motion preference. It draws hand-authored pixel geometry for the physical monitor and rain outside it. Losing window focus freezes decorative movement; it cannot change a review or economic result. The earlier SVG office renderer remains available as an art component, but no office banner appears in the current composition.

The workstation is a local fictional computer whose monitor fills most of the viewport. `computer_frame.gd` renders the surrounding room and physical bezel; the interface places the operating-system desktop inside its screen insets. The initial home screen contains three app launchers (Review, Intranet, System), with no preopened review panels. Floating native windows own movement, focus, stacking, minimization, maximization, and closing; the interface manages launched apps, taskbar restoration, HOME, and layout reset. Review combines code and sign-off in one app. A local intranet view links authored procedures and the current memo to the rulebook. It has no web engine or network access. Desktop arrangement is presentation state and does not enter the career save.

At closing, the interface opens Morgan's end-of-day panel, a fourth native window with no icon or close button. It renders `Chat.evening(state)`: the closed day's notes (escalations and abandons from `Encounters.morgan`, shipped bugs, handoffs to Helios) and her closing words, then the evening choices as the existing `next-day` command. Emotional tone conveys consequences instead of exposing numeric scores.

The Slouch chat app is off the desktop for now. Its company channel and coworker conversations (`content/chat.gd`, `content/policy_chat.gd`, and the encounter and tree DM lines) still derive authored messages from the decision history and career state, and stay tested, for a future chat app. PR hints are written separately from audit answers, and future requests cannot appear before they reach the player's desk.

New Game selects a save slot, plays the interactive offer cold open, then enters the tutorial workstation. The handoff focuses a neutral surface so releasing Enter cannot activate a review control. The main menu contains only the title and game actions.

## Content and gameplay

`content/policy_campaign.gd` defines ten days (two Monday-to-Friday weeks), fifteen packets per day, and eleven standards (P15 is reserved), at most six in force at once. Standards change at the start of each two-day block (days 1, 3, 5, 7, 9): a rule has an `introduced_day`, an optional `retired_day`, and dated `amendments` that replace its text. `rules_for_day(day)` returns the amended, active rulebook and `changes(day)` what each morning added, amended, or retired. Source text, keyword ink, per-file permits, the file list, the diffstat, and the PR's records (its Jiro ticket and Pipeline build, from `content/records.gd`) determine expected citations through the same evidence the player sees. Evidence has five scopes: line standards need the exact line; file standards (`FILE_SCOPED`) accept the file or any of its lines; whole-PR standards (`PR_SCOPED`: diff budget, tests) list a finding on every changed file, so WHOLE FILE on any of them is accepted; ticket and build standards (`TICKET_SCOPED`, `BUILD_SCOPED`) accept only the PR's own ticket link or build, selected in Jiro or Pipeline. Each packet records a private recipe (bank entry, slot, author, companion files, clean decoys, every fault with its file or record and its wording, permits) so a revision can be regenerated from it minus the faults the author fixed, with a new build; whole-PR faults (a missing travelling test, a lookup table sized just past the budget) are settled after the files are written. Source is never executed. The first Friday opens exact per-file INK-EXCEPTION permits; from the second Thursday a permit must name the PR's own Jiro ticket.

`content/pr_bank.gd` holds the authored bank of realistic, clean pull requests (path, humorous title, coworker phrase, source), ordered as the two weeks' arc: slot N of the campaign reads entry N, and entries past the 150th are spares. Each day has a private plan of what its fifteen slots break (a third clean, every active standard covered, more combined faults in week two) plus decoys: near misses of active standards and the old faults of retired ones. A slot's entry takes the first of the day's waiting plans it can carry; a realized recipe must break exactly what was planned, keep code on main clean, and come apart predictably when any one fault is fixed. Companion files (tests, config, legacy shims, a shim in a `legacy/` subfolder) and one of several believable faults per rule complete the packet. Packets never foreshadow later standards: tickets arrive with Jiro, builds with Pipeline, and permits with the Exception Desk. A test enforces this.

The first loop separates technical trust from relationships. Approval can make a coworker happy even when an audit finds a defect. Stress, salary, daily expenses, and evening choices add personal stakes. Morgan extends the assignment on the first Friday; the ten-day ending is her last word on the end-of-day panel, based on trust, stress, and automation authority.

## Soundtrack

`native/music.gd` is a child of the application. Five stems (`audio/music/intro`, `pulse`, `hats`, `air`, `tension`) of identical length play on one player each, routed to a `Music` bus. They start under `AudioServer.lock()`, so all begin in the same mix step and, at the same rate and loop length, stay sample-locked; the manager only moves their volumes. (`AudioStreamSynchronized` would do the same natively, but it cannot play as a Web Audio sample, which is the robust path in the single-threaded browser build. Samples skip bus effects, so on the web pause and the filtered variations rely on their lower levels.) `Music.mix_for(scene, progress, tense, ending)` is a pure table from game state to stem gains, an overall level, and a bus low-pass cutoff. `main.gd` reports the scene each frame: menu, cold open, morning reading (and orientation), the shift by `shift_seconds / Catalog.shift_seconds()`, Morgan's end-of-day panel, or the finished assignment. A change waits for the next bar line of the playback position (the wall clock since the synchronized start where samples report none) and fades over two bars; pause and focus loss duck and filter at once. `music.play_ending(kind)` (`"warm"`, `"bleak"`) holds an ending variation until the player is back at the menu. `air` is the bright render of the synth figure minus the dark one, so `intro + g·air` opens the figure's filter by `g` without phasing. Each stem file carries 64 samples of its loop start after the loop end, because Godot's interpolation reads past `loop_end` at the wrap. Music never touches simulation state or saves.

## Persistence

State version 14 stores a bounded timed action journal including decisions, consultations, pushback answers, chat replies, shift closure, and evening choices, plus the encounter beats that replaying it rebuilds. Save parsing validates types, active rule IDs, and sequence, then replays the journal to reconstruct canonical state. It rejects altered balances, impossible phases, repeated wages, and inconsistent audit records. Numeric JSON floats representing integers are normalized.

The filesystem adapter writes a temporary file, rotates the previous save to a backup, and atomically renames the new file. Load failures preserve the active session. Saves remain in the original Last Review application-data directory so the title change preserves existing progress. There is no automatic load, autosave, or cloud storage.

There is one campaign and one supported save format. Validation never swaps content or rules. Incompatible files are rejected with a new-game instruction; no migration or alternate campaign is maintained. Stable slot filenames keep valid current saves available.

Because validation replays authored content and economics, incompatible changes require a version bump. Do not silently change scenario outcomes while expecting old saves to remain valid.

## Extending the slice

- Add scenario packets and rules with explicit, non-overlapping audit criteria.
- Extend the campaign by adding day-tagged packets and corresponding briefings; keep future queue lengths out of the player interface.
- Add richer coworker motivations and evening events without placing rules in button handlers.
- Keep opinion, technical quality, and automation authority as distinct consequences.
- Add a seeded stateful generator only if procedural content becomes necessary; keep validation deterministic.

Native macOS export is configured with the official universal template and local ad-hoc signing. Public distribution signing/notarization and additional platforms are separate future work.

## Session entry and practice

`main_menu.gd` owns the New Game / Load Game entry screen. `tutorial.gd` tracks an untimed lesson over a real simulation state for the chosen campaign. The parent dispatches practice commands normally, allows a retry after mistakes, and resets to a fresh career on completion. Orientation goes straight to REVIEW; the practice PR is already on the desk. Only the current orientation format (version 3, inside a version 14 state) is supported.

`save_store.gd` accepts current-format careers and a versioned session envelope for orientation. Both canonical state and lesson progress are validated before writing or loading. Returning to the menu saves first; new-game selection alone never overwrites an existing slot.

The window rain uses three depths of independently moving, angled rainfall outside, without beads or trails on the glass. It uses deterministic decoration seeds, respects pause/reduced motion, and is drawn behind the window frame and monitor. No gameplay randomness is consumed.

The office frame separates exterior glass from the interior wall: skyline and angled rain are clipped to the recessed glazing, above a projecting sill, radiator, outlet, and cable. The desktop has a back lip, light plane, front fascia, and stand shadow. Monitor bounds and cup geometry remain unchanged.
