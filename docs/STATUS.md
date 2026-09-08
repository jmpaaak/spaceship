## Current Status

- R1 Lane C (partial): extracted the `solarSystem` settlement characterization block from `game/self_test.lua` into `game/tests/legacy_solar_system_settlement.lua`, preserving EN/KO max-durability copy, the +1 maximum durability settlement effect, and full repair to the new clamped maximum on launch.
- Added `game/tests/self_test_solar_system_settlement_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of those behavior contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,347 to 1,310 `wc -l` lines including both new registrations.

## Next slice

- R1 Lane C: extract the adjacent `gearPopupChipVertical` characterization block into one `game/tests/legacy_*.lua` suite, preserving the vertical chip-stack contract.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
