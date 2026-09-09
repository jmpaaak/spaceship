local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test play-gameover extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_play_gameover_extraction.lua")

    assert(runner:find('require("game.tests.legacy_play_gameover_extraction").run()', 1, true),
        "R1-C: self_test must delegate play-gameover extraction checks")
    assert(not runner:find("-- INBOX 61(32) play_gameover.lua extraction test", 1, true)
            and not runner:find('goSrc:find("destroyedPanelY"', 1, true),
        "R1-C: play-gameover extraction body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted play-gameover suite must expose run()")
    assert(suite:find('type(PlayScene.destroyedRestartTextY) == "function"', 1, true)
            and suite:find('type(PlayScene.handleDestroyedTouch) == "function"', 1, true)
            and suite:find('goSrc:find("destroyedPanelY"', 1, true)
            and suite:find('not playSrc:find("function M%.drawBalatroCard")', 1, true),
        "R1-C: extracted suite must retain installed methods, source location, and removed-inline checks")
    print("  R1-C self_test play-gameover extraction OK")
end

return M