## Current Status

- R1 Lane C (partial): extracted the HUD characterization block from `game/self_test.lua` into `game/tests/legacy_hud.lua`.
  - The suite preserves the configured collision-risk scene handoff and the original assertion order for HUD labels, dimensions, durability blocks, and Earth-distance display.
  - `game/tests/self_test_hud_extraction.lua` enforces delegation and prevents the test body from returning to the runner.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 3,140 to 3,032 lines.

## Next slice

- R1 Lane C: extract the adjacent collision feedback and destruction/meta-wipe characterization block from `game/self_test.lua` into one `game/tests/legacy_*.lua` suite while preserving the configured scene handoff and assertion order.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
