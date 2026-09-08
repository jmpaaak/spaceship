local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test panel sprite extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_panel_sprite.lua")

    assert(runner:find('require("game.tests.legacy_panel_sprite").run()', 1, true),
        "R1-C: self_test must delegate panel sprite checks")
    assert(not runner:find("drawPanelSprite must be exported on PlayScene", 1, true)
            and not runner:find("launchRocketIconImage", 1, true),
        "R1-C: panel sprite characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted panel sprite suite must expose run()")
    assert(suite:find("drawPanelSprite(nil,...) must return false", 1, true)
            and suite:find("love.graphics == previousGraphics", 1, true)
            and suite:find("relaunChImage", 1, true),
        "R1-C: extracted suite must retain false-return, graphics restoration, and image-slot contracts")
    print("  R1-C self_test panel sprite extraction OK")
end

return M
