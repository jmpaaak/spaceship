## Current Status

- R1 Lane C (partial): extracted the dead in-flight slot localization characterization block from `game/self_test.lua` into `game/tests/legacy_inflight_slot_i18n.lua`.
  - Preserved all 18 missing-key checks in both English and Korean, and explicitly characterized that each locale's `returning_message` remains free of abolished in-flight slot wording while restoring the caller's locale.
  - Added `game/tests/self_test_inflight_slot_i18n_extraction.lua` to enforce delegation, body removal, the complete key list, and both returning-message checks.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,202 to 2,179 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent dead expedition fuel-upgrade/run slot-state characterization block into one `game/tests/legacy_*.lua` suite, preserving the absent `buyFuelUpgrade`, `slotOpportunities`, and `slotDistance` contracts.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
