## Current Status

- R1 Lane C (partial): extracted the PixelPlanets planet-sprite characterization block from `game/self_test.lua` into `game/tests/legacy_pixelplanets_planet_sprite.lua`, preserving six RGBA PNG checks, generated galaxy `starType` coverage, hub/shop/regular-planet parent-type propagation, and regular/hub/shop/fallback image-path contracts.
- Added `game/tests/self_test_pixelplanets_planet_sprite_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of those behavior contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,473 to 1,383 `wc -l` lines including both new registrations.

## Next slice

- R1 Lane C: extract the adjacent deterministic per-planet rotation/scale variation characterization block into one `game/tests/legacy_*.lua` suite, preserving identity defaults, ID determinism/divergence, and rotation/scale range contracts.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
