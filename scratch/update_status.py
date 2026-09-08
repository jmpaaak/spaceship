import re
with open('docs/STATUS.md', 'r') as f:
    text = f.read()

text = re.sub(r'## Next slice.*', '', text, flags=re.DOTALL)

new_content = """
- R1-A1 (Lane A): Extracted `game/scenes/play_input.lua` and its comprehensive test `game/tests/play_input.lua`.
  - Enforced rigorous input consumption contract (popup -> overlay -> phase UI -> joystick).
  - Fixed the shop relaunch button bug where touches were bleeding into world coordinates.

- R1 (Lane B, partial): Extracted slot machine logic to `game/expedition_slot.lua`.
  - Moved `loadSlotConfig`, `earthSlotSpin`, `slotTier`, `slotReward` etc., from `game/expedition.lua`.
  - Reduced `game/expedition.lua` by ~250 lines.
  - Retained `M.*` API wrappers in `game/expedition.lua` ensuring all tests and caller modules work transparently.

## Next slice

- R1 (Lane C): Extract `game/self_test.lua` (currently ~10k lines) legacy tests into `game/tests/legacy_*.lua`.
- R1 (Lane B): Extract remaining `game/expedition.lua` logic (e.g. `expedition_shop.lua`, `expedition_upgrades.lua`).

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
"""

with open('docs/STATUS.md', 'w') as f:
    f.write(text.rstrip() + '\n\n' + new_content.strip() + '\n')
