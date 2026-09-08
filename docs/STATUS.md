## Current Status

- R1 Lane C (partial): extracted the INBOX 61(11) star-scan-range characterization block from `game/self_test.lua` into `game/tests/legacy_star_scan_range.lua`, preserving the positive `world.sectorSize` and minimum four-sector contracts.
- Added `game/tests/self_test_star_scan_range_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of both assertions.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,279 to 1,269 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent INBOX 61(13) debris-at-t=300 characterization block into one `game/tests/legacy_*.lua` suite, preserving non-empty nearby debris and minimum radius contracts.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
