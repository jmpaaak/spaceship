-- Sector planet generation extracted from game/world.lua.
-- Pure rules only: no love.*. Callers keep using world.planets().
local M = {}

local function getBasePlanets(world, sectorX, sectorY)
    local centerX = sectorX * world.sectorSize + world.sectorSize / 2
    local centerY = sectorY * world.sectorSize + world.sectorSize / 2
    local galaxy = world.galaxyContaining(centerX, centerY)
    if not galaxy then
        return {}
    end
    local hash = world.hash
    local count = hash(sectorX, sectorY, 1) > 0.85 and 1 or 0
    if hash(sectorX, sectorY, 7) > 0.98 then count = 2 end
    local planets = {}
    local baseHue = galaxy.baseHue or 0.5
    for i = 1, count do
        local radius = 14 + math.floor(hash(sectorX + i * 7, sectorY + i * 13, 20) * 20)
        local rawHue = hash(sectorX + i * 11, sectorY + i * 17, 80)
        local hue = (baseHue - 0.083 + rawHue * 0.166) % 1
        
        -- INBOX 64: Polar coordinates seeded by both axes and i
        local ang = hash(sectorX * 31 + i * 17, sectorY * 19 + i * 23, 140) * math.pi * 2
        -- Use sqrt for uniform area distribution. Allow wider spread to pass stddev test.
        local maxR = world.sectorSize / 2
        local dist = math.sqrt(hash(sectorX * 17 + i * 29, sectorY * 41 + i * 53, 160)) * maxR
        
        planets[#planets + 1] = {
            id = string.format("%d:%d:%d", sectorX, sectorY, i),
            x = centerX + math.cos(ang) * dist,
            y = centerY + math.sin(ang) * dist,
            radius = radius,
            hue = hue,
            galaxyStarType = galaxy.starType,
            galaxyStarTypeIdx = galaxy.starTypeIdx,
        }
    end
    -- Self-overlap within sector
    if #planets == 2 then
        local p1, p2 = planets[1], planets[2]
        local dx = p2.x - p1.x
        local dy = p2.y - p1.y
        local dist = math.sqrt(dx * dx + dy * dy)
        local minDist = p1.radius + p2.radius + 10
        if dist < minDist then
            planets[2] = nil
        end
    end
    return planets
end

function M.planets(world, sectorX, sectorY)
    local myPlanets = getBasePlanets(world, sectorX, sectorY)
    if #myPlanets == 0 then return {} end
    
    local validPlanets = {}
    for _, p1 in ipairs(myPlanets) do
        local ok = true
        for oy = -1, 1 do
            for ox = -1, 1 do
                if ox ~= 0 or oy ~= 0 then
                    local neighbors = getBasePlanets(world, sectorX + ox, sectorY + oy)
                    for _, p2 in ipairs(neighbors) do
                        local dx = p2.x - p1.x
                        local dy = p2.y - p1.y
                        local dist = math.sqrt(dx * dx + dy * dy)
                        local minDist = p1.radius + p2.radius + 10
                        if dist < minDist then
                            -- Tie-breaker: keep the one with the larger ID
                            if p2.id > p1.id then
                                ok = false
                                break
                            end
                        end
                    end
                end
                if not ok then break end
            end
            if not ok then break end
        end
        if ok then
            validPlanets[#validPlanets + 1] = p1
        end
    end
    return validPlanets
end

return M
