## Current Status

- R1 Lane C (partial): extracted the adjacent INBOX 61(13) debris-at-t=300 characterization block from `game/self_test.lua` into `game/tests/legacy_debris_t300.lua`, preserving the non-empty nearby debris and minimum radius (`>= 3`) contracts.
- Added `game/tests/self_test_debris_t300_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of both assertions.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,269 to 1,261 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent INBOX 61(12) keep-one confirmation-popup characterization block into one `game/tests/legacy_*.lua` suite, preserving 44px touch targets, 720×1280 bounds, in-popup button placement, and `keepConfirmBtnH` contracts.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
