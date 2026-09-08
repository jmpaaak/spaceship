local viewport = require("game.viewport")
local PlayScene = require("game.scenes.play")

local M = {}

local function cornersAndCenter(area)
    return {
        { x = area.left, y = area.top },
        { x = area.right - 1, y = area.top },
        { x = area.left, y = area.bottom - 1 },
        { x = area.right - 1, y = area.bottom - 1 },
        { x = math.floor((area.left + area.right) / 2),
          y = math.floor((area.top + area.bottom) / 2) },
    }
end

function M.run()
    local destroyedArea = PlayScene.destroyedTouchArea
    -- Mobile-UI sub-item (6): destroyed touch area must span the full
    -- 720×1280 canvas so any tap restarts.
    assert(destroyedArea.left == 0 and destroyedArea.top == 0,
        "destroyed touch area must start at (0,0)")
    assert(destroyedArea.right == 720 and destroyedArea.bottom == 1280,
        "destroyed touch area must span full 720×1280 canvas")
    assert(destroyedArea.bottom - destroyedArea.top >= 34,
        "destroyed touch area height is under the 34px minimum")
    assert(destroyedArea.right - destroyedArea.left >= 34,
        "destroyed touch area width is under the 34px minimum")
    local destroyedAreaPoints = viewport.canvasPixelsToPoints(
        destroyedArea.bottom - destroyedArea.top, 720, 1280, 1, false)
    assert(destroyedAreaPoints >= 44,
        "destroyed touch area is under the 44pt accessibility minimum at scale 1 (" .. destroyedAreaPoints .. "pt)")
    for _, point in ipairs(cornersAndCenter(destroyedArea)) do
        local destroyedTouchScene = PlayScene.new({
            bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
        })
        destroyedTouchScene.expedition.phase = "destroyed"
        destroyedTouchScene:touchpressed("destroyed-tap", point.x, point.y)
        assert(destroyedTouchScene.expedition.phase == "ascending",
            "destroyed tap at (" .. point.x .. "," .. point.y .. ") did not restart the run")
    end

    -- LAUNCH accepts any tap on the internal canvas. Keep the full-canvas
    -- accessibility and corner/center action contract explicit.
    local launchArea = PlayScene.launchTouchArea
    assert(launchArea.bottom - launchArea.top >= 34,
        "launch touch area height is under the 34px minimum")
    assert(launchArea.right - launchArea.left >= 34,
        "launch touch area width is under the 34px minimum")
    local launchAreaPoints = viewport.canvasPixelsToPoints(
        launchArea.bottom - launchArea.top, 720, 1280, 1, false)
    assert(launchAreaPoints >= 44,
        "launch touch area is under the 44pt accessibility minimum at scale 1 (" .. launchAreaPoints .. "pt)")
    for _, point in ipairs(cornersAndCenter(launchArea)) do
        local launchTouchScene = PlayScene.new({
            bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
        })
        launchTouchScene:touchpressed("launch-tap", point.x, point.y)
        assert(launchTouchScene.expedition.phase == "ascending",
            "launch tap at (" .. point.x .. "," .. point.y .. ") did not start the run")
    end
end

return M