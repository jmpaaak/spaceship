## Current Status

- R1 Lane C (partial): extracted the adjacent settlement shop input and empty-banner characterization block from `game/self_test.lua` into `game/tests/legacy_settlement_shop_input.lua`.
  - Preserved keyboard hull/yield purchases, touch scout purchase/selection, scout hull stats, repeated-upgrade pricing, insufficient-funds gating, and empty-message assertions in their original order.
  - Added `game/tests/self_test_settlement_shop_input_extraction.lua` to enforce delegation, body removal, and retained behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,775 to 2,714 lines (including the new extraction-test registration).

## Next slice

- R1 Lane C: extract the adjacent `touchScene` launch/held-steering/release and settlement touch purchase/relaunch block into one `game/tests/legacy_*.lua` suite, preserving touch state, movement direction, purchase selection, and relaunch behavior.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
