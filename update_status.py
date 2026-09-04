import re

with open('docs/STATUS.md', 'r') as f:
    content = f.read()

# Replace the Next Slice section entirely.
new_entry = """2026-09-05 — ComfyUI asset generation: UI panels (group 5 of INBOX asset generation item).

- Generated 64x64 corner tile transparent PNGs for `shop_panel.png`, `loadout_panel.png`, and `destroyed_panel.png` via ComfyUI.
- Logged new assets to `docs/GENERATED_ASSET_LOG.md` and updated `MANIFEST.json`.
- Moved "모든 시각 에셋 ComfyUI 전면 재생성" to `## 처리 완료` as all sub-items (0-5) are now fully completed.
- `make verify` GREEN.

## Next Slice

- INBOX `## 처리 대기` is now empty. Waiting for new user feedback or design items.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다."""

content = re.sub(r'## Next Slice.*', new_entry, content, flags=re.DOTALL)

with open('docs/STATUS.md', 'w') as f:
    f.write(content)
