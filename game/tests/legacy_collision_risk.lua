local expedition = require("game.expedition")
local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    local riskScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    riskScene.expedition.phase = "ascending"
    riskScene.expedition.altitude = 500
    riskScene.expedition.durability = 3
    local warning = riskScene:collisionRisk({ y = -500 })
    assert(warning.damage == 1 and not warning.lethal and warning.label == "RISK -1")
    assert(warning.sampleValue == 1 and warning.sampleLabel == "SAMPLE $1")
    local lethalWarning = riskScene:collisionRisk({ y = -5000 })
    assert(lethalWarning.damage == 3 and lethalWarning.lethal and lethalWarning.label == "LETHAL -3")
    assert(lethalWarning.sampleValue == 1 and lethalWarning.sampleLabel == "SAMPLE $1")
    -- The SAMPLE YIELD upgrade multiplies the actual money awarded by
    -- expedition.collectSample (see collectSample's `awarded` return value
    -- and its use in PlayScene's floating "+$N" text), but the RISK/SAMPLE
    -- approach-warning preview label was still built directly from
    -- world.sampleValue(planet), ignoring the multiplier. That made the
    -- preview understate the real payout once a player owned any SAMPLE
    -- YIELD level, so it must also apply expedition.sampleYieldMultiplier.
    riskScene.expedition.sampleYieldUpgradeLevel = 4
    local yieldWarning = riskScene:collisionRisk({ y = -500 })
    -- planet $1 × sampleYieldMultiplier(level4) → rounded
    local expectedYieldVal = math.floor(1 * expedition.sampleYieldMultiplier(riskScene.expedition) + 0.5)
    assert(yieldWarning.sampleValue == expectedYieldVal,
        "collisionRisk sampleValue must apply the SAMPLE YIELD multiplier ("
            .. tostring(yieldWarning.sampleValue) .. " expected " .. expectedYieldVal .. ")")
    riskScene.expedition.sampleYieldUpgradeLevel = 0
    riskScene.expedition.sampleCount = 3
    riskScene.expedition.pendingSampleValue = 95

    return riskScene
end

return M