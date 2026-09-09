## Current Status

- INBOX 75 is complete and moved to 처리 완료. Added a continuous distance-based discovery alpha (`discoveryAlpha`) in `game/minimap.lua` for the next undiscovered galaxy.
- The minimap rendering in `game/scenes/play_minimap.lua` now smoothly fades in the galaxy elements (mist/star -> boundary ring -> details) based on distance, preventing the pop-in effect.
- Added `testMinimapGalaxyDiscoveryFade` to `game/tests/legacy_galaxy_structure.lua` to verify the continuous alpha behavior. Tests passed.

## Next slice

- INBOX 76: Fix Asset Studio 8766 POST 501 error by running the POST-supported server from the repository on port 8766. Add clipboard image paste support (`Ctrl+V`/`Cmd+V`) to load images into the source image pipeline with `sourceKind="clipboard"`.
