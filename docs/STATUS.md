## Current Status

- INBOX (23) complete: Earth settle radius shrunk closer to visual radius.
  - `earthSettleRadius` 88→68 (margin 30→10), `launchSpawnY` -63→-13 (margin 50→20).
  - `earthReentryRadius` 174→145 (58*2.5 instead of 58*3).
  - self_test reentryR updated to use `PlayScene.earthReentryRadius` directly.
  - New assertion block verifies all three constants + spawn-outside-settle invariant.
  - `make verify` GREEN.

## Next Slice

- INBOX (24): Sample collect zoom-in + timeslip 0.3→0.24.
