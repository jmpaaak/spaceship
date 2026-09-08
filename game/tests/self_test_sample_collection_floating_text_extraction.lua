local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test sample-collection floating-text extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_sample_collection_floating_text.lua")

    assert(runner:find('require("game.tests.legacy_sample_collection_floating_text").run()', 1, true),
        "R1-C: self_test must delegate sample-collection floating-text checks")
    assert(not runner:find('floatingTextScene.collided["floating-text-sample"]', 1, true)
            and not runner:find("local startingFloatingY", 1, true),
        "R1-C: sample-collection floating-text characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted sample-collection floating-text suite must expose run()")
    assert(suite:find('world.nearbyPlanets = function()', 1, true)
            and suite:find('id = "floating-text-sample"', 1, true),
        "R1-C: extracted suite must retain the mocked nearby sample planet")
    assert(suite:find('sampleFloatingText.text == "+$0"', 1, true)
            and suite:find('sampleFloatingText.text == "+$1"', 1, true),
        "R1-C: extracted suite must retain the +$0 to +$1 roll-up")
    assert(suite:find("sampleFloatingText.y < startingFloatingY", 1, true)
            and suite:find("floatingTextScene:update(0.35)", 1, true)
            and suite:find("floatingTextScene:update(0.36)", 1, true),
        "R1-C: extracted suite must retain upward motion, hold, and removal timing")
    print("  R1-C self_test sample-collection floating-text extraction OK")
end

return M
