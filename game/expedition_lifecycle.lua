local M = {}

local gear = require("game.gear")
local engineParts = require("game.engine_parts")

local function combinedGearList(run)
    local parts = {}
    for _, part in ipairs(run.equippedGear or {}) do parts[#parts + 1] = part end
    for _, part in ipairs(run.equippedEngineParts or {}) do parts[#parts + 1] = part end
    return parts
end

function M.equippedHullDurabilityBonus(run)
    return (gear.equippedTotals(run.equippedGear or {}).hullDurability or 0)
        + gear.engineSlotHullDurabilityDrawback(run.equippedEngineParts or {})
end

function M.getScoutDurabilityBonus(run)
    local baseAndGearD = run.baseDurability
        + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
        + M.equippedHullDurabilityBonus(run)
    local bonus = -math.floor(baseAndGearD * 0.5)
    if baseAndGearD + bonus < 1 then bonus = 1 - baseAndGearD end
    return bonus
end

function M.refreshShipStats(run)
    local durabilityBonus = 0
    if run.selectedShipId == "scout" then
        durabilityBonus = M.getScoutDurabilityBonus(run)
    end
    run.maxDurability = run.baseDurability + durabilityBonus
        + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
        + M.equippedHullDurabilityBonus(run)
end

function M.equippedHullMoneyBonus(run)
    return gear.equippedTotals(run.equippedGear or {}).money or 0
end

function M.settle(run)
    local syn = gear.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    local sampleMult = syn.binaryStar and 1.3 or 1.0
    run.lastSampleSettlement = math.floor(run.pendingSampleValue * sampleMult + 0.5)
    local payout = run.lastSampleSettlement + M.equippedHullMoneyBonus(run)
    run.money = run.money + payout
    run.lastSettlement = payout
    run.lastSampleCount = run.sampleCount
    run.lastAltitude = run.maxAltitude
    run.lastNewBest = run.bestAltitude > (run.launchBestAltitude or 0)
    run.pendingSampleValue = 0
    run.sampleCount = 0
    if run.lastHubX and run.lastHubY then
        run.lastCheckpointX = run.lastHubX
        run.lastCheckpointY = run.lastHubY
    else
        run.lastCheckpointX = 0
        run.lastCheckpointY = 75
    end
    syn = gear.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    if syn.solarSystem then
        run.maxDurability = (run.maxDurability or 3) + 1
        run.durability = math.min(run.durability + 1, run.maxDurability)
    end
    run.phase = "settlement"
end

function M.destroy(run)
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
    M.refreshShipStats(run)
    run.gearLoadout = engineParts.newLoadout()
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

function M.lastCheckpointOrEarth(run)
    if run.lastCheckpointX and run.lastCheckpointY then
        return run.lastCheckpointX, run.lastCheckpointY
    end
    return 0, 75
end

function M.new(options)
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
    run.gearLoadout = engineParts.newLoadout()
    run.equippedGear = run.gearLoadout.hull
    run.equippedEngineParts = run.gearLoadout.engine
    return run
end

function M.launch(run, equipGear)
    if run.phase ~= "launch" and run.phase ~= "settlement" and run.phase ~= "destroyed" then return false end
    run.launchBestAltitude = run.bestAltitude
    run.lastNewBest = false
    run.lastLostNewBest = false
    if run.phase ~= "launch" then
        run.altitude = 0
        run.maxAltitude = 0
        local fromHub = run.lastVisitedGalaxyId ~= nil
        if not fromHub then run.durability = run.maxDurability end
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
        if kept and kept.part and kept.category then
            equipGear(run, kept.category, kept.part)
        end
    end
    run.phase = "ascending"
    return true
end

function M.damage(run, amount)
    if (run.phase ~= "ascending" and run.phase ~= "returning")
        or type(amount) ~= "number" or amount <= 0 then
        return false
    end
    run.durability = math.max(0, run.durability - amount)
    if run.durability == 0 then
        if not run.insuranceUsed and gear.hasInsurance(combinedGearList(run)) then
            run.insuranceUsed = true
            run.durability = 1
            return false
        end
        M.destroy(run)
        return true
    end
    return false
end

function M.settleAtHub(run)
    local syn = gear.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    local sampleMult = syn.binaryStar and 1.3 or 1.0
    local payout = math.floor(run.pendingSampleValue * sampleMult + 0.5)
    if payout > 0 then
        run.money = run.money + payout
        run.pendingSampleValue = 0
        return payout
    end
    return 0
end

function M.exploreHub(run, galaxyId, pool, rolls)
    if run.hubExplored[galaxyId] then return nil end
    run.hubExplored[galaxyId] = true
    run.lastVisitedGalaxyId = galaxyId
    local part = gear.galaxySpecificGear(pool, galaxyId)
    if not part then return nil end
    local edition = nil
    local effects = part.effects
    if rolls then
        local luckBonus = gear.totalLuckBonus(combinedGearList(run))
        edition = gear.rollEdition(part, rolls.editionChance or 1, rolls.editionPick or 0, luckBonus)
        if edition then effects = gear.applyEditionEffects(part, edition) end
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

return M