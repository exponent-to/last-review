# Interface foundation

`src/ui/index.ts` exports `createInterface(root, callbacks)`. It builds a stable DOM and returns the workshop `canvas`, `render(state)`, `notify(message, isError?)`, and `destroy()`. The parent application owns state, simulation timing, renderer lifecycle, persistence, and command validation. The interface has no simulation timer.

The four sections are functional: overview combines the scene, inventory, operations, and recent activity; production exposes the assembly line; ledger shows current inventory and recent events; settings manages browser saves and decorative motion. The header identity and copy are provisional and can be replaced without changing the simulation API.

## Integration

- Call `render(state)` after state changes. Text, button state, and log items update without replacing navigation, canvas, or controls. The log is rebuilt only when its contents change, and event messages use `textContent`.
- Commands are forwarded through `onCommand`. The UI disables purchases below the sample game's fixed costs ($30 for ten materials, $100 per worker), caps hiring at six workers, and requires goods for dispatch. The simulation must enforce the same rules.
- `onSave`, `onLoad`, and `onReset` handle storage and reset. Use `notify` for their results, including errors. New game requires an inline confirmation before calling `onReset`.
- `onMotion(enabled)` is called during construction and on subsequent motion-preference changes. Be prepared to receive it before `createInterface` returns. The initial value respects `prefers-reduced-motion`; an explicit checkbox choice takes precedence over later OS changes.
- The canvas is decorative, rendered at its intrinsic resolution and scaled with pixelated sampling. The renderer may change its internal resolution; preserve an 8:3 scene composition or update the CSS aspect ratio to match.
- `destroy()` removes DOM handlers and media-query listeners, clears pending notices, and empties the root. The application remains responsible for stopping animation and simulation clocks.

The footer displays elapsed simulation ticks. A theme-specific calendar can replace that presentation once the relationship between ticks and days is established. Inventory sale value is the current finished-parts count multiplied by $12; it is not cumulative revenue.

## Design and accessibility

The visual system uses warm paper, navy ink, rust accents, square borders, compact monospaced labels, and restrained sans-serif body text. There are no generated images in the interface. System fonts keep the interface self-contained and usable offline. CSS adapts the side navigation into a horizontal row and collapses cards and inventories for narrow viewports.

Controls are native buttons and inputs, with visible keyboard focus, pressed states, disabled states, and semantic navigation. Save/error notifications use a polite live region; routine tick and inventory changes are intentionally not announced. Reduced motion controls scenery only, leaving simulation time under the explicit pause/speed controls.
