local gear = require("game.gear")

local M = {}

-- Item 9/10 gap audit: expedition.effectiveSpeed applies item 9's tag-
-- synergy multiplier (gear.equippedTotals -> gear.tagSynergyMultiplier) to
-- the HULL climbSpeed total, but the engine-slot climbSpeed contribution
-- (added since the item 10(b)/9 "engine-slot climbSpeed run wiring" slice)
-- is summed with a plain gear.aggregateEffects call, which never invokes
-- tagSynergyMultiplier at all. Two consequences, found by auditing every
-- caller of tagSynergyMultiplier/equippedTotals against run.equippedEngineParts:
-- (1) two engine-slot cards that share a synergy tag (item 9's "부품들의
-- 조합(시너지)" — the same combo mechanic item 10(b) explicitly says engine
-- parts also carry via their own tags) get zero multiplier bonus between
-- themselves, unlike two hull cards with the same shared tag; (2) the
-- bundled `engine_fusion_core` card lists "irradiated" as a candidate
-- edition specifically for its synergyBonusAdd amplification (item 12), but
-- since engine-slot synergy is never computed at all, that edition can never
-- have any observable effect when rolled on an engine card -- silently dead
-- content identical in shape to the hull-side gap the item 12 "irradiated
-- synergy bonus wiring" slice closed, just one slot category over.
function M.run()
    local expedition = require("game.expedition")

    -- Pure layer: two engine-slot parts sharing a tag must produce a
    -- multiplier > 1 via gear.tagSynergyMultiplier, exactly like hull parts
    -- (this already passes -- tagSynergyMultiplier itself is category-blind).
    local sharedA = { id = "eng-syn-a", tags = { "altitude" }, effects = { { type = "speed", value = 4 } } }
    local sharedB = { id = "eng-syn-b", tags = { "altitude" }, effects = { { type = "speed", value = 6 } } }
    local rawMultiplier = gear.tagSynergyMultiplier({ sharedA, sharedB })
    assert(rawMultiplier > 1, "two engine-tag-sharing parts must produce a synergy multiplier above 1 in the pure layer")

    -- Run-level gap: effectiveSpeed must apply that same multiplier to
    -- the ENGINE slot's speed total, not just sum it flat.
    local run = expedition.new()
    assert(expedition.equipGear(run, "engine", sharedA))
    assert(expedition.equipGear(run, "engine", sharedB))
    local baseline = run.baseSpeed
    local actualClimb = expedition.effectiveSpeed(run)
    local flatSum = baseline + 4 + 6
    local synergizedSum = baseline + (4 + 6) * rawMultiplier
    assert(math.abs(actualClimb - synergizedSum) < 1e-9,
        "engine-slot shared-tag synergy must multiply the engine speed total (expected "
            .. tostring(synergizedSum) .. ", got " .. tostring(actualClimb)
            .. "); a plain additive sum would give " .. tostring(flatSum))
    assert(actualClimb > flatSum,
        "engine-slot synergy-multiplied speed must exceed the plain additive sum, got "
            .. tostring(actualClimb) .. " vs flat " .. tostring(flatSum))

    -- No shared tag -> no synergy bonus, engine climb stays a plain sum
    -- (regression: this must not start multiplying unrelated engine cards).
    local noSynRun = expedition.new()
    local loneA = { id = "eng-lone-a", tags = { "altitude" }, effects = { { type = "speed", value = 3 } } }
    local loneB = { id = "eng-lone-b", tags = { "control" }, effects = { { type = "speed", value = 5 } } }
    assert(expedition.equipGear(noSynRun, "engine", loneA))
    assert(expedition.equipGear(noSynRun, "engine", loneB))
    assert(math.abs(expedition.effectiveSpeed(noSynRun) - (noSynRun.baseSpeed + 3 + 5)) < 1e-9,
        "engine-slot parts with no shared tag must stay a plain additive sum")

    -- Bundled engine_fusion_core (irradiated candidate, tags altitude/economy,
    -- carries speed) reaches this live: pairing it with another
    -- altitude-tagged engine card and equipping it WITH the irradiated
    -- edition applied must yield a strictly larger speed contribution
    -- than the same pairing without the edition.
    local poolCard = gear.findById(gear.loadEngineParts(), "engine_fusion_core")
    assert(poolCard, "fixture engine_fusion_core must exist")
    local canRollIrradiated = false
    for _, editionId in ipairs(poolCard.editions or {}) do
        if editionId == "irradiated" then canRollIrradiated = true end
    end
    assert(canRollIrradiated, "engine_fusion_core must list irradiated so the live drop path can reach this synergy amplification")
    local partnerCard = { id = "eng-partner-altitude", tags = { "altitude" }, editions = {}, effects = { { type = "speed", value = 5 } } }

    local plainRun = expedition.new()
    local plainFusionCore = { id = poolCard.id, name = poolCard.name, nameKo = poolCard.nameKo, icon = poolCard.icon,
        rarity = poolCard.rarity, tags = poolCard.tags, editions = poolCard.editions, effects = poolCard.effects }
    assert(expedition.equipGear(plainRun, "engine", plainFusionCore))
    assert(expedition.equipGear(plainRun, "engine", partnerCard))
    local plainClimb = expedition.effectiveSpeed(plainRun)

    local irradiatedRun = expedition.new()
    local irradiatedFusionCore = { id = poolCard.id, name = poolCard.name, nameKo = poolCard.nameKo, icon = poolCard.icon,
        rarity = poolCard.rarity, tags = poolCard.tags, editions = poolCard.editions,
        edition = "irradiated", effects = poolCard.effects }
    assert(expedition.equipGear(irradiatedRun, "engine", irradiatedFusionCore))
    assert(expedition.equipGear(irradiatedRun, "engine", { id = "eng-partner-altitude", tags = { "altitude" }, editions = {}, effects = { { type = "speed", value = 5 } } }))
    local irradiatedClimb = expedition.effectiveSpeed(irradiatedRun)

    assert(irradiatedClimb > plainClimb,
        "an irradiated engine_fusion_core sharing a synergy tag with another engine card must yield strictly higher "
            .. "speed than the same pairing without the edition (plain=" .. tostring(plainClimb)
            .. ", irradiated=" .. tostring(irradiatedClimb) .. ")")
end

return M
