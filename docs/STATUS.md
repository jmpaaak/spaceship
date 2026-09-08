## Current Status

- R1 Lane C (partial): extracted the `drawPixelStar` nil-image behavior and `pixelStarsImage` / `pixelStarsSpecialImage` image-slot characterization block from `game/self_test.lua` into `game/tests/legacy_pixel_star_sprite.lua`.
- Added `game/tests/self_test_pixel_star_sprite_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of the false return plus both scene image-slot contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,672 to 1,658 `wc -l` lines including both new registrations.

## Next slice

- R1 Lane C: extract the adjacent `nearbyPlanets` / `nearbyDebris` four-sector search-radius characterization block into one `game/tests/legacy_*.lua` suite, preserving the ascending scene setup, world-function restoration, and exact radius assertions.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
