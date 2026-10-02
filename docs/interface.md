# Native computer interface

`native/interface.gd` presents the game as a first-person workstation. A large physical monitor sits within a visible rainy office, with the desk and keyboard below it. There is no exterior dashboard, office banner, resource strip, briefing strip, or game footer. The operating-system menu, application windows, and taskbar all live inside `ComputerFrame.get_screen_rect()`.

## Application boundary

Connect `command_requested(Dictionary)`, `save_requested`, `load_requested`, `reset_requested`, and `motion_changed(bool)`. Mount `native/computer_frame.gd` inside the public full-viewport `scene_host`; it retains `set_motion` and `set_story` for the parent application. The frame supplies the exact interior screen rectangle.

Call `render_state(state: Dictionary)` after state changes. After New Game reveals the interface, call `focus_workspace()` to focus the non-actionable root and settle the initial diff scroll. This never launches an application. Later calls preserve the reading position. The hidden briefing dialog remains for application-test compatibility, but no exterior briefing control is rendered.

`notify(message, is_error)` uses an in-monitor notification panel. Generation tracking prevents older timers from hiding new messages. Save serialization, disk paths, game-state transitions, and reset policy remain parent responsibilities. New-run requests require native confirmation.

## HOME and applications

HOME starts with all applications closed and four original pixel icons: REVIEW, SLOUCH, INTRANET, and SYSTEM. Single-clicking an icon launches its application. The taskbar lists only launched applications. HOME minimizes visible applications while retaining their taskbar entries; closing an application removes its entry. Reopening retains the application's data.

REVIEW holds exactly one PR, the one on the desk: there is no arrived-PR dropdown or NEXT PR button, and the next PR loads by itself a beat after each stamp. Between PRs the form reads DESK CLEAR. Revisions show as "PR-2004 · v2 / AWAITING REVIEW" with their author's own note. REVIEW combines the author packet (a paper change-request form), the read-only diff, a read-only summary of the current citations, and two rubber stamps: APPROVED and CHANGES REQUESTED. Submitting stamps the form. The PR's author sits in the top-left corner with a speech bubble; the PR itself is a one-line paper slip (title and number, no description). Citing uses the citation slip in the right sidebar, which lists every active standard: click or select a line (or WHOLE FILE) to select it as evidence (amber), then tick the standard it breaks. A ticked rule shows where it was cited; ticking it again with a different line selected moves it, and with nothing selected withdraws it. Full standards text is the INTRANET > STANDARDS page; there is no separate Handbook app. SLOUCH contains company messages and coworker DMs. INTRANET offers local home, procedure, Hackerish News headlines and full stories, and daily memo pages, and the STANDARDS rulebook, with back navigation. It is a website: it links only to its own pages, never to desktop apps such as SLOUCH or REVIEW. SYSTEM provides save/load, confirmed reset, and instructions. No browser engine, external network request, or nonfunctional chat composer is involved.

Windows cascade at useful independent sizes rather than filling fixed columns. Their black terminal chrome (red cursor block on the active window) provides minimize, maximize/restore, and close controls. The player can drag a titlebar or focus it and use arrow keys, with Shift for larger moves. Titlebar clamping keeps windows reachable. Resizing the main game window fits ordinary windows to the monitor; maximized windows follow the desktop extent.

`native/desktop_window.gd` owns dragging, focus, chrome, and application visibility. `launched` distinguishes closed apps from minimized apps. The interface consumes `activated`, `minimized`, and `closed` signals to keep taskbar state current. It preserves app positions and open state across ordinary simulation refreshes. Closing time marks Morgan’s conversation unread and minimizes REVIEW. Evening choices appear inside that conversation; no results window opens or steals focus. The initial render and orientation handoff leave HOME untouched. Real workdays explicitly open the morning reader before the clock starts.

## Review information and consequences

CodeEdit shows each changed file in full as a diff against the code already on main: added lines carry a green + and tint, removed lines a dim red − and no line number, and the gutter numbers the proposed file, which is what citations point at. Removed lines cannot be flagged. The file picker marks each file A(dded), M(odified), or R(enamed) with its own +/− counts, and a git-style diffstat line summarizes the whole PR. The author packet scrolls separately. A new PR resets its packet and code to the beginning. Rule controls are built once, then filtered by ID, title, text, category, and authored introduction day. Later shifts show a compact notice of new rules. Search, citation state, and scroll survive ordinary refreshes.

