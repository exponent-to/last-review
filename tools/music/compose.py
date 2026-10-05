#!/usr/bin/env python3
"""Compose and render the PRs please soundtrack: five synchronized loop stems.

An original, minimal dance-punk piece in E Phrygian at 125 BPM. It lives in the
mood of a long, sparse club intro: dry woodblock and cowbell ticks, a muted kick,
a quiet hypnotic synth figure, and a lot of empty space. There is no drop. The
game raises and lowers the stems over the workday (see native/music.gd):

  intro    woodblock / cowbell / rim ticks, a rare dry clap, and the dark figure
  pulse    a muted four-on-the-floor kick and a soft offbeat bass pulse
  hats     a ticking closed hat and a shaker
  air      the figure's filter opening (bright render minus dark render)
  tension  late-shift clap on 2 and 4, soft open hats, a breathing drone,
           sparse high pings, and woodblock rolls into each phrase

Every stem is exactly 16 bars long and seamless: events are rendered into a
circular buffer, and effects with memory (filters, delay) run over two passes
of the loop so the kept pass already contains the previous pass's tails. A
copy of the loop's first samples follows the loop end in each file, so Godot's
interpolation reads the true continuation at the wrap.

Requires Python 3 with numpy and scipy (pip install numpy scipy). The output
is deterministic for a given seed:

  python3 tools/music/compose.py                 # writes audio/music/*.wav
  python3 tools/music/compose.py --preview out.wav

After rendering, run `sh scripts/run.sh --headless --import`. The script also
writes each stem's .wav.import parameters (QOA compression, forward loop with
an exact loop end); existing uids are kept.
"""

import argparse
import math
import os
import sys
import wave

import numpy as np
from scipy.signal import lfilter, resample_poly

SEED = 20261004
RATE = 44100           # synthesis rate
OUT_RATE = 22050       # shipped rate (mono, 16-bit source, QOA in Godot)
BPM = 125
STEP = RATE * 60 // (BPM * 4)        # samples per sixteenth (5292, exact)
BAR = STEP * 16
BARS = 16
LOOP = BAR * BARS                    # 1,354,752 samples = 30.72 s
OUT_LOOP = LOOP * OUT_RATE // RATE   # 677,376 samples
PAD = 64                             # continuation samples written after the loop
STEMS = ["intro", "pulse", "hats", "air", "tension"]
FULL_MIX_PEAK_DB = -1.5              # all stems at full volume peak here

rng = np.random.default_rng(SEED)


def hz(midi):
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


# E Phrygian (the white keys from E). Bass root per bar: E for the first
# phrase, a half-step lift to F, back to E, then C and D leading home to E.
E2, F2, C2, D2 = 40, 41, 36, 38
ROOTS = [E2, E2, E2, E2, E2, E2, F2, F2, E2, E2, E2, E2, C2, C2, D2, D2]

# ---------------------------------------------------------------- primitives


def seconds(n):
    return np.arange(n) / RATE


def place(buf, sig, start):
    """Add sig into the circular buffer at start, wrapping past the loop end."""
    start %= LOOP
    while len(sig):
        take = min(len(sig), LOOP - start)
        buf[start:start + take] += sig[:take]
        sig = sig[take:]
        start = 0


def at(bar, step, offset=0.0):
    return int(round((bar * 16 + step) * STEP + offset))


def circular(effect, x):
    """Run a stateful effect over two passes of the loop; keep the second."""
    return effect(np.concatenate([x, x]))[LOOP:]


def polyblep(phase, dt):
    out = np.zeros_like(phase)
    m = phase < dt
    x = phase[m] / dt[m]
    out[m] = x + x - x * x - 1.0
    m = phase > 1.0 - dt
    x = (phase[m] - 1.0) / dt[m]
    out[m] = x * x + x + x + 1.0
    return out


def saw(freq, n, phase0=0.0):
    """Band-limited (PolyBLEP) sawtooth; freq may be a scalar or an array."""
    dt = np.broadcast_to(np.asarray(freq, dtype=float) / RATE, (n,))
    phase = (phase0 + np.concatenate([[0.0], np.cumsum(dt[:-1])])) % 1.0
    return 2.0 * phase - 1.0 - polyblep(phase, dt)


