#!/usr/bin/env python3
"""Generate 6 central-star sprites (128×128, RGBA) — one per galaxy starType.
Chunky 4px retro style: draw at 32×32 then upscale NEAREST to 128×128.
Also generates star_sun_sheet.png (128×512, 4 frames) for animation.
Strict circle mask applied after upscale."""
import os, math, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "star")
os.makedirs(OUT, exist_ok=True)
S = 128          # final sprite size
B = 4            # block size → draw at S//B = 32
ss = S // B      # 32

TYPES = {
    "sun":  {"core": (255, 220, 60), "mid": (255, 180, 30), "corona": (255, 140, 20), "glow": (255, 100, 10)},
    "ice":  {"core": (200, 230, 255), "mid": (140, 190, 255), "corona": (80, 150, 230), "glow": (50, 100, 200)},
    "lava": {"core": (255, 160, 40), "mid": (255, 100, 20), "corona": (220, 50, 10), "glow": (180, 30, 0)},
    "dry":  {"core": (255, 210, 140), "mid": (230, 170, 90), "corona": (200, 130, 60), "glow": (160, 100, 40)},
    "gas":  {"core": (180, 220, 255), "mid": (120, 180, 240), "corona": (80, 140, 220), "glow": (50, 100, 180)},
    "bare": {"core": (240, 240, 240), "mid": (200, 200, 210), "corona": (160, 160, 180), "glow": (120, 120, 150)},
}

def apply_circle_mask(img):
    """Zero any pixel outside the inscribed circle (strict: dist > r → alpha=0)."""
    w, h = img.size
    cx, cy = w / 2, h / 2
    r = min(cx, cy) - 1.0   # 1px transparent border
    px = img.load()
    for y in range(h):
        for x in range(w):
            if math.sqrt((x - cx + 0.5) ** 2 + (y - cy + 0.5) ** 2) > r:
                px[x, y] = (0, 0, 0, 0)
    return img

def gen_star(name, pal):
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = ss // 2, ss // 2  # 16
    # Corona glow layers (scaled from 64→32, halve all radii)
    for r_draw, alpha, col in [(14, 40, pal["glow"]), (12, 70, pal["corona"]), (10, 140, pal["mid"])]:
        d.ellipse([cx - r_draw, cy - r_draw, cx + r_draw, cy + r_draw], fill=col + (alpha,))
    # Core
    d.ellipse([cx - 8, cy - 8, cx + 8, cy + 8], fill=pal["core"] + (255,))
    # Surface spots
    rng = random.Random(hash(name) % 2**32)
    for _ in range(5):
        sx = cx + rng.randint(-5, 5)
        sy = cy + rng.randint(-5, 5)
        sr = rng.randint(1, 3)
        dist = math.sqrt((sx - cx)**2 + (sy - cy)**2)
        if dist + sr < 8:
            r2, g2, b2 = pal["mid"]
            d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(r2, g2, b2, 180))
    # Highlight
    d.ellipse([cx - 5, cy - 6, cx - 1, cy - 2], fill=(255, 255, 255, 100))
    # Upscale NEAREST then apply strict circle mask
    out = img.resize((S, S), Image.Resampling.NEAREST)
    apply_circle_mask(out)
    out.save(os.path.join(OUT, f"star_{name}.png"))

for name, pal in TYPES.items():
    gen_star(name, pal)

# 4-frame pulse sheet (128×512) for sun — used by gen_star_sheets for sun variant
pal = TYPES["sun"]
sheet = Image.new("RGBA", (S, S * 4), (0, 0, 0, 0))
for frame in range(4):
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = ss // 2, ss // 2
    pulse = 15 + frame * 7
    d.ellipse([cx - 14, cy - 14, cx + 14, cy + 14], fill=pal["glow"] + (pulse,))
    d.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=pal["corona"] + (30 + frame * 10,))
    d.ellipse([cx - 10, cy - 10, cx + 10, cy + 10], fill=pal["mid"] + (140,))
    d.ellipse([cx - 8,  cy - 8,  cx + 8,  cy + 8],  fill=pal["core"] + (255,))
    d.ellipse([cx - 5,  cy - 6,  cx - 1,  cy - 2],  fill=(255, 255, 255, 100))
    frame_img = img.resize((S, S), Image.Resampling.NEAREST)
    apply_circle_mask(frame_img)
    sheet.paste(frame_img, (0, frame * S))
sheet.save(os.path.join(OUT, "star_sun_sheet.png"))

print(f"Generated 6 star sprites (128×128) + sun sheet (128×512) in {OUT}")
