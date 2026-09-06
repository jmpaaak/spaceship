## Current Status

- INBOX (33) complete: RCS exhaust color and size scale with speed upgrade level.
  - Added `expedition.rcsSpeedLevel(run)` → 0/1/2/3 from `steeringUpgradeLevel`.
  - Lv0 (no upgrades): white (1,1,1), radius 1.5.
  - Lv1 (upgrades 1-2): red (1,0.4,0.2), radius 2.
  - Lv2 (upgrades 3-4): blue (0.3,0.5,1), radius 2.5.
  - Lv3 (upgrades 5+): rainbow (HSV cycling), radius 3.
  - Draw code uses `particle.radius or 1.5` instead of hardcoded 1.5.
  - Self-test: INBOX-33 block validates all 4 levels (mapping + scene particle checks).
  - `make verify` GREEN.

## Next Slice

- INBOX (29): reduce collect zoom 1.35 → 1.12.
