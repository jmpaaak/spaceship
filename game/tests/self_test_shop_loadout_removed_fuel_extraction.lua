local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test removed fuel shop-loadout extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_shop_loadout_removed_fuel.lua")

    assert(runner:find('require("game.tests.legacy_shop_loadout_removed_fuel").run()', 1, true),
        "R1-C: self_test must delegate removed fuel shop-loadout checks")
    assert(not runner:find("loadout.fuelAction == nil", 1, true)
            and not runner:find("loadout.fuelStatus == nil", 1, true)
            and not runner:find("loadout.fuelAffordable == nil", 1, true)
            and not runner:find("loadout.fuelPreview == nil", 1, true),
        "R1-C: removed fuel shop-loadout characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted removed fuel shop-loadout suite must expose run()")
    assert(suite:find('require("game.scenes.play")', 1, true)
            and suite:find("loadout.fuelAction == nil", 1, true)
            and suite:find("loadout.fuelStatus == nil", 1, true)
            and suite:find("loadout.fuelAffordable == nil", 1, true)
            and suite:find("loadout.fuelPreview == nil", 1, true),
        "R1-C: extracted suite must retain all four abolished fuel fields")
    assert(suite:find("loadout.hullAction ~= nil", 1, true)
            and suite:find("loadout.yieldAction ~= nil", 1, true)
            and suite:find("loadout.steeringAction ~= nil", 1, true),
        "R1-C: extracted suite must retain all three remaining upgrade rows")
    print("  R1-C self_test removed fuel shop-loadout extraction OK")
end

return M