Approve requires no citations; requesting changes requires at least one. Each citation pins its rule to evidence: the player clicks a code line (amber) or WHOLE FILE and picks the rule in the flag box; cited lines stay red. Line rules (P01, P04–P07) need the exact line; whole-file rules (P02–P03, P08) accept the file or any of its lines. A right rule at the wrong place grades the review incorrect. Clear citations emits one toggle command per selected rule. Core validation remains authoritative. The active PR view never reads audit-only violations or explanation. AI advice appears only after consultation and is described as optional and fallible. Review submission confirms delivery only. Closed-shift consequences appear as authored manager messages about symptoms, delays, and handoffs, without revealing required rule IDs or technical grades.

While a PR is open, its author sits beside the paper form (`native/review_banter.gd`) and talks in a speech bubble for about 4.6 seconds per line. The lines in `content/banter.gd` (Maya: tired; Theo: "it's a one-line change"; Inez: per the meeting) react to visible actions only: opening a PR or a revision, about 12 seconds of unpaused inactivity, flagging a line, withdrawing a citation, the stamp, and asking Helios. Lines are picked deterministically from the PR id, trigger, and a counter. The banter never reads audit data, so a right flag and a wrong flag get the same words. A verdict's reaction plays before the next author's greeting, and the desk empties when no PR is open. Orientation stays quiet apart from Maya's greeting. The portrait comes from `native/portraits.gd` when that module exists, or a lettered placeholder.

No trust, stress, automation, relationship, or final-score meters are displayed. Coworker feelings and story consequences are expressed through messages and prose. Pay and expenses remain internal; no payroll table is shown. PR IDs, rule IDs, code line numbers, and technical quantities remain where the review task needs them. Queue totals and campaign denominators remain concealed.

## Slouch behavior

`content/chat.gd` supplies `messages(state, contact)` for company, Maya, Theo, Inez, and manager Morgan. Slouch renders authored author/text rows; it does not derive hints from hidden audit answers. Incoming messages never open, raise, or switch the app. The selected conversation remains under player control. Unread counts appear on conversations, red circular desktop-icon badges, and taskbar entries. Opening a conversation clears only its messages; the player’s own replies never increase the count.

Every message from someone else carries a 32-pixel cat portrait left of its bubble (`native/portraits.gd`); the player's own messages have none, and a faceless sender such as Operations keeps the same indent. The DM buttons show each coworker's portrait, and a Slouch ticker card from a person shows their face beside the text.

The portraits are alive: each cat blinks, plays a small personality idle, perks up under the cursor (a pointing hand), and flinches when clicked. A click never stops at the face, so the ticker card or row underneath still gets it. In Slouch a click only plays the reaction. In Review the seated author's mouth flaps while their bubble shows, and clicking them gets a `poke` line from `content/banter.gd`. Orientation stays quiet, and a goodbye already underway plays out. The DM button icons stay still. See `docs/art-pipeline.md` for the frames and timing.

Opening a conversation clears its dot. New messages follow the bottom only when the player was reading the latest content; otherwise the previous scroll position is retained. Contact changes settle at the latest messages after native layout. The message viewport uses `SCROLL_MODE_SHOW_NEVER` horizontally so a hidden paragraph's temporary unwrapped width cannot inflate the floating window on first open.

## Verification

The native interface suite covers HOME-only startup, actual icon launch signals, taskbar launch/minimize/close lifecycle, both supported resolutions, dominant monitor sizing, dragging and keyboard movement, focus ordering, menu handoff, local-browser navigation, and the complete authored review flow. Slouch checks reproduce hidden workstation → reveal → first open without an arrangement reset, including loaded progress and repeated contact changes; they assert bounded window width and wrapped long messages.

The packaged native office view was inspected with REVIEW and INTRANET open after pulling the monitor back. At a 1280×900 logical viewport, the monitor screen is 1080×664; application windows fit the available desktop, and HOME icons wrap to a second column when needed. The rainy city window, sill, desk, keyboard, and shaded mug remain visible around the enclosure. Bundled OFL-licensed IBM Plex Mono gives consistent local typography; code remains 14px and general text 15px. No remote fonts are required.

Windows resize from all eight edges/corners with directional cursor feedback. Minimum sizes are tailored to each app; content scrolls when needed. Dragged edges stop at the desktop boundary, maximize disables resize handles, and restore retains the last user-sized rectangle.

