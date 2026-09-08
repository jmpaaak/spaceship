local gear = require("game.gear")

local M = {}

-- Item 12 quantum_flawed (quantum-flawed: doubled effects plus one drawback):
-- applyEditionEffects already appends hullDurability -1, and hull-slot
-- equipping that drawback is covered by the extracted equipped-edition
-- run-wiring suite.
-- The bundled engine card engine_singularity_drive lists quantum_flawed as
-- a rollable edition, but equippedHullDurabilityBonus only reads
-- run.equippedGear, so an engine-slot quantum_flawed card doubles its (G)
-- propulsion effects with ZERO hull penalty -- the documented unique
-- promise is dead for the only engine card that can actually roll it.
-- Positive hullDurability on an engine card must stay ignored (item 9
-- hull-only plating); only the negative edition drawback crosses slots.
function M.run()
    local expedition = require("game.expedition")

    -- Pure conversion: negative hullDurability on an engine-slot list is
    -- the edition drawback; positives on that list stay 0.
    assert(gear.engineSlotHullDurabilityDrawback({}) == 0,
        "an empty engine list must contribute 0 hullDurability drawback")
    assert(gear.engineSlotHullDurabilityDrawback({
        { effects = { { type = "hullDurability", value = 2 }, { type = "fuelEfficiency", value = 10 } } },
    }) == 0, "positive hullDurability on an engine card must still be ignored")
    assert(gear.engineSlotHullDurabilityDrawback({
        { effects = { { type = "hullDurability", value = -1 }, { type = "fuelEfficiency", value = 20 } } },
    }) == -1, "a quantum_flawed-style hullDurability -1 on an engine card must count")
    assert(gear.engineSlotHullDurabilityDrawback({
        { effects = { { type = "hullDurability", value = -1 } } },
        { effects = { { type = "hullDurability", value = 4 } } },
        { effects = { { type = "hullDurability", value = -1 } } },
    }) == -2, "only negative hullDurability values from engine slots must stack")

    -- Regression: a positive hullDurability engine card still does not
    -- raise maxDurability (item 9 hull-only plating).
    local positiveEngineRun = expedition.new({ durability = 3 })
    assert(expedition.equipGear(positiveEngineRun, "engine", {
        id = "engine-positive-hull", name = "Pos", nameKo = "Pos", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 2 }, { type = "fuelEfficiency", value = 5 } },
    }))
    assert(positiveEngineRun.maxDurability == 3,
        "positive engine-slot hullDurability must stay ignored, got "
            .. tostring(positiveEngineRun.maxDurability))

    -- quantum_flawed engine card: doubled (G) effect AND hullDurability -1
    -- drawback must land on maxDurability immediately (not only after launch).
    local flawedEngineCard = {
        id = "engine-flawed-fixture", name = "FlawedEngine", nameKo = "FlawedEngine", icon = "*",
        rarity = "legendary", tags = { "speed" }, editions = { "quantum_flawed" },
        edition = "quantum_flawed",
        effects = { { type = "fuelEfficiency", value = 10 } },
    }
    local flawedEngineRun = expedition.new({ durability = 3 })
    assert(expedition.equipGear(flawedEngineRun, "engine", flawedEngineCard))
    assert(flawedEngineRun.maxDurability == 2,
        "engine-slot quantum_flawed must apply hullDurability -1 drawback (3 -> 2), got "
            .. tostring(flawedEngineRun.maxDurability))
    assert(#flawedEngineRun.equippedGear == 0,
        "engine-slot quantum_flawed must not occupy a hull slot")
    local stored = flawedEngineRun.equippedEngineParts[1]
    local sawDrawback = false
    for _, effect in ipairs(stored.effects) do
        if effect.type == "hullDurability" and effect.value == -1 then
            sawDrawback = true
        end
    end
    assert(sawDrawback, "materializeEdition must still append the hullDurability -1 drawback on the engine entry")

    -- Unequip restores maxDurability (engine unequip must refresh stats).
    assert(expedition.unequipGear(flawedEngineRun, "engine", "engine-flawed-fixture"))
    assert(flawedEngineRun.maxDurability == 3,
        "unequipping an engine-slot quantum_flawed card must restore maxDurability to 3, got "
            .. tostring(flawedEngineRun.maxDurability))

    -- Bundled engine_singularity_drive actually lists quantum_flawed, so
    -- the live drop path can reach this drawback without a synthetic card.
    local poolCard = gear.findById(gear.loadEngineParts(), "engine_singularity_drive")
    assert(poolCard, "fixture engine_singularity_drive must exist")
    local canRollFlawed = false
    for _, editionId in ipairs(poolCard.editions or {}) do
        if editionId == "quantum_flawed" then canRollFlawed = true end
    end
    assert(canRollFlawed, "engine_singularity_drive must list quantum_flawed so the live drop path can reach this drawback")
    local liveCard = {
        id = poolCard.id, name = poolCard.name, nameKo = poolCard.nameKo, icon = poolCard.icon,
        rarity = poolCard.rarity, tags = poolCard.tags, editions = poolCard.editions,
        edition = "quantum_flawed", effects = poolCard.effects,
    }
    local liveRun = expedition.new({ durability = 3 })
    assert(expedition.equipGear(liveRun, "engine", liveCard))
    assert(liveRun.maxDurability == 2,
        "bundled engine_singularity_drive with quantum_flawed must drop maxDurability 3 -> 2, got "
            .. tostring(liveRun.maxDurability))
end

return M