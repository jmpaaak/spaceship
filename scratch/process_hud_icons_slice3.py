#!/usr/bin/env python3
"""ComfyUI generate + chroma-key post-process for HUD icon group (4) slice 3.

Generation is ComfyUI-only. Pillow only knocks out the generated backdrop,
crops the symbol, and nearest-neighbor fits it into a 32x32 RGBA canvas.
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import time

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MANIFEST_PATH = os.path.join(ROOT, "docs", "assets", "MANIFEST.json")
CANVAS = 32
TARGET = 22  # ~70% of 32x32, padding around a solid HUD symbol
DARK = 40
LIGHT_MIN = 180
SIM = 28

ICONS = [
    {
        "path": "assets/effects/hud_galaxy.png",
        "seed": 20260905307,
        "prompt": (
            "pixel art, 16-bit, tiny solid gold eight-pointed star HUD icon, "
            "simple sparkling galaxy star, single solid-color galaxy-name "
            "symbol centered with padding, isolated game HUD sprite, black "
            "background, no text, no numbers, no letters, no scene, no frame, "
            "no glow bloom"
        ),
        "qa_name": "gold eight-pointed-star galaxy HUD icon",
    },
    {
        "path": "assets/effects/hud_return.png",
        "seed": 20260905308,
        "prompt": (
            "pixel art, 16-bit, tiny solid cyan downward chevron HUD icon, "
            "simple front-view Earth-return arrow pointing down, single "
            "solid-color return-progress symbol centered with padding, "
            "isolated game HUD sprite, black background, no text, no numbers, "
            "no letters, no scene, no frame, no glow bloom"
        ),
        "qa_name": "cyan downward-chevron return HUD icon",
    },
    {
        "path": "assets/effects/hud_earth.png",
        "seed": 20260905309,
        "prompt": (
            "pixel art, 16-bit, tiny solid cyan Earth globe HUD icon, simple "
            "front-view planet Earth with continents, single solid-color "
            "earth-distance symbol centered with padding, isolated game HUD "
            "sprite, black background, no text, no numbers, no letters, no "
            "scene, no frame, no glow bloom"
        ),
        "qa_name": "cyan Earth-globe earth HUD icon",
    },
]


def generate(spec: dict) -> None:
    cmd = [
        sys.executable,
        "tools/comfyui_asset_pipeline.py",
        "--asset-path",
        spec["path"],
        "--prompt",
        spec["prompt"],
        "--width",
        "512",
        "--height",
        "512",
        "--seed",
        str(spec["seed"]),
        "--qa",
        f"INBOX group (4) HUD regen: 32x32 transparent {spec['qa_name']}",
    ]
    print("Generating", spec["path"], "seed", spec["seed"], flush=True)
    res = subprocess.run(cmd, cwd=ROOT)
    if res.returncode != 0:
        raise SystemExit(res.returncode)


def _similar(a, b, tol: int) -> bool:
    return abs(a[0] - b[0]) <= tol and abs(a[1] - b[1]) <= tol and abs(a[2] - b[2]) <= tol


def flood_transparent(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    avg = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    dark_mode = avg[0] < DARK and avg[1] < DARK and avg[2] < DARK
    light_mode = avg[0] >= LIGHT_MIN and avg[1] >= LIGHT_MIN and avg[2] >= LIGHT_MIN
    seen = [[False] * h for _ in range(w)]
    stack = []
    for x in range(w):
        stack.append((x, 0))
        stack.append((x, h - 1))
    for y in range(h):
        stack.append((0, y))
        stack.append((w - 1, y))
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[x][y]:
            continue
        seen[x][y] = True
        r, g, b, a = px[x, y]
        if dark_mode:
            if r >= DARK or g >= DARK or b >= DARK:
                continue
        elif light_mode:
            if not _similar((r, g, b), avg, SIM):
                continue
        else:
            if not _similar((r, g, b), avg, SIM):
                continue
        px[x, y] = (0, 0, 0, 0)
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return img


def fit_canvas(img: Image.Image, path: str) -> Image.Image:
    bbox = img.getbbox()
    if not bbox:
        raise SystemExit(f"{path} became fully transparent")
    cropped = img.crop(bbox)
    w, h = cropped.size
    ratio = min(TARGET / w, TARGET / h)
    new_w = max(1, int(w * ratio))
    new_h = max(1, int(h * ratio))
    resized = cropped.resize((new_w, new_h), Image.Resampling.NEAREST)
    final = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    final.paste(resized, ((CANVAS - new_w) // 2, (CANVAS - new_h) // 2))
    return final


def update_manifest(path: str, seed: int, qa_name: str, opaque: int, body: tuple[int, int]) -> str:
    full = os.path.join(ROOT, path)
    with open(full, "rb") as fh:
        sha = hashlib.sha256(fh.read()).hexdigest()
    with Image.open(full) as im:
        width, height = im.size
        mode = im.mode
    with open(MANIFEST_PATH, "r", encoding="utf-8") as fh:
        entries = json.load(fh)
    found = False
    for entry in entries:
        if entry.get("path") == path:
            entry["sha256"] = sha
            entry["width"] = width
            entry["height"] = height
            entry["qa"] = (
                f"INBOX group (4) slice 3: {width}x{height} {mode} transparent {qa_name}, "
                f"seed {seed}, body {body[0]}x{body[1]} centered with padding, "
                f"opaque={opaque}/{CANVAS * CANVAS}, corners transparent, no full bleed"
            )
            found = True
            break
    if not found:
        raise SystemExit(f"manifest missing {path} after pipeline")
    with open(MANIFEST_PATH, "w", encoding="utf-8") as fh:
        json.dump(entries, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    return sha


def body_size(img: Image.Image) -> tuple[int, int]:
    bbox = img.getbbox()
    if not bbox:
        return (0, 0)
    return (bbox[2] - bbox[0], bbox[3] - bbox[1])


def main() -> int:
    for spec in ICONS:
        generate(spec)
        full = os.path.join(ROOT, spec["path"])
        img = Image.open(full)
        processed = fit_canvas(flood_transparent(img), spec["path"])
        processed.save(full)
        opaque = sum(1 for p in processed.getdata() if p[3] > 0)
        body = body_size(processed)
        corners = [
            processed.getpixel((0, 0))[3],
            processed.getpixel((CANVAS - 1, 0))[3],
            processed.getpixel((0, CANVAS - 1))[3],
            processed.getpixel((CANVAS - 1, CANVAS - 1))[3],
        ]
        print(
            f"Saved {spec['path']} mode={processed.mode} opaque={opaque}/{CANVAS * CANVAS} "
            f"body={body} corner_alpha={corners}",
            flush=True,
        )
        if any(a != 0 for a in corners):
            raise SystemExit(f"{spec['path']} corners not transparent: {corners}")
        if opaque == 0 or opaque == CANVAS * CANVAS:
            raise SystemExit(f"{spec['path']} full-bleed or empty: opaque={opaque}")
        sha = update_manifest(spec["path"], spec["seed"], spec["qa_name"], opaque, body)
        print(f"manifest sha256={sha}", flush=True)
    print("downloaded_at", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
