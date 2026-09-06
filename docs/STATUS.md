## Current Status

- INBOX (20) complete: Minimap galaxy clipping, overlap prevention, checkpoint colors, Earth/Star labels.
  - (a) Stencil clip: `love.graphics.stencil` clips all minimap content inside disc boundary.
  - (b) Overlap prevention: `viewRadius` reduced to 0.55*cellSize; only containing galaxy emits boundary ring.
  - (c) Checkpoint colors confirmed: gold pulsing star = checkpoint galaxy, magenta diamond = HUB. No separate red marker exists.
  - (d) Earth(HUB)/Star text labels: 11px grey font, stencil-clipped inside disc.
  - Tests `testMinimapStencilClip` + `testMinimapEarthStarLabels` registered and GREEN.

## Next Slice

- INBOX (21): Distance = euclidean distance from Earth (replace virtual altitude on HUD).
