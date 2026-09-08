## Current Status

- R1 Lane C (partial): extracted the `rimMarker1Color`/`rimMarker2Color` characterization block from `game/self_test.lua` into `game/tests/legacy_rim_marker_styling.lua`, preserving shared cyan RGB, lower 0.4–0.5 secondary alpha, and smaller secondary-radius contracts.
- Added `game/tests/self_test_rim_marker_styling_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of all three marker-style assertions.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,306 to 1,291 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent INBOX 61(10) paused/gear-popup time-freeze structural characterization block into one `game/tests/legacy_*.lua` suite, preserving the `PlayScene.update` function contract.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
