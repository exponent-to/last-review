# Pixel scene pipeline

The workshop is a provisional theme demonstrating a replaceable presentation layer. Every SVG is hand-authored, editable geometry. No generated raster artwork, external fonts, runtime image service, gradients, blur, or scanline overlays are used.

## Source files

| File | Source pixels | Purpose |
| --- | --- | --- |
| `public/art/workshop.svg` | 320 × 120 | Sky, hills, pines, buildings, crates, truck, and yard |
| `public/art/cloud.svg` | 47 × 13 | Two slowly drifting cloud instances |
| `public/art/smoke.svg` | 7 × 5 | Three chimney puffs while the workshop is working |
| `public/art/worker.svg` | 32 × 22 | Two horizontal 16 × 22 worker frames, left foot then right foot |

Use integer coordinates and axis-aligned steps to preserve the pixel grid. The scene's palette uses sage and blue-gray scenery, warm cream masonry, ochre details, and brick-red roofing. Sprite backgrounds are transparent. Keep edits inside each declared viewBox; change source dimensions and rasterization metadata together.

## Rendering

`createWorkshopScene(canvas)` in `src/rendering/index.ts` loads assets relative to Vite's `BASE_URL`, decodes each SVG, and draws it once into a native-resolution offscreen canvas. Each animation frame composites those raster buffers onto a 320 × 120 canvas. The final draw scales that buffer by an integer factor of two to a 640 × 240 display canvas. Both canvas contexts disable smoothing, and the display canvas uses `image-rendering: pixelated` for CSS resizing.

All sprite positions and frame selections are integers. Worker frames advance at three frames per second; clouds and smoke advance slowly in discrete pixels. This uses the browser's animation clock only for decoration: simulation state and elapsed game time must never depend on it.

For exact square pixels, display the scene at integer multiples of its 320 × 120 source size. A fluid CSS width keeps nearest-neighbor edges, but intermediate sizes can produce uneven pixel widths. Preserve the 8:3 aspect ratio.

## Lifecycle and accessibility

Await the factory and retain the returned controller:

```ts
const scene = await createWorkshopScene(canvas);
scene.setWorking(simulationIsRunning);
scene.setMotion(userWantsAnimation);
// When the screen unmounts:
scene.destroy();
```

Initialization rejects with an asset-specific error if decoding fails; show a static CSS fallback or short loading error from the caller. No animation loop or event listener is installed until all assets have loaded. If the caller unmounts while initialization is pending, destroy the controller when its promise resolves.

The first frame honors `prefers-reduced-motion`, and subsequent system preference changes are followed until `setMotion` explicitly overrides that preference. Disabled motion produces a complete still scene. Hidden tabs stop scheduling animation frames and resume without trying to catch up elapsed decoration time. `destroy()` cancels the loop, unregisters listeners, and is safe to call more than once. Controller methods become no-ops after destruction.

The host owns the semantic role: this canvas should normally be decorative (`aria-hidden="true"`), with simulation information represented separately in accessible HTML. The illustration must not be the only place a player can see a production state.

## Extending the art

1. Add a hand-authored SVG to `public/art/`, using a small explicit viewBox and flat palette.
2. Add its raster dimensions to the initialization list. Keep decoding out of the animation loop.
3. For a sprite strip, document frame size, frame count, and intended timing here. Select frames by source rectangles in `drawImage`.
4. Connect new domain presentation states through controller methods rather than importing simulation code into the renderer.
5. Verify the scene with motion disabled, an inactive workshop, a resized canvas, a hidden tab, and a non-root deployment base URL.

The workshop can be replaced by a farm, station, shop, or another simulator setting while keeping the controller contract and menu UI intact.
