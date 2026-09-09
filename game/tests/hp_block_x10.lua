local M = {}
function M.run()
    print("  [INBOX 65] hp_block_x10 tests...")
    
    local play_scene_draw = require("game.scenes.play_scene_draw")
    local hud_draw = nil
    -- We can extract the function body and check if "x10" is printed.
    local body, err = love.filesystem.read("game/scenes/play_scene_draw.lua")
    assert(body, "cannot read play_scene_draw.lua")
    
    local found_x10 = body:find('love.graphics.print%("x10"') or body:find("love.graphics.print%('x10'")
    assert(found_x10, "INBOX 65: x10 text must be printed for maxDurability >= 10")
    
    local found_11 = body:find("fonts.get%((.-11.-)%)")
    assert(found_11, "INBOX 65: x10 text must use Galmuri 11px font or multiple")

    print("  INBOX 65 hp_block_x10 OK")
end
return M
