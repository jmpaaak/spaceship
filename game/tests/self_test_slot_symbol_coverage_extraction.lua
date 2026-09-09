local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test slot-symbol-coverage extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_slot_symbol_coverage.lua")

    assert(runner:find('require("game.tests.legacy_slot_symbol_coverage").run()', 1, true),
        "R1-C: self_test must delegate slot-symbol-coverage checks")
    assert(not runner:find("-- INBOX 61(35): slot reels must cover all 5 symbols", 1, true)
            and not runner:find("for roll = 0, tw - 1 do", 1, true),
        "R1-C: slot-symbol-coverage body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted slot-symbol-coverage suite must expose run()")
    assert(suite:find("tw == spinCheck.totalWeight", 1, true)
            and suite:find("for roll = 0, tw - 1 do", 1, true)
            and suite:find("for _, sym in ipairs(expedition.slotSymbols)", 1, true)
            and suite:find("twLuck > tw", 1, true),
        "R1-C: extracted suite must retain weight equivalence, all-symbol reachability, and luck growth")
    print("  R1-C self_test slot-symbol-coverage extraction OK")
end

return M
