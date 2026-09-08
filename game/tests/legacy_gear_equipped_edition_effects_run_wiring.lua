local M = {}

-- Item 12/9 follow-up: equipGear must materialize an edition carried by a
-- pool-shaped card before storing it, while preserving edition identity and
-- avoiding a second transform for already-materialized offers.
function M.run()
    local expedition = require("game.expedition")

    -- crystallized doubles only sampleSellValue. The pool card carries
    -- value 5; once equipped WITH edition="crystallized", the live sample
    -- bonus must be 10, not the raw 5.
    local crystalCard = {
        id = "hull-crystallized-fixture", name = "Crystal", nameKo = "Crystal", icon = "*",
        rarity = "rare", tags = { "economy" }, editions = { "crystallized" },
        edition = "crystallized",
        effects = { { type = "sampleSellValue", value = 5 } },
    }
    local crystalRun = expedition.new()
    assert(expedition.equipGear(crystalRun, "hull", crystalCard),
        "equipGear must accept a pool card carrying a rolled edition id")
    local crystalBonus = expedition.effectiveSampleBonus(crystalRun)
    assert(crystalBonus == 10,
        "equipping a crystallized card (raw sampleSellValue 5) must yield sample bonus 10, got "
            .. tostring(crystalBonus))
    -- The stored loadout entry must keep the edition id (sell premium /
    -- irradiated synergy / noSlotCost all key off part.edition) AND hold
    -- the transformed effects so subsequent consumers don't re-apply.
    local storedCrystal = crystalRun.equippedGear[1]
    assert(storedCrystal.edition == "crystallized",
        "equipGear must persist the rolled edition id on the loadout entry")
    assert(storedCrystal.effects[1].value == 10,
        "equipGear must store crystallized-transformed effects (5 -> 10), got "
            .. tostring(storedCrystal.effects[1].value))
    -- Input card must not be mutated (same contract as applyEditionEffects).
    assert(crystalCard.effects[1].value == 5,
        "equipGear must not mutate the input card's raw effects")

    -- Un-editioned copy of the same raw card is the baseline the edition
    -- is supposed to beat.
    local rawCard = {
        id = "hull-raw-fixture", name = "Raw", nameKo = "Raw", icon = "*",
        rarity = "rare", tags = { "economy" }, editions = { "crystallized" },
        effects = { { type = "sampleSellValue", value = 5 } },
    }
    local rawRun = expedition.new()
    assert(expedition.equipGear(rawRun, "hull", rawCard))
    assert(expedition.effectiveSampleBonus(rawRun) == 5,
        "an un-editioned card with sampleSellValue 5 must still yield bonus 5")
    assert(crystalBonus > expedition.effectiveSampleBonus(rawRun),
        "a crystallized equipped card must grant a strictly larger sample bonus than the same card without the edition")

    -- quantum_flawed doubles every effect AND appends hullDurability -1.
    -- Equipping a card with raw hullDurability +2 must change maxDurability:
    -- base 3 + doubled 4 + drawback -1 = 6, not the raw +2 (which would be 5).
    local flawedCard = {
        id = "hull-flawed-fixture", name = "Flawed", nameKo = "Flawed", icon = "*",
        rarity = "rare", tags = { "defense" }, editions = { "quantum_flawed" },
        edition = "quantum_flawed",
        effects = { { type = "hullDurability", value = 2 } },
    }
    local flawedRun = expedition.new({ durability = 3 })
    assert(expedition.equipGear(flawedRun, "hull", flawedCard))
    expedition.launch(flawedRun)
    assert(flawedRun.maxDurability == 6,
        "equipping a quantum_flawed card (hullDurability 2 doubled to 4 plus drawback -1) must set maxDurability to 6, got "
            .. tostring(flawedRun.maxDurability))
    local storedFlawed = flawedRun.equippedGear[1]
    local sawDrawback = false
    for _, effect in ipairs(storedFlawed.effects) do
        if effect.type == "hullDurability" and effect.value == -1 then
            sawDrawback = true
        end
    end
    assert(sawDrawback, "equipGear must append quantum_flawed's hullDurability -1 drawback onto the stored effects")

    -- refined halves effects. speed 8 -> 4; equipped speed must
    -- be base + 4, not base + 8.
    local refinedCard = {
        id = "hull-refined-fixture", name = "Refined", nameKo = "Refined", icon = "*",
        rarity = "uncommon", tags = { "altitude" }, editions = { "refined" },
        edition = "refined",
        effects = { { type = "speed", value = 8 } },
    }
    local refinedRun = expedition.new()
    local baseClimb = expedition.effectiveSpeed(refinedRun)
    assert(expedition.equipGear(refinedRun, "hull", refinedCard))
    local refinedClimb = expedition.effectiveSpeed(refinedRun)
    assert(math.abs(refinedClimb - (baseClimb + 4)) < 1e-9,
        "equipping a refined card (speed 8 halved to 4) must add 4 to speed, got "
            .. tostring(refinedClimb) .. " from base " .. tostring(baseClimb))

    -- ENGINE-slot editioned card: crystallized on an engine card must
    -- NOT raise hull-scoped sampleSellValue (item 9 hull-only additive),
    -- but the stored engine entry must still keep the edition id and
    -- transformed effects (sell premium / noSlotCost / irradiated synergy).
    local engineCrystalCard = {
        id = "engine-crystallized-fixture", name = "ECrystal", nameKo = "ECrystal", icon = "*",
        rarity = "rare", tags = { "economy" }, editions = { "crystallized" },
        edition = "crystallized",
        effects = { { type = "sampleSellValue", value = 5 }, { type = "fuelEfficiency", value = 5 } },
    }
    local engineRun = expedition.new()
    assert(expedition.equipGear(engineRun, "engine", engineCrystalCard),
        "equipGear must accept a pool card carrying a rolled edition id as an engine card")
    local storedEngine = engineRun.equippedEngineParts[1]
    assert(storedEngine and storedEngine.edition == "crystallized",
        "an equipped engine card must keep its rolled edition id")
    assert(storedEngine.effects[1].value == 10,
        "engine-slot crystallized must still transform stored sampleSellValue 5 -> 10, got "
            .. tostring(storedEngine.effects[1].value))
    assert(expedition.effectiveSampleBonus(engineRun) == 0,
        "engine-slot sampleSellValue (even crystallized-doubled) must stay hull-scoped and yield 0")

    -- Idempotent: handing equipGear an already-transformed offer (the
    -- rollGearOffer shape: effects already mutated, edition already set,
    -- editionApplied stamped so materializeEdition does not double-apply)
    -- must NOT double-apply the edition transform.
    local alreadyTransformed = {
        id = "hull-already-transformed", name = "Already", nameKo = "Already", icon = "*",
        rarity = "rare", tags = { "economy" }, editions = { "crystallized" },
        edition = "crystallized",
        editionApplied = true,
        effects = { { type = "sampleSellValue", value = 10 } },
    }
    local idemRun = expedition.new()
    assert(expedition.equipGear(idemRun, "hull", alreadyTransformed))
    assert(expedition.effectiveSampleBonus(idemRun) == 10,
        "equipGear must not re-apply crystallized on an already-transformed offer (10 must stay 10, not 20), got "
            .. tostring(expedition.effectiveSampleBonus(idemRun)))
end

return M
