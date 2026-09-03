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

local function spinSlot(run)
    local symbols = {}
    for reel = 1, 3 do
        symbols[reel] = weightedSlotSymbol(run.slotRandom(slotTotalWeight))
    end
    return symbols, slotReward(symbols)
end

-- docs/GAME_DESIGN.md's 귀환 슬롯 section lists repair vouchers (수리권)
-- as one of the reward kinds a slot spin can grant, alongside money. Only
-- the rarest/most valuable combo (STAR-STAR-STAR jackpot, 10% per reel,
-- 0.1% overall) also grants a repair voucher worth 1 durability point.
local function slotRepairVoucher(symbols)
    if symbols[1] == "STAR" and symbols[2] == "STAR" and symbols[3] == "STAR" then
        return 1
    end
    return 0
end
M.slotRepairVoucher = slotRepairVoucher

-- docs/GAME_DESIGN.md's 귀환 슬롯 section also lists "다음 원정 연료 보너스"
-- (next-expedition fuel bonus) as one of the reward kinds a slot spin can
-- grant, alongside money and repair vouchers. A PLANET-PLANET-PLANET
-- triple (40% per reel, 6.4% overall -- rarer than a mismatched-symbol
-- payout but far more common than the STAR jackpot) grants a fuel bonus.
-- Unlike the repair voucher, this bonus cannot help the current, already
-- fuel-empty expedition; it is banked at safe settlement and applied to
-- the *next* launch's starting fuel instead.
local slotFuelBonusAmount = 15
M.slotFuelBonusAmount = slotFuelBonusAmount

local function slotFuelBonus(symbols)
    if symbols[1] == "PLANET" and symbols[2] == "PLANET" and symbols[3] == "PLANET" then
        return slotFuelBonusAmount
    end
    return 0
end
M.slotFuelBonus = slotFuelBonus

-- docs/GAME_DESIGN.md's 귀환 슬롯 section also lists "표본 보너스" (sample
-- bonus) as one of the four slot reward kinds, alongside money multiples,
-- repair vouchers and the fuel bonus above. It was the only one of the four
-- still unimplemented. A COMET-COMET-COMET triple (50% per reel, 12.5%
-- overall -- the most common triple, since COMET is the common filler
-- symbol) grants a flat bonus added directly to the current expedition's
-- unbanked sample value. Unlike the fuel bonus (which cannot help the
-- already fuel-empty current expedition and must be banked for next
-- launch), a sample bonus can still help this expedition: it stacks into
-- run.pendingSampleValue immediately, same as a collected sample, and is
-- confirmed at settlement or forfeited at destruction like any other
-- pending sample value.
local slotSampleBonusAmount = 25
M.slotSampleBonusAmount = slotSampleBonusAmount

local function slotSampleBonus(symbols)
    if symbols[1] == "COMET" and symbols[2] == "COMET" and symbols[3] == "COMET" then
        return slotSampleBonusAmount
    end
    return 0
end
M.slotSampleBonus = slotSampleBonus

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
    local fuelBonus = 0
    local durabilityBonus = 0
    if run.selectedShipId == "scout" then
        fuelBonus = run.scoutFuelBonus
        durabilityBonus = run.scoutDurabilityBonus
    end
    run.maxFuel = run.baseFuel + fuelBonus + run.fuelUpgradeLevel * run.fuelUpgradeAmount
    run.maxDurability = run.baseDurability + durabilityBonus
        + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
        + equippedHullDurabilityBonus(run)
end

local function slotCount(distance, slotDistance)
    if distance <= 0 then return 0 end
    return math.ceil(distance / slotDistance)
end

-- Item 10(b)/14(G) wiring: engine-part fuelEfficiency effects (already a
-- pure conversion in gear.effectiveFuelBurnRate) reduce the burn rate used
-- for this forecast, same "최소한의 로더 호출" exception used for the
-- climbSpeed synergy wiring above. No equipped engine parts (or none with
-- fuelEfficiency) leaves run.fuelBurnRate unchanged.
function M.effectiveFuelBurnRate(run)
    return gearModule.effectiveFuelBurnRate(run.fuelBurnRate, run.equippedEngineParts or {})
