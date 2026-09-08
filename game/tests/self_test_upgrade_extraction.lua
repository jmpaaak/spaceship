local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test upgrade extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_expedition_upgrades.lua")

    assert(runner:find('require("game.tests.legacy_expedition_upgrades").run()', 1, true),
        "R1-C: self_test must delegate durability and sample-yield upgrade checks")
    assert(not runner:find("local hullShopRun", 1, true),
        "R1-C: durability and sample-yield characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted expedition upgrade suite must expose run()")
    assert(suite:find("hullShopRun.durability == 3", 1, true),
        "R1-C: extracted suite must retain upgraded durability launch coverage")
    assert(suite:find("awarded == 25", 1, true),
        "R1-C: extracted suite must retain upgraded sample award coverage")
    assert(suite:find('yieldRun.phase == "destroyed"', 1, true),
        "R1-C: extracted suite must retain destruction reset coverage")
    print("  R1-C self_test upgrade extraction OK")
end

return M
