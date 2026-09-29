# Yard — simulation framework

A menu-driven simulation game with a clean retro interface and animated pixel-style scenery.

## Project principles

- Keep the simulation independent of the interface and rendering.
- Make menus clear, readable, and usable with keyboard and mouse.
- Author visual assets in SVG, then rasterize them at a deliberately low resolution for crisp pixel rendering.
- Keep animation decorative: the simulation must remain usable with reduced motion.
- Build in small, reviewable commits with focused validation.

Yard is a provisional workshop example used to exercise the framework. Its name, theme, economy, and art can change independently of the underlying architecture.

## Run locally

Use Node.js 22.12 or newer (the project includes `.nvmrc`).

```sh
npm ci
npm run dev
```

Open the local URL printed by Vite. Other commands:

```sh
npm test          # deterministic simulation, saves, and clock checks
npm run build    # strict TypeScript check and production bundle
npm run preview  # serve the production bundle locally
```

Development tooling follows the [Vite setup documentation](https://vite.dev/guide/). There are no application runtime dependencies or remote fonts.

## First loop

Start parts production, buy materials, sell finished goods, and hire up to six workers. Pause or change simulation speed with the clock controls. The Settings panel contains browser-local save/load, new-game confirmation, and scenery motion controls.

One real second advances one simulation tick at 1×. Hidden tabs stop advancing; reopening a tab does not simulate offline progress. Saves are explicit, use one slot in the current browser/origin, and are not automatically loaded. Starting a new game preserves that slot until you explicitly save again. This is a framework demonstration, not a balanced game economy.

## Structure

- `src/simulation/` — pure state transitions, game commands, and validated versioned saves.
- `src/ui/` — semantic HTML menus, responsive retro CSS, and presentation.
- `src/rendering/` — low-resolution SVG rasterization and decorative animation.
- `public/art/` — editable SVG source assets.
- `src/clock.ts` — bounded fixed-step simulation timing.
- `src/main.ts` — application lifecycle, storage, and integration.

See [architecture](docs/architecture.md), [simulation](docs/simulation.md), [interface](docs/interface.md), and [art pipeline](docs/art-pipeline.md) for extension guidance.

## Development workflow

The initial framework is developed in scoped branches and isolated worktrees, then merged into `main` with reviewable commits. Validate with `npm test` and `npm run build` before integrating changes. Keep simulation rules out of UI event handlers and never make game logic depend on decorative animation.

Next decisions: choose the actual simulation theme, define its first meaningful player tradeoff, and replace the example economy and scenery accordingly.
