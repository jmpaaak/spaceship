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
-- 720x1280 HUD without covering the left-aligned DIST/CASH text).
M.size = 192
M.inset = 16
M.mapRadius = M.size / 2 - M.inset

-- World-unit radius of the chart around the player (how much of the
-- galaxy grid one minimap "screen" covers). Zoomed in to 0.7 cells
-- so the current galaxy fills most of the chart and the hub is distinct.
M.viewRadius = world.galaxyCellSize * 0.7

-- docs/feedback/INBOX.md "내부 해상도를 발라트로 수준으로 상향" — remaining
-- decorative px: the small marker dot/ring radii drawn on the minimap
-- chart (sun, galaxy dots, Earth, player, beyond-chart arrow, checkpoint
-- arrow) were still the old 180x320-era pixel sizes. ×4 so they keep the
-- same screen fraction on the 720x1280 canvas / M.size (which was already
-- scaled 48 -> 192, i.e. also ×4).
-- Mobile-UI sub-item (2): all marker radii ×1.5 for mobile readability.
-- Original values in parentheses for reference.
M.markerSunRadius = 15.6           -- (was 10.4)
M.markerGalaxyHomeRadius = 13.2    -- (was 8.8)
-- docs/feedback/INBOX.md item 1 part 2: the checkpoint galaxy marker used to
-- be a plain filled dot (radius 9.2) plus a big pulsing ring (radius 16,
-- 20% of the whole mapRadius=80) -- too large relative to the chart and
-- indistinguishable in shape from an ordinary galaxy dot at a glance.
-- Shrunk and replaced with a small distinct star glyph (M.starPoints) so it
-- reads as a special waypoint rather than "a bigger circle".
M.markerGalaxyHubRadius = 8.4      -- (was 5.6)
M.markerGalaxyHubRingRadius = 24   -- (was 16)
M.markerGalaxyPlainRadius = 9      -- (was 6)
M.markerEarthRadius = 12           -- (was 8)
M.markerPlayerFillRadius = 10.2    -- (was 6.8)
M.markerPlayerLineRadius = 14.4    -- (was 9.6)
M.markerBeyondRadius = 13.2        -- (was 8.8)
M.markerCheckpointTipRadius = 10.8 -- (was 7.2)

-- Reference "known universe" circle around Earth. This is NOT a collision
-- wall -- ships may fly arbitrarily far. Past this radius the minimap
-- switches to the beyond-chart readout (distance + return bearing).
M.chartRadius = world.galaxyCellSize * 5

-- How many galaxy-grid cells around the player to plot.
M.galaxyCellRadius = 2

-- Wider search window used only to find the nearest off-chart checkpoint
-- for the direction arrow (docs/feedback/INBOX.md item 1). Every
-- non-milkyway galaxy already has a guaranteed hub/checkpoint planet at
-- its center (world.hubPlanet), so "nearest checkpoint" is simply the
-- nearest non-home galaxy. This window is wider than galaxyCellRadius so
-- the arrow can still find a target even when it is diagonally outside
-- the plotted-dot window (a real gap: a galaxy inside galaxyCellRadius's
-- square scan can still be farther than viewRadius on the diagonal, so it
-- is silently skipped by the dot-drawing "inside" check today).
M.checkpointSearchCellRadius = M.galaxyCellRadius + 4

-- docs/feedback/INBOX.md item 13: concentric rings replace the old spiral
-- arms. Ring count (2-5) is derived from galaxy.radius using the same
-- bracket table the old spiralArmCount used.
function M.concentricRingCount(galaxy)
    if not galaxy then return 2 end
    local r = galaxy.radius
    if r < 1000 then return 2
    elseif r < 1400 then return 3
    elseif r < 1800 then return 4
    else return 5
    end
end

