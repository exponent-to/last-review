# Review-sim verification

Verified on Apple Silicon macOS with Godot 4.7.2.

- 154 simulation checks passed, zero failures.
- Native-control integration completed all 12 reviews, all three evenings, and the final accuracy summary without failures.
- Citation checkboxes, clear-citation controls, approval/rejection gating, persistent rule search, and conditional AI disclosure passed.
- Save round trips cover every game phase; altered histories, duplicate pay, incompatible versions, and invalid citations are rejected. Native save/load and backup recovery passed in an isolated application-data namespace.
- Full native project import and universal macOS app export completed without script or asset errors.
- In the exported app, searching for timeout found R01; consulting AI showed its incorrect approval advice; citing R01 and requesting changes increased trust and reduced Maya's relationship. Approving the next compliant PR produced Theo's positive reaction.
- Completing the first shift applied salary and expenses once. Socializing spent $15, improved relationships, reduced stress, and started day two with 33 active rules and fewer occupied desks. Saving and loading the resulting career succeeded in the exported app.
- Office assets load from the packaged app. Scene tests verify day-dependent occupancy, automation indicators, parameter clamping, and decorative-motion controls.
- Headless layout checks at 1280×900 and 1120×800 found no visible button extending beyond the window's right edge. Code, packet, rules, decisions, and secondary pages have native scroll containers.

Windows export, distribution notarization, assistive-technology support, audio, and a campaign longer than three days are not covered by this milestone.
