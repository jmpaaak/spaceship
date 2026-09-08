## Current Status

- R1 Lane C (partial): extracted the collision feedback, destruction/meta-wipe, and non-damaging hub/shop collision characterization block from `game/self_test.lua` into `game/tests/legacy_collision_feedback.lua`.
  - The suite accepts the configured collision-risk scene and preserves the original assertion order, world stub restoration, damage text checks, full meta-wipe contract, and hub/shop collision exemptions.
  - `game/tests/self_test_collision_feedback_extraction.lua` enforces delegation and prevents the characterization body from returning to the runner.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 3,032 to 2,941 lines (including the new extraction-test registration).

## Next slice

- R1 Lane C: extract the adjacent basic expedition launch/settlement/best-altitude characterization block beginning at `basicSlotRolls` from `game/self_test.lua` into one `game/tests/legacy_*.lua` suite while preserving RNG consumption and assertion order.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
