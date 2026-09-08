## Current Status

- R1 Lane C (partial): extracted the adjacent sample-collection floating-text roll-up characterization block from `game/self_test.lua` into `game/tests/legacy_sample_collection_floating_text.lua`.
  - Preserved the mocked nearby sample planet, initial `+$0`, mid-animation/final `+$1`, upward movement, post-roll-up hold interval, and removal timing.
  - Added `game/tests/self_test_sample_collection_floating_text_extraction.lua` to enforce delegation, body removal, and retained behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,458 to 2,419 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent settlement touch-row/layout characterization block into one `game/tests/legacy_*.lua` suite, preserving minimum row/column touch sizes, summary and shop column spacing, alternating row backgrounds, and row-center purchase/relaunch actions.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
