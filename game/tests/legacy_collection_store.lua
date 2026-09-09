local collectionStore = require("game.collection_store")
local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    -- collection_store: persists discovered specimen ids across instances
    -- (mirrors best_altitude_store's file-round-trip test), and record() only
    -- reports true (a "new" discovery) the first time a given id is seen.
    local testCollection = "self-test-specimen-collection.txt"
    love.filesystem.remove(testCollection)
    local specimenStore = collectionStore.new(testCollection)
    local emptyIds = specimenStore:load()
    assert(next(emptyIds) == nil)
    assert(specimenStore:record("solar_common") == true)
    assert(specimenStore:record("solar_common") == false)
    assert(specimenStore:record("nebula_rare") == true)
    local reloadedStore = collectionStore.new(testCollection)
    local reloadedIds = reloadedStore:load()
    assert(reloadedIds.solar_common == true)
    assert(reloadedIds.nebula_rare == true)
    assert(reloadedIds.void_epic == nil)
    assert(reloadedStore:record("solar_common") == false)
    assert(love.filesystem.remove(testCollection))

    -- PlayScene initializes collectedSpecimens from an injected collectionStore.
    local specimenScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
        collectionStore = { load = function() return { solar_common = true } end, record = function() return true end },
    })
    assert(specimenScene.collectedSpecimens.solar_common == true)
end

return M