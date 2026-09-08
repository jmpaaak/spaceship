## Current Status

- R1 Lane C (partial): extracted the destroyed/relaunch and launch full-canvas touch-area characterization block from `game/self_test.lua` into `game/tests/legacy_destroyed_launch_touch.lua`.
  - Preserved 34px/44pt sizing, the 720×1280 destroyed surface, and corner/center tap actions that restart a destroyed run or launch a new run.
  - Added `game/tests/self_test_destroyed_launch_touch_extraction.lua` to enforce delegation, body removal, and retained behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,326 to 2,262 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent launch loadout visual/layout characterization block into one `game/tests/legacy_*.lua` suite, preserving Earth-disc coverage, hidden redundant title, bottom-third placement, row spacing, gear-box size, full-canvas touch bounds, and font size.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
