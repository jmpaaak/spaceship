local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test solar-system settlement extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_solar_system_settlement.lua")

    assert(runner:find('require("game.tests.legacy_solar_system_settlement").run()', 1, true),
        "R1-C: self_test must delegate solar-system settlement checks")
    assert(not runner:find("-- INBOX 61(5): solarSystem synergy", 1, true)
            and not runner:find('i18n.t("synergy_desc_solarSystem")', 1, true),
        "R1-C: solar-system settlement characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted solar-system settlement suite must expose run()")
    assert(suite:find('enDesc:find("max", 1, true)', 1, true)
            and suite:find('koDesc:find("최대내구", 1, true)', 1, true),
        "R1-C: extracted suite must retain localized max-durability description contracts")
    assert(suite:find("run.maxDurability == 4", 1, true)
            and suite:find("run.durability == 4", 1, true),
        "R1-C: extracted suite must retain max increment, full repair, and clamp contracts")
    print("  R1-C self_test solar-system settlement extraction OK")
end

return M
