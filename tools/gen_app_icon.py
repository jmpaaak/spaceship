#!/usr/bin/env python3
"""INBOX (49): 256x256 nearest window icon from assets/ship/ship_default.png."""
import os
from PIL import Image

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "assets/ship/ship_default.png")
OUT = os.path.join(ROOT, "assets/icon.png")
SIZE = 256
NAVY = (8, 10, 22, 255)
MARGIN = 24

ship = Image.open(SRC).convert("RGBA")
bbox = ship.getbbox() or (0, 0, ship.width, ship.height)
pad = 2
crop = ship.crop((
    max(0, bbox[0] - pad),
    max(0, bbox[1] - pad),
    min(ship.width, bbox[2] + pad),
    min(ship.height, bbox[3] + pad),
))
inner = SIZE - MARGIN * 2
scale = max(1, min(inner // crop.width, inner // crop.height))
scaled = crop.resize((crop.width * scale, crop.height * scale), Image.Resampling.NEAREST)
icon = Image.new("RGBA", (SIZE, SIZE), NAVY)
icon.paste(scaled, ((SIZE - scaled.width) // 2, (SIZE - scaled.height) // 2), scaled)
icon.save(OUT)
print("wrote", os.path.relpath(OUT, ROOT), scaled.size, "scale", scale)
