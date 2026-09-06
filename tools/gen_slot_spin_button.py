#!/usr/bin/env python3
"""Generate slot spin button PNG (96×22, RGBA) — Balatro-inspired gold bar."""
import os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "slot_symbols")
os.makedirs(OUT, exist_ok=True)
W, H = 96, 22

img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle([0, 0, W - 1, H - 1], radius=6, fill=(35, 28, 50, 255),
                     outline=(200, 160, 50, 255))
d.rounded_rectangle([2, 2, W - 3, H - 3], radius=5, outline=(120, 95, 35, 180))
# Gold highlight stripe
d.rectangle([6, 4, W - 7, 7], fill=(220, 180, 60, 160))
# Decorative dots
for dx in [20, 48, 76]:
    d.ellipse([dx - 2, H // 2 - 2, dx + 2, H // 2 + 2], fill=(255, 215, 70, 200))
img.save(os.path.join(OUT, "spin_button.png"))
print("Generated spin button:", os.path.join(OUT, "spin_button.png"))
