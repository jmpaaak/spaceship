import json
import hashlib
import sys

with open("docs/assets/MANIFEST.json", "r") as f:
    manifest = json.load(f)

paths = ["assets/effects/hud_coin.png", "assets/effects/hud_shield.png", "assets/effects/hud_speed.png"]
for entry in manifest:
    if entry["path"] in paths:
        with open(entry["path"], "rb") as f:
            entry["sha256"] = hashlib.sha256(f.read()).hexdigest()

with open("docs/assets/MANIFEST.json", "w") as f:
    json.dump(manifest, f, indent=2, ensure_ascii=False)
    f.write("\n")
