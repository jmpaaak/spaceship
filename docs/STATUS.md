## Current Status

- R1 Lane C (partial): extracted the Item 7(a) shop-planet modal keyboard characterization block from `game/self_test.lua` into `game/tests/legacy_shop_planet_modal_keyboard.lua`.
  - Preserved modal skip, successful purchase (money/equipment feedback), insufficient-funds refusal, and settlement `sampleYield` shortcut-consumption behavior without changing production code.
  - Added `game/tests/self_test_shop_planet_modal_keyboard_extraction.lua` to enforce delegation, body removal, and retention of all four contracts.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,142 to 2,055 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent Item 15(b) Earth-shop slot-machine keyboard characterization block into one `game/tests/legacy_*.lua` suite, preserving result assignment, money/reward message, outside-settlement no-op, and `{ reels = {...} }` argument-shape behavior.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
