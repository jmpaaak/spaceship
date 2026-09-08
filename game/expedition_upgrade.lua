local gearModule = require("game.gear")
local expeditionGear = require("game.expedition_gear")

local M = {}

function M.upgradeCost(_, _, baseCost, level)
    return math.floor(baseCost * (1.05 ^ (level or 0)) + 0.5)
end

function M.buyDurabilityUpgrade(api, run)
    local base = api.upgradeCost(run, run.durabilityUpgradeCost, run.durabilityUpgradeLevel)
    local price = api.shopPrice(run, base)
    if run.phase ~= "settlement" or run.money < price then return false end
    run.money = run.money - price
    run.durabilityUpgradeLevel = run.durabilityUpgradeLevel + 1
    local beforeMax = run.maxDurability or 0
    expeditionGear.refreshShipStats(api, run)
    local gained = (run.maxDurability or 0) - beforeMax
    run.durability = math.min(
        run.maxDurability,
        (run.durability or 0) + math.max(gained, run.durabilityUpgradeAmount or 1)
    )
    return true
end

function M.sampleYieldMultiplier(_, run)
    local base = 1 + run.sampleYieldUpgradeLevel * run.sampleYieldUpgradeAmount
    local syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    if syn.nebulaField then base = base * 1.5 end
    return base
end

function M.buySampleYieldUpgrade(api, run)
    local base = api.upgradeCost(run, run.sampleYieldUpgradeCost, run.sampleYieldUpgradeLevel)
    local price = api.shopPrice(run, base)
    if run.phase ~= "settlement" or run.money < price then return false end
    run.money = run.money - price
    run.sampleYieldUpgradeLevel = run.sampleYieldUpgradeLevel + 1
    return true
end

function M.rcsVisual(api, run, time, particleCount)
    local speed = api.effectiveSpeed(run)
    local t = math.min(math.max(speed, 0) / 999, 1)
    local radius = 1.5 + t * 2.5
    local r, g, b
    if t < 0.33 then
        local u = t / 0.33
        r, g, b = 1, 1 - 0.6 * u, 1 - 0.8 * u
    elseif t < 0.66 then
        local u = (t - 0.33) / 0.33
        r, g, b = 1 - 0.7 * u, 0.4 + 0.1 * u, 0.2 + 0.8 * u
    else
        local hue = (((time or 0) * 3) + (particleCount or 0) * 0.2) % 1
        local h6 = hue * 6
        local c = 1
        local x2 = c * (1 - math.abs(h6 % 2 - 1))
        local hi = math.floor(h6)
        if hi == 0 then r, g, b = c, x2, 0
        elseif hi == 1 then r, g, b = x2, c, 0
        elseif hi == 2 then r, g, b = 0, c, x2
        elseif hi == 3 then r, g, b = 0, x2, c
        elseif hi == 4 then r, g, b = x2, 0, c
        else r, g, b = c, 0, x2 end
    end
    return r, g, b, radius, t
end

function M.rcsSpeedLevel(api, run)
    local _, _, _, _, t = api.rcsVisual(run, 0, 0)
    if t >= 0.66 then return 3
    elseif t >= 0.33 then return 2
    elseif t >= 0.10 then return 1
    else return 0 end
end

function M.buySteeringUpgrade(api, run)
    local base = api.upgradeCost(run, run.steeringUpgradeCost, run.steeringUpgradeLevel)
    local price = api.shopPrice(run, base)
    if run.phase ~= "settlement" or run.money < price then return false end
    run.money = run.money - price
    run.steeringUpgradeLevel = run.steeringUpgradeLevel + 1
    return true
end

function M.adminUpgrade(api, run, kind)
    if kind == "speed" then
        run.steeringUpgradeLevel = (run.steeringUpgradeLevel or 0) + 1
        return true
    elseif kind == "hull" then
        run.durabilityUpgradeLevel = (run.durabilityUpgradeLevel or 0) + 1
        local before = run.maxDurability or 0
        expeditionGear.refreshShipStats(api, run)
        local gained = (run.maxDurability or 0) - before
        run.durability = (run.durability or 0)
            + math.max(gained, run.durabilityUpgradeAmount or 1)
        return true
    elseif kind == "yield" then
        run.sampleYieldUpgradeLevel = (run.sampleYieldUpgradeLevel or 0) + 1
        return true
    end
    return false
end

function M.shipTradeoff(api, run, shipId)
    if shipId == "scout" then
        return {
            gains = { { label = "SPEED", value = string.format("%+d", run.scoutClimbSpeedBonus) } },
            losses = { { label = "HULL", value = string.format("%+d", api.getScoutDurabilityBonus(run)) } },
        }
    end
    return { gains = {}, losses = {} }
end

function M.buyShip(api, run, shipId)
    if run.phase ~= "settlement" or shipId ~= "scout" or run.ownedShips.scout then return false end
    local price = api.shopPrice(run, run.scoutShipCost)
    if run.money < price then return false end
    run.money = run.money - price
    run.ownedShips.scout = true
    return true
end

function M.selectShip(api, run, shipId)
    if run.phase ~= "settlement" or not run.ownedShips[shipId]
        or (shipId ~= "starter" and shipId ~= "scout") then
        return false
    end
    run.selectedShipId = shipId
    expeditionGear.refreshShipStats(api, run)
    return true
end

return M
