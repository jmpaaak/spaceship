local M = {}

function M.run()
    -- Legacy HUD wiring: drawHudSpriteOrPoly remains exported and a nil image
    -- with no polygon callback remains a no-throw fallback.
    local PlayScene = require("game.scenes.play")
    assert(type(PlayScene.drawHudSpriteOrPoly) == "function",
        "drawHudSpriteOrPoly must be exported on PlayScene")
    local ok, err = pcall(PlayScene.drawHudSpriteOrPoly, nil, nil, 10, 10, 8)
    assert(ok, "drawHudSpriteOrPoly(nil,nil,...) must not throw: " .. tostring(err))
end

return M