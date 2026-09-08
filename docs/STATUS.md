## Current Status

- R1 Lane C (partial): extracted the adjacent starter, purchased scout/upgrades, and destruction-reset `loadoutLines()` characterization block from `game/self_test.lua` into `game/tests/legacy_loadout_lines.lua`.
  - Preserved hidden starter ship-name, hull/upgrade/steering text, purchased scout selection, and full meta-wipe reset assertions in their original order.
  - Added `game/tests/self_test_loadout_lines_extraction.lua` to enforce delegation, body removal, and retained starter/upgraded/reset behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,682 to 2,645 `wc -l` lines including both new test registrations.

## Next slice

- R1 Lane C: extract the adjacent `nextLaunchScene:shopLoadoutLines()` settlement-shop characterization block into one `game/tests/legacy_*.lua` suite, preserving starter prices/affordability, compact labels, purchased upgrade/scout previews, and active-ship hiding assertions.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
