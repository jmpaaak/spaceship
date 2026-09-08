local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test loadout-lines extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_loadout_lines.lua")

    assert(runner:find('require("game.tests.legacy_loadout_lines").run()', 1, true),
        "R1-C: self_test must delegate loadout-lines checks")
    assert(not runner:find("local loadoutScene", 1, true),
        "R1-C: loadout-lines characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted loadout-lines suite must expose run()")
    assert(suite:find('starterLoadout.ship == nil', 1, true)
            and suite:find('starterLoadout.stats == "HULL 3"', 1, true)
            and suite:find('starterLoadout.steering == "60"', 1, true),
        "R1-C: extracted suite must retain starter loadout coverage")
    assert(suite:find('upgradedLoadout.ship == "SHIP SCOUT"', 1, true)
            and suite:find('upgradedLoadout.upgrades == "HULL LV.1"', 1, true)
            and suite:find('upgradedLoadout.steering == "181"', 1, true),
        "R1-C: extracted suite must retain purchased scout and upgrade coverage")
    assert(suite:find("expedition.damage(loadoutScene.expedition", 1, true)
            and suite:find('resetLoadout.ship == nil', 1, true)
            and suite:find('resetLoadout.upgrades == "HULL LV.0"', 1, true),
        "R1-C: extracted suite must retain destruction-reset coverage")
    print("  R1-C self_test loadout-lines extraction OK")
end

return M
