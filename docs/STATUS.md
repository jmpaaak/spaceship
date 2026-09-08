## Current Status

- R1 Lane C (partial): extracted the Item 7(c) Earth-shop gear-offer keyboard characterization block from `game/self_test.lua` into `game/tests/legacy_earth_shop_gear_offer_keyboard.lua`.
  - Preserved successful purchase, insufficient-money, full-slot, non-settlement no-op, and relaunch-clear behavior through the existing `PlayScene:keypressed` boundary.
  - Added `game/tests/self_test_earth_shop_gear_offer_keyboard_extraction.lua` to enforce delegation, body removal, and retention of all five contracts.
  - Observed the expected missing-suite RED for both registrations, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,903 to 1,797 `wc -l` lines including both new registrations.

## Next slice

- R1 Lane C: extract the adjacent `drawHudSpriteOrPoly` nil-image fallback characterization block into one `game/tests/legacy_*.lua` suite, preserving the exported helper contract and no-throw fallback behavior.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
