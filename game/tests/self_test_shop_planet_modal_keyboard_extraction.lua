local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test shop-planet modal keyboard extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_shop_planet_modal_keyboard.lua")

    assert(runner:find('require("game.tests.legacy_shop_planet_modal_keyboard").run()', 1, true),
        "R1-C: self_test must delegate shop-planet modal keyboard checks")
    assert(not runner:find('fakePlanet = { id = "shop:skip-test"', 1, true)
            and not runner:find("failed buy must keep shopModal open", 1, true)
            and not runner:find("must not trigger settlement sampleYield upgrade", 1, true),
        "R1-C: shop-planet modal keyboard characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted shop-planet modal keyboard suite must expose run()")
    assert(suite:find('keypressed("n")', 1, true)
            and suite:find("skip must not deduct money", 1, true)
            and suite:find('keypressed("y")', 1, true)
            and suite:find("successful buy must clear shopModal", 1, true),
        "R1-C: extracted suite must retain skip and successful-purchase behavior")
    assert(suite:find("failed buy must keep shopModal open", 1, true)
            and suite:find("failed buy must not deduct money", 1, true),
        "R1-C: extracted suite must retain insufficient-funds behavior")
    assert(suite:find("sampleYieldUpgradeLevel == beforeYieldLevel", 1, true),
        "R1-C: extracted suite must retain settlement-shortcut consumption behavior")
    print("  R1-C self_test shop-planet modal keyboard extraction OK")
end

return M