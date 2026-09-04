import sys

with open("docs/STATUS.md", "r") as f:
    content = f.read()

header = "## Current Status\n"
new_status = """
2026-09-05 — ComfyUI HUD icon regen (group 4 of INBOX regen item).
- Regenerated 32x32 `hud_coin.png`, `hud_shield.png`, `hud_speed.png` via ComfyUI SDXL pipeline (monochrome white).
- Applied circle-mask alpha channel modification to ensure strict transparent corners for UI overlay compatibility.
- Updated `docs/assets/MANIFEST.json` with new SHA-256 hashes and appended to `docs/GENERATED_ASSET_LOG.md`.
- `make verify` GREEN (passed all `self_test.lua` transparency assertions).
"""

if header in content:
    content = content.replace(header, header + new_status)
else:
    content = header + new_status + "\n" + content

with open("docs/STATUS.md", "w") as f:
    f.write(content)
