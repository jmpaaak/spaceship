local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test leaderboard-client extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_leaderboard_client.lua")

    assert(runner:find('require("game.tests.legacy_leaderboard_client").run()', 1, true),
        "R1-C: self_test must delegate leaderboard-client checks")
    assert(not runner:find("-- ===== INBOX 61(23b): Leaderboard client auto-post on settle/destroy =====", 1, true)
            and not runner:find('local lbClient = require("game.leaderboard_client")', 1, true)
            and not runner:find('lbClient.submitScore("TestPlayer", 1000)', 1, true),
        "R1-C: leaderboard-client characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted leaderboard-client suite must expose run()")
    assert(suite:find('require("game.leaderboard_client")', 1, true)
            and suite:find('type(lbClient.submitScore) == "function"', 1, true)
            and suite:find('type(lbClient.isNewBest) == "function"', 1, true)
            and suite:find("bestAltitude = 500, launchBestAltitude = 400", 1, true)
            and suite:find("bestAltitude = 300, launchBestAltitude = 400", 1, true)
            and suite:find("bestAltitude = 400, launchBestAltitude = 400", 1, true)
            and suite:find('lbClient.submitScore("TestPlayer", 1000)', 1, true)
            and suite:find('require("game.scenes.play")', 1, true),
        "R1-C: extracted suite must retain API, new-best comparisons, headless submission, and PlayScene load contracts")
    print("  R1-C self_test leaderboard-client extraction OK")
end

return M
