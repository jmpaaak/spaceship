## Current Status

- R1 Lane C (partial): extracted the adjacent basic expedition launch, sample settlement, relaunch reset, and best-altitude preservation characterization block from `game/self_test.lua` into `game/tests/legacy_basic_expedition.lua`.
  - The suite preserves the original setup and assertion order, including settlement idempotence, last-run fields, new-best reporting, and the lower-run all-time-best invariant.
  - `game/tests/self_test_basic_expedition_extraction.lua` enforces delegation and prevents the characterization body from returning to the runner.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,941 to 2,906 lines (including the new extraction-test registration).

## Next slice

- R1 Lane C: extract the adjacent durability and sample-yield upgrade characterization block beginning at `hullShopRun` from `game/self_test.lua` into one `game/tests/legacy_*.lua` suite while preserving launch, purchase, collection, and destruction assertion order.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
