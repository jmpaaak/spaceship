## Current Status

- INBOX (18) complete: Pause button — top-right corner during ascending phase.
  - 44×44 touch area at (668, 8), visible only in ascending phase.
  - Tap toggles `self.paused`; paused → `update()` returns early (dt=0 effect).
  - Pause icon: two vertical bars drawn semi-transparent (brighter when active).
  - Paused overlay: dark scrim + centered "PAUSED" / "일시정지" text (i18n).
  - Tap anywhere while paused (outside button) also unpauses.
  - Auto-unpauses when phase changes away from ascending.
  - Hidden in settlement/destroyed/launch phases.
  - Tests: testPauseButton() covers toggle, phase gating, update freeze, auto-clear.

## Next Slice

- INBOX (19): Planet text replacement — remove sample/damage labels, add discovery/hub/star/shop labels.
