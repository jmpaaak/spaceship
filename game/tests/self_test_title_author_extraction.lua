local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test title-author extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_title_author.lua")

    assert(runner:find('require("game.tests.legacy_title_author").run()', 1, true),
        "R1-C: self_test must delegate title-author checks")
    assert(not runner:find("-- INBOX-61(30): Jimmy's author line on title screen", 1, true)
            and not runner:find('i18n.t("title_author")', 1, true),
        "R1-C: title-author body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted title-author suite must expose run()")
    assert(suite:find('i18n.setLocale("en")', 1, true)
            and suite:find('i18n.setLocale("ko")', 1, true)
            and suite:find('i18n.t("title_author") == "Jimmy\'s"', 1, true),
        "R1-C: extracted suite must retain EN/KO checks and locale restoration")
    print("  R1-C self_test title-author extraction OK")
end

return M