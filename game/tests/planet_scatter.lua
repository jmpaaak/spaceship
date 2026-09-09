local world = require("game.world")

local M = {}

local function stddev(values)
    assert(#values >= 2, "need at least two samples")
    local sum = 0
    for i = 1, #values do
        sum = sum + values[i]
    end
    local mean = sum / #values
    local acc = 0
    for i = 1, #values do
        local d = values[i] - mean
        acc = acc + d * d
    end
    return math.sqrt(acc / #values)
end

local function collectHomeColumns()
    -- Home galaxy radius covers roughly ±21 sectors from origin.
    local columns = {}
    for sx = -16, 16 do
        local col = {}
        for sy = -16, 16 do
            for _, p in ipairs(world.planets(sx, sy)) do
                col[#col + 1] = p
            end
        end
        columns[sx] = col
    end
    return columns
end

-- Same sector-x column must not form a visual vertical line.
local function testSameGxXSpread()
    local columns = collectHomeColumns()
    local checked = 0
    for sx = -16, 16 do
        local col = columns[sx]
        if #col >= 4 then
            local xs = {}
            for i = 1, #col do
                xs[i] = col[i].x
            end
            local sd = stddev(xs)
            assert(sd >= world.sectorSize * 0.18,
                string.format(
                    "INBOX 64: gx=%d x stddev %.2f must be a substantial fraction of sector width %d",
                    sx, sd, world.sectorSize))
            local xmin, xmax = xs[1], xs[1]
            for i = 2, #xs do
                if xs[i] < xmin then xmin = xs[i] end
                if xs[i] > xmax then xmax = xs[i] end
            end
            assert(xmax - xmin >= world.sectorSize * 0.45,
                string.format(
                    "INBOX 64: gx=%d x span %.2f must cover a large part of the sector",
                    sx, xmax - xmin))
            checked = checked + 1
        end
    end
    assert(checked >= 3, "need several same-gx columns with enough planets")
end

-- Consecutive planets in a column must not share nearly the same x (grid line).
local function testNoEvenVerticalColumns()
    local columns = collectHomeColumns()
    local pairs, closePairs = 0, 0
    for sx = -16, 16 do
        local col = columns[sx]
        if #col >= 2 then
            table.sort(col, function(a, b) return a.y < b.y end)
            for i = 2, #col do
                pairs = pairs + 1
                if math.abs(col[i].x - col[i - 1].x) < 16 then
                    closePairs = closePairs + 1
                end
            end
        end
    end
    assert(pairs >= 10, "need consecutive same-gx planet pairs")
    assert(closePairs / pairs < 0.35,
        string.format(
            "INBOX 64: even vertical-line pattern: %d/%d consecutive same-gx pairs share x within 16px",
            closePairs, pairs))
end

local function testAdjacentSectorMinDistance()
    local minDist = math.huge
    local checked = 0
    for sx = -8, 8 do
        for sy = -8, 8 do
            local here = world.planets(sx, sy)
            for ox = -1, 1 do
                for oy = -1, 1 do
                    if not (ox == 0 and oy == 0) then
                        local there = world.planets(sx + ox, sy + oy)
                        for _, a in ipairs(here) do
                            for _, b in ipairs(there) do
                                local dx = a.x - b.x
                                local dy = a.y - b.y
                                local dist = math.sqrt(dx * dx + dy * dy)
                                local need = a.radius + b.radius + 10
                                assert(dist >= need,
                                    string.format(
                                        "INBOX 64: adjacent sectors (%d,%d)/(%d,%d) planets %.1f apart, min %.1f",
                                        sx, sy, sx + ox, sy + oy, dist, need))
                                if dist < minDist then
                                    minDist = dist
                                end
                                checked = checked + 1
                            end
                        end
                    end
                end
            end
        end
    end
    assert(checked >= 1, "need at least one adjacent-sector planet pair")
    assert(minDist >= 10, "adjacent-sector planets must keep a gap")
end

local function testHashedPolarNotEvenAngles()
    local planets = {}
    for sx = -8, 8 do
        for sy = -8, 8 do
            for _, p in ipairs(world.planets(sx, sy)) do
                planets[#planets + 1] = p
            end
        end
    end
    assert(#planets >= 8, "home galaxy should have planets near origin")
    local twoPi = math.pi * 2
    local angles = {}
    for i = 1, #planets do
        local ang = math.atan2(planets[i].y, planets[i].x)
        if ang < 0 then
            ang = ang + twoPi
        end
        angles[i] = ang
    end
    table.sort(angles)
    local n = #angles
    local expected = twoPi / n
    local evenHits = 0
    for i = 1, n do
        local nxt = angles[(i % n) + 1]
        local gap = nxt - angles[i]
        if gap <= 0 then
            gap = gap + twoPi
        end
        if math.abs(gap - expected) < expected * 0.12 then
            evenHits = evenHits + 1
        end
    end
    assert(evenHits < n * 0.55,
        string.format("INBOX 64: galaxy angles look evenly sliced (%d/%d even gaps)", evenHits, n))
end

local function testDeterministicAfterReseed()
    local a = world.planets(4, -11)
    local b = world.planets(4, -11)
    assert(#a == #b)
    for i = 1, #a do
        assert(a[i].x == b[i].x and a[i].y == b[i].y)
        assert(a[i].id == b[i].id)
    end
end

function M.run()
    print("  [INBOX 64] planet scatter tests...")
    testSameGxXSpread()
    testNoEvenVerticalColumns()
    testAdjacentSectorMinDistance()
    testHashedPolarNotEvenAngles()
    testDeterministicAfterReseed()
    print("  INBOX 64 planet scatter OK")
end

return M
