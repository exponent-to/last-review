# Native game verification

Verified on Apple Silicon macOS with Godot 4.7.2.

- Simulation: 219 checks passed. Coverage includes progressive rules, variable shift boundaries, alternate catalog schedules, precise citations, AI mistakes, immutable transitions, one-time wages, evenings, and malformed saves.
- Authored conversations: 512 checks passed. Future requests and notices stay hidden; reactions follow the player's verdict independently of audit correctness; relationship tone is qualitative; returned messages cannot mutate career state or cached content.
- Pointer windows: 59 checks passed using actual viewport press/motion/release events. The regression reproduced four movement failures before switching from polled cursor position to event coordinates. Native and headless checks cover scaled desktop coordinates, clamping, offscreen release, all eight resize handles, usable minimum sizes, anchored opposite edges, maximizing, desktop resize, and closing/reopening without discarding content.
- Native interface integration: zero failures across the authored campaign. It exercises citation controls, AI disclosure, search preservation, window movement/focus/minimization, browser history, unread conversations, and preservation of the player's selected Slouch conversation. Both supported window sizes are covered, including home-icon containment and the exposed office margins.
- Application handoff: zero failures. New Game opens the tutorial directly; releasing Enter cannot submit a review or open an unrelated control. Neutral keyboard focus and disabled-motion preferences survive the transition and focus changes.
- First-person composition: the monitor screen occupies 1040×630 pixels of a 1280×900 viewport. HOME starts with five app icons and all windows closed; the exterior HUD and office strip are removed. App launch, taskbar state, closing/reopening, maximization, and HOME are covered by native interface tests at both supported resolutions.
- All displayed Python diffs were executed with controlled stubs during content review; 16 behavioral assertions confirmed the authored defects and clean cases. The game itself never executes displayed code.
- Native v4 save/load and backup recovery passed, including preservation of earlier save files. Timed arrivals require a fresh career.
- The universal native macOS app exports with the bundled terminal font, its license, local JSON dialogue, and rasterized SVG scenery. No real browser, messaging service, or AI API is involved.
- Packaged monitor build: verified HOME startup, Slouch icon launch, readable wrapped messages on first opening, pointer dragging, and maximize staying inside the monitor. Screenshots are saved under ignored `build/monitor-home.jpg` and `build/monitor-slouch.jpg`.

Windows packaging, notarized distribution, audio, and comprehensive assistive-technology support remain outside this milestone. Pointer and keyboard interaction are supported; screen-reader support is not claimed.

- Timed shift suite: 147 checks pass for six-minute deadlines, ordered arrivals, out-of-order selections, zero-review shifts, handoffs, chat replies, and strict mixed-history save replay. Application checks cover fractional clock accumulation, menu isolation, pause/resume, focus loss, daylight change, and one-time deadline closure.
- Browser playtest: contextual Slouch questions, links into multi-file reviews, file switching, pause/resume, and browser-local Save/reload/Load passed at 1280×900. Native and Web exports both build successfully.

- Main menu: 21 checks pass for entry controls, disabled load, errors, focus, and layout. Tutorial: 11 checks pass for real-action progression, early questions, save round trips, invalid progress, retry, and compatibility with existing v4 careers.
- Manager feedback: 20 checks pass for incident timing, authored defects, handoffs, hidden grades, and immutable message generation. Interface checks verify evening controls in Morgan’s conversation and the absence of a results window. Application checks exercise the full orientation and reset into Monday.

- Browser menu/orientation playtest: New Game, compact lesson instructions, Maya’s contextual question, SAVE AND MAIN MENU, page reload, and Load Game all passed. Loading preserved the lesson and reply history and resumed paused.

- Desktop notifications: 22 checks cover real unread counts, duplicate suppression, conversation-specific reading, hidden future PRs, direct PR and memo routing, focus preservation, System status, dismissal, pause, and bounded bottom-right layout.

Chronology regressions cover returning to an older PR, same-tick exchanges across PRs, interleaved review reactions, stable timestamps across clock ticks, and JSON save/load ordering.

- Cold open: 36 checks passed for staged completion, ping buffer, readable offer wrapping, skip, focus pause, and idempotent handoff.
- Daily press: 189 checks passed for three editions, authored articles, day-gated links, rule-derived memos, deep copies, and independence from audit answers.
- Daily reader: 15 checks passed for clickable headlines, full articles and back navigation, memo-before-start behavior, layout at both supported sizes, and reopening during work.
- Application integration covers the cold-open → orientation → morning-reader → shift sequence, every next-day briefing, no time spent reading before work, and safe Escape handoff.
