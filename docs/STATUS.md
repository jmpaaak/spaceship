## Current Status

- R1 Lane C (partial): extracted the `gearPopupChipVertical` characterization block from `game/self_test.lua` into `game/tests/legacy_gear_popup_chip_layout.lua`, preserving the vertical gear-popup chip-stack contract.
- Added `game/tests/self_test_gear_popup_chip_layout_extraction.lua` to enforce delegation, removal of the legacy body, and preservation of the vertical-layout assertion.
- TDD evidence: observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,310 to 1,306 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent `rimMarker1Color`/`rimMarker2Color` characterization block into one `game/tests/legacy_*.lua` suite, preserving shared cyan RGB, lower 0.4–0.5 secondary alpha, and smaller secondary radius contracts.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
