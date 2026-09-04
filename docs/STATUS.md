# STATUS
- preflight this cycle: READY
- Slice: Item 15(c) — Earth shop slot ODDS badge used rewardProfile.name on a string

## 2026-09-04 — Item 15(c): Fix Earth shop slot ODDS badge (string vs table)

- Found bug: `expedition.earthSlotSpin` returns `rewardProfile` as a plain string (`"solar"`/`"fringe"`/`"void"`). Settlement `draw()` gated the ODDS badge on `earthShopSlotResult.rewardProfile.name`, which is always nil on a string, so the profile badge never rendered after a spin.
- Fix: added pure helper `PlayScene.earthSlotProfileLabel(rewardProfile)` that uppercases the string (`"void"` → `"VOID ODDS"`) and returns nil for empty/non-string. `draw()` now uses that helper.
- TDD: RED (`earthSlotProfileLabel must exist`) then GREEN. Covers solar/fringe/void labels, nil/empty skip, and a settlement `"l"` spin whose stored string `rewardProfile` formats as `"VOID ODDS"`.
- `make verify LOVE=/Users/jm/.local/bin/love`: SPACESHIP_UNIT_OK, SPACESHIP_SMOKE_OK x3, LOVE_BUNDLE_OK:build/game.love:58, ASSET_MANIFEST_OK.
- Next slice: remaining Item 11/15 UI remnants, or Item 7/8 wiring gaps.

## 2026-09-04 — Item 8: Fix double-dipping sample collection on hubs/shops

- Found bug: `play.lua` correctly evaluated `planet.hub` to call `expedition.settleAtHub` or `planet.isShop` to show shop offers, but it fell through and called `expedition.collectSample` for EVERY discovered planet. This violated Item 8's spec that hubs and shops do not yield samples.
- Fix: Wrapped the `collectSample` call in `play.lua` inside an `else` block so it only runs for normal planets.
- TDD: added `testItem8HubProximitySettle` in `game/self_test.lua`:
  (1) ship passing near a normal planet doesn't trigger settlement.
  (2) ship passing near a hub planet correctly triggers `settleAtHub` and clears `pendingSampleValue`, adding to `money`.
  (3) verified that `pendingSampleValue` is exactly 0 after hub proximity (detects the double-dipping bug).
  Confirmed RED before fix, GREEN after.
- `make verify LOVE=/Users/jm/.local/bin/love`: SPACESHIP_UNIT_OK,
  SPACESHIP_SMOKE_OK x3, LOVE_BUNDLE_OK:build/game.love:58, ASSET_MANIFEST_OK.
- Next slice: Audit remaining UI wiring for Item 11/15, or check if Item 7/8 has any gaps left (like Item 7 shop UI popups).

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
