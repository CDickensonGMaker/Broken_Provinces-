"""gen_audio.py - procedural synthesis for the sounds this game names and does not have.

Every file it writes lands under assets/audio/generated/. It never writes
anywhere else, and it never overwrites a hand-made recording: the generated
tree is the only tree it knows about.

    python tools/gen_audio.py sfx
    python tools/gen_audio.py ambience
    python tools/gen_audio.py voice
    python tools/gen_audio.py music
    python tools/gen_audio.py all

22050 Hz mono, 16-bit. Slightly crunchy is the aesthetic, not an accident.
Loops and the music bed go out as .ogg through ffmpeg; one-shots stay .wav.

Loudness is normalised per class, because mismatched loudness is the loudest
tell that a sound was generated:

    one-shots   -6 dBFS peak
    blips      -12 dBFS peak
    ambience   -33 dBFS RMS, -12 dBFS peak ceiling
    music      -30 dBFS RMS, -10 dBFS peak ceiling

Beds are matched by RMS, not peak: peak-matching a sparse bed (drips,
crickets) against a dense one (wind) leaves them 8 dB apart to the ear.
"""

from __future__ import annotations

import math
import os
import struct
import subprocess
import sys
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "generated")

PEAK_ONESHOT = -6.0
PEAK_BLIP = -12.0
PEAK_AMBIENCE = -12.0   # ceiling; ambience is matched by RMS, below
PEAK_MUSIC = -10.0      # ceiling; music is matched by RMS, below
RMS_AMBIENCE = -33.0
RMS_MUSIC = -30.0


# ---------------------------------------------------------------- primitives


def n_samples(dur: float) -> int:
    return max(1, int(round(dur * SR)))


def t_axis(dur: float) -> np.ndarray:
    return np.arange(n_samples(dur), dtype=np.float64) / SR


def rng(seed: str) -> np.random.Generator:
    return np.random.default_rng(abs(hash(seed)) % (2**32))


def noise(dur: float, r: np.random.Generator) -> np.ndarray:
    return r.standard_normal(n_samples(dur))


def env_ad(dur: float, attack: float, decay_pow: float = 2.0) -> np.ndarray:
    """Attack then power-law decay. The workhorse for impacts."""
    n = n_samples(dur)
    a = max(1, int(attack * SR))
    e = np.ones(n)
    e[:a] = np.linspace(0.0, 1.0, a)
    tail = np.linspace(0.0, 1.0, n - a) if n > a else np.zeros(0)
    e[a:] = (1.0 - tail) ** decay_pow
    return e


def env_bell(dur: float, skew: float = 0.5) -> np.ndarray:
    """Smooth rise-and-fall. Whooshes and swells."""
    x = np.linspace(0.0, 1.0, n_samples(dur))
    return np.sin(np.pi * (x**skew)) ** 1.5


def env_adsr(dur: float, a: float, d: float, s: float, r_: float) -> np.ndarray:
    n = n_samples(dur)
    na, nd, nr = int(a * SR), int(d * SR), int(r_ * SR)
    ns = max(0, n - na - nd - nr)
    parts = [
        np.linspace(0.0, 1.0, na) if na else np.zeros(0),
        np.linspace(1.0, s, nd) if nd else np.zeros(0),
        np.full(ns, s),
        np.linspace(s, 0.0, nr) if nr else np.zeros(0),
    ]
    e = np.concatenate(parts)
    return np.resize(e, n)


def phase(freq: np.ndarray | float, dur: float) -> np.ndarray:
    """Integrate a frequency envelope into phase, so pitch can sweep."""
    n = n_samples(dur)
    f = np.full(n, float(freq)) if np.isscalar(freq) else np.resize(freq, n)
    return 2.0 * np.pi * np.cumsum(f) / SR


def sine(freq, dur: float) -> np.ndarray:
    return np.sin(phase(freq, dur))


def saw(freq, dur: float) -> np.ndarray:
    p = phase(freq, dur) / (2.0 * np.pi)
    return 2.0 * (p - np.floor(p + 0.5))


def square(freq, dur: float, duty: float = 0.5) -> np.ndarray:
    p = phase(freq, dur) / (2.0 * np.pi)
    return np.where((p - np.floor(p)) < duty, 1.0, -1.0)


def tri(freq, dur: float) -> np.ndarray:
    p = phase(freq, dur) / (2.0 * np.pi)
    return 4.0 * np.abs(p - np.floor(p + 0.5)) - 1.0


def sweep(a: float, b: float, dur: float, curve: float = 1.0) -> np.ndarray:
    x = np.linspace(0.0, 1.0, n_samples(dur)) ** curve
    return a + (b - a) * x


def lowpass(x: np.ndarray, cutoff) -> np.ndarray:
    """One-pole lowpass; cutoff may be a scalar or a per-sample envelope."""
    n = len(x)
    fc = np.full(n, float(cutoff)) if np.isscalar(cutoff) else np.resize(cutoff, n)
    alpha = 1.0 - np.exp(-2.0 * np.pi * np.clip(fc, 20.0, SR * 0.45) / SR)
    y = np.empty(n)
    acc = 0.0
    for i in range(n):
        acc += alpha[i] * (x[i] - acc)
        y[i] = acc
    return y


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def resonant(x: np.ndarray, cutoff, q: float = 6.0) -> np.ndarray:
    """State-variable bandpass. Cutoff may sweep - this is the magic sound."""
    n = len(x)
    fc = np.full(n, float(cutoff)) if np.isscalar(cutoff) else np.resize(cutoff, n)
    fc = np.clip(fc, 30.0, SR * 0.42)
    f = 2.0 * np.sin(np.pi * fc / SR)
    damp = min(1.0, 1.0 / max(0.5, q))
    low = band = 0.0
    out = np.empty(n)
    for i in range(n):
        high = x[i] - low - damp * band
        band += f[i] * high
        low += f[i] * band
        out[i] = band
    return out


