#!/usr/bin/env python3
"""Generate 5 slot-machine symbol PNGs (32×32, RGBA, transparent bg)."""
import os, math
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "slot_symbols")
os.makedirs(OUT, exist_ok=True)
S = 32

def new():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))

# --- money.png: gold coin with $ ---
img = new(); d = ImageDraw.Draw(img)
d.ellipse([4, 4, 27, 27], fill=(255, 200, 50, 255), outline=(180, 130, 20, 255))
d.ellipse([7, 7, 24, 24], fill=(255, 220, 80, 255))
d.line([(16, 8), (16, 23)], fill=(140, 90, 0, 255), width=2)
d.line([(12, 12), (20, 12)], fill=(140, 90, 0, 255)); d.line([(12, 19), (20, 19)], fill=(140, 90, 0, 255))
d.point((12, 14), fill=(140, 90, 0, 255)); d.point((20, 17), fill=(140, 90, 0, 255))
img.save(os.path.join(OUT, "money.png"))

# --- part.png: gear/wrench motif ---
img = new(); d = ImageDraw.Draw(img)
cx, cy, r = 16, 16, 10
for i in range(6):
    a = math.radians(i * 60)
    tx, ty = cx + math.cos(a) * r, cy + math.sin(a) * r
    d.rectangle([tx - 3, ty - 3, tx + 3, ty + 3], fill=(160, 180, 200, 255))
d.ellipse([cx - 7, cy - 7, cx + 7, cy + 7], fill=(100, 120, 150, 255))
d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(60, 70, 90, 255))
img.save(os.path.join(OUT, "part.png"))

# --- speed.png: lightning bolt ---
img = new(); d = ImageDraw.Draw(img)
bolt = [(18, 3), (10, 15), (16, 15), (13, 29), (22, 14), (16, 14), (20, 3)]
d.polygon(bolt, fill=(255, 230, 60, 255), outline=(200, 160, 0, 255))
img.save(os.path.join(OUT, "speed.png"))

# --- durability.png: shield motif ---
img = new(); d = ImageDraw.Draw(img)
shield = [(16, 3), (27, 8), (26, 20), (16, 29), (6, 20), (5, 8)]
d.polygon(shield, fill=(60, 180, 220, 255), outline=(30, 120, 180, 255))
inner = [(16, 7), (23, 10), (22, 18), (16, 25), (10, 18), (9, 10)]
d.polygon(inner, fill=(80, 200, 240, 255))
d.line([(16, 11), (16, 21)], fill=(200, 240, 255, 255), width=2)
d.line([(11, 16), (21, 16)], fill=(200, 240, 255, 255), width=2)
img.save(os.path.join(OUT, "durability.png"))

# --- harvest.png: crystal/gem motif ---
img = new(); d = ImageDraw.Draw(img)
gem = [(16, 3), (26, 12), (22, 28), (10, 28), (6, 12)]
d.polygon(gem, fill=(180, 80, 255, 255), outline=(120, 40, 200, 255))
d.polygon([(16, 3), (20, 12), (16, 20), (12, 12)], fill=(220, 140, 255, 255))
d.line([(10, 28), (16, 20), (22, 28)], fill=(140, 60, 220, 255))
img.save(os.path.join(OUT, "harvest.png"))

print("Generated 5 slot symbol PNGs in", OUT)
