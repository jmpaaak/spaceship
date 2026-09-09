from pathlib import Path
from PIL import Image

files = [
    "docs/assets/runs/sprite-gen/star-sun-sprite-sheet-alpha.png",
    "docs/assets/runs/sprite-gen/hub-neptune-sprite-sheet-alpha.png",
    "assets/star/star_sun_sheet.png",
    "assets/planet/hub_sheet.png",
    "docs/assets/masters/star/star_sun_sheet_pre_spritegen.png",
    "docs/assets/masters/planet/hub_neptune_nasa_pia00046_master.png",
    "docs/assets/sources/planet/hub_neptune_nasa_pia00046.jpg",
    "assets/star/star_sun.png",
    "assets/planet/planet_hub.png",
]
for f in files:
    p = Path(f)
    if not p.exists():
        print("MISSING", f)
        continue
    im = Image.open(p)
    print(f, im.size, im.mode, p.stat().st_size)
