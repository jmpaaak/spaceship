local M = {}

-- When rolls is nil (legacy callers / headless tests that don't care about
-- editions), exploreHub must still return a valid non-nil drop (regression
-- safety: guaranteed card is still guaranteed).
function M.run()
    local expedition = require("game.expedition")
    local gear_mod = require("game.gear")

    -- Use engine pool: engine_void_forge_drive is galaxy-exclusive and has
    -- edition candidates.
    local enginePool = gear_mod.loadEngineParts()
    local editionableCard = nil
    for _, card in ipairs(enginePool) do
        if card.galaxyExclusive and card.editions and #card.editions > 0 then
            editionableCard = card
            break
        end
    end
    assert(editionableCard,
        "engine pool must have at least one galaxyExclusive card with editions candidates")

    -- Build a single-card pool so galaxySpecificGear always returns our target.
    local singlePool = { editionableCard }

    -- Legacy call (no rolls) must still return a drop without an edition.
    local run0 = expedition.new()
    local drop0 = expedition.exploreHub(run0, "omega", singlePool)
    assert(drop0 and drop0.id == editionableCard.id,
        "exploreHub without rolls must still return a guaranteed drop")
    assert(drop0.edition == nil,
        "exploreHub without rolls must return edition=nil (no RNG call)")

    -- An above-threshold chance roll must not grant an edition.
    local run1 = expedition.new()
    local drop1 = expedition.exploreHub(run1, "omega", singlePool,
        { editionChance = 0.99, editionPick = 0 })
    assert(drop1 and drop1.id == editionableCard.id,
        "exploreHub with above-threshold editionChance must still return a guaranteed card")
    assert(drop1.edition == nil,
        "exploreHub with above-threshold editionChance must return edition=nil, got: "
            .. tostring(drop1.edition))

    -- A below-threshold chance roll must grant the first edition candidate.
    local run2 = expedition.new()
    local drop2 = expedition.exploreHub(run2, "omega", singlePool,
        { editionChance = 0.001, editionPick = 0 })
    assert(drop2 and drop2.id == editionableCard.id,
        "exploreHub with sub-threshold editionChance must return a guaranteed card")
    local expectedEdition = editionableCard.editions[1]
    assert(drop2.edition == expectedEdition,
        "exploreHub with sub-threshold editionChance must grant the first edition candidate ("
            .. expectedEdition .. "), got: " .. tostring(drop2.edition))

    -- The returned card must already contain the edition's transformed effects.
    local baseEffects = editionableCard.effects
    local droppedEffects = drop2.effects
    local anyChanged = false
    for index, baseEffect in ipairs(baseEffects) do
        local droppedEffect = droppedEffects[index]
        if droppedEffect and droppedEffect.value ~= baseEffect.value then
            anyChanged = true
        end
    end
    if not anyChanged then
        anyChanged = (#droppedEffects ~= #baseEffects)
    end
    assert(anyChanged,
        "exploreHub with edition must return effects transformed by applyEditionEffects "
            .. "(quantum_flawed must double values or add drawback)")

    -- Luck raises the effective edition threshold from 0.08 to 0.58.
    local luckCard = {
        id = "hub-luck-fixture", name = "Luck", nameKo = "럭", icon = "✦",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "luck", value = 50 } },
    }
    local runNoLuck = expedition.new()
    local dropNoLuck = expedition.exploreHub(runNoLuck, "beta", singlePool,
        { editionChance = 0.09, editionPick = 0 })
    assert(dropNoLuck.edition == nil,
        "exploreHub without luck, editionChance=0.09 must NOT grant edition "
            .. "(base threshold 0.08, 0.09 >= 0.08)")

    local runLuck = expedition.new()
    assert(expedition.equipGear(runLuck, "hull", luckCard))
    local dropLuck = expedition.exploreHub(runLuck, "gamma", singlePool,
        { editionChance = 0.09, editionPick = 0 })
    assert(dropLuck.edition == expectedEdition,
        "exploreHub with luck-boosted run and editionChance=0.09 must grant edition "
            .. "(luck raises effective threshold to 0.58 > 0.09), got: "
            .. tostring(dropLuck.edition))
end

return M