# Native review workstation

`native/interface.gd` is a Godot `Control` tree, with no embedded browser engine or external font/image requests. Its in-game intranet browser is made entirely from native controls and local authored documents. Its cool midnight palette uses slate outlines, near-white text, cyan operational labels, and restrained red/green decision and diff colors. It reads authored packets through `content/catalog.gd`; the simulation and disk persistence remain separate.

## Application boundary

Connect `command_requested(Dictionary)`, `save_requested`, `load_requested`, `reset_requested`, and `motion_changed(bool)`. Add the interface to the scene tree, mount the decorative renderer inside the public `scene_host`, and call `render_state(state: Dictionary)` after each state change. `scene_host` has a 640×192 minimum for the office renderer's integer scaling. Motion defaults on and the checkbox emits explicit changes.

`notify(message: String, is_error: bool = false)` displays a footer message for eight seconds. A generation counter keeps an older timer from dismissing a newer message. New-run requests require a native confirmation dialog. Save, load, serialization, and reset policy belong to the parent application.

## Review procedure

The review desk has independent overlapping native windows for the current PR, the rulebook, and sign-off controls. Each has a draggable titlebar, focus border, minimize button, and taskbar entry. Clicking a window brings it forward; taskbar buttons restore minimized windows. The default arrangement offsets the windows without obscuring their primary controls. CodeEdit provides selectable monospaced code, line numbers, independent scrolling, and a native diff highlighter. Additions are green, removals red, and hunk markers cyan. The author packet scrolls separately so long prose cannot consume the code area. The header briefing has a compact preview and a button that opens its full text in a native dialog.

Rule controls are built once. Search checks IDs, titles, and text, with an optional category filter. Rules introduced after the current day stay hidden. Later shifts show a compact count of rules added that day; the catalog controls the initial policy set and unlock pace. State updates synchronize checked citations without rebuilding the list, resetting search, or replacing controls. Clearing citations sends one toggle command per selected rule. The approve button requires no citations; requesting changes requires at least one. Core simulation validation is still authoritative.

The active PR view deliberately never reads the request's audit-only `violations` or `explanation`. AI recommendation fields are displayed only after consultation. The consultation's stress -2 and AI authority +4 effects are shown before use, and the interface warns that advice can be wrong. The previous audit names its PR and author and displays correctness, required rule IDs, explanation, and relationship/trust consequences, so it cannot be mistaken for the new PR's answer.

## Days, relationships, and endings

Debrief replaces the active review desk when the authored shift closes. It shows earned pay, expenses, correct reviews, balance, colleague relationships, the final audit, and the three evening choices with exact effects: rest lowers stress by 18; socializing costs $15, improves all relationships by 4, and lowers stress by 8; studying raises trust and stress by 4. The simulation decides when the next day or completion begins.

Completion shows accuracy, money, trust, stress, automation authority, and relationships. A short prototype ending reacts to high automation authority, low trust, and high stress. It marks the end of the playable slice without presenting unimplemented future play as available.

PEOPLE shows Maya, Theo, and Inez separately from system trust and the workplace log. SYSTEM contains disk save/load, confirmed reset, decorative-motion settings, and review instructions. BROWSER provides local intranet home, procedure, and daily memo pages with back navigation, plus links that open the standards and directory windows. It never fetches a real URL. The top metrics and rainy office remain visible above the desktop. The footer explicitly states that reading costs no game time. Request headers show only the PR identifier and review status. The interface conceals future queue sizes, per-shift request positions, campaign denominators, and the number of shifts remaining. Debrief reports only work already completed; the ending shows the number of correct reviews without a total denominator.

## Layout and verification

The native layout targets 1280×900 with a 1120×800 minimum. Window contents are stable; code, author packet, rulebook, disposition, and long secondary pages scroll independently. The desktop rearranges to fit a resized game window. ARRANGE resets positions explicitly. Focus a titlebar and use arrow keys to move its window, with Shift for larger steps. Dragging clamps the titlebar to remain reachable; minimizing never discards content or state. State updates preserve window positions, minimized state, search, and scroll except for the existing new-PR packet reset. The OFL-licensed IBM Plex Mono font is bundled at `art/fonts/IBMPlexMono-Regular.ttf` and preloaded for consistent terminal typography, including code, on every machine. Body text is 15px; code is 14px, and secondary field labels are compact. Focus rings and disabled explanations remain visible.

A headless Godot 4.7.2 instantiation check exercised sample review, debrief, and complete states. Layout checks at both target dimensions found no visible button crossing the window's right edge. The committed `tests/test_interface.gd` drives actual citation and decision controls through every catalogued PR and each shift’s evening choice, checks AI disclosure and search preservation, and verifies final accuracy. Exported-app verification also exercised decisions, shift payout, evening choices, and saving/loading. Author-packet scrolling resets when a new PR arrives so its message is not skipped.

## Floating window component

`native/desktop_window.gd` owns native titlebar movement, boundary clamping, activation styling, and minimize/restore behavior. It exposes its content `body`, emits `activated(window_id)` and `minimized(window_id)`, and provides `focus_window`, `minimize_window`, `restore_window`, `move_window`, and `clamp_to_desktop`. The interface owns desktop sizing, default arrangement, taskbar state, and app content. Shift records are their own window; gameplay windows reappear when a new shift begins.

The interface integration suite now checks both supported resolutions, mouse drag initiation/release, keyboard movement, all drag bounds, focus ordering, minimize/reopen behavior across a state refresh, local-browser back navigation, and the complete authored review flow. A native OpenGL render was inspected at 1280×900; its PR code area retained 564×246 pixels with the 192px office strip.