def pulse(freq, n, width=0.5, phase0=0.0):
    """Band-limited pulse as the difference of two PolyBLEP saws."""
    return 0.5 * (saw(freq, n, phase0) - saw(freq, n, phase0 + width)) + (width - 0.5)


def sine(freq, n, phase0=0.0):
    dt = np.broadcast_to(np.asarray(freq, dtype=float) / RATE, (n,))
    phase = phase0 + np.concatenate([[0.0], np.cumsum(dt[:-1])])
    return np.sin(2.0 * np.pi * phase)


def noise(n):
    return rng.uniform(-1.0, 1.0, n)


def adsr(n, attack, decay, sustain, release, gate):
    """Linear attack, exponential decay to sustain, exponential release after gate."""
    t = seconds(n)
    env = np.where(t < attack, t / max(attack, 1e-6),
                   sustain + (1.0 - sustain) * np.exp(-(t - attack) / max(decay, 1e-6)))
    after = t >= gate
    if after.any():
        level = env[np.argmax(after)]
        env[after] = level * np.exp(-(t[after] - gate) / max(release, 1e-6))
    return env


def perc_env(n, attack, decay):
    t = seconds(n)
    return np.minimum(1.0, t / max(attack, 1e-6)) * np.exp(-t / decay)


def biquad(kind, freq, q=0.707):
    """RBJ cookbook biquad coefficients."""
    w = 2.0 * np.pi * freq / RATE
    alpha = np.sin(w) / (2.0 * q)
    cw = np.cos(w)
    if kind == "lp":
        b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
    elif kind == "hp":
        b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
    elif kind == "bp":
        b = [alpha, 0.0, -alpha]
    else:
        raise ValueError(kind)
    a = [1 + alpha, -2 * cw, 1 - alpha]
    return np.array(b) / a[0], np.array(a) / a[0]


def filt(kind, x, freq, q=0.707):
    b, a = biquad(kind, freq, q)
    return lfilter(b, a, x)


def svf_lowpass(x, cutoff, resonance=0.0):
    """Resonant TPT state-variable low-pass with a per-sample cutoff (Hz)."""
    n = len(x)
    c = np.clip(np.broadcast_to(np.asarray(cutoff, dtype=float), (n,)), 20.0, RATE * 0.45)
    g = np.tan(np.pi * c / RATE)
    k = 2.0 - 2.0 * min(resonance, 0.97)
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    xs, A1, A2, A3 = x.tolist(), a1.tolist(), a2.tolist(), a3.tolist()
    out = [0.0] * n
    ic1 = ic2 = 0.0
    for i in range(n):
        v3 = xs[i] - ic2
        v1 = A1[i] * ic1 + A2[i] * v3
        v2 = ic2 + A2[i] * ic1 + A3[i] * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        out[i] = v2
    return np.array(out)


def feedback_delay(x, steps, feedback, damp_hz, mix):
    """Tempo-synced echo with a damped feedback path (blockwise, exact)."""
    d = int(steps * STEP)
    b, a = biquad("lp", damp_hz, 0.6)
    zi = np.zeros(2)
    echo = np.zeros_like(x)
    for start in range(d, len(x), d):
        end = min(start + d, len(x))
        src = x[start - d:end - d] + feedback * echo[start - d:end - d]
        echo[start:end], zi = lfilter(b, a, src, zi=zi)
    return x + mix * echo


def cents(c):
    return 2.0 ** (c / 1200.0)


def pattern(text):
    """'x..o' -> [(step, velocity)]; X=1.0, x=0.75, o=0.5, -=0.3, .=rest."""
    levels = {"X": 1.0, "x": 0.75, "o": 0.5, "-": 0.3}
    return [(i, levels[ch]) for i, ch in enumerate(text) if ch in levels]


def human(v, spread=0.06):
    return float(np.clip(v * (1.0 + rng.uniform(-spread, spread)), 0.0, 1.2))


# --------------------------------------------------------------- instruments


def woodblock(freq, vel):
    n = int(0.16 * RATE)
    t = seconds(n)
    body = (np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.045)
            + 0.38 * np.sin(2 * np.pi * freq * 2.71 * t) * np.exp(-t / 0.018)
            + 0.12 * np.sin(2 * np.pi * freq * 4.95 * t) * np.exp(-t / 0.008))
    click = filt("bp", noise(n), 3200, 1.2) * np.exp(-t / 0.0015)
    sig = (body + 0.6 * click) * np.minimum(1.0, t / 0.0004)
    return vel * sig


