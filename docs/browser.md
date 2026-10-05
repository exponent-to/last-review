# Browser build

Live release: [travis.show/prs-please/](https://travis.show/prs-please/). The website repository is `TravisGibbs/blog`; its existing Fly.io workflow publishes main. `public/prs-please/` contains the tested static export, with a file-hash manifest and update instructions under that repository’s `docs/`.

The same Godot game can be exported for desktop browsers alongside the native macOS app. The Web preset uses the existing Compatibility renderer, WebGL 2.0, and the single-threaded Godot 4.7.2 runtime. It does not embed a browser in the native game or change the native export preset.

## Automatic deploys

`.github/workflows/deploy-web.yml` runs on every push to `main` (and on demand from the Actions tab). It installs Godot 4.7.2 for Linux (`scripts/bootstrap-linux.sh`) and the Web template, imports resources, runs `scripts/check.sh`, and exports with `scripts/build-web.sh`. `scripts/publish-web.sh` then copies `build/web/` into the website's `public/prs-please/` and rewrites `docs/prs-please-release.json` with the game commit and file hashes. The job pushes that as one commit to `TravisGibbs/blog` `main`, whose Fly workflow deploys the site. A failing test stops the release, and an unchanged export pushes nothing.

The workflow needs one repository secret, `BLOG_DEPLOY_TOKEN`: a fine-grained personal access token limited to `TravisGibbs/blog` with **Contents: read and write**. To roll back, revert the publish commit in the website repository.

To publish manually instead, run `sh scripts/publish-web.sh <blog-checkout>` after a tested build, then commit in that checkout.

## Build and run locally

Use Godot 4.7.2 on PATH, the existing project-local editor, or set `GODOT_BIN` to that editor executable. Python 3 and curl are required by the template bootstrap; Python 3 also provides the local server.

```sh
sh scripts/bootstrap-web.sh
sh scripts/build-web.sh
python3 scripts/serve-web.py
```

Open [PRs please locally](http://127.0.0.1:8060/) in a desktop browser. Use a reasonably large browser window for the computer desktop interface. The server binds only to `127.0.0.1`; stop it with Ctrl-C. Choose a different port with `--port 8061` if necessary.

The build is written to `build/web/index.html` with its matching JavaScript, WebAssembly, asset pack, and images. Open it through the local HTTP server rather than double-clicking the HTML file. Keep these generated files together and retain their names.

`bootstrap-web.sh` obtains `web_nothreads_release.zip` and the version marker from the official pinned export-template archive. It uses HTTP byte ranges to retrieve only the needed archive member, rather than downloading the entire multi-platform bundle. ZIP integrity and the expected version are checked before installation. Re-running the bootstrap reuses a matching intact template. `GODOT_TEMPLATE_DIR` can select a shared template cache when working across checkouts; the export preset expects the installed file at `.tools/templates/web_nothreads_release.zip` in the project being built.

## Browser saves

The game's explicit Save and Load controls use Godot's browser-local `user://` storage, backed by IndexedDB. Browser saves are separate from native app saves and are not cloud-synced. They belong to the browser profile and origin: keep the same hostname and port to return to the same local save. `localhost` and `127.0.0.1`, or different ports, are different origins.

Clearing site data removes these saves. Private browsing and browser storage restrictions may prevent durable persistence. After first saving, reload the same URL and use Load to verify persistence in that browser. The native save files remain independent.

## Serving or hosting

The local server serves only the export directory, suppresses directory listings, disables development caching, and supplies explicit MIME types for `.wasm`, `.js`, `.pck`, and `.html`. It does not require cross-origin isolation headers because threads and GDExtensions are disabled. PWA/service-worker behavior is disabled to avoid stale development builds.

For a public deployment, upload the entire `build/web` directory to a static HTTPS host that serves `.wasm` as `application/wasm`. Exporting and running locally do not publish anything. Modern Chromium or Firefox with WebAssembly and WebGL 2.0 support are the primary desktop targets; other browsers need their own playtest. This is not a touch/mobile interface redesign.

## Verification

The Godot 4.7.2 release export completed successfully with `GODOT_THREADS_ENABLED=false`. The generated WebAssembly header and HTML configuration were checked. A loopback HTTP smoke check returned the expected HTML, JavaScript, WebAssembly, and asset-pack MIME types, while a repository file outside the export directory returned 404. Shell syntax checks passed.

The integrated browser build was playtested at 1280×900: intro handoff, advancing clock, manual pause/resume, timed Slouch arrival, contextual question and coworker response, PR link navigation, multi-file dropdown and helper diff, and Save → reload → Load. (That playtest predates the removal of Slouch; PRs now open from REVIEW and its notification card.) The loaded clock and conversation were preserved. In-game popup menus no longer trigger focus-loss pause; only application focus loss does.

Implementation references: [Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html) and the [Godot 4.7.2 Web template selection code](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/web/export/export_plugin.h).

## Startup screen

`web/shell.html` is the custom Godot HTML shell. It displays a Paperclip Labs terminal with bundled IBM Plex Mono while the real engine download progresses, then hands off immediately to the main menu. Failed downloads and unsupported browsers show a readable error and Retry Startup. Motion follows the browser’s reduced-motion preference. The native boot splash also omits the default Godot logo.

The Web build copies `loader-font.ttf` and its OFL license beside the export; deploy these with the other generated files. No remote fonts or artificial loading delay are used. See [Godot’s custom HTML shell documentation](https://docs.godotengine.org/en/stable/tutorials/platform/web/customizing_html5_shell.html).
