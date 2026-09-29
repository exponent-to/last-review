# Last Review

A native software-engineering life sim built with Godot 4.7.2. You review pull requests at a company handing more authority to an AGI assistant. Technical correctness, coworker approval, and your own ability to cope do not always align.

The current playable slice has **three days, 12 authored PRs, and 36 indexed standards**. Its cool midnight-blue workstation uses native controls, readable diffs, a searchable rulebook, and animated SVG-derived pixel art. Last Review is a working title.

## Play

Open `build/Last Review.app`, or run from source:

```sh
sh scripts/run.sh
```

The launcher finds the project-local Godot editor, `godot` on PATH, or `/Applications/Godot.app`. Set `GODOT_BIN` to override. You can also import `project.godot` in Godot and press F5.

On a fresh macOS checkout:

```sh
sh scripts/bootstrap-macos.sh
sh scripts/build-macos.sh
open 'build/Last Review.app'
```

The bootstrap downloads the pinned editor and export template from Godot's official download service. Binaries and builds are ignored by Git. The app runs locally with no browser, server, external LLM, or account.

## Your shift

1. Read the PR's author message, review packet, and code diff. The packet and diff scroll independently.
2. Search standards by ID, title, or text; optionally filter by category.
3. Approve compliant work with no citations. To request changes, cite every violated rule and no unrelated rules.
4. Read the previous-review audit. Its technical assessment and the author's reaction are separate.
5. After four reviews, receive pay, cover living expenses, and choose rest, socializing, or study.

Helios can advise you, but its scripted recommendations may be wrong. Consultation eases stress while increasing its authority. New automation policies arrive on days two and three. The office loses human occupants as more machine terminals come online. The final report responds to trust, stress, and AI authority.

Reading and searching never consume game time. Native keyboard navigation uses Tab/Shift-Tab and Enter/Space; the code viewer is read-only and selectable. SYSTEM contains save/load, confirmed new-run controls, instructions, and the background-motion toggle.

## Saves

Saves are explicit, use one local slot plus the previous-save backup, and do not load automatically. The v2 file is `user://review-save-v2.json`; on macOS this normally lives under `~/Library/Application Support/Godot/app_userdata/Last Review/`. Old workshop saves remain separate. Starting a new run preserves the disk save until you save again.

The bounded decision history is replayed when validating a save. Changes to scenario answers, economics, or canonical feedback require a save migration/version bump. See [simulation documentation](docs/simulation.md).

## Develop and verify

```sh
sh scripts/check.sh
sh scripts/build-macos.sh
```

The simulation suite covers all three days, precise citations, AI mistakes, relationship and audit consequences, one-time pay, evening choices, immutability, and malformed saves. The native-interface test drives actual rule/decision controls through all 12 PRs and the final report. Both run headlessly without test plugins.

- `content/` — editable JSON rules, PR packets, and daily briefings.
- `native/simulation.gd` — pure turn-based decisions and life-sim consequences.
- `native/interface.gd` — review desk, rule search, people, evenings, and system controls.
- `native/office_scene.gd`, `art/` — rasterized SVG office scenery and animation.
- `native/save_store.gd`, `native/main.gd` — persistence and application wiring.
- `tests/`, `scripts/`, `export_presets.cfg` — checks and native macOS packaging.

See [architecture](docs/architecture.md), [interface](docs/interface.md), [art pipeline](docs/art-pipeline.md), and [verification](docs/verification.md).

This is an authored prototype, not a finished or procedurally generated career. There is no live code execution, real repository access, audio, multiplayer, or Windows build yet. Earlier workshop/browser prototypes remain in Git history; development continues through scoped branches/worktrees and incremental commits. No hosted Git remote is configured.
