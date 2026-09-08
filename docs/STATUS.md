## Current Status

- INBOX 78 Lane D wired the fifth approved photo-derived central-star candidate, `star_sdo_nasa_pia26681`, to bare-type galaxies only.
  - `game/central_star_asset_manifest.lua` now allowlists `assets/star/studio/star_sdo.png`; its Asset Studio and asset-catalog records are marked wired.
  - A decoded 128×128 RGBA studio SDO image takes precedence over the legacy bare sheet. Decode failure keeps the existing exact-type/sun/circle fallback chain.
  - Engine-hosted tests cover manifest routing, decoded-image precedence, ice-type isolation, and unchanged center/diameter geometry; the existing world suite continues to cover central-star gravity and collision behavior. `make verify LOVE=/Users/jm/.local/bin/love` is GREEN.

## Next slice

- INBOX 78 Lane D: wire one additional approved hub-planet candidate through `game/hub_planet_asset_manifest.lua`, preserving hub type isolation, location, radius, collision, and ordinary-planet separation.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
