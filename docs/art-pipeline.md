# Native pixel scene pipeline

The workshop is a provisional theme demonstrating a replaceable presentation layer. All source SVGs are explicitly authored, editable geometry. No image-generation service, external fonts, gradients, blur, or scanline overlays are involved.

## Source files

| File | Source pixels | Purpose |
| --- | --- | --- |
| `art/workshop.svg` | 320 × 120 | Sky, hills, pines, buildings, crates, truck, and yard |
| `art/surroundings.svg` | 640 × 120 | Landscape continuation for wider native windows |
| `art/cloud.svg` | 47 × 13 | Two slowly drifting cloud instances |
| `art/smoke.svg` | 7 × 5 | Three chimney puffs while the workshop is working |
| `art/worker.svg` | 32 × 22 | Two horizontal 16 × 22 worker frames, left foot then right foot |

Use integer coordinates and axis-aligned steps to preserve the pixel grid. The palette uses gray-green scenery, concrete and tan masonry, subdued ochre details, and dark desaturated brick roofing, matching the utilitarian olive-and-charcoal menus. Sprite backgrounds are transparent. Keep edits inside each declared viewBox; change source dimensions and `ASSET_SIZES` in the renderer together.

The adjacent `.svg.import` files set `importer="keep"`, corresponding to Godot's **Keep File (exported as is)** setting. Commit these metadata files: runtime SVG loading needs the original source text preserved in exported builds. They deliberately bypass texture import because this renderer performs its own rasterization. See Godot's [FileAccess documentation](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html).

## Rasterization and rendering

`native/workshop_scene.gd` extends Godot `Control`. In `_ready()`, it reads each SVG using `FileAccess.get_file_as_string`, rasterizes it at scale 1.0 using `Image.load_svg_from_string`, validates its size, and creates one `ImageTexture`. Godot documents this conversion in its [Image API](https://docs.godotengine.org/en/stable/classes/class_image.html#class-image-method-load-svg-from-string).

The Control draws these cached raster textures around a 320 × 120 central logical grid through `_draw()`. It disables texture smoothing with `TEXTURE_FILTER_NEAREST`, uses integer sprite positions, and scales the artwork by the largest fitting integer factor. The minimum requested size is 640 × 240. A wider SVG landscape continues behind the central workshop, filling the standard desktop window without stretching pixels. Clouds are clipped to the central artwork edge. If a host forcibly provides less than the source size, the renderer shrinks to fit while preserving the 8:3 aspect ratio.

Worker frames advance at three frames per second. Clouds and smoke advance slowly in discrete pixels. `_process(delta)` controls decoration only: simulation state and elapsed game time must never depend on it.

## Host integration and lifecycle

```gdscript
const WorkshopScene = preload("res://native/workshop_scene.gd")

var scene := WorkshopScene.new()
scene.set_motion(player_wants_animation)
scene.set_working(simulation_is_running)
parent_container.add_child(scene)
```

The script sets horizontal `SIZE_EXPAND_FILL`, ignores mouse input, and clips draws to its own rect. Parent menus should present all production state as text and controls; the illustration is decorative and must never be the sole indicator of progress.

`set_motion(false)` stops processing and displays a complete still frame. The host owns the user's motion preference; set it before adding the node to avoid an unwanted initial animation. `set_working(false)` removes chimney smoke and places the worker at rest while ambient clouds can continue. Hidden controls stop processing; minimized windows do not advance decorative time. Godot releases the node's textures and signal connections when it is freed; there is no external timer or animation loop to clean up.

A missing, empty, malformed, or incorrectly sized SVG produces a native text fallback and logs the failing asset path without affecting simulation. No texture decoding occurs inside `_draw()` or `_process()`.

## Extending the art

1. Add a hand-authored SVG under `art/` using a small explicit viewBox and flat palette.
2. Add its dimensions to `ASSET_SIZES` and a matching `.svg.import` file with the `keep` importer.
3. For sprite strips, document frame size, frame count, and timing here. Select frames with source rectangles in `draw_texture_rect_region`.
4. Connect new presentation states through controller methods instead of importing game rules into the renderer.
5. Check animation enabled/disabled, idle production, minimum and large windows, hidden and minimized windows, asset failure fallback, and the exported native application.

The workshop can be replaced by a farm, station, shop, or another simulator setting while retaining the controller contract and native menus.
