local PlayScene = require("game.scenes.play")
local world = require("game.world")

local M = {}

function M.run()
    -- Collision impact should trigger a brief ship shake so hits feel more
    -- physical, mirroring how the sample pickup triggers a scale-punch.
    local shakeScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    shakeScene.expedition.phase = "ascending"
    shakeScene.expedition.altitude = 500
    shakeScene.expedition.durability = 3
    shakeScene.ship.x = 0
    shakeScene.ship.y = -500
    assert(shakeScene.shipShake == 0)
    local shakeNearby = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "shake-test", x = 0, y = -500, radius = 7 } }
    end
    shakeScene:update(0)
    world.nearbyPlanets = shakeNearby
    assert(shakeScene.shipShake == PlayScene.shipShakeDuration,
        "planet collision must trigger a ship shake")

    -- Score-proportional screen shake (INBOX 2026-09-02 후속 확정 사항 #3):
    -- a collision with a higher sample-tier planet must feel bigger than a
    -- collision with a common one, so the shake magnitude scales with
    -- world.sampleTier(planet) the same way particle density/glow already
    -- do (common < rare < epic).
    local commonMagnitude = PlayScene.sampleTierShakeMultiplier("common")
    local rareMagnitude = PlayScene.sampleTierShakeMultiplier("rare")
    local epicMagnitude = PlayScene.sampleTierShakeMultiplier("epic")
    assert(commonMagnitude < rareMagnitude and rareMagnitude < epicMagnitude,
        "shake magnitude must increase common < rare < epic")
    assert(shakeScene.shipShakeMagnitude == rareMagnitude,
        "collision at height 500 (rare tier) must set shipShakeMagnitude to the rare multiplier")

    local commonShakeScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    commonShakeScene.expedition.phase = "ascending"
    commonShakeScene.expedition.altitude = 0
    commonShakeScene.expedition.durability = 3
    commonShakeScene.ship.x = 0
    commonShakeScene.ship.y = 0
    local commonNearby = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "shake-test-common", x = 0, y = 0, radius = 7 } }
    end
    commonShakeScene:update(0)
    world.nearbyPlanets = commonNearby
    assert(commonShakeScene.shipShakeMagnitude == commonMagnitude,
        "collision at height 0 (common tier) must set shipShakeMagnitude to the common multiplier")
end

return M