## Current Status

- R1 Lane C (partial): extracted the adjacent `shopLoadoutLines()` settlement-shop characterization block from `game/self_test.lua` into `game/tests/legacy_shop_loadout_lines.lua`.
  - Preserved starter prices and affordability, compact labels, purchased hull/harvest/scout previews, and active-scout keyboard/touch hiding assertions in their original order.
  - Added `game/tests/self_test_shop_loadout_lines_extraction.lua` to enforce delegation, body removal, and retained starter/upgraded/scout behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,645 to 2,554 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent `destroyedRun` destruction/meta-wipe and `testSave` best-altitude persistence characterization block into one `game/tests/legacy_*.lua` suite, preserving staged hull damage, lost-run telemetry reset, relaunch state, and all-time-best file round trip.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
