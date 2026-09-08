local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test Earth-slot reward-profile extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_earth_slot_reward_profile.lua")

    assert(runner:find('require("game.tests.legacy_earth_slot_reward_profile").run()', 1, true),
        "R1-C: self_test must delegate Earth-slot reward-profile checks")
    assert(not runner:find("earthSlotSpin rewardProfile is a string", 1, true)
            and not runner:find("ODDS label removed, badge must be nil", 1, true),
        "R1-C: Earth-slot reward-profile characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted Earth-slot reward-profile suite must expose run()")
    assert(suite:find('earthSlotProfileLabel("solar") == nil', 1, true)
            and suite:find("earthSlotProfileLabel(nil) == nil", 1, true)
            and suite:find('earthSlotProfileLabel("") == nil', 1, true),
        "R1-C: extracted suite must retain removed-ODDS-label nil behavior")
    assert(suite:find("earthShopSlotResult ~= nil", 1, true)
            and suite:find('rewardProfile = "void"', 1, true)
            and suite:find('type(scene.earthShopSlotResult.rewardProfile) == "string"', 1, true),
        "R1-C: extracted suite must retain settlement storage and string profile shape")
    print("  R1-C self_test Earth-slot reward-profile extraction OK")
end

return M