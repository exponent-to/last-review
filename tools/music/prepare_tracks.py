#!/usr/bin/env python3
"""Prepare the soundtrack's scene tracks from the author's masters.

Each chosen take (48 kHz WAV, made with Suno) is cut to what its scene needs,
loudness-matched to Motorik Minor (-16.3 LUFS integrated, BS.1770 gated), and
encoded as Ogg Vorbis for audio/music/. A loop plays its opening once, then
cycles a section chosen so its end matches its start in rhythm and texture,
with a crossfade baked into the tail and the restart point as the .import
loop_offset; one-shots get a fade-out.

  python3 tools/music/prepare_tracks.py ~/Downloads

reads "PRs please - <Slot>[ (1)].wav" from that folder (see TRACKS for which
take each slot uses) and writes audio/music/<name>.ogg plus .ogg.import.
The masters themselves are not committed. Needs numpy, scipy, and ffmpeg (its
built-in Vorbis encoder; libvorbis via `oggenc` would sound slightly better
in the top octave). Run `sh scripts/run.sh --headless --import` afterwards.
"""

import argparse
import math
import os
import subprocess
import sys
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import lfilter

RATE = 48000
TARGET_LUFS = -16.3       # Motorik Minor's integrated loudness
QUALITY = 5               # ffmpeg vorbis -q:a 5, about 110 kbps for this material
CROSSFADE = 3.0           # seconds of baked loop crossfade

# name: (master file, kind, where). A "loop" searches loop start a and end b
# within where = ((a_min, a_max), (b_min, b_max)) seconds; a "once" track is
# cut at `where` seconds and faded over its last FADE seconds.
TRACKS = {
    "title": ("PRs please - Title (1).wav", "loop", ((25.0, 60.0), (140.0, 156.0))),
    "cold_open": ("PRs please - Cold Open.wav", "once", 75.0),
    # Morning stays in its opening, before the band comes in.
    "morning": ("PRs please - Morning.wav", "loop", ((8.0, 22.0), (48.0, 62.0))),
    "after_hours": ("PRs please - After Hours.wav", "loop", ((25.0, 60.0), (140.0, 158.0))),
    "last_reviewers": ("PRs please - Last Reviewers.wav", "once", 100.0),
    "helios_prime": ("PRs please - Helios Prime.wav", "once", 100.0),
}
FADE = {"cold_open": 5.0, "last_reviewers": 10.0, "helios_prime": 10.0}


def decode(path):
    raw = subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-i", path, "-f", "f32le",
                          "-ac", "2", "-ar", str(RATE), "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, "<f4").reshape(-1, 2).astype(float)


def loudness(x):
    """BS.1770 integrated loudness at 48 kHz (400 ms blocks, 75% overlap, gated)."""
    b1 = [1.53512485958697, -2.69169618940638, 1.19839281085285]
    a1 = [1.0, -1.69065929318241, 0.73248077421585]
    b2 = [1.0, -2.0, 1.0]
    a2 = [1.0, -1.99004745483398, 0.99007225036621]
    y = lfilter(b2, a2, lfilter(b1, a1, x, axis=0), axis=0)
    p = np.sum(y ** 2, axis=1)
    block, hop = int(0.4 * RATE), int(0.1 * RATE)
    z = np.array([np.mean(p[s:s + block]) for s in range(0, len(p) - block, hop)])
    lk = -0.691 + 10 * np.log10(z + 1e-12)
    z = z[lk > -70]
    rel = -0.691 + 10 * np.log10(np.mean(z)) - 10
    z = z[-0.691 + 10 * np.log10(z) > rel]
    return -0.691 + 10 * np.log10(np.mean(z))


def onset_envelope(x):
    """Half-wave rectified change in log energy, 10 ms frames."""
    hop = RATE // 100
    m = x.mean(axis=1)
    e = np.array([np.sum(m[i:i + hop] ** 2) for i in range(0, len(m) - hop, hop)])
    d = np.diff(np.log(e + 1e-9))
    return np.maximum(d, 0.0)


def band_energies(x):
    """Log energy in 12 bands, 100 ms frames: the arrangement's texture."""
    hop = RATE // 10
    m = x.mean(axis=1)
    frames = len(m) // hop
    spec = np.abs(np.fft.rfft(m[:frames * hop].reshape(frames, hop) * np.hanning(hop), axis=1)) ** 2
    freqs = np.fft.rfftfreq(hop, 1 / RATE)
    edges = np.geomspace(60, 12000, 13)
    bands = [spec[:, (freqs >= lo) & (freqs < hi)].sum(axis=1) for lo, hi in zip(edges[:-1], edges[1:])]
    return 10 * np.log10(np.stack(bands, axis=1) + 1e-12)


