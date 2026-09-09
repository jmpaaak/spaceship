local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test collection-store extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_collection_store.lua")

    assert(runner:find('require("game.tests.legacy_collection_store").run()', 1, true),
        "R1-C: self_test must delegate collection-store checks")
    assert(not runner:find('local testCollection = "self-test-specimen-collection.txt"', 1, true)
            and not runner:find("local specimenScene = PlayScene.new", 1, true),
        "R1-C: collection-store characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted collection-store suite must expose run()")
    assert(suite:find('specimenStore:record("solar_common") == true', 1, true)
            and suite:find('reloadedStore:record("solar_common") == false', 1, true),
        "R1-C: extracted suite must retain first-discovery and persisted-id coverage")
    assert(suite:find("specimenScene.collectedSpecimens.solar_common == true", 1, true),
        "R1-C: extracted suite must retain PlayScene injected-store initialization coverage")
    print("  R1-C self_test collection-store extraction OK")
end

return M