import { describe, expect, it } from 'vitest';
import { createClock } from './clock';

describe('fixed-step clock', () => {
  it('produces the same ticks across different frame rates', () => {
    const slow = createClock();
    const fast = createClock();
    let slowTicks = 0;
    let fastTicks = 0;
    for (let i = 0; i < 20; i++) slowTicks += slow.consume(100, 1);
    for (let i = 0; i < 100; i++) fastTicks += fast.consume(20, 1);
    expect(slowTicks).toBe(2);
    expect(fastTicks).toBe(slowTicks);
  });
  it('applies speed once and clears partial time when paused', () => {
    const clock = createClock();
    expect(clock.consume(250, 4)).toBe(1);
    expect(clock.consume(500, 1)).toBe(0);
    expect(clock.consume(10000, 0)).toBe(0);
    expect(clock.consume(500, 1)).toBe(0);
  });
  it('bounds long frame gaps and discards hidden-tab time on reset', () => {
    const clock = createClock();
    expect(clock.consume(60000, 2)).toBe(2);
    clock.consume(900, 1);
    clock.reset();
    expect(clock.consume(100, 1)).toBe(0);
    expect(clock.consume(NaN, 1)).toBe(0);
  });
});
