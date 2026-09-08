local M = {}

local sampleTierColors = {
    common = { 0.75, 0.8, 0.85 },
    rare = { 0.35, 0.75, 1 },
    epic = { 0.95, 0.7, 0.15 },
}

local sampleTierEffects = {
    common = { particleCount = 6, glowRings = 1, glowAlpha = 0.35 },
    rare = { particleCount = 10, glowRings = 2, glowAlpha = 0.5 },
    epic = { particleCount = 16, glowRings = 3, glowAlpha = 0.75 },
}

local sampleTierSparkles = {
    common = { count = 2, speed = 2.2, base = 0.35, amplitude = 0.15 },
    rare = { count = 3, speed = 3.0, base = 0.5, amplitude = 0.25 },
    epic = { count = 5, speed = 4.2, base = 0.65, amplitude = 0.35 },
}

local sampleTierShakeMultipliers = {
    common = 1.0,
    rare = 1.6,
    epic = 2.4,
}

M.sparkleAnticipationRange = 60
M.sparkleAnticipationMaxMultiplier = 3.0
M.shipPunchDuration = 0.2
M.shipShakeDuration = 0.25

function M.sampleTierColor(tier)
    local color = sampleTierColors[tier] or sampleTierColors.common
    return color[1], color[2], color[3]
end

function M.sampleTierEffect(tier)
    return sampleTierEffects[tier] or sampleTierEffects.common
end

function M.sampleTierSparkle(tier)
    return sampleTierSparkles[tier] or sampleTierSparkles.common
end

function M.sparkleAlpha(tier, time, seed)
    local sparkle = M.sampleTierSparkle(tier)
    return sparkle.base + math.sin(time * sparkle.speed + (seed or 0)) * sparkle.amplitude
end

function M.sparkleAnticipationMultiplier(distance, collectRadius)
    local edgeDistance = distance - collectRadius
    if edgeDistance <= 0 then return M.sparkleAnticipationMaxMultiplier end
    if edgeDistance >= M.sparkleAnticipationRange then return 1 end
    local progress = 1 - edgeDistance / M.sparkleAnticipationRange
    return 1 + progress * (M.sparkleAnticipationMaxMultiplier - 1)
end

function M.sampleTierShakeMultiplier(tier)
    return sampleTierShakeMultipliers[tier] or sampleTierShakeMultipliers.common
end

function M.install(scene)
    scene.sparkleAnticipationRange = M.sparkleAnticipationRange
    scene.sparkleAnticipationMaxMultiplier = M.sparkleAnticipationMaxMultiplier
    scene.shipPunchDuration = M.shipPunchDuration
    scene.shipShakeDuration = M.shipShakeDuration
    scene.sampleTierColor = M.sampleTierColor
    scene.sampleTierEffect = M.sampleTierEffect
    scene.sampleTierSparkle = M.sampleTierSparkle
    scene.sparkleAlpha = M.sparkleAlpha
    scene.sparkleAnticipationMultiplier = M.sparkleAnticipationMultiplier
    scene.sampleTierShakeMultiplier = M.sampleTierShakeMultiplier
    return scene
end

return M
