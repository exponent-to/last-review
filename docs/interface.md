# Native desktop interface

`native/interface.gd` extends Godot `Control` and constructs a stable native scene tree using containers, buttons, labels, and flat style boxes. It does not embed a browser or load web assets. The interface creates no simulation timer and does not own game state or storage.

## Integration contract

Instantiate the script, connect its signals, and add it to the scene tree. `_ready()` builds the interface. After that, the public `scene_host: Control` is available for mounting the decorative renderer, and `render_state(state: Dictionary)` updates the displayed state.

Signals:

- `command_requested(command: Dictionary)` forwards production, purchase, dispatch, hiring, and speed commands.
- `save_requested` and `load_requested` ask the application to manage its local save.
- `reset_requested` fires only after the player confirms in a Godot `ConfirmationDialog`.
- `motion_changed(enabled: bool)` controls decorative movement separately from simulation speed. Background motion defaults on; the checkbox emits on explicit user changes.

`notify(message: String, is_error: bool = false)` shows a status message above the footer for eight seconds. New messages replace prior ones; older timers cannot dismiss newer messages. Use it for save/load success and errors. Storage paths and serialization remain application concerns.

## Layout and state

The interface follows a restrained bureaucratic control-desk direction: charcoal/olive background, tan records, rust status labels, monospaced system text, and hard edges. Compact typography prioritizes operational data, with 15px native default text and smaller secondary labels. Buttons retain keyboard focus styles and provide disabled-state explanations through tooltips. SystemFont uses locally available Menlo, Courier New, or monospace; no fonts are downloaded.

The top resource ticker and inset exterior scene remain visible above CONTROL, RECORDS, and SYSTEM tabs. CONTROL contains production orders and recent dispatch records. RECORDS contains the inventory statement and longer activity register. SYSTEM contains disk save/load, reset, and motion controls. Each tab scrolls vertically as needed while the scene and clock footer remain visible. `scene_host` has a 640×240 minimum; the renderer should fill its actual control size and preserve its intended pixel-art proportions.

State keys match the simulation dictionary: `credits`, `materials`, `goods`, `workers`, `tick`, `speed`, `production`, and `log`. Rendering updates existing controls and only rewrites log text when the log changes. No player strings are parsed as rich text. The footer displays elapsed ticks without assuming a relationship to calendar days.

The sample economy uses $30 for ten materials, $12 per finished part, $100 per additional worker, and a six-worker capacity. The UI disables unaffordable/unavailable actions; the simulation must independently enforce those same rules. Inventory sale value is current goods multiplied by $12, not cumulative revenue.

No web fonts, HTML, CSS, browser runtime, generated images, or remote resources are required by this interface. Rename YARD and replace workshop copy as the game's theme becomes concrete.
