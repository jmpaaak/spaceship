## Current Status

- INBOX 78 Lane D wired the sixth and final approved photo-derived ordinary-planet candidate, `pp_earth_nasa_as17_148_22727`.
  - `game/celestial_asset_manifest.lua` now enables `assets/planet/studio/pp_earth.png`; its Asset Studio and asset-catalog entries are marked wired.
  - Ordinary earth planets prefer the decoded 128×128 RGBA derivative over the legacy animation sheet. A failed load preserves the existing `pp_earth` sprite/sheet fallback.
  - Ordinary-planet candidates remain excluded from hub and shop selection, so their existing artwork contracts are unchanged.
  - Engine-hosted tests cover earth routing, decoded-image precedence, failed-load fallback, and hub/shop isolation; `make verify LOVE=/Users/jm/.local/bin/love` is GREEN.

## Next slice

- INBOX 78 Lane D: wire the existing `star_sun_nasa_gsfc_20171208_archive_e002035` candidate through a dedicated central-star manifest and `game/scenes/play_star.lua`, preserving the current load-failure fallback and star geometry.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
