## Current Status

- Extracted sector planet generation from `game/world.lua` (838→796 lines) into `game/world_planets.lua`.
- `world.planets()` remains the public API and delegates to the new module; hash/galaxyContaining/sectorSize are injected.
- Characterization: `game/tests/world_planets_extraction.lua` (RED before the file existed, then GREEN). Existing world-generation tests still pass.

## Next slice

- INBOX 64: scatter planet coordinates in `game/world_planets.lua` (polar/hash reseed + adjacent-sector min distance). Do not grow `world.lua`.
