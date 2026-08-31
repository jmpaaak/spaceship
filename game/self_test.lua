local viewport = require("game.viewport")
local player = require("game.player")
local M = {}

function M.run()
    local scale, x, y = viewport.fit(1280, 720, false)
    assert(scale == 4 and x == 0 and y == 0)
    local gx, gy, inside = viewport.toGame(640, 360, 1280, 720, false)
    assert(gx == 160 and gy == 90 and inside)

    local actor = player.new()
    player.update(actor, 1, { right = true })
    assert(actor.x == 232 and actor.y == 90)
    player.update(actor, 10, { left = true, up = true })
    assert(actor.x == 5 and actor.y == 5)
    print("LOVE2D_GAME_SKELETON_UNIT_OK")
end

return M
