local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test hub-relaunch-regen extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_hub_relaunch_regen.lua")

    assert(runner:find('require("game.tests.legacy_hub_relaunch_regen").run()', 1, true),
        "R1-C: self_test must delegate hub-relaunch-regen checks")
    assert(not runner:find("-- INBOX 61(31): hub relaunch does not full-heal", 1, true)
            and not runner:find('id = "hull_nano_mesh"', 1, true),
        "R1-C: hub-relaunch-regen body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted hub-relaunch-regen suite must expose run()")
    assert(suite:find('run.lastVisitedGalaxyId = "andromeda"', 1, true)
            and suite:find("earthRun.lastVisitedGalaxyId = nil", 1, true)
            and suite:find("expedition.update(regenRun, 2.1)", 1, true)
            and suite:find('i18n.effectLine({ type = "hullRegen", value = 0.5 })', 1, true),
        "R1-C: extracted suite must retain hub, Earth, regen timing, and display fixtures")
    print("  R1-C self_test hub-relaunch-regen extraction OK")
end

return M