local M = {}

function M.run()
    -- Legacy shop/control sprite wiring: both helpers remain exported and
    -- nil-safe, while scene instances retain the related image slots.
    local PlayScene = require("game.scenes.play")
    assert(type(PlayScene.drawShopIconSprite) == "function",
        "drawShopIconSprite must be exported on PlayScene")
    local ok1, res1 = pcall(PlayScene.drawShopIconSprite, nil, 50, 50, 8)
    assert(ok1, "drawShopIconSprite(nil,...) must not throw")
    assert(res1 == false, "drawShopIconSprite(nil,...) must return false")

    assert(type(PlayScene.drawStarPointSprite) == "function",
        "drawStarPointSprite must be exported on PlayScene")
    local ok2, res2 = pcall(PlayScene.drawStarPointSprite, nil, 50, 50, 3)
    assert(ok2, "drawStarPointSprite(nil,...) must not throw")
    assert(res2 == false, "drawStarPointSprite(nil,...) must return false")

    local scene = PlayScene.new()
    for _, key in ipairs({
        "joystickPadImage", "joystickKnobImage",
        "specimenBannerImage", "starPointImage",
    }) do
        assert(scene[key] == nil or type(scene[key]) == "userdata",
            key .. " must be nil (headless) or image userdata")
    end
    assert(type(scene.shopIconImages) == "table",
        "shopIconImages must be a table")
    for _, ikey in ipairs({"hull", "steering", "yield", "ship"}) do
        assert(scene.shopIconImages[ikey] == nil or type(scene.shopIconImages[ikey]) == "userdata",
            "shopIconImages." .. ikey .. " must be nil (headless) or image userdata")
    end
end

return M