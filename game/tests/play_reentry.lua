local reentry = require("game.scenes.play_reentry")

local M = {}

local function near(actual, expected)
    return math.abs(actual - expected) < 0.000001
end

function M.run()
    print("  [R1] play_reentry module tests...")

    assert(near(reentry.drawOffsetX(math.pi / 120, 6), 6),
        "R1: reentry draw offset must retain its 60 Hz sinusoid")
    assert(reentry.shakeFromDistance(145, 145, 6) == 0,
        "R1: shake must stop at the reentry boundary")
    assert(reentry.shakeFromDistance(0, 145, 6) == 6
            and near(reentry.shakeFromDistance(72.5, 145, 6), 3),
        "R1: shake must ramp linearly toward Earth")
    assert(reentry.heatVignetteAlpha(145, 145) == 0
            and near(reentry.heatVignetteAlpha(72.5, 145), 0.15)
            and near(reentry.heatVignetteAlpha(0, 145), 0.3),
        "R1: heat vignette must retain its linear 0.3 alpha ramp")

    local api = { earthReentryRadius = 145, reentryShakeMax = 6 }
    reentry.install(api)
    assert(near(api.reentryDrawOffsetX(math.pi / 120, 6), 6)
            and near(api.reentryShakeFromDistance(72.5), 3)
            and near(api.reentryHeatVignetteAlpha(72.5), 0.15),
        "R1: installed scene API must use scene reentry constants")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_reentry"%)'),
        "R1: play.lua must delegate reentry presentation rules")
    assert(not playSource:find("function M%.reentryDrawOffsetX"),
        "R1: reentry draw offset rule must leave play.lua")
    assert(not playSource:find("function M%.reentryShakeFromDistance"),
        "R1: reentry shake rule must leave play.lua")
    assert(not playSource:find("function M%.reentryHeatVignetteAlpha"),
        "R1: reentry heat rule must leave play.lua")

    print("  R1 play_reentry module OK")
end

return M
