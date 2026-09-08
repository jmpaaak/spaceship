## Current Status

- R1 Lane C (partial): extracted the abolished expedition fuel-upgrade/run slot-state characterization block from `game/self_test.lua` into `game/tests/legacy_expedition_removed_slots.lua`.
  - Preserved the absent `buyFuelUpgrade`, `slotOpportunities`, and `slotDistance` contracts without changing production behavior.
  - Added `game/tests/self_test_expedition_removed_slots_extraction.lua` to enforce delegation, body removal, and retention of all three assertions.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,179 to 2,166 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent Earth-shop `shopLoadoutLines()` abolished-fuel-key characterization block into one `game/tests/legacy_*.lua` suite, preserving all four absent fuel fields and the three remaining upgrade rows.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
