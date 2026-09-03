# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- EARTH SHOP `nextLaunch.stats` (`stats_line`, "HULL n") was still a bare centered printf while compact action rows already had ComfyUI icons.
  - `game/self_test.lua` `testStatsIconSprite()`: file exists + `PlayScene.statsIconImagePath` wiring + `statsIconPoints` geometry (even-length hull-plate hexagon, spans cy, horizontally symmetric). Invoked from `testCanvasLayoutScale` so `M.run()` stays under Lua's 60-upvalue cap (RED 확인 후 GREEN).
  - `assets/effects/shop_stats.png` via remote ComfyUI (`http://222.238.86.132:8188`, workflow `7a3eb820-f17d-47ce-a337-da2358c2a0d5`, seed `20260904160`). Pipeline PNG signature/decode gate only; no vision QA.
  - `game/scenes/play.lua`: always-set path + graphics-gated image; settlement `:draw()` draws the hull-plate left of `nextLaunch.stats`; Lua `statsIconPoints` fallback when the sprite fails to load.
  - `docs/assets/MANIFEST.json` provenance + `docs/GENERATED_ASSET_LOG.md` one append-only line.
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:142`, `ASSET_MANIFEST_OK`).
- INBOX 처리 대기 항목 6은 gear, 7/8/11/15는 econ, 9/10/12/13/14는 gear. 이번 사이클에서 다른 레인 항목은 건드리지 않음.

## Next Slice
- Remaining always-drawn shop labels are numeric status/preview plus `nextLaunch.ship` (`hullStatus`/`steeringStatus`/`yieldStatus`/`shipStatus`, `*PreviewCompact`, `nextLaunch.ship`). Compact action rows and `nextLaunch.stats` now have ComfyUI icons. `drawShopIcon` is now unused from `:draw()`. Launch loadout `loadout.stats` is still bare text.
- 항목 6은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
