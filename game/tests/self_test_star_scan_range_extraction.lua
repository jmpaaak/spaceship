local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "R1-C: cannot read " .. path .. ": " .. tostring(err))
    return body
end

function M.run()
    print("  [R1-C] self_test star-scan-range extraction tests...")
    local runner = read("game/self_test.lua")
    local suite = read("game/tests/legacy_star_scan_range.lua")

    assert(runner:find('require("game.tests.legacy_star_scan_range").run()', 1, true),
        "R1-C: self_test must delegate star-scan-range checks")
    assert(not runner:find("-- INBOX 61(11): star scan range must cover canvas height", 1, true)
            and not runner:find('"INBOX 61(11): world.sectorSize must be positive"', 1, true),
        "R1-C: star-scan-range characterization body must leave self_test")
    assert(suite:find("function M.run()", 1, true),
        "R1-C: extracted star-scan-range suite must expose run()")
    assert(suite:find("world.sectorSize", 1, true)
            and suite:find("math.max(4, math.ceil(1280 / 2 / ss) + 2)", 1, true),
        "R1-C: extracted suite must retain positive sector size and four-sector contracts")
    print("  R1-C self_test star-scan-range extraction OK")
end

return M
