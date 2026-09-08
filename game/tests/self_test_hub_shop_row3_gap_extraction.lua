local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test hub-shop row-3 gap extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_hub_shop_row3_gap.lua")

    assert(runner:find('require("game.tests.legacy_hub_shop_row3_gap").run()', 1, true),
        "R1-C: self_test must delegate hub-shop row-3 gap checks")
    assert(not runner:find("-- INBOX 61(18): hub shop row3", 1, true)
            and not runner:find("local row3H = rows[3].bottom - rows[3].top", 1, true),
        "R1-C: hub-shop row-3 gap characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted hub-shop row-3 gap suite must expose run()")
    assert(suite:find("row3H < 100", 1, true)
            and suite:find("rows[4].top == rows[3].bottom", 1, true)
            and suite:find("rows[#rows].bottom <= PlayScene.settlementPanelTop", 1, true),
        "R1-C: extracted suite must retain gear-row height, contiguous-row, and panel-bounds coverage")
    print("  R1-C self_test hub-shop row-3 gap extraction OK")
end

return M