The top-right desktop clock maps each five-minute shift to 09:00–18:00. PAUSE/Esc covers the desktop and stops game time; switching away pauses until an explicit resume. Rain and office lighting follow the day without driving simulation time. When a PR reaches the desk, its author's Slouch message carries an OPEN link; it opens only the PR on the desk. A link to a PR still in line says it isn't at your desk yet, and a link to a stamped or handed-off PR says it is closed. Slouch is read-only; coworkers send PR links, review reactions, and the revision exchange: a reaction to each change request, a v2 or v3 note when the revision lands, relief when it's approved, and an escalation ("I'm looping in Morgan.") on a third change request, with Morgan's follow-up in the manager DM. Older saved questions and answers remain visible, but no new replies can be sent.

Review's changed-file selector displays each file's own diff and remembers its caret/scroll position while switching. The first three PRs split callers from imported helpers. Citations and disposition apply to the whole PR.

## Main menu and orientation

Startup displays New Game and Load Game inside the monitor. Load is disabled when neither a current save nor its backup exists. New Game opens directly into an untimed orientation with a compact, collapsible instruction panel. Players ask Maya a question, follow her PR link, inspect both changed files, consult the handbook, and submit a practice change request. Mistakes can be retried; practice is discarded before Monday.

SYSTEM and the pause screen offer SAVE AND MAIN MENU. Loading resumes paused, including the current orientation step when applicable. Morgan’s final conversation offers a return to the menu.

## Desktop notifications

Every app has a notification source: the PR waiting on the desk for REVIEW (a badge of 1 until Review is looked at), team messages for SLOUCH, newly introduced standards and daily memos for INTRANET, and save/load or local status for SYSTEM. Only arrived, unread items are counted; badges never reveal the line behind the desk. Counts and read presentation remain session-local.

`native/desktop_notifications.gd` keeps up to three clickable notifications as a one-line ticker inside the bottom-right of the taskbar, showing the newest; they never cover application windows. They coalesce by app and target, expire after nine seconds, and wait while paused or hovered. Clicking opens the corresponding PR, conversation, memo, or app. Dismissing a bubble leaves its unread badge intact. Notifications do not steal focus.

Player messages align right in a blue bubble; coworkers align left. Newly sent questions show a typing indicator for 2.4 active seconds, with further response choices hidden until the answer arrives. Pending answers do not enter unread counts early; pause freezes delivery. Saved conversation history is immediately available after loading.

Coworkers begin with a single introduction. Neutral filler greetings are omitted; separate relationship messages appear only for warm or strained relationships. Conversation headers show the person or channel without storage or internal-system labels.

Slouch bubbles show weekday and office-clock send time. Histories sort by saved day/time, then command-journal sequence, before clipping to the history limit. PR links keep the time the PR reached the desk; asking about an older PR appends the exchange chronologically. Questions and delayed answers share a send minute with a stable pair order, including untimed training. Stable message IDs prevent clock refreshes from producing new unread notifications. Existing saves derive this metadata without a schema change.


## Cold open and morning reading

New Game runs the laptop-only cold open before orientation. Load Game bypasses it. The vignette owns only presentation: rejection emails, a new Paperclip Labs offer, and a player-controlled inbox with clickable emails and signature; it never submits a simulation action or moves the OS pointer. Skip completes the same guarded handoff as normal playback.

At the start of each career day, INTRANET opens Hackerish News with three authored, clickable stories. Its paper-colored article pages and compact masthead share the real draggable browser window. The morning action opens Morgan's memo, which describes the day's mechanics and renders exactly the rules introduced that day from Catalog. BEGIN SHIFT releases the clock and minimizes the reader. Closing/minimizing the window alone cannot start time; reopen INTRANET and its daily memo. During work the same pages remain readable without changing the clock. Headlines cannot resolve stories from a future day.

Morning state is presentation-only. A saved career at 09:00 reopens the morning reader; a midshift load resumes paused without replaying the cold open or news. All slots use the current campaign and save format.

The morning desktop bar exposes **Begin Shift** next to 09:00, enabled after opening the daily memo. It stays outside application windows and restores Pause when work begins.

Hackerish News uses original fictional launch posts, personal write-ups, and technical arguments. Tone references consulted: [HN front page](https://news.ycombinator.com/), [platform-team discussion](https://news.ycombinator.com/item?id=49878857), and [Show HN discussion](https://news.ycombinator.com/item?id=49891769). No live headlines or comments are imported into the game.

New Game and Load Game open a three-slot chooser. Slot 1 reads the original save path for compatibility. Creating a run immediately saves its orientation state; subsequent saves target that active slot. Occupied-slot replacement is confirmed in the menu, and each slot retains its own backup. System shows the current slot; New Run saves current progress before returning to the chooser.