def cowbell_tick(vel):
    n = int(0.12 * RATE)
    t = seconds(n)
    tone = pulse(562.0, n) + 0.8 * pulse(845.0, n)
    tone = filt("bp", tone, 2400, 1.6)
    env = np.exp(-t / 0.028) * 0.85 + 0.15 * np.exp(-t / 0.09)
    return vel * tone * env * np.minimum(1.0, t / 0.0005)


def rim(vel):
    n = int(0.08 * RATE)
    t = seconds(n)
    sig = (np.sin(2 * np.pi * 1720 * t) * np.exp(-t / 0.010)
           + 0.5 * np.sin(2 * np.pi * 480 * t) * np.exp(-t / 0.018)
           + 0.7 * filt("bp", noise(n), 2600, 1.5) * np.exp(-t / 0.004))
    return vel * sig * np.minimum(1.0, t / 0.0003)


def clap(vel, tail=0.07):
    n = int(0.35 * RATE)
    t = seconds(n)
    raw = noise(n)
    env = np.zeros(n)
    for k, off in enumerate([0.0, 0.0095, 0.0185, 0.0285]):
        tt = t - off
        burst = np.where(tt >= 0, np.exp(-np.maximum(tt, 0) / 0.0032), 0.0)
        env = np.maximum(env, burst * (0.85 if k < 3 else 1.0))
    last = t - 0.0285
    env = np.maximum(env, np.where(last >= 0, 0.75 * np.exp(-np.maximum(last, 0) / tail), 0.0))
    sig = filt("bp", raw * env, 1150, 0.9)
    sig = filt("hp", sig, 480)
    return vel * 2.2 * sig


def kick_muted(vel):
    n = int(0.42 * RATE)
    t = seconds(n)
    freq = 47.0 + (128.0 - 47.0) * np.exp(-t / 0.028)
    body = sine(freq, n) * np.exp(-t / 0.13) * np.minimum(1.0, t / 0.002)
    body = np.tanh(1.6 * body) / np.tanh(1.6)
    body = filt("lp", body, 700, 0.6)   # muted: no click, no top
    return vel * body


def bass_note(midi, vel, length):
    n = int((length + 0.12) * RATE)
    t = seconds(n)
    f = hz(midi)
    osc = (0.5 * saw(f * cents(-6), n) + 0.5 * saw(f * cents(6), n, 0.37)
           + 0.6 * sine(f, n))
    cutoff = 170.0 + 520.0 * np.exp(-t / 0.055)
    sig = svf_lowpass(osc, cutoff, 0.35)
    env = adsr(n, 0.004, 0.09, 0.45, 0.025, length)
    return vel * np.tanh(1.4 * sig * env) / np.tanh(1.4)


def hat(vel, decay=0.028):
    n = int((decay * 7 + 0.01) * RATE)
    t = seconds(n)
    metal = sum(pulse(f * 1.65, n) for f in (205.3, 304.4, 369.6, 522.7, 540.0, 800.0)) / 6.0
    sig = 0.55 * metal + 0.45 * noise(n)
    sig = filt("bp", sig, 8200, 0.8)
    sig = filt("hp", sig, 6200)
    return vel * 2.4 * sig * np.exp(-t / decay) * np.minimum(1.0, t / 0.0004)


def shaker(vel):
    n = int(0.12 * RATE)
    t = seconds(n)
    sig = filt("bp", noise(n), 6200, 1.1)
    env = np.minimum(1.0, t / 0.007) * np.exp(-t / 0.03)
    return vel * 1.8 * sig * env


def figure_note(midi, vel, bright, lfo):
    """The quiet figure: pulse + detuned saw into a resonant, enveloped low-pass."""
    gate = 0.27
    n = int((gate + 0.45) * RATE)
    t = seconds(n)
    f = hz(midi)
    osc = pulse(f, n, 0.38) + 0.35 * saw(f * cents(7), n, 0.21)
    if bright:
        cutoff = (680.0 + 2500.0 * np.exp(-t / 0.11)) * lfo
        res = 0.55
    else:
        cutoff = (300.0 + 640.0 * np.exp(-t / 0.07)) * lfo
        res = 0.25
    sig = svf_lowpass(osc, cutoff, res)
    env = adsr(n, 0.003, 0.2, 0.0, 0.06, gate)
    return vel * sig * env


