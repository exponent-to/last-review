/** Hand-authored SVG assets are rasterized once, then composited on a pixel grid. */
export interface WorkshopScene {
  setMotion(enabled: boolean): void;
  setWorking(working: boolean): void;
  destroy(): void;
}

const WIDTH = 320;
const HEIGHT = 120;
const DISPLAY_SCALE = 2;

async function rasterize(name: string, width: number, height: number): Promise<HTMLCanvasElement> {
  const image = new Image();
  image.src = `${import.meta.env.BASE_URL}art/${name}.svg`;
  try {
    await image.decode();
  } catch {
    throw new Error(`Could not load scene asset: ${name}.svg`);
  }
  const buffer = document.createElement('canvas');
  buffer.width = width;
  buffer.height = height;
  const context = buffer.getContext('2d');
  if (!context) throw new Error('This browser cannot render the workshop scene.');
  context.imageSmoothingEnabled = false;
  context.drawImage(image, 0, 0, width, height);
  return buffer;
}

export async function createWorkshopScene(canvas: HTMLCanvasElement): Promise<WorkshopScene> {
  const context = canvas.getContext('2d');
  if (!context) throw new Error('This browser cannot render the workshop scene.');

  const [background, cloud, smoke, worker] = await Promise.all([
    rasterize('workshop', WIDTH, HEIGHT),
    rasterize('cloud', 47, 13),
    rasterize('smoke', 7, 5),
    rasterize('worker', 32, 22),
  ]);
  const frame = document.createElement('canvas');
  frame.width = WIDTH;
  frame.height = HEIGHT;
  const pixels = frame.getContext('2d');
  if (!pixels) throw new Error('This browser cannot render the workshop scene.');
  canvas.width = WIDTH * DISPLAY_SCALE;
  canvas.height = HEIGHT * DISPLAY_SCALE;
  canvas.style.imageRendering = 'pixelated';
  pixels.imageSmoothingEnabled = false;
  context.imageSmoothingEnabled = false;

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  let motion = !reducedMotion.matches;
  let motionOverridden = false;
  let working = true;
  let destroyed = false;
  let elapsed = 0;
  let previousTime: number | null = null;
  let animationId: number | null = null;

  function draw(): void {
    pixels!.drawImage(background, 0, 0);
    // The clouds remain above every opaque foreground feature.
    const cloudX = Math.floor((elapsed * 1.4 + 31) % (WIDTH + 47)) - 47;
    pixels!.drawImage(cloud, cloudX, 12);
    pixels!.drawImage(cloud, Math.floor((elapsed * 0.8 + 181) % (WIDTH + 47)) - 47, 7);

    if (working) {
      for (let index = 0; index < 3; index += 1) {
        const rise = (elapsed * 3 + index * 7) % 21;
        pixels!.drawImage(smoke, 217 + Math.floor(rise / 5), 23 - Math.floor(rise));
      }
    }
    const workerFrame = working && motion ? Math.floor(elapsed * 3) % 2 : 0;
    const workerX = working ? 153 + Math.floor((Math.sin(elapsed * 0.28) + 1) * 7) : 160;
    pixels!.drawImage(worker, workerFrame * 16, 0, 16, 22, workerX, 84, 16, 22);
    context!.drawImage(frame, 0, 0, canvas.width, canvas.height);
  }

  function tick(time: number): void {
    animationId = null;
    if (destroyed || !motion || document.hidden) return;
    if (previousTime !== null) elapsed += Math.min((time - previousTime) / 1000, 0.1);
    previousTime = time;
    draw();
    animationId = window.requestAnimationFrame(tick);
  }

  function syncAnimation(): void {
    if (destroyed) return;
    if (animationId !== null) window.cancelAnimationFrame(animationId);
    animationId = null;
    previousTime = null;
    draw();
    if (motion && !document.hidden) animationId = window.requestAnimationFrame(tick);
  }

  function onMotionPreference(): void {
    if (motionOverridden) return;
    motion = !reducedMotion.matches;
    syncAnimation();
  }

  reducedMotion.addEventListener('change', onMotionPreference);
  document.addEventListener('visibilitychange', syncAnimation);
  syncAnimation();

  return {
    setMotion(enabled) {
      if (destroyed) return;
      motionOverridden = true;
      motion = enabled;
      syncAnimation();
    },
    setWorking(enabled) {
      if (destroyed) return;
      working = enabled;
      draw();
    },
    destroy() {
      if (destroyed) return;
      destroyed = true;
      if (animationId !== null) window.cancelAnimationFrame(animationId);
      reducedMotion.removeEventListener('change', onMotionPreference);
      document.removeEventListener('visibilitychange', syncAnimation);
    },
  };
}
