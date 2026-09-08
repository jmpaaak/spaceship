local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test dead settlement-slot fields extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_dead_settlement_slot_fields.lua")

    assert(runner:find('require("game.tests.legacy_dead_settlement_slot_fields").run()', 1, true),
        "R1-C: self_test must delegate dead settlement-slot field checks")
    assert(not runner:find("settlement panel must NOT show a dead slot-spin line", 1, true)
            and not runner:find("lastLostSlotSpinsCount must not exist", 1, true),
        "R1-C: dead settlement-slot field characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted dead settlement-slot field suite must expose run()")
    assert(suite:find("lastSlotSpinsCount == nil", 1, true)
            and suite:find("lastSlotSettlement == nil", 1, true)
            and suite:find("lastLostSlotValue == nil", 1, true)
            and suite:find("lastLostSlotSpinsCount == nil", 1, true),
        "R1-C: extracted suite must retain all four dead-field nil contracts")
    print("  R1-C self_test dead settlement-slot fields extraction OK")
end

return M