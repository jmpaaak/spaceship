## Current Status

- R1 Lane C (partial): extracted the ascending-scene `nearbyPlanets` / `nearbyDebris` four-sector search-radius characterization block from `game/self_test.lua` into `game/tests/legacy_nearby_search_radius.lua`, preserving scene/ship setup, world-function restoration, and both exact radius assertions.
- Added `game/tests/self_test_nearby_search_radius_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of the setup/restoration/radius contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,658 to 1,629 `wc -l` lines including both new registrations.

## Next slice

- R1 Lane C: extract the adjacent Earth-proximity auto-settlement characterization block into one `game/tests/legacy_*.lua` suite, preserving launch via touch, away-from-Earth ascending state, return coordinates, and the exact `settlement` transition assertion.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
