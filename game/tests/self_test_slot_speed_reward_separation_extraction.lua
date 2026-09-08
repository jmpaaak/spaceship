local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test slot-speed reward separation extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_slot_speed_reward_separation.lua")

    assert(runner:find('require("game.tests.legacy_slot_speed_reward_separation").run()', 1, true),
        "R1-C: self_test must delegate slot-speed reward separation checks")
    assert(not runner:find("-- INBOX 61(19): slot speed reward", 1, true)
            and not runner:find("run.slotSpeedBonus = (run.slotSpeedBonus or 0) + 20", 1, true),
        "R1-C: slot-speed reward separation characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted slot-speed reward separation suite must expose run()")
    assert(suite:find("run.steeringUpgradeLevel == 2", 1, true)
            and suite:find("costAfterShop == costAfterSlot", 1, true)
            and suite:find("exp.effectiveSpeed(run)", 1, true)
            and suite:find("run.slotSpeedBonus == 0", 1, true),
        "R1-C: extracted suite must retain shop level/cost, effective-speed, and destruction-reset coverage")
    print("  R1-C self_test slot-speed reward separation extraction OK")
end

return M