local M = {}

function M.run()
    -- Legacy PixelPlanets star sprite wiring: helper remains exported and
    -- nil-safe, while scene instances retain both image slots.
    local PlayScene = require("game.scenes.play")
    assert(type(PlayScene.drawPixelStar) == "function",
        "drawPixelStar must be exported on PlayScene")
    local ok, res = pcall(PlayScene.drawPixelStar, nil, 10, 10, 9, 9, 17, 0, 2, 1, 1, 1, 1)
    assert(ok, "drawPixelStar(nil,...) must not throw")
    assert(res == false, "drawPixelStar(nil,...) must return false")

    local scene = PlayScene.new()
    assert(scene.pixelStarsImage == nil or type(scene.pixelStarsImage) == "userdata",
        "pixelStarsImage must be nil (headless) or image userdata")
    assert(scene.pixelStarsSpecialImage == nil or type(scene.pixelStarsSpecialImage) == "userdata",
        "pixelStarsSpecialImage must be nil (headless) or image userdata")
end

return M