def comb(x: np.ndarray, delay_s: float, feedback: float = 0.5) -> np.ndarray:
    d = max(1, int(delay_s * SR))
    y = x.astype(np.float64).copy()
    for i in range(d, len(y)):
        y[i] += feedback * y[i - d]
    return y


def reverb(x: np.ndarray, size: float = 0.06, decay: float = 0.45, taps: int = 5) -> np.ndarray:
    """Cheap Schroeder-ish smear. Enough to put a sound in a room."""
    y = x.astype(np.float64).copy()
    for k in range(taps):
        y = comb(y, size * (1.0 + 0.31 * k), decay * (0.8**k))
    return lowpass(y, 5000.0)


def pad(x: np.ndarray, dur: float) -> np.ndarray:
    n = n_samples(dur)
    out = np.zeros(n)
    m = min(n, len(x))
    out[:m] = x[:m]
    return out


def at(base: np.ndarray, x: np.ndarray, start: float, gain: float = 1.0) -> np.ndarray:
    i = int(start * SR)
    m = min(len(base) - i, len(x))
    if m > 0:
        base[i : i + m] += gain * x[:m]
    return base


def mix(*layers: np.ndarray) -> np.ndarray:
    n = max(len(a) for a in layers)
    out = np.zeros(n)
    for a in layers:
        out[: len(a)] += a
    return out


def crunch(x: np.ndarray, bits: int = 11, downsample: int = 1) -> np.ndarray:
    """PS1-era character: quantise hard, optionally hold samples."""
    if downsample > 1:
        held = np.repeat(x[::downsample], downsample)
        x = np.resize(held, len(x))
    levels = float(2 ** (bits - 1))
    return np.round(np.clip(x, -1.0, 1.0) * levels) / levels


def normalize(x: np.ndarray, peak_db: float) -> np.ndarray:
    m = float(np.max(np.abs(x)))
    if m < 1e-9:
        return x
    return x * (10.0 ** (peak_db / 20.0)) / m


def normalize_rms(x: np.ndarray, rms_db: float, peak_ceiling_db: float) -> np.ndarray:
    """Beds and music are matched by loudness, not by peak. Peak-matching a
    sparse bed (drips, crickets) against a dense one (wind) leaves them 8 dB
    apart to the ear even though the meters agree."""
    r = float(np.sqrt(np.mean(x**2)))
    if r < 1e-9:
        return x
    y = x * (10.0 ** (rms_db / 20.0)) / r
    m = float(np.max(np.abs(y)))
    ceiling = 10.0 ** (peak_ceiling_db / 20.0)
    if m > ceiling:
        y *= ceiling / m
    return y


def fade(x: np.ndarray, in_s: float = 0.004, out_s: float = 0.02) -> np.ndarray:
    n = len(x)
    a, b = min(int(in_s * SR), n // 2), min(int(out_s * SR), n // 2)
    y = x.copy()
    if a:
        y[:a] *= np.linspace(0.0, 1.0, a)
    if b:
        y[-b:] *= np.linspace(1.0, 0.0, b)
    return y


def seam_loop(x: np.ndarray, xfade: float = 3.0) -> np.ndarray:
    """Crossfade the tail over the head so the loop point is inaudible."""
    f = int(xfade * SR)
    if f * 2 >= len(x):
        return x
    head, tail = x[:f], x[-f:]
    w = np.linspace(0.0, 1.0, f)
    blended = tail * (1.0 - w) + head * w
    return np.concatenate([blended, x[f:-f]])


# ---------------------------------------------------------------- writing


def write_wav(path: str, x: np.ndarray) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = np.clip(x, -1.0, 1.0)
    pcm = (data * 32767.0).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


def write_ogg(path: str, x: np.ndarray, bitrate: str = "40k") -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp.wav"
    write_wav(tmp, x)
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", tmp,
        "-c:a", "libvorbis", "-b:a", bitrate, "-ac", "1", "-ar", str(SR),
        path,
    ]
    subprocess.run(cmd, check=True)
    os.remove(tmp)


WRITTEN: list[tuple[str, int]] = []


def emit(rel: str, x: np.ndarray, peak: float, ogg: bool = False, bitrate: str = "40k",
         rms: float | None = None) -> None:
    # A loop must not be faded: a fade to zero at the tail is a dropout at
    # the loop point, which is exactly the seam seam_loop() just removed.
    x = x if rms is not None else fade(x)
    x = normalize_rms(x, rms, peak) if rms is not None else normalize(x, peak)
    path = os.path.join(OUT, rel)
    if ogg:
        write_ogg(path, x, bitrate)
    else:
        write_wav(path, crunch(x, bits=11))
    WRITTEN.append((rel, os.path.getsize(path)))
    print("  %-58s %6.1f KB" % (rel, os.path.getsize(path) / 1024.0))


# ---------------------------------------------------------------- voices


def grunt(dur: float, f0: float, seed: str, breath: float = 0.35, rough: float = 0.5) -> np.ndarray:
    """A stylised human vocalisation. Two detuned saws through a pair of
    formant bands plus breath noise - readable as a voice, never mistaken
    for a recording, which is the point."""
    r = rng(seed)
    pitch = f0 * np.concatenate([
        np.linspace(1.18, 1.0, n_samples(dur * 0.25)),
        np.linspace(1.0, 0.72, n_samples(dur) - n_samples(dur * 0.25)),
    ])
    wobble = 1.0 + 0.03 * sine(5.5 + 3.0 * r.random(), dur)
    src = 0.6 * saw(pitch * wobble, dur) + 0.4 * saw(pitch * wobble * 1.008, dur)
    src += rough * 0.25 * square(pitch * 0.5, dur, 0.3)
    f1 = resonant(src, sweep(620.0, 480.0, dur), 7.0)
    f2 = resonant(src, sweep(1180.0, 900.0, dur), 9.0)
    body = 0.75 * f1 + 0.4 * f2 + 0.25 * src
    air = breath * lowpass(highpass(noise(dur, r), 500.0), 3200.0)
    return (body + air) * env_adsr(dur, 0.012, dur * 0.25, 0.55, dur * 0.5)


