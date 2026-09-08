## Current Status

- R1 Lane C (partial): extracted the adjacent INBOX 61(19) slot-speed reward separation characterization block from `game/self_test.lua` into `game/tests/legacy_slot_speed_reward_separation.lua`, preserving independent shop-upgrade level/cost, effective-speed inclusion, and destruction-reset coverage.
- Added `game/tests/self_test_slot_speed_reward_separation_extraction.lua` to enforce delegation, removal of the legacy runner body, the extracted `run()` boundary, and retention of all three behavior contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,092 to 1,060 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent INBOX 61(20) Earth gear-offer keyboard-prefix/i18n characterization block into one `game/tests/legacy_*.lua` suite, preserving EN/KO prefix removal, localized label, and locale restoration coverage.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
