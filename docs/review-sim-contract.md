# PRs please: first playable slice

Working title: PRs please. Native Godot desktop game. Grounded workplace tension with gradual AGI authority; cold midnight blue, cool paper, cyan and restrained red. Reference is the functional clarity and human stakes of Papers, Please, not its assets or exact UI.

## Content API

`Catalog` extends RefCounted and exposes static `rules() -> Array`, `rules_for_day(day:int) -> Array`, `requests() -> Array`, `request_at(index:int) -> Dictionary`, `requests_for_day(day:int) -> Array`, `campaign_days() -> Array`, `briefing(day:int) -> String`. Content returned as deep copies.

Rule: `{id:String, category:String, title:String, text:String, introduced_day:int}`. Four rules initially, with new standards introduced between shifts. Future standards stay hidden.

PR: `{id:String, title:String, author:String, day:int, file:String, description:String, message:String, diff:String, violations:Array[String], explanation:String, ai_verdict:String, ai_note:String}`. Ordered by day with variable shift lengths. Authors are Maya, Theo, or Inez. `violations` and `explanation` are audit-only and must not be revealed until after a decision. `ai_verdict` is approve or request_changes and can be wrong. AI recommendation is visible only after the player uses consult-ai. Misleading comments are fictional in-game claims; actual code must support every audited defect.

## Simulation API (core agent)

Preserve pure static `initial_state`, `dispatch`, `advance`, `validate_save`, `serialize_save`. `advance(state, seconds)` progresses a three-minute shift. The application stops calling it during intro, pause, focus loss, and after closing. Reading while unpaused consumes time. PRs must have arrived and been selected before review.

Core state fields (see simulation.md for the full action journal): version=5, day:int (catalog day), request_index:int (bounded by catalog length), phase:String(review/debrief/complete), credits:int, trust:int0..100, stress:int0..100, autonomy:int0..100, coworkers:Dictionary(Maya/Theo/Inez:int0..100), selected_rules:Array[String], consulted:bool, decisions:Array[Dictionary], log:Array[{day:int,message:String}], last_feedback:Dictionary, last_debrief:Dictionary.

Commands: `{type:'toggle-rule',rule_id:String}`, `{type:'consult-ai'}`, `{type:'review',verdict:'approve'|'request_changes'}`, `{type:'next-day',choice:'rest'|'socialize'|'study'}`.

On a decision, request_index advances immediately; last_feedback describes the previous decision and must remain visible. When the catalog's current day ends, phase=debrief and pay/expenses apply exactly once. next-day applies the evening choice, advances to the next catalog day and returns to review; after the final day it changes phase to complete. Last day choice still applies. Complete cannot review again. Do not show prospective queue counts or campaign denominators in the interface.

Feedback fields: `{pr_id:String,author:String,correct:bool,verdict:String,message:String,expected_rules:Array,relationship_delta:int,trust_delta:int}`. Debrief fields: `{day:int,reviewed:int,correct:int,pay:int,expenses:int,balance:int,message:String}`.

Rejecting requires one or more cited rules. Correct reject = cited IDs exactly equal actual violation IDs. Approve requires no citations (disable until cleared). Invalid commands must not advance or award anything. Coworker approval is separate from technical correctness. AI consultation increases automation reliance and can recommend an incorrect decision. Save validation must enforce content-index/phase/day/decision invariants and reject unsupported save formats with a useful message. Timed transitions are deterministic for the same commands and elapsed seconds; there is no randomness. See docs/simulation.md for the current state contract.

## Interface API (UI agent)

Keep native Control signals `command_requested(Dictionary)`, `save_requested`, `load_requested`, `reset_requested`, `motion_changed(bool)`, public `scene_host:Control`, `render_state(state:Dictionary)`, `notify(message:String,is_error:bool=false)`.

Native review workstation, not SaaS dashboard. Compact resource strip, shallow animated office view, 3-column main desk: PR code + author context, searchable/filterable rules and citation toggles, decision controls and consequences. Prefer Review / People / System tabs if space requires. All primary controls fit 1280x900 and minimum1120x800; native scrolling for lengthy code/rules. No large blank card areas. Display day briefing and clear help for citing violations. Never expose audit answer in active PR. Debrief and complete are actual playable views. Clear visual separation between system trust, coworker relationships, and automation reliance.

## Scene API (art agent)

Own native/office_scene.gd and new art/office*.svg assets. Control has `set_motion(bool)` and `set_story(day:int,autonomy:int)`. Pure decorative rasterized hand-authored SVGs, native nearest filtering. Shallow wide office night scene: desks/monitors, city windows, server racks; automation presence changes with day/autonomy. Parent instantiates in scene_host.
