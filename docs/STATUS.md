## Current Status

- R1 Lane C (partial): extracted the central-star gravity-well characterization block from `game/self_test.lua` into `game/tests/legacy_central_star_gravity_well.lua`, preserving world-function stubs/restoration plus outside-well safety, 0.5-second damage ticks, continuous-survival sampling, leave/re-entry timer reset, and once-per-galaxy reward contracts.
- Added `game/tests/self_test_central_star_gravity_well_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of those behavior contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,610 to 1,473 `wc -l` lines including both new registrations.

## Next slice

- R1 Lane C: extract the adjacent PixelPlanets planet-sprite characterization block into one `game/tests/legacy_*.lua` suite, preserving RGBA PNG validation, galaxy `starType` coverage, planet mapping, and image-path contracts.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