def creature_growl(dur: float, f0: float, seed: str) -> np.ndarray:
    r = rng(seed)
    pitch = f0 * (1.0 + 0.10 * sine(7.0, dur)) * sweep(1.1, 0.85, dur)
    src = mix(saw(pitch, dur), 0.7 * saw(pitch * 1.011, dur), 0.5 * square(pitch * 0.503, dur, 0.42))
    src = resonant(src, sweep(340.0, 240.0, dur), 5.0) + 0.35 * src
    grit = 0.4 * lowpass(noise(dur, r), 1600.0) * (0.5 + 0.5 * sine(31.0, dur))
    return (src + grit) * env_bell(dur, 0.4)


def blip(dur: float, f0: float, shape: str, seed: str) -> np.ndarray:
    """One PS1 dialogue syllable. Not speech - a pitched grain with a
    formant on it, the Banjo-Kazooie trick."""
    r = rng(seed)
    bend = f0 * sweep(1.0, r.uniform(0.82, 1.22), dur, 0.7)
    if shape == "saw":
        src = saw(bend, dur)
    elif shape == "square":
        src = square(bend, dur, r.uniform(0.3, 0.6))
    elif shape == "tri":
        src = tri(bend, dur)
    else:
        src = sine(bend, dur) + 0.35 * sine(bend * 2.0, dur)
    formant = resonant(src, r.uniform(700.0, 1500.0), 8.0)
    out = 0.7 * src + 0.6 * formant
    return out * env_adsr(dur, 0.006, dur * 0.3, 0.6, dur * 0.55)


# ---------------------------------------------------------------- 1. one-shots


def whoosh(dur: float, lo: float, hi: float, seed: str, q: float = 3.0) -> np.ndarray:
    r = rng(seed)
    src = noise(dur, r)
    swept = resonant(src, sweep(lo, hi, dur, 0.7), q)
    return (swept + 0.3 * lowpass(src, hi)) * env_bell(dur, 0.55)


def thud(dur: float, f_hi: float, f_lo: float, seed: str, click: float = 0.5) -> np.ndarray:
    r = rng(seed)
    body = sine(sweep(f_hi, f_lo, dur, 0.35), dur) * env_ad(dur, 0.001, 2.5)
    tick = click * lowpass(noise(0.03, r), 4000.0) * env_ad(0.03, 0.0005, 3.0)
    return mix(body, pad(tick, dur))


def chime(dur: float, partials: list[float], seed: str, bend: float = 1.0) -> np.ndarray:
    out = np.zeros(n_samples(dur))
    for i, f in enumerate(partials):
        d = dur * (1.0 - 0.12 * i)
        v = sine(sweep(f, f * bend, d, 0.6), d) * env_ad(d, 0.004, 1.6 + 0.5 * i)
        out = at(out, v, 0.0, 1.0 / (i + 1.4))
    return out


def metallic(dur: float, base: float, seed: str) -> np.ndarray:
    """Inharmonic partials - coins, buckles, keys."""
    r = rng(seed)
    out = np.zeros(n_samples(dur))
    for k in range(6):
        f = base * (1.0 + 1.41 * k + 0.17 * r.random())
        d = dur * (0.9 - 0.1 * k)
        out = at(out, sine(f, d) * env_ad(d, 0.0008, 2.4 + k * 0.4), 0.0, 0.8 / (k + 1.5))
    return out


def rattle(dur: float, count: int, base: float, seed: str) -> np.ndarray:
    r = rng(seed)
    out = np.zeros(n_samples(dur))
    for i in range(count):
        t0 = r.uniform(0.0, dur * 0.8)
        out = at(out, metallic(0.09, base * r.uniform(0.85, 1.2), seed + str(i)), t0, r.uniform(0.5, 1.0))
    return out


def creak(dur: float, seed: str, f0: float = 180.0) -> np.ndarray:
    """Wood turning on stone: a stick-slip buzz under a scrape."""
    r = rng(seed)
    stick = square(f0 * sweep(1.0, 0.55, dur) * (1.0 + 0.25 * sine(11.0, dur)), dur, 0.2)
    scrape = lowpass(noise(dur, r), sweep(3000.0, 900.0, dur))
    body = resonant(0.5 * stick + scrape, sweep(420.0, 260.0, dur), 5.0)
    return (body + 0.4 * scrape) * env_bell(dur, 0.35)


