local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test planet-variation extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_planet_variation.lua")

    assert(runner:find('require("game.tests.legacy_planet_variation").run()', 1, true),
        "R1-C: self_test must delegate deterministic planet-variation checks")
    assert(not runner:find("-- INBOX (12): per-planet rotation/scale variation", 1, true)
            and not runner:find('PlayScene.planetVariation({ id = "3:4:1" })', 1, true),
        "R1-C: planet-variation characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted planet-variation suite must expose run()")
    assert(suite:find("PlayScene.planetVariation(nil)", 1, true)
            and suite:find("rA == rA2 and sA == sA2", 1, true)
            and suite:find("rA ~= rB or sA ~= sB", 1, true),
        "R1-C: extracted suite must retain identity and ID determinism contracts")
    assert(suite:find("rA >= 0 and rA < 2 * math.pi", 1, true)
            and suite:find("sA >= 0.85 and sA <= 1.15", 1, true)
            and suite:find('id = "hub:galaxy:1:2"', 1, true),
        "R1-C: extracted suite must retain variation ranges and hub coverage")
    print("  R1-C self_test planet-variation extraction OK")
end

return M