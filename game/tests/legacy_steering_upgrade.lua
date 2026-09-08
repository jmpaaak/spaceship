local expedition = require("game.expedition")
local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    -- GAME_DESIGN.md's meta loop lists four upgrade axes ("연료·내구도·조종·
    -- 표본 수익을 강화": fuel, hull, steering, sample yield), but only three
    -- (fuel/hull/sample yield) existed until now. STEERING is the missing
    -- fourth axis: it scales the ship's left/right steering speed used
    -- during ascending/returning, giving players a fourth strategic EARTH
    -- SHOP purchase that improves planet-collision avoidance rather than
    -- capacity or money yield.
    local steeringRun = expedition.new({
        steeringUpgradeCost = 65,
        steeringUpgradeAmount = 1,
        money = 40,
    })
    assert(expedition.effectiveSpeed(steeringRun) == 60)
    assert(not expedition.buySteeringUpgrade(steeringRun))
    steeringRun.phase = "settlement"
    assert(not expedition.buySteeringUpgrade(steeringRun))
    steeringRun.money = 65
    assert(expedition.buySteeringUpgrade(steeringRun))
    assert(steeringRun.money == 0 and steeringRun.steeringUpgradeLevel == 1)
    assert(expedition.effectiveSpeed(steeringRun) == 61)
    assert(expedition.launch(steeringRun) and steeringRun.phase == "ascending")
    assert(expedition.effectiveSpeed(steeringRun) == 61,
        "steering upgrade must persist across relaunch like fuel/hull upgrades")
    assert(expedition.damage(steeringRun, steeringRun.durability))
    assert(steeringRun.phase == "destroyed" and steeringRun.steeringUpgradeLevel == 0)
    assert(expedition.effectiveSpeed(steeringRun) == 60,
        "steering upgrade must reset to base speed on destruction like the other upgrades")

    local steeringMoveScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    steeringMoveScene.expedition.phase = "ascending"
    steeringMoveScene.expedition.steeringUpgradeLevel = 1
    steeringMoveScene.touches["upgraded-steer"] = { x = 500, y = 10 }
    local shipXBefore = steeringMoveScene.ship.x
    steeringMoveScene:update(1)
    -- steeringUpgradeAmount=1: speed = 60 + 1*1 = 61
    assert(math.abs(steeringMoveScene.ship.x - shipXBefore - 61) < 1e-9,
        "ascending steering must move the ship at expedition.effectiveSpeed(run), not a fixed constant ("
            .. tostring(steeringMoveScene.ship.x - shipXBefore) .. ")")

    local steeringShopScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    steeringShopScene.expedition.phase = "settlement"
    steeringShopScene.expedition.money = steeringShopScene.expedition.steeringUpgradeCost
    steeringShopScene:keypressed("g")
    assert(steeringShopScene.expedition.steeringUpgradeLevel == 1,
        "keypressed('g') in settlement must purchase the STEERING upgrade")
    assert(steeringShopScene.expedition.money == 0)
    steeringShopScene:keypressed("g")
    assert(steeringShopScene.expedition.steeringUpgradeLevel == 1,
        "a second STEERING purchase attempt without enough money must fail")
end

return M