end

function M.launchForecast(run, maxFuel)
    local forecastFuel = maxFuel or run.maxFuel
    local burnRate = M.effectiveFuelBurnRate(run)
    if forecastFuel <= 0 or burnRate <= 0 or run.climbSpeed <= 0 then return 0, 0 end
    local altitude = forecastFuel / burnRate * run.climbSpeed
    return altitude, slotCount(altitude, run.slotDistance)
end

-- Fuel is no longer a flight constraint. These stay as no-ops so older
-- call sites (joystick extra-distance burn) compile without draining the
-- tank or forcing a return.
function M.maneuverFuel(run, extraDistance)
    return 0
end

function M.burnManeuverFuel(run, extraDistance)
    return 0
end

-- Safe return is now an explicit action (tests / future player input),
-- not a fuel-empty side effect.
function M.beginReturn(run)
    if not run or run.phase ~= "ascending" then return false end
    run.phase = "returning"
    run.returnDistance = run.maxAltitude
    run.slotOpportunities = slotCount(run.returnDistance, run.slotDistance)
    return true
end

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
    run.lastSlotSettlement = run.pendingSlotReward
    local payout = run.lastSampleSettlement + run.lastSlotSettlement + M.equippedHullMoneyBonus(run)
    run.money = run.money + payout
    run.lastSettlement = payout
    run.lastSampleCount = run.sampleCount
    run.lastSlotSpinsCount = run.slotSpins
    run.lastAltitude = run.maxAltitude
    run.lastNewBest = run.bestAltitude > (run.launchBestAltitude or 0)
    run.bankedFuelBonus = run.pendingFuelBonus
    run.pendingFuelBonus = 0
    run.pendingSampleValue = 0
    run.pendingSlotReward = 0
    run.sampleCount = 0
    run.slotOpportunities = 0
    run.phase = "settlement"
end

local function destroy(run)
    run.phase = "destroyed"
    run.fuel = 0
    run.durability = 0
    run.lastLostSampleCount = run.sampleCount
    run.lastLostSampleValue = run.pendingSampleValue
    run.lastLostSlotSpinsCount = run.slotSpins
    run.lastLostSlotValue = run.pendingSlotReward
    run.lastLostAltitude = run.maxAltitude
    run.lastLostNewBest = run.bestAltitude > (run.launchBestAltitude or 0)
    run.sampleCount = 0
    run.pendingSampleValue = 0
    run.sampleStreakCount = 0
    run.sampleStreakFamily = nil
    run.pendingSlotReward = 0
    run.slotOpportunities = 0
    run.slotSpins = 0
    run.lastSlotSymbols = nil
    run.lastSlotReward = 0
    run.lastSlotRepair = 0
    run.lastSlotFuelBonus = 0
    run.lastSlotSampleBonus = 0
    run.pendingFuelBonus = 0
    run.bankedFuelBonus = 0
    run.returnDistance = 0
    run.money = 0
    run.lastSettlement = 0
    run.lastSampleSettlement = 0
    run.lastSlotSettlement = 0
    run.lastSampleCount = 0
    run.lastSlotSpinsCount = 0
    run.fuelUpgradeLevel = 0
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
    run.hubExplored = {}
end

