#!/usr/bin/env python3
"""Generate PixelPlanets-style 64x64 RGBA planet sprites via PIL.
Each starType gets a deterministic palette and surface pattern.
Usage: python3 tools/gen_pixelplanet.py [type ...] [--seed N] [--size 64]
Saves to assets/planet/pp_<type>.png (RGBA, color type 6).
"""
import math, random, sys, os
from PIL import Image, ImageDraw

TYPES = {
    "ice":   {"base": (160, 210, 240), "dark": (80, 130, 180), "accent": (220, 240, 255)},
    "lava":  {"base": (180, 60, 20),   "dark": (80, 20, 10),   "accent": (255, 180, 40)},
    "dry":   {"base": (180, 150, 100), "dark": (120, 90, 50),  "accent": (210, 190, 140)},
    "gas":   {"base": (140, 120, 180), "dark": (80, 60, 130),  "accent": (200, 180, 220)},
    "earth": {"base": (60, 140, 80),   "dark": (30, 80, 120),  "accent": (100, 180, 100)},
    "bare":  {"base": (150, 140, 130), "dark": (90, 85, 80),   "accent": (190, 185, 175)},
}

def lerp_color(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def generate(ptype, seed=42, size=64):
    rng = random.Random(seed)
    pal = TYPES[ptype]
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cx, cy, r = size / 2, size / 2, size / 2 - 2
    # noise grid for surface detail
    noise = [[rng.random() for _ in range(size)] for _ in range(size)]
    for y in range(size):
        for x in range(size):
            dx, dy = x - cx, y - cy
            dist = math.sqrt(dx * dx + dy * dy)
            if dist > r:
                continue
            # sphere shading: light from upper-left
            nx, ny = dx / r, dy / r
            nz = math.sqrt(max(0, 1 - nx * nx - ny * ny))
            light = max(0, 0.35 * (-nx) + 0.35 * (-ny) + 0.7 * nz)
            light = min(1.0, light * 1.2)
            # surface noise bands
            n = noise[y][x]
            if ptype == "gas":
                band = math.sin(ny * 8 + n * 2) * 0.5 + 0.5
                base = lerp_color(pal["dark"], pal["accent"], band)
            elif ptype == "lava":
                crack = 1.0 if n > 0.78 else 0.0
                base = lerp_color(pal["dark"], pal["accent"], crack) if crack else pal["base"]
            elif ptype == "ice":
                streak = math.sin(nx * 6 + n * 3) * 0.5 + 0.5
                base = lerp_color(pal["base"], pal["accent"], streak * 0.6)
            elif ptype == "earth":
                land = 1 if n > 0.45 else 0
                base = pal["base"] if land else pal["dark"]
            else:
                base = lerp_color(pal["dark"], pal["base"], n)
            c = lerp_color((30, 20, 15), base, light)
            # rim darkening
            rim = max(0, 1 - (dist / r) ** 3)
            alpha = 255 if dist <= r - 0.5 else int(255 * max(0, r - dist + 0.5))
            c = tuple(int(c[i] * (0.3 + 0.7 * rim)) for i in range(3))
            img.putpixel((x, y), (*c, alpha))
    return img

if __name__ == "__main__":
    args = sys.argv[1:]
    seed = 20260905
    size = 64
    types_to_gen = []
    i = 0
    while i < len(args):
        if args[i] == "--seed":
            seed = int(args[i + 1]); i += 2
        elif args[i] == "--size":
            size = int(args[i + 1]); i += 2
        else:
            types_to_gen.append(args[i]); i += 1
    if not types_to_gen:
        types_to_gen = list(TYPES.keys())
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "planet")
    os.makedirs(out_dir, exist_ok=True)
    for t in types_to_gen:
        img = generate(t, seed=seed, size=size)
        path = os.path.join(out_dir, f"pp_{t}.png")
        img.save(path)
        print(f"Saved {path} ({img.size[0]}x{img.size[1]}, mode={img.mode})")
