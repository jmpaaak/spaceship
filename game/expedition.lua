local M = {}

local slotSymbols = { "COMET", "PLANET", "STAR" }
M.slotSymbols = slotSymbols

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

local function spinSlot(run)
    local symbols = {}
    for reel = 1, 3 do
        symbols[reel] = slotSymbols[run.slotRandom(#slotSymbols)]
    end
    return symbols, slotReward(symbols)
end

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
    run.sampleCount = 0
    run.pendingSampleValue = 0
    run.pendingSlotReward = 0
    run.slotOpportunities = 0
    run.slotSpins = 0
    run.lastSlotSymbols = nil
    run.lastSlotReward = 0
    run.returnDistance = 0
    run.money = 0
    run.lastSettlement = 0
    run.lastSampleSettlement = 0
    run.lastSlotSettlement = 0
    run.lastSampleCount = 0
    run.lastSlotSpinsCount = 0
    run.fuelUpgradeLevel = 0
    run.durabilityUpgradeLevel = 0
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
        sampleCount = 0,
        pendingSampleValue = 0,
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
    if run.phase ~= "launch" then
        run.altitude = 0
        run.maxAltitude = 0
        run.fuel = run.maxFuel
        run.durability = run.maxDurability
        run.returnDistance = 0
        run.slotOpportunities = 0
        run.slotSpins = 0
        run.lastSlotSymbols = nil
        run.lastSlotReward = 0
        run.sampleCount = 0
        run.pendingSampleValue = 0
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
    return true
end

function M.collectSample(run, value)
    if run.phase ~= "ascending" or type(value) ~= "number" or value <= 0 then return false end
    run.sampleCount = run.sampleCount + 1
    run.pendingSampleValue = run.pendingSampleValue + value
    return true
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
