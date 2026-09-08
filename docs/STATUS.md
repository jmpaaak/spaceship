## Current Status

- R1 Lane C (partial): extracted the `drawPanelSprite` characterization block from `game/self_test.lua` into `game/tests/legacy_panel_sprite.lua`.
  - Preserved the exported helper contract, nil-image false return, native 64×64 draw scale, `love.graphics` restoration, and all eight panel image-slot types through the engine-hosted test boundary.
  - Added `game/tests/self_test_panel_sprite_extraction.lua` to enforce delegation, body removal, and retention of the behavior contracts.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,755 to 1,703 `wc -l` lines including both new registrations.

## Next slice

- R1 Lane C: extract the adjacent `drawShopIconSprite` / `drawStarPointSprite` nil-image behavior and four joystick/star/specimen image-slot characterization block into one `game/tests/legacy_*.lua` suite, preserving return values and slot types.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
