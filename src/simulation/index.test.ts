import { describe, expect, it } from 'vitest';
import { advance, createInitialState, dispatch, parseSave, serializeSave, type GameState } from './index';

function running(overrides: Partial<GameState> = {}): GameState {
  return { ...createInitialState(), production: 'parts', ...overrides };
}

function freezeState(state: GameState): GameState {
  state.log.forEach(Object.freeze);
  Object.freeze(state.log);
  return Object.freeze(state);
}

describe('fixed simulation ticks', () => {
  it('produces the same result with batch or individual ticks, including depletion', () => {
    const initial = running({ workers: 3 });
    const batch = advance(initial, 10);
    const individual = Array.from({ length: 10 }).reduce<GameState>(state => advance(state), initial);
    expect(batch).toEqual(individual);
    expect(batch).toMatchObject({ tick: 10, goods: 20, materials: 0 });
    expect(batch.log.at(-1)).toEqual({ tick: 7, message: 'Materials depleted. Buy supplies to resume production.' });
  });

  it('pauses all time and production without losing state', () => {
    const state = running({ speed: 0 });
    expect(advance(state, 10)).toBe(state);
    expect(advance(state, 0)).toBe(state);
  });

  it('leaves speed multiplication to the outer clock', () => {
    expect(advance(running({ speed: 4 }), 2)).toMatchObject({ tick: 2, goods: 2, materials: 18 });
  });

  it('advances time while idle without consuming materials', () => {
    expect(advance(createInitialState(), 3)).toMatchObject({ tick: 3, goods: 0, materials: 20 });
  });

  it('clamps production to available materials and resumes after buying supplies', () => {
    const depleted = advance(running({ materials: 2, workers: 6 }), 2);
    expect(depleted).toMatchObject({ materials: 0, goods: 2, production: 'parts' });
    expect(advance(dispatch(depleted, { type: 'buy-materials' }))).toMatchObject({ materials: 4, goods: 8 });
  });

  it.each([-1, 0.5, NaN, Infinity, 10_001])('rejects invalid tick batch %s', ticks => {
    expect(() => advance(running(), ticks)).toThrow('Tick count');
  });

  it('prevents integer overflow', () => {
    expect(() => advance(running({ tick: Number.MAX_SAFE_INTEGER }))).toThrow('tick limit');
    expect(advance(running({ goods: Number.MAX_SAFE_INTEGER }))).toMatchObject({ goods: Number.MAX_SAFE_INTEGER, materials: 20 });
  });
});

describe('workshop commands', () => {
  it('buys materials, hires workers, produces goods, and sells for the stated prices', () => {
    let state = createInitialState();
    state = dispatch(state, { type: 'buy-materials' });
    state = dispatch(state, { type: 'hire-worker' });
    state = dispatch(state, { type: 'set-production', production: 'parts' });
    state = advance(state, 3);
    expect(state).toMatchObject({ credits: 110, materials: 24, goods: 6, workers: 2 });
    expect(dispatch(state, { type: 'sell-goods' })).toMatchObject({ credits: 182, goods: 0 });
  });

  it('does not spend unavailable credits or hire beyond capacity', () => {
    expect(dispatch(running({ credits: 29 }), { type: 'buy-materials' })).toMatchObject({ credits: 29, materials: 20 });
    expect(dispatch(running({ credits: 99 }), { type: 'hire-worker' })).toMatchObject({ credits: 99, workers: 1 });
    expect(dispatch(running({ workers: 6 }), { type: 'hire-worker' })).toMatchObject({ credits: 240, workers: 6 });
    expect(dispatch(running(), { type: 'sell-goods' })).toMatchObject({ credits: 240, goods: 0 });
  });

  it('keeps actions available while paused', () => {
    const state = dispatch(running({ speed: 0 }), { type: 'buy-materials' });
    expect(state).toMatchObject({ speed: 0, tick: 0, credits: 210, materials: 30 });
  });

  it('never mutates incoming state or log entries', () => {
    const initial = freezeState(running());
    const before = serializeSave(initial);
    advance(initial, 25);
    dispatch(initial, { type: 'buy-materials' });
    dispatch(initial, { type: 'hire-worker' });
    dispatch(initial, { type: 'sell-goods' });
    dispatch(initial, { type: 'set-speed', speed: 0 });
    dispatch(initial, { type: 'set-production', production: 'idle' });
    expect(serializeSave(initial)).toBe(before);
  });

  it('bounds log growth', () => {
    let state = running();
    for (let action = 0; action < 100; action += 1) state = dispatch(state, { type: 'sell-goods' });
    expect(state.log).toHaveLength(40);
    expect(parseSave(serializeSave(state))).toEqual(state);
  });

  it('prevents resource and revenue overflow', () => {
    expect(dispatch(running({ materials: Number.MAX_SAFE_INTEGER }), { type: 'buy-materials' })).toMatchObject({ credits: 240, materials: Number.MAX_SAFE_INTEGER });
    expect(dispatch(running({ goods: Number.MAX_SAFE_INTEGER }), { type: 'sell-goods' })).toMatchObject({ credits: 240, goods: Number.MAX_SAFE_INTEGER });
  });
});

describe('versioned saves', () => {
  it('round trips a progressed game into an independent state', () => {
    const state = advance(running(), 5);
    const restored = parseSave(serializeSave(state));
    expect(restored).toEqual(state);
    expect(restored).not.toBe(state);
    expect(restored.log).not.toBe(state.log);
  });

  it.each(['{', '', 'null', '[]', '42'])('rejects malformed or non-object saves: %s', raw => {
    expect(() => parseSave(raw)).toThrow('Invalid save');
  });

  it('rejects incompatible versions and missing fields', () => {
    expect(() => parseSave(JSON.stringify({ ...running(), version: 2 }))).toThrow('unsupported save version');
    expect(() => parseSave('{"version":1}')).toThrow('tick');
  });

  it.each([
    ['tick', -1], ['tick', 0.5], ['credits', '240'], ['credits', -1],
    ['materials', null], ['goods', Number.MAX_SAFE_INTEGER + 1],
    ['workers', 0], ['workers', 7], ['speed', 3], ['production', 'weapons'],
    ['log', {}], ['log', [{ tick: 1, message: 'Future event' }]],
    ['log', [{ tick: 0, message: '' }]], ['log', [{ tick: 0, message: 123 }]],
    ['log', [{ tick: 0, message: 'x'.repeat(241) }]],
    ['log', Array.from({ length: 41 }, () => ({ tick: 0, message: 'Event' }))],
  ])('rejects corrupt %s fields', (field, value) => {
    expect(() => parseSave(JSON.stringify({ ...createInitialState(), [field]: value }))).toThrow('Invalid save');
  });

  it('rejects nonchronological logs', () => {
    const state = running({ tick: 5, log: [{ tick: 4, message: 'Later' }, { tick: 2, message: 'Earlier' }] });
    expect(() => parseSave(JSON.stringify(state))).toThrow('log entry 1 tick');
  });

  it('discards unrecognized object properties', () => {
    const raw = JSON.stringify({ ...running(), injected: 'ignored', log: [{ tick: 0, message: 'Ready', extra: 'ignored' }] });
    const parsed = parseSave(raw);
    expect(parsed).not.toHaveProperty('injected');
    expect(parsed.log[0]).not.toHaveProperty('extra');
  });

  it('validates state before serialization and limits input size', () => {
    expect(() => serializeSave(running({ credits: Infinity }))).toThrow('credits');
    expect(() => parseSave(' '.repeat(100_001))).toThrow('100,000');
  });
});
