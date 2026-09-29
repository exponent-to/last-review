# Last Review

A native software-engineering life sim built with Godot 4.7.2. You review pull requests at a company handing more authority to an AGI assistant. Technical correctness, coworker approval, and your own ability to cope do not always align.

The playable slice opens with a terminal onboarding sequence, then a computer desktop inside a large physical monitor. Launch Review, Handbook, Slouch, Intranet, or System from the home-screen icons. The windowed desktop uses bundled IBM Plex Mono and hand-authored pixel art, with a rainy room visible around the monitor. The rulebook starts small and expands as management issues new policies. Last Review is a working title.

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
5. When management closes the shift, receive pay, cover living expenses, and choose rest, socializing, or study. Shift lengths vary; the remaining queue is not disclosed.

Helios can advise you, but its scripted recommendations may be wrong. Generated comments also make confident claims: trace recursive helpers and actual values instead of taking their reassurance on trust. Consultation eases stress while increasing its authority. New policies arrive between shifts. The office loses human occupants as more machine terminals come online. The final report responds to trust, stress, and AI authority.

Reading and searching never consume game time. Skip the opening with Enter, Escape, or its on-screen control. Native keyboard navigation uses Tab/Shift-Tab and Enter/Space; the code viewer is read-only and selectable. SYSTEM contains save/load, confirmed new-run controls, instructions, and the background-motion toggle.

Open an app from its desktop icon. Drag titlebars to arrange windows, drag any edge or corner to resize, or use the minimize, maximize, and close controls. Resizing stops at the screen boundaries and each app's usable minimum size. The taskbar tracks open apps; HOME reveals the desktop. With a titlebar focused, arrow keys move its window (Shift moves farther). ARRANGE restores the layout. Intranet opens company procedures, daily memos, standards, and team chat. It is an authored local interface, not a real web browser.

Open **SLOUCH**, the company's chat app, to read coworker DMs and company messages. Colleagues hint at tricky code and react to your approvals or change requests. Their tone carries relationship signals; there are no visible relationship scores, stress percentages, or authority meters. Incoming messages mark conversations unread without opening them for you. Money remains explicit in payroll paperwork. Slouch is entirely fictional and local, with no connection to a real messaging service.

## Saves

Saves are explicit, use one local slot plus the previous-save backup, and do not load automatically. The v3 file is `user://review-save-v3.json`; on macOS this normally lives under `~/Library/Application Support/Godot/app_userdata/Last Review/`. Earlier review careers and workshop saves remain separate and unchanged. The revised rule progression and shift schedule require a fresh career. Starting a new run preserves the disk save until you save again.

The bounded decision history is replayed when validating a save. Changes to scenario answers, economics, or canonical feedback require a save migration/version bump. See [simulation documentation](docs/simulation.md).

## Develop and verify

```sh
sh scripts/check.sh
sh scripts/build-macos.sh
```

The simulation suite covers the authored career, precise citations, AI mistakes, relationship and audit consequences, one-time pay, evening choices, immutability, and malformed saves. The native-interface test drives actual rule/decision controls through the campaign and final report. The intro suite checks completion, skipping, reduced motion, and pause behavior. All run headlessly without test plugins.

- `content/` — editable JSON rules, PR packets, and daily briefings.
- `content/chat.gd`, `content/messages.json` — authored coworker messages derived from the career's decisions.
- `native/simulation.gd` — pure turn-based decisions and life-sim consequences.
- `native/interface.gd` — review desk, rule search, people, evenings, and system controls.
- `native/desktop_window.gd` — draggable, focusable, minimizable native desktop windows.
- `native/intro.gd` — animated terminal opening and skip controls.
- `native/office_scene.gd`, `art/` — rasterized SVG office scenery and animation.
- `native/computer_frame.gd` — physical monitor and animated rainy room around the desktop.
- `native/save_store.gd`, `native/main.gd` — persistence and application wiring.
- `tests/`, `scripts/`, `export_presets.cfg` — checks and native macOS packaging.

See [architecture](docs/architecture.md), [interface](docs/interface.md), [art pipeline](docs/art-pipeline.md), and [verification](docs/verification.md).

This is an authored prototype, not a finished or procedurally generated career. There is no live code execution, real repository access, audio, multiplayer, or Windows build yet. Earlier workshop/browser prototypes remain in Git history; development continues through scoped branches/worktrees and incremental commits. Development history is hosted in the private [TravisGibbs/last-review repository](https://github.com/TravisGibbs/last-review).
