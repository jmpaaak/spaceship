## Current Status

- R1 Lane C (partial): extracted the adjacent durability and sample-yield upgrade characterization block from `game/self_test.lua` into `game/tests/legacy_expedition_upgrades.lua`.
  - The suite preserves the original launch gating, purchase, collection, upgraded award, destruction, and reset assertion order.
  - `game/tests/self_test_upgrade_extraction.lua` enforces delegation and prevents the characterization body from returning to the runner.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,906 to 2,876 lines (including the new extraction-test registration).

## Next slice

- R1 Lane C: extract the adjacent same-hue sample streak characterization block beginning at `streakRun` from `game/self_test.lua` into one `game/tests/legacy_*.lua` suite while preserving multiplier, family reset, destruction reset, and relaunch assertion order.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
