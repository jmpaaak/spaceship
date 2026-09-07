#!/usr/bin/env python3
"""4-frame rotation sheet for hub planet (magenta/purple). Output: assets/planet/hub_sheet.png (128×512).
Draw at 32×32 (block=4) then upscale NEAREST to 128×128.
STRICT circular alpha mask: any pixel with dist > radius gets alpha=0 (fixes green square artifact)."""
import os, math, random
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "planet")
os.makedirs(OUT, exist_ok=True)
S, B = 128, 4   # final size, block size → draw at S//B = 32
ss = S // B      # 32

PAL = {"base": (180, 80, 200), "dark": (90, 30, 130), "accent": (220, 140, 255)}

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

def hub_frame(frame, seed=99):
    """Draw hub planet at 32×32, upscale NEAREST to 128×128, apply strict mask."""
    rng = random.Random(seed)
    shift = frame * (ss // 4)  # 8px scroll per frame in 32px space
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    cx = cy = ss / 2.0          # 16.0
    r = ss / 2.0 - 1.0         # 15.0
    noise = [[rng.random() for _ in range(ss * 2)] for _ in range(ss)]
    for y in range(ss):
        for x in range(ss):
            dx, dy = x - cx + 0.5, y - cy + 0.5  # pixel-center distance
            dist = math.sqrt(dx * dx + dy * dy)
            if dist > r:
                continue   # outside circle → leave transparent
            nx, ny = dx / r, dy / r
            nz = math.sqrt(max(0.0, 1.0 - nx * nx - ny * ny))
            light = min(1.0, max(0.0, 0.35 * (-nx) + 0.35 * (-ny) + 0.7 * nz) * 1.2)
            n = noise[y][(x + shift) % ss]
            swirl = math.sin(nx * 5 - ny * 3 + n * 3) * 0.5 + 0.5
            base = lerp(PAL["dark"], PAL["accent"], swirl)
            if n > 0.80:
                base = PAL["accent"]
            c = lerp((20, 10, 30), base, light)
            rim = max(0.0, 1.0 - (dist / r) ** 3)
            c = tuple(int(c[i] * (0.3 + 0.7 * rim)) for i in range(3))
            img.putpixel((x, y), (*c, 255))
    # Upscale NEAREST then apply strict circle mask at full resolution
    out = img.resize((S, S), Image.Resampling.NEAREST)
    apply_circle_mask(out)
    return out

sheet = Image.new("RGBA", (S, S * 4), (0, 0, 0, 0))
for f in range(4):
    sheet.paste(hub_frame(f), (0, f * S))
out_path = os.path.join(OUT, "hub_sheet.png")
sheet.save(out_path)
print(f"Saved {out_path}")
