#!/usr/bin/env python3
"""Generate 4 suit-icon sprites (32x32 RGBA) — chunky 4px retro.
   solar (gold sun), nebula (purple cloud), void (dark-blue diamond), pulsar (cyan lightning).
"""
from PIL import Image, ImageDraw
import os

S = 32
T = S // 4   # 8 — draw at 8x8, upscale
os.makedirs("assets/suit_icons", exist_ok=True)

def upscale(sm):
    return sm.resize((S, S), Image.Resampling.NEAREST)

def new(bg=(0,0,0,0)):
    return Image.new("RGBA", (T, T), bg)

# ── Solar: gold sun with rays ────────────────────────────────────────────────
def make_solar():
    sm = new()
    d = ImageDraw.Draw(sm)
    # Central disc (3x3 at centre)
    d.rectangle([2,2,5,5], fill=(255, 200, 30, 255))
    # Cardinal rays
    for rx,ry in [(0,3),(7,3),(3,0),(3,7)]:
        d.point([(rx,ry)], fill=(255, 230, 80, 255))
    # Diagonal rays
    for rx,ry in [(1,1),(6,1),(1,6),(6,6)]:
        d.point([(rx,ry)], fill=(255, 210, 50, 220))
    return upscale(sm)

# ── Nebula: purple cloud puffs ───────────────────────────────────────────────
def make_nebula():
    sm = new()
    d = ImageDraw.Draw(sm)
    # Three overlapping ellipses
    d.ellipse([0,2,4,6], fill=(180, 60, 220, 240))
    d.ellipse([2,1,6,5], fill=(200, 80, 230, 240))
    d.ellipse([3,3,7,7], fill=(160, 50, 200, 240))
    # Highlight dot
    d.point([(3,2)], fill=(230, 180, 255, 255))
    return upscale(sm)

# ── Void: dark-blue diamond ──────────────────────────────────────────────────
def make_void():
    sm = new()
    # Diamond polygon: top(3,0) right(7,3) bottom(3,7) left(0,3) — but T=8 so coords 0..7
    pts = [(3,0),(7,3),(3,7),(0,3)]
    d = ImageDraw.Draw(sm)
    d.polygon(pts, fill=(20, 30, 140, 255))
    # Inner highlight
    d.polygon([(3,1),(6,3),(3,6),(1,3)], fill=(40, 60, 200, 255))
    # Bright centre pixel
    d.point([(3,3)], fill=(120, 160, 255, 255))
    return upscale(sm)

# ── Pulsar: cyan lightning bolt ──────────────────────────────────────────────
def make_pulsar():
    sm = new()
    d = ImageDraw.Draw(sm)
    # Thick zigzag bolt: 2px wide line segments
    bolt = [(4,0),(4,1),(5,1),(5,2),(3,2),(3,3),(5,3),(5,4),(2,4),(2,5),(4,5),(4,7)]
    # Draw bold by filling adjacent pixels
    for i in range(len(bolt)-1):
        x0,y0 = bolt[i]; x1,y1 = bolt[i+1]
        d.line([x0,y0,x1,y1], fill=(0, 230, 255, 255), width=1)
    # Glow — lighter shade one pixel wider (re-draw thinner)
    d.point([(3,0),(5,7)], fill=(180, 255, 255, 180))
    return upscale(sm)

make_solar().save("assets/suit_icons/solar.png")
make_nebula().save("assets/suit_icons/nebula.png")
make_void().save("assets/suit_icons/void.png")
make_pulsar().save("assets/suit_icons/pulsar.png")
print("OK 4x 32x32 RGBA suit icons saved.")
