## Current Status

- INBOX 61 is complete: slot HARVEST settlement now applies shop-upgrade units. `play_slot.lua` adds `round(rewardValue / sampleYieldUpgradeAmount)` to `sampleYieldUpgradeLevel` instead of a hard-coded +1.
- Home-galaxy 2-match HARVEST is +1 level (x1.10); 3-match is +5 levels (x1.50). Result copy still shows the actual `rewardValue` (`+0.10` / `+0.50`). SPEED still uses `slotSpeedBonus += rewardValue`; DURABILITY still adds `rv` hull levels.
- `earthSlotSpin` HARVEST `rewardValue` 0.10/0.50 (times tier) is unchanged. `game/tests/slot_payout_audit.lua` is GREEN.

## Next slice

- INBOX 62: `slot_spin` SFX volume 0.3 (half of the global 0.6) via a def `volume` field in `game/sfx.lua`; `game/tests/sfx.lua`.
