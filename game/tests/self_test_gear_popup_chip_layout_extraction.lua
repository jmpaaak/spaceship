local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test gear-popup chip layout extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_gear_popup_chip_layout.lua")

    assert(runner:find('require("game.tests.legacy_gear_popup_chip_layout").run()', 1, true),
        "R1-C: self_test must delegate gear-popup chip layout checks")
    assert(not runner:find("-- INBOX 61(7): gear popup chips must be vertical", 1, true)
            and not runner:find("PlayScene.gearPopupChipVertical == true", 1, true),
        "R1-C: gear-popup chip layout characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted gear-popup chip layout suite must expose run()")
    assert(suite:find("PlayScene.gearPopupChipVertical == true", 1, true),
        "R1-C: extracted suite must retain the vertical chip-stack contract")
    print("  R1-C self_test gear-popup chip layout extraction OK")
end

return M