def ping(midi, vel):
    n = int(0.6 * RATE)
    t = seconds(n)
    f = hz(midi)
    tone = np.sin(2 * np.pi * f * t) + 0.18 * np.sin(2 * np.pi * f * 3.0 * t) * np.exp(-t / 0.05)
    return vel * tone * np.exp(-t / 0.16) * np.minimum(1.0, t / 0.002)


# ---------------------------------------------------------------------- stems

FIGURE = [(0, 64, 1.0), (3, 59, 0.62), (6, 64, 0.8), (10, 62, 0.7), (13, 59, 0.6)]
# The fourth bar of each phrase adds a pickup note on the last sixteenths.
PICKUPS = {3: 67, 7: 69, 11: 67, 15: 65}


def figure_events():
    events = []
    for bar in range(BARS):
        lfo = 1.0 + 0.18 * math.sin(2 * math.pi * (bar + 0.5) / 8.0)
        for step, midi, vel in FIGURE:
            events.append((bar, step, midi, human(vel, 0.05), lfo))
        if bar in PICKUPS:
            events.append((bar, 14, PICKUPS[bar], human(0.55, 0.05), lfo))
    return events


def render_figure(bright):
    buf = np.zeros(LOOP)
    cache = {}
    for bar, step, midi, vel, lfo in figure_events():
        key = (midi, round(lfo, 4))
        if key not in cache:
            cache[key] = figure_note(midi, 1.0, bright, lfo)
        place(buf, vel * cache[key], at(bar, step))
    return buf


def figure_echo(x):
    return circular(lambda s: feedback_delay(s, 3, 0.38, 1900, 0.32), x)


def intro_percussion():
    """The morning bed's ticks; the dark figure is added in main()."""
    buf = np.zeros(LOOP)
    wb_hi = [pattern("..o....x..o....."), pattern("..o....x....o..x")]
    wb_lo = [pattern("x..........o...."), pattern("x......o........")]
    cow = [pattern("......o........."), pattern("......o.......-.")]
    rims = [pattern("........-......."), pattern("................")]
    for bar in range(BARS):
        b = bar % 2
        for step, v in wb_hi[b]:
            place(buf, 0.30 * woodblock(1240, human(v)), at(bar, step))
        for step, v in wb_lo[b]:
            place(buf, 0.34 * woodblock(830, human(v)), at(bar, step))
        for step, v in cow[b]:
            place(buf, 0.15 * cowbell_tick(human(v)), at(bar, step))
        for step, v in rims[b]:
            place(buf, 0.22 * rim(human(v)), at(bar, step))
        if b == 1:
            place(buf, 0.34 * clap(human(0.8)), at(bar, 12))
    # A small flam into the top of the loop.
    place(buf, 0.18 * clap(0.5), at(15, 15))
    return buf


def stem_pulse():
    buf = np.zeros(LOOP)
    for bar in range(BARS):
        for beat in range(4):
            if bar == BARS - 1 and beat == 3:
                continue   # a breath before the loop comes around
            place(buf, 0.78 * kick_muted(human(0.9 if beat in (0, 2) else 0.8, 0.04)), at(bar, beat * 4))
    cache = {}
    for bar in range(BARS):
        root = ROOTS[bar]
        steps = [(2, 0.55), (6, 0.5), (10, 0.55), (14, 0.5)]
        if bar % 4 == 3:
            steps.append((15, 0.3))
        for step, v in steps:
            midi = root + (12 if (step == 15) else 0)
            key = midi
            if key not in cache:
                cache[key] = bass_note(midi, 1.0, 0.15)
            place(buf, 0.62 * human(v, 0.05) * cache[key], at(bar, step))
    return buf


