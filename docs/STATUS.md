## Current Status

- R1 Lane C (partial): extracted the adjacent same-hue sample-streak characterization block from `game/self_test.lua` into `game/tests/legacy_sample_streak.lua`.
  - Preserved the x1.0/x1.2/x1.4 multiplier order, hue-family switch reset, pending-value/sample-count assertions, destruction reset, and relaunch reset.
  - Added `game/tests/self_test_sample_streak_extraction.lua` to enforce delegation, body removal, and retained behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,876 to 2,846 lines (including the new extraction-test registration).

## Next slice

- R1 Lane C: extract the adjacent steering-upgrade characterization block from `steeringRun` through `steeringShopScene` into one `game/tests/legacy_*.lua` suite while preserving purchase gating, relaunch/destruction behavior, effective movement speed, and settlement keyboard-purchase assertion order.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
