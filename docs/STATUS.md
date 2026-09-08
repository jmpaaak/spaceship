## Current Status

- INBOX 78 Lane D wired the first approved photo-derived runtime candidate, `pp_bare_nasa_pia00405`.
  - `game/celestial_asset_manifest.lua` is the explicit runtime allowlist; only `assets/planet/studio/pp_bare.png` is enabled in this slice.
  - Bare planets prefer the decoded 128×128 RGBA Asset Studio derivative over the legacy animation sheet. If that image cannot load, the existing `pp_bare` sprite/sheet path remains the fallback.
  - Draw scaling still derives from `planet.radius`; collision, gravity, hub placement, and minimap rules were not changed.
  - Engine-hosted tests cover manifest routing, studio precedence, and failed-load fallback; `make verify LOVE=/Users/jm/.local/bin/love` is GREEN.

## Next slice

- INBOX 78 Lane D: add the existing `pp_gas_nasa_pia01518` candidate to the dedicated runtime manifest with the same decoded-image precedence and legacy fallback contract.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
