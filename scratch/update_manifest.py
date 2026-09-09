import json

with open("docs/assets/MANIFEST.json", "r") as f:
    manifest = json.load(f)

manifest.append({
    "file": "assets/planet/studio/hub_neptune_sheet.png",
    "sha256": "f7eb512c6ce8b0ac5080001b945bb4b6a5da4a9f4260644b39be639e812d8d5d",
    "prompt": "Grok sprite-gen hub_neptune 8-frame rotate",
    "model": "grok",
    "style": "pixel-art",
    "settings": {},
    "downloaded_at": "2026-09-09T18:27:00Z",
    "width": 128,
    "height": 512,
    "qa": "Approved"
})

manifest.append({
    "file": "assets/star/studio/star_sun_sheet.png",
    "sha256": "7885cfe4e264caa8d7757770b9b2b00a6ad568e4768013b75bb0b636a016c60c",
    "prompt": "Grok sprite-gen star_sun 8-frame rotate",
    "model": "grok",
    "style": "pixel-art",
    "settings": {},
    "downloaded_at": "2026-09-09T18:27:00Z",
    "width": 128,
    "height": 512,
    "qa": "Approved"
})

with open("docs/assets/MANIFEST.json", "w") as f:
    json.dump(manifest, f, indent=2)
