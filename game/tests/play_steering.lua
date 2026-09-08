local steering = require("game.scenes.play_steering")

local M = {}

local function near(actual, expected)
    return math.abs(actual - expected) < 0.000001
end

function M.run()
    print("  [R1] play_steering module tests...")

    assert(near(steering.headingFromStick(1, 0), 0)
            and near(steering.headingFromStick(0, 1), math.pi / 2)
            and near(steering.headingFromStick(-1, 0), math.pi),
        "R1: stick heading must retain full-circle atan2 direction")
    assert(near(steering.headingFromStick(nil, nil), 0),
        "R1: missing stick components must retain the zero heading fallback")

    assert(near(steering.shortestAngleDelta(0, math.pi / 2), math.pi / 2)
            and near(steering.shortestAngleDelta(0, 3 * math.pi / 2), -math.pi / 2)
            and near(steering.shortestAngleDelta(3 * math.pi / 2, 0), math.pi / 2),
        "R1: angle delta must choose the shortest wrapped rotation")

    local api = {}
    steering.install(api)
    assert(api.headingFromStick == steering.headingFromStick
            and api.shortestAngleDelta == steering.shortestAngleDelta,
        "R1: installed scene API must expose steering rules")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_steering"%)'),
        "R1: play.lua must delegate heading and angle rules")
    assert(not playSource:find("function M%.headingFromStick"),
        "R1: stick heading rule must leave play.lua")
    assert(not playSource:find("local function shortestAngleDelta"),
        "R1: shortest angle rule must leave play.lua")

    print("  R1 play_steering module OK")
end

return M
