local world = require("game.world")

local M = {}

function M.run()
    assert(world.sampleTier({ y = -50 }) == "common")
    assert(world.sampleTier({ y = -299 }) == "common")
    assert(world.sampleTier({ y = -300 }) == "rare")
    assert(world.sampleTier({ y = -799 }) == "rare")
    assert(world.sampleTier({ y = -800 }) == "epic")

    -- Specimen catalog (9 = 3 hue families x 3 tiers): every entry has a
    -- unique id, and specimenKind maps a planet to a stable id/label pair
    -- that matches the catalog exactly.
    local catalog = world.specimenCatalog()
    assert(#catalog == 9)
    local seenIds = {}
    for _, entry in ipairs(catalog) do
        assert(not seenIds[entry.id], "duplicate specimen id " .. entry.id)
        seenIds[entry.id] = true
    end
    local azureCommonId, azureCommonLabel = world.specimenKind({ hue = 0.1, y = -50 })
    assert(azureCommonId == "azure_common")
    assert(azureCommonLabel == "AZURE DUST")
    local emberRareId, emberRareLabel = world.specimenKind({ hue = 0.5, y = -500 })
    assert(emberRareId == "ember_rare")
    assert(emberRareLabel == "EMBER SHARD")
    local voidEpicId, voidEpicLabel = world.specimenKind({ hue = 0.9, y = -900 })
    assert(voidEpicId == "void_epic")
    assert(voidEpicLabel == "VOID CORE")
    assert(world.sampleTier({ y = -5000 }) == "epic")
end

return M