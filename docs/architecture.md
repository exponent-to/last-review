# Native game architecture

Godot 4.7.2 provides the native desktop window, Control-based menus, texture rendering, input, and application export. GDScript game rules are independent of scene nodes and drawing.

## Data flow

Native button → command dictionary → pure state transition → update existing Control values.

Frame delta → bounded fixed-step clock → whole simulation ticks → pure state transition.

The decorative workshop receives only working/idle and motion flags. SVG sources are rasterized once into native ImageTextures at their intrinsic low resolution. Integer scaling and nearest filtering keep source pixels square. Animation never changes gameplay.

## Timing and persistence

The clock applies simulation speed exactly once, and the core consumes whole ticks. Time accumulation stops when the game window loses focus. Long frames are bounded to prevent runaway catch-up. There is no offline progress in this milestone.

Simulation state is plain data with a versioned schema. Save parsing reconstructs known fields, checks numeric limits and enums, and rejects malformed data before replacing the active state. The filesystem adapter writes a temporary file and retains the previous save as a backup. Files live in Godot's `user://` application-data directory, not in the source checkout. On macOS the default is `~/Library/Application Support/Godot/app_userdata/Yard/`.

## Extension points

1. Replace the workshop state/commands with the actual simulation theme.
2. Add pure transition tests for each player decision and invariant.
3. Extend native menu views without putting rules in button handlers.
4. Replace or expand SVG frame strips without coupling art to timing.
5. Add explicit migrations before changing save schema versions.

If randomness is introduced, store and advance an explicit seed. Avoid wall-clock time or scene state inside deterministic rules.

## Desktop builds

`export_presets.cfg` exports a native universal macOS application using a project-local official template. `scripts/build-macos.sh` produces `build/Yard.app` and its ZIP. The local build uses ad-hoc signing; public distribution would require its own signing/notarization setup. Windows export is a later packaging task unless requested.

Current scope: one local player, one manual disk-save slot plus backup, example economy, no audio, multiplayer, backend, or public distribution. The earlier web prototype is retained in Git history only.
