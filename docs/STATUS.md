## Current Status

- INBOX (42) complete: gear slots layout changed from horizontal row to vertical column.
  - `drawHudGearSlots`: x fixed at 5px, y increments by (slotSize+gap) per slot downward.
  - Hull 6 slots, then 8px gap, then engine 3 slots — single vertical column.
  - Test updated: horizontal width assert → vertical height assert (< 600px).
  - `make verify` GREEN.

## Next slice

- INBOX (43): HUD icon replacement — PIL-generated distance/cash/durability icons.

## Previous

- INBOX (41) complete: HUD font size unified across all phases (launch = ascending).
- INBOX (40) complete: Gear slots grid fixed below left HUD stats during ascending/returning/launch.
- INBOX (36) complete: flat $1 planet sample value.
