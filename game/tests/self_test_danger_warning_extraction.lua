local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test danger-warning extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_danger_warning.lua")

    assert(runner:find('require("game.tests.legacy_danger_warning").run()', 1, true),
        "R1-C: self_test must delegate danger-warning checks")
    assert(not runner:find("-- INBOX 61(22): danger_warning i18n + starDangerTextMultiplier constant", 1, true)
            and not runner:find('local val = i18n.t("danger_warning")', 1, true)
            and not runner:find("world.starWellRadius * world.starDangerTextMultiplier", 1, true),
        "R1-C: danger-warning characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted danger-warning suite must expose run()")
    assert(suite:find('{"en", "ko"}', 1, true)
            and suite:find('i18n.t("danger_warning")', 1, true)
            and suite:find('i18n.t("danger_warning") == "DANGER"', 1, true)
            and suite:find("world.starDangerTextMultiplier > 1", 1, true)
            and suite:find("world.starWellRadius * world.starDangerTextMultiplier", 1, true)
            and suite:find("dangerOuter > world.starWellRadius", 1, true)
            and suite:find('i18n.setLocale("en")', 1, true),
        "R1-C: extracted suite must retain locale, copy, multiplier, outer-radius, and locale-restoration contracts")
    print("  R1-C self_test danger-warning extraction OK")
end

return M
