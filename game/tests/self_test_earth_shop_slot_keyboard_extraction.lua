local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test Earth-shop slot keyboard extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_earth_shop_slot_keyboard.lua")

    assert(runner:find('require("game.tests.legacy_earth_shop_slot_keyboard").run()', 1, true),
        "R1-C: self_test must delegate Earth-shop slot keyboard checks")
    assert(not runner:find("winning spin must be money - cost + reward", 1, true)
            and not runner:find("earthSlotSpin must not be called outside settlement phase", 1, true)
            and not runner:find("rolls.reels must have exactly 3 entries", 1, true),
        "R1-C: Earth-shop slot keyboard characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted Earth-shop slot keyboard suite must expose run()")
    assert(suite:find("earthShopSlotResult ~= nil", 1, true)
            and suite:find("winning spin must be money - cost + reward", 1, true)
            and suite:find("slotResultMessage", 1, true),
        "R1-C: extracted suite must retain result, money, and reward-message behavior")
    assert(suite:find("earthShopSlotResult == nil", 1, true)
            and suite:find("earthSlotSpin must not be called outside settlement phase", 1, true),
        "R1-C: extracted suite must retain outside-settlement no-op behavior")
    assert(suite:find("capturedRolls.reels ~= nil", 1, true)
            and suite:find("#capturedRolls.reels == 3", 1, true),
        "R1-C: extracted suite must retain the { reels = {...} } argument contract")
    print("  R1-C self_test Earth-shop slot keyboard extraction OK")
end

return M