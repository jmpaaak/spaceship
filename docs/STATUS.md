## Current Status

- INBOX (20a) complete: Minimap galaxy ring disc clipping via stencil.
- INBOX (20d) complete: Minimap Earth/Star text labels.
  - Added i18n keys `minimap_earth_label` (en: "Earth(HUB)" / ko: "지구(HUB)") and `minimap_star_label` (en: "Star" / ko: "항성").
  - In `drawMinimap()`, after player marker and before stencil clear, draws 11px grey (0.6, 0.6, 0.6, 0.7) labels next to Earth and Sun markers using `fonts.get(11)`.
  - Labels are inside the stencil-clipped disc region so they clip naturally.
  - New test `testMinimapEarthStarLabels` verifies printf calls contain both label texts and setFont is called.
  - Updated existing drawMinimap test mocks (testMinimapUnifiedGalaxyPalette, testMinimapStencilClip) with getFont/setFont/newFont stubs.
  - make verify GREEN.

## Next Slice

- INBOX (20b): Minimap galaxy overlap prevention — visual overlap check, viewRadius or marker size adjustment.
- INBOX (20c): Checkpoint color legend — verify red planet meaning, update legend if needed.
