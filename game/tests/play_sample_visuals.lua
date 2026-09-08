local sampleVisuals = require("game.scenes.play_sample_visuals")

local M = {}

local function near(actual, expected)
    return math.abs(actual - expected) < 0.000001
end

function M.run()
    print("  [R1] play_sample_visuals module tests...")

    local api = {}
    sampleVisuals.install(api)

    for _, name in ipairs({
        "sampleTierColor", "sampleTierEffect", "sampleTierSparkle",
        "sparkleAlpha", "sparkleAnticipationMultiplier", "sampleTierShakeMultiplier",
    }) do
        assert(type(api[name]) == "function", "R1: play_sample_visuals must install " .. name)
    end
    assert(api.sparkleAnticipationRange == 60,
        "R1: sparkle anticipation range must remain stable")
    assert(api.sparkleAnticipationMaxMultiplier == 3,
        "R1: sparkle anticipation maximum must remain stable")
    assert(api.shipPunchDuration == 0.2 and api.shipShakeDuration == 0.25,
        "R1: sample punch and collision shake durations must remain stable")

    local r, g, b = api.sampleTierColor("rare")
    assert(near(r, 0.35) and near(g, 0.75) and near(b, 1),
        "R1: rare sample color must remain stable")
    local fr, fg, fb = api.sampleTierColor("unknown")
    assert(near(fr, 0.75) and near(fg, 0.8) and near(fb, 0.85),
        "R1: unknown sample tiers must use common color")

    local epicEffect = api.sampleTierEffect("epic")
    assert(epicEffect.particleCount == 16 and epicEffect.glowRings == 3
            and near(epicEffect.glowAlpha, 0.75),
        "R1: epic sample effect must remain stable")
    local rareSparkle = api.sampleTierSparkle("rare")
    assert(rareSparkle.count == 3 and near(rareSparkle.speed, 3)
            and near(rareSparkle.base, 0.5) and near(rareSparkle.amplitude, 0.25),
        "R1: rare sparkle profile must remain stable")
    assert(near(api.sparkleAlpha("common", 0, 0), 0.35),
        "R1: sparkle alpha must retain deterministic sine animation")

    assert(near(api.sparkleAnticipationMultiplier(200, 100), 1),
        "R1: distant samples must use normal sparkle speed")
    assert(near(api.sparkleAnticipationMultiplier(130, 100), 2),
        "R1: anticipation speed must ramp linearly near collection range")
    assert(near(api.sparkleAnticipationMultiplier(100, 100), 3),
        "R1: samples at collection range must use maximum sparkle speed")
    assert(near(api.sampleTierShakeMultiplier("epic"), 2.4)
            and near(api.sampleTierShakeMultiplier("unknown"), 1),
        "R1: shake strength must scale by tier and default to common")

    local playSource = love.filesystem.read("game/scenes/play.lua") or ""
    assert(playSource:find('require%("game%.scenes%.play_sample_visuals"%)'),
        "R1: play.lua must delegate sample presentation rules")
    assert(not playSource:find("local sampleTierColors%s*="),
        "R1: sample color rules must leave play.lua")
    assert(not playSource:find("local sampleTierEffects%s*="),
        "R1: sample effect rules must leave play.lua")
    assert(not playSource:find("local sampleTierSparkles%s*="),
        "R1: sample sparkle rules must leave play.lua")
    assert(not playSource:find("local sampleTierShakeMultipliers%s*="),
        "R1: sample shake rules must leave play.lua")

    print("  R1 play_sample_visuals module OK")
end

return M
