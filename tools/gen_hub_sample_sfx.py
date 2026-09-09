#!/usr/bin/env python3
"""INBOX (60): procedural Loud Space Launch fallback (Pixabay 351055 blocked)."""
import math
import random
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "assets" / "sfx" / "hub_sample.mp3"
SR, DUR, SEED = 44100, 6.0, 351055


def main():
    rng = random.Random(SEED)
    n = int(SR * DUR)
    frames = bytearray()
    for i in range(n):
        t = i / SR
        if t < 1.5:
            env = (t / 1.5) ** 2
        elif t < 3.5:
            env = 1.0
        else:
            env = math.exp(-(t - 3.5) * 1.8)
        rumble = 0.55 * math.sin(2 * math.pi * (40 + 40 * min(t / 3.0, 1.0)) * t)
        sub = 0.25 * math.sin(2 * math.pi * 28 * t)
        whoosh = 0.22 * (rng.random() * 2 - 1) * math.sin(math.pi * min(t / 4.0, 1.0)) ** 2
        engine = 0.18 * math.sin(2 * math.pi * (120 + 380 * min(t / 5.0, 1.0)) * t) * min(t / 2.0, 1.0)
        bang = 0.7 * math.exp(-(t - 1.15) * 18) * (rng.random() * 2 - 1) if 1.15 < t < 1.45 else 0.0
        v = max(-1.0, min(1.0, env * (rumble + sub + whoosh + engine) + bang))
        frames += struct.pack("<h", int(v * 32767 * 0.85))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)


if __name__ == "__main__":
    main()
