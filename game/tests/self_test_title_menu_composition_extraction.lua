local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test title-menu composition extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_title_menu_composition.lua")

    assert(runner:find('require("game.tests.legacy_title_menu_composition").run()', 1, true),
        "R1-C: self_test must delegate title-menu composition checks")
    assert(not runner:find("-- INBOX 61(24b): Title menu composition", 1, true)
            and not runner:find('t2:touchpressed("test-ng"', 1, true),
        "R1-C: title-menu composition body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted title-menu suite must expose run()")
    assert(suite:find("r1.continue_.y < r1.newGame.y", 1, true)
            and suite:find('t2:touchpressed("test-ng"', 1, true)
            and suite:find('t3:touchpressed("test-legacy"', 1, true)
            and suite:find('t5:touchpressed("test-c2"', 1, true)
            and suite:find("store:reset()", 1, true)
            and suite:find("cs:reset()", 1, true)
            and suite:find('i18n.t("title_new_game")', 1, true),
        "R1-C: extracted suite must retain order, callback, reset, and i18n contracts")
    print("  R1-C self_test title-menu composition extraction OK")
end

return M
