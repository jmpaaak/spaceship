local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    -- Ascending no longer draws HOLD LEFT/HOLD RIGHT boxes; the full
    -- canvas is still a tap-hold fallback (left half / right half).
    local ascendControls = PlayScene.ascendControls
    local ascendEdgeScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    ascendEdgeScene.expedition.phase = "ascending"
    ascendEdgeScene:touchpressed("ascend-edge-left", 20, ascendControls.top)
    local ascendEdgeLeftSteering = ascendEdgeScene:steeringButtonState()
    assert(ascendEdgeLeftSteering.leftActive and not ascendEdgeLeftSteering.rightActive,
        "ascending tap on the left half must still register left steering")
    ascendEdgeScene:touchreleased("ascend-edge-left")
    ascendEdgeScene:touchpressed("ascend-edge-right", 500, ascendControls.bottom - 1)
    local ascendEdgeRightSteering = ascendEdgeScene:steeringButtonState()
    assert(not ascendEdgeRightSteering.leftActive and ascendEdgeRightSteering.rightActive,
        "ascending tap on the right half must still register right steering")
    ascendEdgeScene:touchreleased("ascend-edge-right")
end

return M
