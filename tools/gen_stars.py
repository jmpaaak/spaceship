#!/usr/bin/env python3
"""Generate 6 central-star sprites (256×256, RGBA) — one per galaxy starType.
Chunky retro style: draw at 64x64 then upscale NEAREST to 256x256.
Also generates star_sun_sheet.png (256x1024, 4 frames) for animation."""
import os, math, random
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "star")
os.makedirs(OUT, exist_ok=True)
S = 256          # final sprite size
B = 4            # block size → draw at S//B = 64
ss = S // B      # 64

TYPES = {
    "sun":  {"core": (255, 220, 60), "mid": (255, 180, 30), "corona": (255, 140, 20), "glow": (255, 100, 10)},
    "ice":  {"core": (200, 230, 255), "mid": (140, 190, 255), "corona": (80, 150, 230), "glow": (50, 100, 200)},
    "lava": {"core": (255, 160, 40), "mid": (255, 100, 20), "corona": (220, 50, 10), "glow": (180, 30, 0)},
    "dry":  {"core": (255, 210, 140), "mid": (230, 170, 90), "corona": (200, 130, 60), "glow": (160, 100, 40)},
    "gas":  {"core": (180, 220, 255), "mid": (120, 180, 240), "corona": (80, 140, 220), "glow": (50, 100, 180)},
    "bare": {"core": (240, 240, 240), "mid": (200, 200, 210), "corona": (160, 160, 180), "glow": (120, 120, 150)},
}

def draw_star_img(name, pal, frame=None):
    img = Image.new("RGBA", (ss, ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = ss // 2, ss // 2  # 32
    rng = random.Random(hash(name) % 2**32 if frame is None else (hash(name) + frame) % 2**32)
    
    # Draw jagged corona
    num_rays = rng.randint(12, 18)
    for i in range(num_rays):
        angle = (i / num_rays) * 2 * math.pi + rng.uniform(-0.2, 0.2)
        if frame is not None:
            angle += frame * (math.pi / 2) / 4  # rotate slightly over frames
        length = rng.uniform(22, 28)
        width = rng.uniform(2, 6)
        ex = cx + math.cos(angle) * length
        ey = cy + math.sin(angle) * length
        d.line([(cx, cy), (ex, ey)], fill=pal["glow"] + (180,), width=int(width))

    # Glow layers
    pulse = 0
    if frame is not None:
        pulse = math.sin(frame * math.pi / 2) * 2
    
    for r_draw, alpha, col in [(24 + pulse, 60, pal["glow"]), (20 + pulse, 120, pal["corona"]), (16, 200, pal["mid"])]:
        d.ellipse([cx - r_draw, cy - r_draw, cx + r_draw, cy + r_draw], fill=col + (int(alpha),))
        
    # Core
    d.ellipse([cx - 12, cy - 12, cx + 12, cy + 12], fill=pal["core"] + (255,))
    
    # Surface spots
    for _ in range(8):
        sx = cx + rng.randint(-8, 8)
        sy = cy + rng.randint(-8, 8)
        sr = rng.randint(2, 4)
        dist = math.sqrt((sx - cx)**2 + (sy - cy)**2)
        if dist + sr < 12:
            r2, g2, b2 = pal["mid"]
            d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(r2, g2, b2, 180))
            
    # Highlight
    d.ellipse([cx - 8, cy - 10, cx - 2, cy - 4], fill=(255, 255, 255, 120))
    
    return img.resize((S, S), Image.Resampling.NEAREST)

for name, pal in TYPES.items():
    out = draw_star_img(name, pal)
    out.save(os.path.join(OUT, f"star_{name}.png"))

# 4-frame pulse sheet (256x1024) for all types
for name, pal in TYPES.items():
    sheet = Image.new("RGBA", (S, S * 4), (0, 0, 0, 0))
    for frame in range(4):
        frame_img = draw_star_img(name, pal, frame=frame)
        sheet.paste(frame_img, (0, frame * S))
    sheet.save(os.path.join(OUT, f"star_{name}_sheet.png"))

print(f"Generated 6 star sprites + sheets (256x256 per frame) in {OUT}")
