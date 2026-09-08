local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test in-flight slot i18n extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_inflight_slot_i18n.lua")

    assert(runner:find('require("game.tests.legacy_inflight_slot_i18n").run()', 1, true),
        "R1-C: self_test must delegate in-flight slot i18n checks")
    assert(not runner:find('"slot_spin_prompt", "slot_result_repair"', 1, true)
            and not runner:find("pcall(i18n.t, key)", 1, true),
        "R1-C: in-flight slot i18n characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted in-flight slot i18n suite must expose run()")
    assert(suite:find('"slot_spin_prompt", "slot_result_repair"', 1, true)
            and suite:find('"button_left", "button_right", "slot_odds_line"', 1, true)
            and suite:find("pcall(i18n.t, key)", 1, true),
        "R1-C: extracted suite must retain the complete missing-key contract")
    assert(suite:find('{ "en", "ko" }', 1, true)
            and suite:find("i18n.setLocale(locale)", 1, true)
            and suite:find('i18n.t("returning_message")', 1, true)
            and suite:find('returningMessage:upper():find("SLOT"', 1, true)
            and suite:find('returningMessage:find("슬롯"', 1, true),
        "R1-C: extracted suite must retain both slot-free returning-message checks")
    print("  R1-C self_test in-flight slot i18n extraction OK")
end

return M