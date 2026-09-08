"""Procedurally synthesizes short combat SFX as 16-bit mono WAV files -- no
external audio sourcing, pure waveform generation (stdlib only: wave/struct/
math/random). Covers the three sounds asked for first: shooting, swinging,
striking. Run once; output goes straight into assets/sfx/.
"""
import math
import random
import struct
import wave
from pathlib import Path

SR = 44100
OUT = Path(r"D:\vapecoder\cyber-draft-duel-2d\assets\sfx")
OUT.mkdir(parents=True, exist_ok=True)


def write_wav(name: str, samples: list[float]) -> None:
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.92 / peak
    path = OUT / name
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s * scale))
            frames += struct.pack("<h", int(v * 32767))
        w.writeframes(bytes(frames))
    print(f"wrote {path}  ({len(samples)/SR*1000:.0f}ms)")


def env_exp(t: float, decay: float) -> float:
    return math.exp(-t / decay)


def noise(n: int, seed: int) -> list[float]:
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(sig: list[float], alpha: float) -> list[float]:
    out = [sig[0]]
    for i in range(1, len(sig)):
        out.append(out[-1] + alpha * (sig[i] - out[-1]))
    return out


def highpass(sig: list[float], alpha: float) -> list[float]:
    out = [sig[0]]
    for i in range(1, len(sig)):
        out.append(alpha * (out[-1] + sig[i] - sig[i - 1]))
    return out


# ---------------------------------------------------------------- shoot.wav
# Rifle-ish crack: a fast noise transient (the "crack") plus a short
# descending sine sweep underneath (the "pew" body), both decaying quickly.
def make_shoot(seed: int = 1) -> list[float]:
    dur = 0.14
    n = int(SR * dur)
    raw = noise(n, seed)
    crack = highpass(raw, 0.6)
    out = []
    for i in range(n):
        t = i / SR
        crack_env = env_exp(t, 0.02)
        sweep_freq = 1400.0 - 1100.0 * (t / dur)
        sweep = math.sin(2 * math.pi * sweep_freq * t) * env_exp(t, 0.045)
        out.append(crack[i] * crack_env * 0.8 + sweep * 0.55)
    return out


# ---------------------------------------------------------------- swing.wav
# Whoosh: band-limited noise with a rise-then-fall amplitude envelope (attack
# then release), body low-passed hard so it reads as air movement, not static.
def make_swing(seed: int = 2) -> list[float]:
    dur = 0.22
    n = int(SR * dur)
    raw = noise(n, seed)
    body = lowpass(raw, 0.12)
    body = highpass(body, 0.25)
    out = []
    attack = 0.05
    for i in range(n):
        t = i / SR
        if t < attack:
            e = t / attack
        else:
            e = env_exp(t - attack, 0.09)
        out.append(body[i] * e)
    return out


# ---------------------------------------------------------------- strike.wav
# Impact thud: a low sine "punch" with very fast decay, plus a brief noise
# "crunch" transient right at the start for a harder-hitting attack.
def make_strike(seed: int = 3) -> list[float]:
    dur = 0.13
    n = int(SR * dur)
    raw = noise(n, seed)
    crunch = highpass(raw, 0.5)
    out = []
    for i in range(n):
        t = i / SR
        thud = math.sin(2 * math.pi * 130.0 * t) * env_exp(t, 0.028)
        thud += math.sin(2 * math.pi * 78.0 * t) * env_exp(t, 0.05) * 0.6
        crunch_env = env_exp(t, 0.012)
        out.append(thud * 0.85 + crunch[i] * crunch_env * 0.5)
    return out


def main() -> None:
    write_wav("shoot.wav", make_shoot())
    write_wav("swing.wav", make_swing())
    write_wav("strike.wav", make_strike())


if __name__ == "__main__":
    main()
