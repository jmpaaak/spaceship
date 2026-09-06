#!/usr/bin/env python3
"""Generate a 128x128 pixel-art Earth sprite (blue sphere + green continents + white clouds)."""
import math, random, os
from PIL import Image, ImageDraw

random.seed(42)
SIZE = 128
R = SIZE // 2 - 2  # sphere radius
CX, CY = SIZE // 2, SIZE // 2

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# --- base ocean sphere ---
for y in range(SIZE):
    for x in range(SIZE):
        dx, dy = x - CX, y - CY
        d = math.sqrt(dx * dx + dy * dy)
        if d <= R:
            shade = max(0.4, 1.0 - d / R * 0.6)
            b = int(200 * shade)
            g = int(100 * shade)
            img.putpixel((x, y), (20, g, b, 255))

# --- continents (random blobs) ---
continents = [(0.3, 0.35, 18), (-0.25, -0.15, 14), (0.1, -0.4, 10),
              (-0.35, 0.25, 12), (0.4, -0.1, 9)]
for cx_f, cy_f, cr in continents:
    ccx, ccy = CX + int(cx_f * R), CY + int(cy_f * R)
    for y in range(max(0, ccy - cr - 4), min(SIZE, ccy + cr + 4)):
        for x in range(max(0, ccx - cr - 4), min(SIZE, ccx + cr + 4)):
            dx, dy = x - CX, y - CY
            if math.sqrt(dx * dx + dy * dy) > R:
                continue
            dd = math.sqrt((x - ccx) ** 2 + (y - ccy) ** 2)
            jitter = random.uniform(-2, 2)
            if dd + jitter < cr:
                shade = max(0.5, 1.0 - math.sqrt(dx * dx + dy * dy) / R * 0.5)
                img.putpixel((x, y), (30, int(180 * shade), 50, 255))

# --- clouds (white patches) ---
clouds = [(0.15, -0.2, 11), (-0.3, 0.1, 9), (0.0, 0.4, 8), (0.35, 0.3, 7)]
for cx_f, cy_f, cr in clouds:
    ccx, ccy = CX + int(cx_f * R), CY + int(cy_f * R)
    for y in range(max(0, ccy - cr - 2), min(SIZE, ccy + cr + 2)):
        for x in range(max(0, ccx - cr - 2), min(SIZE, ccx + cr + 2)):
            dx, dy = x - CX, y - CY
            if math.sqrt(dx * dx + dy * dy) > R:
                continue
            dd = math.sqrt((x - ccx) ** 2 + (y - ccy) ** 2)
            if dd + random.uniform(-1, 1) < cr:
                prev = img.getpixel((x, y))
                a = 0.45
                img.putpixel((x, y), (int(prev[0] * (1 - a) + 240 * a),
                                       int(prev[1] * (1 - a) + 245 * a),
                                       int(prev[2] * (1 - a) + 250 * a), 255))

out = os.path.join(os.path.dirname(__file__), "..", "assets", "earth", "earth_generic.png")
img.save(out)
print(f"Saved {out} ({SIZE}x{SIZE})")
