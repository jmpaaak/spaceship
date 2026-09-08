## Current Status

- R1 Lane C (partial): extracted the adjacent `collection_store` file-round-trip and `PlayScene` injected-store initialization characterization block from `game/self_test.lua` into `game/tests/legacy_collection_store.lua`.
  - Preserved empty-load behavior, first-discovery return values, duplicate rejection across a reloaded store, persisted specimen IDs, and scene initialization of `collectedSpecimens`.
  - Added `game/tests/self_test_collection_store_extraction.lua` to enforce delegation, body removal, and retained persistence/scene-wiring behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,509 to 2,482 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent injected `bestAltitudeStore`/`PlayScene:persistBestAltitude()` characterization block into one `game/tests/legacy_*.lua` suite, preserving HUD record text across launch/settlement/returning phases and reload from the injected store.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
