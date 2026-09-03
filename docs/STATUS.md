# STATUS

preflight PASS 진입 및 이번 사이클 작업 완료.

- Destroyed-phase `peak_dist_line` / conditional `newbest_label` / `meta_reset_line` were the last bare `printf` calls in the destroyed summary block after all other labels had received icons.
  - `game/self_test.lua`: added `testDestroyedPeakDistIconSprite()`, `testDestroyedNewBestIconSprite()`, `testDestroyedMetaResetIconSprite()` (file-existence + always-set-path + Lua fallback geometry assertions). All invoked from `testCanvasLayoutScale` (RED 확인 후 GREEN).
  - `game/scenes/play.lua`: `M.destroyedPeakDistIconPoints` (mountain-peak triangle, 4 verts), `M.destroyedNewBestIconPoints` (8-point diamond star, 8 verts), `M.destroyedMetaResetIconPoints` (chevron-ring hexagon, 6 verts) pure functions; corresponding `IconSize`/`Gap` (24/8); `self.destroyedPeakDistIconImage(Path)`, `self.destroyedNewBestIconImage(Path)`, `self.destroyedMetaResetIconImage(Path)` loaded in `new()`. Draw block replaces bare `printf` with centered icon+label pairs matching the pattern of all prior destroyed-phase icons.
  - ComfyUI assets: seed 20260904301 (`destroyed_peak_dist.png`), 20260904302 (`destroyed_new_best.png`), 20260904303 (`destroyed_meta_reset.png`). All 64×64. Manifest + `docs/GENERATED_ASSET_LOG.md` 3 lines appended. No vision QA (policy).
- `GAME_HEADLESS=1 GAME_UNIT=1 love .` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK`).
- `make verify LOVE=/Users/jm/.local/bin/love` GREEN (`SPACESHIP_UNIT_OK`, `SPACESHIP_SMOKE_OK` x3, `LOVE_BUNDLE_OK:build/game.love:160`, `ASSET_MANIFEST_OK`).
- INBOX 처리 대기 항목 6은 gear, 7/8/11/15는 econ, 9/10/12/13/14는 gear. 이번 사이클에서 다른 레인 항목은 건드리지 않음.

## Next Slice
- All destroyed-phase summary printfs now have icons. The settlement-phase `peak_dist_line` at line ~5139 (in the EARTH SHOP return summary card, not the destroyed block) is still a bare `printf` — that surface could receive the same `destroyedPeakDistIcon` reuse. Alternatively pick next pending INBOX item (항목 7/8/11/15 econ, 9/10/12/13/14 gear — none owned by main lane).
- 항목 6은 gear 레인. 항목 7/8/11/15는 econ, 9/10/12/13/14는 gear.
