local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    local touchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    touchScene:touchpressed("launch", 90, 280)
    assert(touchScene.expedition.phase == "ascending")
    local idleAscendSteering = touchScene:steeringButtonState()
    assert(not idleAscendSteering.leftActive and not idleAscendSteering.rightActive)
    touchScene:touchpressed("steer-left", 20, 160)
    local leftAscendSteering = touchScene:steeringButtonState()
    assert(leftAscendSteering.leftActive and not leftAscendSteering.rightActive)
    touchScene:update(1)
    assert(math.abs(touchScene.ship.x - (-60)) < 1e-9,
        "expected -60, got " .. string.format("%.17g", touchScene.ship.x))
    touchScene:touchreleased("steer-left")
    local releasedAscendSteering = touchScene:steeringButtonState()
    assert(not releasedAscendSteering.leftActive and not releasedAscendSteering.rightActive)
    touchScene:update(1)
    touchScene:touchpressed("steer-right", 500, 160)
    local rightAscendSteering = touchScene:steeringButtonState()
    assert(not rightAscendSteering.leftActive and rightAscendSteering.rightActive)
    local xBeforeRight = touchScene.ship.x
    touchScene:update(1)
    assert(touchScene.ship.x > xBeforeRight,
        "holding right must still increase ship.x while main thrust follows heading")
    touchScene:touchreleased("steer-right")

    touchScene.expedition.phase = "settlement"
    touchScene.expedition.money = touchScene.expedition.durabilityUpgradeCost
        + touchScene.expedition.scoutShipCost
    touchScene:touchpressed("hull", 180, 500)
    touchScene:touchpressed("ship", 540, 670)
    assert(touchScene.expedition.durabilityUpgradeLevel == 1)
    assert(touchScene.expedition.ownedShips.scout and touchScene.expedition.selectedShipId == "scout")
    touchScene:touchpressed("relaunch", 360, PlayScene.settlementTouchRows[5].top + 40)
    assert(touchScene.expedition.phase == "ascending")
end

return M