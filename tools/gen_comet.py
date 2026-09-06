#!/usr/bin/env python3
"""Generate a 32x32 chunky 4px comet (icy head, no tail — tail is drawn in LÖVE)."""
from PIL import Image
import math, os

S, T = 32, 8
sm = Image.new("RGBA", (T, T), (0, 0, 0, 0))
cx, cy, R = T / 2, T / 2, T / 2 - 0.6
for y in range(T):
    for x in range(T):
        dx, dy = x - cx + 0.5, y - cy + 0.5
        d = math.sqrt(dx * dx + dy * dy)
        if d > R:
            continue
        nd = d / R
        light = max(0.5, 1.0 + (-dx * 0.45 - dy * 0.45) / (R * 2))
        shade = max(0.4, 1.0 - nd * 0.25) * light
        ice = (255, 235, 160) if nd < 0.45 else (255, 200, 80)
        v = tuple(min(255, int(c * shade)) for c in ice)
        sm.putpixel((x, y), (*v, 255))
img = sm.resize((S, S), Image.Resampling.NEAREST)
os.makedirs("assets/comet", exist_ok=True)
img.save("assets/comet/comet_generic.png")
print("OK 32x32 RGBA comet_generic.png")
