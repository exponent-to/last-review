# Framework verification

Verified locally on Apple Silicon macOS with Godot 4.7.2.

- Simulation headless suite: 65 checks passed, zero failures.
- Clock checks: frame-rate independence, speed, pause, reset, and bounded long frames passed.
- Full project import and native startup: no script or asset errors.
- Export: standalone universal macOS application produced using the official export template and ad-hoc signing.
- Packaged game: all source SVGs load and rasterize correctly inside the exported app.
- Production: starting the line decreases materials and increases finished parts.
- Pause: tick and production counts remain fixed.
- Transactions: dispatching 12 parts, buying 10 materials, and assigning one worker changes $240 to $254, 8 materials to 18, 12 parts to 0, and crew 1 to 2.
- Persistence: saving, confirming a new run, and loading restores inventory, tick, production mode, and pause state.
- Native reset dialog: readable confirmation and cancellation controls.
- Layout: native controls fit at 1120×820 and 960×720; overflowing records use a scroll container and the clock controls remain available.

Windows export, public distribution signing/notarization, audio, and accessibility through assistive technologies have not been validated in this milestone. Native keyboard focus uses Godot's standard Control navigation.
