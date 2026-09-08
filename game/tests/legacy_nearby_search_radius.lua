local M = {}

function M.run()
    -- nearbyPlanets / nearbyDebris search radius must be 4 sectors (not 1)
    -- to prevent pop-in/pop-out on the 720×1280 canvas.
    local PlayScene = require("game.scenes.play")
    local expedition = require("game.expedition")
    local shipModule = require("game.ship")
    local world = require("game.world")

    local scene = PlayScene.new()
    scene.expedition = expedition.new()
    scene.expedition.phase = "ascending"
    scene.ship = shipModule.new()
    scene.ship.x = 100
    scene.ship.y = -200

    local capturedPlanetRad = nil
    local capturedDebrisRad = nil
    local savedNP = world.nearbyPlanets
    local savedND = world.nearbyDebris
    world.nearbyPlanets = function(x, y, rad)
        capturedPlanetRad = rad
        return {}
    end
    world.nearbyDebris = function(x, y, rad, t)
        capturedDebrisRad = rad
        return {}
    end
    scene:update(0.016)
    world.nearbyPlanets = savedNP
    world.nearbyDebris = savedND

    assert(capturedPlanetRad == 4,
        "nearbyPlanets search radius must be 4 sectors, got " .. tostring(capturedPlanetRad))
    assert(capturedDebrisRad == 4,
        "nearbyDebris search radius must be 4 sectors, got " .. tostring(capturedDebrisRad))
end

return M
