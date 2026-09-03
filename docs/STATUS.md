# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- LAUNCH LOADOUT `loadout.ship` (selected hull name, shown once SCOUT is owned) was still a bare centered printf after shop `nextLaunch.ship` already had a hangar-roof icon.
  - `game/self_test.lua` `testLoadoutShipIconSprite()`: file-existence + always-set-path (`assets/effects/loadout_ship.png` → `self.loadoutShipIconImagePath`) + Lua hexagonal nameplate fallback geometry (even-length, spans cy, horizontally symmetric). Invoked from `testCanvasLayoutScale` (RED 확인 후 GREEN).
  - `game/scenes/play.lua`: `M.loadoutShipIconPoints`, `M.loadoutShipIconSize`/`Gap` (24/8), `self.loadoutShipIconImage(Path)`. Launch draw pairs the icon with `loadout.ship`.
  - ComfyUI seed 20260904170, 64x64. Manifest + `docs/GENERATED_ASSET_LOG.md` line appended. No vision QA (policy).
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:152`, `ASSET_MANIFEST_OK`).
- INBOX 처리 대기 항목 6은 gear, 7/8/11/15는 econ, 9/10/12/13/14는 gear. 이번 사이클에서 다른 레인 항목은 건드리지 않음.

## Next Slice
- Remaining always-drawn labels after launch `loadout.ship`: destroyed `next_ship_line` / `tap_start_over`. Shop compact action rows, status/preview rows, `nextLaunch.stats`, `nextLaunch.ship`, and launch `loadout.ship` now have icons.
- 항목 6은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
