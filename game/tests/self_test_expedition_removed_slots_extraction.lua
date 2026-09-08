local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test removed expedition slots extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_expedition_removed_slots.lua")

    assert(runner:find('require("game.tests.legacy_expedition_removed_slots").run()', 1, true),
        "R1-C: self_test must delegate removed expedition slot-state checks")
    assert(not runner:find("expedition.buyFuelUpgrade == nil", 1, true)
            and not runner:find("run.slotOpportunities == nil", 1, true)
            and not runner:find("run.slotDistance == nil", 1, true),
        "R1-C: removed expedition slot-state characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted removed expedition slots suite must expose run()")
    assert(suite:find('require("game.expedition")', 1, true)
            and suite:find("expedition.buyFuelUpgrade == nil", 1, true)
            and suite:find("run.slotOpportunities == nil", 1, true)
            and suite:find("run.slotDistance == nil", 1, true),
        "R1-C: extracted suite must retain all three abolished-state contracts")
    print("  R1-C self_test removed expedition slots extraction OK")
end

return M