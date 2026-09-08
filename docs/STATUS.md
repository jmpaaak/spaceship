## Current Status

- R1 Lane C (partial): extracted the `drawFloatingIconSprite` nil-image fallback and three floating-icon image-slot characterization block from `game/self_test.lua` into `game/tests/legacy_floating_icon_sprite.lua`.
  - Preserved the exported `PlayScene.drawFloatingIconSprite` contract, nil-image false return, and `floatingSampleIconImage`, `floatingDamageIconImage`, and `messageBannerIconImage` slot types through the engine-hosted test boundary.
  - Added `game/tests/self_test_floating_icon_sprite_extraction.lua` to enforce delegation, body removal, and retention of both behavior contracts.
  - Observed the expected delegation RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,771 to 1,755 `wc -l` lines including both new registrations.

## Next slice

- R1 Lane C: extract the adjacent `drawPanelSprite` nil-image/native-size behavior and eight panel image-slot characterization block into one `game/tests/legacy_*.lua` suite, preserving graphics restoration, return values, and slot types.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
