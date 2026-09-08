local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test settlement-shop-input extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_settlement_shop_input.lua")

    assert(runner:find('require("game.tests.legacy_settlement_shop_input").run()', 1, true),
        "R1-C: self_test must delegate settlement shop input checks")
    assert(not runner:find("local scoutHullMessageScene", 1, true)
            and not runner:find("local repeatedUpgradeMessageScene", 1, true)
            and not runner:find("local shortfallScene", 1, true),
        "R1-C: settlement shop input characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted settlement shop input suite must expose run()")
    assert(suite:find('shopScene:keypressed("h")', 1, true)
            and suite:find('shopScene:keypressed("y")', 1, true)
            and suite:find('shopScene:touchpressed("ship", 540, 670)', 1, true),
        "R1-C: extracted suite must retain keyboard and touch purchase coverage")
    assert(suite:find("scoutHullMessageScene.expedition.maxDurability == 2", 1, true),
        "R1-C: extracted suite must retain scout hull stat coverage")
    assert(suite:find("repeatedUpgradeMessageScene.expedition.money == 229", 1, true),
        "R1-C: extracted suite must retain repeated-upgrade pricing coverage")
    assert(suite:find("not shortfallScene.expedition.ownedShips.scout", 1, true),
        "R1-C: extracted suite must retain insufficient-funds gating")
    assert(suite:find('shortfallScene.message == ""', 1, true),
        "R1-C: extracted suite must retain empty-message behavior")
    print("  R1-C self_test settlement-shop-input extraction OK")
end

return M