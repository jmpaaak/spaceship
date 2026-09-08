## Current Status

- R1 Lane C (partial): extracted the adjacent INBOX 61(16) hub-restock characterization block from `game/self_test.lua` into `game/tests/legacy_hub_restock.lua`, preserving hub success/cost deduction, Earth rejection, insufficient-money rejection, and localized button-copy coverage.
- Added `game/tests/self_test_hub_restock_extraction.lua` to enforce delegation, removal of the legacy runner body, the extracted `run()` boundary, and retention of all four behavior contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,160 to 1,127 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent INBOX 61(17) destroyed-screen restart-text positioning characterization block into one `game/tests/legacy_*.lua` suite, preserving empty-choice panel centering, populated-choice bottom placement, and relative vertical-order coverage.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
