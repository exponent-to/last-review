# Native computer interface

`native/interface.gd` presents the game as a first-person workstation. The physical monitor occupies almost the entire viewport; only narrow room and rain edges remain visible. There is no exterior dashboard, office banner, resource strip, briefing strip, or game footer. The operating-system menu, application windows, and taskbar all live inside `ComputerFrame.get_screen_rect()`.

## Application boundary

Connect `command_requested(Dictionary)`, `save_requested`, `load_requested`, `reset_requested`, and `motion_changed(bool)`. Mount `native/computer_frame.gd` inside the public full-viewport `scene_host`; it retains `set_motion` and `set_story` for the parent application. The frame supplies the exact interior screen rectangle.

Call `render_state(state: Dictionary)` after state changes. After an intro reveals the interface, call `focus_workspace()` to focus the non-actionable root and settle the initial diff scroll. This never launches an application. Later calls preserve the reading position. The hidden briefing dialog remains for application-test compatibility, but no exterior briefing control is rendered.

`notify(message, is_error)` uses an in-monitor notification panel. Generation tracking prevents older timers from hiding new messages. Save serialization, disk paths, game-state transitions, and reset policy remain parent responsibilities. New-run requests require native confirmation.

## HOME and applications

HOME starts with all applications closed and five original pixel icons: REVIEW, HANDBOOK, SLOUCH, INTRANET, and SYSTEM. Single-clicking an icon launches its application. The taskbar lists only launched applications. HOME minimizes visible applications while retaining their taskbar entries; closing an application removes its entry. Reopening retains the application's data.

REVIEW combines the current author packet and read-only diff with the sign-off controls and previous audit. HANDBOOK is an independent searchable standards window. SLOUCH contains company messages and coworker DMs. INTRANET offers local home, procedure, and daily memo pages, including back navigation and links to other apps. SYSTEM provides save/load, confirmed reset, motion settings, and instructions. No browser engine, external network request, or nonfunctional chat composer is involved.

Windows cascade at useful independent sizes rather than filling fixed columns. Their classic gray and blue chrome provides minimize, maximize/restore, and close controls. The player can drag a titlebar or focus it and use arrow keys, with Shift for larger moves. Titlebar clamping keeps windows reachable. ARRANGE restores default positions. Resizing the main game window fits ordinary windows to the monitor; maximized windows follow the desktop extent.

`native/desktop_window.gd` owns dragging, focus, chrome, and application visibility. `launched` distinguishes closed apps from minimized apps. The interface consumes `activated`, `minimized`, and `closed` signals to keep taskbar state current. It preserves app positions and open state across ordinary simulation refreshes. A submitted final review opens the shift record; choosing an evening option returns to REVIEW. The initial render and intro handoff always leave HOME untouched.

## Review information and consequences

CodeEdit provides selectable code, line numbers, independent scrolling, and native diff colors. The author packet scrolls separately. A new PR resets its packet and code to the beginning. Rule controls are built once, then filtered by ID, title, text, category, and authored introduction day. Later shifts show a compact notice of new rules. Search, citation state, and scroll survive ordinary refreshes.

Approve requires no citations; requesting changes requires at least one. Clear citations emits one toggle command per selected rule. Core validation remains authoritative. The active PR view never reads audit-only violations or explanation. AI advice appears only after consultation and is described as optional and fallible. The previous audit identifies its PR and preserves the exact defects and required rule IDs while suppressing legacy numerical consequence suffixes.

No trust, stress, automation, relationship, or final-score meters are displayed. Coworker feelings and story consequences are expressed through messages and prose. Money appears only on retrospective payroll paperwork. PR IDs, rule IDs, code line numbers, and technical quantities remain where the review task needs them. Queue totals and campaign denominators remain concealed.

## Slouch behavior

`content/chat.gd` supplies `messages(state, contact)` for company, Maya, Theo, and Inez. Slouch renders authored author/text rows; it does not derive hints from hidden audit answers. Incoming messages never open, raise, or switch the app. The selected conversation remains under player control. Boolean unread dots appear on contacts, the Slouch desktop icon, and its taskbar entry without message counts.

Opening a conversation clears its dot. New messages follow the bottom only when the player was reading the latest content; otherwise the previous scroll position is retained. Contact changes settle at the latest messages after native layout. The message viewport uses `SCROLL_MODE_SHOW_NEVER` horizontally so a hidden paragraph's temporary unwrapped width cannot inflate the floating window on first open.

## Verification

The native interface suite covers HOME-only startup, actual icon launch signals, taskbar launch/minimize/close lifecycle, both supported resolutions, dominant monitor sizing, dragging and keyboard movement, focus ordering, intro handoff, local-browser navigation, and the complete authored review flow. Slouch checks reproduce hidden intro → reveal → first open without an arrangement reset, including loaded progress and repeated contact changes; they assert bounded window width and wrapped long messages.

Native OpenGL screenshots were inspected for HOME, REVIEW, and SLOUCH at 1280×900. The monitor screen is 1220×810, REVIEW opens at 900×620, and SLOUCH opens at 760×520. Bundled OFL-licensed IBM Plex Mono gives consistent local typography; code remains 14px and general text 15px. No remote fonts are required.