def stem_hats():
    buf = np.zeros(LOOP)
    swing = 0.0036 * RATE
    hat_levels = [0.26, 0.17, 0.62, 0.2]
    shaker_levels = [0.0, 0.34, 0.12, 0.3]
    for bar in range(BARS):
        for step in range(16):
            offset = swing if step % 2 else 0.0
            pos = step % 4
            place(buf, 0.26 * hat(human(hat_levels[pos], 0.12), 0.024 if pos != 2 else 0.034), at(bar, step, offset))
            if shaker_levels[pos]:
                place(buf, 0.14 * shaker(human(shaker_levels[pos], 0.15)), at(bar, step, offset))
    return buf


def stem_tension():
    buf = np.zeros(LOOP)
    for bar in range(BARS):
        for step in (4, 12):
            place(buf, 0.40 * clap(human(0.85), 0.06), at(bar, step))
        for step in (2, 6, 10, 14):
            place(buf, 0.10 * hat(human(0.6, 0.1), 0.11), at(bar, step))
        if bar % 4 == 3:
            for k, step in enumerate(range(12, 16)):
                place(buf, 0.26 * woodblock(1240, 0.35 + 0.15 * k), at(bar, step))
    pings = [(1, 9, 77, 0.8), (3, 3, 76, 0.6), (5, 9, 77, 0.8), (7, 11, 72, 0.6),
             (9, 9, 77, 0.8), (11, 3, 76, 0.6), (13, 9, 76, 0.7), (15, 7, 71, 0.6)]
    tones = np.zeros(LOOP)
    for bar, step, midi, v in pings:
        place(tones, 0.11 * ping(midi, human(v)), at(bar, step))
    tones = circular(lambda s: feedback_delay(s, 3, 0.45, 2600, 0.45), tones)
    buf += tones
    # A thin drone on B and E: the fifth and root of E, a maj7 and #11 over F,
    # so it holds still while the bass moves under it. Frequencies are rounded
    # to whole cycles per loop and every modulation divides the loop, so the
    # two-pass render is exactly periodic.
    span = 2 * LOOP
    t = np.arange(span) / RATE
    loop_seconds = LOOP / RATE
    drone = np.zeros(span)
    for midi, detune, level in ((59, -5, 0.5), (59, 6, 0.5), (64, -4, 0.4), (64, 5, 0.4), (71, 0, 0.12)):
        f = round(hz(midi) * cents(detune) * loop_seconds) / loop_seconds
        drone += level * saw(f, span, (midi * 0.137) % 1.0)
    lfo_cut = 0.5 - 0.5 * np.cos(2 * np.pi * t / (loop_seconds / 2))      # 8-bar sweep
    lfo_amp = 0.72 + 0.28 * (0.5 - 0.5 * np.cos(2 * np.pi * t / (loop_seconds / 4)))
    drone = svf_lowpass(drone, 420.0 + 900.0 * lfo_cut, 0.45) * lfo_amp
    drone = filt("hp", drone, 160)
    buf += 0.075 * drone[LOOP:]
    return buf


def soft_limit(x, ratio=2.0):
    """Round off the sharpest transients (memoryless, so the loop is unchanged):
    a tanh knee at 1/ratio of the peak takes the top few dB off woodblock and
    clap attacks while leaving quieter material nearly linear."""
    knee = np.max(np.abs(x)) / ratio
    return knee * np.tanh(x / knee)


def clean(x):
    """Remove DC and sub-rumble without breaking the loop."""
    return circular(lambda s: filt("hp", s, 28, 0.6), x)


def to_out_rate(x):
    """Downsample with circular padding so the loop seam is preserved."""
    pad = 4096
    wrapped = np.concatenate([x[-pad:], x, x[:pad]])
    y = resample_poly(wrapped, OUT_RATE, RATE)
    p = pad * OUT_RATE // RATE
    return y[p:p + OUT_LOOP]


def quantize(x):
    dither = (rng.uniform(-0.5, 0.5, len(x)) + rng.uniform(-0.5, 0.5, len(x))) / 32768.0
    return np.clip(np.round((x + dither) * 32767.0), -32768, 32767).astype("<i2")


def write_wav(path, samples, rate=OUT_RATE):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(samples.tobytes())


IMPORT_PARAMS = """[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode=2
edit/loop_begin=0
edit/loop_end={loop_end}
compress/mode=2
"""


