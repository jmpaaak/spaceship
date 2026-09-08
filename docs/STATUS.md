## Current Status

- R1 Lane C (partial): extracted the `drawHudSpriteOrPoly` nil-image fallback characterization block from `game/self_test.lua` into `game/tests/legacy_hud_sprite_fallback.lua`.
  - Preserved the exported `PlayScene.drawHudSpriteOrPoly` contract and the nil-image/nil-polygon no-throw fallback through the existing engine-hosted test boundary.
  - Added `game/tests/self_test_hud_sprite_fallback_extraction.lua` to enforce delegation, body removal, and retention of both contracts.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 1,797 to 1,788 `wc -l` lines including both new registrations.

## Next slice

- R1 Lane C: extract the adjacent `drawPlanetEffectSprite` nil-image fallback and `planetEffectImages` slot characterization block into one `game/tests/legacy_*.lua` suite, preserving its exported false-return contract and six image-slot types.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
