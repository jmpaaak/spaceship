# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- LAUNCH LOADOUT `loadout.stats` (`stats_line`, "HULL n") was still a bare centered printf after EARTH SHOP `nextLaunch.stats` already had the ComfyUI hull-plate icon.
  - `game/self_test.lua` `testStatsIconSprite()`: `PlayScene.drawLoadoutStatsIcon == true` + shared `statsIconLabelLayout` centering (iconSpan/labelX/iconCenterX, box-centered startX). Existing file-existence + path wiring + hull-plate hexagon geometry kept. Invoked from `testCanvasLayoutScale` (RED 확인 후 GREEN).
  - `game/scenes/play.lua`: `M.drawLoadoutStatsIcon`, `M.statsIconLabelLayout`, `M:drawStatsIconLabel`. Launch loadout uses the helper (cyan 0.4/0.85/1); EARTH SHOP `nextLaunch.stats` now shares the same drawer. Reuses `assets/effects/shop_stats.png` (no new ComfyUI generation).
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:142`, `ASSET_MANIFEST_OK`).
- INBOX 처리 대기 항목 6은 gear, 7/8/11/15는 econ, 9/10/12/13/14는 gear. 이번 사이클에서 다른 레인 항목은 건드리지 않음.

## Next Slice
- Remaining always-drawn shop labels are numeric status/preview plus `nextLaunch.ship` (`hullStatus`/`steeringStatus`/`yieldStatus`/`shipStatus`, `*PreviewCompact`, `nextLaunch.ship`). Compact action rows, `nextLaunch.stats`, and launch `loadout.stats` now have the hull-plate icon. `drawShopIcon` is now unused from `:draw()`.
- 항목 6은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
