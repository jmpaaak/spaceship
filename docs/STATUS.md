## Current Status

- R1 Lane C (partial): extracted the adjacent touch launch, held-steering/release, settlement purchase, and relaunch characterization block from `game/self_test.lua` into `game/tests/legacy_touch_flight_settlement.lua`.
  - Preserved touch launch phase transition, left/right active-state and movement assertions, pointer release behavior, hull/scout purchases, and relaunch behavior in their original order.
  - Added `game/tests/self_test_touch_flight_settlement_extraction.lua` to enforce delegation, body removal, and retained behavior markers.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` and `make verify LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,714 to 2,682 lines (including the new extraction-test registration).

## Next slice

- R1 Lane C: extract the adjacent `loadoutScene` baseline, purchased scout/upgrades, and destruction-reset `loadoutLines()` characterization block into one `game/tests/legacy_*.lua` suite, preserving hidden ship-name, hull, steering, and meta-wipe reset assertions.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
