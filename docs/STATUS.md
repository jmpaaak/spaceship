## Current Status

- R1 Lane C (partial): extracted the ascending full-canvas touch-steering characterization block from `game/self_test.lua` into `game/tests/legacy_ascending_touch_steering.lua`.
  - Preserved left-half activation at the control area's top edge, right-half activation at its bottom edge, and both touch-release calls.
  - Added `game/tests/self_test_ascending_touch_steering_extraction.lua` to enforce delegation, body removal, and retained behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,217 to 2,202 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent dead in-flight slot i18n-key removal characterization block into one `game/tests/legacy_*.lua` suite, preserving missing-key checks and the slot-free returning-message contract.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
