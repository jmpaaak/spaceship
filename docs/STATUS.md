## Current Status

- INBOX (31) complete: minimap galaxy 2-marker fix.
  - `minimap.view()` galaxy entries now carry `isContaining` flag (true for the containing galaxy, false for others).
  - `play.lua`: galaxy dot markers only drawn for the containing galaxy; non-containing nearby galaxies are hidden entirely (rim marker from INBOX-34b already indicates nearest off-disc galaxy).
  - Hub markers (magenta diamond) also restricted to containing galaxy only.
  - Added `testMinimapGalaxyContainingFlag`: verifies exactly one containing galaxy at origin (milkyway), all others have `isContaining == false`.
  - `make verify` GREEN.

## Next slice
- Process next pending INBOX item.

## Previous

- INBOX (30) complete: hide starter switch when scout is active in shop.
  - (a) Raised `galaxyExistenceThreshold` from 0.72 to 0.82 (~18% galaxy density, down from ~28%).
  - Galaxy overlap filter (8-connected neighbour suppression) already in place from prior cycle.
  - (b) `minimap.view()` now emits `nearestGalaxyRimMarker` with `{dx, dy, distance, name, id}` when nearest non-home galaxy is outside the minimap disc.
  - `play.lua` draws a cyan dot + distance label on the disc rim for the marker.
  - Added `testMinimapGalaxyRimMarker`: verifies reduced density < 25%, rim marker structure.
  - `make verify` GREEN.

## Next Slice

- INBOX (29): collect zoom reduction 1.35→1.12.
