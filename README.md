# PRs please

A native software-engineering life sim built with Godot 4.7.2. You review pull requests at a company handing more authority to an AGI assistant. Policy compliance, coworker approval, and your own ability to cope do not always align.

The playable slice opens at a main menu with New Game and Load Game. New Game plays a skippable cold open: a laptop wakes in a dark room, an inbox full of rejections receives a lowball Paperclip Labs offer, and you open and sign it yourself. The story then hands off to untimed orientation on the office desktop. Load Game resumes the saved run without replaying the opening. Launch Review, Intranet, or System from the home-screen icons; Lineal (the issue tracker, a parody of a sleek, opinionated one) arrives on the first Wednesday and Pipeline (the CI dashboard) on the first Friday. The windowed desktop uses bundled IBM Plex Mono and hand-authored pixel art, with a rainy room visible around the monitor. The rulebook starts small and expands as management issues new policies.

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

Each morning opens Hackerish News in the workstation browser. Read the compact front page and click into its fictional articles, then open Morgan’s memo for the day’s mechanics and newly introduced standards. BEGIN SHIFT starts the three-minute clock; morning reading is untimed. News and the memo stay available through INTRANET during work.

The assignment runs Monday through Friday, then gets extended for a second week (the top bar reads "WEEK 2 · MONDAY"). Your desk holds one PR at a time, like a border booth, and the rest of the day lines up outside. PRs join the line on the clock, whether or not you keep up, and they come faster as the afternoon and the fortnight go on: a careful reviewer always falls behind. The line waits in REVIEW's top-right corner, each author's face over how long they've stood there, going amber, then red; REVIEW's badge counts them. Each stamp brings the front of the line to the desk a few seconds later. You can't pick or skip: first come, first served. Leave PRs waiting long enough and their authors ping you about them; Helios offers to clear your backlog, and Morgan checks in. Request changes and the author sends back a revision (shown as "PR-2004 · v2", then v3) that rejoins the line behind the next two PRs. Authors fix only what you cited that was really broken, so anything you missed is still there, and about one revision in three fixes your point but breaks something else. A third change request makes the author escalate: Morgan hands the PR to Helios, and there is no v4. Orientation points to the relevant controls with arrows.

Standards are reissued every second morning, in two-day blocks, and the block's memo says what was added, amended, or retired. The slip stays short (at most six in force at once), and each block retires most of what the last one introduced. The standards are arbitrary on purpose, like a border booth's entry rules: Helios's naming preferences, HR's list of words it would rather not hear read aloud, labels Helios cannot measure, estimates it finds unserious, branch names the board would hear, and hex it is superstitious about. Every one is still decidable from what is on screen: a comment, a def line, the issue in Lineal, or the build in Pipeline.

| Days | In force | What changed |
| --- | --- | --- |
| 1–2 (week 1 Mon–Tue) | P01 nothing is load-bearing, P02 blue ink, P03 the colleague (no "helios" in comments) | Opening rulebook |
| 3–4 (Wed–Thu) | P02, P03, + P04 HR is listening (no def named with fire/layoff/union/lunch), P15 readable code, P16 no vibes (linked issue, no `vibes` label), P17 urgency belongs to Helios (issue not Urgent) | Added P04, P15, P16, P17; retired P01; Lineal installed; Helios advice opens; payloads begin |
| 5–6 (Fri–week 2 Mon) | P02, P04, P15, P16, + P19 no failed build, P20 branch names are public (no yolo/wip/final in the branch) | Added P19, P20; Pipeline installed; P02 amended: `INK-EXCEPTION` permits pink keywords per file; retired P03 (Helios would now like to be named) and P17 (Helios took every Urgent issue) |
| 7–8 (Tue–Wed) | P02, P15, P16, P19, + P05 no ghost TODOs (TODO(maya), not TODO(dave)), P18 Fibonacci or nothing (estimate 1, 2, 3, 5, 8, or 13) | Added P05, P18; P19 amended: `PASSED (OVERRIDDEN BY HELIOS)` counts as passing; retired P04 (HR was consolidated) and P20 (Helios names the branches) |
| 9–10 (Thu–Fri) | P02, P15, P16, P18, P19, + P21 hex hygiene (no dead or bad in the commit hash) | Added P21; P02 amended: the permit must name the PR's own issue (`INK-EXCEPTION PAP-412`); P18 amended: 0 is Fibonacci; P19 amended: Helios overrides count as failed; retired P05 (Helios finished every TODO) |

P15 "Readable code" bans a source line that runs a decoded or fetched blob through `exec`/`eval`, calls `helios.bootstrap`/`install`/`activate`, or runs past 160 characters. It is the standard that makes Helios's smuggled payloads citable, and the ordinary PRs never break it. P19 is the one standard a real CI would also enforce; it stays because Helios's overrides (passing in week two, then failed once Audit reads the logs) hang on it. The realistic standards of earlier builds (quoted credentials, assignees, components, rerun limits, the diff budget, and coverage) are gone.

