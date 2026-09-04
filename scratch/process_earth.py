#!/usr/bin/env python3
"""ComfyUI generate + chroma-key post-process for earth_generic.png.

Generation is ComfyUI-only. Pillow is used only to knock out the black
backdrop, crop, and nearest-neighbor fit into a 64x64 RGBA canvas so the
runtime sprite has a transparent background as required by INBOX group (2).
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
ASSET_PATH = "assets/earth/earth_generic.png"
MANIFEST_PATH = os.path.join(ROOT, "docs", "assets", "MANIFEST.json")
SEED = 20260905101
PROMPT = (
    "pixel art, 16-bit, small round planet Earth sprite, tiny blue globe, "
    "green and brown continent silhouettes, white cloud swirls, circular sphere "
    "centered in frame with padding, isolated game sprite, black background, "
    "no text, no watermark, no rings, no stars, no frame"
)
TARGET = 38  # ~60% of 64x64, matching ship regen padding
DARK = 40


def generate() -> None:
    cmd = [
        sys.executable,
        "tools/comfyui_asset_pipeline.py",
        "--asset-path",
        ASSET_PATH,
        "--prompt",
        PROMPT,
        "--width",
        "512",
        "--height",
        "512",
        "--seed",
        str(SEED),
        "--qa",
        "INBOX group (2) earth regen: 64x64 transparent small blue Earth sphere",
    ]
    print("Generating", ASSET_PATH, "seed", SEED)
    res = subprocess.run(cmd, cwd=ROOT)
    if res.returncode != 0:
        raise SystemExit(res.returncode)


def flood_transparent(img: Image.Image) -> Image.Image:
    img = img.convert("RGBA")
    w, h = img.size
    px = img.load()
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
        if r >= DARK or g >= DARK or b >= DARK:
            continue
        px[x, y] = (0, 0, 0, 0)
        stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return img


def fit_64(img: Image.Image) -> Image.Image:
    bbox = img.getbbox()
    if not bbox:
        raise SystemExit("earth sprite became fully transparent")
    cropped = img.crop(bbox)
    w, h = cropped.size
    ratio = min(TARGET / w, TARGET / h)
    new_w = max(1, int(w * ratio))
    new_h = max(1, int(h * ratio))
    resized = cropped.resize((new_w, new_h), Image.Resampling.NEAREST)
    final = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    final.paste(resized, ((64 - new_w) // 2, (64 - new_h) // 2))
    return final


def update_manifest(path: str) -> str:
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
                f"INBOX group (2): {width}x{height} {mode} transparent Earth sphere, "
                f"seed {SEED}, body ~{TARGET}px with edge padding"
            )
            found = True
            break
    if not found:
        raise SystemExit("manifest missing earth_generic entry after pipeline")
    with open(MANIFEST_PATH, "w", encoding="utf-8") as fh:
        json.dump(entries, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    return sha


def main() -> int:
    generate()
    full = os.path.join(ROOT, ASSET_PATH)
    img = Image.open(full)
    processed = fit_64(flood_transparent(img))
    processed.save(full)
    opaque = sum(1 for p in processed.getdata() if p[3] > 0)
    print(f"Saved {ASSET_PATH} mode={processed.mode} opaque={opaque}/4096")
    sha = update_manifest(ASSET_PATH)
    print(f"manifest sha256={sha}")
    print("downloaded_at", time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