def best_region(x, starts, ends):
    """The loop [a, b) (seconds) with a in `starts` and b in `ends` whose
    following 12 s match best: the onset rhythm lines up (normalized
    correlation at 10 ms) and the arrangement's band energies agree, so the
    crossfade from b back to a lands on the beat in the same texture."""
    env = np.convolve(onset_envelope(x), np.ones(4) / 4, mode="same")
    tex = band_energies(x)
    span = 1200
    best = (-1e9, 0.0, 0.0, 0.0, 0.0)
    for a in range(int(starts[0] * 100), int(starts[1] * 100), 5):
        ref = env[a:a + span] - env[a:a + span].mean()
        ref /= np.linalg.norm(ref) + 1e-12
        for b in range(int(ends[0] * 100), int(ends[1] * 100)):
            seg = env[b:b + span]
            if len(seg) < span:
                break
            seg = seg - seg.mean()
            rhythm = float(np.dot(seg, ref) / (np.linalg.norm(seg) + 1e-12))
            texture = float(np.mean(np.abs(tex[a // 10:a // 10 + 40] - tex[b // 10:b // 10 + 40])))
            score = rhythm - 0.05 * texture
            if score > best[0]:
                best = (score, a / 100.0, b / 100.0, rhythm, texture)
    return best


def make_loop(x, starts, ends):
    """Body x[0:b+F]: its last F seconds crossfade (equal power) into x[a:a+F],
    and the loop restarts at a+F (the .import loop_offset). The opening plays
    once; after that the section [a+F, b+F) cycles."""
    _, a, b, rhythm, texture = best_region(x, starts, ends)
    ia, ib, f = int(a * RATE), int(b * RATE), int(CROSSFADE * RATE)
    out = x[:ib + f].copy()
    t = np.linspace(0.0, 1.0, f)[:, None]
    out[ib:ib + f] = x[ib:ib + f] * np.cos(t * np.pi / 2) + x[ia:ia + f] * np.sin(t * np.pi / 2)
    return out, a + CROSSFADE, a, b, rhythm, texture


def make_once(x, cut, fade):
    out = x[:int(cut * RATE)].copy()
    n = int(fade * RATE)
    out[-n:] *= np.cos(np.linspace(0.0, 1.0, n) * np.pi / 2)[:, None] ** 2
    return out


IMPORT = """[remap]

importer="oggvorbisstr"
type="AudioStreamOggVorbis"

[params]

loop={loop}
loop_offset={offset}
bpm=0
beat_count=0
bar_beats=4
"""


def write_import(path, loop, offset):
    head = None
    if os.path.exists(path):
        text = open(path).read()
        head = text.split("[params]")[0]
    body = IMPORT.format(loop="true" if loop else "false", offset=("%g" % offset) if loop else 0)
    if head is not None:
        body = head + "[params]" + body.split("[params]")[1]
    with open(path, "w") as f:
        f.write(body)


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    parser.add_argument("masters", help="folder holding the 'PRs please - *.wav' masters")
    parser.add_argument("--out", default=os.path.join(root, "audio", "music"))
    parser.add_argument("--only", nargs="*", help="prepare only these tracks")
    args = parser.parse_args()
    for name, (master, kind, seconds) in TRACKS.items():
        if args.only and name not in args.only:
            continue
        x = decode(os.path.join(args.masters, master))
        if kind == "loop":
            out, offset, a, b, rhythm, texture = make_loop(x, *seconds)
            note = "%.1f s file; loops %.2f-%.2f s (a %.1f s cycle; rhythm match %.2f, texture %.1f dB)" % (
                len(out) / RATE, offset, len(out) / RATE, b - a, rhythm, texture)
        else:
            out = make_once(x, seconds, FADE[name])
            offset, note = 0.0, "once, %.1f s with a %.0f s fade" % (len(out) / RATE, FADE[name])
        before = loudness(out)
        out *= 10 ** ((TARGET_LUFS - before) / 20.0)
        peak = np.max(np.abs(out))
        if peak > 0.97:
            out *= 0.97 / peak
        path = os.path.join(args.out, name + ".ogg")
        with tempfile.TemporaryDirectory() as tmp:
            wav = os.path.join(tmp, "track.wav")
            wavfile.write(wav, RATE, out.astype(np.float32))
            subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", wav, "-map_metadata", "-1",
                            "-c:a", "vorbis", "-strict", "-2", "-q:a", str(QUALITY), path], check=True)
        write_import(path + ".import", kind == "loop", offset)
        print("%-15s %-34s %s; %.1f -> %.1f LUFS, peak %.1f dBFS, %d bytes" % (
            name, master, note, before, loudness(out), 20 * math.log10(np.max(np.abs(out))), os.path.getsize(path)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
