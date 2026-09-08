local sampleFeedback = require("game.scenes.play_sample_feedback")

local M = {}

function M.run()
    print("  [R1] play_sample_feedback module tests...")

    local api = {}
    sampleFeedback.install(api)

    assert(api.sampleRollupDuration == 0.3,
        "R1: sample roll-up duration must remain stable")
    assert(api.clampLabelX(50, 20, 100) == 40,
        "R1: centered labels must remain centered")
    assert(api.clampLabelX(5, 20, 100) == 2,
        "R1: labels must respect the default left margin")
    assert(api.clampLabelX(98, 20, 100) == 78,
        "R1: labels must respect the default right margin")
    assert(api.clampLabelX(5, 20, 100, 4) == 4,
        "R1: labels must support a custom margin")

    assert(api.rollupAmount(100, -1, 0.3) == 0,
        "R1: roll-up values must clamp before the animation")
    assert(api.rollupAmount(100, 0.15, 0.3) == 50,
        "R1: roll-up values must interpolate linearly")
    assert(api.rollupAmount(9, 0.15, 0.3) == 5,
        "R1: roll-up values must round to the nearest dollar")
    assert(api.rollupAmount(100, 1, 0.3) == 100,
        "R1: roll-up values must clamp after the animation")
    assert(api.rollupAmount(17, 0, 0) == 17,
        "R1: non-positive durations must settle immediately")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_sample_feedback"%)'),
        "R1: play.lua must delegate sample floating-label rules")
    assert(not playSource:find("local function clampLabelX"),
        "R1: label clamping must leave play.lua")
    assert(not playSource:find("local sampleRollupDuration%s*=%s*0%.3"),
        "R1: sample roll-up timing must leave play.lua")
    assert(not playSource:find("local function rollupAmount"),
        "R1: sample roll-up calculation must leave play.lua")

    print("  R1 play_sample_feedback module OK")
end

return M
