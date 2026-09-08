## Current Status

- R1 Lane C (partial): extracted the deterministic per-planet rotation/scale characterization block from `game/self_test.lua` into `game/tests/legacy_planet_variation.lua`, preserving nil/missing-ID identity defaults, same-ID determinism, different-ID divergence, rotation/scale ranges, and hub-ID coverage.
- Added `game/tests/self_test_planet_variation_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of those behavior contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,383 to 1,347 `wc -l` lines including both new registrations.

## Next slice

- R1 Lane C: extract the adjacent `solarSystem` max-durability settlement characterization block into one `game/tests/legacy_*.lua` suite, preserving localized description, max-durability increment, full-repair, and clamping contracts.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
