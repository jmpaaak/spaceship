## Current Status

- INBOX (36) complete: flat $1 planet sample value.
  - `world.sampleValue()` → fixed `return 1` (was `10 + floor(distance/100)*5`).
  - `sampleTier` and `collisionDamage` remain distance-based (unchanged).
  - Comet value: 50 × $1 = $50. (Moon will be 10× = $10 when INBOX-37 lands.)
  - Updated 5 existing test assertions to match new values; added INBOX-36 dedicated test block.
  - `make verify` GREEN.

## Next slice
- INBOX (37): moon system — 0–1 moons per planet, fast orbit, $10 reward.

## Previous

- INBOX (35) complete: comet system — fast, rare, high-reward celestial body.
  - `minimap.view()` galaxy entries now carry `isContaining` flag (true for the containing galaxy, false for others).
  - `play.lua`: galaxy dot markers only drawn for the containing galaxy; non-containing nearby galaxies are hidden entirely (rim marker from INBOX-34b already indicates nearest off-disc galaxy).
  - Hub markers (magenta diamond) also restricted to containing galaxy only.
  - Added `testMinimapGalaxyContainingFlag`: verifies exactly one containing galaxy at origin (milkyway), all others have `isContaining == false`.
  - `make verify` GREEN.