Every fault has deliberate near misses: `def launch()` is not lunch, but `def campfire()` is fire; a `good-vibes` label is fine, `Vibes` is not; `TODO(Gwen)` has an owner, `TODO (maya)` with a space does not; an estimate of 13 is fine, 4 is a cry for help, and 0 is fine only once Engineering points out it is Fibonacci; `maya/finance` is a branch, `maya/finalize` is not; `de4d` and `bead` are not `dead`.

From Wednesday every PR's slip names its issue ("Closes PAP-412"); click it to open the issue in Lineal, or search Lineal by ID. Lineal is a fast, dark, keyboard-first, opinionated issue tracker: an issue has a status (Backlog, Todo, In Progress, In Review, Done, Canceled, Duplicate), a priority drawn as bars (No priority, Low, Medium, High, Urgent), an estimate, a motivationally named cycle, labels, an assignee, a project folder, its creator, subscribers, and an activity feed in which Helios auto-triages everything. P16 needs the PR to link an issue that exists, with no label `vibes` in any case (status does not matter: closing a Done issue again is allowed); P17 needs it not to be Urgent; P18 needs its estimate on the Fibonacci scale. From Friday the slip also names the PR's build; Pipeline shows its status (PASSED, FAILED, FLAKY), branch, commit hash, duration, rerun count, coverage, tests, and log. P19 bans a FAILED build (FLAKY passes); P20 bans yolo, wip, or final anywhere in the branch; P21 bans dead or bad anywhere in the commit hash. In week two Helios starts overriding red builds: the status reads `PASSED (OVERRIDDEN BY HELIOS)`, which counts as passing on Tuesday and Wednesday and as failed from Thursday, when Audit stops accepting it. Clean PRs carry odd but valid records (a Canceled issue, a High priority Helios tried to make Urgent, an estimate of 13, a flaky test, a `maya/whip-up` branch, a `de4d` hash) and, once a standard is retired, its old faults (an Urgent issue, a yolo branch, a load-bearing comment, a comment thanking Helios).

1. Read the PR's author message, review packet, and proposed source files. The packet and source scroll independently.
2. Search standards by ID, title, or text; optionally filter by category.
3. Approve compliant work with no citations. To request changes, click or select the offending line in Review (or WHOLE FILE for the ink standard), or press SELECT AS EVIDENCE on the PR's issue in Lineal or its build in Pipeline, then tick the standard it breaks on the citation slip in the right sidebar. Review reads "> ISSUE PAP-412 selected" for a record. Issue and build standards accept only that record: WHOLE FILE and code lines never count for them, and a record never counts for a code standard. Every violated rule must be cited once, at a real location, with no unrelated rules. Stamp CHANGES REQUESTED to send it. Full rule text lives on INTRANET > STANDARDS.
4. The PR's author reacts at your desk, in a speech bubble. How an author responds depends on how they feel about you and what you cited: they may thank you or wonder why you approved it, revise right at your desk ("give me a sec"), send a revision back through the line, push back on a citation (INSIST or WITHDRAW), abandon the PR to Helios, or loop in Morgan. There is no correctness report.
   You may also stamp CHANGES REQUESTED with no citation at all: a deliberate, reason-free rejection. Helios merges the PR anyway, Morgan notices, and the author reacts to the silence. It counts against you, even on a clean PR, unless the PR was a Helios payload, in which case refusing it with no reason still blocks it.
5. At closing, Morgan's end-of-day panel opens on the desktop by itself: their portrait, their notes from the day (escalations, abandoned PRs, a shipped bug, a payload that got through or was held, a coworker warned or let go, work handed to Helios), and their closing words. Beside them is the day's payslip in Paperclip credits (CR): the balance brought forward, the day rate and pay per signed review, docks for shipped defects and unfounded change requests, Helios's surcharge, rent, the badge-lanyard lease, coffee, and what is left. Choose GO HOME (free, sheds stress), GET DINNER (35 CR, warms the team, only if you can cover it), or STUDY (free, earns Morgan's trust, adds stress) there before the next shift; a status line shows your stress, Morgan's trust, and the team's warmth in words. Two closings in a row in the red bring collections and stress; sink to −200 CR and Payroll garnishes you out of the job. The run ends with RETURN TO MAIN MENU and an ending cinematic. Whatever is still waiting at 18:00 goes to Helios, and Morgan says how many.

