## Current Status

- INBOX 78 Lane D wired the first approved photo-derived central-star candidate, `star_sun_nasa_gsfc_20171208_archive_e002035`, to the home galaxy's `earth` star type.
  - New `game/central_star_asset_manifest.lua` allowlists `assets/star/studio/star_sun.png`; its Asset Studio and asset-catalog records are marked wired.
  - A decoded 128×128 RGBA studio Sun takes precedence over the legacy earth sheet. Decode failure preserves the existing exact-type, sun, and circle fallback chain.
  - Engine-hosted tests cover manifest routing, decoded-image precedence, load-failure fallback, other-type isolation, and unchanged center/diameter geometry; `make verify LOVE=/Users/jm/.local/bin/love` is GREEN.

## Next slice

- INBOX 78 Lane D: wire one existing approved hub-planet candidate through a dedicated hub manifest and the hub-only draw path, preserving hub position, radius, collision, and non-hub artwork selection.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
