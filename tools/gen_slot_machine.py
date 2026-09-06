#!/usr/bin/env python3
"""Generate slot machine body frame PNG (96×48, RGBA) — Balatro-inspired."""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "slot_symbols")
os.makedirs(OUT, exist_ok=True)
W, H = 96, 48

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
# Outer body — dark with subtle purple tint (Balatro dark)
d.rounded_rectangle([0, 0, W - 1, H - 1], radius=6, fill=(22, 18, 32, 255), outline=(90, 70, 130, 255))
d.rounded_rectangle([2, 2, W - 3, H - 3], radius=5, outline=(55, 45, 85, 255))
# Gold trim strip at top
d.rectangle([4, 3, W - 5, 7], fill=(200, 160, 50, 200))
d.rectangle([4, H - 8, W - 5, H - 4], fill=(200, 160, 50, 140))
# Three reel windows — dark inset with gold border
rw, rh = 26, 34
gap = 3
x0 = (W - 3 * rw - 2 * gap) // 2
for i in range(3):
    rx = x0 + i * (rw + gap)
    ry = (H - rh) // 2
    d.rounded_rectangle([rx, ry, rx + rw, ry + rh], radius=3,
                         fill=(8, 6, 16, 255), outline=(180, 145, 55, 255))
    # Inner glow line
    d.line([(rx + 2, ry + 2), (rx + rw - 2, ry + 2)], fill=(80, 65, 120, 180))
# Lever
lx = W - 5
d.line([(lx, 10), (lx, 30)], fill=(220, 55, 55, 255), width=3)
d.ellipse([lx - 4, 5, lx + 4, 13], fill=(240, 40, 40, 255), outline=(180, 30, 30, 255))
# Decorative gold dots
for dx in [18, 48, 78]:
    d.ellipse([dx - 2, H - 7, dx + 2, H - 3], fill=(255, 210, 60, 200))

img.save(os.path.join(OUT, "machine.png"))
print("Generated slot machine body:", os.path.join(OUT, "machine.png"))
