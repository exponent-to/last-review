# Native computer interface

`native/interface.gd` presents the game as a first-person workstation. A large physical monitor sits within a visible rainy office, with the desk and keyboard below it. There is no exterior dashboard, office banner, resource strip, briefing strip, or game footer. The operating-system menu, application windows, and taskbar all live inside `ComputerFrame.get_screen_rect()`.

## Application boundary

Connect `command_requested(Dictionary)`, `save_requested`, `load_requested`, `reset_requested`, and `motion_changed(bool)`. Mount `native/computer_frame.gd` inside the public full-viewport `scene_host`; it retains `set_motion` and `set_story` for the parent application. The frame supplies the exact interior screen rectangle.

Call `render_state(state: Dictionary)` after state changes. After New Game reveals the interface, call `focus_workspace()` to focus the non-actionable root and settle the initial diff scroll. This never launches an application. Later calls preserve the reading position. The hidden briefing dialog remains for application-test compatibility, but no exterior briefing control is rendered.

`notify(message, is_error)` uses an in-monitor notification panel. Generation tracking prevents older timers from hiding new messages. Save serialization, disk paths, game-state transitions, and reset policy remain parent responsibilities. New-run requests require native confirmation.

## HOME and applications

HOME starts with all applications closed and five original pixel icons: REVIEW, HANDBOOK, SLOUCH, INTRANET, and SYSTEM. Single-clicking an icon launches its application. The taskbar lists only launched applications. HOME minimizes visible applications while retaining their taskbar entries; closing an application removes its entry. Reopening retains the application's data.

REVIEW combines the current author packet and read-only diff with the sign-off controls and a delivery confirmation. HANDBOOK is an independent searchable standards window. SLOUCH contains company messages and coworker DMs. INTRANET offers local home, procedure, Hackerish News headlines and full stories, and daily memo pages, including back navigation and links to other apps. SYSTEM provides save/load, confirmed reset, and instructions. No browser engine, external network request, or nonfunctional chat composer is involved.

Windows cascade at useful independent sizes rather than filling fixed columns. Their classic gray and blue chrome provides minimize, maximize/restore, and close controls. The player can drag a titlebar or focus it and use arrow keys, with Shift for larger moves. Titlebar clamping keeps windows reachable. Resizing the main game window fits ordinary windows to the monitor; maximized windows follow the desktop extent.

`native/desktop_window.gd` owns dragging, focus, chrome, and application visibility. `launched` distinguishes closed apps from minimized apps. The interface consumes `activated`, `minimized`, and `closed` signals to keep taskbar state current. It preserves app positions and open state across ordinary simulation refreshes. Closing time marks Morgan’s conversation unread and minimizes REVIEW. Evening choices appear inside that conversation; no results window opens or steals focus. The initial render and orientation handoff leave HOME untouched. Real workdays explicitly open the morning reader before the clock starts.

## Review information and consequences

CodeEdit provides selectable code, line numbers, independent scrolling, and native diff colors. The author packet scrolls separately. A new PR resets its packet and code to the beginning. Rule controls are built once, then filtered by ID, title, text, category, and authored introduction day. Later shifts show a compact notice of new rules. Search, citation state, and scroll survive ordinary refreshes.

Approve requires no citations; requesting changes requires at least one. Clear citations emits one toggle command per selected rule. Core validation remains authoritative. The active PR view never reads audit-only violations or explanation. AI advice appears only after consultation and is described as optional and fallible. Review submission confirms delivery only. Closed-shift consequences appear as authored manager messages about symptoms, delays, and handoffs, without revealing required rule IDs or technical grades.

No trust, stress, automation, relationship, or final-score meters are displayed. Coworker feelings and story consequences are expressed through messages and prose. Pay and expenses remain internal; no payroll table is shown. PR IDs, rule IDs, code line numbers, and technical quantities remain where the review task needs them. Queue totals and campaign denominators remain concealed.

## Slouch behavior

`content/chat.gd` supplies `messages(state, contact)` for company, Maya, Theo, Inez, and manager Morgan. Slouch renders authored author/text rows; it does not derive hints from hidden audit answers. Incoming messages never open, raise, or switch the app. The selected conversation remains under player control. Unread counts appear on conversations, red circular desktop-icon badges, and taskbar entries. Opening a conversation clears only its messages; the player’s own replies never increase the count.

Opening a conversation clears its dot. New messages follow the bottom only when the player was reading the latest content; otherwise the previous scroll position is retained. Contact changes settle at the latest messages after native layout. The message viewport uses `SCROLL_MODE_SHOW_NEVER` horizontally so a hidden paragraph's temporary unwrapped width cannot inflate the floating window on first open.

