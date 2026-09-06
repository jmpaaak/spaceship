## Current Status

- INBOX (34a) complete: galaxy overlap prevention.
  - Refactored `world.galaxy()` into `rawGalaxy()` + overlap filter.
  - Each galaxy gets `_priority` from its existence hash; home galaxy has `math.huge`.
  - `M.galaxy()` checks 8-connected neighbours: if `dist < r1 + r2 + 200px padding`, lower-priority galaxy is suppressed (returns nil).
  - Home galaxy (0,0) is never suppressed.
  - Added `testGalaxyOverlapPrevention`: scans 60×60 grid, asserts no pair overlaps, home survives, determinism.
  - `make verify` GREEN.

## Next Slice

- INBOX (34b): minimap nearest galaxy marker on disc rim.
