local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test hub-restock extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_hub_restock.lua")

    assert(runner:find('require("game.tests.legacy_hub_restock").run()', 1, true),
        "R1-C: self_test must delegate hub-restock checks")
    assert(not runner:find("-- INBOX 61(16): hub restock button test", 1, true)
            and not runner:find("local ok3, err3 = exp.hubRestock", 1, true),
        "R1-C: hub-restock characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted hub-restock suite must expose run()")
    assert(suite:find("expedition.hubRestock(run, pool, rolls)", 1, true)
            and suite:find("100 - (expedition.hubRestockCost or 5)", 1, true),
        "R1-C: extracted suite must retain hub success and cost-deduction coverage")
    assert(suite:find("lastVisitedGalaxyId = nil", 1, true)
            and suite:find("hubRestock should fail on Earth", 1, true),
        "R1-C: extracted suite must retain Earth rejection coverage")
    assert(suite:find("money = 1", 1, true)
            and suite:find("hubRestock should fail when broke", 1, true),
        "R1-C: extracted suite must retain insufficient-money coverage")
    assert(suite:find('i18n.t("hub_restock_btn", 5)', 1, true),
        "R1-C: extracted suite must retain localized button-copy coverage")
    print("  R1-C self_test hub-restock extraction OK")
end

return M
