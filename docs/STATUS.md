## Current Status

- R1 Lane C (partial): extracted the Item 15(c) Earth-slot reward-profile/removed-ODDS-label characterization block from `game/self_test.lua` into `game/tests/legacy_earth_slot_reward_profile.lua`.
  - Preserved helper availability, nil label behavior for `"solar"`/`nil`/empty profiles, settlement result storage, and the string `rewardProfile` contract without changing production code.
  - Added `game/tests/self_test_earth_slot_reward_profile_extraction.lua` to enforce delegation, body removal, and retention of those contracts.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,977 to 1,933 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent Item 15/11 dead settlement-slot-field characterization block into one `game/tests/legacy_*.lua` suite, preserving the nil contracts for `lastSlotSpinsCount`, `lastSlotSettlement`, `lastLostSlotValue`, and `lastLostSlotSpinsCount`.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
