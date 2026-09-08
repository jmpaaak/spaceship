local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    local commonR, commonG, commonB = PlayScene.sampleTierColor("common")
    local rareR, rareG, rareB = PlayScene.sampleTierColor("rare")
    local epicR, epicG, epicB = PlayScene.sampleTierColor("epic")
    assert(commonR and commonG and commonB)
    assert(rareR and rareG and rareB)
    assert(epicR and epicG and epicB)
    assert(commonR ~= rareR or commonG ~= rareG or commonB ~= rareB)
    assert(rareR ~= epicR or rareG ~= epicG or rareB ~= epicB)

    -- Balatro-style visual punch-up (2026-09-02 pending feedback): each
    -- sample tier gets a distinct particle-burst density and glow strength
    -- so common/rare/epic planets read as increasingly valuable at a
    -- glance, not just by ring color.
    local commonEffect = PlayScene.sampleTierEffect("common")
    local rareEffect = PlayScene.sampleTierEffect("rare")
    local epicEffect = PlayScene.sampleTierEffect("epic")
    assert(commonEffect.particleCount < rareEffect.particleCount
        and rareEffect.particleCount < epicEffect.particleCount,
        "particle density must increase common < rare < epic")
    assert(commonEffect.glowAlpha < rareEffect.glowAlpha
        and rareEffect.glowAlpha < epicEffect.glowAlpha,
        "glow intensity must increase common < rare < epic")

    local particleScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    assert(#particleScene.particles == 0)
    assert(particleScene.shipPunch == 0)
    particleScene:spawnSampleParticles(0, -500, "epic")
    assert(#particleScene.particles == PlayScene.sampleTierEffect("epic").particleCount,
        "spawnSampleParticles must create a tier-scaled particle burst")
    assert(particleScene.shipPunch == PlayScene.shipPunchDuration,
        "sample pickup must start a ship scale-punch")
    local firstParticle = particleScene.particles[1]
    particleScene:update(0.1)
    assert(math.abs(firstParticle.timer - 0.4) < 1e-9)
    assert(particleScene.shipPunch < PlayScene.shipPunchDuration and particleScene.shipPunch > 0)
    particleScene:update(1.0)
    assert(#particleScene.particles == 0, "expired particles must be removed")
    assert(particleScene.shipPunch == 0)

    -- Balatro-style twinkle/sparkle animation (2026-09-02 pending feedback,
    -- "너무 밋밋하다"): undiscovered planets should shimmer over time, with
    -- higher tiers sparkling faster, brighter and with more points so the
    -- card-like glow feels alive rather than a static ring.
    local commonSparkle = PlayScene.sampleTierSparkle("common")
    local rareSparkle = PlayScene.sampleTierSparkle("rare")
    local epicSparkle = PlayScene.sampleTierSparkle("epic")
    assert(commonSparkle.count < rareSparkle.count and rareSparkle.count < epicSparkle.count,
        "sparkle point count must increase common < rare < epic")
    assert(commonSparkle.speed < rareSparkle.speed and rareSparkle.speed < epicSparkle.speed,
        "sparkle animation speed must increase common < rare < epic")
    assert(commonSparkle.amplitude < rareSparkle.amplitude and rareSparkle.amplitude < epicSparkle.amplitude,
        "sparkle brightness swing must increase common < rare < epic")

    -- sparkleAlpha(tier, time, seed) must oscillate deterministically around
    -- the tier's base brightness so draw code can sample it every frame.
    local a0 = PlayScene.sparkleAlpha("epic", 0, 0)
    assert(math.abs(a0 - epicSparkle.base) < 1e-9, "sparkleAlpha at t=0,seed=0 must equal the tier base")
    local aQuarter = PlayScene.sparkleAlpha("epic", (math.pi / 2) / epicSparkle.speed, 0)
    assert(math.abs(aQuarter - (epicSparkle.base + epicSparkle.amplitude)) < 1e-6,
        "sparkleAlpha must peak at base+amplitude a quarter period in")
    assert(a0 >= 0 and a0 <= 1)

    -- PlayScene:update must accumulate elapsed time so draw can animate
    -- sparkles smoothly across frames instead of resetting each draw call.
    local sparkleScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    assert(sparkleScene.time == 0)
    sparkleScene:update(0.25)
    assert(math.abs(sparkleScene.time - 0.25) < 1e-9, "scene time must accumulate across update calls")
    sparkleScene:update(0.25)
    assert(math.abs(sparkleScene.time - 0.5) < 1e-9)

    -- Anticipation glow acceleration (INBOX 2026-09-02 후속 확정 사항 #6,
    -- "불확실성 속의 기대감"): as the ship closes in on an undiscovered
    -- planet's collection radius, the twinkle should visibly speed up so
    -- the player feels rising tension right before the sample is grabbed,
    -- instead of a constant-speed shimmer regardless of proximity.
    assert(PlayScene.sparkleAnticipationRange > 0)
    assert(PlayScene.sparkleAnticipationMaxMultiplier > 1,
        "anticipation multiplier must exceed 1x so the sparkle actually accelerates")
    local collectRadius = 14
    local atCollectEdge = PlayScene.sparkleAnticipationMultiplier(collectRadius, collectRadius)
    assert(math.abs(atCollectEdge - PlayScene.sparkleAnticipationMaxMultiplier) < 1e-9,
        "multiplier must peak at the collection radius edge")
    local farAway = PlayScene.sparkleAnticipationMultiplier(
        collectRadius + PlayScene.sparkleAnticipationRange + 50, collectRadius)
    assert(math.abs(farAway - 1) < 1e-9,
        "multiplier must settle to 1x once far outside the anticipation range")
    local midway = PlayScene.sparkleAnticipationMultiplier(
        collectRadius + PlayScene.sparkleAnticipationRange / 2, collectRadius)
    assert(midway > 1 and midway < PlayScene.sparkleAnticipationMaxMultiplier,
        "multiplier must interpolate strictly between 1x and the max inside the range")
    assert(midway > farAway and midway < atCollectEdge)
    local insideCollectRadius = PlayScene.sparkleAnticipationMultiplier(5, collectRadius)
    assert(math.abs(insideCollectRadius - PlayScene.sparkleAnticipationMaxMultiplier) < 1e-9,
        "multiplier must stay clamped at max once already inside the collection radius")
end

return M