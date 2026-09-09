-- INBOX (61): slot HARVEST payout must apply shop-upgrade units.
-- 2-match = +1 level (+0.10), 3-match = +5 levels (+0.50).
local M = {}

local function settleSpin(scene)
    scene:keypressed("l")
    local guard = 0
    while scene.slotState and scene.slotState.spinning do
        if scene.slotState.stopNext then scene.slotState:stopNext() end
        scene:update(0.1)
        guard = guard + 1
        assert(guard < 200, "INBOX (61): slot spin did not settle")
    end
end

local function newScene()
    local PlayScene = require("game.scenes.play")
    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    scene.expedition.phase = "settlement"
    scene.expedition.money = 1000
    return scene
end

function M.run()
    local expedition = require("game.expedition")
    local originalSpin = expedition.earthSlotSpin

    -- Keep earthSlotSpin rewardValue contract (harvest_hull_upgrade.lua).
    local twoSpin = expedition.earthSlotSpin(expedition.new(), nil, { reels = { 16, 16, 0 } })
    assert(twoSpin.rewardType == "harvest" and math.abs((twoSpin.rewardValue or 0) - 0.10) < 1e-9,
        "INBOX (61): 2-match HARVEST rewardValue must stay 0.10, got " .. tostring(twoSpin.rewardValue))
    local threeSpin = expedition.earthSlotSpin(expedition.new(), nil, { reels = { 16, 16, 16 } })
    assert(threeSpin.rewardType == "harvest" and math.abs((threeSpin.rewardValue or 0) - 0.50) < 1e-9,
        "INBOX (61): 3-match HARVEST rewardValue must stay 0.50, got " .. tostring(threeSpin.rewardValue))

    -- (a/d) 2-match HARVEST settlement: +1 shop unit, multiplier x1.10
    local twoScene = newScene()
    expedition.earthSlotSpin = function()
        return {
            symbols = { "HARVEST", "HARVEST", "MONEY" },
            reward = 0,
            rewardType = "harvest",
            rewardValue = 0.10,
            matchCount = 2,
            matchSymbol = "HARVEST",
        }
    end
    settleSpin(twoScene)
    assert(twoScene.expedition.sampleYieldUpgradeLevel == 1,
        "INBOX (61): 2-match HARVEST must add 1 shop level, got "
            .. tostring(twoScene.expedition.sampleYieldUpgradeLevel))
    assert(math.abs(expedition.sampleYieldMultiplier(twoScene.expedition) - 1.10) < 1e-9,
        "INBOX (61): 2-match HARVEST multiplier must be x1.10, got "
            .. tostring(expedition.sampleYieldMultiplier(twoScene.expedition)))
    assert(twoScene.slotResultMessage and twoScene.slotResultMessage:find("0%.10", 1),
        "INBOX (61): 2-match message must show +0.10, got "
            .. tostring(twoScene.slotResultMessage))

    -- (a/d) 3-match HARVEST settlement: +5 shop units, multiplier x1.50
    local threeScene = newScene()
    expedition.earthSlotSpin = function()
        return {
            symbols = { "HARVEST", "HARVEST", "HARVEST" },
            reward = 0,
            rewardType = "harvest",
            rewardValue = 0.50,
            matchCount = 3,
            matchSymbol = "HARVEST",
        }
    end
    settleSpin(threeScene)
    assert(threeScene.expedition.sampleYieldUpgradeLevel == 5,
        "INBOX (61): 3-match HARVEST must add 5 shop levels, got "
            .. tostring(threeScene.expedition.sampleYieldUpgradeLevel))
    assert(math.abs(expedition.sampleYieldMultiplier(threeScene.expedition) - 1.50) < 1e-9,
        "INBOX (61): 3-match HARVEST multiplier must be x1.50, got "
            .. tostring(expedition.sampleYieldMultiplier(threeScene.expedition)))
    assert(threeScene.slotResultMessage and threeScene.slotResultMessage:find("0%.50", 1),
        "INBOX (61): 3-match message must show +0.50, got "
            .. tostring(threeScene.slotResultMessage))

    -- (c) SPEED already applies rewardValue as slotSpeedBonus; shop level stays put.
    local speedScene = newScene()
    local speedBefore = speedScene.expedition.steeringUpgradeLevel or 0
    expedition.earthSlotSpin = function()
        return {
            symbols = { "SPEED", "SPEED", "MONEY" },
            reward = 0,
            rewardType = "speed",
            rewardValue = 5,
            matchCount = 2,
            matchSymbol = "SPEED",
        }
    end
    settleSpin(speedScene)
    assert(speedScene.expedition.slotSpeedBonus == 5,
        "INBOX (61): SPEED 2-match must add slotSpeedBonus=5, got "
            .. tostring(speedScene.expedition.slotSpeedBonus))
    assert(speedScene.expedition.steeringUpgradeLevel == speedBefore,
        "INBOX (61): SPEED payout must not bump steeringUpgradeLevel")

    -- (c) DURABILITY applies rewardValue as extra shop-sized hull levels.
    local hullScene = newScene()
    local hullBefore = hullScene.expedition.durabilityUpgradeLevel or 0
    expedition.earthSlotSpin = function()
        return {
            symbols = { "DURABILITY", "DURABILITY", "MONEY" },
            reward = 0,
            rewardType = "durability",
            rewardValue = 3,
            matchCount = 2,
            matchSymbol = "DURABILITY",
        }
    end
    settleSpin(hullScene)
    assert(hullScene.expedition.durabilityUpgradeLevel == hullBefore + 3,
        "INBOX (61): DURABILITY 2-match must add 3 hull levels, got "
            .. tostring(hullScene.expedition.durabilityUpgradeLevel))

    expedition.earthSlotSpin = originalSpin
    print("  INBOX-61 slot HARVEST payout applies shop units OK")
end

return M