## Verification

The native interface suite covers HOME-only startup, actual icon launch signals, taskbar launch/minimize/close lifecycle, both supported resolutions, dominant monitor sizing, dragging and keyboard movement, focus ordering, menu handoff, local-browser navigation, and the complete authored review flow. Slouch checks reproduce hidden workstation → reveal → first open without an arrangement reset, including loaded progress and repeated contact changes; they assert bounded window width and wrapped long messages.

The packaged native office view was inspected with REVIEW and HANDBOOK open after pulling the monitor back. At a 1280×900 logical viewport, the monitor screen is 1040×630; application windows fit the available desktop, and HOME icons wrap to a second column when needed. The rainy city window, sill, desk, keyboard, and shaded mug remain visible around the enclosure. Bundled OFL-licensed IBM Plex Mono gives consistent local typography; code remains 14px and general text 15px. No remote fonts are required.

Windows resize from all eight edges/corners with directional cursor feedback. Minimum sizes are tailored to each app; content scrolls when needed. Dragged edges stop at the desktop boundary, maximize disables resize handles, and restore retains the last user-sized rectangle.

The top-right desktop clock maps each six-minute shift to 09:00–18:00. PAUSE/Esc covers the desktop and stops game time; switching away pauses until an explicit resume. Rain and office lighting follow the day without driving simulation time. Incoming PRs appear as Slouch links, and Review stays empty until a link is selected. Slouch has a per-PR question target and authored reply choices; asked questions and answers survive saving.

Review's changed-file selector displays each file's own diff and remembers its caret/scroll position while switching. The first three PRs split callers from imported helpers. Citations and disposition apply to the whole PR.

## Main menu and orientation

Startup displays New Game and Load Game inside the monitor. Load is disabled when neither a current save nor its backup exists. New Game opens directly into an untimed orientation with a compact, collapsible instruction panel. Players ask Maya a question, follow her PR link, inspect both changed files, consult the handbook, and submit a practice change request. Mistakes can be retried; practice is discarded before Monday.

SYSTEM and the pause screen offer SAVE AND MAIN MENU. Loading resumes paused, including the current orientation step when applicable. Morgan’s final conversation offers a return to the menu.

## Desktop notifications

Every app has a notification source: arrived PRs for REVIEW, team messages for SLOUCH, newly introduced standards for HANDBOOK, daily memos for INTRANET, and save/load or local status for SYSTEM. Only arrived, unread items are counted; badges never reveal future work. Counts and read presentation remain session-local.

`native/desktop_notifications.gd` stacks up to three clickable bubbles above the bottom-right taskbar. They coalesce by app and target, expire after nine seconds, and wait while paused or hovered. Clicking opens the corresponding PR, conversation, memo, or app. Dismissing a bubble leaves its unread badge intact. Notifications do not steal focus.

Player messages align right in a blue bubble; coworkers align left. Newly sent questions show a typing indicator for 2.4 active seconds, with further response choices hidden until the answer arrives. Pending answers do not enter unread counts early; pause freezes delivery. Saved conversation history is immediately available after loading.

Coworkers begin with a single introduction. Neutral filler greetings are omitted; separate relationship messages appear only for warm or strained relationships. Conversation headers show the person or channel without storage or internal-system labels.

Slouch bubbles show weekday and office-clock send time. Histories sort by saved day/time, then command-journal sequence, before clipping to the history limit. PR links retain scheduled arrival time; asking about an older PR appends the exchange chronologically. Questions and delayed answers share a send minute with a stable pair order, including untimed training. Stable message IDs prevent clock refreshes from producing new unread notifications. Existing saves derive this metadata without a schema change.


## Cold open and morning reading

New Game runs the laptop-only cold open before orientation. Load Game bypasses it. The vignette owns only presentation: rejection emails, a new Northstar offer, and a player-controlled inbox with clickable emails and signature; it never submits a simulation action or moves the OS pointer. Skip completes the same guarded handoff as normal playback.

At the start of each career day, INTRANET opens Hackerish News with three authored, clickable stories. Its paper-colored article pages and compact masthead share the real draggable browser window. The morning action opens Morgan's memo, which describes the day's mechanics and renders exactly the rules introduced that day from Catalog. BEGIN SHIFT releases the clock and minimizes the reader. Closing/minimizing the window alone cannot start time; reopen INTRANET and its daily memo. During work the same pages remain readable without changing the clock. Headlines cannot resolve stories from a future day.

Morning state is presentation-only. A saved career at 09:00 reopens the morning reader; a midshift load resumes paused without replaying the cold open or news. The existing v4 save schema stays compatible.
