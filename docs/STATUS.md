## Current Status

- R1 Lane C (partial): extracted the Item 15/11 dead settlement-slot-field characterization block from `game/self_test.lua` into `game/tests/legacy_dead_settlement_slot_fields.lua`.
  - Preserved the nil contracts for `lastSlotSpinsCount`, `lastSlotSettlement`, `lastLostSlotValue`, and `lastLostSlotSpinsCount` without changing production code.
  - Added `game/tests/self_test_dead_settlement_slot_fields_extraction.lua` to enforce delegation, body removal, and retention of all four contracts.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,933 to 1,903 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent Item 7(c) Earth-shop gear-offer keyboard characterization block into one `game/tests/legacy_*.lua` suite, preserving successful purchase, insufficient-money, full-slot, and relaunch-clear behavior.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
