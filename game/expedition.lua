local M = {}

-- Minimal exception carved out by loop/PROMPT.md: this lane may not touch
-- play.lua/world.lua/i18n.lua, but IS explicitly allowed a "최소한의 로더
-- 호출" to wire game/gear.lua (item 9/13) and game/engine_parts.lua (item
-- 10) into actual run state. requiring these here (rather than in play.lua)
-- keeps that wiring inside this lane's owned files.
local lifecycle = require("game.expedition_lifecycle")
local expeditionGear = require("game.expedition_gear")
local expeditionUpgrade = require("game.expedition_upgrade")
local expeditionRun = require("game.expedition_run")


local expedition_slot = require('game.expedition_slot')
M.slotSymbols = expedition_slot.slotSymbols
M.slotWeights = expedition_slot.slotWeights
M.slotTotalWeight = expedition_slot.slotTotalWeight
M.slotPayouts = expedition_slot.slotPayouts
M.earthSlotOddsProfiles = expedition_slot.earthSlotOddsProfiles
M.earthSlotRewardMultipliers = expedition_slot.earthSlotRewardMultipliers
M.slotSpinCost = expedition_slot.slotSpinCost
M.slotConfigPath = expedition_slot.slotConfigPath
M.slotReward = expedition_slot.slotReward


function M.loadSlotConfig(fsOverride)
    local slot = require('game.expedition_slot')
    local r1, r2 = slot.loadSlotConfig(fsOverride)
    M.slotSymbols = slot.slotSymbols
    M.slotWeights = slot.slotWeights
    M.slotTotalWeight = slot.slotTotalWeight
    M.slotPayouts = slot.slotPayouts
    M.earthSlotOddsProfiles = slot.earthSlotOddsProfiles
    M.earthSlotRewardMultipliers = slot.earthSlotRewardMultipliers
    M.slotSpinCost = slot.slotSpinCost
    return r1, r2
end

function M.slotSymbolProbability(symbol)
    return require('game.expedition_slot').slotSymbolProbability(symbol)
end

-- INBOX (52b): slotReward now returns a multiplier (pair=3, triple=10).
-- The actual money value is computed by the caller as spinCost * multiplier.
-- matchCount and matchSymbol are returned by earthSlotSpin for effect dispatch.


local function weightedSlotSymbol(roll)
    local cumulative = 0
    for _, symbol in ipairs(slotSymbols) do
        cumulative = cumulative + slotWeights[symbol]
        if roll <= cumulative then return symbol end
    end
    return slotSymbols[#slotSymbols]
end
M.weightedSlotSymbol = weightedSlotSymbol

-- Exact expected payout of a single spin given the current symbol weights,
-- computed by brute-forcing every reel combination (used for balance tests
-- and future UI display, not just an approximation).
function M.slotExpectedValue()
    return require('game.expedition_slot').slotExpectedValue()
end


-- docs/GAME_DESIGN.md's 귀환 슬롯 section lists repair vouchers (수리권)
-- as one of the reward kinds a slot spin can grant, alongside money. Only
-- the rarest/most valuable combo (STAR-STAR-STAR jackpot, 10% per reel,
-- 0.1% overall) also grants a repair voucher worth 1 durability point.

-- docs/GAME_DESIGN.md's 귀환 슬롯 section also lists "표본 보너스" (sample
-- bonus) as one of the four slot reward kinds, alongside money multiples,
-- repair vouchers. It was the only one of the four
-- still unimplemented. A COMET-COMET-COMET triple (50% per reel, 12.5%
-- overall -- the most common triple, since COMET is the common filler
-- symbol) grants a flat bonus added directly to the current expedition's
-- unbanked sample value. It stacks into
-- run.pendingSampleValue immediately, same as a collected sample, and is
-- confirmed at settlement or forfeited at destruction like any other
-- pending sample value.

-- Item 9/14 (A) hullDurability gap: gear.equippedTotals has additively
-- summed a part's hullDurability effect since item 14's very first slice,
-- and the bundled hull_parts.json pool has carried 9 hullDurability cards
-- since item 9's 24-card expansion, but this function -- the only place
-- run.maxDurability is (re)computed -- never read that total, so every one
-- of those cards was equippable with zero actual effect on the ship's
-- maximum hull points. Kept hull-only (like climbSpeed/sampleSellValue,
-- unlike the category-agnostic (C)/(E)/collisionRadius wrappers) because
-- item 9 explicitly scopes hullDurability's payoff to hull ("선체") gear.
-- Exception: item 12 quantum_flawed's hullDurability -1 drawback on an
-- ENGINE card is the edition's unique cost and must still land on
-- maxDurability. Positive engine-slot hullDurability stays 0.
function M.equippedHullDurabilityBonus(run)
    return expeditionGear.equippedHullDurabilityBonus(M, run)
