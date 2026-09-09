local world = require("game.world")

local M = {}

function M.run()
    assert(world.sampleTier({ y = -50 }) == "common")
    assert(world.sampleTier({ y = -299 }) == "common")
    assert(world.sampleTier({ y = -300 }) == "rare")
    assert(world.sampleTier({ y = -799 }) == "rare")
    assert(world.sampleTier({ y = -800 }) == "epic")

    -- Specimen catalog (12 = 4 gear-suit families x 3 tiers): every entry
    -- has a unique id, and specimenKind maps a planet to a stable id/label
    -- pair that matches the catalog exactly.
    local catalog = world.specimenCatalog()
    assert(#catalog == 12)
    local seenIds = {}
    for _, entry in ipairs(catalog) do
        assert(not seenIds[entry.id], "duplicate specimen id " .. entry.id)
        seenIds[entry.id] = true
    end
    local solarCommonId, solarCommonLabel = world.specimenKind({ hue = 0.1, y = -50 })
    assert(solarCommonId == "solar_common")
    assert(solarCommonLabel == "SOLAR DUST")
    local nebulaRareId, nebulaRareLabel = world.specimenKind({ hue = 0.4, y = -500 })
    assert(nebulaRareId == "nebula_rare")
    assert(nebulaRareLabel == "NEBULA SHARD")
    local voidRareId, voidRareLabel = world.specimenKind({ hue = 0.6, y = -500 })
    assert(voidRareId == "void_rare")
    assert(voidRareLabel == "VOID SHARD")
    local pulsarEpicId, pulsarEpicLabel = world.specimenKind({ hue = 0.9, y = -900 })
    assert(pulsarEpicId == "pulsar_epic")
    assert(pulsarEpicLabel == "PULSAR CORE")
    assert(world.sampleTier({ y = -5000 }) == "epic")
end

return M