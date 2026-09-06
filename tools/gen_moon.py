#!/usr/bin/env python3
"""Generate a 32x32 pixel-art moon sprite — chunky 4px retro style."""
from PIL import Image
import math, os

S = 32
TILE = S // 4  # 8 — draw at 8x8 then upscale

small = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
R = TILE // 2 - 1   # 3
cx = cy = TILE // 2

for y in range(TILE):
    for x in range(TILE):
        dx, dy = x - cx + 0.5, y - cy + 0.5
        d = math.sqrt(dx*dx + dy*dy)
        if d > R:
            continue
        nd = d / R
        # Light from top-left
        light = max(0.55, min(1.0, 0.75 + (-dx * 0.4 - dy * 0.4) / (R * 1.5)))
        shade = max(0.4, 1.0 - nd * 0.3) * light
        # Base grey
        base = 200
        # Crater darkening via simple pattern
        crater = (math.sin(x * 1.8 + 0.5) * math.cos(y * 2.1 + 1.0)) > 0.5
        base = 155 if crater else 200
        v = min(255, int(base * shade))
        small.putpixel((x, y), (v, v, v, 255))

# Rim highlight
for y in range(TILE):
    for x in range(TILE):
        dx, dy = x - cx + 0.5, y - cy + 0.5
        d = math.sqrt(dx*dx + dy*dy)
        if R - 0.6 < d <= R:
            small.putpixel((x, y), (100, 100, 110, 200))

img = small.resize((S, S), Image.NEAREST)
os.makedirs("assets/moon", exist_ok=True)
img.save("assets/moon/moon_generic.png")
print(f"OK {S}x{S} RGBA moon_generic.png")
