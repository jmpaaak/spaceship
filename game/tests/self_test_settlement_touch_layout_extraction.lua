local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test settlement touch/layout extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_settlement_touch_layout.lua")

    assert(runner:find('require("game.tests.legacy_settlement_touch_layout").run()', 1, true),
        "R1-C: self_test must delegate settlement touch/layout checks")
    assert(not runner:find("local rowTouchScene = PlayScene.new", 1, true)
            and not runner:find("shopActionColumnW >= 100", 1, true),
        "R1-C: settlement touch/layout characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted settlement touch/layout suite must expose run()")
    assert(suite:find("heightPoints >= 44", 1, true)
            and suite:find("widthPoints >= 44", 1, true),
        "R1-C: extracted suite must retain row and column touch-size checks")
    assert(suite:find("settlementSamplesY %- PlayScene.settlementTotalY")
            and suite:find("shopStatusColumnX >= PlayScene.shopActionColumnX", 1, true),
        "R1-C: extracted suite must retain summary and shop-column spacing checks")
    assert(suite:find("settlementRowBackgroundColor%(1%) ~= PlayScene.settlementRowBackgroundColor%(2%)")
            and suite:find("settlementRowBackgroundColor%(1%) == PlayScene.settlementRowBackgroundColor%(3%)"),
        "R1-C: extracted suite must retain alternating row-background checks")
    assert(suite:find("rowTouchScene:touchpressed", 1, true)
            and suite:find('rowTouchScene.expedition.phase == "ascending"', 1, true),
        "R1-C: extracted suite must retain row-center purchase and relaunch actions")
    print("  R1-C self_test settlement touch/layout extraction OK")
end

return M