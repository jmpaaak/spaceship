local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test leaderboard-scene extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_leaderboard_scene.lua")

    assert(runner:find('require("game.tests.legacy_leaderboard_scene").run()', 1, true),
        "R1-C: self_test must delegate leaderboard scene checks")
    assert(not runner:find("-- ===== INBOX 61(23): Leaderboard button + scene + config =====", 1, true)
            and not runner:find("local leaderboardKeys =", 1, true)
            and not runner:find("LeaderboardScene._parseScores", 1, true),
        "R1-C: leaderboard scene characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted leaderboard scene suite must expose run()")
    assert(suite:find('{"en", "ko"}', 1, true)
            and suite:find('"title_leaderboard", "leaderboard_title", "leaderboard_empty"', 1, true)
            and suite:find("tRects.leaderboard.y > tRects.continue_.y", 1, true)
            and suite:find("tRects.leaderboard.y < tRects.settings.y", 1, true)
            and suite:find("onLeaderboard = function() lbCalled = true end", 1, true)
            and suite:find('require("game.scenes.leaderboard")', 1, true)
            and suite:find("LeaderboardScene._parseScores", 1, true)
            and suite:find('require("game.game_config")', 1, true)
            and suite:find('gameConfig.leaderboardUrl:find("8770")', 1, true)
            and suite:find('lb2:keypressed("escape")', 1, true)
            and suite:find('i18n.setLocale("en")', 1, true),
        "R1-C: extracted suite must retain locale, title layout/touch, scene, parsing, back, and config contracts")
    print("  R1-C self_test leaderboard-scene extraction OK")
end

return M