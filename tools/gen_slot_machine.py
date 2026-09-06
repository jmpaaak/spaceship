#!/usr/bin/env python3
"""Generate slot machine body frame PNG (96×48, RGBA, transparent bg)."""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "slot_symbols")
os.makedirs(OUT, exist_ok=True)
W, H = 96, 48

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
# Machine body — dark metallic rectangle with rounded feel
d.rectangle([2, 2, W - 3, H - 3], fill=(30, 30, 45, 255), outline=(80, 80, 110, 255))
d.rectangle([4, 4, W - 5, H - 5], outline=(50, 50, 70, 255))
# Three reel windows (each ~28x36, with 2px gap)
rw, rh = 28, 36
gap = 2
x0 = (W - 3 * rw - 2 * gap) // 2
for i in range(3):
    rx = x0 + i * (rw + gap)
    ry = (H - rh) // 2
    d.rectangle([rx, ry, rx + rw, ry + rh], fill=(10, 10, 20, 255), outline=(100, 100, 140, 255))
    # Inner highlight line at top of each window
    d.line([(rx + 1, ry + 1), (rx + rw - 1, ry + 1)], fill=(60, 60, 90, 255))
# Lever on right side
lx = W - 6
d.line([(lx, 8), (lx, 28)], fill=(200, 60, 60, 255), width=3)
d.ellipse([lx - 4, 4, lx + 4, 12], fill=(220, 40, 40, 255))
# Top decorative dots
for dx in [20, 48, 76]:
    d.ellipse([dx - 2, 1, dx + 2, 5], fill=(255, 220, 60, 220))

img.save(os.path.join(OUT, "machine.png"))
print("Generated slot machine body in", os.path.join(OUT, "machine.png"))
