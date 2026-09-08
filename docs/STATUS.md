## Current Status

- R1 Lane C (partial): extracted the ascending-scene Earth-proximity auto-settlement characterization block from `game/self_test.lua` into `game/tests/legacy_earth_proximity_auto_settlement.lua`, preserving touch launch, the away-from-Earth ascending state, exact return coordinates, and the `settlement` transition assertion.
- Added `game/tests/self_test_earth_proximity_auto_settlement_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of those behavior contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,629 to 1,610 `wc -l` lines including both new registrations.

## Next slice

- R1 Lane C: extract the adjacent central-star gravity-well characterization block into one `game/tests/legacy_*.lua` suite, preserving world-function stubs/restoration and the outside-well, inner-well, and lethal-damage contracts.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
