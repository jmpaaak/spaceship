## Current Status

- R1 Lane C (partial): extracted the adjacent INBOX 61(17) destroyed-screen restart-text positioning characterization block from `game/self_test.lua` into `game/tests/legacy_destroyed_restart_text.lua`, preserving empty-choice panel centering, populated-choice bottom placement, and relative vertical-order coverage.
- Added `game/tests/self_test_destroyed_restart_text_extraction.lua` to enforce delegation, removal of the legacy runner body, the extracted `run()` boundary, and retention of all three positioning contracts.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,127 to 1,109 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent INBOX 61(18) hub-shop row-3 gap characterization block into one `game/tests/legacy_*.lua` suite, preserving the sub-100px gear-row height, contiguous-row, and panel-bounds coverage.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
