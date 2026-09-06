## Current Status

- INBOX (24) complete: sample collect zoom-in + slower timeslip.
  - (a) `collectZoom = { timer = 0.5, scale = 1.35, planetX, planetY }` set on sample collection.
    Camera zooms 1.35× toward ship–planet midpoint over 0.5s, lerp back to 1.0.
    `love.graphics.push/scale` wraps world rendering; HUD stays unzoomed.
  - (b) `timeSlip.scale` changed from 0.3 to 0.24 (1.25× slower).
  - Update tick decrements `collectZoom.timer` by rawDt; nils when expired.
  - Test `INBOX-24 collectZoom + timeslip OK` verifies timer/scale/expiry.
  - `make verify` GREEN.

## Next Slice

- INBOX: check for next pending item.
