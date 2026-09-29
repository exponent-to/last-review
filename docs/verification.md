# Native game verification

Verified on Apple Silicon macOS with Godot 4.7.2.

- Simulation: 216 checks passed. Coverage includes progressive rules, variable shift boundaries, alternate catalog schedules, precise citations, AI mistakes, immutable transitions, one-time wages, evenings, and malformed saves.
- Authored conversations: 1,102 checks passed. Future requests and notices stay hidden; reactions follow the player's verdict independently of audit correctness; relationship tone is qualitative; returned messages cannot mutate career state or cached content.
- Intro: 21 checks passed for skip controls, completion once, reduced motion, focus pause, and final prompt behavior.
- Pointer windows: 23 checks passed using actual viewport press/motion/release events. The regression reproduced four movement failures before switching from polled cursor position to event coordinates. Native and headless checks cover scaled desktop coordinates, clamping, offscreen release, maximizing, desktop resize, and closing/reopening without discarding content.
- Native interface integration: zero failures across the authored campaign. It exercises citation controls, AI disclosure, search preservation, window movement/focus/minimization, browser history, unread conversations, and preservation of the player's selected Slouch conversation. Both supported window sizes are covered.
- Application handoff: zero failures. Enter press/release skips the intro without submitting a review or opening an unrelated control. Neutral keyboard focus and disabled-motion preferences survive the transition and focus changes.
- First-person composition: the monitor screen occupies 1220×810 pixels of a 1280×900 viewport. HOME starts with five app icons and all windows closed; the exterior HUD and office strip are removed. App launch, taskbar state, closing/reopening, maximization, and HOME are covered by native interface tests at both supported resolutions.
- All displayed Python diffs were executed with controlled stubs during content review; 16 behavioral assertions confirmed the authored defects and clean cases. The game itself never executes displayed code.
- Native v3 save/load and backup recovery passed, including preservation of earlier v2 save files. The new authored schedule requires a fresh career.
- The universal native macOS app exports with the bundled terminal font, its license, local JSON dialogue, and rasterized SVG scenery. No real browser, messaging service, or AI API is involved.
- Packaged monitor build: verified HOME startup, Slouch icon launch, readable wrapped messages on first opening, pointer dragging, and maximize staying inside the monitor. Screenshots are saved under ignored `build/monitor-home.jpg` and `build/monitor-slouch.jpg`.

Windows packaging, notarized distribution, audio, and comprehensive assistive-technology support remain outside this milestone. Pointer and keyboard interaction are supported; screen-reader support is not claimed.
