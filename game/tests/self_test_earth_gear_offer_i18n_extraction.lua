local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test Earth gear-offer i18n extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_earth_gear_offer_i18n.lua")

    assert(runner:find('require("game.tests.legacy_earth_gear_offer_i18n").run()', 1, true),
        "R1-C: self_test must delegate Earth gear-offer i18n checks")
    assert(not runner:find("-- INBOX 61(20): earth_gear_offer", 1, true)
            and not runner:find('i18n.t("earth_gear_offer", "TestGear", 100)', 1, true),
        "R1-C: Earth gear-offer i18n characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted Earth gear-offer i18n suite must expose run()")
    assert(suite:find('i18n.setLocale("en")', 1, true)
            and suite:find('not en:find("%[B%]")', 1, true)
            and suite:find('en:find("GEAR OFFER:")', 1, true)
            and suite:find('not ko:find("%[B%]")', 1, true)
            and suite:find('ko:find("장비 제안:")', 1, true)
            and suite:find('i18n.setLocale("en")  -- restore', 1, true),
        "R1-C: extracted suite must retain EN/KO prefix, localized-label, and locale-restoration coverage")
    print("  R1-C self_test Earth gear-offer i18n extraction OK")
end

return M