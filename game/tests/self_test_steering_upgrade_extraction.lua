local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test steering-upgrade extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_steering_upgrade.lua")

    assert(runner:find('require("game.tests.legacy_steering_upgrade").run()', 1, true),
        "R1-C: self_test must delegate steering-upgrade checks")
    assert(not runner:find("local steeringRun", 1, true),
        "R1-C: steering-upgrade characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted steering-upgrade suite must expose run()")
    assert(suite:find("buySteeringUpgrade(steeringRun)", 1, true),
        "R1-C: extracted suite must retain purchase gating coverage")
    assert(suite:find("expedition.launch(steeringRun)", 1, true),
        "R1-C: extracted suite must retain relaunch persistence coverage")
    assert(suite:find('steeringRun.phase == "destroyed"', 1, true),
        "R1-C: extracted suite must retain destruction reset coverage")
    assert(suite:find("steeringMoveScene:update(1)", 1, true),
        "R1-C: extracted suite must retain effective movement-speed coverage")
    assert(suite:find('steeringShopScene:keypressed("g")', 1, true),
        "R1-C: extracted suite must retain settlement keyboard-purchase coverage")
    print("  R1-C self_test steering-upgrade extraction OK")
end

return M
