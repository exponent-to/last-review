import { createInitialState, dispatch, advance, serializeSave, parseSave } from './simulation';
import { createInterface } from './ui';
import { createWorkshopScene } from './rendering';
import { createClock } from './clock';

const SAVE_KEY = 'yard.save.v1';
const root = document.querySelector<HTMLDivElement>('#app');
if (!root) throw new Error('Application root is missing.');

let state = createInitialState();
let scene: Awaited<ReturnType<typeof createWorkshopScene>> | undefined;
let motionEnabled = !window.matchMedia('(prefers-reduced-motion: reduce)').matches;
let disposed = false;
const clock = createClock();

function render() {
  ui.render(state);
  scene?.setWorking(state.speed !== 0 && state.production === 'parts' && state.materials > 0);
}

const ui = createInterface(root, {
  onCommand(command) {
    state = dispatch(state, command);
    if (command.type === 'set-speed') clock.reset();
    render();
  },
  onSave() {
    try {
      localStorage.setItem(SAVE_KEY, serializeSave(state));
      ui.notify('Game saved in this browser.');
    } catch {
      ui.notify('Unable to save. Browser storage may be full or disabled.', true);
    }
  },
  onLoad() {
    try {
      const raw = localStorage.getItem(SAVE_KEY);
      if (raw === null) { ui.notify('No saved game in this browser yet.', true); return; }
      const loaded = parseSave(raw);
      state = loaded;
      clock.reset();
      render();
      ui.notify('Saved game loaded.');
    } catch (error) {
      ui.notify(error instanceof Error ? error.message : 'Unable to load this save.', true);
    }
  },
  onReset() {
    state = createInitialState();
    clock.reset();
    render();
    ui.notify('New workshop started. Your last saved game is still available.');
  },
  onMotion(enabled) { motionEnabled = enabled; scene?.setMotion(enabled); },
});

render();
void createWorkshopScene(ui.canvas).then((created) => {
  if (disposed) { created.destroy(); return; }
  scene = created;
  scene.setMotion(motionEnabled);
  render();
}).catch(() => {
  if (!disposed) ui.notify('Scenery could not load. You can still use every game menu.', true);
});

let previous = performance.now();
let frame = 0;
function animate(now: number) {
  const elapsed = now - previous;
  previous = now;
  if (!document.hidden) {
    const ticks = clock.consume(elapsed, state.speed);
    if (ticks > 0) { state = advance(state, ticks); render(); }
  }
  frame = requestAnimationFrame(animate);
}
function visibilityChanged() { previous = performance.now(); clock.reset(); }
document.addEventListener('visibilitychange', visibilityChanged);
frame = requestAnimationFrame(animate);

if (import.meta.hot) {
  import.meta.hot.dispose(() => {
    disposed = true;
    cancelAnimationFrame(frame);
    document.removeEventListener('visibilitychange', visibilityChanged);
    scene?.destroy();
    ui.destroy();
  });
}
