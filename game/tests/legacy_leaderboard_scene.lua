local M = {}

-- INBOX 61(23): Leaderboard button + scene + config
function M.run()
    print("  [INBOX 61(23)] leaderboard button + scene + config")

    local i18n = require("game.i18n")
    local TitleScene = require("game.scenes.title")

    -- (a) i18n keys exist for both locales
    local leaderboardKeys = {
        "title_leaderboard", "leaderboard_title", "leaderboard_empty",
        "leaderboard_back", "leaderboard_rank", "leaderboard_loading",
        "leaderboard_error",
    }
    for _, loc in ipairs({"en", "ko"}) do
        i18n.setLocale(loc)
        for _, key in ipairs(leaderboardKeys) do
            assert(i18n.t(key) ~= key,
                "INBOX 61(23): i18n key '" .. key .. "' missing for locale " .. loc)
        end
    end
    i18n.setLocale("en")

    -- (b) TitleScene has leaderboard button rect
    local title = TitleScene.new({
        hasSave = false,
        onStart = function() end,
        onContinue = function() end,
        onLeaderboard = function() end,
    })
    local tRects = title:buttonRects()
    assert(tRects.leaderboard,
        "INBOX 61(23): TitleScene:buttonRects must include leaderboard")
    assert(tRects.leaderboard.y > tRects.continue_.y,
        "INBOX 61(23): leaderboard button must be below continue button")
    assert(tRects.leaderboard.y < tRects.settings.y,
        "INBOX 61(23): leaderboard button must be above settings button")

    -- (c) TitleScene leaderboard tap fires callback
    local lbCalled = false
    local title2 = TitleScene.new({
        hasSave = false,
        onStart = function() end,
        onLeaderboard = function() lbCalled = true end,
    })
    local lbRect = title2:buttonRects().leaderboard
    title2:touchpressed("test", lbRect.x + 1, lbRect.y + 1)
    assert(lbCalled, "INBOX 61(23): tapping leaderboard button must call onLeaderboard")

    -- (d) LeaderboardScene exists and has required methods
    local LeaderboardScene = require("game.scenes.leaderboard")
    local backCalled = false
    local lb = LeaderboardScene.new({
        onBack = function() backCalled = true end,
    })
    assert(lb, "INBOX 61(23): LeaderboardScene.new must return an object")
    assert(lb.backButtonRect, "INBOX 61(23): LeaderboardScene must have backButtonRect")
    assert(lb.state == "loaded" or lb.state == "loading",
        "INBOX 61(23): initial state must be loaded or loading")
    local backRect = lb:backButtonRect()
    lb:touchpressed("test", backRect.x + 1, backRect.y + 1)
    assert(backCalled, "INBOX 61(23): tapping back button must call onBack")

    -- (e) _parseScores works
    local scores = LeaderboardScene._parseScores(
        '[{"name":"Alice","bestAltitude":500},{"name":"Bob","bestAltitude":1000}]')
    assert(#scores == 2, "INBOX 61(23): _parseScores must parse 2 entries")
    assert(scores[1].name == "Bob", "INBOX 61(23): scores must be sorted desc")
    assert(scores[1].rank == 1, "INBOX 61(23): first score must be rank 1")
    assert(scores[2].rank == 2, "INBOX 61(23): second score must be rank 2")

    -- (f) game_config module exists with leaderboardUrl
    local gameConfig = require("game.game_config")
    assert(type(gameConfig.leaderboardUrl) == "string",
        "INBOX 61(23): game_config.leaderboardUrl must be a string")
    assert(gameConfig.leaderboardUrl:find("8770"),
        "INBOX 61(23): leaderboardUrl must include port 8770")

    -- (g) keypressed escape triggers back
    local backCalled2 = false
    local lb2 = LeaderboardScene.new({
        onBack = function() backCalled2 = true end,
    })
    lb2:keypressed("escape")
    assert(backCalled2, "INBOX 61(23): escape key must call onBack")

    print("  INBOX-61(23) leaderboard button + scene + config OK")
end

return M