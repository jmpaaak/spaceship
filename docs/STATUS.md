## Current Status

- INBOX (30) complete: hide starter switch when scout is active in shop.
  - `shopLoadoutLines()`: when scout is owned+selected, `shipAction`/`shipStatus`/`shipAffordable` are nil, `shipHidden = true`, `scoutTradeoff = {}`.
  - Draw: ship slot shows "SCOUT ✓" instead of action/preview. scoutTradeoff lines skipped when empty.
  - Key/touch "v" is a no-op when scout is already selected.
  - Updated existing self_test assertions + added INBOX-30 coverage.
  - `make verify` GREEN.

## Next slice
- INBOX (31): minimap galaxy 2-marker fix — only show containing galaxy rings, dim non-containing markers.

## Previous

- INBOX (34) complete: galaxy overlap prevention + minimap nearest galaxy rim marker.
  - (a) Raised `galaxyExistenceThreshold` from 0.72 to 0.82 (~18% galaxy density, down from ~28%).
  - Galaxy overlap filter (8-connected neighbour suppression) already in place from prior cycle.
  - (b) `minimap.view()` now emits `nearestGalaxyRimMarker` with `{dx, dy, distance, name, id}` when nearest non-home galaxy is outside the minimap disc.
  - `play.lua` draws a cyan dot + distance label on the disc rim for the marker.
  - Added `testMinimapGalaxyRimMarker`: verifies reduced density < 25%, rim marker structure.
  - `make verify` GREEN.

## Next Slice

- INBOX (29): collect zoom reduction 1.35→1.12.
