# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- Settlement-phase (EARTH SHOP return summary card) `peak_dist_line` and
  `newbest_label` were the last two bare `printf` calls in the settlement
  summary block after all other labels had received icons.
  - `game/self_test.lua`: added `testSettlementPeakDistIconSprite()` and
    `testSettlementNewBestIconSprite()` (file-existence + always-set-path +
    Lua fallback geometry assertions). Both called from `testCanvasLayoutScale`
    (RED 확인 후 GREEN).
  - `game/scenes/play.lua`: `M.settlementPeakDistIconPoints` (mountain-peak,
    4 verts, identical shape to `destroyedPeakDistIconPoints`),
    `M.settlementNewBestIconPoints` (8-point diamond star, 8 verts, identical
    to `destroyedNewBestIconPoints`), corresponding `IconSize = 24` /
    `IconGap = 8`; `self.settlementPeakDistIconImage(Path)` and
    `self.settlementNewBestIconImage(Path)` loaded in `new()` (reusing
    `assets/effects/destroyed_peak_dist.png` and `destroyed_new_best.png`
    sprites — identical visual intent, no new ComfyUI generation needed).
    Draw block replaces bare `printf` with centered icon+label pair matching
    the destroyed-phase pattern.
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`,
  `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:160`, `ASSET_MANIFEST_OK`).
- INBOX 처리 대기 항목 6은 gear, 7/8/11/15는 econ, 9/10/12/13/14는 gear.
  이번 사이클에서 다른 레인 항목은 건드리지 않음.

## Next Slice
- All settlement-phase and destroyed-phase summary printfs now have icons.
  No remaining bare printf surfaces in either block.
- 처리 대기 항목 모두 econ(7/8/11/15) 또는 gear(6/9/10/12/13/14) 레인 소유.
  main 레인이 단독 착수 가능한 표면은 소진됨 — 다음 사이클은 econ/gear 레인
  완료 후 연동 가능한 새 요청이 INBOX에 들어올 때까지 대기하거나, STATUS.md
  확인 후 새 요청을 처리한다.
