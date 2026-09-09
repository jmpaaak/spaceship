## Current Status

- INBOX 78 Lane D (partial): wired the approved `hub_venus_nasa_pia00104` 128×128 RGBA Asset Studio derivative to lava-type hubs through `game/hub_planet_asset_manifest.lua`.
- The draw path now prefers the decoded Venus derivative only for lava hubs, while failed decoding retains the existing lava PixelPlanets/hub-sheet fallback; ordinary planets and other hub types remain isolated. All 16 celestial derivatives produced by Lane B are now wired.
- TDD evidence: observed RED for the missing lava-hub mapping, then the engine-hosted unit suite passed with path, decode-priority, fallback, and type-isolation contracts. `docs/assets/CELESTIAL_ASSET_STUDIO.json` now records this derivative as wired; `make verify LOVE=/Users/jm/.local/bin/love` is GREEN.

## Next slice

- INBOX 78 verification: capture and inspect one actual runtime frame containing a wired ordinary planet, establishing a reproducible representative-capture path before the central-star, hub, and ship captures.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
