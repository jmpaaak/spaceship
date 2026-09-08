## Current Status

- R1 Lane C (partial): extracted the adjacent INBOX 61(12) keep-one confirmation-popup characterization block from `game/self_test.lua` into `game/tests/legacy_keep_one_confirm.lua`, preserving 44px touch targets, 720×1280 bounds, in-popup button placement, and `keepConfirmBtnH` contracts.
- Added `game/tests/self_test_keep_one_confirm_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of those assertions.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,261 to 1,234 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent INBOX 61(14) planet-sheet characterization block into one `game/tests/legacy_*.lua` suite, preserving RGBA/runtime-gate checks for all six planet sheets and the hub sheet plus mobile-failure sprite-load fallback coverage.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
