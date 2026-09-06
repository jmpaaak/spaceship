## Current Status

- INBOX (37) complete: moon (satellite) system.
  - `world.planetHasMoon(planet)`: deterministic ~30% chance via `hash(x, y, 700) > 0.7`.
  - `world.moonForPlanet(planet, time)`: returns orbiting moon table or nil.
    - Orbit radius: `planet.radius + 15~25px`, period 3s, moon radius 3~5px.
  - `world.moonSampleValue()` → fixed $10 (10× planet $1).
  - `world.moonCollisionDamage(moon)` → same distance-based formula as planet (uses parent position).
  - Collection radius: `moonRadius + 15` (narrower than planets' +30).
  - Collision radius: `moonRadius + 5` (same formula as planets).
  - `play.lua`: moon state tracking (`moonDiscovered`, `moonCollided`), reset on relaunch.
  - `play.lua`: moon drawing — bright hue circle with highlight, collection ring, "Moon"/"위성" label.
  - i18n: `moon_label` = "Moon" / "위성".
  - INBOX-37 test block: spawn rate, orbit, sample value, collision damage, i18n.
  - `make verify` GREEN.

## Next slice
- INBOX next pending item (check INBOX.md).

## Previous

- INBOX (36) complete: flat $1 planet sample value.
  - `world.sampleValue()` → fixed `return 1`.
  - Comet value: 50 × $1 = $50.

- INBOX (35) complete: comet system — fast, rare, high-reward celestial body.
