# PRs please

A native software-engineering life sim built with Godot 4.7.2. You review pull requests at a company handing more authority to an AGI assistant. Policy compliance, coworker approval, and your own ability to cope do not always align.

The playable slice opens at a main menu with New Game and Load Game. New Game plays a skippable cold open: a laptop wakes in a dark room, an inbox full of rejections receives a lowball Paperclip Labs offer, and you open and sign it yourself. The story then hands off to untimed orientation on the office desktop. Load Game resumes the saved run without replaying the opening. Launch Review, Slouch, Intranet, or System from the home-screen icons. The windowed desktop uses bundled IBM Plex Mono and hand-authored pixel art, with a rainy room visible around the monitor. The rulebook starts small and expands as management issues new policies.

## Play

[Play in your desktop browser](https://travis.show/prs-please/). Browser progress is saved locally and is separate from the native app.

Open `build/PRs please.app`, or run from source:

```sh
sh scripts/run.sh
```

The launcher finds the project-local Godot editor, `godot` on PATH, or `/Applications/Godot.app`. Set `GODOT_BIN` to override. You can also import `project.godot` in Godot and press F5.

On a fresh macOS checkout:

```sh
sh scripts/bootstrap-macos.sh
sh scripts/build-macos.sh
open 'build/PRs please.app'
```

The bootstrap downloads the pinned editor and export template from Godot's official download service. Binaries and builds are ignored by Git. The app runs locally with no browser, server, external LLM, or account.

## Your shift

Each morning opens Hackerish News in the workstation browser. Read the compact front page and click into its fictional articles, then open Morgan’s memo for the day’s mechanics and newly introduced standards. BEGIN SHIFT starts the five-minute clock; morning reading is untimed. News and the memo stay available through INTRANET during work.

The assignment runs Monday through Friday, then gets extended for a second week (the top bar reads "WEEK 2 · MONDAY"). Your desk holds one PR at a time, like a border booth: the day's first lands when you BEGIN SHIFT, and each stamp brings the next one in line a few seconds later. You can't pick, skip, or count what's waiting. Request changes and the author sends back a revision (shown as "PR-2004 · v2", then v3) that rejoins the line behind the next two PRs. Authors fix only what you cited that was really broken, so anything you missed is still there, and about one revision in three fixes your point but breaks something else. A third change request makes the author escalate: Morgan hands the PR to Helios, and there is no v4. Orientation points to the relevant controls with arrows.

Standards are reissued every second morning, in two-day blocks, and the block's memo says what was added, amended, or retired. At most eight are in force at once:

| Days | In force | What changed |
| --- | --- | --- |
| 1–2 (week 1 Mon–Tue) | P01 load-bearing, P02 blue ink, P03 quiet filenames | Opening rulebook |
| 3–4 (Wed–Thu) | + P04 60 columns, P05 PIGEON sign-off, P06 no `!` in comments | Added; Helios advice opens |
| 5–6 (Fri–week 2 Mon) | + P07 no tabs, P08 no quoted “urgent” | Added; P02 amended: `INK-EXCEPTION` permits pink keywords per file |
| 7–8 (Tue–Wed) | P01–P04, P07, + P09 diff budget, P10 file cap, P11 no quoted credentials | Retired P05, P06, P08; P04 amended to 72 columns |
| 9–10 (Thu–Fri) | P02, P04, P09–P11, + P12 no `print(`, P13 tests travel with code, P14 Helios disclosure | Retired P01, P03, P07; P02 amended: permits need a ticket (`INK-EXCEPTION PCL-1234`) |

Week two's standards read like real review policy. P09 caps a PR at 30 changed lines (added plus removed, as the diffstat totals them), P10 at three files, P11 bans a quoted string assigned to a password/secret/token/api_key name, P12 bans `print(` outside `tests/`, P13 requires a `tests/` change whenever existing code is modified or renamed, and P14 requires the exact line `# generated-by: helios` in any file whose comments mention Helios. Clean PRs carry what used to be faults (tabs, shouting filenames, 61–72-column lines, an old pigeon stamp) and near misses (29 changed lines, exactly three files, a vault read, a commented-out print).

1. Read the PR's author message, review packet, and proposed source files. The packet and source scroll independently.
2. Search standards by ID, title, or text; optionally filter by category.
3. Approve compliant work with no citations. To request changes, click or select the offending line in Review (or WHOLE FILE for file standards such as filename, ink, quoted labels, and disclosure; whole-PR standards such as the diff budget, file cap, and tests accept WHOLE FILE on any changed file) then tick the standard it breaks on the citation slip in the right sidebar. Every violated rule must be cited once, at a real location, with no unrelated rules. Stamp CHANGES REQUESTED to send it. Full rule text lives on INTRANET > STANDARDS.
4. Watch Slouch for coworker reactions. How an author responds depends on how they feel about you and what you cited: they may thank you or wonder why you approved it, revise right at your desk ("give me a sec"), send a revision back through the line, push back on a citation (INSIST or WITHDRAW), abandon the PR to Helios, or loop in Morgan. At closing, Morgan messages you about incidents, delayed work, and the company’s direction; there is no correctness report.
5. At closing, open Morgan’s conversation and choose rest, dinner, or study before the next shift. Pay and living expenses settle in the simulation; the remaining queue is not disclosed.

From the first Wednesday, Helios can advise you, but its scripted recommendations may be wrong. Check the visible letters, comments, keyword colors, filenames, stamps, file list, and diffstat yourself; no programming knowledge is required. Consultation eases stress while increasing its authority. New policies arrive between shifts. The office loses human occupants as more machine terminals come online; in week two whole floors are consolidated into Helios. Morgan extends your assignment on the first Friday, and the final message on the second Friday reflects trust, stress, and AI authority.

Each workday lasts five real minutes, shown as 09:00–18:00 by the desktop clock. Time runs while reading code and messages. Use PAUSE or Esc to stop it; switching away automatically pauses until you resume. The office darkens toward evening, and at closing time Helios takes unfinished reviews. Native keyboard navigation uses Tab/Shift-Tab and Enter/Space; the code viewer is read-only and selectable. The PR on your desk is already loaded in Review; use its file selector to inspect every changed file. Click a source line to see its character count; approval and citations apply to the entire PR. SYSTEM contains save/load, confirmed new-run controls, and instructions.

Open an app from its desktop icon. Drag titlebars to arrange windows, drag any edge or corner to resize, or use the minimize, maximize, and close controls. Resizing stops at the screen boundaries and each app's usable minimum size. The taskbar tracks open apps; HOME reveals the desktop. With a titlebar focused, arrow keys move its window (Shift moves farther). Intranet opens Hackerish News, full stories, company procedures, daily memos, standards, and team chat. It is an authored local interface, not a real web browser.

Open **SLOUCH**, the company's chat app, to read coworker DMs and company messages. When a PR reaches your desk, its author messages you with a link that opens it; links to PRs that are closed or still in line just say so. Slouch is read-only: colleagues send requests and react to your approvals or change requests, then argue about revisions: Maya is tired and dry, Theo is overconfident, and Inez lives by the process. Their reactions follow your verdict and what you cited, never whether you were right. There is no reply composer. Existing saved conversations remain visible. There are no visible relationship scores, stress percentages, or authority meters. Incoming items show numbered app badges (Review shows 1 while an unread PR waits on the desk) and clickable notification bubbles at the bottom right. Messages, PRs, standards, memos, and save status each belong to their app; notifications never open windows automatically. Morgan’s evening messages communicate consequences without scores, rule answers, or payroll tables. Slouch is entirely fictional and local, with no connection to a real messaging service.

## Saves

There are three local save slots, each with its own previous-save backup. New Game opens a slot picker and immediately saves orientation; replacing an occupied slot requires confirmation. Load Game resumes the chosen slot paused. Progress is saved through System or Save and Main Menu. All slots use the same two-week campaign, rules, and five-minute clock. Only the current save format (version 11) is supported; an incompatible or damaged save requires a new game or recovery from its valid backup. There are no campaign variants or compatibility modes. Storage remains in the existing application-data location, normally `~/Library/Application Support/Godot/app_userdata/Last Review/` on macOS, so current-format saves stay available.

The bounded decision history is replayed when validating a save. Changes to scenario answers, economics, or canonical feedback require a save migration/version bump. See [simulation documentation](docs/simulation.md).

## Develop and verify

```sh
sh scripts/check.sh
sh scripts/build-macos.sh
```

The simulation suite covers the authored career, precise citations, AI mistakes, relationship and audit consequences, one-time pay, evening choices, immutability, and malformed saves. The native-interface test drives actual rule/decision controls through the campaign and manager follow-up. Menu and tutorial checks cover untimed practice, retries, lesson progress, save compatibility, and the fresh-career handoff. All run headlessly without test plugins.

- `content/` — rules, daily briefings, and `pr_bank.gd`, the bank of realistic pull requests. `policy_campaign.gd` records each packet's private recipe and regenerates revisions from it.
- `content/chat.gd`, `content/policy_chat.gd` — authored coworker messages derived from the career's decisions.
- `content/encounters.gd`, `content/encounter_lines.gd` — the encounter flow chart (mood, branches, lines). `tools/encounter_flowchart.gd` exports it to HTML.
- `native/simulation.gd` — deterministic timed shifts, the one-PR desk and its line, revisions, decisions, and life-sim consequences.
- `native/interface.gd` — review desk, rule search, people, evenings, and system controls.
- `native/desktop_window.gd` — draggable, focusable, minimizable native desktop windows.
- `native/main_menu.gd`, `native/cold_open.gd`, `native/tutorial.gd` — start/load menu, animated hiring vignette, and guided practice.
- `native/daily_reader.gd`, `content/daily_press.gd` — morning news, articles, and rule-derived daily memos.
- `native/office_scene.gd`, `art/` — rasterized SVG office scenery and animation.
- `native/portraits.gd`, `art/cats/` — pixel-art cat portraits of the cast, shown in Slouch, Review, and notifications.
- `native/computer_frame.gd` — physical monitor and animated rainy room around the desktop.
- `native/save_store.gd`, `native/main.gd` — persistence and application wiring.
- `tests/`, `scripts/`, `export_presets.cfg` — checks and native macOS packaging.

See [architecture](docs/architecture.md), [interface](docs/interface.md), [art pipeline](docs/art-pipeline.md), and [verification](docs/verification.md).

This is an authored prototype, not a finished or procedurally generated career. There is no live code execution, real repository access, multiplayer, or Windows build yet. Earlier workshop/browser prototypes remain in Git history; development continues through scoped branches/worktrees and incremental commits. Development history is hosted in the private [TravisGibbs/last-review repository](https://github.com/TravisGibbs/last-review).

The same game also runs in a desktop browser. See [browser build instructions](docs/browser.md) for the Web export and local server. Native and browser saves are separate.
