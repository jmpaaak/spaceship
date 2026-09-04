# STATUS
- preflight this cycle: READY
- Slice: Item 7(a) shop modal keyboard interaction regression tests

## 2026-09-04 — Item 7(a): Add regression tests for shop-planet modal Y/N keyboard interaction

- Commit 4358510 ("Finish Item 7(a)") added `keypressed("y"/"n")` shop modal handling to play.lua but had zero self_test coverage for that path.
- Added a 4-case regression block in `game/self_test.lua`:
  (a) "n" key dismisses shopModal without deducting money or equipping gear.
  (b) "y" key with sufficient money calls `buyGearFromShopPlanet`, clears shopModal, deducts exactly `gear.buyPrice`, and appends a floating text naming the gear.
  (c) "y" key with insufficient money keeps shopModal open and sets `shopModal.errorText` without touching money.
  (d) shopModal open during settlement phase: "y" is consumed by the modal handler and does NOT fall through to the settlement `sampleYieldUpgrade` shortcut.
- All 4 cases GREEN on first run (behavior was already correctly implemented by 4358510; test coverage was the gap).
- Also committing preflight-compressed INBOX.md (-561 chars) from cycle start.
- `make verify LOVE=/Users/jm/.local/bin/love`: SPACESHIP_UNIT_OK, SPACESHIP_SMOKE_OK x3, LOVE_BUNDLE_OK:build/game.love:58, ASSET_MANIFEST_OK.
- Next slice: Item 7(b) regression gap audit — `exploreHub` hub-drop behavior vs. test coverage, or item 11 remaining fuel-framing text audit.




- `hud_status` in i18n.lua (en + ko) had `S%02d` that displayed `slotOpportunities` (always 0 after item-15 abolished in-flight slots). This was dead/misleading UI implying a slot mechanic still existed mid-flight.
- Removed `S%02d` from `hud_status` so it matches `hud_status_no_slots` format: `"H%d/%d %-6s"`. Both keys now share the same format; `hud_status_no_slots` kept as an alias for backward-compat.
- Simplified `hudLines()` in `play.lua` to always call `hud_status_no_slots` (removed the old launch-vs-other-phase conditional that existed solely to hide `S00` on launch only).
- TDD: Updated existing `"H3/3 SETTLE S00"` assertion to `"H3/3 SETTLE"`, added `not find("S%d%d")` guard across all phases. Confirmed RED before fix, GREEN after.
- `make verify LOVE=/Users/jm/.local/bin/love`: SPACESHIP_UNIT_OK, SPACESHIP_SMOKE_OK x3, LOVE_BUNDLE_OK:58, ASSET_MANIFEST_OK.
- Next slice: Item 11(b)(c) — dead fuel upgrade shop rows in main.lua capture-phase scripts / expedition.lua dead references cleanup, or move to Item 15 remaining UI wiring.



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
