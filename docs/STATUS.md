## Current Status

- R1 Lane C (partial): extracted the adjacent ship purchase/selection lifecycle block from `game/self_test.lua` into `game/tests/legacy_ship_shop.lua`.
  - Preserved settlement phase gating, purchase funds and duplicate-purchase checks, selection stats, launch durability, and destruction full-wipe assertions in their original order.
  - Added `game/tests/self_test_ship_shop_extraction.lua` to enforce delegation, body removal, and retained behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,795 to 2,775 lines (including the new extraction-test registration).

## Next slice

- R1 Lane C: extract the adjacent settlement shop input/empty-banner block from `shopScene` through `shortfallScene` into one `game/tests/legacy_*.lua` suite, preserving keyboard/touch purchases, scout hull stats, repeated-upgrade pricing, insufficient-funds gating, and empty-message behavior.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