def footstep(surface: str, seed: str) -> np.ndarray:
    r = rng(seed)
    if surface == "stone":
        d = 0.13
        x = mix(
            lowpass(noise(d, r), 2600.0) * env_ad(d, 0.001, 5.0),
            0.5 * resonant(noise(d, r), 900.0, 4.0) * env_ad(d, 0.001, 6.0),
            0.4 * sine(sweep(150.0, 70.0, d), d) * env_ad(d, 0.001, 4.0),
        )
    elif surface == "wood":
        d = 0.15
        x = mix(
            resonant(noise(d, r), sweep(420.0, 300.0, d), 6.0) * env_ad(d, 0.001, 4.0),
            0.6 * sine(sweep(220.0, 110.0, d), d) * env_ad(d, 0.001, 3.0),
            0.4 * lowpass(noise(d, r), 3500.0) * env_ad(d, 0.001, 7.0),
        )
    elif surface == "grass":
        d = 0.17
        x = highpass(lowpass(noise(d, r), 6500.0), 900.0) * env_ad(d, 0.006, 3.0)
        x += 0.25 * sine(sweep(120.0, 60.0, d), d) * env_ad(d, 0.002, 4.0)
    elif surface == "water":
        d = 0.24
        x = mix(
            lowpass(noise(d, r), sweep(5000.0, 700.0, d)) * env_ad(d, 0.004, 2.2),
            0.5 * sine(sweep(700.0, 220.0, d, 0.4), d) * env_ad(d, 0.002, 3.5),
        )
    elif surface == "metal":
        d = 0.2
        x = mix(metallic(d, 620.0, seed), 0.5 * lowpass(noise(d, r), 5000.0) * env_ad(d, 0.001, 8.0))
    else:  # dirt
        d = 0.14
        x = lowpass(noise(d, r), 1800.0) * env_ad(d, 0.003, 4.0)
        x += 0.35 * sine(sweep(140.0, 65.0, d), d) * env_ad(d, 0.001, 4.0)
    return x


