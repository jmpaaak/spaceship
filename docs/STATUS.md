## Current Status

- R1 Lane C (partial): extracted the adjacent steering-upgrade characterization block from `game/self_test.lua` into `game/tests/legacy_steering_upgrade.lua`.
  - Preserved purchase phase/funds gating, effective-speed calculation, relaunch persistence, destruction reset, ascending movement, and settlement `g` keyboard-purchase assertion order.
  - Added `game/tests/self_test_steering_upgrade_extraction.lua` to enforce delegation, body removal, and retained behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,846 to 2,795 lines (including the new extraction-test registration).

## Next slice

- R1 Lane C: extract the adjacent ship purchase/selection lifecycle block from `shipShopRun` through its destruction-reset assertions into one `game/tests/legacy_*.lua` suite, preserving phase/funds/duplicate-purchase gating, selection stats, launch durability, and full-wipe behavior.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
