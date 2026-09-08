## Current Status

- INBOX 78 Lane D wired the second approved photo-derived ordinary-planet candidate, `pp_gas_nasa_pia01518`.
  - `game/celestial_asset_manifest.lua` now enables `assets/planet/studio/pp_gas.png`; its Asset Studio manifest entry is marked wired.
  - Ordinary gas planets prefer the decoded 128×128 RGBA derivative over the legacy animation sheet. A failed load preserves the existing `pp_gas` sprite/sheet fallback.
  - Ordinary-planet candidates are explicitly excluded from hub and shop selection, so their existing artwork contracts remain unchanged.
  - Engine-hosted tests cover gas routing, decoded-image precedence, failed-load fallback, and hub isolation; `make verify LOVE=/Users/jm/.local/bin/love` is GREEN.

## Next slice

- INBOX 78 Lane D: add the existing `pp_dry_nasa_pia00407` candidate to the dedicated runtime manifest with the same ordinary-planet decoded-image precedence, legacy fallback, and hub/shop isolation contract.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
