# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- Destroyed-phase `next_ship_line` (NEXT STARTER after meta wipe) was still a bare centered printf after launch `loadout.ship` already had a hexagonal nameplate icon.
  - `game/self_test.lua` `testDestroyedNextShipIconSprite()`: file-existence + always-set-path (`assets/effects/destroyed_next_ship.png` → `self.destroyedNextShipIconImagePath`) + Lua restart-hull dart fallback geometry (even-length, spans cy, horizontally symmetric). Invoked from `testCanvasLayoutScale` (RED 확인 후 GREEN).
  - `game/scenes/play.lua`: `M.destroyedNextShipIconPoints`, `M.destroyedNextShipIconSize`/`Gap` (24/8), `self.destroyedNextShipIconImage(Path)`. Destroyed draw pairs the icon with `next_ship_line`.
  - ComfyUI seed 20260904171, 64x64. Manifest + `docs/GENERATED_ASSET_LOG.md` line appended. No vision QA (policy).
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:153`, `ASSET_MANIFEST_OK`).
- INBOX 처리 대기 항목 6은 gear, 7/8/11/15는 econ, 9/10/12/13/14는 gear. 이번 사이클에서 다른 레인 항목은 건드리지 않음.

## Next Slice
- Remaining always-drawn labels after destroyed `next_ship_line`: destroyed `tap_start_over`. Shop compact action rows, status/preview rows, `nextLaunch.stats`, `nextLaunch.ship`, launch `loadout.ship`, and destroyed `next_ship_line` now have icons.
- 항목 6은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
