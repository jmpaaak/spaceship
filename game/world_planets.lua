-- Sector planet generation extracted from game/world.lua.
-- Pure rules only: no love.*. Callers keep using world.planets().
local M = {}

function M.planets(world, sectorX, sectorY)
    local centerX = sectorX * world.sectorSize + world.sectorSize / 2
    local centerY = sectorY * world.sectorSize + world.sectorSize / 2
    -- Planets only ever generate inside a galaxy's radius; deep space
    -- between galaxies is empty. See the galaxy structure comment above.
    local galaxy = world.galaxyContaining(centerX, centerY)
    if not galaxy then
        return {}
    end
    local hash = world.hash
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
            x = sectorX * world.sectorSize + 24 + hash(sectorX + i * 7, sectorY, 40) * (world.sectorSize - 48),
            y = sectorY * world.sectorSize + 24 + hash(sectorX, sectorY + i * 13, 60) * (world.sectorSize - 48),
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

return M
