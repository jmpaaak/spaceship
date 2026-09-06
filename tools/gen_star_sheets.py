#!/usr/bin/env python3
"""4-frame rotation sheets for 6 star types. Output: assets/star/star_*_sheet.png (64x256)."""
import os, math
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "star")
os.makedirs(OUT, exist_ok=True)
S, B = 64, 4  # final size, block size → draw at S//B=16

TYPES = {
    "sun":  {"core": (255,220,60),  "mid": (255,180,30),  "corona": (255,140,20), "glow": (255,100,10)},
    "ice":  {"core": (200,230,255), "mid": (140,190,255),  "corona": (80,150,230), "glow": (50,100,200)},
    "lava": {"core": (255,160,40),  "mid": (255,100,20),   "corona": (220,50,10),  "glow": (180,30,0)},
    "dry":  {"core": (255,210,140), "mid": (230,170,90),   "corona": (200,130,60), "glow": (160,100,40)},
    "gas":  {"core": (180,220,255), "mid": (120,180,240),  "corona": (80,140,220), "glow": (50,100,180)},
    "bare": {"core": (240,240,240), "mid": (200,200,210),  "corona": (160,160,180),"glow": (120,120,150)},
}

def star_frame(pal, frame):
    ss = S // B  # 16
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = cy = ss // 2  # 8
    # glow offset rotates per frame (chunky: 1-pixel steps at small size)
    ang = frame * math.pi / 2
    gx, gy = int(round(math.cos(ang) * 1.5)), int(round(math.sin(ang) * 1.5))
    ag = 25 + frame * 15   # glow alpha pulses
    ac = 55 + frame * 20   # corona alpha pulses
    d.ellipse([cx-7+gx, cy-7+gy, cx+7+gx, cy+7+gy], fill=pal["glow"]   + (ag,))
    d.ellipse([cx-6,    cy-6,    cx+6,    cy+6],     fill=pal["corona"] + (ac,))
    d.ellipse([cx-5,    cy-5,    cx+5,    cy+5],     fill=pal["mid"]    + (175,))
    d.ellipse([cx-4,    cy-4,    cx+4,    cy+4],     fill=pal["core"]   + (255,))
    # highlight drifts opposite to glow
    hx = cx - 2 - int(round(math.cos(ang) * 0.8))
    hy = cy - 3 - int(round(math.sin(ang) * 0.8))
    d.ellipse([hx, hy, hx+2, hy+2], fill=(255, 255, 255, 90))
    return img.resize((S, S), Image.Resampling.NEAREST)

for name, pal in TYPES.items():
    sheet = Image.new("RGBA", (S, S * 4), (0, 0, 0, 0))
    for f in range(4):
        sheet.paste(star_frame(pal, f), (0, f * S))
    out_path = os.path.join(OUT, f"star_{name}_sheet.png")
    sheet.save(out_path)
    print(f"Saved {out_path}")
