local M = {}

function M.run()
    local PlayScene = require("game.scenes.play")
    local world = require("game.world")
    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scene.expedition.phase = "ascending"
    scene.expedition.pendingSampleValue = 50
    scene.expedition.money = 100
    scene.ship.x = 20
    scene.ship.y = -500

    local savedNearby = world.nearbyPlanets

    world.nearbyPlanets = function(x, y, rad)
        return {
            { id = "normal1", x = 0, y = -500, radius = 10, hub = false },
            { id = "hub1", x = 1000, y = -1000, radius = 20, hub = true, galaxyId = "g1" }
        }
    end

    scene:update(0.01)
    assert(scene.expedition.pendingSampleValue > 0, "Approaching normal planet must not trigger settlement")
    assert(scene.expedition.money == 100, "Money should remain unchanged")

    scene.ship.x = 970
    scene.ship.y = -1000
    scene:update(0.01)

    assert(scene.expedition.pendingSampleValue == 0, "Approaching hub planet must clear pendingSampleValue")
    assert(scene.expedition.money > 100, "Approaching hub planet must add to money")

    local foundText = false
    for _, text in ipairs(scene.floatingTexts) do
        if text.kind == "sample" and text.awarded > 0 then
            foundText = true
        end
    end
    assert(foundText, "Hub settlement must spawn floating_hub_settle text")

    world.nearbyPlanets = savedNearby
end

return M