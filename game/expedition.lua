local M = {}

-- Minimal exception carved out by loop/PROMPT.md: this lane may not touch
-- play.lua/world.lua/i18n.lua, but IS explicitly allowed a "최소한의 로더
-- 호출" to wire game/gear.lua (item 9/13) and game/engine_parts.lua (item
-- 10) into actual run state. requiring these here (rather than in play.lua)
-- keeps that wiring inside this lane's owned files.
local gearModule = require("game.gear")
local enginePartsModule = require("game.engine_parts")

local slotSymbols = { "COMET", "PLANET", "STAR" }
M.slotSymbols = slotSymbols

-- Weighted so rarer symbols carry the bigger payout: COMET is the common
-- filler, PLANET is mid-rare, STAR is the rare jackpot symbol.
local slotWeights = { COMET = 5, PLANET = 4, STAR = 1 }
M.slotWeights = slotWeights

local slotTotalWeight = 0
for _, symbol in ipairs(slotSymbols) do
    slotTotalWeight = slotTotalWeight + slotWeights[symbol]
end
M.slotTotalWeight = slotTotalWeight

function M.slotSymbolProbability(symbol)
    return slotWeights[symbol] / slotTotalWeight
end

local function slotReward(symbols)
    if symbols[1] == symbols[2] and symbols[2] == symbols[3] then
        if symbols[1] == "STAR" then return 75 end
        return 40
    end
    if symbols[1] == symbols[2] or symbols[1] == symbols[3] or symbols[2] == symbols[3] then
        return 15
    end
    return 5
end
M.slotReward = slotReward

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
    local total = 0
    local probabilitySum = 0
    for _, a in ipairs(slotSymbols) do
        for _, b in ipairs(slotSymbols) do
            for _, c in ipairs(slotSymbols) do
                local probability = M.slotSymbolProbability(a)
                    * M.slotSymbolProbability(b)
                    * M.slotSymbolProbability(c)
                total = total + probability * slotReward({ a, b, c })
                probabilitySum = probabilitySum + probability
            end
        end
    end
    return total, probabilitySum
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
local function equippedHullDurabilityBonus(run)
    return (gearModule.equippedTotals(run.equippedGear or {}).hullDurability or 0)
        + gearModule.engineSlotHullDurabilityDrawback(run.equippedEngineParts or {})
end
M.equippedHullDurabilityBonus = equippedHullDurabilityBonus

local function refreshShipStats(run)
    local durabilityBonus = 0
    if run.selectedShipId == "scout" then
        durabilityBonus = run.scoutDurabilityBonus
    end
    run.maxDurability = run.baseDurability + durabilityBonus
        + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
        + equippedHullDurabilityBonus(run)
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
    return gearModule.equippedTotals(run.equippedGear or {}).money or 0
end

local function settle(run)
    run.lastSampleSettlement = run.pendingSampleValue
    local payout = run.lastSampleSettlement + M.equippedHullMoneyBonus(run)
    run.money = run.money + payout
    run.lastSettlement = payout
    run.lastSampleCount = run.sampleCount
    run.lastAltitude = run.maxAltitude
    run.lastNewBest = run.bestAltitude > (run.launchBestAltitude or 0)
    run.pendingSampleValue = 0
    run.sampleCount = 0
    -- Stellar Origin (item 16, 2026-09-05): solarSystem heals 1 durability per
    -- settlement (capped at maxDurability); binaryStar grants +30 money flat.
    local syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    if syn.solarSystem then
        run.durability = math.min(run.maxDurability, run.durability + 1)
    end
    if syn.binaryStar then
        run.money = run.money + 30
    end
    -- Item 15(a): slotOpportunities removed from run state.
    run.phase = "settlement"
end
M.settle = settle

local function destroy(run)
    run.phase = "destroyed"
    run.durability = 0
    run.lastLostSampleCount = run.sampleCount
    run.lastLostSampleValue = run.pendingSampleValue
    run.lastLostAltitude = run.maxAltitude
    run.lastLostNewBest = run.bestAltitude > (run.launchBestAltitude or 0)
    run.sampleCount = 0
    run.pendingSampleValue = 0
    run.sampleStreakCount = 0
    run.sampleStreakFamily = nil
    -- Item 15(a): slotOpportunities removed from run state.
    run.returnDistance = 0
    run.money = 0
    run.lastSettlement = 0
    run.lastSampleSettlement = 0
    run.lastSampleCount = 0
    run.durabilityUpgradeLevel = 0
    run.sampleYieldUpgradeLevel = 0
    run.steeringUpgradeLevel = 0
    run.ownedShips = { starter = true }
    run.selectedShipId = "starter"
    refreshShipStats(run)
    -- Docs/GAME_DESIGN.md's full meta wipe on destruction ("구매한 함선,
    -- 업그레이드... 모두 초기화") extends to equipped gear (item 10): both
    -- slot lists and the underlying loadout reset to empty.
    run.gearLoadout = enginePartsModule.newLoadout()
    run.equippedGear = run.gearLoadout.hull
    run.equippedEngineParts = run.gearLoadout.engine
    run.insuranceUsed = false
    run.rerollsUsed = 0
    run.boostsUsed = 0
    run.hubExplored = {}
    run.lastVisitedGalaxyId = nil
