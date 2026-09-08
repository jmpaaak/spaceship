local M = {}

function M.run()
    -- Auto-settle on Earth proximity during ascending.
    local PlayScene = require("game.scenes.play")
    local rtScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    rtScene:touchpressed("launch-rt", 90, 280)
    assert(rtScene.expedition.phase == "ascending", "should be ascending")

    -- Fly away from Earth
    rtScene.ship.x = 0
    rtScene.ship.y = -500
    rtScene:update(0.1)
    assert(rtScene.expedition.phase == "ascending", "should stay ascending")

    -- Fly back to Earth proximity
    rtScene.ship.x = PlayScene.earthCenterX
    rtScene.ship.y = PlayScene.earthCenterY - PlayScene.earthSettleRadius + 10
    rtScene:update(0.1)
    assert(rtScene.expedition.phase == "settlement",
        "proximity to earth should auto-settle, got " .. rtScene.expedition.phase)
end

return M