# Native computer and office pixel art

The current first-person view uses `native/computer_frame.gd`: hand-authored pixel geometry for a physical monitor, visible rainy-room edges, lower bezel, vents, power lamp, and a small stand. `get_screen_rect(size)` defines the desktop inset (left 100, top 108, right 100, bottom 128 pixels). At 1280×900 the screen is 1080×664. A red rooftop sign and blinking beacons sit in the window strip above the monitor; `interface.gd` draws faint CRT scanlines over the screen. The interface owns everything inside that rectangle; there is no exterior HUD or office banner. `set_motion` and `set_story` retain the decorative renderer contract.

The four `art/desktop-*.svg` app icons are original 32×32 vector pixel geometry in the warm-neutral / phosphor-green / alarm-red desktop palette, imported as native textures and displayed with nearest-neighbor filtering. They identify Review, Slouch, Intranet, and System. Font files are bundled separately under `art/fonts/` with their OFL license.

The following office sprites remain reusable art components from the earlier room composition.

`native/office_scene.gd` is a decorative Godot `Control` for PRs please. All SVGs are explicit, editable pixel geometry. The palette is midnight navy, blue-gray, cool off-white, cyan monitor light, and restrained red indicators. There are no brown/olive tones, gradients, glow filters, or generated images.

## Source assets

| File | Source size | Contents / frames |
| --- | --- | --- |
| `art/office.svg` | 640 × 96 | Night-office room, tall rainy city windows, server cabinets |
| `art/office-foreground.svg` | 640 × 96 | Four review desks; masks outdoor rain behind monitors |
| `art/office-worker.svg` | 32 × 27 | Two horizontal 16 × 27 seated typing poses |
| `art/office-terminal.svg` | 72 × 12 | Three 24 × 12 states: human code review, assistant, autonomous agent |
| `art/office-rain.svg` | 77 × 52 | Transparent curtain of rain, wrapped vertically, with longer near-glass streaks |
| `art/office-indicator.svg` | 6 × 2 | Three 2 × 2 states: standby, cyan activity, red authority indicator |
| `art/app-icon.svg` | 512 × 512, 32 × 32 viewBox | Review terminal app icon |

Keep shapes and sprite bounds on integer coordinates. Desk repeats in the foreground SVG are editable `<use>` instances. Update `ASSET_SIZES` in the renderer when changing source dimensions. The icon uses Godot's normal texture import; office sprites use adjacent `.svg.import` files with `importer="keep"` so original SVG text survives native exports.

## Native rendering

On `_ready()`, the renderer reads each office SVG with `FileAccess.get_file_as_string`, rasterizes it once with `Image.load_svg_from_string`, validates its dimensions, and creates a cached `ImageTexture`. Godot documents [SVG rasterization in the Image API](https://docs.godotengine.org/en/stable/classes/class_image.html#class-image-method-load-svg-from-string) and [source-file preservation in FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html).

`_draw()` composites those raster textures with nearest-neighbor filtering and integer source coordinates. Height determines integer scaling: a 192-pixel panel displays the 640 × 96 source at 2×. Widths below 1280 crop unimportant side-room scenery symmetrically, preserving all four workstations and server cabinets at the supported 1120-pixel window minimum. Larger widths center the office against its navy background. Host containers own outer panel padding; `clip_contents` prevents any draw outside the scene Control.

Rain wraps only inside the taller window band at 17 source pixels per second. The cached foreground texture masks rain behind desk and monitor silhouettes. A stopped scene retains visible raindrops rather than an empty sky. Worker poses switch at two frames per second. Server indicators pulse slowly. No runtime image generation, SVG decoding, or texture allocation occurs in the animation loop.

## Story contract

```gdscript
const OfficeScene = preload("res://native/office_scene.gd")
var scene := OfficeScene.new()
scene.set_motion(player_wants_animation)
scene.set_story(state.day, state.autonomy)
scene_host.add_child(scene)
```

`set_story(day, autonomy)` clamps its inputs to days 1–3 and autonomy 0–100. Story changes redraw even when motion is disabled.

| Day | Human occupancy | Baseline AGI terminals | Visual interpretation |
| --- | --- | --- | --- |
| 1 | Four desks | One assistant screen | Coworkers remain present; assistance is peripheral |
| 2 | Three desks | Two assistant screens | One empty chair, more machine activity |
| 3 | One desk | Three autonomous screens | The reviewer is isolated as the server presence grows |

Higher autonomy activates extra terminals and rack indicators. These visual cues reflect state only; the scene never mutates simulation state or measures game time. The native UI must describe the story and resources independently, since the artwork is decorative.

## Motion, errors, and cleanup

`set_motion(false)` stops processing and shows a complete still scene. Set it before adding the node when restoring a saved preference. Hidden or unfocused windows stop decorative processing; minimized windows do not advance decoration time. Focus restoration resumes without catching up elapsed time. Godot automatically releases textures and signal connections when the scene node is freed.

Missing, empty, malformed, or incorrectly sized assets display a short native fallback message and log the failing path. The game's review controls continue to function. Keep the office `.svg.import` metadata in version control and verify packaged builds retain each source SVG.

## Extending the scene

Add new SVGs under `art/office*.svg`, record their dimensions and frames above, and give runtime-rasterized assets a `keep` importer. Prefer controller parameters for additional story presentation states; do not import game rules into this renderer. Verify all five days with low/high autonomy, motion disabled, hidden/unfocused windows, the minimum window size, and the packaged native app.
