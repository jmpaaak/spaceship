## Current Status

- INBOX (20a) complete: Minimap galaxy ring disc clipping.
  - Added `love.graphics.stencil` circular clip in `drawMinimap()` so all rings, galaxy markers, hub markers, earth, player are clipped inside the minimap disc circle.
  - Stencil enabled after background disc draw, disabled before beyond-chart arrows/text.
  - New test `testMinimapStencilClip` verifies stencil() and setStencilTest() calls with correct args.
  - make verify GREEN.

## Next Slice

- INBOX (20b-d): Minimap — galaxy overlap prevention, checkpoint color legend, Earth/Star text labels.
