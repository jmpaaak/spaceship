## Current Status

- Resolved INBOX 65: Added `x10` text label next to the HUD's durability blocks when `maxDurability >= 10`.
- The text is rendered using the standard Galmuri 11px font setting (`fonts.get(11)`) and colored gray to match the blocks' outline.
- Test `game/tests/hp_block_x10.lua` added and passing, which asserts the presence of the `x10` print and font configuration in `game/scenes/play_scene_draw.lua`.

## Next slice

- INBOX 66: Implement Booster+ regenerative mechanic. Update `game/expedition.lua` to treat `boostCharge` as a cap, recharge 1 boost every 5 seconds during ascent, and extend boost duration from 0.8s to 1.0s.
