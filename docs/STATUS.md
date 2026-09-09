## Current Status

- INBOX 77(2): equipped hull and engine cards can now be sold from their detail tooltip in every phase, including flight, using the localized `[S] SELL` button or its 50px touch target.
- `game/shop_gear_rules.lua` owns atomic sell-value/payment/inventory removal; `game/expedition_gear.lua` immediately refreshes loadout aliases and ship stats and clamps durability after sale. Missing cards and duplicate taps cannot pay twice.
- Added `game/tests/gear_sell.lua`; RED was observed on the former flight-phase rejection, then `make test LOVE=/Users/jm/.local/bin/love` passed after implementation.

## Next slice

- INBOX 77(3): remove all residual `SCOUT X` / `SCOUT ✓` state text from purchased or selected scout cards in `game/scenes/play_loadout_data.lua` and its i18n consumers, with `game/tests/scout_status_hidden.lua` coverage.
