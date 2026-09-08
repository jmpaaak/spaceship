## Current Status

- R1 Lane C (partial): extracted the launch loadout visual/layout characterization block from `game/self_test.lua` into `game/tests/legacy_launch_loadout_layout.lua`.
  - Preserved Earth-disc coverage, the hidden redundant title, bottom-third placement, row spacing, gear-box dimensions, full-canvas touch bounds, and minimum font size.
  - Added `game/tests/self_test_launch_loadout_layout_extraction.lua` to enforce delegation, body removal, and retained behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,262 to 2,217 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent ascending left/right full-canvas touch-steering characterization block into one `game/tests/legacy_*.lua` suite, preserving left/right-half activation and release behavior at the control-area edges.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