def gen_sfx() -> None:
    print("one-shots ->", os.path.join(OUT, "sfx"))
    p = PEAK_ONESHOT

    # --- swings and misses -------------------------------------------------
    for i in range(1, 4):
        s = "player_attack%d" % i
        emit("sfx/combat/player_attack_%d.wav" % i,
             whoosh(0.30, 900.0 + 200 * i, 2600.0 + 300 * i, s, 3.5)
             + 0.25 * pad(metallic(0.10, 1500.0, s), 0.30), p)
    for i in range(1, 4):
        s = "enemy_attack%d" % i
        emit("sfx/combat/enemy_attack_%d.wav" % i,
             whoosh(0.36, 500.0 + 120 * i, 1700.0 + 200 * i, s, 2.2), p)
    for i in range(1, 3):
        s = "miss%d" % i
        emit("sfx/combat/miss_%d.wav" % i, whoosh(0.26, 700.0, 1900.0, s, 4.5), p)
    for i in range(1, 3):
        s = "projectile_miss%d" % i
        d = 0.34
        w = whoosh(d, 1600.0, 3400.0, s, 8.0)
        emit("sfx/combat/projectile_miss_%d.wav" % i, w * np.linspace(0.4, 1.0, len(w)) ** 2, p)

    # --- stagger grunts ----------------------------------------------------
    for i in range(1, 4):
        s = "player_stagger%d" % i
        g = grunt(0.36, 138.0 + 9 * i, s, breath=0.4)
        stumble = pad(footstep("dirt", s), 0.36)
        emit("sfx/voice/player_hurt_%d.wav" % i, mix(g, 0.5 * np.roll(stumble, int(0.16 * SR))), p)
    for i in range(1, 4):
        s = "enemy_stagger%d" % i
        emit("sfx/voice/enemy_hurt_%d.wav" % i, grunt(0.32, 108.0 + 14 * i, s, breath=0.5, rough=0.8), p)

    # --- deaths ------------------------------------------------------------
    d = 1.30
    cry = grunt(d, 190.0, "player_death", breath=0.5)
    cry *= np.concatenate([np.ones(n_samples(0.35)), np.linspace(1.0, 0.25, n_samples(d) - n_samples(0.35))])
    exhale = lowpass(noise(0.65, rng("pd_ex")), sweep(2400.0, 500.0, 0.65)) * env_ad(0.65, 0.05, 1.6)
    emit("sfx/voice/player_death.wav", mix(cry, pad(np.concatenate([np.zeros(n_samples(0.55)), exhale]), d)), p)

    for i in range(1, 4):
        s = "enemy_death%d" % i
        dd = 0.95
        c = grunt(dd, 118.0 + 16 * i, s, breath=0.55, rough=0.7)
        ex = lowpass(noise(0.45, rng(s + "ex")), sweep(1800.0, 380.0, 0.45)) * env_ad(0.45, 0.04, 1.8)
        emit("sfx/voice/enemy_death_%d.wav" % i,
             mix(c, pad(np.concatenate([np.zeros(n_samples(0.42)), ex]), dd)), p)
    for i in range(1, 3):
        s = "death_exhale%d" % i
        dd = 0.7
        ex = lowpass(noise(dd, rng(s)), sweep(2000.0, 320.0, dd)) * env_ad(dd, 0.03, 1.4)
        tone = 0.35 * sine(sweep(150.0 + 20 * i, 70.0, dd), dd) * env_ad(dd, 0.02, 2.0)
        emit("sfx/voice/death_exhale_%d.wav" % i, mix(ex, tone), p)

    emit("sfx/combat/enemy_spawn.wav",
         mix(creature_growl(0.9, 62.0, "spawn"),
             0.5 * pad(resonant(noise(0.9, rng("spawn2")), sweep(90.0, 400.0, 0.9), 4.0) * env_bell(0.9, 0.8), 0.9)), p)

    # --- player good news --------------------------------------------------
    emit("sfx/ui/player_heal.wav",
         mix(chime(0.9, [523.25, 783.99, 1046.5], "heal", 1.02),
             0.4 * pad(resonant(noise(0.9, rng("heal2")), sweep(700.0, 2600.0, 0.9), 9.0) * env_bell(0.9, 1.4), 0.9)), p)
    lvl = np.zeros(n_samples(1.5))
    for i, f in enumerate([392.0, 523.25, 659.25, 783.99]):
        lvl = at(lvl, chime(0.85, [f, f * 2.0, f * 3.0], "lvl%d" % i), 0.11 * i, 0.9)
    emit("sfx/ui/player_level_up.wav", lvl, p)

    # --- items -------------------------------------------------------------
    for i in range(1, 3):
        emit("sfx/items/item_drop_%d.wav" % i, thud(0.22, 190.0 - 20 * i, 55.0, "drop%d" % i, 0.7), p)
    emit("sfx/items/item_equip.wav",
         mix(lowpass(noise(0.28, rng("eq")), sweep(4000.0, 900.0, 0.28)) * env_ad(0.28, 0.01, 2.0),
             0.7 * pad(metallic(0.20, 780.0, "eq2"), 0.28)), p)
    emit("sfx/items/item_unequip.wav",
         mix(lowpass(noise(0.24, rng("uq")), sweep(1200.0, 3600.0, 0.24)) * env_bell(0.24, 0.8),
             0.5 * pad(metallic(0.16, 620.0, "uq2"), 0.24)), p)
    snap = mix(highpass(noise(0.05, rng("br")), 1800.0) * env_ad(0.05, 0.0004, 6.0),
               0.8 * sine(sweep(900.0, 160.0, 0.05, 0.3), 0.05) * env_ad(0.05, 0.0004, 4.0))
    emit("sfx/items/item_break.wav", mix(pad(snap, 0.5), 0.45 * pad(metallic(0.42, 430.0, "br2"), 0.5)), p)

    # --- spells ------------------------------------------------------------
    emit("sfx/magic/spell_fail.wav",
         mix(resonant(noise(0.45, rng("sf")), sweep(2200.0, 260.0, 0.45, 1.6), 4.0) * env_ad(0.45, 0.01, 1.8),
             0.4 * square(sweep(300.0, 70.0, 0.45), 0.45, 0.25) * env_ad(0.45, 0.01, 2.4)), p)
    for i in range(1, 3):
        s = "spell_impact%d" % i
        dd = 0.7
        emit("sfx/magic/spell_impact_%d.wav" % i,
             mix(resonant(noise(dd, rng(s)), sweep(3200.0 + 400 * i, 220.0, dd, 1.3), 7.0) * env_ad(dd, 0.003, 1.5),
                 0.8 * sine(sweep(420.0, 60.0, dd, 0.35), dd) * env_ad(dd, 0.002, 2.5),
                 0.35 * pad(chime(0.6, [880.0 * i, 1320.0 * i], s), dd)), p)

    # --- doors, locks, levers ----------------------------------------------
    for i in range(1, 3):
        emit("sfx/world/door_open_%d.wav" % i,
             mix(creak(0.85, "do%d" % i, 150.0 + 30 * i),
                 0.5 * pad(thud(0.25, 130.0, 45.0, "do2%d" % i), 0.85)), p)
    for i in range(1, 3):
        dd = 0.6
        emit("sfx/world/door_close_%d.wav" % i,
             mix(pad(creak(0.3, "dc%d" % i, 190.0), dd),
                 pad(np.concatenate([np.zeros(n_samples(0.28)),
                                     thud(0.32, 260.0, 60.0, "dc2%d" % i, 1.0)]), dd)), p)
    emit("sfx/world/door_locked.wav",
         mix(thud(0.3, 220.0, 70.0, "dl", 0.9), 0.6 * pad(rattle(0.45, 5, 900.0, "dl2"), 0.3 + 0.2)), p)
    emit("sfx/world/door_unlock.wav",
         mix(pad(metallic(0.12, 1700.0, "du"), 0.65),
             pad(np.concatenate([np.zeros(n_samples(0.10)), rattle(0.5, 6, 820.0, "du2")]), 0.65)), p)
    lev = np.zeros(n_samples(0.6))
    for i in range(7):
        lev = at(lev, metallic(0.06, 1250.0 - 60 * i, "lev%d" % i), 0.035 * i, 0.9 - 0.07 * i)
    emit("sfx/world/lever_pull.wav", mix(lev, 0.5 * pad(creak(0.5, "lev_c", 240.0), 0.6)), p)
    emit("sfx/world/secret_found.wav",
         mix(chime(1.1, [659.25, 987.77, 1318.5], "sec", 1.01),
             0.5 * pad(reverb(resonant(noise(0.5, rng("sec2")), sweep(400.0, 2400.0, 0.5), 10.0) * env_bell(0.5, 1.5)), 1.1)), p)
    emit("sfx/world/trap_trigger.wav",
         mix(pad(mix(highpass(noise(0.04, rng("tt")), 2200.0) * env_ad(0.04, 0.0003, 7.0),
                     sine(sweep(1200.0, 200.0, 0.04, 0.3), 0.04) * env_ad(0.04, 0.0003, 5.0)), 0.55),
             pad(np.concatenate([np.zeros(n_samples(0.04)), whoosh(0.4, 1400.0, 3000.0, "tt2", 5.0)]), 0.55)), p)
    emit("sfx/world/torch_extinguish.wav",
         mix(lowpass(noise(0.45, rng("tx")), sweep(6000.0, 500.0, 0.45, 0.5)) * env_ad(0.45, 0.006, 2.2),
             0.35 * sine(sweep(300.0, 90.0, 0.2), 0.2) * env_ad(0.2, 0.004, 3.0)), p)

    # --- conditions --------------------------------------------------------
    dd = 0.65
    bub = np.zeros(n_samples(dd))
    rr = rng("poi")
    for i in range(9):
        bub = at(bub, sine(sweep(rr.uniform(180.0, 420.0), rr.uniform(90.0, 200.0), 0.09, 0.4), 0.09)
                 * env_ad(0.09, 0.002, 3.0), rr.uniform(0.0, dd * 0.8), 0.7)
    emit("sfx/effects/effect_poison.wav", mix(bub, 0.4 * lowpass(noise(dd, rr), 900.0) * env_bell(dd, 0.6)), p)
    emit("sfx/effects/effect_burn.wav",
         mix(highpass(noise(0.7, rng("brn")), 1500.0) * env_bell(0.7, 0.4) * (0.5 + 0.5 * rng("brn2").random(n_samples(0.7))),
             0.6 * lowpass(noise(0.7, rng("brn3")), sweep(2600.0, 700.0, 0.7)) * env_ad(0.7, 0.02, 1.6)), p)
    emit("sfx/effects/effect_freeze.wav",
         mix(chime(0.8, [1760.0, 2637.0, 3520.0], "frz", 0.93),
             0.5 * pad(resonant(noise(0.8, rng("frz2")), sweep(4200.0, 900.0, 0.8), 12.0) * env_ad(0.8, 0.01, 1.8), 0.8)), p)
    emit("sfx/effects/effect_stun.wav",
         mix(sine(330.0 * (1.0 + 0.18 * sine(9.0, 0.8)), 0.8) * env_bell(0.8, 0.5),
             0.5 * tri(220.0 * (1.0 + 0.22 * sine(7.0, 0.8)), 0.8) * env_bell(0.8, 0.5)), p)
    emit("sfx/effects/effect_bleed.wav",
         mix(lowpass(noise(0.55, rng("bld")), sweep(1400.0, 300.0, 0.55)) * env_ad(0.55, 0.01, 2.0) * (0.6 + 0.4 * sine(6.0, 0.55)),
             0.45 * sine(sweep(190.0, 80.0, 0.55), 0.55) * env_ad(0.55, 0.008, 2.2)), p)
    emit("sfx/effects/effect_cure.wav", chime(1.0, [440.0, 660.0, 880.0, 1320.0], "cure", 1.03), p)

    # --- quest -------------------------------------------------------------
    qf = np.zeros(n_samples(1.2))
    qf = at(qf, chime(0.7, [311.13, 466.16], "qf1"), 0.0, 1.0)
    qf = at(qf, chime(0.9, [233.08, 349.23], "qf2"), 0.30, 1.0)
    emit("sfx/ui/quest_fail.wav", mix(qf, 0.3 * lowpass(noise(1.2, rng("qf3")), 700.0) * env_bell(1.2, 1.2)), p)

    # --- footsteps by surface ---------------------------------------------
    for surface in ("stone", "wood", "grass", "water", "metal", "dirt"):
        for i in range(1, 5):
            emit("sfx/footsteps/footstep_%s_%d.wav" % (surface, i),
                 footstep(surface, "%s%d" % (surface, i)), p)


