/** Serializable, deterministic game state. Time advances only through advance(). */
export interface GameState {
  version: 1;
  tick: number;
  credits: number;
  materials: number;
  goods: number;
  workers: number;
  production: 'idle' | 'parts';
  speed: 0 | 1 | 2 | 4;
  log: Array<{ tick: number; message: string }>;
}

export type GameCommand =
  | { type: 'set-speed'; speed: GameState['speed'] }
  | { type: 'set-production'; production: GameState['production'] }
  | { type: 'buy-materials' }
  | { type: 'sell-goods' }
  | { type: 'hire-worker' };

const LOG_LIMIT = 40;
const MAX_BATCH_TICKS = 10_000;

export function createInitialState(): GameState {
  return {
    version: 1,
    tick: 0,
    credits: 240,
    materials: 20,
    goods: 0,
    workers: 1,
    production: 'idle',
    speed: 1,
    log: [{ tick: 0, message: 'Workshop ready. Select parts production to begin.' }],
  };
}

function record(state: GameState, message: string): GameState {
  return {
    ...state,
    log: [...state.log, { tick: state.tick, message }].slice(-LOG_LIMIT),
  };
}

/** Fixed simulation ticks; the caller translates wall time and speed into ticks. */
export function advance(state: GameState, ticks = 1): GameState {
  if (!Number.isSafeInteger(ticks) || ticks < 0 || ticks > MAX_BATCH_TICKS) {
    throw new Error(`Tick count must be an integer between 0 and ${MAX_BATCH_TICKS}.`);
  }
  if (state.speed === 0 || ticks === 0) return state;
  if (!Number.isSafeInteger(state.tick + ticks)) {
    throw new Error('Simulation tick limit reached.');
  }

  let next = state;
  for (let step = 0; step < ticks; step += 1) {
    const produced = next.production === 'parts'
      ? Math.min(next.workers, next.materials, Number.MAX_SAFE_INTEGER - next.goods)
      : 0;
    next = {
      ...next,
      tick: next.tick + 1,
      materials: next.materials - produced,
      goods: next.goods + produced,
    };
    if (produced > 0 && next.materials === 0) {
      next = record(next, 'Materials depleted. Buy supplies to resume production.');
    }
  }
  return next;
}

export function dispatch(state: GameState, command: GameCommand): GameState {
  switch (command.type) {
    case 'set-speed':
      if (![0, 1, 2, 4].includes(command.speed)) throw new Error('Invalid simulation speed.');
      if (state.speed === command.speed) return state;
      return record({ ...state, speed: command.speed }, command.speed === 0
        ? 'Simulation paused.'
        : `Simulation running at ${command.speed}× speed.`);
    case 'set-production':
      if (command.production !== 'idle' && command.production !== 'parts') {
        throw new Error('Invalid production mode.');
      }
      if (state.production === command.production) return state;
      return record({ ...state, production: command.production }, command.production === 'parts'
        ? 'Parts production selected.'
        : 'Production set to idle.');
    case 'buy-materials':
      if (state.credits < 30) return record(state, 'Need 30 credits to buy 10 materials.');
      if (!Number.isSafeInteger(state.materials + 10)) return record(state, 'Material storage limit reached.');
      return record({ ...state, credits: state.credits - 30, materials: state.materials + 10 }, 'Bought 10 materials for 30 credits.');
    case 'sell-goods': {
      if (state.goods === 0) return record(state, 'No finished goods to sell.');
      const revenue = state.goods * 12;
      if (!Number.isSafeInteger(revenue) || !Number.isSafeInteger(state.credits + revenue)) {
        return record(state, 'Credit limit reached. Goods were not sold.');
      }
      return record({ ...state, credits: state.credits + revenue, goods: 0 }, `Sold ${state.goods} goods for ${revenue} credits.`);
    }
    case 'hire-worker':
      if (state.workers >= 6) return record(state, 'Workshop is fully staffed at 6 workers.');
      if (state.credits < 100) return record(state, 'Need 100 credits to hire a worker.');
      return record({ ...state, credits: state.credits - 100, workers: state.workers + 1 }, 'Hired a worker for 100 credits.');
    default:
      throw new Error('Unknown game command.');
  }
}

function invalidSave(reason: string): never {
  throw new Error(`Invalid save: ${reason}`);
}

function object(value: unknown, label: string): Record<string, unknown> {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    return invalidSave(`${label} must be an object.`);
  }
  return value as Record<string, unknown>;
}

function integer(value: unknown, label: string, min = 0, max = Number.MAX_SAFE_INTEGER): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < min || value > max) {
    return invalidSave(`${label} must be an integer between ${min} and ${max}.`);
  }
  return value;
}

function validateSave(value: unknown): GameState {
  const data = object(value, 'game state');
  if (data.version !== 1) invalidSave('unsupported save version; expected version 1.');
  const tick = integer(data.tick, 'tick');
  const credits = integer(data.credits, 'credits');
  const materials = integer(data.materials, 'materials');
  const goods = integer(data.goods, 'goods');
  const workers = integer(data.workers, 'workers', 1, 6);
  if (data.production !== 'idle' && data.production !== 'parts') invalidSave('unknown production mode.');
  if (data.speed !== 0 && data.speed !== 1 && data.speed !== 2 && data.speed !== 4) invalidSave('unknown simulation speed.');
  if (!Array.isArray(data.log) || data.log.length > LOG_LIMIT) invalidSave(`log must be an array with at most ${LOG_LIMIT} entries.`);
  let previousTick = 0;
  const log = data.log.map((value, index) => {
    const entry = object(value, `log entry ${index}`);
    const entryTick = integer(entry.tick, `log entry ${index} tick`, previousTick, tick);
    previousTick = entryTick;
    if (typeof entry.message !== 'string' || entry.message.trim().length === 0 || entry.message.length > 240) {
      invalidSave(`log entry ${index} message must contain 1–240 characters.`);
    }
    return { tick: entryTick, message: entry.message };
  });
  // Reconstruct the object to discard unknown properties from untrusted saves.
  return { version: 1, tick, credits, materials, goods, workers, production: data.production, speed: data.speed, log };
}

export function serializeSave(state: GameState): string {
  return JSON.stringify(validateSave(state));
}

export function parseSave(raw: string): GameState {
  if (typeof raw !== 'string' || raw.length > 100_000) invalidSave('save data must be a string under 100,000 characters.');
  let value: unknown;
  try {
    value = JSON.parse(raw);
  } catch {
    return invalidSave('malformed JSON.');
  }
  return validateSave(value);
}
