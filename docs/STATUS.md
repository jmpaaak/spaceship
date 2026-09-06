## Current Status

- INBOX (21) complete: HUD distance now shows euclidean distance from Earth center to ship.
  - `hudLines()` computes `sqrt((ship.x - earthCenterX)^2 + (ship.y - earthCenterY)^2)` instead of virtual `run.altitude`.
  - `run.altitude` / `bestAltitude` kept for internal sample-value calculations and meta-reset.
  - Test `distScene21` verifies ship at (300, -325) → Earth(0,75) shows DIST 0500.
  - `make verify` GREEN.

## Next Slice

- INBOX (23): Shrink Earth settle radius closer to visual radius (margin 30→10).
