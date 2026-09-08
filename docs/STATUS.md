## Current Status

- INBOX 78 Lane D wired the first approved photo-derived hub candidate, `hub_neptune_nasa_pia00046`, to ice-type hubs only.
  - New `game/hub_planet_asset_manifest.lua` allowlists `assets/planet/studio/hub_neptune.png`; its Asset Studio and asset-catalog records are marked wired.
  - A decoded 128×128 RGBA studio Neptune takes precedence in the hub-only draw path. Decode failure preserves the existing typed PixelPlanets/hub-sheet fallback chain.
  - Engine-hosted tests cover manifest routing, decoded-image precedence, load-failure fallback, ordinary-planet isolation, and the existing hub geometry suite; `make verify LOVE=/Users/jm/.local/bin/love` is GREEN.

## Next slice

- INBOX 78 Lane D: wire one additional approved central-star candidate through `game/central_star_asset_manifest.lua`, preserving star type isolation, center, diameter, gravity, and collision behavior.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
