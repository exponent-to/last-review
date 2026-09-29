/** Accumulates wall time into simulation ticks without tying rules to animation FPS. */
export function createClock(stepMs = 1000, maxElapsedMs = 1000) {
  if (!Number.isFinite(stepMs) || stepMs <= 0 || !Number.isFinite(maxElapsedMs) || maxElapsedMs <= 0) {
    throw new Error('Clock durations must be positive finite numbers.');
  }
  let remainder = 0;
  return {
    consume(elapsedMs: number, speed: 0 | 1 | 2 | 4): number {
      if (speed === 0) { remainder = 0; return 0; }
      if (!Number.isFinite(elapsedMs) || elapsedMs <= 0) return 0;
      remainder += Math.min(elapsedMs, maxElapsedMs) * speed;
      const ticks = Math.floor(remainder / stepMs);
      remainder -= ticks * stepMs;
      return ticks;
    },
    reset() { remainder = 0; },
  };
}
