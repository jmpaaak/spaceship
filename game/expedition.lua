local M = {}

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
end

local function slotCount(distance, slotDistance)
    if distance <= 0 then return 0 end
    return math.ceil(distance / slotDistance)
end

function M.launchForecast(run, maxFuel)
    local forecastFuel = maxFuel or run.maxFuel
    if forecastFuel <= 0 or run.fuelBurnRate <= 0 or run.climbSpeed <= 0 then return 0, 0 end
    local altitude = forecastFuel / run.fuelBurnRate * run.climbSpeed
    return altitude, slotCount(altitude, run.slotDistance)
end

local function settle(run)
    run.lastSampleSettlement = run.pendingSampleValue
    run.lastSlotSettlement = run.pendingSlotReward
    local payout = run.lastSampleSettlement + run.lastSlotSettlement
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
end

function M.new(options)
    options = options or {}
    local baseFuel = options.fuel or 100
    local baseDurability = options.durability or 3
    return {
        phase = "launch",
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
    }
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

function M.buyFuelUpgrade(run)
    if run.phase ~= "settlement" or run.money < run.fuelUpgradeCost then return false end
    run.money = run.money - run.fuelUpgradeCost
    run.fuelUpgradeLevel = run.fuelUpgradeLevel + 1
    refreshShipStats(run)
    return true
end

function M.buyDurabilityUpgrade(run)
    if run.phase ~= "settlement" or run.money < run.durabilityUpgradeCost then return false end
    run.money = run.money - run.durabilityUpgradeCost
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
    if run.phase ~= "settlement" or run.money < run.sampleYieldUpgradeCost then return false end
    run.money = run.money - run.sampleYieldUpgradeCost
    run.sampleYieldUpgradeLevel = run.sampleYieldUpgradeLevel + 1
    return true
end

-- Steering is the fourth meta upgrade axis named in
-- docs/GAME_DESIGN.md's meta loop ("연료·내구도·조종·표본 수익을 강화":
-- fuel/hull/steering/sample-yield). It scales the ship's left/right
-- steering speed applied while ascending/returning (game/scenes/play.lua),
-- giving players a way to spend money on better planet-collision avoidance
-- rather than capacity or money yield.
function M.steeringSpeed(run)
    return run.baseSteeringSpeed + run.steeringUpgradeLevel * run.steeringUpgradeAmount
end

function M.buySteeringUpgrade(run)
    if run.phase ~= "settlement" or run.money < run.steeringUpgradeCost then return false end
    run.money = run.money - run.steeringUpgradeCost
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
    if run.phase ~= "settlement" or shipId ~= "scout" or run.ownedShips.scout
        or run.money < run.scoutShipCost then
        return false
    end
    run.money = run.money - run.scoutShipCost
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
local streakBonusPerStep = 0.2
function M.streakMultiplier(streakCount)
    if not streakCount or streakCount <= 1 then return 1 end
    return 1 + (streakCount - 1) * streakBonusPerStep
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
    local streakMultiplier = M.streakMultiplier(run.sampleStreakCount)
    local awarded = math.floor(value * M.sampleYieldMultiplier(run) * streakMultiplier + 0.5)
    run.sampleCount = run.sampleCount + 1
    run.pendingSampleValue = run.pendingSampleValue + awarded
    return true, awarded, streakMultiplier
end

function M.damage(run, amount)
    if (run.phase ~= "ascending" and run.phase ~= "returning") or type(amount) ~= "number" or amount <= 0 then
        return false
    end
    run.durability = math.max(0, run.durability - amount)
    if run.durability == 0 then
        destroy(run)
        return true
    end
    return false
end

function M.update(run, dt)
    if dt <= 0 then return end

    if run.phase == "returning" then
        run.altitude = math.max(0, run.altitude - run.returnSpeed * dt)
        if run.altitude == 0 then settle(run) end
        return
    end

    if run.phase ~= "ascending" then return end

    local ascentTime = dt
    if run.fuelBurnRate > 0 then
        ascentTime = math.min(dt, run.fuel / run.fuelBurnRate)
        run.fuel = math.max(0, run.fuel - run.fuelBurnRate * dt)
    end

    run.altitude = run.altitude + run.climbSpeed * ascentTime
    run.maxAltitude = math.max(run.maxAltitude, run.altitude)
    run.bestAltitude = math.max(run.bestAltitude, run.altitude)

    if run.fuel <= 0 then
        run.phase = "returning"
        run.returnDistance = run.maxAltitude
        run.slotOpportunities = slotCount(run.returnDistance, run.slotDistance)
    end
end

return M
