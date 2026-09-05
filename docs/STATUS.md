## Current Status

- INBOX (15)(c) complete: `feat(tools): slot-editor web UI`. Created `tools/slot-editor/index.html`, `editor.css`, `editor.js` replicating the gear-editor pattern. Added `game/data/slot_config.json` with base values (10 spin cost, 0 miss payout). Exposed `expedition.loadSlotConfig` and wired dynamic probabilities and payouts for Earth shop slots based on profile (solar, fringe, void).

## Next Slice

- INBOX (16): HUD 가로 검정띠 제거 (사용자 확정, 2026-09-05). `M:draw` 가 `drawPanelSprite` 로 화면 가로 전체를 덮는 동작 수정.
