-- Pure minimap projection (docs/GAME_DESIGN.md 이동 방식 개선 항목 2·3):
-- a tiny circular chart of nearby galaxy centers plus the player's
-- position, with no hard world wall. When the ship is farther from Earth
-- than the chart's reference radius, the map does not clamp the ship in
-- the world -- it only reports how far past that reference circle the
-- ship has gone and the direction back toward Earth.
--
-- Deliberately framework-free (no love.* calls) so it can be unit tested
-- headlessly; PlayScene only consumes the returned marker list to draw.
local world = require("game.world")
local M = {}

-- Canvas-pixel diameter of the drawn chart (fits in the top-right of the
-- 180x320 HUD without covering the left-aligned ALT/CASH text).
M.size = 48
M.inset = 4
M.mapRadius = M.size / 2 - M.inset

-- World-unit radius of the chart around the player (how much of the
-- galaxy grid one minimap "screen" covers). ~2.5 galaxy cells so a
-- handful of neighboring galaxies fit as distinct dots.
M.viewRadius = world.galaxyCellSize * 2.5

-- Reference "known universe" circle around Earth. This is NOT a collision
-- wall -- ships may fly arbitrarily far. Past this radius the minimap
-- switches to the beyond-chart readout (distance + return bearing).
M.chartRadius = world.galaxyCellSize * 5

-- How many galaxy-grid cells around the player to plot.
M.galaxyCellRadius = 2

-- Projects world point (wx, wy) into minimap space relative to origin
-- (ox, oy). Returns mx, my (canvas offsets from the chart center, already
-- clamped onto the rim when the point sits outside viewRadius), inside
-- (whether the point is strictly inside the chart), and world distance
-- from the origin.
function M.project(wx, wy, ox, oy)
    local dx, dy = wx - ox, wy - oy
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 1e-9 then
        return 0, 0, true, 0
    end
    local scaled = dist * M.mapRadius / M.viewRadius
    local inside = scaled <= M.mapRadius
    local mag = inside and scaled or M.mapRadius
    return dx / dist * mag, dy / dist * mag, inside, dist
end

-- Snapshot of everything PlayScene needs to draw the chart for a ship at
-- (shipX, shipY). Player is always at the chart origin (player-centered)
-- so nearby galaxies stay readable as the ship travels; Earth is a
-- separate marker that clamps to the rim when it falls outside viewRadius.
function M.view(shipX, shipY)
    local distEarth = math.sqrt(shipX * shipX + shipY * shipY)
    local beyond = distEarth > M.chartRadius
    local returnDx, returnDy = 0, 0
    if distEarth > 1e-9 then
        returnDx = -shipX / distEarth
        returnDy = -shipY / distEarth
    end
    local earthX, earthY, earthInside = M.project(0, 0, shipX, shipY)
    local galaxies = {}
    local rings = {}
    for _, galaxy in ipairs(world.nearbyGalaxies(shipX, shipY, M.galaxyCellRadius)) do
        local mx, my, inside = M.project(galaxy.x, galaxy.y, shipX, shipY)
        galaxies[#galaxies + 1] = {
            id = galaxy.id,
            name = galaxy.name,
            x = mx,
            y = my,
            inside = inside,
            hub = galaxy.id ~= "milkyway",
        }
        local scaled = galaxy.radius * M.mapRadius / M.viewRadius
        rings[#rings + 1] = {
            id = galaxy.id,
            name = galaxy.name,
            x = mx,
            y = my,
            radius = math.max(2, math.min(scaled, M.mapRadius)),
            kind = "galaxy",
            inside = inside,
        }
    end
    -- Sun-centered solar-system orbits: readable pixel rings around the
    -- sun marker (true AU scale is sub-pixel on this chart).
    if earthInside or math.sqrt(earthX * earthX + earthY * earthY) < M.mapRadius then
        for _, radius in ipairs({ 4, 7, 11 }) do
            rings[#rings + 1] = {
                x = earthX,
                y = earthY,
                radius = radius,
                kind = "orbit",
            }
        end
    end
    local containing = world.galaxyContaining(shipX, shipY)
    return {
        player = { x = 0, y = 0 },
        earth = { x = earthX, y = earthY, inside = earthInside },
        sun = { x = earthX, y = earthY, inside = earthInside },
        galaxies = galaxies,
        rings = rings,
        galaxyName = containing and containing.name or nil,
        beyond = beyond,
        distanceBeyond = beyond and (distEarth - M.chartRadius) or 0,
        returnDx = returnDx,
        returnDy = returnDy,
    }
end

return M