end

function M.getScoutDurabilityBonus(run)
    return expeditionGear.getScoutDurabilityBonus(M, run)
end

-- Item 2: beginReturn abolished. The returning phase no longer exists;
-- players steer back to Earth during ascending, and proximity triggers
-- settle() automatically (play.lua's earthSettleRadius check).

-- Item 9/14 (A) `money` gap: the last of the original five (A) additive
-- effect types (speed/sampleSellValue/money/climbSpeed/hullDurability) to
-- go unread by any run function -- gear.equippedTotals has summed a part's
-- flat `money` effect since item 14's first slice, and hull_parts.json has
-- carried `money` cards (hull_reserve_tank +2 more) since item 9's
-- expansion, but nothing ever added that total to run.money. Kept hull-only
-- (matching climbSpeed/sampleSellValue/hullDurability/speed's hull-scoped
-- design, since item 9 calls these the "선체(조커형)" combo payoff stats)
-- and applied once per settlement (a flat bonus, not a per-sample/per-tick
-- rate like its (A) siblings) rather than per-sample.
function M.equippedHullMoneyBonus(run)
    return expeditionGear.equippedHullMoneyBonus(M, run)
end

local function settle(run)
    return lifecycle.settle(run)
end
M.settle = settle

-- INBOX 61(24): Returns the last checkpoint position (hub or Earth).
-- After destruction, the ship respawns here instead of always at Earth.
function M.lastCheckpointOrEarth(run)
    return lifecycle.lastCheckpointOrEarth(run)
end

function M.new(options)
    return lifecycle.new(options)
end

-- Equips a hull/engine card (from gear.loadHullParts/loadEngineParts) into
-- run's independent loadout, keeping the convenience run.equippedGear /
-- run.equippedEngineParts arrays (item 10's named lists) in sync with the
-- underlying engine_parts.lua loadout. Returns true, nil on success or
-- false, error-message on failure (full slot / duplicate id), matching
-- engine_parts.equip's own contract.
--
-- Item 9/14 (A) hullDurability wiring: a hull-slot change can shift
-- run.maxDurability (equippedHullDurabilityBonus above). Item 12
-- quantum_flawed engine drawbacks can too, so this recomputes ship
-- stats immediately on every hull OR engine equip/unequip -- unlike
-- climbSpeed/sampleSellValue (pure per-tick/per-sample derived values that
-- read equippedGear live and never need a cached run field refreshed).
-- Before this run's very first launch (phase == "launch", the pre-flight
-- loadout screen) current durability is kept synced to the recomputed max
-- too, since M.launch only refills durability on a RE-launch (settlement/
-- destroyed -> ascending) -- matching M.new's invariant that a fresh,
-- never-yet-launched run always starts with durability == maxDurability.
-- Item 12 farming payoff: a rolled `edition` on an otherwise-raw pool card
-- (JSON effects still at their file values) must actually change the
-- numbers run wrappers consume. rollGearOffer already produces a
-- transformed offer, but shop/hub UI — and any caller that only stamps
-- `edition` onto the pool card — historically fed untransformed effects
-- into climbSpeed / sampleSellValue / hullDurability. Materialize the
-- edition here, once, onto a shallow copy so (a) the input card is never
-- mutated (same contract as gear.applyEditionEffects) and (b) already-
-- transformed offers (rollGearOffer / a previous equip) are not doubled
-- (gated by `editionApplied`).
function M.equipGear(run, category, part)
    return expeditionGear.equipGear(M, run, category, part)
end

-- Unequips by id from the given category; keeps run.equippedGear /
-- run.equippedEngineParts pointed at the (mutated in place) underlying
-- list, same as equipGear above. Hull unequips also recompute ship stats
-- (see equipGear's comment) so removing a hullDurability card shrinks
-- maxDurability back down immediately, clamping current durability down
-- to the new max if it would otherwise exceed it (pre-launch only, same
-- guard as equipGear -- mid-flight durability is never silently reduced
-- by a shop/loadout-only action).
function M.unequipGear(run, category, id)
    return expeditionGear.unequipGear(M, run, category, id)
end

-- Item 9(c): "카드 획득... 과 교체가 잦아지는 루프". With a fixed 6/3-slot
-- loadout cap (game/engine_parts.lua), the only way to try a different
-- combination once slots are full is to free one up -- M.sellGear removes
-- an equipped card from its slot AND refunds money for it in one atomic
-- action (gear.sellValue's rarity/edition-scaled refund), restricted to
-- the settlement/shop phase like every other money-moving action in this
-- module (M.buyDurabilityUpgrade etc.) so it can't be spammed mid-flight for a
-- free money glitch. Returns true, nil on success or false, error-message
-- on failure (wrong phase, unknown id) -- never partially applies (no
-- money change without a successful unequip, and vice versa).
function M.sellGear(run, category, id)
    return expeditionGear.sellGear(M, run, category, id)
end

-- Item 9(c) Earth-shop purchase counterpart to M.sellGear: spend money to
-- occupy a hull/engine slot. Same settlement-only / no-partial-apply
-- contract as sellGear and the existing buy*Upgrade helpers. Item 14(F)
-- shopDiscount applies via M.shopPrice so a trade-license loadout actually
-- cheapens the card that is the shop's main product, not only hull
-- upgrades. Item 7's Earth-shop rule (galaxyExclusive cards are never
-- sold on Earth) is enforced here because this IS that Earth-shop action.
-- Returns true, price on success or false, error-message on failure.
function M.buyGear(run, category, part)
    return expeditionGear.buyGear(M, run, category, part)
end

-- Item 7(a) gap: `world.shopPlanet(galaxy)` has generated a deterministic
-- per-galaxy shop-planet location since the item 7 data-layer slice, and
-- `M.buyGear` (item 9(c)) already lets a player spend money to occupy a
-- slot -- but `M.buyGear` is hard-gated to `run.phase == "settlement"`
-- (the Earth shop) and explicitly REJECTS `galaxyExclusive` parts (item
-- 7(c)'s Earth-only exclusion rule). That left item 7(a)'s actual promise
-- -- "각 은하계의 고정 좌표에 존재하는 상점 행성에서 돈으로 구매" -- with
-- a real-world coordinate (world.shopPlanet) and a real price/equip
-- mechanism (gearModule.buyPrice/M.equipGear), but literally NO run
-- function a shop-planet encounter could call: `buyGear` would refuse both
-- because a shop-planet purchase happens mid-flight (`ascending`, not
-- `settlement`) and item 7(a) never says shop planets are limited to
-- generic (non-exclusive) gear the way Earth is -- only item 7(c) singles
-- out Earth's restriction. This was a documented-acquisition-path-with-no-
-- consumer gap, the same class this lane has repeatedly found and closed
-- for individual effect types.
--
-- Same atomic no-partial-apply / phase-gated / M.shopPrice-discounted
-- contract as `M.buyGear`, but scoped to the in-flight `ascending` phase
-- (when a shop planet can actually be reached) and, unlike `M.buyGear`,
-- does NOT reject `galaxyExclusive` parts -- a shop planet's whole reason
-- to exist per item 7(a) is a physical, in-galaxy location, so it may
-- legitimately sell that galaxy's own exclusive card. Returns
-- `true, price` on success or `false, error-message` on failure.
function M.buyGearFromShopPlanet(run, category, part)
    return expeditionGear.buyGearFromShopPlanet(M, run, category, part)
end

function M.launch(run)
    return lifecycle.launch(run, M.equipGear)
end

-- Item 14(F) shopDiscount wiring: equipped hull/engine parts' shopDiscount
-- effects (already a pure percentage-discount conversion via
-- gear.effectiveShopPrice) reduce a base shop price. Exposed as its own
-- function (not just inlined into each buy* below) so UI/tests can display
-- the discounted price before a purchase, same pattern as
-- M.effectiveSpeed above.
function M.shopPrice(run, basePrice)
    return expeditionGear.shopPrice(M, run, basePrice)
end

-- Upgrade price escalation: base * 1.05^level (user 2026-09-07)
function M.upgradeCost(run, baseCost, level)
    return expeditionUpgrade.upgradeCost(M, run, baseCost, level)
end

function M.buyDurabilityUpgrade(run)
    return expeditionUpgrade.buyDurabilityUpgrade(M, run)
end

-- Sample yield scales the money value of every collected sample (not just durability
-- capacity), giving players a third strategic upgrade axis at EARTH SHOP.
-- Stellar Origin (item 16, 2026-09-05): nebulaField synergy (nebula 3+) applies an
-- additional ×1.5 multiplier on top of the upgrade-derived base.
function M.sampleYieldMultiplier(run)
    return expeditionUpgrade.sampleYieldMultiplier(M, run)
end

function M.buySampleYieldUpgrade(run)
    return expeditionUpgrade.buySampleYieldUpgrade(M, run)
end

-- Steering is the fourth meta upgrade axis named in
-- The steering upgrade scales the ship's left/right
-- steering speed applied while ascending/returning (game/scenes/play.lua),
-- giving players a way to spend money on better planet-collision avoidance
-- rather than capacity or money yield.
-- Item 53a: unified effectiveSpeed replaces equippedHullSpeedBonus,
-- steeringSpeed and effectiveClimbSpeed. One speed for both altitude
-- accumulation and joystick steering.
-- Removed: equippedHullSpeedBonus, steeringSpeed, effectiveClimbSpeed.

-- RCS exhaust: continuous 0–999 speed gradient (user 2026-09-07).
-- t = clamp(effectiveSpeed / 999, 0, 1)
-- white→red (t<0.33) → red→blue (t<0.66) → rainbow HSV (t≥0.66)
-- radius = 1.5 + t * 2.5
function M.rcsVisual(run, time, particleCount)
    return expeditionUpgrade.rcsVisual(M, run, time, particleCount)
end

-- Kept for callers that still want a coarse bucket; derived from 0–999 t.
function M.rcsSpeedLevel(run)
    return expeditionUpgrade.rcsSpeedLevel(M, run)
end

function M.buySteeringUpgrade(run)
    return expeditionUpgrade.buySteeringUpgrade(M, run)
end

-- Dev/admin: free +1 on speed / hull / yield, any phase. No money cost.
function M.adminUpgrade(run, kind)
    return expeditionUpgrade.adminUpgrade(M, run, kind)
end

-- Ship trade-offs expressed as explicit GAINS/LOSSES rows, matching the
-- planet-style-editor tool's numeric format (label + signed value) so the
-- same shape can later describe per-planet-style risk/reward without a
-- separate ad-hoc string format for each source.
function M.shipTradeoff(run, shipId)
    return expeditionUpgrade.shipTradeoff(M, run, shipId)
end

function M.buyShip(run, shipId)
    return expeditionUpgrade.buyShip(M, run, shipId)
end

function M.selectShip(run, shipId)
    return expeditionUpgrade.selectShip(M, run, shipId)
end


-- docs/feedback/INBOX.md's Balatro core-mechanics porting plan item 1
-- ("점진적 시너지/빌드업") requests a multiplicative STREAK bonus for
-- collecting consecutive same-hue-family samples, mirroring a card game's
-- combo scaling. streakCount 0 or 1 is the base x1.0 rate; each additional
-- consecutive same-family sample adds +0.2 (x1.2, x1.4, x1.6, ...).
-- Item 14(B) streakMultiplier wiring: equipped hull/engine parts carrying
-- a streakMultiplier effect raise the per-step growth rate above the base
-- 0.2 (gear.effectiveStreakBonusPerStep is the pure percentage-point
-- conversion; run.equippedGear/run.equippedEngineParts are category-
-- agnostic here, matching item 14 (C)/(E)'s combinedGearList design since
-- a streak-boosting card could plausibly live on either slot type).
function M.streakBonusPerStep(run)
    return expeditionGear.streakBonusPerStep(M, run)
end

-- Stellar Origin (item 16, 2026-09-05): pulsarBurst (pulsar 2+) doubles the
-- final streak multiplier; darkMatter (void 2 + pulsar 2) adds an extra +50%
-- on top of the base computed value. Both are applied AFTER the gear-based
-- per-step bonus so synergy rewards compound correctly with equipped gear.
function M.streakMultiplier(streakCount, run)
    return expeditionGear.streakMultiplier(M, streakCount, run)
end

-- hueKey is the optional hue-family key from world.hueFamily/specimenKind
-- (e.g. "azure"/"ember"/"void"). When provided, consecutive calls with the
-- same hueKey build a streak that multiplies the awarded value on top of
-- the SAMPLE YIELD upgrade; a different hueKey (or no hueKey) resets the
-- streak back to the base rate for that call.
function M.collectSample(run, value, hueKey)
    return expeditionRun.collectSample(M, run, value, hueKey)
end

function M.damage(run, amount)
    return lifecycle.damage(run, amount)
end

-- Item 9's core payoff, now actually wired into gameplay: equipped hull
-- gear's climbSpeed effects (already synergy-multiplied by
-- gear.equippedTotals, see game/gear.lua) stack ON TOP of the run's own
-- climbSpeed (upgrades etc.), rather than replacing it.
--
-- Item 10(b)/9 gap wiring: 7 of the 24 bundled engine_parts.json cards
-- carry a climbSpeed effect (item 10's "상승 가속" propulsion stat), but
-- this function historically only ever read run.equippedGear (hull), so
-- every engine-slot climbSpeed value was validated/loaded/synergy-tagged
-- yet never actually applied to ascent -- silently dead content on nearly
-- a third of the engine pool. The engine-slot total is added as a PLAIN
-- additive bonus (gearModule.aggregateEffects, not equippedTotals) since
-- item 9 explicitly scopes the tag-synergy combo multiplier to hull
-- ("선체(조커형)") parts only; engine climbSpeed stacks alongside the
-- hull synergy-multiplied total rather than being folded into it.
-- Item 9/10 gap wiring: hull-slot climbSpeed already goes through
-- gearModule.equippedTotals, which applies item 9's tag-synergy multiplier
-- (gearModule.tagSynergyMultiplier -- two equipped parts sharing a synergy
-- tag multiply their combined contribution beyond a flat sum, item 12's
-- "irradiated" edition amplifies that multiplier further). The engine-slot
-- climbSpeed total, however, used to go through a plain
-- gearModule.aggregateEffects call with no synergy pass at all -- two
-- engine-slot cards sharing a tag (e.g. bundled engine_fusion_core, an
-- "irradiated" edition candidate specifically for its synergy amplification)
-- got zero combo bonus between themselves, and the irradiated edition could
-- never have any observable effect when rolled on an engine card. Engine
-- climbSpeed now runs through the SAME tagSynergyMultiplier (scoped to the
-- engine-slot list only, so hull and engine synergy pairs never cross-
-- contaminate each other -- a hull/engine pair sharing a tag still
-- contributes nothing, matching item 10(a)'s slot-category independence),
-- Item 53a: unified effectiveSpeed — single speed stat for both altitude
-- accumulation and joystick steering.  Combines:
--   base speed (run.baseSpeed) + steering upgrades
--   + hull gear `speed` (synergy-multiplied via equippedTotals)
--   + engine gear `speed` (synergy-multiplied via tagSynergyMultiplier)
--   + scout ship bonus
function M.effectiveSpeed(run)
    return expeditionGear.effectiveSpeed(M, run)
end

-- Item 9/14 economy-stat gap audit: gear.equippedTotals already combines a
-- part's flat (A) sampleSellValue with the (B) sellMultiplier percentage
-- (additive-sum-then-multiply, see game/gear.lua's M.equippedTotals) into
-- one number, but until this slice nothing in this file ever READ that
-- total -- every bundled sampleSellValue/sellMultiplier hull card (8 of
-- the former, 1 of the latter, per docs/GEAR_SCHEMA.md's item 14 content
-- coverage audit) was equippable but had zero effect on actual money
-- earned. This wrapper is the single source of truth for "how much extra
-- money per sample does the currently equipped hull gear grant".
--
-- Item 10/14 (B) follow-up: sampleSellValue stays hull-only (item 9
-- scopes the (A) additive payoff to hull "조커형" parts, matching
-- climbSpeed/money/speed/hullDurability), but sellMultiplier is
-- category-agnostic — testEngineCardsHaveCategoryAgnosticEffectCoverage
-- and the bundled engine_market_thruster card exist specifically so an
-- engine-slot (B) multiplier scales the hull (A) total. Combining the two
-- via equippedTotals(run.equippedGear) silently dropped engine
-- sellMultiplier; this recomputes the same additive-then-multiply once
-- across hull sampleSellValue + hull/engine sellMultiplier.
function M.effectiveSampleBonus(run)
    return expeditionGear.effectiveSampleBonus(M, run)
end

-- Stellar Origin (item 16, 2026-09-05): supernova (all 4 suits 1+) scales
-- every equipped legendary card's effect values by ×1.5 before summing.
-- This is the synergy-aware equivalent of gearModule.aggregateEffects; the
-- result table has the same shape and is a drop-in replacement for callers
-- that already have access to a `run` (and therefore know the synergy state).
function M.aggregateEffectsWithSynergies(run, parts)
    return expeditionGear.aggregateEffectsWithSynergies(M, run, parts)
end

-- Run-level equippedTotals wrapper that incorporates Stellar Origin synergies.
-- Supernova (all 4 suits 1+) is the only synergy that modifies the raw
-- aggregated effect totals; the tag-synergy multiplier and sellMultiplier
-- combine pass from gear.equippedTotals are preserved exactly.
function M.equippedTotals(run, parts)
    return expeditionGear.equippedTotals(M, run, parts)
end

-- Item 10(b)/14(G) wiring: how many one-shot emergency boost charges the
-- currently equipped engine parts grant this run (gear.boostChargeCount is
-- a pure discrete-count conversion). Actual consumption/UI for spending a
-- charge belongs to play.lua (out of this lane's scope) -- this just
-- exposes the count so that future wiring has a single source of truth.
function M.boostChargeCount(run)
    return expeditionGear.boostChargeCount(M, run)
end

-- Item 10(b)/14(G) boostCharge consumption wiring: boostChargeCount(run)
-- above has always been a pure re-derived total (equipped engine parts'
-- boostCharge effects summed and floored), which -- exactly like
-- rerollCount(run) before M.spendReroll existed -- is meaningless as a
-- per-expedition resource on its own, since nothing could ever actually
-- SPEND a "긴급 부스트/1회성 소모 아이템" charge and see the pool deplete.
-- run.boostsUsed tracks how many of the CURRENT expedition's boost
-- charges have already been spent; M.boostsRemaining(run) is the live
-- boostChargeCount(run) minus that counter (never negative), so
-- re-equipping more boostCharge gear mid-run raises the ceiling
-- immediately, matching rerollsRemaining's exact contract.
-- M.launch resets run.boostsUsed to 0 alongside run.insuranceUsed/
-- run.rerollsUsed.
function M.boostsRemaining(run)
    return expeditionGear.boostsRemaining(M, run)
end

-- Spends one emergency boost charge if any remain. Returns true on
-- success, or false, error-message (never throws) if none remain -- same
-- "atomic, reject-don't-partial-apply" contract as M.spendReroll/
-- M.sellGear/M.equipGear. Actual gameplay effect of spending a boost
-- (a tap-to-boost thrust/altitude burst) remains out of this lane's scope
-- (play.lua) per loop/PROMPT.md -- this establishes the single
-- run-level source of truth a future consumer will read from.
function M.spendBoost(run)
    return expeditionGear.spendBoost(M, run)
end

-- Item 14 (C)/(E) run wiring: gear.chainTriggerCount/rerollCount/
-- effectiveDetectionRadius/autoCollectEnabled have existed as pure
-- gear.lua conversion functions since item 14's first slice, but until
-- now no run-facing wrapper combined them with an actual equipped-gear
-- list (same "최소한의 로더 호출" exception used throughout this file).
-- These are category-agnostic (unlike climbSpeed synergy, which only
-- reads hull, or boostChargeCount, which only reads engine): both
-- run.equippedGear and run.equippedEngineParts count toward the totals,
-- matching item 10's design that hull/engine are independent SLOTS but
-- not independent stat pools for every effect type.
function M.chainTriggerCount(run)
    return expeditionGear.chainTriggerCount(M, run)
end

function M.rerollCount(run)
    return expeditionGear.rerollCount(M, run)
end

-- Item 14(C) rerollBonus consumption wiring: rerollCount(run) above has
-- always been a pure re-derived total (equipped-gear rerollBonus effects
-- summed and floored), which is meaningless as a per-expedition resource
-- on its own -- nothing could ever actually SPEND a "free reroll" and see
-- the pool deplete, the same gap rerollBonus's (C) sibling `luck` never had
-- (luck feeds rollRarity/rollEdition directly, no spend/deplete semantics
-- needed) and `insurance` closed via a one-shot boolean (run.insuranceUsed).
-- run.rerollsUsed tracks how many of the CURRENT expedition's free rerolls
-- have already been spent; M.rerollsRemaining(run) is the live
-- rerollCount(run) minus that counter (never negative), so re-equipping
-- more rerollBonus gear mid-run raises the ceiling immediately without any
-- extra bookkeeping. M.launch resets run.rerollsUsed to 0 alongside
-- run.insuranceUsed, matching the "resets once per expedition" contract.
function M.rerollsRemaining(run)
    return expeditionGear.rerollsRemaining(M, run)
end

-- Spends one free reroll if any remain. Returns true on success, or
-- false, error-message (never throws) if none remain -- same "atomic,
-- reject-don't-partial-apply" contract as M.sellGear/M.equipGear.
function M.spendReroll(run)
    return expeditionGear.spendReroll(M, run)
end

-- Item 14(C) rerollBonus consumption: M.spendReroll(run) above only ever
-- decremented a per-expedition counter with no effect of its own, and
-- M.rollGearOffer(run, pool, rolls) above only ever generated an offer with
-- no gate on an actual reroll budget -- exactly the "counter exists but
-- nothing spends it for its documented effect" gap this lane closed for
-- boostCharge (M.spendBoost) and insurance (M.damage's one-shot gate).
-- M.rerollGearOffer atomically joins the two: it refuses (false +
-- error-message, no state mutated) when M.rerollsRemaining(run) is zero,
-- otherwise it spends exactly one free reroll via M.spendReroll and returns
-- true + the freshly generated offer from M.rollGearOffer. Same
-- reject-don't-partial-apply contract as every other atomic run mutator in
-- this file (M.equipGear/M.sellGear/M.buyGear/M.spendReroll/M.spendBoost).
function M.rerollGearOffer(run, pool, rolls)
    return expeditionGear.rerollGearOffer(M, run, pool, rolls)
end

-- INBOX 61(16): hub-only restock — pay hubRestockCost to re-roll a gear
-- offer at a hub settlement shop. Only allowed when lastVisitedGalaxyId is
-- set (i.e. settled at a hub, not Earth). Pure function: deducts money,
-- returns new offer.
function M.hubRestock(run, pool, rolls)
    return expeditionGear.hubRestock(M, run, pool, rolls)
end

function M.detectionRadius(run, baseRadius)
    return expeditionGear.detectionRadius(M, run, baseRadius)
end

function M.autoCollectEnabled(run)
    return expeditionGear.autoCollectEnabled(M, run)
end

-- Item 14(D) run wiring: gear.effectiveCollisionRadius (percentage shrink
-- of a base hitbox radius) has existed as a pure conversion since item 14's
-- first slice, but -- unlike its (D) sibling `insurance` (wired into
-- M.damage) and its (C)/(E) neighbors above -- never gained a run-facing
-- wrapper. Category-agnostic like chainTrigger/rerollBonus/detectionRadius/
-- autoCollect: both hull and engine slots count toward the total (item 10
-- keeps SLOT capacity independent per category, not every effect's stat
-- pool). Actual collision-detection call sites that would pass a real
-- base hitbox radius live in play.lua/world.lua, out of this lane's scope
-- per loop/PROMPT.md; this establishes the single run-level source of
-- truth a future consumer will read from, same posture as boostChargeCount.
-- Stellar Origin (item 16, 2026-09-05): eventHorizon (void 3+) increases
-- the collection orbit radius by +30%, making sample/moon pickup easier.
-- INBOX item 6 (2026-09-07): changed from collisionRadius −30% to
-- collectOrbitRadius +30% per user request.
function M.collisionRadius(run, baseRadius)
    return expeditionGear.collisionRadius(M, run, baseRadius)
end

-- eventHorizon (void 3+) synergy: +30% collect orbit radius.
function M.collectOrbitRadius(run, baseCollectRadius)
    return expeditionGear.collectOrbitRadius(M, run, baseCollectRadius)
end

-- Item 12's drop RNG (gear.rollRarity / gear.rollEdition), wired into an
-- actual run for the first time. Given a candidate `pool` (from
-- gear.loadHullParts/loadEngineParts) and explicit `rolls` (shop/checkpoint
-- drop code, still out of this lane's scope, decides the real RNG source --
-- same explicit-roll design gear.lua's own functions already use), this:
--   1. resolves a target rarity tier via gear.rollRarity, boosted by the
--      run's own equipped-gear luck total (item 14(C) target #2: "희귀
--      등급... 드롭 가중치를 상위 등급 쪽으로 상향");
--   2. picks a candidate from `pool` matching that tier (falling back to
--      ANY pool card, in `rolls.pick` order, if the tier is empty in this
--      pool -- callers should never have to special-case "no card of that
--      rarity available");
--   3. rolls whether an edition attaches via gear.rollEdition, again boosted
--      by the run's luck total (item 14(C) target #1: "에디션... 부여 확률
--      상향"), and applies it via gear.applyEditionEffects.
-- Returns a plain offer table: { id, name, nameKo, icon, rarity, tags,
-- edition, effects } -- NOT a loadout entry; callers equip it explicitly
-- via M.equipGear once accepted.
function M.rollGearOffer(run, pool, rolls)
    return expeditionGear.rollGearOffer(M, run, pool, rolls)
end

-- Item 8: Partial settlement at a galaxy hub. Converts pending samples
-- into money without ending the flight phase (unlike full Earth return).
-- Does NOT trigger M.equippedHullMoneyBonus (that remains Earth-only).
function M.settleAtHub(run)
    return lifecycle.settleAtHub(run)
end

-- Item 15(c): Earth-shop slot machine galaxy-specific odds tables.
-- Per docs/feedback/INBOX.md item 15: "은하계마다 슬롯머신 내용/오즈/특수
-- 심볼 구성에 변화(변동)를 주어, 어떤 은하계의 체크포인트를 찍고 돌아왔느냐에
-- 따라 지구 상점의 슬롯머신 확률과 보상 테이블이 달라지도록 해 파밍과 탐험의
-- 동기를 극대화한다 (예: 태양계 슬롯은 표준형, 화성/외곽 은하 슬롯은 고배당/
-- 위험부담형 등)".
--
-- Three risk profiles:
--   "solar"  — home solar system; standard balanced odds (mirrors the existing
--               slotWeights so long-time players see no change in familiar play).
--   "fringe"  — nearby outer galaxies; moderate STAR boost, slight COMET cut.
--   "void"    — deep/far galaxies; strong STAR boost, significant COMET cut —
--               high variance, high jackpot, Balatro high-risk-high-reward feel.
--
-- The profile assignment is pure/deterministic from galaxyId hash so the same
-- galaxy always shows the same odds (no per-run RNG, "어떤 은하계의 체크포인트를
-- 찍고" is the wording — galaxy identity, not per-expedition roll).

M.homeGalaxies = { milkyway = true }

-- INBOX 61(25): slot cost/rewards scale with galaxy-grid distance from origin.
-- slotTier = 1 + floor(galaxyDistance / galaxyCellSize). Home/nil → tier 1.
-- Named ids like "galaxy:gx:gy" use hypot(gx, gy) * cellSize so (1,0) is tier 2.
function M.galaxyDistance(run, galaxyId)
    return require('game.expedition_slot').galaxyDistance(run, galaxyId)
end

function M.slotTier(run, galaxyId)
    return require('game.expedition_slot').slotTier(run, galaxyId)
end

function M.slotSpinCostFor(run, galaxyId)
    return require('game.expedition_slot').slotSpinCostFor(run, galaxyId)
end

-- Maps a galaxyId string to one of the three profile names. nil or any
-- known home galaxy ("milkyway") returns "solar". Outer galaxies are
-- assigned "fringe" or "void" via a stable hash of their id (mod 3: 0 ->
-- fringe, 1 -> void, 2 -> fringe again so fringe is twice as likely as
-- void — outer galaxies are mostly fringe-grade with occasional deep-void
-- anomalies, matching the game's tone of gradual risk escalation).
function M.galaxySlotOddsProfile(galaxyId)
    return require('game.expedition_slot').galaxySlotOddsProfile(galaxyId)
end

-- Returns the base slot weight table for a given galaxy. Callers can then
-- apply the luck modifier (see M.earthSlotSpin) on top.
function M.earthSlotWeights(galaxyId)
    return require('game.expedition_slot').earthSlotWeights(galaxyId)
end

-- INBOX 61(35): Compute the effective total weight for a given run + galaxy,
-- including the luck-boosted HARVEST weight. Callers use this to generate
-- uniformly distributed reel rolls in [0, totalWeight - 1].
function M.earthSlotTotalWeight(run, galaxyId)
    return require('game.expedition_slot').earthSlotTotalWeight(run, galaxyId)
end

-- Item 15(c) + Item 14(C) luck: Earth-shop slot spin with per-galaxy odds
-- and luck-boosted STAR weight (item 15 says luck applies to the Earth shop
-- slot's high-payout symbol probability — the third luck target alongside
-- item 14's two original targets: edition-assignment chance and rarity drop
-- weights). Pure function: no state mutation, fully deterministic from its
-- arguments (same design as M.rollGearOffer/M.rollRarity/M.rollEdition).
--
-- `run`: used to read the equipped gear's combined luck bonus (same
--   combinedGearList pattern as every category-agnostic effect).
-- `galaxyId`: nil defaults to the "solar" profile (standard odds).
-- `rolls.reels`: table of 3 pre-rolled integers, each in [0, totalWeight).
--   The caller (shop UI) generates these from love.math.random or any RNG
--   source; earthSlotSpin never calls RNG itself (same convention as
--   rollGearOffer's `rolls` parameter).
--
-- Returns a result table:
--   .symbols        — array of 3 symbol strings (COMET/PLANET/STAR)
--   .reward         — money value of the resulting symbol combination
--   .totalWeight    — total weight used for this spin (for UI's random-roll range)
--   .effectiveStarWeight — the STAR weight after luck boost (for UI preview / tests)
-- Item 15(c) follow-up: per-profile reward tables. Item 15 says
-- "보상 테이블이 달라지도록" (reward TABLE changes, not just odds weights).
-- void is "고배당/위험부담형" so its triple-STAR jackpot scales up; the miss
-- (no-match) floor stays equal-to or lower-than solar so it's a genuine
-- risk trade-off, not a free upgrade. Fringe sits between as a gradient.
--
-- Design: multiply the global slotReward baseline by a profile jackpot
-- multiplier for the triple-STAR case only; other combinations (triple-
-- other, pairs, misses) use the same unscaled table so solar players see
-- no change and void/fringe just pay out bigger jackpots for the rare hit.

-- INBOX (52b): profile-aware reward multiplier for triples.
-- Non-triples and misses use the base slotReward. Triples get scaled
-- by the profile's tripleMultiplier so void pays more on triple hits.

function M.earthSlotSpin(run, galaxyId, rolls)
    return require('game.expedition_slot').earthSlotSpin(run, galaxyId, rolls)
end

-- Item 7(b): Exploring a galaxy hub deterministically drops a specific
-- gear part for that galaxy (100% chance, only once per run).
function M.exploreHub(run, galaxyId, pool, rolls)
    return lifecycle.exploreHub(run, galaxyId, pool, rolls)
end

function M.update(run, dt)
    return expeditionRun.update(M, run, dt)
end

return M
