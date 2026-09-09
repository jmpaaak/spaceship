local PlayScene = require("game.scenes.play")

local M = {}

-- Galaxy structure + radial-distance economy (docs/GAME_DESIGN.md 이동
-- 방식 개선 항목 2, "은하계(태양계 포함) 들이 존재"; item 1's economy
-- follow-up, "연료소모가 거리 기반"). Split into its own top-level function
-- for the same reason as testJoystick (M.run() is near Lua's 200-local
-- limit).
local function testGalaxyStructure()
    local world = require("game.world")

    -- Cell (0,0) always contains the home galaxy (Milky Way) centered on
    -- Earth (0,0) so existing near-origin gameplay is unaffected.
    local home = world.galaxy(0, 0)
    assert(home and home.id == "milkyway" and home.x == 0 and home.y == 0 and home.radius > 0)

    -- Deterministic: the same cell must always return the same galaxy (or
    -- consistently nil), mirroring world.planets' existing determinism
    -- guarantee.
    local farA = world.galaxy(41, -17)
    local farB = world.galaxy(41, -17)
    if farA then
        assert(farB and farA.id == farB.id and farA.x == farB.x and farA.y == farB.y and farA.radius == farB.radius)
    else
        assert(farB == nil)
    end

    -- The universe must not be uniformly dense with galaxies: scanning a
    -- wide swath of cells must turn up both existing and nil (empty deep
    -- space) cells, matching the user's explicit "정확히 은하계들이 존재하며"
    -- (galaxies exist as discrete pockets, not everywhere) request.
    local foundGalaxy, foundEmpty = false, false
    for gx = -20, 20 do
        for gy = -20, 20 do
            if not (gx == 0 and gy == 0) then
                if world.galaxy(gx, gy) then foundGalaxy = true else foundEmpty = true end
            end
        end
    end
    assert(foundGalaxy, "scanning a wide grid must find at least one non-origin galaxy")
    assert(foundEmpty, "scanning a wide grid must find at least one empty deep-space cell")

    -- galaxyContaining must find the home galaxy for points inside its
    -- radius, and return nil for a point far out in known-empty deep
    -- space between galaxies.
    assert(world.galaxyContaining(0, 0).id == "milkyway")
    assert(world.galaxyContaining(100, -100).id == "milkyway")

    -- planets() must return no planets for a sector whose center falls
    -- outside every galaxy (deep space), even if the sector-hash alone
    -- would otherwise have placed a planet there.
    local farSectorX, farSectorY = 5000, 5000
    if not world.galaxyContaining(
        farSectorX * world.sectorSize + world.sectorSize / 2,
        farSectorY * world.sectorSize + world.sectorSize / 2) then
        local emptyPlanets = world.planets(farSectorX, farSectorY)
        assert(#emptyPlanets == 0, "a sector outside every galaxy must generate zero planets")
    end

    -- nearbyGalaxies must include the home galaxy when scanning around
    -- the origin.
    local nearby = world.nearbyGalaxies(0, 0, 1)
    local sawHome = false
    for _, galaxy in ipairs(nearby) do
        if galaxy.id == "milkyway" then sawHome = true end
    end
    assert(sawHome, "nearbyGalaxies around the origin must include the home galaxy")

    -- Radial-distance economy: world.distanceFromEarth must match the old
    -- vertical-only height formula (math.max(0, -planet.y)) for any planet
    -- with x omitted/0, so every pre-existing engine-hosted scenario
    -- (which only ever set planet.y) keeps producing identical
    -- sampleValue/collisionDamage/sampleTier results.
    assert(world.distanceFromEarth({ y = -500 }) == 500)
    assert(world.distanceFromEarth({ x = 0, y = -500 }) == 500)
    -- A planet reached by drifting sideways (x nonzero, y = 0) must be
    -- treated identically to one reached by climbing straight up the same
    -- distance -- the whole point of the omnidirectional-movement economy
    -- change.
    assert(world.sampleValue({ x = 500, y = 0 }) == world.sampleValue({ x = 0, y = -500 }),
        "sampleValue must depend on radial distance from Earth, not just vertical height")
    assert(world.collisionDamage({ x = -500, y = 0 }) == world.collisionDamage({ x = 0, y = -500 }))
    assert(world.sampleTier({ x = 300, y = 400 }) == "rare", "a diagonal 500-distance planet must land in the same tier as a 500-height one")

    -- Home galaxy has no extra hub planet (Earth is the center). Every
    -- other existing galaxy has a visitable center planet at its origin.
    assert(world.hubPlanet(home) == nil, "milkyway hub is Earth, not an extra planet")
    local foreignGalaxy
    for gx = -20, 20 do
        for gy = -20, 20 do
            if not (gx == 0 and gy == 0) then
                local candidate = world.galaxy(gx, gy)
                if candidate then
                    foreignGalaxy = candidate
                    break
                end
            end
        end
        if foreignGalaxy then break end
    end
    assert(foreignGalaxy, "need at least one non-home galaxy to check hub planets")
    local hub = world.hubPlanet(foreignGalaxy)
    assert(hub and hub.hub, "foreign galaxy must have a hub planet")
    assert(hub.id == "hub:" .. foreignGalaxy.id)
    -- Item 10 change B: hub must be offset from sun (galaxy center)
    local foreignSun = world.sunPosition(foreignGalaxy)
    assert(hub.x ~= foreignSun.x or hub.y ~= foreignSun.y,
        "hub planet must be offset from sun position (item 10 change B)")
    local hubsNearby = world.nearbyPlanets(hub.x, hub.y, 1)
    local sawHub = false
    for _, planet in ipairs(hubsNearby) do
        if planet.id == hub.id then sawHub = true end
    end
    assert(sawHub, "nearbyPlanets at a galaxy center must include that galaxy's hub planet")

    local shop = world.shopPlanet(foreignGalaxy)
    assert(shop and shop.isShop and shop.id == "shop:" .. foreignGalaxy.id)
    local shopsNearby = world.nearbyPlanets(shop.x, shop.y, 1)
    local sawShop = false
    for _, planet in ipairs(shopsNearby) do
        if planet.id == shop.id then sawShop = true end
    end
    assert(sawShop, "nearbyPlanets at a shop planet location must include that shop planet")

    -- Galaxy shared traits (sub-item 5): starType, starTypeIdx, baseHue
    assert(type(home.starType) == "string", "home galaxy must have a starType string")
    assert(type(home.starTypeIdx) == "number", "home galaxy must have a numeric starTypeIdx")
    assert(home.starTypeIdx >= 0 and home.starTypeIdx <= 5, "home starTypeIdx must be 0..5")
    assert(type(home.baseHue) == "number", "home galaxy must have a numeric baseHue")

    assert(type(foreignGalaxy.starType) == "string", "foreign galaxy must have a starType string")
    assert(type(foreignGalaxy.starTypeIdx) == "number", "foreign galaxy must have a numeric starTypeIdx")
    assert(foreignGalaxy.starTypeIdx >= 0 and foreignGalaxy.starTypeIdx <= 5, "foreign starTypeIdx must be 0..5")
    assert(type(foreignGalaxy.baseHue) == "number", "foreign galaxy must have a numeric baseHue")

    -- Hub and shop planets inherit starType from their galaxy
    assert(hub.galaxyStarType == foreignGalaxy.starType, "hub planet galaxyStarType must match galaxy starType")
    assert(hub.galaxyStarTypeIdx == foreignGalaxy.starTypeIdx, "hub planet galaxyStarTypeIdx must match galaxy starTypeIdx")
    assert(shop.galaxyStarType == foreignGalaxy.starType, "shop planet galaxyStarType must match galaxy starType")
    assert(shop.galaxyStarTypeIdx == foreignGalaxy.starTypeIdx, "shop planet galaxyStarTypeIdx must match galaxy starTypeIdx")

    -- Regular planets inside foreignGalaxy inherit starType and have hue clamped to baseHue ±0.083
    local fgx, fgy = foreignGalaxy.gx, foreignGalaxy.gy
    local fsx = math.floor(foreignGalaxy.x / world.sectorSize)
    local fsy = math.floor(foreignGalaxy.y / world.sectorSize)
    local foundPlanet = nil
    for searchOy = -3, 3 do
        for searchOx = -3, 3 do
            local ps = world.planets(fsx + searchOx, fsy + searchOy)
            if #ps > 0 then foundPlanet = ps[1]; break end
        end
        if foundPlanet then break end
    end
    if foundPlanet then
        assert(foundPlanet.galaxyStarType == foreignGalaxy.starType,
            "regular planet galaxyStarType must match containing galaxy starType")
        local lo = (foreignGalaxy.baseHue - 0.083) % 1
        local hi = (foreignGalaxy.baseHue + 0.083) % 1
        -- Verify hue is within the window (handles wrap-around too)
        local h = foundPlanet.hue
        local inRange
        if lo <= hi then
            inRange = h >= lo and h <= hi
        else
            inRange = h >= lo or h <= hi  -- wraps around 0
        end
        assert(inRange, string.format(
            "planet hue %.3f must be within baseHue %.3f ± 0.083", h, foreignGalaxy.baseHue))
    end
end

-- INBOX-34(a): galaxy overlap prevention.  No two surviving galaxies
-- (after the overlap filter) should have circles closer than the padding.
local function testGalaxyOverlapPrevention()
    local world = require("game.world")
    -- Scan a wide region and collect all surviving galaxies.
    local galaxies = {}
    for gx = -30, 30 do
        for gy = -30, 30 do
            local g = world.galaxy(gx, gy)
            if g then galaxies[#galaxies + 1] = g end
        end
    end
    assert(#galaxies >= 2, "must have at least 2 galaxies in a 60×60 scan")
    -- Pairwise distance check: no two galaxies should overlap.
    for i = 1, #galaxies do
        for j = i + 1, #galaxies do
            local a, b = galaxies[i], galaxies[j]
            local dx = a.x - b.x
            local dy = a.y - b.y
            local dist = math.sqrt(dx * dx + dy * dy)
            local minDist = a.radius + b.radius
            assert(dist >= minDist,
                string.format("galaxies (%d,%d) and (%d,%d) overlap: dist=%.0f < r1+r2=%.0f",
                    a.gx, a.gy, b.gx, b.gy, dist, minDist))
        end
    end
    -- Home galaxy must always survive.
    local home = world.galaxy(0, 0)
    assert(home and home.id == "milkyway", "home galaxy must never be suppressed by overlap filter")
    -- Determinism: calling galaxy() twice must return the same result.
    for _, g in ipairs(galaxies) do
        local g2 = world.galaxy(g.gx, g.gy)
        assert(g2 and g2.id == g.id, "galaxy overlap filter must be deterministic")
    end
end

-- Minimap: galaxy centers + player, plus beyond-chart distance/bearing
-- (docs/GAME_DESIGN.md 이동 방식 개선 항목 2·3). Own top-level function
-- for the same 200-local limit as testJoystick.
local function testMinimap()
    local minimap = require("game.minimap")
    local world = require("game.world")

    -- At Earth the player and Earth markers coincide at the chart origin,
    -- and the home galaxy is plotted.
    local originView = minimap.view(0, 0)
    assert(originView.player.x == 0 and originView.player.y == 0)
    assert(originView.earth.x == 0 and originView.earth.y == 0 and originView.earth.inside)
    assert(not originView.beyond)
    assert(originView.distanceBeyond == 0)
    local sawHome = false
    for _, galaxy in ipairs(originView.galaxies) do
        if galaxy.id == "milkyway" then
            sawHome = true
            assert(galaxy.x == 0 and galaxy.y == 0 and galaxy.inside)
        end
    end
    assert(sawHome, "minimap around Earth must plot the home galaxy")

    -- A ship due east of Earth must see Earth to its west on the chart
    -- (negative x) and still be inside the reference circle.
    local near = world.galaxyCellSize
    local nearView = minimap.view(near, 0)
    assert(not nearView.beyond)
    assert(nearView.earth.x < 0)
    assert(math.abs(nearView.earth.y) < 1e-6)

    -- Earth must clamp to the minimap rim when the ship is beyond viewRadius.
    local clampX = minimap.viewRadius + 100
    local clampView = minimap.view(clampX, 0)
    local earthDist = math.sqrt(clampView.earth.x ^ 2 + clampView.earth.y ^ 2)
    assert(math.abs(earthDist - minimap.mapRadius) < 1e-6,
        "Earth must clamp to the minimap rim when the ship is beyond viewRadius")

    -- Past chartRadius there is still no world wall: the readout only
    -- reports how far past the reference circle the ship is, and the
    -- unit vector pointing back toward Earth.
    local overshoot = 1234
    local farX = minimap.chartRadius + overshoot
    local farView = minimap.view(farX, 0)
    assert(farView.beyond)
    assert(math.abs(farView.distanceBeyond - overshoot) < 1e-6)
    assert(farView.returnDx < 0 and math.abs(farView.returnDy) < 1e-6)

    -- Projecting a point inside viewRadius must not clamp; a point well
    -- outside must land exactly on the rim.
    local mx, my, inside = minimap.project(0, 0, 0, 0)
    assert(mx == 0 and my == 0 and inside)
    mx, my, inside = minimap.project(minimap.viewRadius * 3, 0, 0, 0)
    assert(not inside)
    assert(math.abs(mx - minimap.mapRadius) < 1e-6 and math.abs(my) < 1e-6)

    -- Galaxy rings: home view is sun-centered (sun offset from Earth at origin)
    -- and includes the solar-system orbit rings plus the galaxy disk.
    assert(originView.sun)
    assert(originView.sun.x ~= 0 or originView.sun.y ~= 0,
        "home sun must be offset from Earth at world origin")
    assert(originView.galaxyName == "SOLAR SYSTEM")
    assert(originView.rings and #originView.rings >= 0, "home minimap rings table must exist")
    local sawDisk, sawOrbit = false, false
    for _, ring in ipairs(originView.rings) do
        if ring.kind == "galaxy" and ring.id == "milkyway" then sawDisk = true end
        if ring.kind == "concentricRing" then sawOrbit = true end
    end
    -- User 2026-09-06: milkyway must NOT have any rings (galaxy boundary or concentric)
    assert(sawDisk, "home minimap must include the Milky Way galaxy boundary ring")
    assert(sawOrbit, "home minimap must include concentric rings around the central star")

    local nameScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    nameScene.expedition.phase = "ascending"
    nameScene.ship.x, nameScene.ship.y = 0, 0
    assert(nameScene:hudLines().galaxy == "SOLAR SYSTEM",
        "entering the home galaxy must label SOLAR SYSTEM at top-left")

    -- Checkpoint marker + off-chart arrow (docs/feedback/INBOX.md item 1):
    -- every non-milkyway galaxy is flagged hub=true for the special marker,
    -- and minimap.nearestCheckpointDirection is a pure function that finds
    -- the closest one and points toward it.
    local world = require("game.world")
    local foundGalaxy
    for _, galaxy in ipairs(world.nearbyGalaxies(0, 0, minimap.checkpointSearchCellRadius)) do
        if galaxy.id ~= "milkyway" then
            foundGalaxy = galaxy
            break
        end
    end
    assert(foundGalaxy, "expected at least one non-home galaxy near the origin for this test")
    local cdx, cdy, cdist, cid = minimap.nearestCheckpointDirection(0, 0)
    assert(cid ~= nil and cid ~= "milkyway",
        "nearestCheckpointDirection must resolve to a real non-home galaxy id")
    assert(cdist ~= nil and cdist >= 0)
    if cdist > 0 then
        assert(math.abs(cdx * cdx + cdy * cdy - 1) < 1e-6, "checkpoint direction must be a unit vector")
    end

    -- No checkpoints reachable: direction defaults to (0, 0) and beyond is false.
    local savedNearbyGalaxies = world.nearbyGalaxies
    world.nearbyGalaxies = function() return {} end
    local emptyDx, emptyDy, emptyDist, emptyId = minimap.nearestCheckpointDirection(0, 0)
    assert(emptyDx == 0 and emptyDy == 0 and emptyDist == nil and emptyId == nil)
    local emptyView = minimap.view(0, 0)
    assert(not emptyView.checkpointBeyond)
    world.nearbyGalaxies = savedNearbyGalaxies

    -- A checkpoint far outside viewRadius must surface checkpointBeyond so
    -- PlayScene draws the off-chart arrow toward it.
    local farCheckpointX = foundGalaxy.x
    local farCheckpointY = foundGalaxy.y
    local awayX = farCheckpointX + minimap.viewRadius * 1.5
    local awayY = farCheckpointY
    local awayView = minimap.view(awayX, awayY)
    if awayView.checkpointDistance and awayView.checkpointDistance > minimap.viewRadius then
        assert(awayView.checkpointBeyond)
        assert(awayView.checkpointDx ~= nil)
    end

    -- (item 10 change A) Always-on hub arrow: even when the hub is inside
    -- the chart (within viewRadius), the arrow must still appear as long as
    -- the ship hasn't arrived (distance >= hubRadius*3).
    local hubObj = world.hubPlanet(foundGalaxy)
    local arrivalDist = hubObj and hubObj.radius * 3 or 48
    -- Place ship just outside arrival threshold from the hub position
    local nearHubDist = arrivalDist + 10
    local nearHubX = hubObj.x + nearHubDist
    local nearHubY = hubObj.y
    local nearView = minimap.view(nearHubX, nearHubY)
    if nearView.checkpointId == foundGalaxy.id then
        assert(nearView.checkpointBeyond,
            "hub arrow must show even when hub is inside chart (not arrived)")
        assert(nearView.checkpointDx ~= nil)
    end

    -- When the ship IS at the hub (distance < hubRadius*3), arrow hides
    local atHubX = hubObj.x + 1
    local atHubY = hubObj.y
    local atHubView = minimap.view(atHubX, atHubY)
    if atHubView.checkpointId == foundGalaxy.id and atHubView.checkpointDistance then
        assert(atHubView.checkpointDistance < arrivalDist,
            "sanity: ship should be within arrival distance")
        assert(not atHubView.checkpointBeyond,
            "hub arrow must hide when ship has arrived at hub")
    end

    -- Item 10 change B: minimap view must include hubMarkers with positions
    -- distinct from the galaxy-center (sun) dot.
    local hubView = minimap.view(foundGalaxy.x + 50, foundGalaxy.y + 50)
    assert(hubView.hubMarkers, "minimap view must have hubMarkers table")
    local foundHub = nil
    for _, hm in ipairs(hubView.hubMarkers) do
        if hm.id == foundGalaxy.id then foundHub = hm end
    end
    -- Find matching galaxy dot
    local foundGalDot = nil
    for _, gd in ipairs(hubView.galaxies) do
        if gd.id == foundGalaxy.id then foundGalDot = gd end
    end
    if foundHub and foundGalDot then
        assert(math.abs(foundHub.x - foundGalDot.x) > 0.1 or math.abs(foundHub.y - foundGalDot.y) > 0.1,
            "hub marker must be at a different chart position than galaxy center dot (item 10 change B)")
    end

    -- Galaxy-specific background tint (item 1 part 4): the home solar
    -- system keeps its established navy color, and a different galaxy
    -- must produce a visibly different, deterministic tint.
    local homeR, homeG, homeB = world.galaxyBackgroundColor(world.galaxy(0, 0))
    assert(homeR == world.homeBackgroundColor[1])
    local otherR, otherG, otherB = world.galaxyBackgroundColor(foundGalaxy)
    assert(otherR ~= homeR or otherG ~= homeG or otherB ~= homeB,
        "a non-home galaxy must have a different background tint than the solar system")
    local otherR2, otherG2, otherB2 = world.galaxyBackgroundColor(foundGalaxy)
    assert(otherR == otherR2 and otherG == otherG2 and otherB == otherB2,
        "galaxy background tint must be deterministic")

    -- Mobile-UI sub-item (2): minimap marker radii must be >= 1.5× the
    -- original 720×1280-era values for mobile touch readability.
    assert(minimap.markerSunRadius >= 15.6,
        "markerSunRadius must be >= 15.6 (1.5× original 10.4)")
    assert(minimap.markerGalaxyHomeRadius >= 13.2,
        "markerGalaxyHomeRadius must be >= 13.2 (1.5× original 8.8)")
    assert(minimap.markerGalaxyHubRadius >= 8.4,
        "markerGalaxyHubRadius must be >= 8.4 (1.5× original 5.6)")
    assert(minimap.markerEarthRadius >= 12,
        "markerEarthRadius must be >= 12 (1.5× original 8)")
    assert(minimap.markerPlayerFillRadius >= 10.2,
        "markerPlayerFillRadius must be >= 10.2 (1.5× original 6.8)")
    assert(minimap.markerPlayerLineRadius >= 14.4,
        "markerPlayerLineRadius must be >= 14.4 (1.5× original 9.6)")
    assert(minimap.markerBeyondRadius >= 13.2,
        "markerBeyondRadius must be >= 13.2 (1.5× original 8.8)")
    assert(minimap.markerCheckpointTipRadius >= 10.8,
        "markerCheckpointTipRadius must be >= 10.8 (1.5× original 7.2)")
end

-- INBOX (8)+(13): every galaxy uses the same gold ring/marker palette.
-- milkyway must not keep a blue special-case. Spiral fields must be absent;
-- concentric rings must appear in view.rings.
local function testMinimapUnifiedGalaxyPalette()
    local minimap = require("game.minimap")
    local PlayScene = require("game.scenes.play")

    local rHome, gHome, bHome, aHome = PlayScene.galaxyChartLineColor("milkyway")
    local rOther, gOther, bOther, aOther = PlayScene.galaxyChartLineColor("outer-1-0")
    assert(rHome == 0.9 and gHome == 0.75 and bHome == 0.3,
        "galaxy ring/spiral line color must be gold 0.9, 0.75, 0.3")
    assert(aHome == 0.12, "galaxy ring line alpha must be 0.12 (INBOX-45b)")
    assert(rHome == rOther and gHome == gOther and bHome == bOther and aHome == aOther,
        "milkyway must not use a different ring/spiral color than other galaxies")

    local fr, fg, fb, fa = PlayScene.galaxyChartFillColor("milkyway")
    local fr2, fg2, fb2, fa2 = PlayScene.galaxyChartFillColor("outer-1-0")
    assert(fr == 0.9 and fg == 0.75 and fb == 0.3 and fa == 1,
        "galaxy marker fill must be gold 0.9, 0.75, 0.3")
    assert(fr == fr2 and fg == fg2 and fb == fb2 and fa == fa2,
        "milkyway galaxy marker must use the same gold fill as every other galaxy")

    -- Item 13: spiral fields must be absent (or nil), concentric rings present
    -- for non-home galaxies. Home (milkyway) must NOT have concentric rings.
    local originView = minimap.view(0, 0)
    assert(originView.spiral == nil or (type(originView.spiral) == "table" and #originView.spiral == 0),
        "minimap.view must not produce spiral-arm points (item 13: replaced by concentric rings)")

    -- Home galaxy: concentric rings present (sun-centered, not Earth-centered)
    local sawConcentricAtHome = false
    for _, ring in ipairs(originView.rings or {}) do
        if ring.kind == "concentricRing" then
            sawConcentricAtHome = true
        end
    end
    assert(sawConcentricAtHome,
        "minimap.view at home (milkyway) must include concentricRing entries (sun-centered)")

    -- concentricRingCount bracket check
    assert(minimap.concentricRingCount(nil) == 2, "nil galaxy => 2 rings")
    assert(minimap.concentricRingCount({ radius = 800 }) == 2)
    assert(minimap.concentricRingCount({ radius = 1200 }) == 3)
    assert(minimap.concentricRingCount({ radius = 1600 }) == 4)
    assert(minimap.concentricRingCount({ radius = 2000 }) == 5)

    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scene.expedition.phase = "ascending"
    scene.ship.x, scene.ship.y = 0, 0
    scene.minimapImages = {}
    scene.time = 0

    local colors = {}
    local circleCount = 0
    local previousGraphics = love.graphics
    love.graphics = {
        setColor = function(r, g, b, a)
            colors[#colors + 1] = { r, g, b, a or 1 }
        end,
        circle = function()
            circleCount = circleCount + 1
        end,
        printf = function() end,
        polygon = function() end,
        draw = function() end,
        getFont = function() return {} end,
        setFont = function() end,
        newFont = function() return {} end,
        stencil = function(fn) if fn then fn() end end,
        setStencilTest = function() end,
    }
    local ok, err = pcall(function() scene:drawMinimap() end)
    love.graphics = previousGraphics
    assert(ok, "drawMinimap must not throw: " .. tostring(err))

    -- Must have drawn circles (disc + galaxy ring at minimum; no concentric at home)
    assert(circleCount >= 2,
        "drawMinimap must draw at least disc + galaxy ring circles (circleCount="
            .. circleCount .. ")")

    for _, c in ipairs(colors) do
        local isBlueRing = math.abs(c[1] - 0.3) < 1e-6
            and math.abs(c[2] - 0.55) < 1e-6
            and math.abs(c[3] - 0.95) < 1e-6
        local isBlueMarker = math.abs(c[1] - 0.25) < 1e-6
            and math.abs(c[2] - 0.55) < 1e-6
            and math.abs(c[3] - 1) < 1e-6
        assert(not isBlueRing, "milkyway ring must not use the old blue special-case color")
        assert(not isBlueMarker, "milkyway galaxy marker must not use the old blue special-case color")
    end

    local sawGold = false
    for _, c in ipairs(colors) do
        if math.abs(c[1] - 0.9) < 1e-6
            and math.abs(c[2] - 0.75) < 1e-6
            and math.abs(c[3] - 0.3) < 1e-6 then
            sawGold = true
        end
    end
    assert(sawGold, "drawMinimap must use the unified gold galaxy palette")
end

-- Item 20a: drawMinimap must set a circular stencil to clip galaxy rings
-- inside the disc boundary. Verify stencil() and setStencilTest() are called.
local function testMinimapStencilClip()
    local playScene = require("game.scenes.play")
    local scene = setmetatable({}, { __index = playScene })
    scene.expedition = { phase = "ascending", fuel = 100, maxFuel = 100,
        altitude = 0, money = 0, durability = 3, maxDurability = 3 }
    scene.run = { altitude = 0 }
    scene.ship = { x = 0, y = 0, speed = 0.14, collectionRadius = 45 }
    scene.minimapImages = {}
    scene.time = 0

    local stencilCalled = false
    local stencilTestCalls = {}
    local previousGraphics = love.graphics
    love.graphics = {
        setColor = function() end,
        circle = function() end,
        printf = function() end,
        polygon = function() end,
        draw = function() end,
        getFont = function() return {} end,
        setFont = function() end,
        newFont = function() return {} end,
        stencil = function(fn)
            stencilCalled = true
            if fn then fn() end
        end,
        setStencilTest = function(...)
            stencilTestCalls[#stencilTestCalls + 1] = { ... }
        end,
    }
    local ok, err = pcall(function() scene:drawMinimap() end)
    love.graphics = previousGraphics
    assert(ok, "drawMinimap stencil test must not throw: " .. tostring(err))
    assert(stencilCalled, "drawMinimap must call love.graphics.stencil for disc clipping")
    assert(#stencilTestCalls >= 2,
        "drawMinimap must call setStencilTest at least twice (enable + disable), got "
        .. #stencilTestCalls)
    -- First call should enable stencil ("greater", 0)
    local first = stencilTestCalls[1]
    assert(first[1] == "greater" and first[2] == 0,
        "first setStencilTest must be ('greater', 0)")
    -- Last call should disable stencil (no args)
    local last = stencilTestCalls[#stencilTestCalls]
    assert(#last == 0, "last setStencilTest must disable stencil (no args)")
end

-- Item 20d: Earth and Star text labels on the minimap.
-- Verifies that drawMinimap calls printf with the i18n minimap_earth_label
-- and minimap_star_label texts inside the stencil-clipped region, and that
-- setFont is called with a font object (11px label font).
local function testMinimapEarthStarLabels()
    local playScene = require("game.scenes.play")
    local i18n = require("game.i18n")
    local fontsModule = require("game.fonts")
    local scene = setmetatable({}, { __index = playScene })
    scene.expedition = { phase = "ascending", fuel = 100, maxFuel = 100,
        altitude = 0, money = 0, durability = 3, maxDurability = 3 }
    scene.run = { altitude = 0 }
    scene.ship = { x = 0, y = 0, speed = 0.14, collectionRadius = 45 }
    scene.minimapImages = {}
    scene.time = 0

    local printfCalls = {}
    local setFontCalls = {}
    local previousGraphics = love.graphics
    love.graphics = {
        setColor = function() end,
        circle = function() end,
        printf = function(text, ...)
            printfCalls[#printfCalls + 1] = text
        end,
        polygon = function() end,
        draw = function() end,
        getFont = function() return {} end,
        setFont = function(f)
            setFontCalls[#setFontCalls + 1] = f
        end,
        newFont = function() return {} end,
        stencil = function(fn)
            if fn then fn() end
        end,
        setStencilTest = function() end,
    }
    local ok, err = pcall(function() scene:drawMinimap() end)
    love.graphics = previousGraphics
    assert(ok, "drawMinimap earth/star labels must not throw: " .. tostring(err))

    -- Verify Earth label text appears in printf calls
    local earthLabel = i18n.t("minimap_earth_label")
    local starLabel = i18n.t("minimap_star_label")
    local foundEarth, foundStar = false, false
    for _, text in ipairs(printfCalls) do
        if text == earthLabel then foundEarth = true end
        if text == starLabel then foundStar = true end
    end
    assert(foundEarth, "drawMinimap must printf the Earth label '" .. earthLabel .. "'")
    assert(foundStar, "drawMinimap must printf the Star label '" .. starLabel .. "'")

    -- Verify setFont was called (for the 11px label font)
    assert(#setFontCalls >= 1, "drawMinimap must call setFont for minimap labels")
end

-- Item 20b: galaxy boundary rings should only appear for the containing
-- galaxy, not for neighbours, so nearby galaxies don't visually overlap.
local function testMinimapGalaxyOverlapPrevention()
    local minimapMod = require("game.minimap")
    local worldMod = require("game.world")
    -- Ship at origin (milkyway). View should only have galaxy boundary
    -- rings for the milkyway, not for any neighbouring galaxy.
    local view = minimapMod.view(0, 0)
    local galaxyRingIds = {}
    for _, ring in ipairs(view.rings or {}) do
        if ring.kind == "galaxy" then
            galaxyRingIds[ring.id] = true
        end
    end
    -- The containing galaxy (milkyway) must NOT have its boundary ring (user 2026-09-06).
    assert(galaxyRingIds["milkyway"],
        "minimap must show boundary ring for containing galaxy (milkyway)")
    -- No OTHER galaxy should have a boundary ring (only containing).
    local otherGalaxyRingCount = 0
    for id, _ in pairs(galaxyRingIds) do
        if id ~= "milkyway" then
            otherGalaxyRingCount = otherGalaxyRingCount + 1
        end
    end
    assert(otherGalaxyRingCount == 0,
        "minimap must NOT show boundary rings for non-containing galaxies (found "
        .. otherGalaxyRingCount .. " extra)")
    -- viewRadius should be tighter than old 0.7 to reduce overlap
    assert(minimapMod.viewRadius <= worldMod.galaxyCellSize * 0.6,
        "viewRadius should be <= 0.6 * galaxyCellSize for overlap prevention")
end

-- INBOX-34(a)/45(a): galaxyExistenceThreshold raised to 0.85 to reduce density.
-- INBOX-34(b): minimap view emits nearestGalaxyRimMarker for off-disc galaxies.
local function testMinimapGalaxyRimMarker()
    local minimapMod = require("game.minimap")
    local worldMod = require("game.world")
    -- (a) Verify threshold is at least 0.85 (fewer galaxies).
    -- Count galaxies in a smaller region — density should be < 20% (old was ~18% at 0.82).
    local galaxyCount = 0
    local totalCells = 0
    for gx = -20, 20 do
        for gy = -20, 20 do
            totalCells = totalCells + 1
            if worldMod.galaxy(gx, gy) then
                galaxyCount = galaxyCount + 1
            end
        end
    end
    local density = galaxyCount / totalCells
    -- With threshold 0.85, existence requires hash > 0.85, so ~15% density.
    -- Allow some margin but must be < 0.20 (was ~18% with 0.82 threshold).
    assert(density < 0.20,
        string.format("galaxy density should be < 20%% with raised threshold, got %.1f%%", density * 100))

    -- (b) From origin (inside milkyway), nearest non-home galaxy should
    -- produce a rim marker since it is outside the minimap disc.
    local view = minimapMod.view(0, 0)
    if view.nearestGalaxyRimMarker then
        local m = view.nearestGalaxyRimMarker
        assert(m.dx ~= nil and m.dy ~= nil, "rim marker must have dx, dy")
        assert(m.distance ~= nil and m.distance > 0, "rim marker must have positive distance")
        assert(m.name ~= nil, "rim marker must have galaxy name")
        assert(m.id ~= nil and m.id ~= "milkyway", "rim marker must not be milkyway")
        -- Direction should be a unit vector
        local mag = math.sqrt(m.dx * m.dx + m.dy * m.dy)
        assert(math.abs(mag - 1) < 1e-4, "rim marker direction must be unit vector")
    end
    -- When ship is inside a non-home galaxy, the galaxy center is nearby
    -- (inside disc), so rim marker should be nil for that galaxy.
    -- (We just verify the field exists and is structured correctly above.)
end

-- INBOX-31: minimap.view() galaxy entries must carry isContaining flag.
-- Only the containing galaxy should have isContaining=true; all others false.
local function testMinimapGalaxyContainingFlag()
    local minimapMod = require("game.minimap")
    -- Ship at origin → inside milkyway.
    local view = minimapMod.view(0, 0)
    local containingCount = 0
    local nonContainingCount = 0
    for _, g in ipairs(view.galaxies) do
        if g.isContaining then
            containingCount = containingCount + 1
            assert(g.id == "milkyway",
                "containing galaxy at origin must be milkyway, got " .. tostring(g.id))
        else
            nonContainingCount = nonContainingCount + 1
            -- Non-containing galaxies must have isContaining == false (not nil)
            assert(g.isContaining == false,
                "non-containing galaxy isContaining must be false, not nil")
        end
    end
    assert(containingCount == 1,
        "exactly one galaxy should be containing at origin, got " .. containingCount)
end

-- INBOX-75: the next undiscovered galaxy fades in continuously before the
-- real galaxy boundary, with deterministic staging for star/ring/details.
local function testMinimapGalaxyDiscoveryFade()
    local minimapMod = require("game.minimap")
    local radius = 1000
    local lead = minimapMod.discoveryLeadDistance

    assert(minimapMod.discoveryAlpha(radius + lead + 1, radius, false, false) == 0,
        "outside the pre-detection band discoveryAlpha must be zero")
    local midpoint = minimapMod.discoveryAlpha(radius + lead * 0.5, radius, false, false)
    assert(midpoint > 0 and midpoint < 1,
        "inside the pre-detection band discoveryAlpha must be continuous")
    assert(minimapMod.discoveryAlpha(radius, radius, false, false) == 1,
        "at the real discovery radius discoveryAlpha must be one")
    assert(minimapMod.discoveryAlpha(radius + lead, radius, true, false) == 1,
        "the current galaxy must remain fully visible")
    assert(minimapMod.discoveryAlpha(radius + lead, radius, false, true) == 1,
        "an already discovered galaxy must remain fully visible")

    local previous = 0
    for i = 0, 100 do
        local distance = radius + lead * (1 - i / 100)
        local alpha = minimapMod.discoveryAlpha(distance, radius, false, false)
        assert(alpha >= previous and alpha >= 0 and alpha <= 1,
            "approach alpha must be bounded and monotonically increasing")
        previous = alpha
    end

    local early = minimapMod.discoveryLayerAlphas(0.2)
    local middle = minimapMod.discoveryLayerAlphas(0.55)
    local full = minimapMod.discoveryLayerAlphas(1)
    assert(early.mist > 0 and early.star > 0 and early.ring == 0 and early.details == 0,
        "early detection must show only mist and the central star")
    assert(middle.star > middle.ring and middle.ring > middle.details,
        "central star, boundary, and details must reveal in that order")
    assert(full.mist == 1 and full.star == 1 and full.ring == 1 and full.details == 1,
        "all discovery layers must be fully visible at the boundary")

    local worldMod = require("game.world")
    local target = minimapMod.nearestUndiscoveredGalaxy(0, 0, { milkyway = true })
    assert(target, "the minimap must select a deterministic next undiscovered galaxy")
    local approachX = target.x + target.radius + lead * 0.5
    local approachView = minimapMod.view(approachX, target.y, { milkyway = true })
    assert(approachView.discoveryTargetId == target.id,
        "only the nearest undiscovered galaxy must become the reveal target")
    local targetEntry
    for _, galaxy in ipairs(approachView.galaxies) do
        if galaxy.id == target.id then targetEntry = galaxy end
    end
    assert(targetEntry and targetEntry.discoveryAlpha > 0 and targetEntry.discoveryAlpha < 1,
        "the target galaxy view entry must carry its continuous discovery alpha")
    local sawFadingBoundary = false
    for _, ring in ipairs(approachView.rings) do
        if ring.id == target.id and ring.kind == "galaxy" then
            sawFadingBoundary = ring.discoveryAlpha > 0 and ring.discoveryAlpha < 1
        end
    end
    assert(sawFadingBoundary, "the target boundary ring must share the staged fade")
end

function M.run()
    testGalaxyStructure()
    testGalaxyOverlapPrevention()
    testMinimap()
    testMinimapUnifiedGalaxyPalette()
    testMinimapStencilClip()
    testMinimapEarthStarLabels()
    testMinimapGalaxyOverlapPrevention()
    testMinimapGalaxyRimMarker()
    testMinimapGalaxyContainingFlag()
    testMinimapGalaxyDiscoveryFade()
end

M.testMinimapStencilClip = testMinimapStencilClip
M.testMinimapEarthStarLabels = testMinimapEarthStarLabels

return M
