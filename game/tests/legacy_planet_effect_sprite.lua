local M = {}

function M.run()
    -- Legacy planet-effect wiring: the helper remains exported and returns
    -- false for a nil image, while scene instances retain all six image slots.
    local PlayScene = require("game.scenes.play")
    assert(type(PlayScene.drawPlanetEffectSprite) == "function",
        "drawPlanetEffectSprite must be exported on PlayScene")
    local ok, res = pcall(PlayScene.drawPlanetEffectSprite, nil, 50, 50, 20, 1, 1, 1, 1)
    assert(ok, "drawPlanetEffectSprite(nil,...) must not throw")
    assert(res == false, "drawPlanetEffectSprite(nil,...) must return false")

    local scene = PlayScene.new()
    local pe = scene.planetEffectImages
    assert(type(pe) == "table", "scene.planetEffectImages must be a table")
    for _, key in ipairs({"glow","shadow","rim","twinkle","sampleValue","risk"}) do
        assert(pe[key] == nil or type(pe[key]) == "userdata",
            "planetEffectImages." .. key .. " must be nil (headless) or image userdata")
    end
end

return M