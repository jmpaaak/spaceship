#!/usr/bin/env python3
"""Generate 32x32 chunky-pixel part icons for hull & engine parts."""
import json, os
from PIL import Image, ImageDraw

SUIT = {"solar":(255,210,50),"nebula":(178,76,229),"void":(50,70,204),"pulsar":(25,217,242)}
PX = 4  # chunky pixel size (32/8 grid)

def px(draw, gx, gy, c, a=255):
    x, y = gx*PX, gy*PX
    draw.rectangle([x, y, x+PX-1, y+PX-1], fill=(*c, a))

HULL_ROWS = [(3,4),(2,3,4,5),(1,2,3,4,5,6),(1,2,3,4,5,6),
             (1,2,3,4,5,6),(2,3,4,5),(3,4),(3,)]
ENGINE_ROWS = [(3,4),(3,4),(2,3,4,5),(2,3,4,5),
               (1,2,3,4,5,6),(1,2,3,4,5,6),(1,2,5,6),(0,1,6,7)]

def draw_icon(draw, rows, c, fade_after):
    for gy, cols in enumerate(rows):
        for gx in cols:
            px(draw, gx, gy, c, 255 if gy < fade_after else 200 if fade_after == 5 else 180)

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = os.path.join(root, "assets", "part_icons")
os.makedirs(out, exist_ok=True)

for fn in ("hull_parts.json", "engine_parts.json"):
    is_hull = fn.startswith("hull")
    data = json.load(open(os.path.join(root, "game", "data", fn)))
    for p in data["parts"]:
        img = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        d = ImageDraw.Draw(img)
        c = SUIT.get(p.get("suit", ""), (160, 160, 160))
        draw_icon(d, HULL_ROWS if is_hull else ENGINE_ROWS, c, 5 if is_hull else 6)
        img.save(os.path.join(out, p["id"] + ".png"))
print(f"Generated icons in {out}")