function M.new(options)
    options = options or {}
    local baseFuel = options.fuel or 100
    local baseDurability = options.durability or 3
    local run = {
        phase = "launch",
        hubExplored = {},
        altitude = 0,
        maxAltitude = 0,
        bestAltitude = options.bestAltitude or 0,
        launchBestAltitude = options.bestAltitude or 0,
        lastNewBest = false,
        lastLostNewBest = false,
        fuel = baseFuel,
        baseFuel = baseFuel,
        maxFuel = baseFuel,
        durability = baseDurability,
        baseDurability = baseDurability,
        maxDurability = baseDurability,
        fuelUpgradeAmount = options.fuelUpgradeAmount or 20,
        fuelUpgradeCost = options.fuelUpgradeCost or 50,
        fuelUpgradeLevel = 0,
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
        scoutFuelBonus = options.scoutFuelBonus or 40,
        scoutDurabilityBonus = options.scoutDurabilityBonus or -1,
        ownedShips = { starter = true },
        selectedShipId = "starter",
        fuelBurnRate = options.fuelBurnRate or 5,
        climbSpeed = options.climbSpeed or 30,
        baseClimbSpeed = options.climbSpeed or 30,
        returnSpeed = options.returnSpeed or 45,
        slotDistance = options.slotDistance or 100,
        returnDistance = 0,
        slotOpportunities = 0,
        slotSpins = 0,
        slotRandom = options.slotRandom or math.random,
        lastSlotSymbols = nil,
        lastSlotReward = 0,
        lastSlotRepair = 0,
        lastSlotFuelBonus = 0,
        lastSlotSampleBonus = 0,
        pendingFuelBonus = 0,
        bankedFuelBonus = 0,
        sampleCount = 0,
        pendingSampleValue = 0,
        sampleStreakCount = 0,
        sampleStreakFamily = nil,
        pendingSlotReward = 0,
        money = options.money or 0,
        lastSettlement = 0,
        lastSampleSettlement = 0,
        lastSlotSettlement = 0,
        lastSampleCount = 0,
        lastSlotSpinsCount = 0,
        lastAltitude = 0,
        lastLostSampleCount = 0,
        lastLostSampleValue = 0,
        lastLostSlotSpinsCount = 0,
        lastLostSlotValue = 0,
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
-- module (M.buyFuelUpgrade etc.) so it can't be spammed mid-flight for a
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
-- cheapens the card that is the shop's main product, not only fuel/hull
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

function M.launch(run)
    if run.phase ~= "launch" and run.phase ~= "settlement" and run.phase ~= "destroyed" then return false end
    run.launchBestAltitude = run.bestAltitude
    run.lastNewBest = false
    run.lastLostNewBest = false
    if run.phase ~= "launch" then
        run.altitude = 0
        run.maxAltitude = 0
        run.fuel = run.maxFuel + (run.bankedFuelBonus or 0)
        run.bankedFuelBonus = 0
        run.durability = run.maxDurability
        run.insuranceUsed = false
        run.rerollsUsed = 0
        run.boostsUsed = 0
        run.returnDistance = 0
        run.slotOpportunities = 0
        run.slotSpins = 0
        run.lastSlotSymbols = nil
        run.lastSlotReward = 0
        run.lastSlotRepair = 0
        run.lastSlotFuelBonus = 0
        run.lastSlotSampleBonus = 0
        run.pendingFuelBonus = 0
        run.sampleCount = 0
        run.pendingSampleValue = 0
        run.sampleStreakCount = 0
        run.sampleStreakFamily = nil
        run.pendingSlotReward = 0
        run.lastSettlement = 0
        run.lastSampleSettlement = 0
        run.lastSlotSettlement = 0
        run.lastSampleCount = 0
        run.lastSlotSpinsCount = 0
        run.lastAltitude = 0
        run.lastLostSampleCount = 0
        run.lastLostSampleValue = 0
        run.lastLostSlotSpinsCount = 0
        run.lastLostSlotValue = 0
        run.lastLostAltitude = 0
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

function M.buyFuelUpgrade(run)
    local price = M.shopPrice(run, run.fuelUpgradeCost)
    if run.phase ~= "settlement" or run.money < price then return false end
    run.money = run.money - price
    run.fuelUpgradeLevel = run.fuelUpgradeLevel + 1
    refreshShipStats(run)
    return true
end

function M.buyDurabilityUpgrade(run)
    local price = M.shopPrice(run, run.durabilityUpgradeCost)
    if run.phase ~= "settlement" or run.money < price then return false end
    run.money = run.money - price
    run.durabilityUpgradeLevel = run.durabilityUpgradeLevel + 1
    refreshShipStats(run)
    return true
end

-- Sample yield is the third meta upgrade requested alongside fuel/hull: it
-- scales the money value of every collected sample (not just fuel/durability
-- capacity), giving players a third strategic upgrade axis at EARTH SHOP.
function M.sampleYieldMultiplier(run)
    return 1 + run.sampleYieldUpgradeLevel * run.sampleYieldUpgradeAmount
end

function M.buySampleYieldUpgrade(run)
    local price = M.shopPrice(run, run.sampleYieldUpgradeCost)
    if run.phase ~= "settlement" or run.money < price then return false end
    run.money = run.money - price
    run.sampleYieldUpgradeLevel = run.sampleYieldUpgradeLevel + 1
    return true
end

-- Steering is the fourth meta upgrade axis named in
-- docs/GAME_DESIGN.md's meta loop ("연료·내구도·조종·표본 수익을 강화":
-- fuel/hull/steering/sample-yield). It scales the ship's left/right
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
            gains = { { label = "FUEL", value = string.format("%+d", run.scoutFuelBonus) } },
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

