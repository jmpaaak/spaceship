import json

with open("docs/assets/MANIFEST.json", "r") as f:
    manifest = json.load(f)

for entry in manifest:
    if "hub_neptune_sheet.png" in entry.get("path", ""):
        entry["settings"] = {"seed": 0}
    elif "star_sun_sheet.png" in entry.get("path", ""):
        entry["settings"] = {"seed": 0}

with open("docs/assets/MANIFEST.json", "w") as f:
    json.dump(manifest, f, indent=2)
