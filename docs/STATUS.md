## Current Status

- INBOX (28) complete: halve planet density and prevent overlap.
  - `world.planets()` line 257: changed `hash(...,1) > 0.70` → `> 0.85` (30%→15%).
  - `world.planets()` line 258: changed `hash(...,7) > 0.96` → `> 0.98` (4%→2%).
  - Added overlap prevention: when 2 planets spawn in same sector and
    distance < (r1 + r2 + 10), the second planet is removed.
  - Tests: `testPlanetDensityHalved` scans 441 sectors, asserts total < 30%.
  - Tests: `testPlanetOverlapPrevention` scans 101×101 sectors, asserts all
    2-planet sectors have dist >= (r1 + r2 + 10).
  - `make verify` GREEN.

## Next Slice

- INBOX (29): reduce collect zoom 1.35 → 1.12.
