## Current Status

- R1 Lane C (partial): extracted the adjacent INBOX 61(14) planet-sheet characterization block from `game/self_test.lua` into `game/tests/legacy_planet_sheet_sprites.lua`, preserving RGBA/runtime-gate checks for all six planet sheets and the hub sheet plus mobile-failure sheet/static sprite-load fallback coverage.
- Added `game/tests/self_test_planet_sheet_sprites_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of those contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,234 to 1,160 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent INBOX 61(16) hub-restock characterization block into one `game/tests/legacy_*.lua` suite, preserving hub success/cost deduction, Earth rejection, insufficient-money rejection, and localized button-copy coverage.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
