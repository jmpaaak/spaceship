## Current Status

- R1 Lane C (partial): extracted the adjacent settlement touch-row/layout characterization block from `game/self_test.lua` into `game/tests/legacy_settlement_touch_layout.lua`.
  - Preserved minimum row/column touch sizes, summary and shop-column spacing, panel containment, alternating row backgrounds, and row-center purchase/relaunch actions.
  - Added `game/tests/self_test_settlement_touch_layout_extraction.lua` to enforce delegation, body removal, and retained behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,419 to 2,326 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent destroyed/relaunch and launch full-canvas touch-area characterization block into one `game/tests/legacy_*.lua` suite, preserving 44pt sizing plus corner/center tap restart and launch actions.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