-- Pure function: flat {x1, y1, x2, y2, ...} polygon points for a small
-- 5-point star glyph centered on (cx, cy), alternating outer/inner radius.
-- Used to mark checkpoint galaxies distinctly from ordinary galaxy dots
-- (docs/feedback/INBOX.md item 1 part 2) instead of a large plain ring.
function M.starPoints(cx, cy, outerRadius, innerRadius)
    innerRadius = innerRadius or outerRadius * 0.45
    local points = {}
    local spikes = 5
    for i = 0, spikes * 2 - 1 do
        local r = (i % 2 == 0) and outerRadius or innerRadius
        local angle = -math.pi / 2 + i * math.pi / spikes
        points[#points + 1] = cx + math.cos(angle) * r
        points[#points + 1] = cy + math.sin(angle) * r
    end
    return points
end

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

-- Pure function: nearest non-home-galaxy checkpoint's direction and
-- distance from world point (shipX, shipY). Every non-milkyway galaxy
-- guarantees a hub/checkpoint planet at its center (world.hubPlanet), so
-- this is simply the nearest other galaxy within checkpointSearchCellRadius
-- cells. Returns unit-vector dx, dy (0, 0 if none found), the world
-- distance (nil if none found), and the galaxy id (nil if none found).
function M.nearestCheckpointDirection(shipX, shipY)
    local nearest, nearestDist, nearestHub
    for _, galaxy in ipairs(world.nearbyGalaxies(shipX, shipY, M.checkpointSearchCellRadius)) do
        if galaxy.id ~= "milkyway" then
            -- Item 10 change B: point toward the offset hub planet, not
            -- galaxy center (the sun).
            local hubObj = world.hubPlanet(galaxy)
            local tx, ty = hubObj and hubObj.x or galaxy.x, hubObj and hubObj.y or galaxy.y
            local dx, dy = tx - shipX, ty - shipY
            local dist = math.sqrt(dx * dx + dy * dy)
            if not nearestDist or dist < nearestDist then
                nearest, nearestDist, nearestHub = galaxy, dist, hubObj
            end
        end
    end
    if not nearest then
        return 0, 0, nil, nil
    end
    local tx = nearestHub and nearestHub.x or nearest.x
    local ty = nearestHub and nearestHub.y or nearest.y
    if nearestDist < 1e-9 then
        return 0, 0, 0, nearest.id, nearest
    end
    return (tx - shipX) / nearestDist, (ty - shipY) / nearestDist, nearestDist, nearest.id, nearest
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
    -- docs/feedback/INBOX.md item 1 part 3: the home solar system's spiral
    -- and orbit rings must pivot on the SUN (world.sunPosition), not on
    -- Earth. Earth keeps its own separate marker (projected at world
    -- origin above) so it now reads as one of the orbiting planets rather
    -- than the center.
    local containing = world.galaxyContaining(shipX, shipY)
    
    local sunX, sunY, sunInside = nil, nil, nil
    if containing then
        local currentSun = world.sunPosition(containing)
        sunX, sunY, sunInside = M.project(currentSun.x, currentSun.y, shipX, shipY)
    end
    local galaxies = {}
    local rings = {}
    local hubMarkers = {}   -- item 10 change B: separate hub markers
    for _, galaxy in ipairs(world.nearbyGalaxies(shipX, shipY, M.galaxyCellRadius)) do
        local mx, my, inside = M.project(galaxy.x, galaxy.y, shipX, shipY)
        galaxies[#galaxies + 1] = {
            id = galaxy.id,
            name = world.galaxyName(galaxy),
            x = mx,
            y = my,
            inside = inside,
            hub = galaxy.id ~= "milkyway",
        }
        local scaled = galaxy.radius * M.mapRadius / M.viewRadius
        rings[#rings + 1] = {
            id = galaxy.id,
            name = world.galaxyName(galaxy),
            x = mx,
            y = my,
            radius = math.max(2, math.min(scaled, M.mapRadius)),
            kind = "galaxy",
            inside = inside,
        }
        -- Item 10 change B: project the offset hub planet so PlayScene can
        -- draw it as a distinct marker (magenta diamond) next to the gold
        -- galaxy-center/sun dot.
        local hubObj = world.hubPlanet(galaxy)
        if hubObj then
            local hx, hy, hInside = M.project(hubObj.x, hubObj.y, shipX, shipY)
            hubMarkers[#hubMarkers + 1] = {
                id = galaxy.id,
                x = hx,
                y = hy,
                inside = hInside,
            }
        end
    end
    -- Sun-centered solar-system orbits: readable pixel rings around the
    -- sun marker (true AU scale is sub-pixel on this chart). Earth's own
    -- orbit (radius 7, matching its position roughly between the inner and
    -- outer decorative rings) is included below so Earth visibly reads as
    -- one of the orbiting bodies around the sun rather than the pivot.
    if sunInside ~= nil and (sunInside or math.sqrt(sunX * sunX + sunY * sunY) < M.mapRadius) then
        for _, radius in ipairs({ 4, 7, 11 }) do
            rings[#rings + 1] = {
                x = sunX,
                y = sunY,
                radius = radius,
                kind = "orbit",
            }
        end
    end
    -- docs/feedback/INBOX.md item 13: concentric rings for the current galaxy.
    -- Evenly spaced rings from center to galaxy.radius, projected onto the
    -- minimap. Drawn as "line" circles in the gold color.
    if containing then
        local sun = world.sunPosition(containing)
        local ringCount = M.concentricRingCount(containing)
        local sunMx, sunMy, sunInside2 = M.project(sun.x, sun.y, shipX, shipY)
        for i = 1, ringCount do
            local worldRadius = containing.radius * (i / ringCount)
            local scaledRadius = worldRadius * M.mapRadius / M.viewRadius
            rings[#rings + 1] = {
                x = sunMx,
                y = sunMy,
                radius = math.max(2, math.min(scaledRadius, M.mapRadius)),
                kind = "concentricRing",
                inside = sunInside2,
                id = containing.id,
            }
        end
    end
    -- Always-on hub arrow (item 10 change A): show arrow whenever a
    -- checkpoint exists and the ship hasn't arrived (distance >= hub radius*3).
    -- Hides only when within arrival distance or no checkpoint found.
    local checkpointDx, checkpointDy, checkpointDist, checkpointId, checkpointGalaxy =
        M.nearestCheckpointDirection(shipX, shipY)
    local checkpointBeyond = false
    if checkpointDist ~= nil then
        local hubRadius = checkpointGalaxy and world.hubPlanet(checkpointGalaxy)
        local arrivalThreshold = hubRadius and hubRadius.radius * 3 or 48
        checkpointBeyond = checkpointDist >= arrivalThreshold
    end
    return {
        player = { x = 0, y = 0 },
        earth = { x = earthX, y = earthY, inside = earthInside },
        sun = sunX and { x = sunX, y = sunY, inside = sunInside } or nil,
        galaxies = galaxies,
        hubMarkers = hubMarkers,
        rings = rings,
        galaxyName = containing and world.galaxyName(containing) or nil,
        beyond = beyond,
        distanceBeyond = beyond and (distEarth - M.chartRadius) or 0,
        returnDx = returnDx,
        returnDy = returnDy,
        checkpointBeyond = checkpointBeyond,
        checkpointDx = checkpointDx,
        checkpointDy = checkpointDy,
        checkpointDistance = checkpointDist,
        checkpointId = checkpointId,
    }
end

return M
