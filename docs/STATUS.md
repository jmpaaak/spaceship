## Current Status

- INBOX 78 Lane D wired the second approved photo-derived hub candidate, `hub_pluto_nasa_pia19952`, to bare-type galaxy hubs only.
  - `game/hub_planet_asset_manifest.lua` now allowlists `assets/planet/studio/hub_pluto.png`; its Asset Studio and asset-catalog records are marked wired.
  - A decoded 128×128 RGBA Pluto image takes precedence over legacy bare hub artwork. Decode failure retains the existing PixelPlanets/hub-sheet fallback, and ordinary planets remain isolated.
  - Engine-hosted tests cover manifest routing, decoded-image precedence, bare-type isolation, and decode-failure fallback; the existing world suite continues to cover hub location, radius, and collision behavior. `make verify LOVE=/Users/jm/.local/bin/love` is GREEN.

## Next slice

- INBOX 78 Lane D: wire one additional approved hub-planet candidate through `game/hub_planet_asset_manifest.lua`, preserving hub type isolation, location, radius, collision, and ordinary-planet separation.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
