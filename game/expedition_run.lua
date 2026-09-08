local gearModule = require("game.gear")
local enginePartsModule = require("game.engine_parts")
local expeditionGear = require("game.expedition_gear")

local M = {}

function M.settle(api, run)
    local syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    local sampleMult = syn.binaryStar and 1.3 or 1.0
    run.lastSampleSettlement = math.floor(run.pendingSampleValue * sampleMult + 0.5)
    local payout = run.lastSampleSettlement + api.equippedHullMoneyBonus(run)
    run.money = run.money + payout
    run.lastSettlement = payout
    run.lastSampleCount = run.sampleCount
    run.lastAltitude = run.maxAltitude
    run.lastNewBest = run.bestAltitude > (run.launchBestAltitude or 0)
    run.pendingSampleValue = 0
    run.sampleCount = 0
    if run.lastHubX and run.lastHubY then
        run.lastCheckpointX, run.lastCheckpointY = run.lastHubX, run.lastHubY
    else
        run.lastCheckpointX, run.lastCheckpointY = 0, 75
    end
    syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    if syn.solarSystem then
        run.maxDurability = (run.maxDurability or 3) + 1
        run.durability = math.min(run.durability + 1, run.maxDurability)
    end
    run.phase = "settlement"
end

function M.destroy(api, run)
    run.phase = "destroyed"
    run.durability = 0
    local keep = {}
    for _, part in ipairs(run.equippedGear or {}) do
        keep[#keep + 1] = { category = "hull", part = part }
    end
    for _, part in ipairs(run.equippedEngineParts or {}) do
        keep[#keep + 1] = { category = "engine", part = part }
    end
    run.keepPartChoices = keep
    run.keptPart = nil
    run.lastLostSampleCount = run.sampleCount
    run.lastLostSampleValue = run.pendingSampleValue
    run.lastLostAltitude = run.maxAltitude
    run.lastLostNewBest = run.bestAltitude > (run.launchBestAltitude or 0)
    run.sampleCount = 0
    run.pendingSampleValue = 0
    run.sampleStreakCount = 0
    run.sampleStreakFamily = nil
    run.returnDistance = 0
    run.money = 0
    run.lastSettlement = 0
    run.lastSampleSettlement = 0
    run.lastSampleCount = 0
    run.durabilityUpgradeLevel = 0
    run.sampleYieldUpgradeLevel = 0
    run.steeringUpgradeLevel = 0
    run.slotSpeedBonus = 0
    run.ownedShips = { starter = true }
    run.selectedShipId = "starter"
    expeditionGear.refreshShipStats(api, run)
    run.gearLoadout = enginePartsModule.newLoadout()
    run.equippedGear = run.gearLoadout.hull
    run.equippedEngineParts = run.gearLoadout.engine
    run.insuranceUsed = false
    run.rerollsUsed = 0
    run.boostsUsed = 0
    run.hubExplored = {}
    run.lastVisitedGalaxyId = nil
    run.lastHubX = nil
    run.lastHubY = nil
end

function M.lastCheckpointOrEarth(_, run)
    if run.lastCheckpointX and run.lastCheckpointY then
        return run.lastCheckpointX, run.lastCheckpointY
    end
    return 0, 75
end

function M.new(_, options)
    options = options or {}
    local baseDurability = options.durability or 3
    local run = {
        phase = "launch",
        hubExplored = {},
        lastVisitedGalaxyId = nil,
        lastHubX = nil,
        lastHubY = nil,
        lastCheckpointX = nil,
        lastCheckpointY = nil,
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
        durabilityUpgradeCost = options.durabilityUpgradeCost or 10,
        durabilityUpgradeLevel = 0,
        sampleYieldUpgradeAmount = options.sampleYieldUpgradeAmount or 0.10,
        sampleYieldUpgradeCost = options.sampleYieldUpgradeCost or 5,
        sampleYieldUpgradeLevel = 0,
        baseSpeed = options.baseSpeed or options.climbSpeed or 60,
        steeringUpgradeAmount = options.steeringUpgradeAmount or 1,
        steeringUpgradeCost = options.steeringUpgradeCost or 5,
        steeringUpgradeLevel = 0,
        slotSpeedBonus = 0,
        scoutShipCost = options.scoutShipCost or 125,
        scoutClimbSpeedBonus = options.scoutClimbSpeedBonus or 120,
        ownedShips = { starter = true },
        selectedShipId = "starter",
        returnSpeed = options.returnSpeed or 45,
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
        gearLoadout = nil,
        equippedGear = nil,
        equippedEngineParts = nil,
        insuranceUsed = false,
        rerollsUsed = 0,
        boostsUsed = 0,
    }
    run.gearLoadout = enginePartsModule.newLoadout()
    run.equippedGear = run.gearLoadout.hull
    run.equippedEngineParts = run.gearLoadout.engine
    return run
end

function M.launch(api, run)
    if run.phase ~= "launch" and run.phase ~= "settlement" and run.phase ~= "destroyed" then return false end
    run.launchBestAltitude = run.bestAltitude
    run.lastNewBest = false
    run.lastLostNewBest = false
    if run.phase ~= "launch" then
        run.altitude = 0
        run.maxAltitude = 0
        if run.lastVisitedGalaxyId == nil then run.durability = run.maxDurability end
        run.insuranceUsed = false
        run.rerollsUsed = 0
        run.boostsUsed = 0
        run.returnDistance = 0
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
        run.hubExplored = {}
        run.lastVisitedGalaxyId = nil
        run.lastHubX = nil
        run.lastHubY = nil
        local kept = run.keptPart
        run.keepPartChoices = nil
        run.keptPart = nil
        if kept and kept.part and kept.category then api.equipGear(run, kept.category, kept.part) end
    end
    run.phase = "ascending"
    return true
end

function M.collectSample(api, run, value, hueKey)
    if run.phase ~= "ascending" or type(value) ~= "number" or value <= 0 then return false end
    if hueKey ~= nil and hueKey == run.sampleStreakFamily then
        run.sampleStreakCount = run.sampleStreakCount + 1
    else
        run.sampleStreakCount = 1
    end
    run.sampleStreakFamily = hueKey
    local streakMultiplier = api.streakMultiplier(run.sampleStreakCount, run)
    local awarded = math.floor(value * api.sampleYieldMultiplier(run) * streakMultiplier + 0.5)
        + api.effectiveSampleBonus(run)
    local retriggers = api.chainTriggerCount(run)
    if retriggers > 0 then awarded = awarded * (1 + retriggers) end
    run.sampleCount = run.sampleCount + 1
    run.pendingSampleValue = run.pendingSampleValue + awarded
    return true, awarded, streakMultiplier, retriggers
end

function M.damage(api, run, amount)
    if (run.phase ~= "ascending" and run.phase ~= "returning")
        or type(amount) ~= "number" or amount <= 0 then
        return false
    end
    run.durability = math.max(0, run.durability - amount)
    if run.durability == 0 then
        if not run.insuranceUsed and expeditionGear.hasInsurance(run) then
            run.insuranceUsed = true
            run.durability = 1
            return false
        end
        M.destroy(api, run)
        return true
    end
    return false
end

function M.settleAtHub(_, run)
    local syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    local payout = math.floor(run.pendingSampleValue * (syn.binaryStar and 1.3 or 1.0) + 0.5)
    if payout > 0 then
        run.money = run.money + payout
        run.pendingSampleValue = 0
        return payout
    end
    return 0
end

function M.update(api, run, dt)
    if dt <= 0 or run.phase ~= "ascending" then return end
    run.altitude = run.altitude + api.effectiveSpeed(run) * dt
    run.maxAltitude = math.max(run.maxAltitude, run.altitude)
    run.bestAltitude = math.max(run.bestAltitude, run.altitude)
    local regen = expeditionGear.totalEffect(run, "hullRegen")
    if regen > 0 and run.durability < run.maxDurability then
        run.durabilityRegenAcc = (run.durabilityRegenAcc or 0) + regen * dt
        local whole = math.floor(run.durabilityRegenAcc)
        if whole >= 1 then
            run.durability = math.min(run.maxDurability, run.durability + whole)
            run.durabilityRegenAcc = run.durabilityRegenAcc - whole
        end
    end
end

return M
