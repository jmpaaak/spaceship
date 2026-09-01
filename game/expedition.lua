local M = {}

local function slotCount(distance, slotDistance)
    if distance <= 0 then return 0 end
    return math.ceil(distance / slotDistance)
end

local function settle(run)
    local payout = run.pendingSampleValue + run.pendingSlotReward
    run.money = run.money + payout
    run.lastSettlement = payout
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
    run.sampleCount = 0
    run.pendingSampleValue = 0
    run.pendingSlotReward = 0
    run.slotOpportunities = 0
    run.slotSpins = 0
    run.returnDistance = 0
    run.money = 0
    run.lastSettlement = 0
    run.fuelUpgradeLevel = 0
    run.maxFuel = run.baseFuel
    run.durabilityUpgradeLevel = 0
    run.maxDurability = run.baseDurability
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
        fuelBurnRate = options.fuelBurnRate or 5,
        climbSpeed = options.climbSpeed or 30,
        returnSpeed = options.returnSpeed or 45,
        slotDistance = options.slotDistance or 100,
        slotReward = options.slotReward or 10,
        returnDistance = 0,
        slotOpportunities = 0,
        slotSpins = 0,
        sampleCount = 0,
        pendingSampleValue = 0,
        pendingSlotReward = 0,
        money = options.money or 0,
        lastSettlement = 0,
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
        run.sampleCount = 0
        run.pendingSampleValue = 0
        run.pendingSlotReward = 0
        run.lastSettlement = 0
    end
    run.phase = "ascending"
    return true
end

function M.buyFuelUpgrade(run)
    if run.phase ~= "settlement" or run.money < run.fuelUpgradeCost then return false end
    run.money = run.money - run.fuelUpgradeCost
    run.fuelUpgradeLevel = run.fuelUpgradeLevel + 1
    run.maxFuel = run.baseFuel + run.fuelUpgradeLevel * run.fuelUpgradeAmount
    return true
end

function M.buyDurabilityUpgrade(run)
    if run.phase ~= "settlement" or run.money < run.durabilityUpgradeCost then return false end
    run.money = run.money - run.durabilityUpgradeCost
    run.durabilityUpgradeLevel = run.durabilityUpgradeLevel + 1
    run.maxDurability = run.baseDurability + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
    return true
end

function M.useSlot(run)
    if run.phase ~= "returning" or run.slotOpportunities <= 0 then return false end
    run.slotOpportunities = run.slotOpportunities - 1
    run.slotSpins = run.slotSpins + 1
    run.pendingSlotReward = run.pendingSlotReward + run.slotReward
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
