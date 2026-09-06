#!/usr/bin/env python3
"""4-frame rotation sheets for 6 planet types. Output: assets/planet/pp_*_sheet.png (64x256)."""
import os, math, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "planet")
os.makedirs(OUT, exist_ok=True)
S, B = 64, 4  # final size, block

TYPES = {
    "ice":   {"base": (160,210,240), "dark": (80,130,180),  "accent": (220,240,255)},
    "lava":  {"base": (180,60,20),   "dark": (80,20,10),    "accent": (255,180,40)},
    "dry":   {"base": (180,150,100), "dark": (120,90,50),   "accent": (210,190,140)},
    "gas":   {"base": (140,120,180), "dark": (80,60,130),   "accent": (200,180,220)},
    "earth": {"base": (60,140,80),   "dark": (30,80,120),   "accent": (100,180,100)},
    "bare":  {"base": (150,140,130), "dark": (90,85,80),    "accent": (190,185,175)},
}

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i]-a[i]) * t) for i in range(3))

def planet_frame(ptype, pal, frame, seed=42):
    ss = S // B  # 16
    rng = random.Random(seed)
    shift = frame * (ss // 4)   # horizontal band scroll ~4px in small space
    img = Image.new("RGBA", (ss, ss), (0,0,0,0))
    cx = cy = ss / 2
    r = ss / 2 - 1
    noise = [[rng.random() for _ in range(ss + ss)] for _ in range(ss)]
    for y in range(ss):
        for x in range(ss):
            dx, dy = x - cx, y - cy
            dist = math.sqrt(dx*dx + dy*dy)
            if dist > r: continue
            nx, ny = dx/r, dy/r
            nz = math.sqrt(max(0, 1 - nx*nx - ny*ny))
            light = min(1.0, max(0, 0.35*(-nx) + 0.35*(-ny) + 0.7*nz) * 1.2)
            # sample noise with horizontal shift for rotation feel
            n = noise[y][(x + shift) % (ss)]
            if ptype == "gas":
                band = math.sin(ny * 4 + n * 2) * 0.5 + 0.5
                base = lerp(pal["dark"], pal["accent"], band)
            elif ptype == "lava":
                base = lerp(pal["dark"], pal["accent"], 1.0) if n > 0.75 else pal["base"]
            elif ptype == "ice":
                base = lerp(pal["base"], pal["accent"], math.sin(nx*4+n*3)*0.5+0.5)
            elif ptype == "earth":
                base = pal["base"] if n > 0.45 else pal["dark"]
            else:
                base = lerp(pal["dark"], pal["base"], n)
            c = lerp((30,20,15), base, light)
            rim = max(0, 1 - (dist/r)**3)
            c = tuple(int(c[i] * (0.3 + 0.7*rim)) for i in range(3))
            alpha = 255 if dist <= r-0.5 else int(255*max(0, r-dist+0.5))
            img.putpixel((x, y), (*c, alpha))
    return img.resize((S, S), Image.Resampling.NEAREST)

for name, pal in TYPES.items():
    sheet = Image.new("RGBA", (S, S * 4), (0, 0, 0, 0))
    for f in range(4):
        sheet.paste(planet_frame(name, pal, f), (0, f * S))
    out_path = os.path.join(OUT, f"pp_{name}_sheet.png")
    sheet.save(out_path)
    print(f"Saved {out_path}")
