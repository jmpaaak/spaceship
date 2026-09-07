local i18n = require("game.i18n")

local M = {
    sectorSize = 192,
}

local function hash(x, y, salt)
    local n = (x * 92837111 + y * 689287499 + salt * 283923481) % 2147483647
    n = (n * 48271 + 1) % 2147483647
    n = ((n * 48271 + 1) % 2147483647)  -- 2nd round
    n = ((n * 48271 + 1) % 2147483647)  -- 3rd round — breaks LCG linearity
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

local galaxyExistenceThreshold = 0.92

-- 6 star type names matching the 6 frames of pixelplanets_stars_special.png.
-- Determined per-galaxy so all special stars inside that galaxy show the same shape.
local starTypes = { "ice", "lava", "dry", "gas", "earth", "bare" }

-- Minimum gap between two galaxy circles (in world pixels).
local galaxyOverlapPadding = 200

-- Raw galaxy data without overlap prevention.  Used internally so that the
-- overlap check can inspect neighbours without infinite recursion.
local function rawGalaxy(gx, gy)
    if gx == 0 and gy == 0 then
        return {
            id = "milkyway",
            name = "SOLAR SYSTEM",
            x = 0,
            y = 0,
            radius = M.galaxyCellSize * 0.9,
            gx = 0,
            gy = 0,
            starType = "earth",       -- home galaxy always uses "earth" star type
            starTypeIdx = 4,          -- 0-based frame index into pixelplanets_stars_special.png
            baseHue = 0.6,            -- consistent hue for home galaxy
            _priority = math.huge,    -- home always wins overlap contests
        }
    end
    local existHash = hash(gx, gy, 500)
    if existHash <= galaxyExistenceThreshold then
        return nil
    end
    local radius = M.galaxyCellSize * (0.18 + hash(gx, gy, 510) * 0.28)
    local cx = gx * M.galaxyCellSize + M.galaxyCellSize / 2
        + (hash(gx, gy, 520) - 0.5) * M.galaxyCellSize * 0.5
    local cy = gy * M.galaxyCellSize + M.galaxyCellSize / 2
        + (hash(gx, gy, 530) - 0.5) * M.galaxyCellSize * 0.5
    -- starType: deterministic from galaxy cell, 6 options
    local starTypeIdx = math.floor(hash(gx, gy, 571) * 6) % 6  -- 0-based
    -- baseHue: drives planet hue clamping within galaxy (0..1 range)
    local baseHue = hash(gx, gy, 572)
    return {
        id = string.format("galaxy:%d:%d", gx, gy),
        name = string.format("GALAXY %d-%d", gx, gy),
        x = cx,
        y = cy,
        radius = radius,
        gx = gx,
        gy = gy,
        starType = starTypes[starTypeIdx + 1],
        starTypeIdx = starTypeIdx,
        baseHue = baseHue,
        _priority = existHash,  -- higher hash = higher priority in overlap contests
    }
end

-- Deterministically returns the galaxy occupying grid cell (gx, gy), or
-- nil if that cell is empty deep space.  After computing the raw galaxy
-- we check 8-connected neighbours: if any neighbour's circle overlaps
-- this one (dist < r1 + r2 + padding) AND has strictly higher priority,
-- this cell is suppressed to nil.  Home galaxy (0,0) always has highest
-- priority so it is never suppressed.
function M.galaxy(gx, gy)
    local self_g = rawGalaxy(gx, gy)
    if not self_g then return nil end
    -- Home galaxy is never suppressed.
    if gx == 0 and gy == 0 then
        self_g._priority = nil
        return self_g
    end
    -- Check 8-connected neighbours for overlap.
    for oy = -1, 1 do
        for ox = -1, 1 do
            if not (ox == 0 and oy == 0) then
                local nb = rawGalaxy(gx + ox, gy + oy)
                if nb then
                    local dx = self_g.x - nb.x
                    local dy = self_g.y - nb.y
                    local dist = math.sqrt(dx * dx + dy * dy)
                    if dist < (self_g.radius + nb.radius + galaxyOverlapPadding) then
                        -- Overlap detected: suppress the lower-priority galaxy.
                        if nb._priority > self_g._priority then
                            return nil  -- neighbour wins, suppress self
                        end
                        -- If equal priority (extremely unlikely with float hashes),
                        -- use cell coords as tiebreaker: lower gy wins, then lower gx.
                        if nb._priority == self_g._priority then
                            if (nb.gy < gy) or (nb.gy == gy and nb.gx < gx) then
                                return nil
                            end
                        end
                    end
                end
            end
        end
    end
    self_g._priority = nil  -- strip internal field before returning
    return self_g
