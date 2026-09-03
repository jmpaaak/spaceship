# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- EARTH SHOP `nextLaunch.ship` (`NEXT STARTER` / `NEXT SCOUT`) was still a bare centered printf after compact action rows, `nextLaunch.stats`, launch `loadout.stats`, status rows, `hullPreviewCompact`, `steeringPreviewCompact`, `yieldPreview`, and `shipPreviewCompact` already had ComfyUI icons.
  - `game/self_test.lua` `testNextShipIconSprite()`: file-existence + always-set-path (`assets/effects/shop_next_ship.png` → `self.nextShipIconImagePath`) + Lua hangar-roof pentagon fallback geometry (even-length, spans cy, horizontally symmetric). Invoked from `testCanvasLayoutScale` (RED 확인 후 GREEN).
  - `game/scenes/play.lua`: `M.nextShipIconPoints`, `M.nextShipIconSize`/`Gap` (24/8), `self.nextShipIconImage(Path)`. Settlement draw pairs the icon with `nextLaunch.ship`.
  - ComfyUI seed 20260904169, 64x64. Manifest + `docs/GENERATED_ASSET_LOG.md` line appended. No vision QA (policy).
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:151`, `ASSET_MANIFEST_OK`).
- INBOX 처리 대기 항목 6은 gear, 7/8/11/15는 econ, 9/10/12/13/14는 gear. 이번 사이클에서 다른 레인 항목은 건드리지 않음.

## Next Slice
- Remaining always-drawn labels after shop `nextLaunch.ship`: launch `loadout.ship` and destroyed `next_ship_line` / `tap_start_over`. Shop compact action rows, status/preview rows, `nextLaunch.stats`, and `nextLaunch.ship` now have icons. `drawShopIcon` is now unused from `:draw()`.
- 항목 6은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