def write_import(path):
    """Write the stem's import parameters, keeping any uid Godot assigned."""
    head = '[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n'
    if os.path.exists(path):
        with open(path) as f:
            text = f.read()
        head = text.split("[params]")[0]
    with open(path, "w") as f:
        f.write(head.rstrip("\n") + "\n\n" + IMPORT_PARAMS.format(loop_end=OUT_LOOP))


def db(x):
    return 20.0 * math.log10(max(x, 1e-12))


def rms(x):
    return float(np.sqrt(np.mean(np.square(x))))


def loudness(x, rate=RATE):
    """Ungated K-weighted loudness (ITU-R BS.1770 filters), in LUFS."""
    k = math.tan(math.pi * 1681.974450955533 / rate)
    q = 0.7071752369554196
    vh = 10 ** (3.999843853973347 / 20.0)
    vb = vh ** 0.4996667741545416
    a0 = 1 + k / q + k * k
    shelf_b = [(vh + vb * k / q + k * k) / a0, 2 * (k * k - vh) / a0, (vh - vb * k / q + k * k) / a0]
    shelf_a = [1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    k = math.tan(math.pi * 38.13547087602444 / rate)
    q = 0.5003270373238773
    a0 = 1 + k / q + k * k
    hp_a = [1.0, 2 * (k * k - 1) / a0, (1 - k / q + k * k) / a0]
    y = lfilter([1.0, -2.0, 1.0], hp_a, lfilter(shelf_b, shelf_a, np.concatenate([x, x])))[len(x):]
    return -0.691 + 10.0 * math.log10(max(float(np.mean(y * y)), 1e-20))


# Each stem is set to a designed loudness before the shared peak scaling, so
# the layers sit in a fixed balance: the intro and the kick-and-bass pulse
# about level, hats and the late layer tucked beneath. `air` keeps the intro's
# gain, because intro + air must equal the bright figure exactly.
FIGURE_LEVEL = 0.2     # the dark figure sits a few dB under the ticks
OPEN_LIFT_DB = 3.0     # the fully open figure's loudness over the dark one
STEM_LUFS = {"intro": -24.0, "pulse": -25.0, "hats": -29.5, "tension": -27.5}


# Layer volumes for the preview, in the spirit of native/music.gd's table.
PREVIEW = [
    # bars, intro, pulse, hats, air, tension, level, cutoff
    (8, 1.0, 0.0, 0.0, 0.0, 0.0, 0.8, 20000),    # morning reading
    (8, 1.0, 0.8, 0.0, 0.0, 0.0, 0.85, 20000),   # 10:00 kick and bass pulse
    (8, 1.0, 1.0, 0.75, 0.4, 0.0, 0.85, 20000),  # 13:00 hat ticks, figure opening
    (12, 1.0, 1.0, 1.0, 1.0, 1.0, 0.85, 20000),  # 17:00 busier, tenser
    (8, 1.0, 0.0, 0.0, 0.0, 0.0, 0.55, 3200),    # end of day: sparse and soft
]


def render_preview(stems, path):
    """A ~85 s walk through the workday at the in-game layer volumes."""
    rate = OUT_RATE
    bar = OUT_LOOP // BARS
    total = sum(p[0] for p in PREVIEW) * bar
    names = STEMS
    gains = {name: np.zeros(total) for name in names}
    level = np.zeros(total)
    cutoff = np.zeros(total)
    prev = None
    pos = 0
    fade = 2 * bar
    for bars, *values in PREVIEW:
        target = dict(zip(names + ["level", "cutoff"], values))
        n = bars * bar
        ramp = np.minimum(1.0, np.arange(n) / fade) if prev else np.ones(n)
        for name in names + ["level"]:
            start = prev[name] if prev else target[name]
            seg = start + (target[name] - start) * ramp
            (level if name == "level" else gains[name])[pos:pos + n] = seg
        c0 = prev["cutoff"] if prev else target["cutoff"]
        cutoff[pos:pos + n] = np.exp(np.log(c0) + (np.log(target["cutoff"]) - np.log(c0)) * ramp)
        prev = target
        pos += n
    mix = np.zeros(total)
    for name in names:
        reps = int(math.ceil(total / OUT_LOOP))
        mix += np.tile(stems[name], reps)[:total] * gains[name]
    # A one-pole low-pass for the end-of-day softening, then the master level
    # and a two-bar fade at the very end.
    a = np.exp(-2 * np.pi * np.minimum(cutoff, rate * 0.45) / rate)
    out = np.empty(total)
    z = 0.0
    for i, (s, k) in enumerate(zip(mix.tolist(), a.tolist())):
        z = (1 - k) * s + k * z
        out[i] = z
    out *= level
    out[-fade:] *= np.linspace(1.0, 0.0, fade)
    out[:int(0.01 * rate)] *= np.linspace(0.0, 1.0, int(0.01 * rate))
    peak = np.max(np.abs(out))
    write_wav(path, quantize(out), rate)
    print("preview  %s  %.1f s  peak %.1f dBFS  rms %.1f dBFS" % (path, total / rate, db(peak), db(rms(out))))


def seam_report(x):
    """Jump across the wrap versus the loop's own sample-to-sample motion."""
    diffs = np.abs(np.diff(x))
    seam = abs(float(x[0]) - float(x[-1]))
    return seam, float(np.percentile(diffs, 99.9))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    parser.add_argument("--out", default=os.path.join(root, "audio", "music"))
    parser.add_argument("--preview", help="also write a ~85 s preview mix to this WAV path")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)

    print("rendering at %d Hz: %d BPM, %d bars, loop %d samples (%.2f s)" % (RATE, BPM, BARS, LOOP, LOOP / RATE))
    dark = figure_echo(render_figure(bright=False))
    bright = figure_echo(render_figure(bright=True))
    # The open figure is brighter and a little louder than the dark one, but
    # only by OPEN_LIFT_DB, so opening the filter never shouts.
    bright *= 10 ** ((loudness(dark) + OPEN_LIFT_DB - loudness(bright)) / 20.0)
    percussion = soft_limit(clean(intro_percussion()))
    figure = clean(FIGURE_LEVEL * dark)
    print("intro balance: ticks %.1f LUFS, figure %.1f LUFS (before stem levels)" % (
        loudness(percussion), loudness(figure)))
    # The figure stays linear: intro + air must sum to the bright figure.
    raw = {
        "intro": percussion + figure,
        "pulse": soft_limit(clean(stem_pulse()), 1.6),
        "hats": soft_limit(clean(stem_hats())),
        "air": clean(FIGURE_LEVEL * (bright - dark)),
        "tension": soft_limit(clean(stem_tension())),
    }
    for name, target in STEM_LUFS.items():
        gain = 10 ** ((target - loudness(raw[name])) / 20.0)
        raw[name] *= gain
        if name == "intro":
            raw["air"] *= gain
    full = sum(raw.values())
    scale = 10 ** (FULL_MIX_PEAK_DB / 20.0) / np.max(np.abs(full))
    stems = {}
    for name in STEMS:
        out = to_out_rate(raw[name] * scale)
        samples = quantize(out)
        data = np.concatenate([samples, samples[:PAD]])
        wav_path = os.path.join(args.out, name + ".wav")
        write_wav(wav_path, data)
        write_import(wav_path + ".import")
        stems[name] = samples.astype(float) / 32768.0
        seam, typical = seam_report(stems[name])
        print("%-8s peak %6.1f dBFS  rms %6.1f dBFS  %6.1f LUFS  seam jump %.4f (99.9%% step %.4f)  %d+%d samples  %d bytes" % (
            name, db(np.max(np.abs(stems[name]))), db(rms(stems[name])), loudness(stems[name], OUT_RATE),
            seam, typical, OUT_LOOP, PAD, os.path.getsize(wav_path)))
    for label, mix in (
            ("morning", {"intro": 1.0}),
            ("early", {"intro": 1.0, "pulse": 0.8}),
            ("mid", {"intro": 1.0, "pulse": 1.0, "hats": 0.7, "air": 0.45}),
            ("late", {name: 1.0 for name in STEMS})):
        x = sum(stems[n] * g for n, g in mix.items())
        print("mix %-8s peak %6.1f dBFS  rms %6.1f dBFS  %6.1f LUFS" % (
            label, db(np.max(np.abs(x))), db(rms(x)), loudness(x, OUT_RATE)))
    if args.preview:
        render_preview(stems, args.preview)
    return 0


if __name__ == "__main__":
    sys.exit(main())
