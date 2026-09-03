# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- EARTH SHOP `nextLaunch.steeringStatus` (`SHORT $n` / `LEFT $n`) was still a bare centered printf after compact action rows, `nextLaunch.stats`, launch `loadout.stats`, and `hullStatus` already had ComfyUI icons.
  - `game/self_test.lua` `testSteeringStatusIconSprite()`: file-existence + always-set-path (`assets/effects/shop_steering_status.png` → `self.steeringStatusIconImagePath`) + Lua gyro-coin octagon fallback geometry (even-length, spans cy, horizontally symmetric). Invoked from `testCanvasLayoutScale` (RED 확인 후 GREEN).
  - `game/scenes/play.lua`: `M.steeringStatusIconPoints`, `M.steeringStatusIconSize`/`Gap` (24/8), `self.steeringStatusIconImage(Path)`. Settlement draw pairs the icon with `steeringStatus` (affordability colors kept on the label).
  - ComfyUI seed 20260904162, 64x64. Manifest + `docs/GENERATED_ASSET_LOG.md` line appended. No vision QA (policy).
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:144`, `ASSET_MANIFEST_OK`).
- INBOX 처리 대기 항목 6은 gear, 7/8/11/15는 econ, 9/10/12/13/14는 gear. 이번 사이클에서 다른 레인 항목은 건드리지 않음.

## Next Slice
- Remaining always-drawn shop labels: `yieldStatus`/`shipStatus`, `*PreviewCompact`, `nextLaunch.ship`. Compact action rows, `nextLaunch.stats`, launch `loadout.stats`, `hullStatus`, and `steeringStatus` now have icons. `drawShopIcon` is now unused from `:draw()`.
- 항목 6은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