end

function M.new(options)
    options = options or {}
    local baseDurability = options.durability or 3
    local run = {
        phase = "launch",
        hubExplored = {},
        lastVisitedGalaxyId = nil,
        altitude = 0,
        maxAltitude = 0,
        bestAltitude = options.bestAltitude or 0,
        launchBestAltitude = options.bestAltitude or 0,
        lastNewBest = false,
        lastLostNewBest = false,
        durability = baseDurability,
        baseDurability = baseDurability,
        maxDurability = baseDurability,
        durabilityUpgradeAmount = options.durabilityUpgradeAmount or 1,
        durabilityUpgradeCost = options.durabilityUpgradeCost or 75,
        durabilityUpgradeLevel = 0,
        sampleYieldUpgradeAmount = options.sampleYieldUpgradeAmount or 0.25,
        sampleYieldUpgradeCost = options.sampleYieldUpgradeCost or 60,
        sampleYieldUpgradeLevel = 0,
        baseSteeringSpeed = options.steeringSpeed or 55,
        steeringUpgradeAmount = options.steeringUpgradeAmount or 15,
        steeringUpgradeCost = options.steeringUpgradeCost or 65,
        steeringUpgradeLevel = 0,
        scoutShipCost = options.scoutShipCost or 125,
        scoutClimbSpeedBonus = options.scoutClimbSpeedBonus or 10,
        scoutDurabilityBonus = options.scoutDurabilityBonus or -1,
        ownedShips = { starter = true },
        selectedShipId = "starter",
        climbSpeed = options.climbSpeed or 30,
        baseClimbSpeed = options.climbSpeed or 30,
        returnSpeed = options.returnSpeed or 45,
        -- Item 15(a): slotDistance / slotOpportunities / slotRandom removed;
        -- in-flight slot machine abolished. earthSlotSpin (item 15(b)) uses
        -- an explicit rolls parameter supplied by the caller, not a run field.
        returnDistance = 0,
        sampleCount = 0,
        pendingSampleValue = 0,
        sampleStreakCount = 0,
        sampleStreakFamily = nil,
        money = options.money or 0,
        lastSettlement = 0,
        lastSampleSettlement = 0,
        lastSampleCount = 0,
        lastAltitude = 0,
        lastLostSampleCount = 0,
        lastLostSampleValue = 0,
        lastLostAltitude = 0,
        -- Items 9/10/13: independent hull/engine equip-slot lists (item
        -- 10's "run.equippedGear"/"run.equippedEngineParts" wiring),
        -- backed by engine_parts.lua's slot-separation bookkeeping. These
        -- alias the loadout's own arrays (not copies) so equipGear/
        -- unequipGear's in-place mutations stay visible through either name.
        gearLoadout = nil,
        equippedGear = nil,
        equippedEngineParts = nil,
        -- Item 14(D) insurance: whether this run's one-time "파괴 시 1회
        -- 한정 정산 없이 생존" save has already been consumed by M.damage.
        insuranceUsed = false,
        -- Item 14(C) rerollBonus consumption: how many of this expedition's
        -- free rerolls (gearModule.rerollCount's floored equipped total)
        -- have already been spent via M.spendReroll. Reset on M.launch,
        -- same per-expedition-resource lifecycle as insuranceUsed.
        rerollsUsed = 0,
        -- Item 10(b)/14(G) boostCharge consumption: how many of this
        -- expedition's emergency-boost charges (M.boostChargeCount's
        -- floored equipped total) have already been spent via
        -- M.spendBoost. Reset on M.launch, same per-expedition-resource
        -- lifecycle as insuranceUsed/rerollsUsed.
        boostsUsed = 0,
    }
    run.gearLoadout = enginePartsModule.newLoadout()
    run.equippedGear = run.gearLoadout.hull
    run.equippedEngineParts = run.gearLoadout.engine
    return run
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
local function materializeEdition(part)
    if type(part) ~= "table" then return part end
    if not part.edition or part.editionApplied then return part end
    local copy = {}
    for k, v in pairs(part) do copy[k] = v end
    copy.effects = gearModule.applyEditionEffects(part, part.edition)
    copy.editionApplied = true
    return copy
end

function M.equipGear(run, category, part)
    local ok, err = enginePartsModule.equip(run.gearLoadout, category, materializeEdition(part))
    if not ok then return false, err end
    if category == "hull" then
        run.equippedGear = run.gearLoadout.hull
    else
        run.equippedEngineParts = run.gearLoadout.engine
    end
    -- Hull plating AND engine-slot quantum_flawed drawbacks both shift
    -- maxDurability, so every category recomputes immediately.
    refreshShipStats(run)
    if run.phase == "launch" then run.durability = run.maxDurability end
    return true
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
    local removed = enginePartsModule.unequip(run.gearLoadout, category, id)
    if removed then
        if category == "hull" then
            run.equippedGear = run.gearLoadout.hull
        else
            run.equippedEngineParts = run.gearLoadout.engine
        end
        refreshShipStats(run)
        if run.phase == "launch" then
            run.durability = math.min(run.durability, run.maxDurability)
        end
    end
    return removed
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
    if run.phase ~= "settlement" then
        return false, "sellGear: only allowed during the settlement/shop phase"
    end
    local list = category == "hull" and run.equippedGear or run.equippedEngineParts
    local part
    for _, candidate in ipairs(list or {}) do
        if candidate.id == id then
            part = candidate
            break
        end
    end
    if not part then
        return false, string.format("sellGear: '%s' is not equipped in %s", tostring(id), tostring(category))
    end
    local value = gearModule.sellValue(part)
    -- Route through M.unequipGear (not engine_parts.unequip directly) so a
    -- sold hullDurability card immediately shrinks maxDurability the same
    -- way M.unequipGear already does for a loadout-screen unequip. Direct
    -- unequip left run.maxDurability stale after the slot-swap slice.
    local removed = M.unequipGear(run, category, id)
    if not removed then
        return false, "sellGear: unequip failed unexpectedly"
    end
    run.money = run.money + value
    return true, value
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
    if run.phase ~= "settlement" then
        return false, "buyGear: only allowed during the settlement/shop phase"
    end
    if type(part) ~= "table" then
        return false, "buyGear: part must be a table"
    end
    if part.galaxyExclusive then
        return false, "buyGear: galaxy-exclusive parts are not sold on Earth"
    end
    local price = M.shopPrice(run, gearModule.buyPrice(part))
    if run.money < price then
        return false, "buyGear: not enough money"
    end
    local ok, err = M.equipGear(run, category, part)
    if not ok then
        return false, err
    end
    run.money = run.money - price
    return true, price
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
    if run.phase ~= "ascending" then
        return false, "buyGearFromShopPlanet: only allowed while in flight (ascending) near a shop planet"
    end
    if type(part) ~= "table" then
        return false, "buyGearFromShopPlanet: part must be a table"
    end
    local price = M.shopPrice(run, gearModule.buyPrice(part))
    if run.money < price then
        return false, "buyGearFromShopPlanet: not enough money"
    end
    local ok, err = M.equipGear(run, category, part)
    if not ok then
        return false, err
    end
    run.money = run.money - price
    return true, price
end

function M.launch(run)
    if run.phase ~= "launch" and run.phase ~= "settlement" and run.phase ~= "destroyed" then return false end
    run.launchBestAltitude = run.bestAltitude
    run.lastNewBest = false
    run.lastLostNewBest = false
    if run.phase ~= "launch" then
        run.altitude = 0
        run.maxAltitude = 0
        run.durability = run.maxDurability
        run.insuranceUsed = false
        run.rerollsUsed = 0
        run.boostsUsed = 0
        run.returnDistance = 0
        -- Item 15(a): slotOpportunities removed from run state.
        run.sampleCount = 0
        run.pendingSampleValue = 0
        run.sampleStreakCount = 0
        run.sampleStreakFamily = nil
        run.lastSettlement = 0
        run.lastSampleSettlement = 0
        run.lastSampleCount = 0
        run.lastAltitude = 0
        run.lastLostSampleCount = 0
        run.lastLostSampleValue = 0
        run.lastLostAltitude = 0
        -- Item 7(b)/8 hub-explored reset gap: `destroy()` already resets
        -- hubExplored/{} and lastVisitedGalaxyId on full meta wipe, but
        -- `launch()` (safe re-launch from settlement) was not clearing them.
        -- Effect: after a safe return, the player's hubExplored from the
        -- previous expedition persisted into the new run, silently preventing
        -- exploreHub from granting hub drops they legitimately earned on
        -- subsequent expeditions to the same galaxy. The Earth shop slot spin
        -- (item 15) also reads lastVisitedGalaxyId, and that spin happens
        -- DURING the settlement phase (before this launch), so a new
        -- expedition has no "last visited galaxy" yet and must start at nil.
        run.hubExplored = {}
        run.lastVisitedGalaxyId = nil
    end
    run.phase = "ascending"
    return true
end

-- Item 14(F) shopDiscount wiring: equipped hull/engine parts' shopDiscount
-- effects (already a pure percentage-discount conversion via
-- gear.effectiveShopPrice) reduce a base shop price. Exposed as its own
-- function (not just inlined into each buy* below) so UI/tests can display
-- the discounted price before a purchase, same pattern as
-- M.effectiveClimbSpeed/M.steeringSpeed above.
function M.shopPrice(run, basePrice)
    local parts = {}
    for _, part in ipairs(run.equippedGear or {}) do parts[#parts + 1] = part end
    for _, part in ipairs(run.equippedEngineParts or {}) do parts[#parts + 1] = part end
    return gearModule.effectiveShopPrice(basePrice, parts)
end

function M.buyDurabilityUpgrade(run)
    local price = M.shopPrice(run, run.durabilityUpgradeCost)
    if run.phase ~= "settlement" or run.money < price then return false end
    run.money = run.money - price
    run.durabilityUpgradeLevel = run.durabilityUpgradeLevel + 1
    refreshShipStats(run)
    return true
end

-- Sample yield scales the money value of every collected sample (not just durability
-- capacity), giving players a third strategic upgrade axis at EARTH SHOP.
-- Stellar Origin (item 16, 2026-09-05): nebulaField synergy (nebula 3+) applies an
-- additional ×1.5 multiplier on top of the upgrade-derived base.
function M.sampleYieldMultiplier(run)
    local base = 1 + run.sampleYieldUpgradeLevel * run.sampleYieldUpgradeAmount
    local syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    if syn.nebulaField then
        base = base * 1.5
    end
    return base
end

function M.buySampleYieldUpgrade(run)
    local price = M.shopPrice(run, run.sampleYieldUpgradeCost)
    if run.phase ~= "settlement" or run.money < price then return false end
    run.money = run.money - price
    run.sampleYieldUpgradeLevel = run.sampleYieldUpgradeLevel + 1
    return true
end

-- Steering is the fourth meta upgrade axis named in
-- The steering upgrade scales the ship's left/right
-- steering speed applied while ascending/returning (game/scenes/play.lua),
-- giving players a way to spend money on better planet-collision avoidance
-- rather than capacity or money yield.
-- Item 9/14 (A) gap audit: `speed` was still one of the original five
-- additive (A) effect types (docs/GEAR_SCHEMA.md) whose bundled hull cards
-- (7 of them) were equippable but had zero read-side effect on any run
-- value -- exactly the pattern already found and closed for hullDurability
-- (M.equippedHullDurabilityBonus above) and sampleSellValue/sellMultiplier
-- (M.effectiveSampleBonus below). This wrapper is hull-only (matching
-- climbSpeed/sampleSellValue/hullDurability's hull-scoped design, since
-- item 9 calls these the "선체(조커형)" combo payoff stats) and returns the
-- additive steeringSpeed bonus contributed by equipped hull gear.
function M.equippedHullSpeedBonus(run)
    return gearModule.equippedTotals(run.equippedGear or {}).speed or 0
end

-- Item 10(b)/14(G) wiring: engine-part steeringResponsiveness effects
-- multiply the upgrade-derived base steering speed (gear.effectiveSteeringRate
-- is a pure percentage-increase conversion; no equipped engine parts with
-- steeringResponsiveness leaves this identical to the pre-wiring formula).
-- The hull `speed` additive bonus (M.equippedHullSpeedBonus, above) is
-- added to the base+upgrade rate BEFORE the engine percentage multiplier is
-- applied, so hull speed cards and engine steeringResponsiveness cards
-- stack (additive-then-multiplicative), matching every other gear category
-- combination in this run-state layer.
function M.steeringSpeed(run)
    local baseRate = run.baseSteeringSpeed + run.steeringUpgradeLevel * run.steeringUpgradeAmount
        + M.equippedHullSpeedBonus(run)
    return gearModule.effectiveSteeringRate(baseRate, run.equippedEngineParts or {})
end

function M.buySteeringUpgrade(run)
    local price = M.shopPrice(run, run.steeringUpgradeCost)
    if run.phase ~= "settlement" or run.money < price then return false end
    run.money = run.money - price
    run.steeringUpgradeLevel = run.steeringUpgradeLevel + 1
    return true
end

-- Ship trade-offs expressed as explicit GAINS/LOSSES rows, matching the
-- planet-style-editor tool's numeric format (label + signed value) so the
-- same shape can later describe per-planet-style risk/reward without a
-- separate ad-hoc string format for each source.
function M.shipTradeoff(run, shipId)
    if shipId == "scout" then
        return {
            gains = { { label = "SPEED", value = string.format("%+d", run.scoutClimbSpeedBonus) } },
            losses = { { label = "HULL", value = string.format("%+d", run.scoutDurabilityBonus) } },
        }
    end
    return { gains = {}, losses = {} }
end

function M.buyShip(run, shipId)
    if run.phase ~= "settlement" or shipId ~= "scout" or run.ownedShips.scout then
        return false
    end
    local price = M.shopPrice(run, run.scoutShipCost)
    if run.money < price then return false end
    run.money = run.money - price
    run.ownedShips.scout = true
    return true
end

function M.selectShip(run, shipId)
    if run.phase ~= "settlement" or not run.ownedShips[shipId]
        or (shipId ~= "starter" and shipId ~= "scout") then
        return false
    end
    run.selectedShipId = shipId
    refreshShipStats(run)
    return true
end


-- docs/feedback/INBOX.md's Balatro core-mechanics porting plan item 1
-- ("점진적 시너지/빌드업") requests a multiplicative STREAK bonus for
-- collecting consecutive same-hue-family samples, mirroring a card game's
-- combo scaling. streakCount 0 or 1 is the base x1.0 rate; each additional
-- consecutive same-family sample adds +0.2 (x1.2, x1.4, x1.6, ...).
local baseStreakBonusPerStep = 0.2

-- Shared by every category-agnostic (C)/(E)/(B) gear-effect wrapper below:
-- both run.equippedGear (hull) and run.equippedEngineParts (engine) count
-- toward these totals even though item 10 keeps the two SLOT lists
-- independent -- effect types like streakMultiplier/chainTrigger/
-- rerollBonus/detectionRadius/autoCollect aren't restricted to one
-- category in the schema, so a card on either slot should contribute.
local function combinedGearList(run)
    local parts = {}
    for _, part in ipairs(run.equippedGear or {}) do parts[#parts + 1] = part end
    for _, part in ipairs(run.equippedEngineParts or {}) do parts[#parts + 1] = part end
    return parts
end

-- Item 14(B) streakMultiplier wiring: equipped hull/engine parts carrying
-- a streakMultiplier effect raise the per-step growth rate above the base
-- 0.2 (gear.effectiveStreakBonusPerStep is the pure percentage-point
-- conversion; run.equippedGear/run.equippedEngineParts are category-
-- agnostic here, matching item 14 (C)/(E)'s combinedGearList design since
-- a streak-boosting card could plausibly live on either slot type).
function M.streakBonusPerStep(run)
    if not run then return baseStreakBonusPerStep end
    return gearModule.effectiveStreakBonusPerStep(baseStreakBonusPerStep, combinedGearList(run))
end

-- Stellar Origin (item 16, 2026-09-05): pulsarBurst (pulsar 2+) doubles the
-- final streak multiplier; darkMatter (void 2 + pulsar 2) adds an extra +50%
-- on top of the base computed value. Both are applied AFTER the gear-based
-- per-step bonus so synergy rewards compound correctly with equipped gear.
function M.streakMultiplier(streakCount, run)
    if not streakCount or streakCount <= 1 then return 1 end
    local base = 1 + (streakCount - 1) * M.streakBonusPerStep(run)
    if run then
        local syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
        if syn.pulsarBurst then
            base = base * 2
        end
        if syn.darkMatter then
            base = base * 1.5
        end
    end
    return base
end

-- hueKey is the optional hue-family key from world.hueFamily/specimenKind
-- (e.g. "azure"/"ember"/"void"). When provided, consecutive calls with the
-- same hueKey build a streak that multiplies the awarded value on top of
-- the SAMPLE YIELD upgrade; a different hueKey (or no hueKey) resets the
-- streak back to the base rate for that call.
function M.collectSample(run, value, hueKey)
    if run.phase ~= "ascending" or type(value) ~= "number" or value <= 0 then return false end
    if hueKey ~= nil and hueKey == run.sampleStreakFamily then
        run.sampleStreakCount = run.sampleStreakCount + 1
    else
        run.sampleStreakCount = 1
    end
    run.sampleStreakFamily = hueKey
    local streakMultiplier = M.streakMultiplier(run.sampleStreakCount, run)
    -- Item 9/14: equipped hull gear's flat sampleSellValue+sellMultiplier
    -- bonus (M.effectiveSampleBonus, already synergy-scaled by
    -- gear.equippedTotals) is added AFTER the yield/streak multipliers are
    -- applied to the base value, matching insurance/collisionRadius's
    -- posture of "gear modifies the final resolved quantity" rather than
    -- being folded into the multiplier chain itself.
    local awarded = math.floor(value * M.sampleYieldMultiplier(run) * streakMultiplier + 0.5)
        + M.effectiveSampleBonus(run)
    -- Item 14(C) chainTrigger consumption gap: M.chainTriggerCount(run) had
    -- existed only as a stateless re-derived count since the (C)/(E) run
    -- wiring slice -- nothing ever actually consumed it. Per item 14's own
    -- description ("특정 조건마다 다른 장착 카드 효과 재발동, 발라트로
    -- Blueprint/Brainstorm 컨셉"), the concrete payoff wired here is
    -- re-applying this same sample collection's awarded value once per
    -- chainTrigger point (1 base application + N retriggers), without
    -- creating additional collection events (sampleCount/streak state
    -- still advance exactly once per collectSample call).
    local retriggers = M.chainTriggerCount(run)
    if retriggers > 0 then
        awarded = awarded * (1 + retriggers)
    end
    run.sampleCount = run.sampleCount + 1
    run.pendingSampleValue = run.pendingSampleValue + awarded
    return true, awarded, streakMultiplier, retriggers
end

function M.damage(run, amount)
    if (run.phase ~= "ascending" and run.phase ~= "returning") or type(amount) ~= "number" or amount <= 0 then
        return false
    end
    run.durability = math.max(0, run.durability - amount)
    if run.durability == 0 then
        -- Item 14(D) insurance wiring: "파괴 시 1회 한정 정산 없이 생존" —
        -- an equipped part with a positive `insurance` total (already a
        -- pure boolean gate via gear.hasInsurance) consumes ONE save per
        -- run instead of triggering the full meta wipe. run.insuranceUsed
        -- tracks whether this run's single save has already been spent, so
        -- a second lethal hit destroys normally even with insurance gear
        -- still equipped. combinedGearList(run) unions equippedGear +
        -- equippedEngineParts so an ENGINE-slot insurance part (e.g.
        -- engine_escape_pod_thruster) saves a run exactly like a hull one,
        -- matching every other category-agnostic effect in this file.
        if not run.insuranceUsed and gearModule.hasInsurance(combinedGearList(run)) then
            run.insuranceUsed = true
            run.durability = 1
            return false
        end
        destroy(run)
        return true
    end
    return false
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
-- mirroring gearModule.equippedTotals's own multiply-only-climbSpeed shape
-- without pulling in equippedTotals's other hull-only totals.
function M.effectiveClimbSpeed(run)
    local gearTotals = gearModule.equippedTotals(run.equippedGear or {})
    local engineParts = run.equippedEngineParts or {}
    local engineClimbRaw = gearModule.aggregateEffects(engineParts).climbSpeed or 0
    local engineClimb = engineClimbRaw * gearModule.tagSynergyMultiplier(engineParts)
    local shipBonus = run.selectedShipId == "scout" and run.scoutClimbSpeedBonus or 0
    return run.climbSpeed + shipBonus + (gearTotals.climbSpeed or 0) + engineClimb
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
    local hullAdditive = gearModule.aggregateEffects(run.equippedGear or {}).sampleSellValue or 0
    if hullAdditive == 0 then return 0 end
    local sellMult = gearModule.totalEffect(combinedGearList(run), "sellMultiplier")
    return hullAdditive * (1 + sellMult / 100)
end

-- Stellar Origin (item 16, 2026-09-05): supernova (all 4 suits 1+) scales
-- every equipped legendary card's effect values by ×1.5 before summing.
-- This is the synergy-aware equivalent of gearModule.aggregateEffects; the
-- result table has the same shape and is a drop-in replacement for callers
-- that already have access to a `run` (and therefore know the synergy state).
function M.aggregateEffectsWithSynergies(run, parts)
    local syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    local totals = {}
    for _, part in ipairs(parts) do
        local scale = (syn.supernova and part.rarity == "legendary") and 1.5 or 1
        for _, effect in ipairs(part.effects) do
            totals[effect.type] = (totals[effect.type] or 0) + effect.value * scale
        end
    end
    return totals
end

-- Run-level equippedTotals wrapper that incorporates Stellar Origin synergies.
-- Supernova (all 4 suits 1+) is the only synergy that modifies the raw
-- aggregated effect totals; the tag-synergy multiplier and sellMultiplier
-- combine pass from gear.equippedTotals are preserved exactly.
function M.equippedTotals(run, parts)
    local combined = parts or combinedGearList(run)
    local totals = M.aggregateEffectsWithSynergies(run, combined)
    local multiplier = gearModule.tagSynergyMultiplier(combined)
    if totals.climbSpeed then
        totals.climbSpeed = totals.climbSpeed * multiplier
    end
    totals.synergyMultiplier = multiplier
    if totals.sellMultiplier and totals.sampleSellValue then
        totals.sampleSellValue = totals.sampleSellValue * (1 + totals.sellMultiplier / 100)
    end
    return totals
end

-- Item 10(b)/14(G) wiring: how many one-shot emergency boost charges the
-- currently equipped engine parts grant this run (gear.boostChargeCount is
-- a pure discrete-count conversion). Actual consumption/UI for spending a
-- charge belongs to play.lua (out of this lane's scope) -- this just
-- exposes the count so that future wiring has a single source of truth.
function M.boostChargeCount(run)
    return gearModule.boostChargeCount(run.equippedEngineParts or {})
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
    local remaining = M.boostChargeCount(run) - (run.boostsUsed or 0)
    if remaining < 0 then remaining = 0 end
    return remaining
end

-- Spends one emergency boost charge if any remain. Returns true on
-- success, or false, error-message (never throws) if none remain -- same
-- "atomic, reject-don't-partial-apply" contract as M.spendReroll/
-- M.sellGear/M.equipGear. Actual gameplay effect of spending a boost
-- (a tap-to-boost thrust/altitude burst) remains out of this lane's scope
-- (play.lua) per loop/PROMPT.md -- this establishes the single
-- run-level source of truth a future consumer will read from.
function M.spendBoost(run)
    if M.boostsRemaining(run) <= 0 then
        return false, "no boost charges remaining"
    end
    run.boostsUsed = (run.boostsUsed or 0) + 1
    return true
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
    return gearModule.chainTriggerCount(combinedGearList(run))
end

function M.rerollCount(run)
    return gearModule.rerollCount(combinedGearList(run))
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
    local remaining = M.rerollCount(run) - (run.rerollsUsed or 0)
    if remaining < 0 then remaining = 0 end
    return remaining
end

-- Spends one free reroll if any remain. Returns true on success, or
-- false, error-message (never throws) if none remain -- same "atomic,
-- reject-don't-partial-apply" contract as M.sellGear/M.equipGear.
function M.spendReroll(run)
    if M.rerollsRemaining(run) <= 0 then
        return false, "no free rerolls remaining"
    end
    run.rerollsUsed = (run.rerollsUsed or 0) + 1
    return true
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
    if M.rerollsRemaining(run) <= 0 then
        return false, "rerollGearOffer: no free rerolls remaining"
    end
    local offer = M.rollGearOffer(run, pool, rolls)
    if not offer then
        return false, "rerollGearOffer: pool produced no offer"
    end
    local ok, err = M.spendReroll(run)
    if not ok then
        return false, err
    end
    return true, offer
end

function M.detectionRadius(run, baseRadius)
    return gearModule.effectiveDetectionRadius(baseRadius, combinedGearList(run))
end

function M.autoCollectEnabled(run)
    return gearModule.autoCollectEnabled(combinedGearList(run))
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
-- Stellar Origin (item 16, 2026-09-05): eventHorizon (void 3+) adds an extra
-- −30 percentage-point collisionRadius reduction on top of any equipped gear.
-- Since effectiveCollisionRadius reads totalEffect(parts, "collisionRadius")
-- as an additive percentage, we inject a synthetic extra-30 by scaling the
-- base radius by the combined (gear + synergy) percentage.
function M.collisionRadius(run, baseRadius)
    local syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    local extraPct = syn.eventHorizon and 30 or 0
    local combined = combinedGearList(run)
    local gearPct = gearModule.totalEffect(combined, "collisionRadius")
    local totalPct = gearPct + extraPct
    local radius = baseRadius * (1 - totalPct / 100)
    if radius < 0 then radius = 0 end
    return radius
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
    rolls = rolls or {}
    -- luck (item 14(C)) is category-agnostic like chainTrigger/rerollBonus/
    -- detectionRadius/autoCollect above -- an ENGINE-slot luck card (e.g.
    -- the bundled engine_probability_core) must contribute to drop-RNG
    -- luck exactly like a hull-slot one. combinedGearList(run) is the same
    -- hull+engine union every other category-agnostic wrapper in this file
    -- already uses.
    local luckBonus = gearModule.totalLuckBonus(combinedGearList(run))
    local targetRarity = gearModule.rollRarity(rolls.rarity or 0, luckBonus)

    local matching = {}
    for _, part in ipairs(pool) do
        if part.rarity == targetRarity then matching[#matching + 1] = part end
    end
    local candidates = #matching > 0 and matching or pool
    if #candidates == 0 then return nil end
    local idx = math.floor((rolls.pick or 0) * #candidates) + 1
    if idx > #candidates then idx = #candidates end
    if idx < 1 then idx = 1 end
    local part = candidates[idx]

    local edition = gearModule.rollEdition(part, rolls.editionChance or 1, rolls.editionPick or 0, luckBonus)
    local effects = gearModule.applyEditionEffects(part, edition)

    return {
        id = part.id,
        name = part.name,
        nameKo = part.nameKo,
        icon = part.icon,
        rarity = part.rarity,
        tags = part.tags,
        edition = edition,
        effects = effects,
        -- editionApplied gates M.equipGear's materializeEdition so a
        -- shop/hub UI that equips this offer as-is does not double-apply
        -- crystallized / quantum_flawed / refined.
        editionApplied = edition ~= nil,
    }
end

-- Item 8: Partial settlement at a galaxy hub. Converts pending samples
-- into money without ending the flight phase (unlike full Earth return).
-- Does NOT trigger M.equippedHullMoneyBonus (that remains Earth-only).
function M.settleAtHub(run)
    local payout = run.pendingSampleValue
    if payout > 0 then
        run.money = run.money + payout
        run.pendingSampleValue = 0
        return payout
    end
    return 0
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

M.earthSlotOddsProfiles = {
    solar  = { COMET = 5, PLANET = 4, STAR = 1 },
    fringe = { COMET = 4, PLANET = 4, STAR = 2 },
    void   = { COMET = 3, PLANET = 4, STAR = 3 },
}
M.homeGalaxies = { milkyway = true }

-- Maps a galaxyId string to one of the three profile names. nil or any
-- known home galaxy ("milkyway") returns "solar". Outer galaxies are
-- assigned "fringe" or "void" via a stable hash of their id (mod 3: 0 ->
-- fringe, 1 -> void, 2 -> fringe again so fringe is twice as likely as
-- void — outer galaxies are mostly fringe-grade with occasional deep-void
-- anomalies, matching the game's tone of gradual risk escalation).
function M.galaxySlotOddsProfile(galaxyId)
    if not galaxyId or M.homeGalaxies[galaxyId] then
        return "solar"
    end
    local h = 0
    for i = 1, #galaxyId do
        h = (h * 31 + string.byte(galaxyId, i)) % 2147483647
    end
    local bucket = h % 3
    if bucket == 1 then return "void" end
    return "fringe"
end

-- Returns the base slot weight table for a given galaxy. Callers can then
-- apply the luck modifier (see M.earthSlotSpin) on top.
function M.earthSlotWeights(galaxyId)
    local profile = M.galaxySlotOddsProfile(galaxyId)
    local base = M.earthSlotOddsProfiles[profile]
    -- Return a copy so callers can safely modify without corrupting the table.
    return { COMET = base.COMET, PLANET = base.PLANET, STAR = base.STAR }
end

-- Item 15(c) + Item 14(C) luck: Earth-shop slot spin with per-galaxy odds
-- and luck-boosted STAR weight (item 15 says luck applies to the Earth shop
-- slot's high-payout symbol probability — the third luck target alongside
-- item 14's two original targets: edition-assignment chance and rarity drop
-- weights). Pure function: no state mutation, fully deterministic from its
-- arguments (same design as M.rollGearOffer/M.rollRarity/M.rollEdition).
--
-- `run`: used to read the equipped gear's combined luck bonus (same
--   combinedGearList pattern as every other category-agnostic effect).
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
M.earthSlotRewardMultipliers = {
    solar  = { tripleSTAR = 1.0 },
    fringe = { tripleSTAR = 1.5 },
    void   = { tripleSTAR = 2.0 },
}

-- Profile-aware reward function used by earthSlotSpin. Falls back to the
-- global slotReward for non-STAR triples and mismatches; the triple-STAR
-- jackpot is scaled by the profile multiplier so the risk/reward shape
-- changes meaningfully between solar/fringe/void.
local function earthSlotReward(symbols, profile)
    local isTriple = (symbols[1] == symbols[2] and symbols[2] == symbols[3])
    if isTriple and symbols[1] == "STAR" then
        local mults = M.earthSlotRewardMultipliers[profile or "solar"]
        local mult = (mults and mults.tripleSTAR) or 1.0
        -- Global STAR×3 jackpot is 75; scale by profile multiplier.
        return math.floor(75 * mult)
    end
    return slotReward(symbols)
end

function M.earthSlotSpin(run, galaxyId, rolls)
    local profile = M.galaxySlotOddsProfile(galaxyId)
    local weights = M.earthSlotWeights(galaxyId)
    -- Item 14(C) luck: boost STAR weight by the equipped gear's luck total.
    -- totalLuckBonus returns a fraction (e.g. 0.5 for 50 luck points);
    -- multiply STAR's base weight by (1 + luckBonus) so +50% luck gives
    -- +50% more STAR weight, same percentage-scaling as rollRarity/rollEdition.
    local luckBonus = gearModule.totalLuckBonus(combinedGearList(run))
    local effectiveStarWeight = weights.STAR * (1 + luckBonus)
    weights.STAR = effectiveStarWeight
    local total = weights.COMET + weights.PLANET + weights.STAR
    -- Resolve each reel: iterate slotSymbols in their canonical order
    -- (COMET -> PLANET -> STAR) with cumulative weight so the same roll
    -- produces the same symbol regardless of profile (only the thresholds
    -- move, not the symbol ordering).
    local reelRolls = (rolls and rolls.reels) or { 0, 0, 0 }
    local symbols = {}
    for _, roll in ipairs(reelRolls) do
        local cumulative = 0
        local chosen = slotSymbols[#slotSymbols]
        for _, sym in ipairs(slotSymbols) do
            cumulative = cumulative + weights[sym]
            if roll < cumulative then
                chosen = sym
                break
            end
        end
        symbols[#symbols + 1] = chosen
    end
    return {
        symbols = symbols,
        reward = earthSlotReward(symbols, profile),
        totalWeight = total,
        effectiveStarWeight = effectiveStarWeight,
        -- Item 15(c) follow-up: expose the active profile so UI can show
        -- which risk tier is in play (e.g. "VOID ODDS" badge in the shop).
        rewardProfile = profile,
    }
end

-- Item 7(b): Exploring a galaxy hub deterministically drops a specific
-- gear part for that galaxy (100% chance, only once per run).
function M.exploreHub(run, galaxyId, pool, rolls)
    if run.hubExplored[galaxyId] then
        return nil
    end
    run.hubExplored[galaxyId] = true
    -- Item 15(c): record the most-recently-explored hub galaxy so the
    -- Earth shop slot machine knows which odds profile to use on
    -- settlement. Always updated (any non-nil galaxyId overrides the
    -- previous value) because the player's last hub visit determines the
    -- active profile -- multiple hub visits in one expedition use the
    -- most recent one, same design as lastVisitedGalaxyId's only consumer
    -- (the Earth shop slot spin on next settlement).
    run.lastVisitedGalaxyId = galaxyId

    local part = gearModule.galaxySpecificGear(pool, galaxyId)
    if not part then return nil end

    -- Item 7(b)/12: the confirmed CARD is guaranteed (no rarity roll), but
    -- the edition layer (item 12B) and luck's edition-chance boost (item 14C
    -- target #1) must still apply when the caller supplies deterministic
    -- rolls. Same pure-function convention as earthSlotSpin/rollGearOffer:
    -- the caller passes love.math.random() pairs; we never call RNG directly.
    -- If rolls is nil (legacy callers / headless tests), edition stays nil.
    local edition = nil
    local effects = part.effects
    if rolls then
        local luckBonus = gearModule.totalLuckBonus(combinedGearList(run))
        edition = gearModule.rollEdition(
            part,
            rolls.editionChance or 1,
            rolls.editionPick    or 0,
            luckBonus
        )
        if edition then
            effects = gearModule.applyEditionEffects(part, edition)
        end
    end

    return {
        id = part.id,
        name = part.name,
        nameKo = part.nameKo,
        icon = part.icon,
        rarity = part.rarity,
        tags = part.tags,
        edition = edition,
        effects = effects,
        editionApplied = (edition ~= nil),
    }
end

function M.update(run, dt)
    if dt <= 0 then return end

    -- Item 2: returning phase abolished. Only ascending drives altitude.
    if run.phase ~= "ascending" then return end

    run.altitude = run.altitude + M.effectiveClimbSpeed(run) * dt
    run.maxAltitude = math.max(run.maxAltitude, run.altitude)
    run.bestAltitude = math.max(run.bestAltitude, run.altitude)
end

return M
