#!/usr/bin/env python3
"""Generate 6 central-star sprites (64×64, RGBA) — one per galaxy starType.
Chunky 4px retro style matching planet sprites. Each star has a glowing
corona, surface texture, and type-specific color palette."""
import os, math
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "star")
os.makedirs(OUT, exist_ok=True)
S = 64
BLOCK = 4  # chunky pixel size

TYPES = {
    "sun":  {"core": (255, 220, 60), "mid": (255, 180, 30), "corona": (255, 140, 20), "glow": (255, 100, 10)},
    "ice":  {"core": (200, 230, 255), "mid": (140, 190, 255), "corona": (80, 150, 230), "glow": (50, 100, 200)},
    "lava": {"core": (255, 160, 40), "mid": (255, 100, 20), "corona": (220, 50, 10), "glow": (180, 30, 0)},
    "dry":  {"core": (255, 210, 140), "mid": (230, 170, 90), "corona": (200, 130, 60), "glow": (160, 100, 40)},
    "gas":  {"core": (180, 220, 255), "mid": (120, 180, 240), "corona": (80, 140, 220), "glow": (50, 100, 180)},
    "bare": {"core": (240, 240, 240), "mid": (200, 200, 210), "corona": (160, 160, 180), "glow": (120, 120, 150)},
}

def gen_star(name, pal):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = S // 2, S // 2
    # Corona glow layers
    for r, alpha, col in [(28, 40, pal["glow"]), (24, 70, pal["corona"]), (20, 140, pal["mid"])]:
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=col + (alpha,))
    # Core
    d.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=pal["core"] + (255,))
    # Surface spots (darker patches)
    import random
    rng = random.Random(hash(name) % 2**32)
    for _ in range(5):
        sx = cx + rng.randint(-10, 10)
        sy = cy + rng.randint(-10, 10)
        sr = rng.randint(2, 5)
        dist = math.sqrt((sx - cx)**2 + (sy - cy)**2)
        if dist + sr < 16:
            r, g, b = pal["mid"]
            d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(r, g, b, 180))
    # Highlight
    d.ellipse([cx - 10, cy - 12, cx - 2, cy - 4], fill=(255, 255, 255, 100))
    # Pixelize to chunky 4px blocks
    small = img.resize((S // BLOCK, S // BLOCK), Image.NEAREST)
    img = small.resize((S, S), Image.NEAREST)
    img.save(os.path.join(OUT, f"star_{name}.png"))

for name, pal in TYPES.items():
    gen_star(name, pal)

# Also generate a 4-frame simple "pulse" sprite sheet (64×256) for animation
# Each frame is the same star at slightly different corona alpha
sheet = Image.new("RGBA", (S, S * 4), (0, 0, 0, 0))
pal = TYPES["sun"]
for frame in range(4):
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx, cy = S // 2, S // 2
    pulse = 30 + frame * 15
    d.ellipse([cx - 28, cy - 28, cx + 28, cy + 28], fill=pal["glow"] + (pulse,))
    d.ellipse([cx - 24, cy - 24, cx + 24, cy + 24], fill=pal["corona"] + (60 + frame * 20,))
    d.ellipse([cx - 20, cy - 20, cx + 20, cy + 20], fill=pal["mid"] + (140,))
    d.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=pal["core"] + (255,))
    d.ellipse([cx - 10, cy - 12, cx - 2, cy - 4], fill=(255, 255, 255, 100))
    small = img.resize((S // BLOCK, S // BLOCK), Image.NEAREST)
    img = small.resize((S, S), Image.NEAREST)
    sheet.paste(img, (0, frame * S))
sheet.save(os.path.join(OUT, "star_sun_sheet.png"))

print("Generated 6 star sprites + 1 animation sheet in", OUT)
