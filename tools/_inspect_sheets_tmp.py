#!/usr/bin/env python3
"""Inspect PNG dimensions/mode without importing from scratch/."""
from pathlib import Path
from PIL import Image

files = [
    "docs/assets/runs/sprite-gen/star-sun-sprite-sheet-alpha.png",
    "docs/assets/runs/sprite-gen/hub-neptune-sprite-sheet-alpha.png",
    "assets/star/star_sun_sheet.png",
    "assets/planet/hub_sheet.png",
    "assets/star/studio/star_sun.png",
    "assets/planet/studio/hub_neptune.png",
    "docs/assets/masters/star/star_sun_nasa_gsfc_20171208_archive_e002035_master.png",
    "docs/assets/masters/planet/hub_neptune_nasa_pia00046_master.png",
    "assets/star/star_sun.png",
]
for f in files:
    p = Path(f)
    if not p.exists():
        print("MISSING", f)
        continue
    im = Image.open(p)
    print(f"{f}: {im.size} {im.mode} bytes={p.stat().st_size}")
