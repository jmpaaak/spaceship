## Current Status

- R1 Lane C (partial): extracted the adjacent destruction/meta-wipe and best-altitude file-persistence characterization block from `game/self_test.lua` into `game/tests/legacy_destruction_persistence.lua`.
  - Preserved staged hull damage, full run-state wipe, lost-run telemetry, relaunch reset, all-time-best preservation, and the best-altitude file round trip in their original order.
  - Added `game/tests/self_test_destruction_persistence_extraction.lua` to enforce delegation, body removal, and retained destruction/relaunch/persistence behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,554 to 2,509 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent `collection_store` file-round-trip and `specimenScene` collection-store wiring characterization block into one `game/tests/legacy_*.lua` suite, preserving first-discovery return values, persisted specimen IDs, and scene initialization from the injected store.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
