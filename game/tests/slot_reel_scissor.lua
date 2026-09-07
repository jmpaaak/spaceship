-- INBOX (47): slot reel scissor uses screen coords after translate+scale.
local M = {}

function M.run()
    local playShop = require("game.scenes.play_shop")

    assert(type(playShop.reelWindowToScissor) == "function",
        "INBOX (47): play_shop.reelWindowToScissor must exist")

    -- Identity when no transform is available.
    local ix, iy, iw, ih = playShop.reelWindowToScissor(8, 16, 24, 32, nil)
    assert(ix == 8 and iy == 16 and iw == 24 and ih == 32,
        "INBOX (47): nil transform must keep game-space scissor")

    -- Mobile portrait: translate(100, 50) then scale(2, 2).
    local function scaled(x, y)
        return 100 + x * 2, 50 + y * 2
    end
    local sx, sy, sw, sh = playShop.reelWindowToScissor(10, 20, 24, 32, scaled)
    assert(sx == 120, "INBOX (47): scissor x must be screen-space, got " .. tostring(sx))
    assert(sy == 90, "INBOX (47): scissor y must be screen-space, got " .. tostring(sy))
    assert(sw == 48, "INBOX (47): scissor w must be scaled, got " .. tostring(sw))
    assert(sh == 64, "INBOX (47): scissor h must be scaled, got " .. tostring(sh))

    local src = love.filesystem.read("game/scenes/play_shop.lua") or ""
    assert(src:find("transformPoint", 1, true),
        "INBOX (47): reel draw must convert via love.graphics.transformPoint")
    assert(src:find("reelWindowToScissor", 1, true),
        "INBOX (47): reel draw must use reelWindowToScissor for setScissor")
    -- Missing-icon fallback: large letter inside the reel window (both spin + idle).
    assert(src:find("drawReelFallbackText", 1, true),
        "INBOX (47): missing reel icon must use large in-window text fallback")

    print("  INBOX-47 slot reel screen-space scissor OK")
end

return M
