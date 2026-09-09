local M = {}

-- INBOX 61(24b): Title menu composition — CONTINUE / NEW GAME / LEADERBOARD / SETTINGS
function M.run()
    local TitleScene = require("game.scenes.title")

    -- (a) buttonRects order: continue_ is above newGame
    local t1 = TitleScene.new({ hasSave = true })
    local r1 = t1:buttonRects()
    assert(r1.continue_ and r1.newGame and r1.leaderboard and r1.settings,
        "INBOX 61(24b): buttonRects must contain continue_/newGame/leaderboard/settings")
    assert(r1.continue_.y < r1.newGame.y,
        "INBOX 61(24b): CONTINUE must be above NEW GAME")
    assert(r1.newGame.y < r1.leaderboard.y,
        "INBOX 61(24b): NEW GAME must be above LEADERBOARD")
    -- rects.start is legacy alias for newGame
    assert(r1.start == r1.newGame,
        "INBOX 61(24b): rects.start must alias rects.newGame")

    -- (b) onNewGame fires when tapping newGame rect
    local newGameCalled = false
    local t2 = TitleScene.new({
        hasSave = false,
        onNewGame = function() newGameCalled = true end,
    })
    local r2 = t2:buttonRects()
    t2:touchpressed("test-ng", r2.newGame.x + 10, r2.newGame.y + 10)
    assert(newGameCalled, "INBOX 61(24b): tapping NEW GAME must call onNewGame")

    -- (c) onStart legacy fallback fires when no onNewGame
    local startCalled = false
    local t3 = TitleScene.new({
        hasSave = false,
        onStart = function() startCalled = true end,
    })
    t3:touchpressed("test-legacy", r2.newGame.x + 10, r2.newGame.y + 10)
    assert(startCalled, "INBOX 61(24b): onStart legacy fallback must fire")

    -- (d) CONTINUE disabled when hasSave=false, enabled when true
    local contCalled = false
    local t4 = TitleScene.new({
        hasSave = false,
        onContinue = function() contCalled = true end,
    })
    t4:touchpressed("test-c1", r2.continue_.x + 10, r2.continue_.y + 10)
    assert(not contCalled, "INBOX 61(24b): CONTINUE must not fire when hasSave=false")
    local t5 = TitleScene.new({
        hasSave = true,
        onContinue = function() contCalled = true end,
    })
    t5:touchpressed("test-c2", r2.continue_.x + 10, r2.continue_.y + 10)
    assert(contCalled, "INBOX 61(24b): CONTINUE must fire when hasSave=true")

    -- (e) best_altitude_store:reset wipes altitude
    local bestAltStore = require("game.best_altitude_store")
    local altData = {}
    local fakeFS = {
        read = function(fn) return altData[fn] end,
        write = function(fn, d) altData[fn] = d; return true end,
    }
    local store = bestAltStore.new("test-best.txt", fakeFS)
    store:save(500)
    assert(store:load() == 500, "INBOX 61(24b): store must save 500")
    store:reset()
    assert(store:load() == 0, "INBOX 61(24b): reset must return 0")

    -- (f) collection_store:reset wipes specimens
    local collStore = require("game.collection_store")
    local specData = {}
    local fakeFS2 = {
        read = function(fn) return specData[fn] end,
        write = function(fn, d) specData[fn] = d; return true end,
    }
    local cs = collStore.new("test-spec.txt", fakeFS2)
    cs:record("solar_common")
    local loaded = cs:load()
    assert(loaded["solar_common"], "INBOX 61(24b): collection must record specimen")
    cs:reset()
    local loaded2 = cs:load()
    assert(not loaded2["solar_common"], "INBOX 61(24b): reset must wipe specimens")

    -- (g) i18n keys exist
    local i18n = require("game.i18n")
    i18n.setLocale("en")
    assert(i18n.t("title_new_game") == "NEW GAME",
        "INBOX 61(24b): EN title_new_game must be 'NEW GAME'")
    i18n.setLocale("ko")
    assert(i18n.t("title_new_game") == "새 게임",
        "INBOX 61(24b): KO title_new_game must be '새 게임'")
    -- Restore locale for remaining tests
    i18n.setLocale("en")

    print("  INBOX-61(24b) title menu composition OK")
end

return M
