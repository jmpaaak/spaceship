## Current Status

- INBOX 78 Lane D (partial): wired the approved `hub_uranus_nasa_pia18182` 128×128 RGBA Asset Studio derivative to dry-type hubs through `game/hub_planet_asset_manifest.lua`.
- The draw path now prefers the decoded Uranus derivative only for dry hubs, while failed decoding retains the existing dry PixelPlanets/hub-sheet fallback; ordinary planets and other hub types remain isolated.
- TDD evidence: observed RED for the missing dry-hub mapping, then `make test LOVE=/Users/jm/.local/bin/love` GREEN with path, decode-priority, and fallback contracts. `docs/assets/CELESTIAL_ASSET_STUDIO.json` now records this derivative as wired.

## Next slice

- INBOX 78 Lane D: wire the remaining `hub_venus_nasa_pia00104` derivative only to lava-type hubs with the same decode-priority, legacy-fallback, and type-isolation tests.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