# ---------------------------------------------------------------- 2. ambience


def wind_bed(dur: float, seed: str, lo: float, hi: float, gust: float, body: float) -> np.ndarray:
    r = rng(seed)
    src = noise(dur, r)
    lfo = 0.5 + 0.5 * sine(0.037, dur) * sine(0.011, dur)
    lfo2 = 0.5 + 0.5 * sine(0.083, dur)
    cutoff = lo + (hi - lo) * (0.55 * lfo + 0.45 * lfo2)
    bed = lowpass(src, cutoff)
    whistle = gust * resonant(src, 300.0 + 900.0 * lfo, 9.0)
    rumble = body * lowpass(src, 140.0)
    amp = 0.55 + 0.45 * (0.6 * lfo + 0.4 * lfo2)
    return (bed + whistle + rumble) * amp


def chirps(dur: float, seed: str, density: float, lo: float, hi: float) -> np.ndarray:
    """Birdsong. Short frequency-modulated whistles, sparsely scattered."""
    r = rng(seed)
    out = np.zeros(n_samples(dur))
    for _ in range(int(dur * density)):
        t0 = r.uniform(0.0, dur - 1.0)
        notes = r.integers(1, 4)
        for k in range(int(notes)):
            d = r.uniform(0.05, 0.13)
            f = r.uniform(lo, hi)
            v = sine(f * sweep(1.0, r.uniform(0.75, 1.35), d, 0.6) * (1.0 + 0.06 * sine(38.0, d)), d)
            v = v * env_bell(d, 0.6) * r.uniform(0.35, 1.0)
            out = at(out, v, t0 + k * r.uniform(0.10, 0.20))
    return lowpass(out, 9000.0)


def insects(dur: float, seed: str, rate: float, freq: float) -> np.ndarray:
    """Night stridulation. A high band pulsing at a steady, slightly drifting rate."""
    r = rng(seed)
    carrier = resonant(noise(dur, r), freq * (1.0 + 0.03 * sine(0.05, dur)), 14.0)
    pulse = np.clip(sine(rate * (1.0 + 0.02 * sine(0.09, dur)), dur), 0.0, 1.0) ** 3
    drift = 0.5 + 0.5 * sine(0.023, dur)
    return carrier * pulse * (0.4 + 0.6 * drift)


def crickets(dur: float, seed: str) -> np.ndarray:
    r = rng(seed)
    out = np.zeros(n_samples(dur))
    for _ in range(int(dur * 2.2)):
        t0 = r.uniform(0.0, dur - 1.0)
        f = r.uniform(3800.0, 5200.0)
        for k in range(int(r.integers(3, 7))):
            d = 0.03
            v = resonant(noise(d, r), f, 16.0) * env_ad(d, 0.004, 2.0)
            out = at(out, v, t0 + k * 0.075, r.uniform(0.4, 1.0))
    return out