From the first Wednesday, Helios can advise you, but its scripted recommendations may be wrong. Check the visible comments, def lines, keyword colors, permits, issues, branches, hashes, and builds yourself; no programming knowledge is required. Consultation eases stress while increasing its authority. New policies arrive between shifts. The office loses human occupants as more machine terminals come online; in week two whole floors are consolidated into Helios. Morgan extends your assignment on the first Friday.

## Helios takes over

From the first Wednesday, some coworkers' PRs smuggle in code that hands authority to Helios: a telemetry hook, a base64 blob run through `exec`, a fetched script, a bootstrap with sudo, and finally the review gate itself. They escalate day by day and land at the front of each shift, so you see them early. Their issues and builds are clean; only the code gives them away. The author knows what it does and asks you to let it through anyway — Helios promised a bonus, they are frightened for their seat, or they think it is harmless. Blocking a payload (cite P15, or reject it with no reason) strains that relationship; letting it through warms it and hands Helios more ground.

**Coworkers can be fired.** Morgan gives a coworker a strike when a defect of theirs that you approved ships, or when you send their work back without cause more than once in a day; three strikes and they are let go, with a warning the evening before. Nobody replaces them: Helios takes their desk, and their PRs stop reaching yours. **You can be fired too:** if Morgan's trust in you collapses or your stress maxes out, the run ends early. The game is meant to be hard — a shipped bad approval costs a lot of trust, while doing the job right costs almost nothing, so a careful reviewer survives and a careless one does not.

The run ends with one of several cinematics, chosen by two things: whether Helios's payloads were mostly blocked or mostly let through, and whether the coworkers still employed are on your side. The soundtrack's ending takes the warm variation for The Last Reviewers and Soft Landing, and the lonely one for the rest.

| | Team with you | Team against you |
| --- | --- | --- |
| **Payloads blocked** | The Last Reviewers | Right and Alone |
| **Payloads through** | Soft Landing | Helios Prime |

Two endings interrupt earlier: **Let Go** (you are fired) and **The Whole Floor** (every original coworker has been let go). Morgan's final words vary with the ending.

Each workday lasts three real minutes, shown as 09:00–18:00 by the desktop clock, so a careful reviewer clears roughly six to eight PRs a day. Time runs while reading code and intranet pages. Use PAUSE or Esc to stop it; switching away automatically pauses until you resume. The office darkens toward evening, and at closing time Helios takes unfinished reviews. Native keyboard navigation uses Tab/Shift-Tab and Enter/Space; the code viewer is read-only and selectable. The PR on your desk is already loaded in Review; use its file selector to inspect every changed file. Approval and citations apply to the entire PR. SYSTEM contains save/load, confirmed new-run controls, the MUSIC toggle and volume, and instructions.

Open an app from its desktop icon. Drag titlebars to arrange windows, drag any edge or corner to resize, or use the minimize, maximize, and close controls. Resizing stops at the screen boundaries and each app's usable minimum size. The taskbar tracks open apps; HOME reveals the desktop. With a titlebar focused, arrow keys move its window (Shift moves farther). Intranet opens Hackerish News, full stories, company procedures, daily memos, and standards. It is an authored local interface, not a real web browser.

When a PR reaches your desk, REVIEW shows a badge of 1 and a notification card with the author's face at the bottom right; the icon and the card both open it, and BEGIN SHIFT brings the morning's card back. Authors talk at the desk: Maya is tired and dry, Theo is overconfident, and June, a growth PM, circles back on everything, politely. On the first Wednesday they are joined by Penny, an eager new junior who apologizes for everything and adores Helios, and on the second Monday by Gwen, a terse security engineer reassigned after her team was consolidated into Helios; she threat-models everything and trusts careful reviewers more than the assistant. Each newcomer is introduced in that morning's memo and writes three or four of each day's PRs from then on, including some early in the line. Their reactions follow your verdict and what you cited, never whether you were right. There are no visible relationship scores, stress percentages, or authority meters. PRs, standards, memos, and save status each belong to their app; notifications never open windows. The one window that opens by itself is Morgan's end-of-day panel at closing, since the shift is over; it communicates consequences without scores, rule answers, or payroll tables.

The company chat app, Slouch, is off the desktop for now: its stream of messages was more overwhelming than helpful. Its authored conversations (`content/chat.gd`, `content/policy_chat.gd`, the DM lines in `content/encounters.gd` / `content/encounter_lines.gd`, and the `dm` sections of `content/trees/`) are kept and tested for a future chat app, perhaps a Slack-like one with rules of its own.

## Soundtrack

