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
-- galaxy grid one minimap "screen" covers). ~2.5 galaxy cells so a
-- handful of neighboring galaxies fit as distinct dots.
M.viewRadius = world.galaxyCellSize * 2.5

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

-- Deterministic pseudo-random in [0, 1), independent of world.lua's local
-- hash (minimap.lua stays framework-free and dependency-light -- it only
-- needs a stable per-galaxy hash, not the exact same sequence world.lua
-- uses for planet/galaxy placement).
local function spiralHash(n)
    n = (n * 2654435761) % 2147483647
    n = (n * 48271 + 12345) % 2147483647
    return n / 2147483647
end

-- docs/feedback/INBOX.md item 1 part 1: each galaxy must draw its OWN
-- spiral-arm shape on the minimap, derived deterministically from its grid
-- coordinates, and that shape must change when the player crosses into a
-- different galaxy. Arm count (2-5) and overall rotation are both derived
-- from (gx, gy) so two different galaxies overwhelmingly get visibly
-- different spirals, while the same galaxy always regenerates the exact
-- same shape (pure function of gx, gy only).
function M.spiralArmCount(galaxy)
    if not galaxy then return 2 end
    local r = galaxy.radius
    if r < 1000 then return 2
    elseif r < 1400 then return 3
    elseif r < 1800 then return 4
    else return 5
    end
end

function M.spiralRotation(galaxy)
    if not galaxy then return 0 end
    return spiralHash(galaxy.gx * 55529 + galaxy.gy * 40399 + 7002) * math.pi * 2
end

-- How many sample points are plotted along each arm, tightest near the
-- core and reaching the galaxy's outer radius.
M.spiralPointsPerArm = 14
-- How many full turns each arm winds through from core to rim.
M.spiralWindTurns = 1.2

-- Pure function: world-space (x, y) points tracing `galaxy`'s spiral arms,
-- centered on its central star (docs/feedback/INBOX.md item 1 part 3:
-- world.sunPosition(galaxy) -- the home solar system spirals around the
-- SUN, not Earth; every other galaxy's star sits at its own galaxy.x/y, so
-- this is unchanged for them) and bounded by galaxy.radius. Same galaxy
-- (same gx, gy, x, y, radius) always returns the identical point list.
function M.spiralPoints(galaxy)
    if not galaxy then return {} end
    local sun = world.sunPosition(galaxy)
    local armCount = M.spiralArmCount(galaxy)
    local rotation = M.spiralRotation(galaxy)
    local points = {}
    for arm = 0, armCount - 1 do
        local armAngle = rotation + (arm / armCount) * math.pi * 2
        for i = 1, M.spiralPointsPerArm do
            local t = i / M.spiralPointsPerArm
            local radius = galaxy.radius * t
            local angle = armAngle + t * math.pi * 2 * M.spiralWindTurns
            points[#points + 1] = {
                x = sun.x + math.cos(angle) * radius,
                y = sun.y + math.sin(angle) * radius,
                arm = arm,
            }
        end
    end
    return points
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
    local nearest, nearestDist
    for _, galaxy in ipairs(world.nearbyGalaxies(shipX, shipY, M.checkpointSearchCellRadius)) do
        if galaxy.id ~= "milkyway" then
            local dx, dy = galaxy.x - shipX, galaxy.y - shipY
            local dist = math.sqrt(dx * dx + dy * dy)
            if not nearestDist or dist < nearestDist then
                nearest, nearestDist = galaxy, dist
            end
        end
    end
    if not nearest then
        return 0, 0, nil, nil
    end
    if nearestDist < 1e-9 then
        return 0, 0, 0, nearest.id
    end
    return (nearest.x - shipX) / nearestDist, (nearest.y - shipY) / nearestDist, nearestDist, nearest.id
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
    local homeGalaxy = world.galaxy(0, 0)
    local homeSun = world.sunPosition(homeGalaxy)
    local sunX, sunY, sunInside = M.project(homeSun.x, homeSun.y, shipX, shipY)
    local galaxies = {}
    local rings = {}
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
    end
    -- Sun-centered solar-system orbits: readable pixel rings around the
    -- sun marker (true AU scale is sub-pixel on this chart). Earth's own
    -- orbit (radius 7, matching its position roughly between the inner and
    -- outer decorative rings) is included below so Earth visibly reads as
    -- one of the orbiting bodies around the sun rather than the pivot.
    if sunInside or math.sqrt(sunX * sunX + sunY * sunY) < M.mapRadius then
        for _, radius in ipairs({ 4, 7, 11 }) do
            rings[#rings + 1] = {
                x = sunX,
                y = sunY,
                radius = radius,
                kind = "orbit",
            }
        end
    end
    local containing = world.galaxyContaining(shipX, shipY)
    -- docs/feedback/INBOX.md item 1 part 1: the player's current galaxy
    -- draws its own deterministic spiral-arm shape (instead of the generic
    -- circular disk ring above), and this spiral swaps for a different
    -- shape the moment `containing` changes to a different galaxy id.
    local spiral = {}
    if containing then
        for _, point in ipairs(M.spiralPoints(containing)) do
            local mx, my, inside = M.project(point.x, point.y, shipX, shipY)
            spiral[#spiral + 1] = { x = mx, y = my, inside = inside, arm = point.arm }
        end
    end
    -- Off-chart checkpoint direction arrow (item 1): only surfaced when the
    -- nearest checkpoint galaxy's center falls outside viewRadius, i.e. its
    -- dot would not already be plotted on the chart.
    local checkpointDx, checkpointDy, checkpointDist, checkpointId =
        M.nearestCheckpointDirection(shipX, shipY)
    local checkpointBeyond = checkpointDist ~= nil and checkpointDist > M.viewRadius
    return {
        player = { x = 0, y = 0 },
        earth = { x = earthX, y = earthY, inside = earthInside },
        sun = { x = sunX, y = sunY, inside = sunInside },
        galaxies = galaxies,
        rings = rings,
        spiral = spiral,
        spiralGalaxyId = containing and containing.id or nil,
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
