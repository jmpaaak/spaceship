#!/usr/bin/env python3
"""4-frame rotation sheets for 6 planet types. Output: assets/planet/pp_*_sheet.png (128×512).
Draw at 32×32 (block=4) then upscale NEAREST to 128×128.
STRICT circular alpha mask: any pixel with dist > radius gets alpha=0 (fixes green square artifact)."""
import os, math, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "planet")
os.makedirs(OUT, exist_ok=True)
S, B = 128, 4   # final size, block size → draw at S//B = 32
ss = S // B      # 32

TYPES = {
    "ice":   {"base": (160, 210, 240), "dark": (80, 130, 180),  "accent": (220, 240, 255)},
    "lava":  {"base": (180, 60, 20),   "dark": (80, 20, 10),    "accent": (255, 180, 40)},
    "dry":   {"base": (180, 150, 100), "dark": (120, 90, 50),   "accent": (210, 190, 140)},
    "gas":   {"base": (140, 120, 180), "dark": (80, 60, 130),   "accent": (200, 180, 220)},
    "earth": {"base": (60, 140, 80),   "dark": (30, 80, 120),   "accent": (100, 180, 100)},
    "bare":  {"base": (150, 140, 130), "dark": (90, 85, 80),    "accent": (190, 185, 175)},
}

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def apply_circle_mask(img):
    """STRICT mask: any pixel whose CENTER is outside radius r gets alpha=0.
    Uses pixel center sampling (x+0.5, y+0.5) to avoid sub-pixel leakage."""
    w, h = img.size
    cx, cy = w / 2.0, h / 2.0
    r = min(cx, cy) - 1.0   # 1px transparent border
    px = img.load()
    for y in range(h):
        for x in range(w):
            dx = (x + 0.5) - cx
            dy = (y + 0.5) - cy
            if math.sqrt(dx * dx + dy * dy) > r:
                px[x, y] = (0, 0, 0, 0)
    return img

def planet_frame(ptype, pal, frame, seed=42):
    """Draw planet at 32×32 using per-pixel putpixel, upscale NEAREST, apply strict mask."""
    rng = random.Random(seed)
    shift = frame * (ss // 4)   # horizontal band scroll ~8px in 32px space
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    cx = cy = ss / 2.0          # 16.0
    r = ss / 2.0 - 1.0         # 15.0
    noise = [[rng.random() for _ in range(ss * 2)] for _ in range(ss)]
    for y in range(ss):
        for x in range(ss):
            dx, dy = x - cx + 0.5, y - cy + 0.5   # pixel-center distance
            dist = math.sqrt(dx * dx + dy * dy)
            if dist > r:
                continue   # outside circle → leave transparent
            nx, ny = dx / r, dy / r
            nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
            light = min(1.0, max(0.0, 0.35 * (-nx) + 0.35 * (-ny) + 0.7 * nz) * 1.2)
            n = noise[y][(x + shift) % ss]
            if ptype == "gas":
                band = math.sin(ny * 4 + n * 2) * 0.5 + 0.5
                base = lerp(pal["dark"], pal["accent"], band)
            elif ptype == "lava":
                base = lerp(pal["dark"], pal["accent"], 1.0) if n > 0.75 else pal["base"]
            elif ptype == "ice":
                base = lerp(pal["base"], pal["accent"], math.sin(nx * 4 + n * 3) * 0.5 + 0.5)
            elif ptype == "earth":
                base = pal["base"] if n > 0.45 else pal["dark"]
            else:
                base = lerp(pal["dark"], pal["base"], n)
            c = lerp((30, 20, 15), base, light)
            rim = max(0.0, 1.0 - (dist / r) ** 3)
            c = tuple(int(c[i] * (0.3 + 0.7 * rim)) for i in range(3))
            img.putpixel((x, y), (*c, 255))
    # Upscale NEAREST then apply strict circle mask at full resolution
    out = img.resize((S, S), Image.Resampling.NEAREST)
    apply_circle_mask(out)
    return out

for name, pal in TYPES.items():
    sheet = Image.new("RGBA", (S, S * 4), (0, 0, 0, 0))
    for f in range(4):
        sheet.paste(planet_frame(name, pal, f), (0, f * S))
    out_path = os.path.join(OUT, f"pp_{name}_sheet.png")
    sheet.save(out_path)
    print(f"Saved {out_path}")
