# Native review workstation

`native/interface.gd` is a Godot `Control` tree, with no embedded browser engine or external font/image requests. Its in-game intranet browser is made entirely from native controls and local authored documents. Its cool midnight palette uses slate outlines, near-white text, cyan operational labels, and restrained red/green decision and diff colors. It reads authored packets through `content/catalog.gd`; the simulation and disk persistence remain separate.

## Application boundary

Connect `command_requested(Dictionary)`, `save_requested`, `load_requested`, `reset_requested`, and `motion_changed(bool)`. Add the interface to the scene tree, mount the decorative renderer inside the public `scene_host`, and call `render_state(state: Dictionary)` after each state change. When an intro reveals the interface, call `focus_workspace()` to focus the non-actionable root and settle the first diff at its beginning; later calls preserve reading position. `scene_host` has a 640×192 minimum for the office renderer's integer scaling. Motion defaults on and the checkbox emits explicit changes.

`notify(message: String, is_error: bool = false)` displays a footer message for eight seconds. A generation counter keeps an older timer from dismissing a newer message. New-run requests require a native confirmation dialog. Save, load, serialization, and reset policy belong to the parent application.

## Review procedure

The review desk has independent overlapping native windows for the current PR, the rulebook, and sign-off controls. Each has a draggable titlebar, focus border, minimize button, and taskbar entry. Clicking a window brings it forward; taskbar buttons restore minimized windows. The default arrangement offsets the windows without obscuring their primary controls. CodeEdit provides selectable monospaced code, line numbers, independent scrolling, and a native diff highlighter. Additions are green, removals red, and hunk markers cyan. The author packet scrolls separately so long prose cannot consume the code area. The header briefing has a compact preview and a button that opens its full text in a native dialog.

Rule controls are built once. Search checks IDs, titles, and text, with an optional category filter. Rules introduced after the current day stay hidden. Later shifts show a compact count of rules added that day; the catalog controls the initial policy set and unlock pace. State updates synchronize checked citations without rebuilding the list, resetting search, or replacing controls. Clearing citations sends one toggle command per selected rule. The approve button requires no citations; requesting changes requires at least one. Core simulation validation is still authoritative.

The active PR view deliberately never reads the request's audit-only `violations` or `explanation`. AI recommendation fields are displayed only after consultation. Consultation is described in-world: Helios can ease the workload while gaining influence, and its advice can be wrong. Numeric consequence values remain internal. The previous audit names its PR and author and displays correctness, required rule IDs, explanation, and the human response, so it cannot be mistaken for the new PR's answer.

## Days, relationships, and endings

Debrief replaces the active review desk when the authored shift closes. It shows pay, expenses, and balance as a payroll record, followed by the final audit and natural-language evening choices: rest, buy dinner with colleagues, or stay up studying. Personal statistics and relationship values are not displayed. The simulation decides when the next day or completion begins.

Completion reports an in-world outcome without a numerical scorecard. A short prototype ending reacts to high automation authority, low trust, and high stress. It marks the end of the playable slice without presenting unimplemented future play as available.

SLOUCH is a separate native app with a company channel and direct messages from Maya, Theo, and Inez. Coworker feelings and PR hints are conveyed through authored messages and review reactions, replacing the numeric relationships page. SYSTEM contains disk save/load, confirmed reset, decorative-motion settings, and review instructions. BROWSER provides local intranet home, procedure, and daily memo pages with back navigation, plus links that open the standards and Slouch windows. It never fetches a real URL. Weekday and terminal status replace the top score strip; the rainy office remains visible above the desktop. The footer explicitly states that reading costs no game time. Request headers show only the PR identifier and review status. The interface conceals future queue sizes, per-shift request positions, campaign denominators, and the number of shifts remaining. Debrief uses payroll paperwork for money; the ending uses narrative consequences. PR IDs, rule IDs, code line numbers, and technical quantities remain because the review task needs them.

## Layout and verification

The native layout targets 1280×900 with a 1120×800 minimum. Window contents are stable; code, author packet, rulebook, disposition, and long secondary pages scroll independently. The desktop rearranges to fit a resized game window. ARRANGE resets positions explicitly. Focus a titlebar and use arrow keys to move its window, with Shift for larger steps. Dragging clamps the titlebar to remain reachable; minimizing never discards content or state. State updates preserve window positions, minimized state, search, and scroll except for the existing new-PR packet reset. The OFL-licensed IBM Plex Mono font is bundled at `art/fonts/IBMPlexMono-Regular.ttf` and preloaded for consistent terminal typography, including code, on every machine. Body text is 15px; code is 14px, and secondary field labels are compact. Focus rings and disabled explanations remain visible.

A headless Godot 4.7.2 instantiation check exercised sample review, debrief, and complete states. Layout checks at both target dimensions found no visible button crossing the window's right edge. The committed `tests/test_interface.gd` drives actual citation and decision controls through every catalogued PR and each shift’s evening choice, checks AI disclosure and search preservation, and verifies final accuracy. Exported-app verification also exercised decisions, shift payout, evening choices, and saving/loading. Author-packet scrolling resets when a new PR arrives so its message is not skipped.

## Floating window component

`native/desktop_window.gd` owns native titlebar movement, boundary clamping, activation styling, and minimize/restore behavior. It exposes its content `body`, emits `activated(window_id)` and `minimized(window_id)`, and provides `focus_window`, `minimize_window`, `restore_window`, `move_window`, and `clamp_to_desktop`. The interface owns desktop sizing, default arrangement, taskbar state, and app content. Shift records are their own window; gameplay windows reappear when a new shift begins.

The interface integration suite now checks both supported resolutions, mouse drag initiation/release, keyboard movement, all drag bounds, focus ordering, minimize/reopen behavior across a state refresh, local-browser back navigation, and the complete authored review flow. A native OpenGL render was inspected at 1280×900; its PR code area retained 564×246 pixels with the 192px office strip.

## Slouch conversations

`content/chat.gd` owns authored dialogue and exposes `messages(state, contact)` for `company`, `Maya`, `Theo`, and `Inez`. The UI displays author/text rows and never derives hints from a request's hidden audit fields. Conversation history updates when state changes; unchanged rows are retained. Unread state is a boolean dot on the relevant contact and the SLOUCH taskbar button, never a numerical badge.

The player controls the app and selected conversation. Incoming messages never open, raise, or switch Slouch, even when it is already visible. Opening a conversation clears only its unread dot. New content follows the bottom only when the player was already reading the latest messages; otherwise it preserves scroll position. Contact changes scroll to the latest messages after native layout. There is no nonfunctional message composer.

The integration suite checks contact selection, explicit opening and minimization, preservation of selected conversation across reviews, unread reactions, focus retention, and authored message updates. It also verifies the removal of numeric stat HUD fields, legacy audit deltas, and final scorecard text. The simulation retains its internal numbers for consequences and save validation; only their presentation changes.
