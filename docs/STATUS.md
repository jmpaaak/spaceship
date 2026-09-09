## Current Status

- Extracted sector planet generation from `game/world.lua` (838→796 lines) into `game/world_planets.lua`.
- `world.planets()` remains the public API and delegates to the new module.
- Resolved INBOX 64: `game/world_planets.lua` now generates polar coordinates utilizing new salts and prevents planet overlap across sector boundaries.
- The `testSameGxXSpread` stddev assertion, along with all scatter layout tests, passes correctly.

## Next slice

- INBOX 65: Add `x10` label next to the HUD's durability blocks when `maxDurability >= 10`. Update `game/scenes/play_hud.lua` (or delegate from play.lua if not extracted yet).
