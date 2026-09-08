local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test pause-time-freeze extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_pause_time_freeze.lua")

    assert(runner:find('require("game.tests.legacy_pause_time_freeze").run()', 1, true),
        "R1-C: self_test must delegate pause-time-freeze checks")
    assert(not runner:find("-- INBOX 61(10): paused/gearPopup must NOT increment self.time", 1, true)
            and not runner:find('"INBOX 61(10): PlayScene.update must be a function"', 1, true),
        "R1-C: pause-time-freeze characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted pause-time-freeze suite must expose run()")
    assert(suite:find('type(PlayScene.update) == "function"', 1, true),
        "R1-C: extracted suite must retain the PlayScene.update function contract")
    print("  R1-C self_test pause-time-freeze extraction OK")
end

return M
