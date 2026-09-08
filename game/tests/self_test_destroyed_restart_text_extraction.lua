local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test destroyed restart-text extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_destroyed_restart_text.lua")

    assert(runner:find('require("game.tests.legacy_destroyed_restart_text").run()', 1, true),
        "R1-C: self_test must delegate destroyed restart-text checks")
    assert(not runner:find("-- INBOX 61(17): destroyed screen restart text Y position", 1, true)
            and not runner:find("local emptyY = PlayScene.destroyedRestartTextY(false)", 1, true),
        "R1-C: destroyed restart-text characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted destroyed restart-text suite must expose run()")
    assert(suite:find("panelCenter - 11", 1, true)
            and suite:find("PlayScene.destroyedPanelH - 72", 1, true)
            and suite:find("emptyY < itemsY", 1, true),
        "R1-C: extracted suite must retain empty centering, populated bottom, and vertical-order coverage")
    print("  R1-C self_test destroyed restart-text extraction OK")
end

return M
