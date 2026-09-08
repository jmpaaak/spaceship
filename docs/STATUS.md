## Current Status

- R1 Lane C (partial): extracted the adjacent injected `bestAltitudeStore` / `PlayScene:persistBestAltitude()` characterization block from `game/self_test.lua` into `game/tests/legacy_best_altitude_persistence.lua`.
  - Preserved initial record loading, HUD record text through settlement and launch, the returning-phase save, and record reload into a restarted scene.
  - Added `game/tests/self_test_best_altitude_persistence_extraction.lua` to enforce delegation, body removal, and retained phase/HUD/injected-store behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,482 to 2,458 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent sample collection floating-text roll-up characterization block into one `game/tests/legacy_*.lua` suite, preserving the mocked nearby planet, `+$0` to `+$1` timing, upward motion, hold interval, and removal timing.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
