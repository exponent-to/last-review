# Framework boundaries

The application uses TypeScript, native HTML/CSS menus, and Canvas 2D for decorative scenery. Vite supplies the development server and build; Vitest checks game rules and timing. Native controls keep the menu layer accessible and avoid a runtime UI framework dependency at this early stage.

## Data flow

Player input → typed command → pure state transition → interface render.

Animation frame → bounded clock accumulator → whole simulation ticks → pure state transition → interface render.

The scene receives only a working/idle signal and a motion preference. Its animation never changes resources, time, or production. SVGs are editable source assets; the renderer rasterizes them to small canvas buffers once and paints those buffers without image smoothing.

## Time

The clock accumulates elapsed time and applies 0×, 1×, 2×, or 4× speed. The core's `advance` consumes the resulting whole ticks without multiplying speed again. Pausing clears fractional time; hidden tabs discard elapsed time. Frame gaps are capped at one second to avoid runaway catch-up after a stalled frame. Reduced scenery motion leaves simulation controls and time functional.

## State and persistence

State is plain, serializable data. Core transitions do not read the DOM, random values, wall-clock time, or browser storage. If random outcomes are added, store a seeded generator state and advance it explicitly.

Browser storage belongs to `main.ts`. Save parsing reconstructs and validates versioned data before replacing current state. A failed load preserves the current session. Storage failures are presented as menu feedback. Save migration should be added at the parsing boundary before incrementing the schema version.

## Growing the game

1. Define a themed state shape and commands in the simulation module.
2. Add rules as pure transitions and test their outcomes and invariants.
3. Adapt menu labels and views to expose player decisions.
4. Replace SVG assets or add sprite frames without changing simulation timing.
5. Add a save migration whenever serialized state changes incompatibly.

Current deliberate limits: single local player, one browser-local save slot, example economy, no offline progression, no backend, no audio, and no desktop packaging. No hosted repository or public deployment is configured.
