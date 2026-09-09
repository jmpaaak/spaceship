local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test pause-menu/title extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_pause_menu_title.lua")

    assert(runner:find('require("game.tests.legacy_pause_menu_title").run()', 1, true),
        "R1-C: self_test must delegate pause-menu/title checks")
    assert(not runner:find("-- INBOX 61(21): pause menu buttons + title scene i18n", 1, true)
            and not runner:find('scene:touchpressed("test-restart"', 1, true)
            and not runner:find("continue must not fire when hasSave=false", 1, true),
        "R1-C: pause-menu/title characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted pause-menu/title suite must expose run()")
    assert(suite:find('{"en", "ko"}', 1, true)
            and suite:find('"pause_restart", "pause_main_menu"', 1, true)
            and suite:find("PlayScene.pauseMenuRects()", 1, true)
            and suite:find('scene:touchpressed("test-restart"', 1, true)
            and suite:find('scene2:touchpressed("test-menu"', 1, true)
            and suite:find("title:buttonRects()", 1, true)
            and suite:find('title:touchpressed("test-start"', 1, true)
            and suite:find("continue must not fire when hasSave=false", 1, true)
            and suite:find("continue must fire when hasSave=true", 1, true),
        "R1-C: extracted suite must retain i18n, geometry, pause actions, start, and continue-state contracts")
    print("  R1-C self_test pause-menu/title extraction OK")
end

return M
