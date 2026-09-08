local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test Earth-shop gear-offer keyboard extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_earth_shop_gear_offer_keyboard.lua")

    assert(runner:find('require("game.tests.legacy_earth_shop_gear_offer_keyboard").run()', 1, true),
        "R1-C: self_test must delegate Earth-shop gear-offer keyboard checks")
    assert(not runner:find("hull_7c_test_fixture", 1, true)
            and not runner:find("successful buy must clear earthShopGearOffer", 1, true),
        "R1-C: Earth-shop gear-offer keyboard characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted Earth-shop gear-offer keyboard suite must expose run()")
    assert(suite:find("successful buy must clear earthShopGearOffer", 1, true)
            and suite:find("insufficient-money buy must preserve earthShopGearOffer", 1, true)
            and suite:find("full-slots buy must preserve earthShopGearOffer", 1, true)
            and suite:find("outside settlement must not consume earthShopGearOffer", 1, true)
            and suite:find("relaunch must clear earthShopGearOffer", 1, true),
        "R1-C: extracted suite must retain all five gear-offer keyboard contracts")
    print("  R1-C self_test Earth-shop gear-offer keyboard extraction OK")
end

return M
