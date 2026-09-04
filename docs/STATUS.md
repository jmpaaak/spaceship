# STATUS
- preflight this cycle: FAIL (`game/self_test.lua:4946`, stale fuel assertion; `git diff --check`, trailing whitespace).
- Slice: Item 11 — removed dead fuel state, upgrades, forecasts, slot bonuses, shop controls, UI text, and ship fuel consumption; redefined SCOUT's former fuel tradeoff as `+10 SPEED / -1 HULL`.

## 2026-09-04 — Item 11 fuel-remnant removal

- `game/expedition.lua` no longer exposes run fuel fields, fuel upgrades, maneuver burn helpers, launch forecasts, or next-launch fuel slot rewards.
- `game/scenes/play.lua` and `game/i18n.lua` no longer contain fuel shop rows, controls, status strings, forecasts, result strings, or settlement summaries.
- `game/ship.lua` now models thrust without a dead fuel field.
- Updated engine-hosted regressions to exercise the fuel-free run/shop/loadout shape and the SCOUT speed tradeoff without placeholder `assert(true)` checks.
- Verification: `git diff --check` clean; `GAME_HEADLESS=1 GAME_UNIT=1 /Users/jm/.local/bin/love .` reports `SPACESHIP_UNIT_OK` and `SPACESHIP_SMOKE_OK`; `make verify LOVE=/Users/jm/.local/bin/love` passes unit, smoke, bundle (`LOVE_BUNDLE_OK:build/game.love:58`), and asset-manifest checks.
- Next slice: Item 15(a/b) — remove the returning phase and in-flight slot controls, then expose slot play only from the Earth settlement shop using the existing Earth slot backend.

## 구현 내용

All gear-lane scope items (13, 9, 10, 12, 14) are fully implemented and verified:

- Item 13: hull_parts.json + engine_parts.json data externalization, tools/gear-editor/ static web editor with all effect categories A-F, sell/buy price preview, edition preview, galaxy-exclusive field round-trip, all editor<->gear.lua sync regression tests passing.
- Item 9: 36 hull parts (>20-30 target), tag-synergy engine (tagSynergyMultiplier/equippedTotals, multiplier >1 for shared tags), all self_test gear tests GREEN.
- Item 10: engine_parts.lua slot separation (hull=6, engine=3), 26 engine parts, independent equip/unequip/isFull, refined noSlotCost honored, engine synergy multiplier wiring on effectiveClimbSpeed.
- Item 12: rollRarity (4 tiers, luck-shifted), rollEdition (per-card editions list, base 8% chance, luck-boosted), applyEditionEffects (irradiated/crystallized/quantum_flawed/refined with drawback, synergyBonusAdd, noSlotCost, sellMultiplier), raritySellValue + buyPrice + crystallized sell premium.
- Item 14: effect categories A (5 additive), B (sellMultiplier/streakMultiplier, additive-then-multiply), C (luck/chainTrigger/rerollBonus), D (insurance/collisionRadius), E (detectionRadius/autoCollect), F (shopDiscount), G (fuelEfficiency/steeringResponsiveness/boostCharge engine-specialist). All effect types covered by bundled JSON content and regression tests.
- Item 15 data layer: earthSlotOddsProfiles (solar/fringe/void), galaxySlotOddsProfile (deterministic per galaxy hash), earthSlotSpin pure function, lastVisitedGalaxyId wiring in exploreHub.
- Item 7/8 gaps: shopPlanet, earthShopPool, galaxySpecificGear, exploreHub (hub confirmed-drop + edition rolling), hubPartialSettlement, hubExplored reset on safe relaunch, hubSettleStreakPersistence.

## 테스트 (TDD, RED → GREEN)
Full regression suite in game/self_test.lua (runGearTests, 42+ gear-specific test functions). All pass.

## 검증
`make verify LOVE=/Users/jm/.local/bin/love` 전체 GREEN (SPACESHIP_UNIT_OK,
SPACESHIP_SMOKE_OK x3, LOVE_BUNDLE_OK:build/game.love:58, ASSET_MANIFEST_OK).

- Next slice: (Scope End) This lane's pure-data/engine backend is complete. UI wiring (shop planet access popup, hub explore prompt, equipment management screen) is delegated to UI-focused lanes (play.lua, world.lua).

> 이전 cycle 이력은 `docs/STATUS_HISTORY.md`에 있다.
