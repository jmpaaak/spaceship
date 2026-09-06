#!/usr/bin/env python3
"""4-frame rotation sheet for hub planet (magenta/purple). Output: assets/planet/hub_sheet.png (64x256)."""
import os, math, random
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "planet")
os.makedirs(OUT, exist_ok=True)
S, B = 64, 4

PAL = {"base": (180, 80, 200), "dark": (90, 30, 130), "accent": (220, 140, 255)}

def lerp(a, b, t):
    return tuple(int(a[i] + (b[i]-a[i]) * t) for i in range(3))

def hub_frame(frame, seed=99):
    ss = S // B  # 16
    rng = random.Random(seed)
    shift = frame * (ss // 4)
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    cx = cy = ss / 2
    r = ss / 2 - 1
    noise = [[rng.random() for _ in range(ss * 2)] for _ in range(ss)]
    for y in range(ss):
        for x in range(ss):
            dx, dy = x - cx, y - cy
            dist = math.sqrt(dx*dx + dy*dy)
            if dist > r: continue
            nx, ny = dx/r, dy/r
            nz = math.sqrt(max(0, 1 - nx*nx - ny*ny))
            light = min(1.0, max(0, 0.35*(-nx) + 0.35*(-ny) + 0.7*nz) * 1.2)
            n = noise[y][(x + shift) % ss]
            # swirly magenta surface: diagonal bands + noise
            swirl = math.sin(nx * 5 - ny * 3 + n * 3) * 0.5 + 0.5
            base = lerp(PAL["dark"], PAL["accent"], swirl)
            # accent flecks
            if n > 0.80:
                base = PAL["accent"]
            c = lerp((20, 10, 30), base, light)
            rim = max(0, 1 - (dist/r)**3)
            c = tuple(int(c[i] * (0.3 + 0.7*rim)) for i in range(3))
            alpha = 255 if dist <= r-0.5 else int(255*max(0, r-dist+0.5))
            img.putpixel((x, y), (*c, alpha))
    return img.resize((S, S), Image.Resampling.NEAREST)

sheet = Image.new("RGBA", (S, S * 4), (0, 0, 0, 0))
for f in range(4):
    sheet.paste(hub_frame(f), (0, f * S))
out_path = os.path.join(OUT, "hub_sheet.png")
sheet.save(out_path)
print(f"Saved {out_path}")
