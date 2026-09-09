local world = require("game.world")

local M = {}

local function read(path)
    local body, err = love.filesystem.read(path)
    assert(body, "cannot read " .. path .. ": " .. tostring(err))
    return body
end

-- Characterization of current M.planets() before extracting
-- game/world_planets.lua. Same sector must keep count, ids, positions,
-- radius, hue, and galaxy star-type fields.
local SAMPLE_SECTORS = {
    {0, 0}, {1, 1}, {2, -1}, {-3, 4}, {7, -3}, {5, 5},
    {12, 3}, {-22, -2}, {-19, -4},
}

local function planetFingerprint(p)
    return string.format(
        "%s|%.17g|%.17g|%s|%.17g|%s|%s",
        tostring(p.id), p.x, p.y, tostring(p.radius), p.hue,
        tostring(p.galaxyStarType), tostring(p.galaxyStarTypeIdx))
end

local function testDeterministicPlanetContract()
    local nonempty = 0
    for _, s in ipairs(SAMPLE_SECTORS) do
        local a = world.planets(s[1], s[2])
        local b = world.planets(s[1], s[2])
        assert(#a == #b, "planet count must be deterministic")
        if #a > 0 then nonempty = nonempty + 1 end
        for i = 1, #a do
            assert(planetFingerprint(a[i]) == planetFingerprint(b[i]),
                "planet fields must be deterministic")
            assert(type(a[i].id) == "string")
            assert(type(a[i].x) == "number" and type(a[i].y) == "number")
            assert(type(a[i].radius) == "number" and a[i].radius >= 14)
            assert(type(a[i].hue) == "number")
            assert(a[i].galaxyStarType ~= nil)
            assert(a[i].galaxyStarTypeIdx ~= nil)
        end
        if #a == 2 then
            local dx = a[2].x - a[1].x
            local dy = a[2].y - a[1].y
            local dist = math.sqrt(dx * dx + dy * dy)
            local minDist = a[1].radius + a[2].radius + 10
            assert(dist >= minDist, "same-sector planets must not overlap")
        end
    end
    assert(nonempty >= 1, "sample sectors must include at least one planet")
end

local function testExtractionBoundary()
    local worldSrc = read("game/world.lua")
    local planetsSrc = love.filesystem.read("game/world_planets.lua")
    assert(planetsSrc, "game/world_planets.lua must exist after extraction")
    assert(planetsSrc:find("function M.planets", 1, true),
        "extracted module must own planet generation")
    assert(worldSrc:find('require("game.world_planets")', 1, true),
        "world.lua must require extracted planet generation")
    assert(not worldSrc:find("Clamp hue within", 1, true),
        "planet generation body must leave world.lua")
end

function M.run()
    print("  [R1] world_planets extraction tests...")
    testDeterministicPlanetContract()
    testExtractionBoundary()
    print("  R1 world_planets extraction OK")
end

return M