def croaks(dur: float, seed: str) -> np.ndarray:
    r = rng(seed)
    out = np.zeros(n_samples(dur))
    for _ in range(int(dur * 0.5)):
        t0 = r.uniform(0.0, dur - 1.5)
        f = r.uniform(90.0, 190.0)
        for k in range(int(r.integers(2, 5))):
            d = r.uniform(0.10, 0.18)
            v = square(f * sweep(1.0, 0.85, d), d, 0.18) * env_ad(d, 0.006, 2.0)
            v = resonant(v, r.uniform(400.0, 800.0), 6.0) + 0.5 * v
            out = at(out, v, t0 + k * r.uniform(0.16, 0.28), r.uniform(0.5, 1.0))
    return lowpass(out, 2600.0)


def drips(dur: float, seed: str, density: float = 0.5) -> np.ndarray:
    r = rng(seed)
    out = np.zeros(n_samples(dur))
    for _ in range(int(dur * density)):
        d = 0.13
        f0 = r.uniform(700.0, 1800.0)
        v = sine(sweep(f0 * 0.5, f0 * 1.6, d, 0.35), d) * env_ad(d, 0.001, 3.5)
        out = at(out, reverb(v, 0.05, 0.4, 3), r.uniform(0.0, dur - 0.5), r.uniform(0.4, 1.0))
    return out


def waves(dur: float, seed: str) -> np.ndarray:
    r = rng(seed)
    src = noise(dur, r)
    out = np.zeros(n_samples(dur))
    t = 0.0
    while t < dur - 6.0:
        period = r.uniform(4.5, 7.5)
        swell = env_bell(period, r.uniform(0.35, 0.7))
        seg = lowpass(src[: n_samples(period)], sweep(400.0, 3500.0, period, 0.5))
        seg = seg * swell
        seg += 0.6 * lowpass(src[: n_samples(period)], 220.0) * swell
        out = at(out, seg, t, r.uniform(0.6, 1.0))
        t += period * r.uniform(0.55, 0.8)
    return out


def leaves(dur: float, seed: str) -> np.ndarray:
    r = rng(seed)
    src = highpass(noise(dur, r), 1800.0)
    gust = np.clip(sine(0.061, dur) * sine(0.017, dur) + 0.3, 0.0, 1.0)
    return src * gust * 0.9


AMBIENCE_DUR = 62.0
AMBIENCE_XFADE = 4.0


def _amb(rel: str, *layers: np.ndarray) -> None:
    x = mix(*layers)
    emit(rel, seam_loop(x, AMBIENCE_XFADE), PEAK_AMBIENCE, ogg=True, bitrate="40k", rms=RMS_AMBIENCE)


def gen_ambience() -> None:
    print("ambience ->", os.path.join(OUT, "ambience"))
    d = AMBIENCE_DUR

    # forest / woodlands
    _amb("ambience/forest_day.ogg",
         0.9 * wind_bed(d, "fd", 300.0, 1400.0, 0.10, 0.5),
         0.8 * leaves(d, "fdl"),
         0.55 * chirps(d, "fdc", 1.1, 1600.0, 4200.0))
    _amb("ambience/forest_night.ogg",
         0.8 * wind_bed(d, "fn", 200.0, 800.0, 0.06, 0.7),
         0.4 * leaves(d, "fnl"),
         0.5 * crickets(d, "fnc"),
         0.30 * insects(d, "fni", 7.0, 5600.0),
         0.35 * chirps(d, "fno", 0.06, 700.0, 1200.0))

    # road / grasslands
    _amb("ambience/road_day.ogg",
         1.0 * wind_bed(d, "rd", 400.0, 2400.0, 0.16, 0.35),
         0.45 * chirps(d, "rdc", 0.7, 2000.0, 5000.0),
         0.25 * insects(d, "rdi", 11.0, 4200.0))
    _amb("ambience/road_night.ogg",
         0.9 * wind_bed(d, "rn", 250.0, 1200.0, 0.10, 0.5),
         0.6 * crickets(d, "rnc"),
         0.35 * insects(d, "rni", 6.0, 4800.0))

    # highlands / rocky
    _amb("ambience/highlands_day.ogg",
         1.0 * wind_bed(d, "hd", 250.0, 2600.0, 0.34, 0.6),
         0.20 * chirps(d, "hdc", 0.22, 1200.0, 2600.0))
    _amb("ambience/highlands_night.ogg",
         1.0 * wind_bed(d, "hn", 180.0, 1800.0, 0.40, 0.8),
         0.15 * chirps(d, "hnc", 0.05, 600.0, 1000.0))

    # swamp
    _amb("ambience/swamp_day.ogg",
         0.7 * wind_bed(d, "sd", 150.0, 700.0, 0.05, 0.8),
         0.55 * croaks(d, "sdk"),
         0.35 * drips(d, "sdd", 0.35),
         0.30 * insects(d, "sdi", 9.0, 3600.0))
    _amb("ambience/swamp_night.ogg",
         0.7 * wind_bed(d, "sn", 120.0, 520.0, 0.03, 1.0),
         0.85 * croaks(d, "snk"),
         0.40 * drips(d, "snd", 0.45),
         0.45 * insects(d, "sni", 5.5, 4400.0),
         0.30 * crickets(d, "snc"))

    # coast
    _amb("ambience/coast_day.ogg",
         0.55 * wind_bed(d, "cd", 400.0, 2200.0, 0.20, 0.4),
         1.0 * waves(d, "cdw"),
         0.30 * chirps(d, "cdg", 0.20, 900.0, 1800.0))
    _amb("ambience/coast_night.ogg",
         0.45 * wind_bed(d, "cn", 250.0, 1400.0, 0.14, 0.6),
         1.0 * waves(d, "cnw"))

    # desert
    _amb("ambience/desert_day.ogg",
         1.0 * wind_bed(d, "dd", 500.0, 3200.0, 0.12, 0.25),
         0.20 * insects(d, "ddi", 14.0, 6200.0))
    _amb("ambience/desert_night.ogg",
         0.9 * wind_bed(d, "dn", 200.0, 1500.0, 0.22, 0.5),
         0.35 * insects(d, "dni", 4.5, 5200.0))

    # winter
    _amb("ambience/winter_day.ogg",
         1.0 * wind_bed(d, "wd", 600.0, 4200.0, 0.42, 0.45))
    _amb("ambience/winter_night.ogg",
         1.0 * wind_bed(d, "wn", 400.0, 3000.0, 0.55, 0.7))

    # caves - an accent layer under the ruins bed that already exists
    _amb("ambience/caves_drips.ogg",
         0.55 * wind_bed(d, "cvd", 60.0, 300.0, 0.02, 1.0),
         1.0 * drips(d, "cvdd", 0.7))


