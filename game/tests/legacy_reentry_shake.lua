local M = {}

function M.run()
    local PlayScene = require("game.scenes.play")
    local world = require("game.world")
    local store = { load = function() return 0 end, save = function() return false end }
    local savedNP = world.nearbyPlanets
    local savedND = world.nearbyDebris
    world.nearbyPlanets = function() return {} end
    world.nearbyDebris = function() return {} end

    local scene = PlayScene.new({ bestAltitudeStore = store })
    scene.expedition.phase = "ascending"
    scene.ship.vx, scene.ship.vy = 0, 0
    scene.ship.x = PlayScene.earthCenterX
    scene.ship.y = PlayScene.earthCenterY - 500
    scene:update(0)
    assert((scene.reentryShake or 0) == 0,
        "far from Earth must not set reentryShake, got " .. tostring(scene.reentryShake))
    assert((scene.reentryHeatAlpha or 0) == 0, "far from Earth must not have heat alpha")

    local reentryR = PlayScene.earthReentryRadius
    scene.ship.y = PlayScene.earthCenterY - (reentryR - 1)
    scene:update(0)
    local farShake = scene.reentryShake or 0
    assert(farShake > 0,
        "ship distance < earthRadius*3 must start reentryShake")
    assert((scene.reentryHeatAlpha or 0) > 0, "must start heat alpha inside reentry range")
    assert(scene.timeSlip == nil, "no slowmo at start of reentry")

    scene.ship.y = PlayScene.earthCenterY - (PlayScene.earthSettleRadius + 16)
    scene:update(0)
    local midShake = scene.reentryShake or 0
    assert(midShake > farShake, "reentryShake must grow")
    local midAlpha = scene.reentryHeatAlpha or 0
    assert(midAlpha > 0, "must have heat alpha")
    assert(scene.timeSlip == nil, "no slowmo before slowmo radius")

    local slowmoR = PlayScene.earthSettleRadius + 15
    scene.ship.y = PlayScene.earthCenterY - (slowmoR - 1)
    scene:update(0)
    assert(scene.timeSlip, "ship distance < settle+15 must trigger slowmo")
    assert(scene.timeSlip.scale == 0.5, "slowmo scale must be 0.5")
    assert(scene.timeSlip.timer == 0.6, "slowmo timer must be 0.6")
    local nearAlpha = scene.reentryHeatAlpha or 0
    assert(nearAlpha > midAlpha, "heat alpha must increase")

    scene.ship.y = PlayScene.earthCenterY - (PlayScene.earthSettleRadius + 1)
    scene:update(0)
    local nearShake = scene.reentryShake or 0
    assert(nearShake > midShake, "reentryShake must grow as Earth distance shrinks")
    assert((scene.reentryHeatAlpha or 0) > nearAlpha, "heat alpha must grow as Earth distance shrinks")

    scene.ship.x = PlayScene.earthCenterX
    scene.ship.y = PlayScene.earthCenterY
    scene:update(0)
    assert(scene.expedition.phase == "settlement",
        "landing on Earth must settle, got " .. tostring(scene.expedition.phase))
    assert((scene.reentryShake or 0) == 0,
        "settle must reset reentryShake to 0")
    assert((scene.reentryHeatAlpha or 0) == 0, "settle must reset heat alpha to 0")

    assert(type(PlayScene.reentryDrawOffsetX) == "function",
        "reentry draw offset helper must be exported")
    local t, mag = 0.1, 4
    assert(math.abs(PlayScene.reentryDrawOffsetX(t, mag) - math.sin(t * 60) * mag) < 1e-9,
        "draw x offset must be sin(time*60)*reentryShake")

    local scene2 = PlayScene.new({ bestAltitudeStore = store })
    scene2.expedition.phase = "ascending"
    scene2.shipShake = 0.25
    scene2.ship.vx, scene2.ship.vy = 0, 0
    scene2.ship.x = PlayScene.earthCenterX
    scene2.ship.y = PlayScene.earthCenterY - (reentryR - 1)
    scene2:update(0)
    assert((scene2.reentryShake or 0) > 0, "reentryShake must be independent of shipShake")
    assert(scene2.shipShake > 0, "reentryShake must not replace shipShake")

    world.nearbyPlanets = savedNP
    world.nearbyDebris = savedND
end

return M