## Current Status

- INBOX (27) complete: fix diagonal planet alignment from LCG hash bug.
  - `world.planets()` lines 263-271: changed `hash(sectorX, sectorY, salt+i)` pattern
    to `hash(sectorX + i*K, sectorY + i*K2, salt)` for radius, hue, x, y.
  - This scrambles `i` into the coordinate inputs instead of the salt, breaking the
    linear correlation that caused planets to align on diagonals when sectorX==sectorY.
  - Test `testPlanetDiagonalHash` verifies no diagonal alignment for sectors (1,1)..(20,20).
  - `make verify` GREEN.

## Next Slice

- INBOX (28): halve planet density + overlap prevention.
