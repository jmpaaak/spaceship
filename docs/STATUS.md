## Current Status

- INBOX (20a) complete: Minimap galaxy ring disc clipping via stencil.
- INBOX (20b) complete: Minimap galaxy overlap prevention.
  - Reduced `viewRadius` from `0.7 * galaxyCellSize` to `0.55 * galaxyCellSize` to zoom in, pushing adjacent galaxies further apart on the disc.
  - Galaxy boundary rings (`kind="galaxy"`) now only emitted for the containing galaxy; neighbouring galaxies still show their center dot markers but not the large boundary circle that caused visual overlap.
  - New test `testMinimapGalaxyOverlapPrevention` verifies only the containing galaxy has boundary rings and viewRadius ≤ 0.6 * cellSize.
  - make verify GREEN.
- INBOX (20d) complete: Minimap Earth/Star text labels.

## Next Slice

- INBOX (20c): Checkpoint color legend — verify red planet meaning, update legend if needed.
- INBOX (21): Distance = euclidean distance from Earth.
