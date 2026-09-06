## Current Status

- INBOX (35) complete: comet system — fast, rare, high-reward celestial body.
  - `world.lua`: `M.comets` table, `M.spawnComet()`, `M.cometPosition()`, `M.tickCometSpawn()`, `M.nearbyComets()`, `M.cometSampleValue()`, `M.cometCollisionDamage()`, `M.resetComets()`.
  - Spawning: first comet guaranteed at 60s, then 30% chance every 30s.
  - Speed 80–120 px/s (linear straight-line trajectory, edge-to-edge).
  - Radius 8–12px, tail particle trail (yellow→red gradient, 40–60px).
  - Sample value: 50× planet base ($1 × 50 after INBOX-36 lands).
  - Collection radius: `radius + 30` (same as planets). Collision damage: same planet formula.
  - `i18n.lua`: `comet_label` = "Comet" / "혜성".
  - `play.lua`: comet state init, reset on relaunch, update (spawn + collect/collide), draw (body + tail + label with sin bob).
  - `self_test.lua`: INBOX-35 block — resetComets, no-spawn-before-60s, guaranteed-first, position, sampleValue 50×, collisionDamage, nearbyComets, pruning, spawn interval, play scene init.
  - `make verify` GREEN.

## Next slice
- INBOX (36): flat $1 planet sample value.

## Previous

- INBOX (31) complete: minimap galaxy 2-marker fix.
  - `minimap.view()` galaxy entries now carry `isContaining` flag (true for the containing galaxy, false for others).
  - `play.lua`: galaxy dot markers only drawn for the containing galaxy; non-containing nearby galaxies are hidden entirely (rim marker from INBOX-34b already indicates nearest off-disc galaxy).
  - Hub markers (magenta diamond) also restricted to containing galaxy only.
  - Added `testMinimapGalaxyContainingFlag`: verifies exactly one containing galaxy at origin (milkyway), all others have `isContaining == false`.
  - `make verify` GREEN.
