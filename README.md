# Yard — native simulation framework

A native desktop game built with Godot 4.7.2 and GDScript. The current workshop loop is a replaceable example for a mostly menu-driven simulator. This is a real Godot application, with native engine controls and disk saves.

The visual direction is restrained and utilitarian, informed by Papers, Please: compact controls, muted industrial colors, hard edges, and ledger-style records. All art is editable SVG geometry rasterized into low-resolution textures; no image-generation service is used.

## Play

On this workspace, open `build/Yard.app` after running the build script. No browser or local server is needed.

For development:

```sh
sh scripts/run.sh
```

The launcher finds the project-local Godot editor, a `godot` executable on PATH, or `/Applications/Godot.app`. You can also set `GODOT_BIN` to another Godot executable, or import `project.godot` in the editor and press F6/F5 to run a scene/project.

On a fresh macOS checkout, prepare the pinned official editor and export template:

```sh
sh scripts/bootstrap-macos.sh
sh scripts/build-macos.sh
open build/Yard.app
```

Godot's editor and templates are downloaded from its [official download service](https://godotengine.org/download/macos/). Tool binaries and app builds are ignored by Git.

## Framework loop

Start parts production, buy materials, dispatch finished parts, and hire up to six workers. Pause or choose 1×/2×/4× speed. The system panel provides save/load, new-game confirmation, and decorative motion controls.

One second advances one tick at 1×. Losing window focus pauses elapsed-time accumulation; there is no offline progression. Disabling scenery motion leaves game rules functional. Saves are explicit and are not automatically loaded. Starting over preserves the last disk save until the next save.

The theme, final title, progression, and economy are still open design decisions. This first loop demonstrates framework boundaries; it is not a balanced finished game.

## Verify

```sh
sh scripts/run.sh --headless --script res://tests/test_simulation.gd
sh scripts/run.sh --headless --script res://tests/test_clock.gd
sh scripts/run.sh --headless --editor --import
sh scripts/build-macos.sh
```

The simulation suite covers deterministic updates, pause, transactions, limits, immutability, and corrupt/incompatible saves. The clock checks frame-rate independence, speed, pause, and bounded catch-up. Native UI and exported asset loading are verified in the desktop window.

## Structure

- `project.godot`, `native/main.tscn` — native application entry point.
- `native/main.gd` — lifecycle and component wiring.
- `native/simulation.gd` — pure commands and simulation rules.
- `native/save_store.gd` — validated disk saves with a previous-save backup.
- `native/clock.gd` — fixed simulation timing.
- `native/interface.gd` — native controls and game menus.
- `native/workshop_scene.gd`, `art/` — editable SVG sources and pixel animation.
- `tests/` — headless GDScript checks.
- `scripts/`, `export_presets.cfg` — local launch and macOS application export.

Read [architecture](docs/architecture.md), [simulation](docs/simulation.md), [interface](docs/interface.md), and [art pipeline](docs/art-pipeline.md) for extension guidance.

Work is split into scoped branches/worktrees and merged as incremental commits. The superseded browser experiment exists only in Git history and `archive/browser-prototype`. Main is the native game. No hosted Git remote has been configured.