end

function M.galaxyName(galaxy_or_gx, gy)
    local gx, gy_val, id
    if type(galaxy_or_gx) == "table" then
        gx = galaxy_or_gx.gx
        gy_val = galaxy_or_gx.gy
        id = galaxy_or_gx.id
    else
        gx = galaxy_or_gx
        gy_val = gy
        if gx == 0 and gy_val == 0 then id = "milkyway" end
    end
    if not gx then return nil end
    if id == "milkyway" then
        return i18n.t("galaxy_home")
    end
    local names = i18n.t("galaxy_names")
    local suffixes = i18n.t("galaxy_suffixes")
    if type(names) ~= "table" or #names == 0 then
        return string.format("GALAXY %d-%d", gx, gy_val)
    end
    local h = math.floor(hash(gx, gy_val, 700) * 1000000)
    local nameIndex = (h % #names) + 1
    if type(suffixes) == "table" and #suffixes > 0 then
        local suffixIndex = (math.floor(h / #names) % #suffixes) + 1
        return i18n.t("galaxy_named", names[nameIndex], suffixes[suffixIndex])
    end
    return names[nameIndex]
end

-- Deterministic central-star name for a galaxy (real star names).
-- Home galaxy always returns the localized "Sun"/"태양".
function M.starName(galaxy)
    if not galaxy then return nil end
    if galaxy.id == "milkyway" then return i18n.t("minimap_star_label") end
    local starNames = i18n.t("star_names")
    if type(starNames) ~= "table" or #starNames == 0 then return "Star" end
    local h = math.floor(hash(galaxy.gx or 0, galaxy.gy or 0, 750) * 1000000)
    return starNames[(h % #starNames) + 1]
end

-- Deterministic hub/checkpoint star name for a galaxy (real star names).
function M.hubStarName(galaxy)
    if not galaxy then return nil end
    if galaxy.id == "milkyway" then return i18n.t("minimap_earth_label") end
    local hubNames = i18n.t("hub_star_names")
    if type(hubNames) ~= "table" or #hubNames == 0 then return "HUB" end
    local h = math.floor(hash(galaxy.gx or 0, galaxy.gy or 0, 760) * 1000000)
    return hubNames[(h % #hubNames) + 1]
end

-- Deterministic per-galaxy background tint (docs/feedback/INBOX.md item 1
-- part 4, "은하계별 배경색 변화"): the home solar system keeps the
-- established dark navy/blue clear color, and every other galaxy gets a
-- small deterministic hue shift (violet/teal/red family) derived from its
-- grid cell so crossing into a different galaxy visibly changes mood.
-- Pure data function -- PlayScene.draw() just calls love.graphics.clear
-- with the returned r, g, b.
local homeBackgroundColor = { 0.015, 0.02, 0.055 }
M.homeBackgroundColor = homeBackgroundColor

function M.galaxyBackgroundColor(galaxy)
    if not galaxy or galaxy.id == "milkyway" then
        return homeBackgroundColor[1], homeBackgroundColor[2], homeBackgroundColor[3]
    end
    local hue = hash(galaxy.gx, galaxy.gy, 560)
    -- Three base tint families cycling by hue bucket, each nudged by a
    -- little per-galaxy jitter so neighboring galaxies in the same family
    -- still read as distinct from each other.
    local families = {
        { 0.05, 0.015, 0.06 }, -- violet
        { 0.01, 0.045, 0.05 }, -- teal
        { 0.06, 0.015, 0.02 }, -- ember red
    }
    local family = families[1 + math.floor(hue * 3) % 3]
    local jitter = (hash(galaxy.gx, galaxy.gy, 561) - 0.5) * 0.02
    return family[1] + jitter, family[2] + jitter, family[3] + jitter
end

-- Deterministic world-space position of a galaxy's central star (the pivot
-- its spiral arms/orbits wind around). The home solar system spirals around
-- the SUN, not Earth; Earth stays at world origin for altitude math.
function M.sunPosition(galaxy)
    if not galaxy then return nil end
    if galaxy.id == "milkyway" then
        local angle = hash(0, 0, 570) * math.pi * 2
        local dist = M.galaxyCellSize * 0.12
        return { x = math.cos(angle) * dist, y = math.sin(angle) * dist }
    end
    return { x = galaxy.x, y = galaxy.y }
end

-- Item 9: Central star "gravity well" parameters. starRadius is the
-- visual body radius of the galaxy's central star (same scale as
-- hubPlanet.radius).  wellRadius = starRadius * 4 defines the danger
-- zone where gravity pull, DoT damage, and the 10-second sample timer
-- apply.  dotInterval is the period between 1-HP ticks inside the well.
-- survivalTime is how long the ship must remain continuously inside the
-- well to earn the one-time-per-galaxy sample.
M.starRadius = 80
M.starWellMultiplier = 2
M.starWellRadius = M.starRadius * M.starWellMultiplier -- 160
M.starDotInterval = 0.5   -- seconds between 1-damage ticks
M.starSurvivalTime = 10   -- continuous seconds for sample reward
M.starGravityStrength = 40 -- pull force (px/s²) at starRadius distance (was 120; reduced so edge is escapable)
M.starDangerTextMultiplier = 1.5 -- DANGER text appears when ship < wellRadius * this

-- Slow fixed helm speed while sampling the central star. Farther galaxies
-- (higher engine-part tiers) get an even slower cap so the 10s dwell is
-- a real risk instead of a fly-through.
function M.starWellSpeed(galaxy)
    if not galaxy or galaxy.id == "milkyway" or ((galaxy.gx or 0) == 0 and (galaxy.gy or 0) == 0) then
        return 22
    end
    local d = math.sqrt((galaxy.gx or 0) ^ 2 + (galaxy.gy or 0) ^ 2)
    if d < 1.6 then return 14 end
    if d < 3.2 then return 9 end
    return 5
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
    -- Item 10 change B: offset hub from galaxy center (sunPosition) so the
    -- minimap can show sun and hub as distinct markers.  The hub sits on a
    -- hash-deterministic angle at ~18% of galaxy.radius (min 80 wu) from
    -- the center, inside the inner spiral but clearly not at the sun.
    local angle = hash(gx, gy, 580) * math.pi * 2
    local dist = math.max(80, galaxy.radius * 0.18)
    local hubX = galaxy.x + math.cos(angle) * dist
    local hubY = galaxy.y + math.sin(angle) * dist
    return {
        id = "hub:" .. galaxy.id,
        x = hubX,
        y = hubY,
        radius = 40 + math.floor(hash(gx, gy, 540) * 16),
        hue = hash(gx, gy, 550),
        hub = true,
        galaxyId = galaxy.id,
        galaxyStarType = galaxy.starType,
        galaxyStarTypeIdx = galaxy.starTypeIdx,
    }
end

function M.shopPlanet(galaxy)
    if not galaxy or galaxy.id == "milkyway" then
        return nil
    end
    local gx, gy = galaxy.gx, galaxy.gy
    local dx = (hash(gx, gy, 800) - 0.5) * galaxy.radius * 1.2
    local dy = (hash(gx, gy, 810) - 0.5) * galaxy.radius * 1.2
    return {
        id = "shop:" .. galaxy.id,
        x = galaxy.x + dx,
        y = galaxy.y + dy,
        radius = 14 + math.floor(hash(gx, gy, 820) * 6),
        hue = hash(gx, gy, 830),
        isShop = true,
        galaxyId = galaxy.id,
        galaxyStarType = galaxy.starType,
        galaxyStarTypeIdx = galaxy.starTypeIdx,
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
    local galaxy = M.galaxyContaining(centerX, centerY)
    if not galaxy then
        return {}
    end
    local count = hash(sectorX, sectorY, 1) > 0.85 and 1 or 0
    if hash(sectorX, sectorY, 7) > 0.98 then count = 2 end
    local planets = {}
    -- Clamp hue within ±0.083 of the galaxy's baseHue so planets in the same
    -- galaxy share a consistent colour mood. (0.083 ≈ 30°/360°)
    local baseHue = galaxy.baseHue or 0.5
    for i = 1, count do
        local radius = 14 + math.floor(hash(sectorX + i * 7, sectorY + i * 13, 20) * 20)
        local rawHue = hash(sectorX + i * 11, sectorY + i * 17, 80)
        -- Map rawHue into [baseHue-0.083, baseHue+0.083], wrapping in 0..1
        local hue = (baseHue - 0.083 + rawHue * 0.166) % 1
        planets[#planets + 1] = {
            id = string.format("%d:%d:%d", sectorX, sectorY, i),
            x = sectorX * M.sectorSize + 24 + hash(sectorX + i * 7, sectorY, 40) * (M.sectorSize - 48),
            y = sectorY * M.sectorSize + 24 + hash(sectorX, sectorY + i * 13, 60) * (M.sectorSize - 48),
            radius = radius,
            hue = hue,
            galaxyStarType = galaxy.starType,
            galaxyStarTypeIdx = galaxy.starTypeIdx,
        }
    end
    -- Overlap prevention: when two planets spawn in the same sector, ensure
    -- they are at least (r1 + r2 + 10) apart; otherwise drop the second.
    if #planets == 2 then
        local p1, p2 = planets[1], planets[2]
        local dx = p2.x - p1.x
        local dy = p2.y - p1.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local minDist = p1.radius + p2.radius + 10
        if dist < minDist then
            planets[2] = nil  -- remove overlapping second planet
        end
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
        local shop = M.shopPlanet(galaxy)
        if shop then
            local ssx, ssy = M.sectorAt(shop.x, shop.y)
            if ssx >= minSx and ssx <= maxSx and ssy >= minSy and ssy <= maxSy then
                result[#result + 1] = shop
            end
        end
    end
    return result
end

-- Drifting asteroids and junk. Deterministic per sector like planets, then
-- offset by (vx, vy) * time so pieces actually float. Collision is handled
-- by PlayScene using the same destroy/reset path as a lethal planet hit.
function M.debris(sectorX, sectorY, time)
    time = time or 0
    local count = 0
    if hash(sectorX, sectorY, 900) > 0.25 then count = 1 end
    if hash(sectorX, sectorY, 901) > 0.80 then count = 2 end
    local pieces = {}
    for i = 1, count do
        local kindRoll = hash(sectorX + i * 7, sectorY + i * 13, 910)
        local kind = "asteroid"
        if kindRoll < 0.22 then
            kind = "can"
        elseif kindRoll < 0.44 then
            kind = "scrap"
        end
        local minR, maxR = 4, 6   -- asteroid — no large chunks
        if kind == "can" then
            minR, maxR = 3, 4
        elseif kind == "scrap" then
            minR, maxR = 3, 5
        end
        local radius = minR + math.floor(hash(sectorX, sectorY, 920 + i) * (maxR - minR + 1))
        local ang = hash(sectorX, sectorY, 930 + i) * 2 * math.pi
        local spd = 6 + hash(sectorX, sectorY, 932 + i) * 10
        local vx = math.cos(ang) * spd
        local vy = math.sin(ang) * spd
        -- Start position: offset so piece enters from outside the sector boundary.
        -- At time=0, piece is at (-margin) along its velocity direction from its
        -- base position, so it drifts INTO the sector over time and never pops
        -- into existence mid-screen.
        local margin = M.sectorSize * 0.6
        local startOffX = -math.cos(ang) * margin
        local startOffY = -math.sin(ang) * margin
        local baseX = sectorX * M.sectorSize + 16
            + hash(sectorX, sectorY, 950 + i) * (M.sectorSize - 32)
            + startOffX
        local baseY = sectorY * M.sectorSize + 16
            + hash(sectorX, sectorY, 960 + i) * (M.sectorSize - 32)
            + startOffY
        local baseRotation = hash(sectorX + i, sectorY, 970) * 2 * math.pi
        local rotSpeed = (hash(sectorX + i, sectorY, 971) - 0.5) * 2  -- ±1 rad/s
        -- No wrapping — pieces drift continuously from outside the sector.
        -- nearbyDebris scan radius (4 sectors) covers enough that pieces
        -- drifting out of their home sector are still returned by a neighbor.
        pieces[#pieces + 1] = {
            id = string.format("debris:%d:%d:%d", sectorX, sectorY, i),
            x = baseX + vx * time,
            y = baseY + vy * time,
            radius = radius,
            kind = kind,
            vx = vx,
            vy = vy,
            rotation = baseRotation + rotSpeed * time,
            rotSpeed = rotSpeed,
        }
    end
    return pieces
end

function M.nearbyDebris(x, y, radiusInSectors, time)
    local sx, sy = M.sectorAt(x, y)
    local result = {}
    for oy = -radiusInSectors, radiusInSectors do
        for ox = -radiusInSectors, radiusInSectors do
            for _, piece in ipairs(M.debris(sx + ox, sy + oy, time)) do
                result[#result + 1] = piece
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
    return 1
end

function M.collisionDamage(planet)
    local distance = distanceFromEarth(planet)
    -- Gentle scaling: 1 at Earth, +1 per 2000px (was /500, too steep)
    return 1 + math.floor(distance / 2000)
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
    local countHash = hash(sectorX * 5 + 3, sectorY * 9 + 1, 9999)
    local count = 10 + math.floor(countHash * 9)  -- 10 to 18 per sector
    for i = 1, count do
        local hx = hash(sectorX * 7 + i * 29, sectorY * 11 + i * 47, 10001 + i * 89)
        local hy = hash(sectorX * 13 + i * 37, sectorY * 7 + i * 59, 20001 + i * 71)
        stars[#stars + 1] = {
            x = (sectorX + hx - 0.15) * M.sectorSize + hx * M.sectorSize * 0.3,
            y = (sectorY + hy - 0.15) * M.sectorSize + hy * M.sectorSize * 0.3,
            bright = hash(sectorX + i * 17, sectorY + i * 31, 300 + i * 43),
        }
    end
    return stars
end

-- UI/HUD cleanup item 1 (docs/feedback/INBOX.md, 2026-09-02): the 18
-- meteor-like stars per sector from M.stars() read as sparse. The user
-- likes that streaking-meteor foreground layer and wants it kept as-is, so
-- this adds a second, independently-seeded and much denser field meant to
-- be drawn behind it with little/no parallax as a near-static Milky Way
-- backdrop. Uses a disjoint salt range (10000+) so it never coincides with
-- M.stars' points, and dims/shrinks are handled by the caller (play.lua)
-- via the `bright` field, kept in the same 0..1 range for consistency.
M.backgroundStarCount = 200

function M.backgroundStars(sectorX, sectorY)
    local stars = {}
    -- Variable star count per sector (2 to backgroundStarCount) to break regularity
    local countHash = hash(sectorX * 3 + 7, sectorY * 5 + 13, 49999)
    local count = 2 + math.floor(countHash * (M.backgroundStarCount - 1))
    for i = 1, count do
        -- Heavy jitter: hash feeds unique per-star scrambled coords
        -- so adjacent sectors produce uncorrelated positions
        local hx = hash(sectorX * 7 + i * 31, sectorY * 13 + i * 53, 50001 + i * 97)
        local hy = hash(sectorX * 11 + i * 43, sectorY * 7 + i * 67, 60001 + i * 83)
        stars[#stars + 1] = {
            x = (sectorX + hx - 0.15) * M.sectorSize + hx * M.sectorSize * 0.3,
            y = (sectorY + hy - 0.15) * M.sectorSize + hy * M.sectorSize * 0.3,
            bright = hash(sectorX + i * 19, sectorY + i * 23, 30000 + i * 41) * 0.55,
        }
    end
    return stars
end

M.hash = hash

---------------------------------------------------------------------------
-- Comet system (INBOX 35)
-- Comets are fast-moving, rare, high-reward celestial bodies that appear
-- during the ascending phase. They spawn from one screen edge and travel
-- in a straight line to the opposite edge.
---------------------------------------------------------------------------

M.comets = {}           -- runtime list of active comets
M.cometIdCounter = 0    -- monotonic id counter
M.cometNextSpawn = 60   -- first spawn at 60 seconds (guaranteed)
M.cometSpawnInterval = 30
M.cometSpawnChance = 0.30
M.cometFirstSpawned = false

-- Reset comet state (call on new expedition / phase change)
-- startTime: current game clock so the first comet spawns 60s from NOW.
function M.resetComets(startTime)
    M.comets = {}
    M.cometIdCounter = 0
    M.cometNextSpawn = (startTime or 0) + 60
    M.cometFirstSpawned = false
end

-- Spawn a comet near the ship's viewport. Returns the new comet or nil.
-- shipX, shipY = world coords of ship (camera center).
-- viewW, viewH = viewport dimensions.
function M.spawnComet(time, shipX, shipY, viewW, viewH)
    viewW = viewW or 720
    viewH = viewH or 1280
    M.cometIdCounter = M.cometIdCounter + 1
    local id = "comet_" .. M.cometIdCounter

    -- Random radius 8-12
    local radius = 8 + math.floor(hash(M.cometIdCounter, 77, 9001) * 5)

    -- Random speed 80-120 px/s
    local speed = (80 + hash(M.cometIdCounter, 88, 9002) * 40) * 3  -- 240-360 px/s (3x)

    -- Pick an entry edge (0=left, 1=right, 2=top, 3=bottom)
    local edge = math.floor(hash(M.cometIdCounter, 99, 9003) * 4)
    local startX, startY, vx, vy
    local margin = 40
    if edge == 0 then       -- enter from left
        startX = shipX - viewW / 2 - margin
        startY = shipY - viewH / 2 + hash(M.cometIdCounter, 100, 9004) * viewH
        vx = speed
        vy = (hash(M.cometIdCounter, 101, 9005) - 0.5) * speed * 0.3
    elseif edge == 1 then   -- enter from right
        startX = shipX + viewW / 2 + margin
        startY = shipY - viewH / 2 + hash(M.cometIdCounter, 100, 9004) * viewH
        vx = -speed
        vy = (hash(M.cometIdCounter, 101, 9005) - 0.5) * speed * 0.3
    elseif edge == 2 then   -- enter from top
        startX = shipX - viewW / 2 + hash(M.cometIdCounter, 100, 9004) * viewW
        startY = shipY - viewH / 2 - margin
        vx = (hash(M.cometIdCounter, 101, 9005) - 0.5) * speed * 0.3
        vy = speed
    else                    -- enter from bottom
        startX = shipX - viewW / 2 + hash(M.cometIdCounter, 100, 9004) * viewW
        startY = shipY + viewH / 2 + margin
        vx = (hash(M.cometIdCounter, 101, 9005) - 0.5) * speed * 0.3
        vy = -speed
    end

    local comet = {
        id = id,
        spawnTime = time,
        startX = startX,
        startY = startY,
        vx = vx,
        vy = vy,
        radius = radius,
        speed = speed,
        hue = 0.12, -- yellow-ish
    }
    M.comets[#M.comets + 1] = comet
    return comet
end

-- Get current world position of a comet at the given time
function M.cometPosition(comet, time)
    local dt = time - comet.spawnTime
    return comet.startX + comet.vx * dt,
           comet.startY + comet.vy * dt
end

-- Check spawn timer and potentially spawn a comet.
-- Returns the spawned comet or nil.
function M.tickCometSpawn(time, shipX, shipY, viewW, viewH)
    if time < M.cometNextSpawn then return nil end

    local shouldSpawn = false
    if not M.cometFirstSpawned then
        -- First spawn at 60s is guaranteed
        shouldSpawn = true
        M.cometFirstSpawned = true
    else
        -- 30% chance every 30 seconds after that
        -- Use a time-based hash for determinism in tests
        local roll = hash(math.floor(time * 100), 555, 9010)
        shouldSpawn = roll < M.cometSpawnChance
    end

    M.cometNextSpawn = M.cometNextSpawn + M.cometSpawnInterval

    if shouldSpawn then
        return M.spawnComet(time, shipX, shipY, viewW, viewH)
    end
    return nil
end

-- Return comets near (shipX, shipY) with updated positions.
-- Also prunes comets that have traveled too far off-screen.
function M.nearbyComets(shipX, shipY, time, viewW, viewH)
    viewW = viewW or 720
    viewH = viewH or 1280
    local nearby = {}
    local alive = {}
    local maxDist = math.max(viewW, viewH) * 1.5 -- prune distance
    for _, comet in ipairs(M.comets) do
        local cx, cy = M.cometPosition(comet, time)
        local dx = cx - shipX
        local dy = cy - shipY
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist < maxDist then
            alive[#alive + 1] = comet
            nearby[#nearby + 1] = {
                id = comet.id,
                x = cx,
                y = cy,
                radius = comet.radius,
                hue = comet.hue,
                speed = comet.speed,
                vx = comet.vx,
                vy = comet.vy,
            }
        end
    end
    M.comets = alive
    return nearby
end

-- Comet sample value: 50x planet sample value at that position
function M.cometSampleValue(comet)
    return M.sampleValue(comet) * 50
end

-- Comet collision damage: same formula as planets
function M.cometCollisionDamage(comet)
    return M.collisionDamage(comet)
end

-- ── INBOX-37: Moon (satellite) system ──────────────────────────────
-- Each planet has a 30% chance of one orbiting moon.
-- Moon orbits at planet.radius + 15~25px, period 3s, radius 3~5px.
-- Sample value: 10x planet ($10). Collision damage: same as planet.

function M.planetHasMoon(planet)
    -- Shop planets sell hull parts — no moons so the shop approach stays clean.
    if planet and planet.isShop then return false end
    return hash(planet.x or 0, planet.y or 0, 700) > 0.7
end

function M.moonForPlanet(planet, time)
    if not M.planetHasMoon(planet) then return nil end
    local orbitRadius = planet.radius + 25 + math.floor(hash(planet.x or 0, planet.y or 0, 701) * 15) -- 25~39
    local moonRadiusBase = 6 + math.floor(hash(planet.x or 0, planet.y or 0, 702) * 6) -- 6~11 (collect radius)
    local moonRadius = math.max(4, math.floor(moonRadiusBase * 0.75)) -- visual 75%
    -- Vary orbit period: 1.5~5s — faster moons are harder to catch
    local speedHash = hash(planet.x or 0, planet.y or 0, 704)
    local period = 1.5 + speedHash * 3.5 -- 1.5~5.0 seconds
    local angle = (time or 0) * (2 * math.pi / period)
    -- Offset phase per planet so moons don't all start at 0
    angle = angle + hash(planet.x or 0, planet.y or 0, 703) * 2 * math.pi
    local mx = planet.x + math.cos(angle) * orbitRadius
    local my = planet.y + math.sin(angle) * orbitRadius
    -- Moon color: brighter version of planet hue
    local hue = planet.hue or 0.5
    -- Speed factor for reward: 0.0 (slowest) ~ 1.0 (fastest)
    local speedFactor = 1.0 - (speedHash) -- inverted: low period = fast = high factor
    return {
        id = (planet.id or "?") .. ":moon",
        x = mx,
        y = my,
        radius = moonRadius,
        collectRadius = moonRadiusBase,
        orbitRadius = orbitRadius,
        hue = hue,
        parentId = planet.id,
        parentX = planet.x,
        parentY = planet.y,
        period = period,
        speedFactor = speedFactor,
    }
end

function M.moonSampleValue(moon)
    -- Faster moons (lower period) give higher reward: $2~$10
    local factor = (moon and moon.speedFactor) or 0.5
    return 2 + math.floor(factor * 8) -- 2~10
end

function M.moonCollisionDamage(moon)
    -- Parent-planet distance as the floor, plus extra from orbit speed
    -- (user 2026-09-07: faster moons deal more damage, matching $2~$10 reward).
    -- speedFactor 0 → +0, 0.5 → +1, 1.0 → +2.
    local base = M.collisionDamage({ x = moon.parentX, y = moon.parentY })
    local factor = (moon and moon.speedFactor) or 0.5
    return base + math.floor(factor * 2 + 0.5)
end

return M