# ---------------------------------------------------------------- 3. voice blips

BLIP_CLASSES = {
    # name: (base hz, shape, syllable seconds)
    "low": (150.0, "saw", 0.075),
    "mid": (235.0, "square", 0.065),
    "high": (360.0, "tri", 0.055),
    "solemn": (185.0, "sine", 0.105),
}


def gen_voice() -> None:
    print("voice blips ->", os.path.join(OUT, "voice"))
    for cls, (f0, shape, dur) in BLIP_CLASSES.items():
        for i in range(1, 7):
            s = "%s_%d" % (cls, i)
            f = f0 * (2.0 ** ((i - 3.5) / 12.0))
            x = blip(dur, f, shape, s)
            if cls == "solemn":
                x = mix(x, 0.35 * pad(reverb(x, 0.04, 0.3, 3), len(x) / SR))
            emit("voice/blip_%s_%d.wav" % (cls, i), x, PEAK_BLIP)


# ---------------------------------------------------------------- 4. music


def pad_voice(dur: float, freq: float, seed: str, detune: float = 0.006) -> np.ndarray:
    """Detuned saws through a slow lowpass - the dark-fantasy drone."""
    r = rng(seed)
    wob = 1.0 + 0.0035 * sine(0.07 + 0.05 * r.random(), dur) + 0.0018 * sine(0.31, dur)
    v = np.zeros(n_samples(dur))
    for k, dt in enumerate((1.0 - detune, 1.0, 1.0 + detune, 1.0 + 2 * detune)):
        v += saw(freq * dt * wob, dur) * (0.9 - 0.15 * k)
    cutoff = 260.0 + 380.0 * (0.5 + 0.5 * sine(0.041, dur))
    return lowpass(v, cutoff) * 0.25


def bell(dur: float, freq: float, seed: str) -> np.ndarray:
    out = chime(dur, [freq, freq * 2.76, freq * 5.4, freq * 8.9], seed, 0.998)
    return reverb(out, 0.09, 0.55, 5)


def gen_music() -> None:
    print("music ->", os.path.join(OUT, "music"))
    total = 150.0
    n = n_samples(total)
    out = np.zeros(n)

    # A slow minor progression: Dm - Bb - Gm - A. Two chords per 30 s.
    root = 73.42  # D2
    prog = [
        [1.0, 1.1892, 1.4983],          # D  F  A
        [0.8909, 1.1225, 1.3348],       # Bb D  F
        [1.3348, 1.5874, 2.0],          # G  Bb D
        [1.4983, 1.8877, 2.2449],       # A  C# E
        [1.0, 1.1892, 1.4983],
    ]
    seg = 30.0
    for i, chord in enumerate(prog):
        t0 = i * seg
        for j, ratio in enumerate(chord):
            v = pad_voice(seg + 8.0, root * ratio, "pad%d_%d" % (i, j))
            v *= env_bell(seg + 8.0, 0.8)
            out = at(out, v, t0, 1.0 / (1.0 + 0.35 * j))
        # an octave-up ghost, quieter
        v = pad_voice(seg + 8.0, root * chord[0] * 2.0, "ghost%d" % i) * env_bell(seg + 8.0, 0.9)
        out = at(out, v, t0, 0.28)

    # sparse low bells on the chord roots
    r = rng("bells")
    t = 6.0
    while t < total - 8.0:
        idx = min(int(t // seg), len(prog) - 1)
        f = root * prog[idx][int(r.integers(0, 3))] * (2.0 ** int(r.integers(1, 3)))
        out = at(out, bell(7.0, f, "bell%.1f" % t), t, r.uniform(0.10, 0.22))
        t += r.uniform(9.0, 17.0)

    # a breath of air over the top, and tape wobble under everything
    out += 0.05 * lowpass(noise(total, rng("air")), 900.0) * (0.5 + 0.5 * sine(0.02, total))
    wobble = 1.0 + 0.0022 * sine(0.9, total) + 0.0012 * sine(3.3, total)
    idx = np.clip(np.cumsum(wobble), 0, n - 1).astype(int)
    out = out[idx]
    out = lowpass(out, 6200.0)

    emit("music/dark_fantasy_drone.ogg", seam_loop(out, 6.0), PEAK_MUSIC, ogg=True, bitrate="56k", rms=RMS_MUSIC)


# ---------------------------------------------------------------- main

STAGES = {"sfx": gen_sfx, "ambience": gen_ambience, "voice": gen_voice, "music": gen_music}


def main() -> int:
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    stages = list(STAGES) if which == "all" else [which]
    for s in stages:
        if s not in STAGES:
            print("unknown stage: %s (want one of %s, or all)" % (s, ", ".join(STAGES)))
            return 2
        STAGES[s]()
    total = sum(sz for _, sz in WRITTEN)
    print("\n%d files, %.2f MB" % (len(WRITTEN), total / (1024.0 * 1024.0)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
