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

function M.planets(sectorX, sectorY)
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
    return result
end

function M.sampleValue(planet)
    local height = math.max(0, -planet.y)
    return 10 + math.floor(height / 100) * 5
end

function M.collisionDamage(planet)
    local height = math.max(0, -planet.y)
    return 1 + math.floor(height / 500)
end

function M.sampleTier(planet)
    local height = math.max(0, -planet.y)
    if height >= 800 then return "epic" end
    if height >= 300 then return "rare" end
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
