## Current Status

- R1 Lane C (partial): extracted the Earth-shop `shopLoadoutLines()` abolished-fuel-key characterization block from `game/self_test.lua` into `game/tests/legacy_shop_loadout_removed_fuel.lua`.
  - Preserved all four absent fuel fields (`fuelAction`, `fuelStatus`, `fuelAffordable`, `fuelPreview`) and the three remaining upgrade-row contracts (`hullAction`, `yieldAction`, `steeringAction`) without changing production behavior.
  - Added `game/tests/self_test_shop_loadout_removed_fuel_extraction.lua` to enforce delegation, body removal, and contract retention.
  - Observed the expected missing-suite RED, then `make test LOVE=/Users/jm/.local/bin/love` GREEN. `game/self_test.lua` decreased from 2,166 to 2,142 `wc -l` lines including the new extraction-test registration.

## Next slice

- R1 Lane C: extract the adjacent Item 7(a) shop-planet modal keyboard characterization block into one `game/tests/legacy_*.lua` suite, preserving skip, successful purchase, insufficient-funds, and settlement-shortcut-consumption behavior.


> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다. 특정 과거 버그를 추적할 때만 그 파일을 검색하고, 평소에는 읽지 않는다.
