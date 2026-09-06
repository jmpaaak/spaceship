#!/usr/bin/env python3
"""Generate 16×16 pixel-art HUD icons for distance, cash, durability."""
import os, math
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "hud")
os.makedirs(OUT, exist_ok=True)

def new():
    return Image.new("RGBA", (16, 16), (0, 0, 0, 0))

# --- icon_distance.png: upward arrow with star sparkle (cyan) ---
img = new(); d = ImageDraw.Draw(img)
# Arrow body
d.line([(8, 2), (8, 13)], fill=(0, 220, 255, 255), width=2)
# Arrow head
d.polygon([(8, 1), (4, 6), (12, 6)], fill=(0, 220, 255, 255))
# Star sparkles
for sx, sy in [(3, 3), (13, 5), (2, 10)]:
    d.point((sx, sy), fill=(180, 240, 255, 200))
    d.point((sx + 1, sy), fill=(120, 200, 255, 140))
img.save(os.path.join(OUT, "icon_distance.png"))

# --- icon_cash.png: coin with $ motif (gold) ---
img = new(); d = ImageDraw.Draw(img)
# Coin circle
d.ellipse([3, 3, 12, 12], fill=(255, 200, 50, 255), outline=(200, 150, 20, 255))
# Inner highlight
d.ellipse([5, 5, 10, 10], fill=(255, 220, 80, 255))
# $ sign — vertical bar + S-curve approximation
d.line([(8, 4), (8, 11)], fill=(180, 120, 0, 255))
d.line([(6, 6), (10, 6)], fill=(180, 120, 0, 255))
d.line([(6, 9), (10, 9)], fill=(180, 120, 0, 255))
d.point((6, 7), fill=(180, 120, 0, 255))
d.point((10, 8), fill=(180, 120, 0, 255))
# Shine
d.point((5, 4), fill=(255, 255, 200, 180))
img.save(os.path.join(OUT, "icon_cash.png"))

# --- icon_durability.png: heart motif (HP indicator, red/pink) ---
img = new(); d = ImageDraw.Draw(img)
# Heart shape — two circular lobes + triangle bottom
d.ellipse([2, 3, 8, 9], fill=(220, 50, 60, 255))
d.ellipse([7, 3, 13, 9], fill=(220, 50, 60, 255))
d.polygon([(2, 7), (8, 14), (14, 7)], fill=(220, 50, 60, 255))
# Inner highlight
d.ellipse([4, 4, 7, 7], fill=(255, 100, 110, 255))
# Shine
d.point((5, 4), fill=(255, 200, 200, 200))
d.point((4, 5), fill=(255, 180, 180, 160))
img.save(os.path.join(OUT, "icon_durability.png"))

print("Generated 3 HUD icons in", OUT)
