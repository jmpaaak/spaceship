#!/usr/bin/env python3
"""Generate a 128x128 pixel-art Earth sprite — clean style."""
from PIL import Image
import math, random
random.seed(7)
S = 128
img = Image.new("RGBA", (S, S), (0,0,0,0))
R = S // 2 - 2
cx, cy = S // 2, S // 2

# Continent mask via clustered blobs
land_mask = [[False]*S for _ in range(S)]
seeds = []
for _ in range(5):
    a = random.uniform(0, 2*math.pi)
    r = random.uniform(0.1, 0.55) * R
    seeds.append((cx+math.cos(a)*r, cy+math.sin(a)*r, random.uniform(16,30)))
for _ in range(10):
    px, py = random.choice(seeds)[:2]
    ox = px + random.uniform(-18, 18)
    oy = py + random.uniform(-18, 18)
    seeds.append((ox, oy, random.uniform(6, 14)))
for y in range(S):
    for x in range(S):
        for sx, sy, sr in seeds:
            if (x-sx)**2 + (y-sy)**2 < sr*sr:
                land_mask[y][x] = True
                break

for y in range(S):
    for x in range(S):
        dx, dy = x - cx, y - cy
        d = math.sqrt(dx*dx + dy*dy)
        if d > R:
            continue
        nd = d / R
        light = max(0.45, min(1.05, 0.75 + (-dx*0.7 - dy*0.7) / (R * 2)))
        shade = max(0.35, 1.0 - nd * 0.5) * light
        polar = abs(dy) / R
        if polar > 0.82:
            c = (210, 225, 240)
        elif land_mask[y][x]:
            h = math.sin(x*0.3)*math.cos(y*0.25)*0.5+0.5
            if polar > 0.65:
                c = (100, 140, 90)
            elif h < 0.3:
                c = (40, 110, 50)
            elif h < 0.7:
                c = (55, 140, 65)
            else:
                c = (75, 155, 75)
        else:
            if nd < 0.35:
                c = (20, 55, 140)
            elif nd < 0.6:
                c = (30, 75, 160)
            else:
                c = (40, 95, 180)
        # Clouds — smooth large patches
        cn = math.sin(x*0.09+1)*math.cos(y*0.07+2) + math.sin(x*0.05-y*0.06)*0.5
        if cn > 0.7:
            mix = min(1.0, (cn - 0.7) * 3)
            c = (int(c[0]+(235-c[0])*mix), int(c[1]+(240-c[1])*mix), int(c[2]+(245-c[2])*mix))
        r = min(255, int(c[0]*shade))
        g = min(255, int(c[1]*shade))
        b = min(255, int(c[2]*shade))
        # Atmosphere edge glow
        if nd > 0.88:
            glow = (nd - 0.88) / 0.12
            r = min(255, int(r + glow*40))
            g = min(255, int(g + glow*60))
            b = min(255, int(b + glow*100))
        img.putpixel((x, y), (r, g, b, 255))

img.save("assets/earth/earth_generic.png")
print("OK 128x128")
