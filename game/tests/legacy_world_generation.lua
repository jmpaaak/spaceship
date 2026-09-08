local world = require("game.world")

local M = {}

local function testBackgroundStars()
    local a = world.backgroundStars(3, -2)
    local b = world.backgroundStars(3, -2)
    assert(#a == #b, "background star field must be deterministic per sector")
    for i = 1, #a do
        assert(a[i].x == b[i].x and a[i].y == b[i].y and a[i].bright == b[i].bright)
    end
    assert(#a > #world.stars(3, -2) * 2,
        "background star layer must be noticeably denser than the foreground meteor layer")
    for _, star in ipairs(a) do
        assert(star.bright >= 0 and star.bright <= 1)
    end

    local foreground = world.stars(3, -2)
    local distinct = false
    for i = 1, math.min(#a, #foreground) do
        if a[i].x ~= foreground[i].x or a[i].y ~= foreground[i].y then distinct = true end
    end
    assert(distinct, "background stars must be an independently seeded point set")

    local fg = world.stars(5, 5)
    local diagCount = 0
    for _, s in ipairs(fg) do
        local ox = s.x - 5 * world.sectorSize
        local oy = s.y - 5 * world.sectorSize
        if math.abs(ox - oy) < 1e-6 then diagCount = diagCount + 1 end
    end
    assert(diagCount <= 1,
        "stars x/y must use independent salts: too many on the diagonal for sectorX==sectorY")

    local bg = world.backgroundStars(5, 5)
    local bgDiagCount = 0
    for _, s in ipairs(bg) do
        local ox = s.x - 5 * world.sectorSize
        local oy = s.y - 5 * world.sectorSize
        if math.abs(ox - oy) < 1e-6 then bgDiagCount = bgDiagCount + 1 end
    end
    assert(bgDiagCount <= 1,
        "backgroundStars x/y must use independent salts: too many on the diagonal for sectorX==sectorY")
end

local function testPlanetDiagonalHash()
    local totalPlanets = 0
    local diagCount = 0
    for s = 1, 20 do
        local planets = world.planets(s, s)
        for _, p in ipairs(planets) do
            totalPlanets = totalPlanets + 1
            local ox = p.x - s * world.sectorSize
            local oy = p.y - s * world.sectorSize
            if math.abs(ox - oy) < 1e-6 then diagCount = diagCount + 1 end
        end
    end
    assert(diagCount <= 1,
        "INBOX-27 planets x/y must use independent hash inputs: " ..
        diagCount .. "/" .. totalPlanets .. " on diagonal for sectorX==sectorY")
end

local function testPlanetDensityHalved()
    local totalPlanets = 0
    for sx = -10, 10 do
        for sy = -30, -10 do
            local planets = world.planets(sx, sy)
            totalPlanets = totalPlanets + #planets
        end
    end
    local scanned = 21 * 21
    assert(totalPlanets < scanned * 0.30,
        "INBOX-28 density should be halved: got " .. totalPlanets ..
        " planets in " .. scanned .. " sectors (max expected ~" ..
        math.floor(scanned * 0.30) .. ")")
end

local function testPlanetOverlapPrevention()
    for sx = -50, 50 do
        for sy = -50, 50 do
            local planets = world.planets(sx, sy)
            if #planets == 2 then
                local p1, p2 = planets[1], planets[2]
                local dx = p2.x - p1.x
                local dy = p2.y - p1.y
                local dist = math.sqrt(dx * dx + dy * dy)
                local minDist = p1.radius + p2.radius + 10
                assert(dist >= minDist,
                    string.format(
                        "INBOX-28 overlap: sector (%d,%d) planets %.1f apart, min %.1f",
                        sx, sy, dist, minDist))
            end
        end
    end
end

function M.run()
    testBackgroundStars()
    testPlanetDiagonalHash()
    testPlanetDensityHalved()
    testPlanetOverlapPrevention()
end

return M