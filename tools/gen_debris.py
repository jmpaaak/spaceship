#!/usr/bin/env python3
"""Generate 3 debris sprites (32x32 RGBA): asteroid, can, scrap — chunky 4px retro."""
from PIL import Image
import math, os

S = 32
T = S // 4   # 8 — draw at 8x8, upscale to 32x32
os.makedirs("assets/debris", exist_ok=True)

# ── Asteroid (brown rocky blob) ─────────────────────────────────────────────
def make_asteroid():
    sm = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    cx = cy = T / 2
    R = T / 2 - 0.5
    for y in range(T):
        for x in range(T):
            dx, dy = x - cx + 0.5, y - cy + 0.5
            d = math.sqrt(dx*dx + dy*dy)
            # Lumpy radius via sine wobble
            wobble = 1.0 + 0.25 * math.sin(math.atan2(dy, dx) * 4 + 1)
            if d > R * wobble:
                continue
            nd = d / R
            light = max(0.45, 1.0 + (-dx * 0.5 - dy * 0.5) / (R * 2))
            shade = max(0.35, 1.0 - nd * 0.35) * light
            crater = math.sin(x * 2.3 + 0.7) * math.cos(y * 1.9 + 0.4) > 0.5
            base = (110, 70, 40) if crater else (155, 100, 55)
            v = tuple(min(255, int(c * shade)) for c in base)
            sm.putpixel((x, y), (*v, 255))
    return sm.resize((S, S), Image.Resampling.NEAREST)

# ── Can (metallic grey cylinder) ────────────────────────────────────────────
def make_can():
    sm = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    # cylinder: columns 1-6, rows 1-6
    for y in range(1, T - 1):
        for x in range(1, T - 1):
            # cylinder shading: left/right darker, centre bright
            cx_frac = (x - 1) / (T - 3)        # 0..1
            shade = 1.0 - abs(cx_frac - 0.5) * 1.2
            shade = max(0.45, min(1.0, shade))
            # stripe bands
            stripe = (y % 3 == 0)
            base = 120 if stripe else 175
            v = min(255, int(base * shade))
            sm.putpixel((x, y), (v, v + 4, v + 8, 255))
    # top cap — lighter row
    for x in range(1, T - 1):
        sm.putpixel((x, 1), (210, 215, 220, 255))
    # bottom rim
    for x in range(1, T - 1):
        sm.putpixel((x, T - 2), (90, 95, 100, 255))
    return sm.resize((S, S), Image.Resampling.NEAREST)

# ── Scrap (angular metal pieces) ────────────────────────────────────────────
def make_scrap():
    sm = Image.new("RGBA", (T, T), (0, 0, 0, 0))
    # Draw two angular shards
    # Shard 1: upper-left triangle-ish
    shard1 = [(0,0),(5,0),(5,3),(2,5),(0,5)]
    # Shard 2: lower-right
    shard2 = [(3,3),(7,2),(7,7),(4,7),(3,5)]
    def fill_poly(pts, color):
        # Scanline fill inside pixel grid
        for y in range(T):
            xs = []
            n = len(pts)
            for i in range(n):
                x0,y0 = pts[i]; x1,y1 = pts[(i+1)%n]
                if (y0<=y<y1) or (y1<=y<y0):
                    xi = x0 + (y - y0) * (x1-x0) / (y1-y0)
                    xs.append(xi)
            xs.sort()
            for k in range(0, len(xs)-1, 2):
                for x in range(int(xs[k]), int(xs[k+1])+1):
                    if 0<=x<T and 0<=y<T:
                        sm.putpixel((x,y), color)
    fill_poly(shard1, (130, 140, 150, 255))
    fill_poly(shard2, (100, 115, 125, 255))
    # Highlight edge pixels on shard1 top row
    for x in range(5):
        sm.putpixel((x, 0), (200, 210, 215, 255))
    return sm.resize((S, S), Image.Resampling.NEAREST)

make_asteroid().save("assets/debris/asteroid.png")
make_can().save("assets/debris/can.png")
make_scrap().save("assets/debris/scrap.png")
print("OK 3x 32x32 RGBA debris sprites saved.")