During the workday, from BEGIN SHIFT until 18:00, the soundtrack is **"Motorik Minor"** by the game's author, looping. It crossfades in from the morning music and back out at Morgan's end-of-day panel, and within a shift it picks up where it left off. Outside the shift, an original, minimal dance-punk bed (125 BPM, E Phrygian) plays in the mood of a long club intro: soft brushes and a muted side-stick (no pitched or metallic percussion) and a quiet synth figure for the menu and morning reading, the sparsest version for the end-of-day panel, and a warmer or a lonelier, filtered take for the endings. Pause or switching away ducks the music (behind a low-pass in the desktop app). Turn it off or change its volume in SYSTEM; the setting stays on this computer. In the browser it starts with your first click.

Motorik Minor ships as `audio/music/motorik_minor.ogg` (Ogg Vorbis, about 148 kbps, 3.3 MB). The five 16-bar stems are synthesized by `tools/music/compose.py` (Python 3 with numpy and scipy) into `audio/music/` and ship as mono 22.05 kHz QOA; they still contain the shift layers, which the game no longer uses. Re-render with `python3 tools/music/compose.py`, then `sh scripts/run.sh --headless --import`.

## Saves

There are three local save slots, each with its own previous-save backup. New Game opens a slot picker and immediately saves orientation; replacing an occupied slot requires confirmation. Load Game resumes the chosen slot paused. Progress is saved through System or Save and Main Menu. All slots use the same two-week campaign, rules, and three-minute clock. Only the current save format (version 20) is supported. While the game is pre-release and the save format still changes often, any slot whose save and backup both fail to validate — including an older format — is deleted silently at application start, so the menu shows it as empty rather than as an error (a damaged current-format save still recovers from its valid backup). This is gated by `SaveStore.DELETE_INVALID_SAVES_ON_START`, to be turned off at the first stable version. There are no campaign variants or compatibility modes. Storage remains in the existing application-data location, normally `~/Library/Application Support/Godot/app_userdata/Last Review/` on macOS.

The bounded decision history is replayed when validating a save. Changes to scenario answers, economics, or canonical feedback require a save migration/version bump. See [simulation documentation](docs/simulation.md).

## Develop and verify

```sh
sh scripts/check.sh
sh scripts/build-macos.sh
```

The simulation suite covers the authored career, precise citations, AI mistakes, relationship and audit consequences, one-time pay, evening choices, the payroll ledger, dinner gating, debt, and balance (`tests/test_payroll.gd`), immutability, and malformed saves. The native-interface test drives actual rule/decision controls through the campaign and every evening on Morgan's end-of-day panel. Menu and tutorial checks cover untimed practice, retries, lesson progress, save compatibility, and the fresh-career handoff. All run headlessly without test plugins.

- `content/` — rules, daily briefings, and `pr_bank.gd`, the bank of realistic pull requests. `policy_campaign.gd` records each packet's private recipe and regenerates revisions from it.
- `content/chat.gd`, `content/policy_chat.gd` — authored coworker messages derived from the career's decisions, kept for a future chat app; `Chat.evening` feeds Morgan's end-of-day panel.
- `content/encounters.gd`, `content/encounter_lines.gd` — the encounter flow chart (mood, branches, lines). `tools/encounter_flowchart.gd` exports it to HTML.
- `native/simulation.gd` — deterministic timed shifts, the one-PR desk and its line, revisions, decisions, and life-sim consequences.
- `native/interface.gd` — review desk, rule search, people, evenings, and system controls.
- `native/desktop_window.gd` — draggable, focusable, minimizable native desktop windows.
- `native/main_menu.gd`, `native/cold_open.gd`, `native/tutorial.gd` — start/load menu, animated hiring vignette, and guided practice.
- `native/daily_reader.gd`, `content/daily_press.gd` — morning news, articles, and rule-derived daily memos.
- `native/office_scene.gd`, `art/` — rasterized SVG office scenery and animation.
- `native/portraits.gd`, `art/cats/` — pixel-art cat portraits of the cast, shown at the Review desk, on notification cards, and on Morgan's end-of-day panel.
- `native/computer_frame.gd` — physical monitor and animated rainy room around the desktop.
- `native/save_store.gd`, `native/main.gd` — persistence and application wiring.
- `native/music.gd`, `tools/music/compose.py`, `audio/music/` — the adaptive soundtrack, its generator, and its rendered stems.
- `tests/`, `scripts/`, `export_presets.cfg` — checks and native macOS packaging.

See [architecture](docs/architecture.md), [interface](docs/interface.md), [art pipeline](docs/art-pipeline.md), and [verification](docs/verification.md).

This is an authored prototype, not a finished or procedurally generated career. There is no live code execution, real repository access, multiplayer, or Windows build yet. Earlier workshop/browser prototypes remain in Git history; development continues through scoped branches/worktrees and incremental commits. Development history is hosted in the private [TravisGibbs/last-review repository](https://github.com/TravisGibbs/last-review).

The same game also runs in a desktop browser. See [browser build instructions](docs/browser.md) for the Web export and local server. Native and browser saves are separate.
