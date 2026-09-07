#!/usr/bin/env python3
"""Generate star sprites from NASA SDO images — chunky 4px retro pixelization."""
from PIL import Image, ImageDraw
import math, os

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "star")
os.makedirs(OUT, exist_ok=True)
S = 128  # output size
BLOCK = 4  # pixel block size for chunky look
SMALL = S // BLOCK  # 32

# NASA SDO wavelength → star type mapping + color tint
SOURCES = {
    "sun":  ("/tmp/sun_hmi.jpg",    (1.0, 0.85, 0.4)),   # visible light → gold
    "lava": ("/tmp/sun_aia304.jpg", (1.0, 0.35, 0.15)),   # 304Å → red/lava
    "ice":  ("/tmp/sun_aia171.jpg", (0.4, 0.7, 1.0)),     # 171Å → blue/ice
    "gas":  ("/tmp/sun_aia193.jpg", (0.5, 0.9, 0.5)),     # 193Å → green/gas
    "dry":  ("/tmp/sun_aia335.jpg", (0.85, 0.6, 0.3)),    # 335Å → brown/dry
    "bare": ("/tmp/sun_aia094.jpg", (0.6, 0.55, 0.7)),    # 094Å → purple/bare
}

def circle_mask(img, cx, cy, r):
    """Zero out pixels outside circle."""
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            if math.sqrt(dx*dx + dy*dy) > r:
                px[x, y] = (0, 0, 0, 0)

for star_type, (src_path, tint) in SOURCES.items():
    src = Image.open(src_path).convert("RGB")
    # Crop to square center (SDO images are 512x512 with black border)
    w, h = src.size
    cx, cy = w // 2, h // 2
    crop_r = min(w, h) // 2 - 10
    src = src.crop((cx - crop_r, cy - crop_r, cx + crop_r, cy + crop_r))
    # Downscale to SMALL with NEAREST for chunky blocks
    small = src.resize((SMALL, SMALL), Image.Resampling.NEAREST)
    # Apply color tint
    px = small.load()
    for y in range(SMALL):
        for x in range(SMALL):
            r, g, b = px[x, y]
            lum = (r * 0.3 + g * 0.59 + b * 0.11) / 255
            nr = min(255, int(lum * tint[0] * 255 * 1.4))
            ng = min(255, int(lum * tint[1] * 255 * 1.4))
            nb = min(255, int(lum * tint[2] * 255 * 1.4))
            px[x, y] = (nr, ng, nb)
    # Upscale to S with NEAREST
    img = small.resize((S, S), Image.Resampling.NEAREST).convert("RGBA")
    circle_mask(img, S / 2, S / 2, S / 2 - 1)
    img.save(os.path.join(OUT, f"star_{star_type}.png"))
    # 4-frame sheet: slight rotation for animation
    sheet = Image.new("RGBA", (S, S * 4), (0, 0, 0, 0))
    for f in range(4):
        frame = small.copy()
        # Shift pixels horizontally for rotation illusion
        shifted = Image.new("RGB", (SMALL, SMALL))
        fpx = frame.load()
        spx = shifted.load()
        shift = f * (SMALL // 4)
        for yy in range(SMALL):
            for xx in range(SMALL):
                sx = (xx + shift) % SMALL
                spx[xx, yy] = fpx[sx, yy]
        fr = shifted.resize((S, S), Image.Resampling.NEAREST).convert("RGBA")
        circle_mask(fr, S / 2, S / 2, S / 2 - 1)
        sheet.paste(fr, (0, f * S))
    sheet.save(os.path.join(OUT, f"star_{star_type}_sheet.png"))
    print(f"  {star_type}: {img.size} + sheet {sheet.size}")

print("Done — 6 star sprites + 6 sheets from NASA SDO")
