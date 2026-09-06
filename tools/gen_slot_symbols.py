#!/usr/bin/env python3
"""Generate 5 slot-machine symbol PNGs (32×32, RGBA) — Balatro-inspired."""
import os, math
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "slot_symbols")
os.makedirs(OUT, exist_ok=True)
S = 32

def new():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))

# --- MONEY: gold coin with inner ring + $ ---
img = new(); d = ImageDraw.Draw(img)
d.ellipse([3, 3, 28, 28], fill=(50, 40, 15, 255), outline=(180, 140, 30, 255))
d.ellipse([5, 5, 26, 26], fill=(240, 195, 55, 255))
d.ellipse([8, 8, 23, 23], fill=(255, 215, 75, 255), outline=(200, 160, 40, 255))
d.line([(16, 9), (16, 22)], fill=(120, 80, 0, 255), width=2)
d.line([(12, 12), (20, 12)], fill=(120, 80, 0, 255))
d.line([(12, 19), (20, 19)], fill=(120, 80, 0, 255))
img.save(os.path.join(OUT, "money.png"))

# --- PART: stylized gear with gold teeth ---
img = new(); d = ImageDraw.Draw(img)
cx, cy = 16, 16
for i in range(8):
    a = math.radians(i * 45)
    tx, ty = cx + math.cos(a) * 11, cy + math.sin(a) * 11
    d.rectangle([tx - 3, ty - 3, tx + 3, ty + 3], fill=(200, 170, 55, 255))
d.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=(80, 70, 120, 255))
d.ellipse([cx - 4, cy - 4, cx + 4, cy + 4], fill=(40, 35, 65, 255))
d.ellipse([cx - 2, cy - 2, cx + 2, cy + 2], fill=(120, 100, 160, 255))
img.save(os.path.join(OUT, "part.png"))

# --- SPEED: electric bolt with glow ---
img = new(); d = ImageDraw.Draw(img)
glow = [(17, 1), (8, 14), (15, 14), (11, 31), (24, 13), (17, 13), (21, 1)]
d.polygon(glow, fill=(255, 200, 40, 80))
bolt = [(18, 3), (10, 15), (16, 15), (13, 29), (22, 14), (16, 14), (20, 3)]
d.polygon(bolt, fill=(255, 235, 65, 255), outline=(200, 160, 10, 255))
d.line([(15, 8), (14, 14)], fill=(255, 255, 180, 200), width=1)
img.save(os.path.join(OUT, "speed.png"))

# --- DURABILITY: shield with cross emblem ---
img = new(); d = ImageDraw.Draw(img)
outer = [(16, 2), (28, 8), (27, 21), (16, 30), (5, 21), (4, 8)]
d.polygon(outer, fill=(45, 55, 100, 255), outline=(80, 100, 180, 255))
inner = [(16, 6), (24, 10), (23, 19), (16, 26), (9, 19), (8, 10)]
d.polygon(inner, fill=(55, 80, 160, 255))
d.line([(16, 10), (16, 22)], fill=(160, 200, 255, 255), width=3)
d.line([(10, 16), (22, 16)], fill=(160, 200, 255, 255), width=3)
img.save(os.path.join(OUT, "durability.png"))

# --- HARVEST: multi-facet gem with highlights ---
img = new(); d = ImageDraw.Draw(img)
gem = [(16, 2), (27, 11), (23, 29), (9, 29), (5, 11)]
d.polygon(gem, fill=(140, 50, 220, 255), outline=(100, 30, 180, 255))
top = [(16, 2), (21, 11), (16, 18), (11, 11)]
d.polygon(top, fill=(200, 120, 255, 255))
d.polygon([(11, 11), (16, 18), (9, 29), (5, 11)], fill=(160, 70, 240, 255))
d.polygon([(21, 11), (27, 11), (23, 29), (16, 18)], fill=(120, 40, 200, 255))
d.line([(13, 7), (11, 11)], fill=(240, 200, 255, 200), width=1)
img.save(os.path.join(OUT, "harvest.png"))

print("Generated 5 slot symbol PNGs in", OUT)
