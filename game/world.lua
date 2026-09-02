local M = {
    sectorSize = 192,
}

local function hash(x, y, salt)
    local n = (x * 92837111 + y * 689287499 + salt * 283923481) % 2147483647
    n = (n * 48271 + 1) % 2147483647
    return n / 2147483647
end

function M.sectorAt(x, y)
    return math.floor(x / M.sectorSize), math.floor(y / M.sectorSize)
end

-- Galaxy structure (docs/GAME_DESIGN.md 이동 방식 개선 항목 2, "우주 내에
-- 은하계(태양계 포함) 들이 존재"): the universe is a coarse grid of cells
-- (much larger than a planet-generation sector), and each cell either
-- contains one galaxy or is empty deep space. Cell (0,0) always contains
-- the home galaxy (Milky Way) centered on Earth so gameplay near the
-- origin keeps working exactly as before; every other cell has a galaxy
-- only ~28% of the time, so a huge universe is mostly empty space
-- scattered with galaxies rather than a uniformly-dense field of planets
-- everywhere (matching the user's explicit request).
M.galaxyCellSize = 4608

local function galaxyAt(x, y)
    return math.floor(x / M.galaxyCellSize), math.floor(y / M.galaxyCellSize)
end
M.galaxyAt = galaxyAt

local galaxyExistenceThreshold = 0.72

-- Deterministically returns the galaxy occupying grid cell (gx, gy), or
-- nil if that cell is empty deep space.
function M.galaxy(gx, gy)
    if gx == 0 and gy == 0 then
        return {
            id = "milkyway",
            name = "MILKY WAY",
            x = 0,
            y = 0,
            radius = M.galaxyCellSize * 0.9,
            gx = 0,
            gy = 0,
        }
    end
    if hash(gx, gy, 500) <= galaxyExistenceThreshold then
        return nil
    end
    local radius = M.galaxyCellSize * (0.18 + hash(gx, gy, 510) * 0.28)
    local cx = gx * M.galaxyCellSize + M.galaxyCellSize / 2
        + (hash(gx, gy, 520) - 0.5) * M.galaxyCellSize * 0.5
    local cy = gy * M.galaxyCellSize + M.galaxyCellSize / 2
        + (hash(gx, gy, 530) - 0.5) * M.galaxyCellSize * 0.5
    return {
        id = string.format("galaxy:%d:%d", gx, gy),
        name = string.format("GALAXY %d-%d", gx, gy),
        x = cx,
        y = cy,
        radius = radius,
        gx = gx,
        gy = gy,
    }
end

-- The "center planet" of a galaxy (docs/GAME_DESIGN.md 이동 방식 개선
-- 항목 2, "각 은하계의 중심 행성들"). The home galaxy's center is Earth
-- itself (drawn separately in PlayScene), so milkyway has no extra hub
-- planet. Every other galaxy gets one larger, deterministic planet at its
-- center so the minimap's galaxy dots correspond to a real visitable body.
function M.hubPlanet(galaxy)
    if not galaxy or galaxy.id == "milkyway" then
        return nil
    end
    local gx, gy = galaxy.gx, galaxy.gy
    return {
        id = "hub:" .. galaxy.id,
        x = galaxy.x,
        y = galaxy.y,
        radius = 16 + math.floor(hash(gx, gy, 540) * 8),
        hue = hash(gx, gy, 550),
        hub = true,
        galaxyId = galaxy.id,
    }
end

-- Finds the galaxy (if any) containing world point (x, y). Searches the
-- point's grid cell and its 8 neighbors since a galaxy's radius can
-- extend past its own cell's boundary into an adjacent one.
function M.galaxyContaining(x, y)
    local gx, gy = galaxyAt(x, y)
    for oy = -1, 1 do
        for ox = -1, 1 do
            local galaxy = M.galaxy(gx + ox, gy + oy)
            if galaxy then
                local dx, dy = x - galaxy.x, y - galaxy.y
                if dx * dx + dy * dy <= galaxy.radius * galaxy.radius then
                    return galaxy
                end
            end
        end
    end
    return nil
end

-- Collects every existing galaxy within `cellRadius` grid cells of world
-- point (x, y). Used by the minimap (slice 3 of the same request) to plot
-- nearby galaxy centers relative to the player.
function M.nearbyGalaxies(x, y, cellRadius)
    local gx, gy = galaxyAt(x, y)
    local result = {}
    for oy = -cellRadius, cellRadius do
        for ox = -cellRadius, cellRadius do
            local galaxy = M.galaxy(gx + ox, gy + oy)
            if galaxy then result[#result + 1] = galaxy end
        end
    end
    return result
end

function M.planets(sectorX, sectorY)
    local centerX = sectorX * M.sectorSize + M.sectorSize / 2
    local centerY = sectorY * M.sectorSize + M.sectorSize / 2
    -- Planets only ever generate inside a galaxy's radius; deep space
    -- between galaxies is empty. See the galaxy structure comment above.
    if not M.galaxyContaining(centerX, centerY) then
        return {}
    end
    local count = hash(sectorX, sectorY, 1) > 0.42 and 1 or 0
    if hash(sectorX, sectorY, 7) > 0.91 then count = 2 end
    local planets = {}
    for i = 1, count do
        local radius = 7 + math.floor(hash(sectorX, sectorY, 20 + i) * 10)
        planets[#planets + 1] = {
            id = string.format("%d:%d:%d", sectorX, sectorY, i),
            x = sectorX * M.sectorSize + 24 + hash(sectorX, sectorY, 40 + i) * (M.sectorSize - 48),
            y = sectorY * M.sectorSize + 24 + hash(sectorX, sectorY, 60 + i) * (M.sectorSize - 48),
            radius = radius,
            hue = hash(sectorX, sectorY, 80 + i),
        }
    end
    return planets
end

function M.nearbyPlanets(x, y, radiusInSectors)
    local sx, sy = M.sectorAt(x, y)
    local result = {}
    for oy = -radiusInSectors, radiusInSectors do
        for ox = -radiusInSectors, radiusInSectors do
            for _, planet in ipairs(M.planets(sx + ox, sy + oy)) do result[#result + 1] = planet end
        end
    end
    -- Include a galaxy's center planet when the ship is close enough that
    -- the hub falls inside the scanned sector window. Home galaxy has no
    -- extra hub (Earth is drawn separately).
    local minSx, maxSx = sx - radiusInSectors, sx + radiusInSectors
    local minSy, maxSy = sy - radiusInSectors, sy + radiusInSectors
    for _, galaxy in ipairs(M.nearbyGalaxies(x, y, 1)) do
        local hub = M.hubPlanet(galaxy)
        if hub then
            local hsx, hsy = M.sectorAt(hub.x, hub.y)
            if hsx >= minSx and hsx <= maxSx and hsy >= minSy and hsy <= maxSy then
                result[#result + 1] = hub
            end
        end
    end
    return result
end

-- Radial distance from Earth (the universe's origin), used as the value/
-- risk driver for planets (docs/GAME_DESIGN.md 이동 방식 개선 항목 1,
-- "연료소모가 거리 기반"). Replaces the old vertical-only "height"
-- (-planet.y) now that movement is omnidirectional (game/joystick.lua):
-- a planet reached by drifting sideways from Earth is exactly as far
-- away, and exactly as valuable/risky, as one reached by climbing
-- straight up used to be. For any planet with only a `y` field (x nil or
-- 0, as every existing engine-hosted test scenario uses), this returns
-- the same value as the old `math.max(0, -planet.y)` height formula.
local function distanceFromEarth(planet)
    return math.sqrt((planet.x or 0) ^ 2 + (planet.y or 0) ^ 2)
end
M.distanceFromEarth = distanceFromEarth

function M.sampleValue(planet)
    local distance = distanceFromEarth(planet)
    return 10 + math.floor(distance / 100) * 5
end

function M.collisionDamage(planet)
    local distance = distanceFromEarth(planet)
    return 1 + math.floor(distance / 500)
end

function M.sampleTier(planet)
    local distance = distanceFromEarth(planet)
    if distance >= 800 then return "epic" end
    if distance >= 300 then return "rare" end
    return "common"
end

-- Specimen catalog: every collected sample belongs to one of 9 kinds
-- (3 hue families x 3 rarity tiers), mirroring how a card game gives each
-- collectible a distinct name/family instead of a single generic pickup.
-- This backs the persistent "탐험 도감" (specimen log) shown under the
-- launch screen so players build a collection across runs, not just a
-- cash total that resets on destruction.
local hueFamilies = {
    { key = "azure", label = "AZURE", threshold = 0.33 },
    { key = "ember", label = "EMBER", threshold = 0.66 },
    { key = "void", label = "VOID", threshold = math.huge },
}
M.hueFamilies = hueFamilies

local tierNames = {
    common = "DUST",
    rare = "SHARD",
    epic = "CORE",
}
M.tierNames = tierNames

function M.hueFamily(hue)
    for _, family in ipairs(hueFamilies) do
        if hue < family.threshold then return family end
    end
    return hueFamilies[#hueFamilies]
end

-- Returns a stable specimen id ("azure_common") and a human label
-- ("AZURE DUST") for a given planet. Used both to award collection credit
-- on pickup and to render the specimen log grid.
function M.specimenKind(planet)
    local family = M.hueFamily(planet.hue or 0)
    local tier = M.sampleTier(planet)
    local id = family.key .. "_" .. tier
    local label = family.label .. " " .. tierNames[tier]
    return id, label, tier
end

-- Full ordered catalog (9 entries: azure/ember/void x common/rare/epic) so
-- the specimen log can render "?" placeholders for anything not yet found,
-- independent of any specific run's discovery order.
function M.specimenCatalog()
    local catalog = {}
    for _, family in ipairs(hueFamilies) do
        for _, tier in ipairs({ "common", "rare", "epic" }) do
            catalog[#catalog + 1] = {
                id = family.key .. "_" .. tier,
                label = family.label .. " " .. tierNames[tier],
                tier = tier,
                hueKey = family.key,
            }
        end
    end
    return catalog
end

function M.stars(sectorX, sectorY)
    local stars = {}
    for i = 1, 18 do
        stars[i] = {
            x = sectorX * M.sectorSize + hash(sectorX, sectorY, 100 + i) * M.sectorSize,
            y = sectorY * M.sectorSize + hash(sectorX, sectorY, 200 + i) * M.sectorSize,
            bright = hash(sectorX, sectorY, 300 + i),
        }
    end
    return stars
end

return M
