## Current Status

- INBOX R1 lane C slice: moved the last-checkpoint respawn characterization body from `game/self_test.lua` into `game/tests/legacy_last_checkpoint.lua`, preserving its Earth/hub settlement, destruction, fallback, and relaunch checks in the same execution order.
- Added `game/tests/self_test_last_checkpoint_extraction.lua` to enforce delegation and prevent the test body from returning to the runner. TDD RED observed when the new extraction check could not load the not-yet-created legacy suite; focused engine-hosted GREEN then reported `R1-C self_test last-checkpoint extraction OK` and `SPACESHIP_UNIT_OK`.
- `game/self_test.lua` decreased from 825 to 773 lines. `make verify LOVE=/Users/jm/.local/bin/love` is GREEN (`SPACESHIP_UNIT_OK`, source/package smoke OK, 28 Python tests OK, `LOVE_BUNDLE_OK`, `ASSET_MANIFEST_OK`).
- R1 remains pending because additional inline legacy bodies still need extraction before `self_test.lua` is runner/common-fixture centered.

## Next slice

- INBOX R1 lane C: extract the adjacent INBOX 61(24b) title-menu composition body from `game/self_test.lua` into `game/tests/legacy_title_menu_composition.lua`, preserving callback and button-order behavior, with an engine-hosted extraction characterization test.

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
