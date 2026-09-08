local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test HUD sprite fallback extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_hud_sprite_fallback.lua")

    assert(runner:find('require("game.tests.legacy_hud_sprite_fallback").run()', 1, true),
        "R1-C: self_test must delegate HUD sprite fallback checks")
    assert(not runner:find("drawHudSpriteOrPoly must be exported on PlayScene", 1, true)
            and not runner:find("drawHudSpriteOrPoly(nil,nil,...) must not throw", 1, true),
        "R1-C: HUD sprite fallback characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted HUD sprite fallback suite must expose run()")
    assert(suite:find("drawHudSpriteOrPoly must be exported on PlayScene", 1, true)
            and suite:find("drawHudSpriteOrPoly(nil,nil,...) must not throw", 1, true),
        "R1-C: extracted suite must retain export and no-throw fallback contracts")
    print("  R1-C self_test HUD sprite fallback extraction OK")
end

return M