local M = {}

function M.run()
    -- Legacy floating-icon wiring: the helper remains exported and returns
    -- false for a nil image, while scene instances retain all three slots.
    local PlayScene = require("game.scenes.play")
    assert(type(PlayScene.drawFloatingIconSprite) == "function",
        "drawFloatingIconSprite must be exported on PlayScene")
    local ok, res = pcall(PlayScene.drawFloatingIconSprite, nil, 50, 50, 8, 1)
    assert(ok, "drawFloatingIconSprite(nil,...) must not throw")
    assert(res == false, "drawFloatingIconSprite(nil,...) must return false")

    local scene = PlayScene.new()
    for _, key in ipairs({"floatingSampleIconImage", "floatingDamageIconImage", "messageBannerIconImage"}) do
        assert(scene[key] == nil or type(scene[key]) == "userdata",
            key .. " must be nil (headless) or image userdata")
    end
end

return M