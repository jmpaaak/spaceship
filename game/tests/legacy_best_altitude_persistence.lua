local expedition = require("game.expedition")
local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    local savedBest = 40
    local fakeStore = {
        load = function() return savedBest end,
        save = function(_, altitude)
            if altitude <= savedBest then return false end
            savedBest = altitude
            return true
        end,
    }
    local persistedScene = PlayScene.new({ bestAltitudeStore = fakeStore })
    assert(persistedScene.expedition.bestAltitude == 40)
    assert(persistedScene:hudLines().best == "RECORD 40")
    persistedScene.expedition.phase = "settlement"
    assert(persistedScene:hudLines().best == "RECORD 40")
    persistedScene.expedition.phase = "launch"
    persistedScene.expedition.baseSpeed = 60
    assert(expedition.launch(persistedScene.expedition))
    persistedScene.expedition.altitude = 60
    persistedScene.expedition.maxAltitude = 60
    persistedScene.expedition.bestAltitude = 60
    persistedScene.expedition.phase = "returning"
    persistedScene:persistBestAltitude()
    assert(persistedScene.expedition.phase == "returning" and savedBest == 60)
    local restartedScene = PlayScene.new({ bestAltitudeStore = fakeStore })
    assert(restartedScene.expedition.bestAltitude == 60)
    assert(restartedScene:hudLines().best == "RECORD 60")
end

return M