function M.useSlot(run)
    if run.phase ~= "returning" or run.slotOpportunities <= 0 then return false end
    local symbols, reward = spinSlot(run)
    run.slotOpportunities = run.slotOpportunities - 1
    run.slotSpins = run.slotSpins + 1
    run.lastSlotSymbols = symbols
    run.lastSlotReward = reward
    run.pendingSlotReward = run.pendingSlotReward + reward
    local voucher = slotRepairVoucher(symbols)
    local applied = math.min(voucher, run.maxDurability - run.durability)
    run.durability = run.durability + applied
    run.lastSlotRepair = applied
    local fuelBonus = slotFuelBonus(symbols)
    run.lastSlotFuelBonus = fuelBonus
    run.pendingFuelBonus = (run.pendingFuelBonus or 0) + fuelBonus
    local sampleBonus = slotSampleBonus(symbols)
    run.lastSlotSampleBonus = sampleBonus
    run.pendingSampleValue = run.pendingSampleValue + sampleBonus
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

function M.streakMultiplier(streakCount, run)
    if not streakCount or streakCount <= 1 then return 1 end
    return 1 + (streakCount - 1) * M.streakBonusPerStep(run)
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
function M.effectiveClimbSpeed(run)
    local gearTotals = gearModule.equippedTotals(run.equippedGear or {})
    return run.climbSpeed + (gearTotals.climbSpeed or 0)
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
function M.collisionRadius(run, baseRadius)
    return gearModule.effectiveCollisionRadius(baseRadius, combinedGearList(run))
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

-- Item 7(b): Exploring a galaxy hub deterministically drops a specific
-- gear part for that galaxy (100% chance, only once per run).
function M.exploreHub(run, galaxyId, pool)
    if run.hubExplored[galaxyId] then
        return nil
    end
    run.hubExplored[galaxyId] = true

    local part = gearModule.galaxySpecificGear(pool, galaxyId)
    if not part then return nil end

    return {
        id = part.id,
        name = part.name,
        nameKo = part.nameKo,
        icon = part.icon,
        rarity = part.rarity,
        tags = part.tags,
        edition = nil,
        effects = part.effects,
    }
end

function M.update(run, dt)
    if dt <= 0 then return end

    if run.phase == "returning" then
        run.altitude = math.max(0, run.altitude - run.returnSpeed * dt)
        if run.altitude == 0 then settle(run) end
        return
    end

    if run.phase ~= "ascending" then return end

    run.altitude = run.altitude + M.effectiveClimbSpeed(run) * dt
    run.maxAltitude = math.max(run.maxAltitude, run.altitude)
    run.bestAltitude = math.max(run.bestAltitude, run.altitude)
end

return M
