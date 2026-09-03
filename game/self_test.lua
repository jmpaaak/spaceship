require("game.i18n").setLocale("en")
local viewport = require("game.viewport")
local shipModule = require("game.ship")
local world = require("game.world")
local expedition = require("game.expedition")
local bestAltitudeStore = require("game.best_altitude_store")
local collectionStore = require("game.collection_store")
local PlayScene = require("game.scenes.play")
local json = require("game.json")
local gear = require("game.gear")
local enginePartsModule = require("game.engine_parts")
local M = {}

-- Omnidirectional joystick movement (docs/GAME_DESIGN.md 이동 방식 개선 항목
-- 1, "조이스틱을 통해 전방향으로 이동 가능함"), split into its own top-level
-- function (instead of inline in M.run()) because M.run() had already
-- accumulated close to Lua's 200-local-variables-per-function limit; a
-- few more locals inline pushed it over ("function at line 10 has more
-- than 200 local variables") even inside a scoping do...end block, since
-- Lua counts peak simultaneously-live locals within one function body.
local function testJoystick()
    local joystick = require("game.joystick")
    local jdx, jdy, jmag = joystick.vector(0, 0, 0, 2)
    assert(jdx == 0 and jdy == 0 and jmag == 0, "drag inside the deadzone must report zero magnitude")
    jdx, jdy, jmag = joystick.vector(0, 0, 0, joystick.maxRadius)
    assert(math.abs(jdx - 0) < 1e-9 and math.abs(jdy - 1) < 1e-9 and math.abs(jmag - 1) < 1e-9,
        "a full-radius straight-down drag must report unit vector (0,1) at magnitude 1")
    jdx, jdy, jmag = joystick.vector(0, 0, joystick.maxRadius * 2, 0)
    assert(math.abs(jdx - 1) < 1e-9 and math.abs(jdy - 0) < 1e-9 and jmag == 1,
        "a drag beyond maxRadius must clamp magnitude at 1, not exceed it")
    local halfRadius = (joystick.deadzone + joystick.maxRadius) / 2
    jdx, jdy, jmag = joystick.vector(0, 0, 0, halfRadius)
    assert(jmag > 0 and jmag < 1, "a drag between deadzone and maxRadius must interpolate strictly between 0 and 1")

    -- A dragged touch (originX/originY set away from the current x/y) must
    -- move the ship diagonally: horizontal speed on ship.x same as before,
    -- plus a new vertical maneuvering offset (self.verticalOffset) applied
    -- on top of the automatic altitude line, scaled by the same
    -- expedition.steeringSpeed(run) used for left/right so STEERING upgrades
    -- also improve joystick responsiveness.
    local joystickMoveScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    joystickMoveScene.expedition.phase = "ascending"
    assert(joystickMoveScene.verticalOffset == 0)
    -- Drag straight down-right from origin (90,10) to (90+maxRadius,10+maxRadius)
    -- normalizes to roughly (0.707, 0.707) at full magnitude.
    joystickMoveScene.touches["stick"] = {
        originX = 90, originY = 10,
        x = 90 + joystick.maxRadius, y = 10 + joystick.maxRadius,
    }
    local shipXBefore, verticalBefore = joystickMoveScene.ship.x, joystickMoveScene.verticalOffset
    joystickMoveScene:update(1)
    assert(joystickMoveScene.ship.x > shipXBefore, "joystick drag with a positive x component must move ship.x right")
    assert(joystickMoveScene.verticalOffset > verticalBefore,
        "joystick drag with a positive y component must increase verticalOffset")
    assert(math.abs(joystickMoveScene.ship.x - shipXBefore) - math.abs(joystickMoveScene.verticalOffset - verticalBefore)
        < 1e-6, "a 45-degree drag must move x and verticalOffset by equal magnitudes")

    -- verticalOffset must clamp so joystick-driven vertical maneuvering
    -- can't push the ship arbitrarily far from the automatic altitude line.
    joystickMoveScene.verticalOffset = PlayScene.verticalOffsetLimit - 1
    joystickMoveScene:update(1)
    assert(joystickMoveScene.verticalOffset == PlayScene.verticalOffsetLimit,
        "verticalOffset must clamp at PlayScene.verticalOffsetLimit")

    -- A plain tap-and-hold touch (no drag away from its origin) must keep
    -- using the legacy binary left/right steering exactly as before, so
    -- existing touch UX (returnControls/ascendControls bands) is unchanged.
    local expedition = require("game.expedition")
    local tapHoldScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    tapHoldScene.expedition.phase = "ascending"
    tapHoldScene.touches["hold"] = { x = 20, y = 160, originX = 20, originY = 160 }
    local tapShipXBefore = tapHoldScene.ship.x
    tapHoldScene:update(1)
    assert(tapHoldScene.ship.x == tapShipXBefore - expedition.steeringSpeed(tapHoldScene.expedition),
        "an undragged tap-and-hold touch must still steer via the legacy binary left/right path")
    assert(tapHoldScene.verticalOffset == 0, "an undragged touch must not move verticalOffset")

    -- Desktop `love .` routes the mouse through the same touch API with
    -- id "mouse". Press then drag past the deadzone must produce a
    -- joystick knob and actually move the ship, otherwise a desktop play
    -- session looks identical to the old left/right-only controls.
    local mouseScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    mouseScene.expedition.phase = "ascending"
    mouseScene:touchpressed("mouse", 90, 160)
    assert(mouseScene:joystickKnob() == nil, "an undragged mouse press must not show a stick knob")
    mouseScene:touchmoved("mouse", 90 + joystick.maxRadius, 160)
    local mx, my, knobX = mouseScene:joystickKnob()
    assert(mx == 90 and my == 160 and knobX > 90, "a dragged mouse must report a stick knob")
    local mouseXBefore = mouseScene.ship.x
    mouseScene:update(1)
    assert(mouseScene.ship.x > mouseXBefore, "a rightward mouse-drag must move the ship")
    mouseScene:touchreleased("mouse")
    assert(mouseScene:joystickKnob() == nil, "releasing the mouse must hide the stick knob")

    assert(joystick.visualRadius < joystick.maxRadius,
        "drawn stick disc must be smaller than the input maxRadius")
    assert(joystick.visualFillAlpha < 0.2 and joystick.visualLineAlpha < 0.4,
        "drawn stick must be translucent, not a solid overlay")
    assert(math.abs(PlayScene.headingFromStick(1, 0)) < 1e-9, "stick right must be heading 0")
    assert(math.abs(PlayScene.headingFromStick(0, -1) + math.pi / 2) < 1e-9,
        "stick up must be heading -pi/2")
    assert(math.abs(PlayScene.shortestAngleDelta(0, 0.1) - 0.1) < 1e-9)

    -- Rightward stick must point the nose fully right (heading 0), not a
    -- capped lean off nose-up, and emit an RCS puff on that same side.
    local tiltScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    tiltScene.expedition.phase = "ascending"
    tiltScene.touches["stick"] = {
        originX = 90, originY = 160,
        x = 90 + joystick.maxRadius, y = 160,
    }
    local restAngle = tiltScene.ship.angle
    tiltScene:update(1)
    assert(math.abs(tiltScene.ship.angle) < 0.05,
        "a full-right stick must be allowed to reach heading 0, not a capped bank")
    assert(math.abs(tiltScene.ship.angle - restAngle) > 0.5,
        "unclamped heading must be able to travel more than the old 0.5 rad lean")
    assert(#tiltScene.particles > 0, "tilting left/right must spawn a side RCS puff")
    assert(tiltScene.particles[1].x < tiltScene.ship.x,
        "a right tilt's RCS puff must emit from the ship's left side")
    local heldAngle = tiltScene.ship.angle
    tiltScene.touches["stick"] = nil
    tiltScene:update(1)
    assert(tiltScene.ship.angle == heldAngle,
        "releasing the stick must keep the current heading, not spring back to nose-up")

    -- Main-engine climb must follow the current nose, not always -Y.
    -- A right stick while already nose-right applies thrust on +x.
    local headingThrustScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    headingThrustScene.expedition.phase = "ascending"
    headingThrustScene.ship.angle = 0
    headingThrustScene.touches["stick"] = {
        originX = 90, originY = 160,
        x = 90 + joystick.maxRadius, y = 160,
    }
    local hx, hy = headingThrustScene.ship.x, headingThrustScene.ship.y
    local headingFuelBefore = headingThrustScene.expedition.fuel
    headingThrustScene:update(1)
    assert(headingThrustScene.ship.x > hx, "nose-right climb must move +x")
    assert(math.abs(headingThrustScene.ship.y - hy) < 1e-6,
        "nose-right climb must not keep forcing the ship straight up")
    assert(headingThrustScene.expedition.fuel == headingFuelBefore,
        "thrusting must not burn fuel; fuel is no longer a flight constraint")
    local coastX = headingThrustScene.ship.x
    local coastFuel = headingThrustScene.expedition.fuel
    headingThrustScene.touches["stick"] = nil
    headingThrustScene:update(1)
    assert(headingThrustScene.expedition.fuel == coastFuel,
        "coasting without stick input must not burn fuel")
    assert(headingThrustScene.ship.x ~= coastX,
        "coasting must keep moving on stored velocity")

    local puffScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    puffScene.expedition.phase = "ascending"
    puffScene.touches["stick"] = {
        originX = 90, originY = 160,
        x = 90, y = 160 + joystick.maxRadius,
    }
    puffScene:update(0.05)
    assert(#puffScene.particles > 0, "vertical stick must spawn an RCS puff")
    local verticalPuff
    for _, p in ipairs(puffScene.particles) do
        if math.abs(p.y - puffScene.ship.y) >= 5 then verticalPuff = p end
    end
    assert(verticalPuff, "downward stick must emit a vertical puff")
    assert(verticalPuff.y < puffScene.ship.y,
        "a down stick's RCS puff must emit from above the ship (opposite jet)")
    assert(math.abs(verticalPuff.maxTimer - PlayScene.rcsPuffDuration) < 1e-9)
    assert(PlayScene.stickTurnFollow < 5,
        "hull turn follow must be slow, not the old snap rate of 14")
end

-- Fuel is no longer a flight constraint: thrusting, coasting, and
-- expedition.update must leave fuel untouched and must not auto-return.
local function testManeuverFuel()
    local expedition = require("game.expedition")
    local run = expedition.new()
    assert(expedition.maneuverFuel(run, 55) == 0,
        "maneuverFuel must be 0 once fuel is unconstrained")
    assert(expedition.maneuverFuel(run, 0) == 0)
    assert(expedition.burnManeuverFuel(run, 55) == 0)
    assert(run.fuel == run.maxFuel)

    expedition.launch(run)
    local fuelBefore = run.fuel
    expedition.update(run, 5)
    assert(run.fuel == fuelBefore, "ascent must not burn fuel")
    assert(run.phase == "ascending", "ascent must not auto-return when fuel is unconstrained")
    assert(run.altitude > 0)

    expedition.beginReturn(run)
    assert(run.phase == "returning")
    assert(run.returnDistance == run.maxAltitude)
    assert(run.slotOpportunities >= 1)

    local idleScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    idleScene.expedition.phase = "ascending"
    local idleFuelBefore = idleScene.expedition.fuel
    idleScene:update(1)
    assert(idleScene.expedition.fuel == idleFuelBefore,
        "coasting without stick/keys must not burn fuel")
    assert(idleScene.expedition.phase == "ascending")

    local steerScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    steerScene.expedition.phase = "ascending"
    steerScene.touches["hold"] = { x = 20, y = 160, originX = 20, originY = 160 }
    local steerFuelBefore = steerScene.expedition.fuel
    steerScene:update(1)
    assert(steerScene.expedition.fuel == steerFuelBefore,
        "steering must not burn fuel")
    assert(steerScene.expedition.phase == "ascending")
end

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
    assert(hub and hub.hub and hub.x == foreignGalaxy.x and hub.y == foreignGalaxy.y)
    assert(hub.id == "hub:" .. foreignGalaxy.id)
    local hubsNearby = world.nearbyPlanets(foreignGalaxy.x, foreignGalaxy.y, 1)
    local sawHub = false
    for _, planet in ipairs(hubsNearby) do
        if planet.id == hub.id then sawHub = true end
    end
    assert(sawHub, "nearbyPlanets at a galaxy center must include that galaxy's hub planet")
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

    -- Past chartRadius there is still no world wall: the readout only
    -- reports how far past the reference circle the ship is, and the
    -- unit vector pointing back toward Earth.
    local overshoot = 1234
    local farX = minimap.chartRadius + overshoot
    local farView = minimap.view(farX, 0)
    assert(farView.beyond)
    assert(math.abs(farView.distanceBeyond - overshoot) < 1e-6)
    assert(farView.returnDx < 0 and math.abs(farView.returnDy) < 1e-6)
    -- Earth is farther than viewRadius, so its marker clamps to the rim.
    local earthDist = math.sqrt(farView.earth.x ^ 2 + farView.earth.y ^ 2)
    assert(math.abs(earthDist - minimap.mapRadius) < 1e-6,
        "Earth must clamp to the minimap rim when the ship is beyond viewRadius")

    -- Projecting a point inside viewRadius must not clamp; a point well
    -- outside must land exactly on the rim.
    local mx, my, inside = minimap.project(0, 0, 0, 0)
    assert(mx == 0 and my == 0 and inside)
    mx, my, inside = minimap.project(minimap.viewRadius * 3, 0, 0, 0)
    assert(not inside)
    assert(math.abs(mx - minimap.mapRadius) < 1e-6 and math.abs(my) < 1e-6)

    -- Galaxy rings: home view is sun-centered (Earth/sun at origin) and
    -- includes the solar-system orbit rings plus the galaxy disk.
    assert(originView.sun and originView.sun.x == 0 and originView.sun.y == 0)
    assert(originView.galaxyName == "SOLAR SYSTEM")
    assert(originView.rings and #originView.rings >= 2, "home minimap must draw galaxy/solar rings")
    local sawDisk, sawOrbit = false, false
    for _, ring in ipairs(originView.rings) do
        assert(ring.radius > 0)
        if ring.kind == "galaxy" and ring.id == "milkyway" then sawDisk = true end
        if ring.kind == "orbit" then sawOrbit = true end
    end
    assert(sawDisk, "home minimap must include the Milky Way / solar disk ring")
    assert(sawOrbit, "home minimap must include sun-centered solar-system orbit rings")

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
    local awayX = farCheckpointX + minimap.viewRadius * 5
    local awayY = farCheckpointY
    local awayView = minimap.view(awayX, awayY)
    if awayView.checkpointDistance and awayView.checkpointDistance > minimap.viewRadius then
        assert(awayView.checkpointBeyond)
        assert(awayView.checkpointDx ~= nil)
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
end

-- Drifting asteroids / junk. Hitting one uses the same destroy/reset path
-- as a lethal planet collision.
-- UI/HUD cleanup item 1 (docs/feedback/INBOX.md, 2026-09-02): the existing
-- 18-star-per-sector field reads as sparse, meteor-like streaks. Keep that
-- foreground layer exactly as-is (the user likes the meteor feel) and add a
-- second, much denser background star field that is deterministic per
-- sector just like the foreground one, but distinct (different point
-- count/salts/brightness range) so `play.lua` can draw it with reduced
-- parallax as a dense, near-static Milky Way backdrop behind the meteors.
local function testBackgroundStars()
    local world = require("game.world")
    local a = world.backgroundStars(3, -2)
    local b = world.backgroundStars(3, -2)
    assert(#a == #b, "background star field must be deterministic per sector")
    for i = 1, #a do
        assert(a[i].x == b[i].x and a[i].y == b[i].y and a[i].bright == b[i].bright)
    end
    assert(#a > #world.stars(3, -2) * 2,
        "background star layer must be noticeably denser than the foreground meteor layer")
    for _, star in ipairs(a) do
        assert(star.bright >= 0 and star.bright <= 1)
    end

    -- Different sectors and different salts from the foreground layer must
    -- produce a distinct point set (not just a re-scaled copy of M.stars).
    local foreground = world.stars(3, -2)
    local distinct = false
    for i = 1, math.min(#a, #foreground) do
        if a[i].x ~= foreground[i].x or a[i].y ~= foreground[i].y then distinct = true end
    end
    assert(distinct, "background stars must be an independently seeded point set")
end

-- docs/feedback/INBOX.md UI/HUD item 3 (아이콘 기반 HUD 간소화, first
-- slice): TAP TO LAUNCH gets a small rocket icon above it. The icon is a
-- pure-geometry helper (no love.graphics calls) so it can be regression
-- tested headless: it must return an even-length flat {x,y,...} polygon
-- list, be vertically symmetric around cx (nose tip and both fin tips
-- centered on cx), and have its topmost point (the nose) strictly above
-- its bottommost points (the fins) so it reads as an upward-pointing
-- rocket silhouette.
local function testLaunchRocketIcon()
    local PlayScene = require("game.scenes.play")
    local points = PlayScene.rocketIconPoints(90, 200, 14)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "rocket silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 200 and maxY > 200, "rocket must span above and below its center")
    assert(maxY - minY > 0, "rocket must have nonzero height")
    -- Nose tip (first point) is the topmost and horizontally centered.
    assert(points[1] == 90 and points[2] == minY,
        "first vertex must be the centered nose tip at the icon's topmost y")
end

-- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
-- second slice): the hull-durability status segment gets a small shield
-- icon paired with it. Pure-geometry regression test mirroring
-- testLaunchRocketIcon: even-length flat polygon list, horizontally
-- symmetric around cx, spans above and below cy.
local function testHullShieldIcon()
    local PlayScene = require("game.scenes.play")
    local points = PlayScene.shieldIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "shield silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "shield must span above and below its center")
    -- Horizontally symmetric: for every point at x, there is a matching
    -- point at (2*cx - x) with the same y among the vertex list.
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "shield outline must be horizontally symmetric around cx")
    end
end

-- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
-- third slice): the CASH readout gets a small coin icon paired with it.
-- Pure-geometry regression test mirroring testHullShieldIcon: even-length
-- flat polygon list, at least a triangle, spans above and below cy, and
-- horizontally symmetric around cx (a coin drawn as a simple diamond/octagon
-- silhouette rather than a circle so it can be regression-tested exactly
-- like the other icons without love.graphics.circle's implicit segment
-- count).
local function testCashCoinIcon()
    local PlayScene = require("game.scenes.play")
    local points = PlayScene.coinIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "coin silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "coin must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "coin outline must be horizontally symmetric around cx")
    end
end

local function testDebris()
    local world = require("game.world")
    local a = world.debris(3, -2)
    local b = world.debris(3, -2)
    assert(#a == #b)
    for i = 1, #a do
        assert(a[i].id == b[i].id and a[i].x == b[i].x and a[i].y == b[i].y)
        assert(a[i].radius == b[i].radius and a[i].kind == b[i].kind)
        assert(a[i].vx ~= nil and a[i].vy ~= nil)
    end

    local kinds, sizes = {}, {}
    for sx = -8, 8 do
        for sy = -8, 8 do
            for _, piece in ipairs(world.debris(sx, sy)) do
                kinds[piece.kind] = true
                sizes[piece.radius] = true
                assert(piece.radius >= 2 and piece.radius <= 16)
                assert(piece.kind == "asteroid" or piece.kind == "can" or piece.kind == "scrap")
            end
        end
    end
    assert(kinds.asteroid and kinds.can and kinds.scrap,
        "debris field must mix asteroids with junk (cans/scrap)")
    local distinctSizes = 0
    for _ in pairs(sizes) do distinctSizes = distinctSizes + 1 end
    assert(distinctSizes >= 3, "debris must come in several sizes")

    local drifted = world.debris(3, -2, 2)
    assert(#drifted == #a)
    local moved = false
    for i = 1, #a do
        if drifted[i].x ~= a[i].x or drifted[i].y ~= a[i].y then moved = true end
    end
    assert(moved, "debris must drift over time")

    local nearby = world.nearbyDebris(0, 0, 1)
    assert(type(nearby) == "table")

    local debrisScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    debrisScene.expedition.phase = "ascending"
    debrisScene.expedition.money = 80
    debrisScene.expedition.sampleCount = 2
    debrisScene.expedition.pendingSampleValue = 40
    debrisScene.expedition.fuelUpgradeLevel = 1
    debrisScene.expedition.bestAltitude = 400
    debrisScene.ship.x, debrisScene.ship.y = 0, -40
    local nearbyDebris = world.nearbyDebris
    world.nearbyDebris = function()
        return { { id = "junk-can", x = 0, y = -40, radius = 3, kind = "can", vx = 0, vy = 0 } }
    end
    debrisScene:update(0)
    world.nearbyDebris = nearbyDebris
    local wiped = debrisScene.expedition
    assert(wiped.phase == "destroyed" and wiped.durability == 0)
    assert(wiped.money == 0 and wiped.sampleCount == 0 and wiped.pendingSampleValue == 0)
    assert(wiped.fuelUpgradeLevel == 0)
    assert(wiped.bestAltitude == 400)
    assert(debrisScene.message == "SHIP DESTROYED  BEST 400  META RESET")
end

-- docs/feedback/INBOX.md item 13: JSON gear-data loader must validate
-- schema and defensively reject malformed data (duplicate ids,
-- out-of-range effect values, unknown effect types/rarities, missing
-- fields) instead of silently corrupting the card pool.
local function testGearJsonLoader()
    -- Minimal decoder smoke test (game.json) covering the subset of
    -- syntax the gear data files actually use.
    local decoded = json.decode('{"a": 1, "b": [1, 2.5, "x", true, false], "c": {"d": null}}')
    assert(decoded.a == 1)
    assert(decoded.b[1] == 1 and decoded.b[2] == 2.5 and decoded.b[3] == "x" and decoded.b[4] == true and decoded.b[5] == false)
    assert(decoded.c.d == nil)
    local okBad = pcall(json.decode, "{not json")
    assert(not okBad, "malformed JSON must raise an error")

    -- The real bundled hull/engine part data files must load and validate
    -- cleanly through love.filesystem (this is the real production path,
    -- not a mocked filesystem).
    local hullPool, hullErr = gear.loadHullParts()
    assert(hullPool, "hull parts must load: " .. tostring(hullErr))
    assert(#hullPool >= 1, "hull parts pool must be non-empty")
    for _, part in ipairs(hullPool) do
        assert(gear.knownRarities[part.rarity], "hull part has unknown rarity: " .. tostring(part.rarity))
        assert(#part.effects >= 1, "hull part must have at least one effect: " .. part.id)
    end

    local enginePool, engineErr = gear.loadEngineParts()
    assert(enginePool, "engine parts must load: " .. tostring(engineErr))
    assert(#enginePool >= 1, "engine parts pool must be non-empty")

    -- gear.findById must resolve a known id and return nil for unknown ids.
    assert(gear.findById(hullPool, hullPool[1].id) == hullPool[1])
    assert(gear.findById(hullPool, "does-not-exist") == nil)

    -- Defensive parsing: a fake in-memory filesystem lets us exercise
    -- failure paths without touching the real bundled JSON files.
    local function fakeFs(contents)
        return { read = function(path) return contents end }
    end

    local missingOk, missingErr = gear.loadPool("does/not/exist.json", { read = function() return nil end })
    assert(not missingOk and missingErr, "missing file must fail with an error message")

    local malformedOk, malformedErr = gear.loadPool("x.json", fakeFs("{not valid json"))
    assert(not malformedOk and malformedErr:find("invalid JSON"), "malformed JSON must be reported")

    local dupOk, dupErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [' ..
        '{"id":"a","name":"A","icon":"x","rarity":"common","effects":[{"type":"speed","value":1}]},' ..
        '{"id":"a","name":"A2","icon":"x","rarity":"common","effects":[{"type":"speed","value":1}]}' ..
        ']}'))
    assert(not dupOk and dupErr:find("duplicate part id"), "duplicate ids must be rejected")

    local rangeOk, rangeErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [{"id":"a","name":"A","icon":"x","rarity":"common","effects":[{"type":"speed","value":9999}]}]}'))
    assert(not rangeOk and rangeErr:find("out of range"), "out-of-range effect value must be rejected")

    local badTypeOk, badTypeErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [{"id":"a","name":"A","icon":"x","rarity":"common","effects":[{"type":"bogusEffect","value":1}]}]}'))
    assert(not badTypeOk and badTypeErr:find("unknown type"), "unknown effect type must be rejected")

    local badRarityOk, badRarityErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [{"id":"a","name":"A","icon":"x","rarity":"mythic","effects":[{"type":"speed","value":1}]}]}'))
    assert(not badRarityOk and badRarityErr:find("unknown rarity"), "unknown rarity must be rejected")

    local noEffectsOk, noEffectsErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [{"id":"a","name":"A","icon":"x","rarity":"common","effects":[]}]}'))
    assert(not noEffectsOk and noEffectsErr:find("at least one effect"), "empty effects array must be rejected")

    local missingIdOk, missingIdErr = gear.loadPool("x.json", fakeFs(
        '{"parts": [{"name":"A","icon":"x","rarity":"common","effects":[{"type":"speed","value":1}]}]}'))
    assert(not missingIdOk and missingIdErr:find("missing a non%-empty string id"), "missing id must be rejected")
end

-- docs/feedback/INBOX.md item 9: "부품들의 조합(시너지)이 고도(distance-from-Earth
-- 점수) 상승 속도/효율에 배가 효과를 내는 것" — combos must multiply, not just add.
-- This exercises game/gear.lua's pure tag-synergy engine: two equipped parts
-- sharing a tag must yield MORE climbSpeed than the two parts' raw additive
-- sum would give alone, and the bundled hull_parts.json card pool must have
-- grown to the 20-30 range item 9 calls for.
local function testGearSynergyEngine()
    local hullPool, hullErr = gear.loadHullParts()
    assert(hullPool, "hull parts must load: " .. tostring(hullErr))
    assert(#hullPool >= 20, "hull part pool must have at least 20 cards (item 9), got " .. #hullPool)

    -- Every card must carry at least one synergy tag so the engine has
    -- something to match against.
    for _, part in ipairs(hullPool) do
        assert(#part.tags >= 1, "hull part '" .. part.id .. "' must have at least one tag")
    end

    -- Pure aggregate: summing effect values of all equipped parts, no synergy.
    local partA = { id = "a", tags = { "altitude" }, effects = { { type = "climbSpeed", value = 4 } } }
    local partB = { id = "b", tags = { "altitude" }, effects = { { type = "climbSpeed", value = 8 } } }
    local partC = { id = "c", tags = { "economy" }, effects = { { type = "sampleSellValue", value = 5 } } }

    local rawTotals = gear.aggregateEffects({ partA, partB })
    assert(rawTotals.climbSpeed == 12, "raw additive sum must be 12, got " .. tostring(rawTotals.climbSpeed))

    -- Two parts sharing the "altitude" tag must synergize: the combined
    -- multiplier must exceed 1 (i.e. more than simple addition).
    local sharedMultiplier = gear.tagSynergyMultiplier({ partA, partB })
    assert(sharedMultiplier > 1, "shared-tag parts must produce a synergy multiplier > 1, got " .. tostring(sharedMultiplier))

    -- A single part (no partner sharing its tag) must get no synergy bonus.
    local soloMultiplier = gear.tagSynergyMultiplier({ partA, partC })
    assert(soloMultiplier == 1, "non-overlapping tags must not synergize, got " .. tostring(soloMultiplier))

    -- equippedTotals must apply the multiplier to climbSpeed specifically,
    -- so the combo total is strictly greater than the raw additive sum.
    local combo = gear.equippedTotals({ partA, partB })
    assert(combo.climbSpeed > rawTotals.climbSpeed,
        "synergized climbSpeed (" .. tostring(combo.climbSpeed) ..
        ") must exceed raw additive sum (" .. tostring(rawTotals.climbSpeed) .. ")")
    assert(combo.synergyMultiplier == sharedMultiplier)

    -- Non-climbSpeed effect types (e.g. sampleSellValue) must remain purely
    -- additive — synergy in this cycle only amplifies altitude/climb rate.
    local mixedCombo = gear.equippedTotals({ partA, partC })
    assert(mixedCombo.sampleSellValue == 5, "sampleSellValue must stay additive, got " .. tostring(mixedCombo.sampleSellValue))
end

-- docs/feedback/INBOX.md item 10: "부품 슬롯 이원화 — 선체(허브/조커형) 부품 +
-- 엔진(타로/소모형) 부품 분리". Hull and engine slots must be tracked in two
-- fully independent lists that neither fill nor empty each other, and the
-- bundled engine_parts.json card pool must load and grow to a reasonable
-- initial size just like hull_parts.json did for item 9.
local function testEnginePartsSlotSeparation()
    local enginePool, engineErr = gear.loadEngineParts()
    assert(enginePool, "engine parts must load: " .. tostring(engineErr))
    assert(#enginePool >= 10, "engine part pool should have at least 10 cards, got " .. #enginePool)
    for _, part in ipairs(enginePool) do
        assert(#part.tags >= 1, "engine part '" .. part.id .. "' must have at least one tag")
    end

    local loadout = enginePartsModule.newLoadout()
    assert(#loadout.hull == 0 and #loadout.engine == 0)

    local hullPart = { id = "hull_x", tags = { "defense" }, effects = { { type = "hullDurability", value = 1 } } }
    local enginePart = { id = "engine_x", tags = { "speed" }, effects = { { type = "speed", value = 1 } } }

    local ok1 = enginePartsModule.equip(loadout, "hull", hullPart)
    assert(ok1)
    -- Equipping a hull part must not touch the engine slot list at all.
    assert(#loadout.hull == 1 and #loadout.engine == 0,
        "equipping a hull part must not affect the engine slot list")

    local ok2 = enginePartsModule.equip(loadout, "engine", enginePart)
    assert(ok2)
    assert(#loadout.hull == 1 and #loadout.engine == 1,
        "hull and engine slot lists must be independently tracked")

    -- Unequipping from one category must not touch the other.
    assert(enginePartsModule.unequip(loadout, "engine", "engine_x"))
    assert(#loadout.hull == 1 and #loadout.engine == 0,
        "unequipping an engine part must not affect the hull slot list")

    -- Filling the (smaller) engine slot capacity independently of hull
    -- capacity: engine capacity must be reached without hull slots
    -- affecting it, and vice versa.
    for i = 1, enginePartsModule.engineSlotCount do
        local ok = enginePartsModule.equip(loadout, "engine", { id = "engine_fill_" .. i, tags = {}, effects = {} })
        assert(ok, "expected to be able to equip engine part #" .. i)
    end
    assert(enginePartsModule.isFull(loadout, "engine"), "engine slots must report full at capacity")
    assert(not enginePartsModule.isFull(loadout, "hull"),
        "hull slots must NOT report full just because engine slots are full")

    local okOverflow, overflowErr = enginePartsModule.equip(loadout, "engine", { id = "engine_overflow", tags = {}, effects = {} })
    assert(not okOverflow and overflowErr, "equipping beyond engine capacity must fail")

    -- Duplicate ids within the same category must be rejected.
    local okDup, dupErr = enginePartsModule.equip(loadout, "hull", hullPart)
    assert(not okDup and dupErr, "equipping the same part id twice in one category must fail")
end

-- docs/feedback/INBOX.md item 12: "선체/엔진 부품 등급(레어리티) + 부수 효과
-- (에디션) 시스템". Two independent axes: (A) rarity drop weights (rarer
-- tiers must be picked less often, and `luck` must shift the odds toward
-- higher tiers), and (B) edition assignment (low base chance, gated to a
-- card's own editions list, and an edition must transform the card's
-- effect values when applied).
local function testGearRarityAndEditionSystem()
    -- (A) Rarity drop weights: common must be the most common outcome at
    -- roll=0, legendary must be reachable near roll=1, and increasing luck
    -- must never make legendary less likely at the same roll.
    assert(gear.rollRarity(0, 0) == "common", "roll=0 must yield the first (most common) tier")
    assert(gear.rollRarity(0.999, 0) == "legendary", "roll near 1 must reach the rarest tier")

    -- With no luck, a roll high enough to land in "rare" territory must do so.
    local noLuck = gear.rollRarity(0.9, 0)
    local withLuck = gear.rollRarity(0.9, 1.0)
    local tierRank = { common = 1, uncommon = 2, rare = 3, legendary = 4 }
    assert(tierRank[withLuck] >= tierRank[noLuck],
        "higher luck must never downgrade the rolled rarity at a fixed roll, got " ..
        noLuck .. " -> " .. withLuck)

    -- Every card in both bundled pools must reference only known rarities
    -- (already enforced by the loader) and, when non-empty, only known
    -- edition ids (also enforced by the loader — a malformed edition id
    -- would have made loadHullParts/loadEngineParts fail above).
    local hullPool = gear.loadHullParts()
    local enginePool = gear.loadEngineParts()
    local sawHullEdition, sawEngineEdition = false, false
    for _, part in ipairs(hullPool) do
        if #part.editions > 0 then sawHullEdition = true end
    end
    for _, part in ipairs(enginePool) do
        if #part.editions > 0 then sawEngineEdition = true end
    end
    assert(sawHullEdition, "at least one bundled hull part must declare candidate editions")
    assert(sawEngineEdition, "at least one bundled engine part must declare candidate editions")

    -- (B) Edition assignment: a card with an empty editions list must never
    -- roll one, regardless of roll values.
    local noEditionPart = { editions = {} }
    assert(gear.rollEdition(noEditionPart, 0, 0, 0) == nil,
        "a part with no candidate editions must never roll one")

    -- A card WITH candidate editions must roll one when chanceRoll is below
    -- the base chance, and must NOT roll one when chanceRoll is above it.
    local candidatePart = { editions = { "irradiated", "crystallized" } }
    local rolledLow = gear.rollEdition(candidatePart, 0, 0, 0)
    assert(rolledLow == "irradiated", "chanceRoll=0 must trigger and pickRoll=0 must select the first edition")
    local rolledHigh = gear.rollEdition(candidatePart, 0.99, 0, 0)
    assert(rolledHigh == nil, "chanceRoll above base chance must not assign an edition")

    -- luck (item 14 target #1: edition chance) must raise the effective
    -- chance so a roll just above the base (unboosted) chance still hits.
    local justAboveBase = gear.baseEditionChance + 0.01
    assert(gear.rollEdition(candidatePart, justAboveBase, 0, 0) == nil,
        "without luck, a roll just above base chance must not assign an edition")
    assert(gear.rollEdition(candidatePart, justAboveBase, 0, 0.05) == "irradiated",
        "luck must raise the effective edition chance enough to cover a roll just above base")

    -- Applying an edition must transform effect values (not just tag it):
    -- "crystallized" doubles sampleSellValue per docs/GEAR_SCHEMA.md-style
    -- edition definitions, leaving unrelated effect types untouched.
    local part = {
        effects = {
            { type = "sampleSellValue", value = 5 },
            { type = "hullDurability", value = 2 },
        },
    }
    local unedited = gear.applyEditionEffects(part, nil)
    assert(unedited[1].value == 5 and unedited[2].value == 2, "nil edition must leave effects unchanged")

    local crystallized = gear.applyEditionEffects(part, "crystallized")
    assert(crystallized[1].value == 10, "crystallized must double sampleSellValue, got " .. tostring(crystallized[1].value))
    assert(crystallized[2].value == 2, "crystallized must not affect unrelated effect types")

    -- "quantum_flawed" doubles ALL effects but appends a hullDurability
    -- drawback (item 12: "효과가 두 배지만 부작용 하나 동반").
    local flawed = gear.applyEditionEffects(part, "quantum_flawed")
    assert(flawed[1].value == 10 and flawed[2].value == 4, "quantum_flawed must double every effect value")
    assert(#flawed == 3 and flawed[3].type == "hullDurability" and flawed[3].value < 0,
        "quantum_flawed must append a negative hullDurability drawback effect")

    -- applying an edition must never mutate the original part's effects.
    assert(part.effects[1].value == 5, "applyEditionEffects must not mutate the input part")

    -- Unknown edition ids must fail loudly, matching the loader's
    -- fail-loud posture for other malformed gear data.
    local ok, err = pcall(gear.applyEditionEffects, part, "not_a_real_edition")
    assert(not ok and tostring(err):find("unknown edition"), "unknown edition id must raise an error")

    -- The "irradiated" edition amplifies tag synergy (item 12: "시너지 태그
    -- 매칭 시 보너스 추가 증폭") — must be strictly positive only for
    -- irradiated, and zero for a plain (no-edition) card.
    assert(gear.editionSynergyBonusAdd("irradiated") > 0, "irradiated must add a positive synergy bonus")
    assert(gear.editionSynergyBonusAdd(nil) == 0, "no edition must add zero synergy bonus")
end

-- docs/feedback/INBOX.md item 12/13: the web editor's client-side
-- validation is documented (tools/gear-editor/README.md, editor.js's own
-- header comment: "Validation rules here intentionally mirror
-- game/gear.lua's loader exactly") as staying byte-for-byte in sync with
-- gear.lua's `M.knownEditions`/`M.knownRarities` whitelists -- exactly the
-- same sync guarantee `testGearEffectSchemaExpansion` already enforces for
-- `M.knownEffectTypes`/`EFFECT_TYPE_GROUPS`. Until this test, that
-- guarantee for editions/rarities existed only as a comment: nothing
-- actually re-read editor.js's `KNOWN_EDITIONS`/`KNOWN_RARITIES` arrays and
-- compared them against gear.lua, so a future rarity/edition added to one
-- side but not the other would silently drift (the editor would either
-- reject valid game data or accept data the game loader rejects) with no
-- test catching it.
local function testGearEditorEditionAndRaritySync()
    local editorSrc = love.filesystem.read("tools/gear-editor/editor.js")
    assert(editorSrc, "tools/gear-editor/editor.js must be readable for the sync check")

    local editionsStart = editorSrc:find("KNOWN_EDITIONS%s*=%s*%[")
    assert(editionsStart, "editor.js must define a KNOWN_EDITIONS array")
    local editionsEnd = editorSrc:find("%]", editionsStart)
    local editionsBlock = editorSrc:sub(editionsStart, editionsEnd)
    for edition, _ in pairs(gear.knownEditions) do
        assert(editionsBlock:find('"' .. edition .. '"', 1, true),
            "editor.js KNOWN_EDITIONS must include '" .. edition .. "' to stay in sync with gear.lua")
    end

    local raritiesStart = editorSrc:find("KNOWN_RARITIES%s*=%s*%[")
    assert(raritiesStart, "editor.js must define a KNOWN_RARITIES array")
    local raritiesEnd = editorSrc:find("%]", raritiesStart)
    local raritiesBlock = editorSrc:sub(raritiesStart, raritiesEnd)
    for rarity, _ in pairs(gear.knownRarities) do
        assert(raritiesBlock:find('"' .. rarity .. '"', 1, true),
            "editor.js KNOWN_RARITIES must include '" .. rarity .. "' to stay in sync with gear.lua")
    end
end

-- docs/feedback/INBOX.md item 12/13 (follow-up): STATUS.md's own recorded
-- next-slice note flagged that the web editor's edition sync check (just
-- above) only verifies the editor *accepts* the right edition ids -- it
-- never verifies the editor actually *previews* what an edition numerically
-- does to a card's effects (e.g. "crystallized" doubling sampleSellValue,
-- "quantum_flawed" doubling everything but appending a hullDurability
-- drawback), even though `game/gear.lua`'s `M.editionEffects` is the single
-- source of truth for exactly that transform and is documented as something
-- "the web editor's preview" should also read (gear.lua's own comment on
-- `M.editionEffects`: "Kept centralized so gear.lua and the web editor's
-- preview both read the exact same table"). Until this test, no code ever
-- checked that editor.js actually has such a preview table, so a numeric
-- edit to `M.editionEffects` (e.g. rebalancing crystallized from 2.0x to
-- 2.5x) could silently drift from what the editor shows an author while
-- they design a card.
local function testGearEditorEditionEffectPreviewSync()
    local editorSrc = love.filesystem.read("tools/gear-editor/editor.js")
    assert(editorSrc, "tools/gear-editor/editor.js must be readable for the sync check")

    local tableStart = editorSrc:find("EDITION_EFFECTS%s*=%s*{")
    assert(tableStart, "editor.js must define an EDITION_EFFECTS table mirroring gear.lua's M.editionEffects")
    local tableEnd = editorSrc:find("\n};", tableStart) or editorSrc:find("\n}", tableStart)
    assert(tableEnd, "editor.js EDITION_EFFECTS table must be closed with a '}'")
    local block = editorSrc:sub(tableStart, tableEnd)

    for editionId, def in pairs(gear.editionEffects) do
        local entryStart = block:find('"' .. editionId .. '"%s*:%s*{')
        assert(entryStart, "editor.js EDITION_EFFECTS must include an entry for '" .. editionId .. "'")
        local entryEnd = block:find("}", entryStart)
        local entry = block:sub(entryStart, entryEnd)

        local scopeMatch = entry:match('scope%s*:%s*"([%w]+)"')
        assert(scopeMatch == def.scope,
            "editor.js EDITION_EFFECTS['" .. editionId .. "'].scope must be '" .. tostring(def.scope) ..
            "' to match gear.lua, got '" .. tostring(scopeMatch) .. "'")

        local multMatch = entry:match("multiplier%s*:%s*([%d%.]+)")
        assert(multMatch and tonumber(multMatch) == def.multiplier,
            "editor.js EDITION_EFFECTS['" .. editionId .. "'].multiplier must be " .. tostring(def.multiplier) ..
            " to match gear.lua, got " .. tostring(multMatch))
    end

    -- The preview must actually be wired to the form, not just declared as
    -- dead data: the editions field's change handler (or an equivalent
    -- explicit preview-update function) must exist and reference
    -- EDITION_EFFECTS so an author sees the transformed values live.
    assert(editorSrc:find("updateEditionPreview"),
        "editor.js must define/wire an updateEditionPreview function so effect values reflect selected editions live")
end

-- docs/feedback/INBOX.md item 14: "부품 효과 종류(effect schema) 확장 — 가산형
-- 5종 + 배율/트리거/조작형 추가". Verifies every newly whitelisted effect
-- type from categories (B)~(F) actually does something distinct (not just
-- validated-and-ignored), that (B) multiplicative effects are applied
-- AFTER (A) additive totals (additive-sum-then-multiply, never
-- compounded), and that the editor's KNOWN_EFFECT_TYPES list stays in sync
-- with game/gear.lua's whitelist (mirrors the existing knownEditions/
-- knownRarities sync convention).
local function testGearEffectSchemaExpansion()
    -- Every category (A)~(F) effect type referenced by docs/GEAR_SCHEMA.md
    -- item 14 must be a known, loadable effect type.
    local expectedTypes = {
        "speed", "sampleSellValue", "money", "climbSpeed", "hullDurability",
        "sellMultiplier", "streakMultiplier",
        "luck", "chainTrigger", "rerollBonus",
        "insurance", "collisionRadius",
        "detectionRadius", "autoCollect",
        "shopDiscount",
    }
    for _, t in ipairs(expectedTypes) do
        assert(gear.knownEffectTypes[t], "effect type '" .. t .. "' must be known (item 14)")
        assert(gear.effectCategories[t], "effect type '" .. t .. "' must be assigned a schema category (item 14)")
    end

    -- (B) sellMultiplier: additive-sum-then-multiply, per card, applied
    -- AFTER (A) additive totals are summed — two +25% sellMultiplier cards
    -- must give +50% total (additive stacking of the percentage), not
    -- compounding (+56.25%).
    local sellA = { id = "sa", tags = {}, effects = { { type = "sampleSellValue", value = 10 }, { type = "sellMultiplier", value = 25 } } }
    local sellB = { id = "sb", tags = {}, effects = { { type = "sellMultiplier", value = 25 } } }
    local sellTotals = gear.equippedTotals({ sellA, sellB })
    assert(math.abs(sellTotals.sampleSellValue - 15) < 1e-9,
        "sampleSellValue 10 with +50% combined sellMultiplier must be 15, got " .. tostring(sellTotals.sampleSellValue))

    -- A part with no sellMultiplier at all must leave sampleSellValue
    -- purely additive, matching pre-item-14 behavior exactly.
    local plain = { id = "p", tags = {}, effects = { { type = "sampleSellValue", value = 7 } } }
    local plainTotals = gear.equippedTotals({ plain })
    assert(plainTotals.sampleSellValue == 7, "no sellMultiplier must leave sampleSellValue unchanged")

    -- (C) chainTrigger / rerollBonus: discrete non-negative counts.
    local triggerPart = { id = "t", tags = {}, effects = { { type = "chainTrigger", value = 2.9 } } }
    assert(gear.chainTriggerCount({ triggerPart }) == 2, "chainTrigger total must floor to a whole re-trigger count")
    assert(gear.chainTriggerCount({}) == 0, "no chainTrigger effects must yield zero re-triggers")

    local rerollPart = { id = "r", tags = {}, effects = { { type = "rerollBonus", value = 3 } } }
    assert(gear.rerollCount({ rerollPart }) == 3, "rerollBonus total must convert to a free-reroll count")

    -- (C) luck: converts a summed percentage-shaped effect value into the
    -- fractional luckBonus M.rollRarity/M.rollEdition already expect.
    local luckPart = { id = "l", tags = {}, effects = { { type = "luck", value = 5 } } }
    assert(math.abs(gear.totalLuckBonus({ luckPart }) - 0.05) < 1e-9,
        "luck effect value 5 must convert to luckBonus 0.05")
    assert(gear.totalLuckBonus({}) == 0, "no luck effects must yield zero luckBonus")

    -- (D) insurance: boolean-ish gate, true with any positive total, false
    -- with none.
    local insurancePart = { id = "i", tags = {}, effects = { { type = "insurance", value = 1 } } }
    assert(gear.hasInsurance({ insurancePart }) == true, "positive insurance effect must grant insurance")
    assert(gear.hasInsurance({}) == false, "no insurance effects must not grant insurance")

    -- (D) collisionRadius: percentage shrink of a base hitbox radius,
    -- clamped at zero.
    local shrinkPart = { id = "cr", tags = {}, effects = { { type = "collisionRadius", value = 20 } } }
    assert(math.abs(gear.effectiveCollisionRadius(10, { shrinkPart }) - 8) < 1e-9,
        "collisionRadius -20%% of base 10 must be 8")
    local hugeShrinkPart = { id = "cr2", tags = {}, effects = { { type = "collisionRadius", value = 500 } } }
    assert(gear.effectiveCollisionRadius(10, { hugeShrinkPart }) == 0,
        "collisionRadius must clamp at zero, never negative")

    -- (E) detectionRadius: percentage growth of a base scan radius.
    local scanPart = { id = "dr", tags = {}, effects = { { type = "detectionRadius", value = 50 } } }
    assert(math.abs(gear.effectiveDetectionRadius(20, { scanPart }) - 30) < 1e-9,
        "detectionRadius +50%% of base 20 must be 30")

    -- (E) autoCollect: boolean gate, same shape as insurance.
    local autoPart = { id = "ac", tags = {}, effects = { { type = "autoCollect", value = 1 } } }
    assert(gear.autoCollectEnabled({ autoPart }) == true, "positive autoCollect effect must enable auto-collect")
    assert(gear.autoCollectEnabled({}) == false, "no autoCollect effects must not enable auto-collect")

    -- (F) shopDiscount: percentage discount off a base price, clamped at
    -- zero (never a negative price).
    local discountPart = { id = "sd", tags = {}, effects = { { type = "shopDiscount", value = 30 } } }
    assert(math.abs(gear.effectiveShopPrice(100, { discountPart }) - 70) < 1e-9,
        "shopDiscount -30%% of base price 100 must be 70")
    local hugeDiscountPart = { id = "sd2", tags = {}, effects = { { type = "shopDiscount", value = 500 } } }
    assert(gear.effectiveShopPrice(100, { hugeDiscountPart }) == 0,
        "shopDiscount must clamp price at zero, never negative")

    -- The web editor's effect-type list (tools/gear-editor/editor.js) must
    -- be kept in sync with gear.lua's whitelist, exactly like
    -- knownEditions/knownRarities already are. Read the JS source and
    -- verify every gear.knownEffectTypes entry appears as a quoted string
    -- literal within its EFFECT_TYPE_GROUPS table (the source of
    -- KNOWN_EFFECT_TYPES, item 14's grouped A~F dropdown).
    local editorSrc = love.filesystem.read("tools/gear-editor/editor.js")
    assert(editorSrc, "tools/gear-editor/editor.js must be readable for the sync check")
    local groupsStart = editorSrc:find("EFFECT_TYPE_GROUPS%s*=%s*{")
    assert(groupsStart, "editor.js must define an EFFECT_TYPE_GROUPS table")
    local groupsEnd = editorSrc:find("};", groupsStart)
    local groupsBlock = editorSrc:sub(groupsStart, groupsEnd)
    for t, _ in pairs(gear.knownEffectTypes) do
        assert(groupsBlock:find('"' .. t .. '"', 1, true),
            "editor.js EFFECT_TYPE_GROUPS must include '" .. t .. "' to stay in sync with gear.lua")
    end
end

-- docs/feedback/INBOX.md item 10(b): "엔진 부품은... 추진/기동 계열에
-- 특화된 효과(상승 가속, 연료 효율, 조종 반응성, 긴급 부스트/1회성 소모
-- 아이템 등)에 집중해 선체 부품(내구도/채집/시너지 등 범용)과 역할이
-- 겹치지 않도록 차별화한다." Verifies the new (G) propulsion-specialization
-- effect category exists, its conversion functions behave correctly, the
-- bundled engine_parts.json pool actually uses these types (making the
-- engine pool mechanically distinct from the hull pool), and the bundled
-- hull_parts.json pool does NOT use them (keeping hull's role generic per
-- the "역할이 겹치지 않도록" requirement).
local function testEnginePropulsionSpecialization()
    -- (G) effect types must be known and categorized.
    for _, t in ipairs({ "fuelEfficiency", "steeringResponsiveness", "boostCharge" }) do
        assert(gear.knownEffectTypes[t], "effect type '" .. t .. "' must be known (item 10b)")
        assert(gear.effectCategories[t] == "G",
            "effect type '" .. t .. "' must be categorized as (G) propulsion")
    end

    -- (G) fuelEfficiency: percentage reduction of a base burn rate, clamped
    -- at zero.
    local effPart = { id = "fe", tags = {}, effects = { { type = "fuelEfficiency", value = 20 } } }
    assert(math.abs(gear.effectiveFuelBurnRate(10, { effPart }) - 8) < 1e-9,
        "fuelEfficiency -20%% of base burn rate 10 must be 8")
    local hugeEffPart = { id = "fe2", tags = {}, effects = { { type = "fuelEfficiency", value = 500 } } }
    assert(gear.effectiveFuelBurnRate(10, { hugeEffPart }) == 0,
        "fuelEfficiency must clamp burn rate at zero, never negative")

    -- (G) steeringResponsiveness: percentage growth of a base turn rate.
    local steerPart = { id = "sr", tags = {}, effects = { { type = "steeringResponsiveness", value = 15 } } }
    assert(math.abs(gear.effectiveSteeringRate(100, { steerPart }) - 115) < 1e-9,
        "steeringResponsiveness +15%% of base turn rate 100 must be 115")

    -- (G) boostCharge: discrete non-negative charge count.
    local boostPart = { id = "bc", tags = {}, effects = { { type = "boostCharge", value = 2.7 } } }
    assert(gear.boostChargeCount({ boostPart }) == 2, "boostCharge total must floor to a whole charge count")
    assert(gear.boostChargeCount({}) == 0, "no boostCharge effects must yield zero charges")

    -- The bundled engine_parts.json pool must actually use at least one of
    -- the three (G) types on at least one card each, so the propulsion
    -- specialization is real content, not just dead schema.
    local enginePool = gear.loadEngineParts()
    local sawFuelEff, sawSteering, sawBoost = false, false, false
    for _, part in ipairs(enginePool) do
        for _, effect in ipairs(part.effects) do
            if effect.type == "fuelEfficiency" then sawFuelEff = true end
            if effect.type == "steeringResponsiveness" then sawSteering = true end
            if effect.type == "boostCharge" then sawBoost = true end
        end
    end
    assert(sawFuelEff, "engine_parts.json must include at least one fuelEfficiency card")
    assert(sawSteering, "engine_parts.json must include at least one steeringResponsiveness card")
    assert(sawBoost, "engine_parts.json must include at least one boostCharge card")

    -- The bundled hull_parts.json pool must stay free of the (G) types —
    -- item 10(b)'s "역할이 겹치지 않도록 차별화" requirement, kept as a
    -- concrete regression rather than just a doc claim.
    local hullPool = gear.loadHullParts()
    for _, part in ipairs(hullPool) do
        for _, effect in ipairs(part.effects) do
            assert(gear.effectCategories[effect.type] ~= "G",
                "hull_parts.json card '" .. part.id .. "' must not use a (G) propulsion-specialization effect type")
        end
    end
end

-- Item 14 (A)~(G) content coverage: every run-wired effect type in
-- gear.knownEffectTypes must actually be used by at least one card in the
-- bundled hull_parts.json/engine_parts.json pools combined, not merely
-- exist as validated-but-dead schema. item 10(b)'s testEnginePropulsionSpecialization
-- already checked this for the (G) propulsion trio; this generalizes the
-- same "real content, not just schema" regression to the full A~F set,
-- which docs/STATUS.md had documented as having a "최소 1개 실제
-- run-level 소비자" (a run-state *function*) for every type, but several
-- types (luck, chainTrigger, rerollBonus, collisionRadius, detectionRadius,
-- autoCollect, sellMultiplier) still had zero cards actually using them in
-- the shipped card pools -- so the run-level wiring existed but a player
-- could never actually encounter it in play.
local function testGearEffectTypeContentCoverage()
    local hullPool = gear.loadHullParts()
    local enginePool = gear.loadEngineParts()
    local seen = {}
    for _, pool in ipairs({ hullPool, enginePool }) do
        for _, part in ipairs(pool) do
            for _, effect in ipairs(part.effects) do
                seen[effect.type] = true
            end
        end
    end
    for t, _ in pairs(gear.knownEffectTypes) do
        assert(seen[t], "effect type '" .. t ..
            "' must be used by at least one bundled hull/engine part (content coverage, item 14)")
    end
end

-- Item 10/14 content-coverage gap audit (this lane's recurring "문서-코드
-- 정합성 감사" pattern applied one level deeper than
-- testGearEffectTypeContentCoverage above): that test only checks that
-- every effect TYPE appears somewhere across the two pools combined, but
-- several run-level wrappers are documented (game/self_test.lua's
-- testGearHullSpeedRunWiring/testGearMoneyRunWiring and
-- docs/GEAR_SCHEMA.md) as explicitly HULL-ONLY -- an engine-slot card
-- carrying `speed`/`money`/`climbSpeed`/`hullDurability`/`sampleSellValue`
-- (the (A) additive types item 9 scopes to hull "조커형" gear) contributes
-- NOTHING when equipped in the engine slot. A bundled engine_parts.json
-- card whose effects are ENTIRELY drawn from that hull-only set is
-- therefore live-looking schema but dead-in-practice content: a player can
-- equip it in its only legal slot category and see zero gameplay effect.
-- Auditing the actual bundled pool finds 9 of engine_parts.json's 14 cards
-- in exactly this state (engine_basic_thruster, engine_afterburner,
-- engine_fusion_core, engine_azure_coolant_jet, engine_ember_burst_valve,
-- engine_void_phase_thruster, engine_solar_sail_flap,
-- engine_burst_capacitor, engine_singularity_drive) -- every single one of
-- the original pre-item-10(b) engine cards, none of which ever got a (G)
-- propulsion-specialization or category-agnostic (C)/(E) effect added
-- alongside their hull-only-scoped stats.
local function testEngineCardsHaveNonHullOnlyEffect()
    -- The (A) additive types with documented hull-only run-scope (per
    -- testGearHullDurabilityRunWiring/testGearHullSpeedRunWiring/
    -- testGearMoneyRunWiring/testGearRunWiring's climbSpeed synergy scope
    -- and testGearSurvivalAndEconomyWiring's sampleSellValue scope).
    local hullOnlyTypes = {
        speed = true, money = true, climbSpeed = true,
        hullDurability = true, sampleSellValue = true,
    }
    local enginePool = gear.loadEngineParts()
    local deadCards = {}
    for _, part in ipairs(enginePool) do
        local hasNonHullOnlyEffect = false
        for _, effect in ipairs(part.effects) do
            if not hullOnlyTypes[effect.type] then
                hasNonHullOnlyEffect = true
                break
            end
        end
        if not hasNonHullOnlyEffect then
            deadCards[#deadCards + 1] = part.id
        end
    end
    assert(#deadCards == 0,
        "every bundled engine_parts.json card must carry at least one effect type that is NOT " ..
        "hull-only-scoped (speed/money/climbSpeed/hullDurability/sampleSellValue), otherwise the " ..
        "card contributes nothing when equipped in its only legal (engine) slot; dead cards: " ..
        table.concat(deadCards, ", "))
end

-- Item 10/14 content-coverage gap audit, one level further (this lane's
-- recurring "문서-코드 정합성 감사" pattern applied to a direction the
-- prior two coverage tests never checked). testGearEffectTypeContentCoverage
-- only requires each of gear.knownEffectTypes to appear SOMEWHERE across
-- the hull+engine pools combined; testEngineCardsHaveNonHullOnlyEffect only
-- requires each bundled engine card to have at least one non-hull-only
-- effect. Neither test catches a category-agnostic (B/C/D/E/F) effect type
-- -- one whose run-level wiring explicitly reads BOTH slot lists via
-- expedition.lua's combinedGearList(run) (luck, chainTrigger, rerollBonus,
-- collisionRadius, detectionRadius, autoCollect, insurance, shopDiscount,
-- sellMultiplier, streakMultiplier are all documented as hull/engine
-- category-agnostic, unlike the five (A) hull-only types) -- being usable
-- from hull gear ONLY, with zero bundled engine cards ever carrying it.
-- An audit of the actual `game/data/engine_parts.json` (14 cards) finds
-- exactly this: every one of these 10 category-agnostic types has at least
-- one bundled hull card (per testGearEffectTypeContentCoverage) but not a
-- single bundled engine card, meaning a player who equips only engine gear
-- can never encounter luck/chainTrigger/rerollBonus/collisionRadius/
-- detectionRadius/autoCollect/insurance/shopDiscount/sellMultiplier/
-- streakMultiplier in actual play even though every one of their run
-- wrappers reads the engine slot list too.

local function testHullCardsHaveNonEngineOnlyEffect()
    -- The (G) engine-only types
    local engineOnlyTypes = {
        fuelEfficiency = true, steeringResponsiveness = true, boostCharge = true
    }
    local hullPool = gear.loadHullParts()
    local deadCards = {}
    for _, part in ipairs(hullPool) do
        local hasNonEngineOnlyEffect = false
        for _, effect in ipairs(part.effects) do
            if not engineOnlyTypes[effect.type] then
                hasNonEngineOnlyEffect = true
                break
            end
        end
        if not hasNonEngineOnlyEffect then
            deadCards[#deadCards + 1] = part.id
        end
    end
    assert(#deadCards == 0,
        "hull_parts.json contains cards with ONLY engine-scoped (G) effects, " ..
        "making them completely dead in the hull slot: " .. table.concat(deadCards, ", "))
end

local function testEngineCardsHaveCategoryAgnosticEffectCoverage()
    local categoryAgnosticTypes = {
        "luck", "chainTrigger", "rerollBonus", "collisionRadius",
        "detectionRadius", "autoCollect", "insurance", "shopDiscount",
        "sellMultiplier", "streakMultiplier",
    }
    local enginePool = gear.loadEngineParts()
    local seen = {}
    for _, part in ipairs(enginePool) do
        for _, effect in ipairs(part.effects) do
            seen[effect.type] = true
        end
    end
    local missing = {}
    for _, t in ipairs(categoryAgnosticTypes) do
        if not seen[t] then
            missing[#missing + 1] = t
        end
    end
    assert(#missing == 0,
        "engine_parts.json must contain at least one bundled card for each hull/engine " ..
        "category-agnostic effect type, otherwise an engine-only loadout can never encounter " ..
        "it even though its run wiring reads both slot lists; missing: " ..
        table.concat(missing, ", "))
end

-- Minimal game wiring for items 9/10/13 ("최소한의 로더 호출 추가는 예외로
-- 허용"): expedition.lua now owns a run.gearLoadout (hull + engine slot
-- lists via engine_parts.lua) and applies the item 9 climbSpeed synergy
-- bonus during ascent. This does NOT touch play.lua/world.lua — only the
-- run-state module explicitly carved out as an exception in loop/PROMPT.md.
local function testGearRunWiring()
    local expedition = require("game.expedition")
    local run = expedition.new({ climbSpeed = 60 })

    -- A fresh run starts with an empty, independent hull/engine loadout.
    assert(type(run.equippedGear) == "table" and #run.equippedGear == 0,
        "a fresh run must start with an empty hull gear list")
    assert(type(run.equippedEngineParts) == "table" and #run.equippedEngineParts == 0,
        "a fresh run must start with an empty engine parts list")

    -- Equipping a bundled hull card with a climbSpeed effect must boost
    -- ascent beyond the base climbSpeed (item 9's core payoff, now actually
    -- wired into gameplay instead of only existing as a pure function).
    local hullPool = gear.loadHullParts()
    local climbCard = gear.findById(hullPool, "hull_ember_core") -- climbSpeed +5, no synergy tag overlap needed alone
    assert(climbCard, "fixture hull card 'hull_ember_core' must exist in the bundled pool")
    local ok, err = expedition.equipGear(run, "hull", climbCard)
    assert(ok, "equipping a hull card into a fresh run must succeed: " .. tostring(err))
    assert(#run.equippedGear == 1 and run.equippedGear[1].id == "hull_ember_core")

    expedition.launch(run)
    expedition.update(run, 1)
    assert(run.altitude > 60,
        "equipped hull card's climbSpeed effect must increase ascent beyond the base climbSpeed 60: "
            .. tostring(run.altitude))

    -- Engine parts occupy a fully independent slot list — equipping one
    -- must not touch equippedGear (item 10's core "서로 슬롯을 잠식하지
    -- 않는다" requirement, now checked against the actual run object).
    local enginePool = gear.loadEngineParts()
    local enginePart = enginePool[1]
    local engineOk = expedition.equipGear(run, "engine", enginePart)
    assert(engineOk, "equipping an engine card must succeed")
    assert(#run.equippedEngineParts == 1 and #run.equippedGear == 1,
        "equipping an engine part must not change the hull gear list")

    assert(expedition.unequipGear(run, "hull", "hull_ember_core"))
    assert(#run.equippedGear == 0 and #run.equippedEngineParts == 1,
        "unequipping a hull card must not affect the engine parts list")

    -- Destruction's full meta wipe (docs/GAME_DESIGN.md) must also clear
    -- both gear slot lists, same as it already clears upgrades/ships.
    local wipeRun = expedition.new()
    assert(expedition.equipGear(wipeRun, "hull", climbCard))
    assert(expedition.equipGear(wipeRun, "engine", enginePart))
    expedition.launch(wipeRun)
    wipeRun.durability = 1
    assert(expedition.damage(wipeRun, 5))
    assert(wipeRun.phase == "destroyed")
    assert(#wipeRun.equippedGear == 0 and #wipeRun.equippedEngineParts == 0,
        "the durability-0 meta wipe must clear equipped hull and engine parts")
end

-- Item 10(b) follow-up: the propulsion-specialization (G) effect types
-- (fuelEfficiency/steeringResponsiveness/boostCharge) were only pure
-- gear.lua conversion functions until now -- never actually consumed by a
-- run. This wires them the same "최소한의 로더 호출" way item 9's climbSpeed
-- synergy and item 10's slot separation were already wired above.
local function testGearPropulsionRunWiring()
    local expedition = require("game.expedition")
    local enginePool = gear.loadEngineParts()

    -- fuelEfficiency: equipping engine_cryo_fuel_cell (fuelEfficiency +25)
    -- must reduce the effective burn rate used by launchForecast, so the
    -- same fuel tank forecasts a HIGHER altitude than with no engine parts.
    local fuelRun = expedition.new({ fuelBurnRate = 5, climbSpeed = 30 })
    local baselineAltitude = expedition.launchForecast(fuelRun)
    local cryoCard = gear.findById(enginePool, "engine_cryo_fuel_cell")
    assert(cryoCard, "fixture engine card 'engine_cryo_fuel_cell' must exist in the bundled pool")
    assert(expedition.equipGear(fuelRun, "engine", cryoCard))
    local boostedAltitude = expedition.launchForecast(fuelRun)
    assert(boostedAltitude > baselineAltitude,
        "equipped fuelEfficiency engine part must raise the launch forecast altitude: "
            .. tostring(baselineAltitude) .. " -> " .. tostring(boostedAltitude))
    assert(math.abs(expedition.effectiveFuelBurnRate(fuelRun) - fuelRun.fuelBurnRate * 0.75) < 1e-9,
        "effectiveFuelBurnRate must apply the equipped fuelEfficiency percentage")

    -- steeringResponsiveness: equipping engine_vector_nozzle
    -- (steeringResponsiveness +15) must raise expedition.steeringSpeed
    -- beyond the base/upgrade-only formula.
    local steerRun = expedition.new({ steeringSpeed = 55 })
    local baseSteering = expedition.steeringSpeed(steerRun)
    local vectorCard = gear.findById(enginePool, "engine_vector_nozzle")
    assert(vectorCard, "fixture engine card 'engine_vector_nozzle' must exist in the bundled pool")
    assert(expedition.equipGear(steerRun, "engine", vectorCard))
    local boostedSteering = expedition.steeringSpeed(steerRun)
    assert(boostedSteering > baseSteering,
        "equipped steeringResponsiveness engine part must raise steeringSpeed: "
            .. tostring(baseSteering) .. " -> " .. tostring(boostedSteering))
    assert(math.abs(boostedSteering - baseSteering * 1.15) < 1e-9,
        "steeringSpeed must apply the equipped steeringResponsiveness percentage")

    -- boostCharge: a fresh run with no engine parts must report zero
    -- charges; equipping engine_emergency_boost_pod (boostCharge +2) must
    -- expose that count via expedition.boostChargeCount.
    local boostRun = expedition.new()
    assert(expedition.boostChargeCount(boostRun) == 0,
        "a fresh run with no engine parts must have zero boost charges")
    local boostCard = gear.findById(enginePool, "engine_emergency_boost_pod")
    assert(boostCard, "fixture engine card 'engine_emergency_boost_pod' must exist in the bundled pool")
    assert(expedition.equipGear(boostRun, "engine", boostCard))
    assert(expedition.boostChargeCount(boostRun) == 2,
        "equipping engine_emergency_boost_pod must grant 2 boost charges")

    -- Sanity: none of these engine-part effects leak into the independent
    -- hull gear list (item 10's slot-independence guarantee still holds).
    assert(#boostRun.equippedGear == 0, "engine part effects must not touch the hull gear list")

    -- Item 10(b)/14(G) boostCharge CONSUMPTION gap: until this slice,
    -- boostChargeCount(run) was only ever a pure re-derived total (like
    -- rerollCount was before M.spendReroll existed) -- nothing could
    -- actually SPEND a "긴급 부스트/1회성 소모 아이템" charge and see the
    -- pool deplete, mirroring the exact gap item 14(C)'s rerollBonus had
    -- before M.rerollsRemaining/M.spendReroll closed it. A fresh run with
    -- the boost pod equipped must start with 2 remaining boosts (matching
    -- the equipped total), spending must decrement a per-expedition
    -- counter down to zero then refuse further spends (never negative,
    -- never throws), and re-launching must refill back to the current
    -- equipped total (same lifecycle as insuranceUsed/rerollsUsed).
    assert(expedition.boostsRemaining(boostRun) == 2,
        "a run with boostChargeCount == 2 must start with 2 remaining boost charges")
    local bOk1 = expedition.spendBoost(boostRun)
    assert(bOk1 == true, "spendBoost must succeed while boost charges remain")
    assert(expedition.boostsRemaining(boostRun) == 1,
        "spending one boost must decrement the remaining count by exactly one")
    local bOk2 = expedition.spendBoost(boostRun)
    assert(bOk2 == true, "spendBoost must succeed for the last remaining boost charge")
    assert(expedition.boostsRemaining(boostRun) == 0,
        "boostsRemaining must reach exactly zero once every boost charge is spent")
    local bOk3, bErr3 = expedition.spendBoost(boostRun)
    assert(bOk3 == false and type(bErr3) == "string",
        "spendBoost must refuse (false + message), not go negative, once boosts are exhausted")
    assert(expedition.boostsRemaining(boostRun) == 0,
        "a refused spendBoost call must not further decrement the remaining count")

    local bareBoostRun = expedition.new()
    assert(expedition.boostsRemaining(bareBoostRun) == 0,
        "an unequipped run must have zero remaining boost charges")
    local bareOk, bareErr = expedition.spendBoost(bareBoostRun)
    assert(bareOk == false and type(bareErr) == "string",
        "spendBoost must refuse (false + message) when no boost charges remain")

    boostRun.phase = "settlement"
    assert(expedition.launch(boostRun))
    assert(expedition.boostsRemaining(boostRun) == 2,
        "launching a new expedition must refill remaining boost charges back to the equipped boostChargeCount total")
end

-- Next slice within item 14: (D) insurance / (F) shopDiscount were only
-- pure gear.lua conversion functions (M.hasInsurance/M.effectiveShopPrice)
-- until now -- never actually consumed by a run's destroy()/shop-purchase
-- code paths. This wires them the same "최소한의 로더 호출" way item 9's
-- climbSpeed synergy and item 10(b)'s propulsion effects were already
-- wired above (game/expedition.lua only; play.lua/world.lua untouched).
local function testGearSurvivalAndEconomyWiring()
    local expedition = require("game.expedition")
    local hullPool = gear.loadHullParts()

    -- (D) insurance: an equipped hull_emergency_beacon (insurance +1) must
    -- survive a lethal hit ONCE without triggering the full meta wipe
    -- (money/ships/upgrades/best-height-preserving destroy()), then a
    -- SECOND lethal hit (insurance already spent) must destroy normally.
    local beaconCard = gear.findById(hullPool, "hull_emergency_beacon")
    assert(beaconCard, "fixture hull card 'hull_emergency_beacon' must exist in the bundled pool")
    local insuredRun = expedition.new({ durability = 2, money = 40 })
    assert(expedition.equipGear(insuredRun, "hull", beaconCard))
    expedition.launch(insuredRun)
    insuredRun.durability = 1

    local destroyedFirstHit = expedition.damage(insuredRun, 5)
    assert(destroyedFirstHit == false,
        "an equipped insurance part must prevent destruction on the first lethal hit")
    assert(insuredRun.phase == "ascending", "an insured survival must keep the run in its current phase")
    assert(insuredRun.durability > 0, "an insured survival must restore at least 1 durability")
    assert(insuredRun.money == 40, "an insured survival must NOT trigger the meta wipe (money must be untouched)")
    assert(#insuredRun.equippedGear == 1, "an insured survival must keep equipped gear (no meta wipe)")

    insuredRun.durability = 1
    local destroyedSecondHit = expedition.damage(insuredRun, 5)
    assert(destroyedSecondHit == true,
        "insurance is a one-time save; a second lethal hit must destroy normally")
    assert(insuredRun.phase == "destroyed")
    assert(insuredRun.money == 0, "the second (uninsured) destruction must still perform the full meta wipe")

    -- Without any insurance-carrying gear equipped, the very first lethal
    -- hit destroys normally (baseline unaffected by this wiring).
    local uninsuredRun = expedition.new({ durability = 1, money = 10 })
    expedition.launch(uninsuredRun)
    assert(expedition.damage(uninsuredRun, 5) == true,
        "a run with no insurance gear must destroy on the first lethal hit, same as before this slice")

    -- (F) shopDiscount: an equipped hull_trade_license (shopDiscount +20%)
    -- must reduce the money actually spent on a settlement-phase purchase
    -- by exactly 20%, while a run with no discount gear pays full price.
    local tradeCard = gear.findById(hullPool, "hull_trade_license")
    assert(tradeCard, "fixture hull card 'hull_trade_license' must exist in the bundled pool")
    local discountRun = expedition.new({ fuelUpgradeCost = 50, money = 50 })
    assert(expedition.equipGear(discountRun, "hull", tradeCard))
    discountRun.phase = "settlement"
    assert(expedition.shopPrice(discountRun, discountRun.fuelUpgradeCost) == 40,
        "shopPrice must apply the equipped shopDiscount percentage")
    assert(expedition.buyFuelUpgrade(discountRun),
        "a discounted purchase must still succeed at the reduced price")
    assert(discountRun.money == 10,
        "buying with an equipped shopDiscount card must charge the discounted price (50 - 40 = 10 left), got "
            .. tostring(discountRun.money))

    local fullPriceRun = expedition.new({ fuelUpgradeCost = 50, money = 50 })
    fullPriceRun.phase = "settlement"
    assert(expedition.buyFuelUpgrade(fullPriceRun))
    assert(fullPriceRun.money == 0,
        "a run with no shopDiscount gear must still pay the full base price, got " .. tostring(fullPriceRun.money))
end

-- Item 12's rarity/edition RNG (gear.rollRarity/gear.rollEdition) has
-- existed only as pure functions until now -- never actually called from a
-- run's shop/checkpoint drop path. This wires an explicit-roll offer
-- generator (M.rollGearOffer) into expedition.lua, same "최소한의 로더
-- 호출" exception already used for the other gear.lua/engine_parts.lua
-- wiring above (game/expedition.lua only; play.lua/world.lua untouched).
-- Callers still supply the actual roll numbers (shop/checkpoint code, out
-- of this lane's scope) so the selection stays deterministically testable.
local function testGearOfferRolling()
    local expedition = require("game.expedition")
    local hullPool = gear.loadHullParts()

    -- roll=0 must always pick the rarest-common tier deterministically
    -- (matches gear.rollRarity(0, 0) == "common"), and must return an
    -- actual card of that rarity from the given pool along with no edition
    -- when editionChanceRoll lands above the base chance.
    local baseRun = expedition.new()
    local commonOffer = expedition.rollGearOffer(baseRun, hullPool, {
        rarity = 0, pick = 0, editionChance = 0.99, editionPick = 0,
    })
    assert(commonOffer, "rollGearOffer must return a card for roll=0")
    assert(commonOffer.rarity == "common",
        "roll=0 with no luck must resolve to the common tier, got " .. tostring(commonOffer.rarity))
    assert(commonOffer.edition == nil,
        "an editionChanceRoll above the base chance must yield no edition")
    assert(type(commonOffer.effects) == "table" and #commonOffer.effects > 0,
        "a rolled offer must carry a concrete effects list")

    -- roll near 1 must resolve to the legendary tier (gear.rollRarity(0.999,
    -- 0) == "legendary"), and forcing editionChanceRoll=0 (below the base
    -- chance) on a card with a non-empty editions list must attach one.
    local editionCard = nil
    for _, part in ipairs(hullPool) do
        if #part.editions > 0 then editionCard = part end
    end
    assert(editionCard, "fixture pool must contain at least one card with editions for this test")
    local onlyEditionCardPool = { editionCard }
    local legendaryOffer = expedition.rollGearOffer(baseRun, onlyEditionCardPool, {
        rarity = 0.999, pick = 0, editionChance = 0, editionPick = 0,
    })
    assert(legendaryOffer, "rollGearOffer must return a card even for a single-card pool")
    assert(legendaryOffer.edition == editionCard.editions[1],
        "editionChanceRoll below the base chance must attach an edition from the card's own list")
    -- The edition's effect transform (gear.applyEditionEffects) must have
    -- actually been applied -- the offer's effects must differ from the
    -- card's raw, un-edition'd effects (unless the multiplier happens to be
    -- 1.0, which none of gear.editionEffects' entries are).
    local rawTotal, offerTotal = 0, 0
    for _, e in ipairs(editionCard.effects) do rawTotal = rawTotal + e.value end
    for _, e in ipairs(legendaryOffer.effects) do offerTotal = offerTotal + e.value end
    assert(rawTotal ~= offerTotal,
        "an attached edition must actually mutate the offer's effect values")

    -- Item 14(C) luck wiring: equipping a hull card with a positive `luck`
    -- effect must raise the probability that the SAME rarity roll resolves
    -- to a higher tier than it would with no luck at all (gear.rollRarity's
    -- luckBonus parameter, now actually sourced from equipped gear instead
    -- of a hand-supplied literal).
    local luckyRun = expedition.new()
    local luckCard = { id = "luck-fixture", tags = {}, editions = {},
        effects = { { type = "luck", value = 20 } } }
    assert(expedition.equipGear(luckyRun, "hull", { id = "luck-fixture", name = "Luck",
        nameKo = "Luck", icon = "*", rarity = "common", tags = {}, editions = {}, effects = luckCard.effects }))
    -- Pick a roll that lands in "uncommon" with zero luck but "rare" (or
    -- better) once the equipped luck bonus shifts the cumulative weights.
    local probeRoll = 0.8
    local noLuckRarity = gear.rollRarity(probeRoll, 0)
    local luckyOffer = expedition.rollGearOffer(luckyRun, hullPool, {
        rarity = probeRoll, pick = 0, editionChance = 0.99, editionPick = 0,
    })
    local rarityOrder = { common = 1, uncommon = 2, rare = 3, legendary = 4 }
    assert(rarityOrder[luckyOffer.rarity] >= rarityOrder[noLuckRarity],
        "equipped luck must never resolve a WORSE rarity tier than the unluck baseline for the same roll")
    assert(rarityOrder[luckyOffer.rarity] > rarityOrder[noLuckRarity],
        "equipped luck must resolve a strictly better rarity tier for this probe roll (baseline "
            .. tostring(noLuckRarity) .. ", got " .. tostring(luckyOffer.rarity) .. ")")

    -- An empty-rarity-tier pool (no cards of the resolved rarity available)
    -- must fall back to returning SOME card rather than nil/erroring, so
    -- callers never have to special-case "no offer this time" themselves.
    local commonOnlyPool = {}
    for _, part in ipairs(hullPool) do
        if part.rarity == "common" then commonOnlyPool[#commonOnlyPool + 1] = part end
    end
    assert(#commonOnlyPool > 0, "fixture pool must have at least one common card")
    local fallbackOffer = expedition.rollGearOffer(baseRun, commonOnlyPool, {
        rarity = 0.999, pick = 0, editionChance = 0.99, editionPick = 0,
    })
    assert(fallbackOffer, "rollGearOffer must fall back to an available card when the resolved rarity is empty")
end

-- Item 14 (C) chainTrigger/rerollBonus + (E) detectionRadius/autoCollect run
-- wiring: gear.chainTriggerCount/rerollCount/effectiveDetectionRadius/
-- autoCollectEnabled have existed as pure gear.lua conversion functions
-- since item 14's first slice, but until now no run-facing wrapper in
-- game/expedition.lua actually combined them with an equipped-gear list
-- (the same "최소한의 로더 호출" wiring pattern already used for climbSpeed
-- synergy/propulsion/insurance/shopDiscount/drop-RNG above). This closes
-- the last remaining gap named in docs/STATUS.md's "여전히 미착수" list.
local function testGearRunEffectWiring()
    local expedition = require("game.expedition")

    -- No gear equipped: all four must resolve to their documented
    -- zero/false/baseline defaults (regression safety, same shape as the
    -- insurance/boostCharge "no gear" baselines above).
    local bareRun = expedition.new()
    assert(expedition.chainTriggerCount(bareRun) == 0,
        "an unequipped run must have zero chain-trigger re-activations")
    assert(expedition.rerollCount(bareRun) == 0,
        "an unequipped run must have zero free rerolls")
    assert(math.abs(expedition.detectionRadius(bareRun, 20) - 20) < 1e-9,
        "an unequipped run's detection radius must equal the unmodified base radius")
    assert(expedition.autoCollectEnabled(bareRun) == false,
        "an unequipped run must not have auto-collect enabled")
    assert(expedition.rerollsRemaining(bareRun) == 0,
        "an unequipped run must have zero remaining free rerolls")
    local spent, err = expedition.spendReroll(bareRun)
    assert(spent == false and type(err) == "string",
        "spendReroll must refuse (false + message) when no free rerolls remain")

    -- Equip one hull card carrying all four (C)/(E) effect types at once
    -- and confirm the run-level wrappers combine gearModule's pure
    -- conversions with the actual equipped list (hull + engine slots are
    -- independent per item 10, so this also proves engine-only equips
    -- don't leak into hull totals or vice versa).
    local run = expedition.new()
    local comboCard = {
        id = "combo-fixture", name = "Combo", nameKo = "Combo", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = {
            { type = "chainTrigger", value = 1.9 },
            { type = "rerollBonus", value = 2.4 },
            { type = "detectionRadius", value = 50 },
            { type = "autoCollect", value = 1 },
        },
    }
    assert(expedition.equipGear(run, "hull", comboCard))
    assert(expedition.chainTriggerCount(run) == 1,
        "chainTrigger total must floor to a whole re-trigger count through the run wrapper")
    assert(expedition.rerollCount(run) == 2,
        "rerollBonus total must floor to a whole free-reroll count through the run wrapper")
    assert(math.abs(expedition.detectionRadius(run, 20) - 30) < 1e-9,
        "detectionRadius +50%% of base 20 must resolve to 30 through the run wrapper")
    assert(expedition.autoCollectEnabled(run) == true,
        "a positive autoCollect effect must enable auto-collect through the run wrapper")

    -- rerollBonus (item 14(C)) has, until this slice, only ever exposed a
    -- pure COUNT (rerollCount) with no run-state consumer -- unlike its (C)
    -- sibling luck (spent via gear.totalLuckBonus feeding rollRarity/
    -- rollEdition) or insurance (a one-shot boolean gate consumed by
    -- M.damage), a "free reroll count" is meaningless unless something can
    -- actually SPEND one. M.rerollsRemaining(run)/M.spendReroll(run) close
    -- that last (C) consumption gap: spending decrements a per-expedition
    -- counter (not the raw equipped total, which is re-derived from gear
    -- and would never deplete) down to zero, then refuses further spends.
    assert(expedition.rerollsRemaining(run) == 2,
        "a run with rerollBonus == 2 (floored) must start with 2 remaining free rerolls")
    local ok1 = expedition.spendReroll(run)
    assert(ok1 == true, "spendReroll must succeed while rerolls remain")
    assert(expedition.rerollsRemaining(run) == 1,
        "spending one reroll must decrement the remaining count by exactly one")
    local ok2 = expedition.spendReroll(run)
    assert(ok2 == true, "spendReroll must succeed for the last remaining reroll")
    assert(expedition.rerollsRemaining(run) == 0,
        "rerollsRemaining must reach exactly zero once every free reroll is spent")
    local ok3, err3 = expedition.spendReroll(run)
    assert(ok3 == false and type(err3) == "string",
        "spendReroll must refuse (false + message), not go negative, once rerolls are exhausted")
    assert(expedition.rerollsRemaining(run) == 0,
        "a refused spendReroll call must not further decrement the remaining count")

    -- Re-launching a fresh expedition must refill the remaining-reroll
    -- counter back up to the current equipped total (same "per-expedition
    -- resource" shape as run.insuranceUsed being reset on M.launch).
    run.phase = "settlement"
    assert(expedition.launch(run))
    assert(expedition.rerollsRemaining(run) == 2,
        "launching a new expedition must refill remaining rerolls back to the equipped rerollBonus total")

    -- Item 9/14 gap audit: gear.equippedTotals already computes a combined
    -- (A) sampleSellValue flat bonus + (B) sellMultiplier scaling (see the
    -- "sellA"/"sellB" fixture in testGearEffectSchemaExpansion), but until
    -- this slice NOTHING in expedition.lua ever read that total -- equipping
    -- 8 bundled sampleSellValue hull cards (or the sellMultiplier
    -- hull_market_broker card) had literally zero effect on the actual
    -- money a player earned from M.collectSample. This is item 9's core
    -- "combo synergy multiplies the payoff" promise for the ECONOMY stat,
    -- not just climbSpeed.
    local sellRun = expedition.new()
    local sellCard = {
        id = "sell-fixture", name = "Sell", nameKo = "Sell", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = {
            { type = "sampleSellValue", value = 10 },
            { type = "sellMultiplier", value = 50 },
        },
    }
    assert(expedition.equipGear(sellRun, "hull", sellCard))
    -- equippedTotals: flat sampleSellValue 10, sellMultiplier +50% ->
    -- combined bonus = 10 * 1.5 = 15.
    assert(math.abs(expedition.effectiveSampleBonus(sellRun) - 15) < 1e-9,
        "equipped sampleSellValue+sellMultiplier gear must resolve to a flat +15 sample bonus")
    sellRun.phase = "ascending"
    local sellOk, sellAwarded = expedition.collectSample(sellRun, 100)
    -- base 100 * sampleYieldMultiplier(1, no upgrade) * streakMultiplier(1,
    -- first collect) + gear bonus 15 = 115.
    assert(sellOk and sellAwarded == 115,
        "collectSample must add the equipped gear's flat sampleSellValue/sellMultiplier bonus: got " .. tostring(sellAwarded))

    -- An unequipped run must be a strict no-op (regression safety matching
    -- every other item 14 "no gear" baseline in this test).
    local bareSellRun = expedition.new()
    assert(expedition.effectiveSampleBonus(bareSellRun) == 0,
        "an unequipped run must have zero gear sample bonus")

    -- Engine-slot equips must feed the same wrappers too (item 10: hull and
    -- engine are independent slot lists, but both should count toward these
    -- run-wide totals, matching how boostChargeCount/effectiveFuelBurnRate
    -- already read only from equippedEngineParts and climbSpeed synergy
    -- only from equippedGear -- here (C)/(E) are gear-category-agnostic).
    local engineRun = expedition.new()
    local engineComboCard = {
        id = "engine-combo-fixture", name = "EngineCombo", nameKo = "EngineCombo", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "chainTrigger", value = 1 } },
    }
    assert(expedition.equipGear(engineRun, "engine", engineComboCard))
    assert(expedition.chainTriggerCount(engineRun) == 1,
        "chainTrigger effects on an engine-slot part must also count toward the run-wide total")
end

-- Item 14(D) collisionRadius run wiring: gear.effectiveCollisionRadius has
-- existed as a pure gear.lua conversion since item 14's first slice (same
-- (D) survival/risk-mitigation category as insurance, which was wired into
-- M.damage long ago), but unlike its sibling M.detectionRadius (item 14
-- (C)/(E) run wiring slice), expedition.lua never gained a run-facing
-- M.collisionRadius wrapper -- this was the last remaining item 14 gap.
local function testGearCollisionRadiusRunWiring()
    local expedition = require("game.expedition")

    -- No gear equipped: the run wrapper must return the base radius
    -- unmodified (same "unequipped == baseline" shape as every other
    -- gear run wrapper in this file).
    local bareRun = expedition.new()
    assert(math.abs(expedition.collisionRadius(bareRun, 10) - 10) < 1e-9,
        "an unequipped run's collision radius must equal the unmodified base radius")

    -- A hull card carrying collisionRadius must shrink the base radius
    -- through the run wrapper, matching gear.effectiveCollisionRadius's
    -- percentage-shrink formula exactly.
    local run = expedition.new()
    local shrinkCard = {
        id = "collision-fixture", name = "Collision", nameKo = "Collision", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "collisionRadius", value = 20 } },
    }
    assert(expedition.equipGear(run, "hull", shrinkCard))
    assert(math.abs(expedition.collisionRadius(run, 10) - 8) < 1e-9,
        "collisionRadius -20%% of base 10 must resolve to 8 through the run wrapper")

    -- Category-agnostic like the (C)/(E) wrappers: an ENGINE-slot card
    -- carrying collisionRadius must also count toward the total.
    local engineRun = expedition.new()
    local engineShrinkCard = {
        id = "engine-collision-fixture", name = "EngineCollision", nameKo = "EngineCollision", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "collisionRadius", value = 50 } },
    }
    assert(expedition.equipGear(engineRun, "engine", engineShrinkCard))
    assert(math.abs(expedition.collisionRadius(engineRun, 10) - 5) < 1e-9,
        "collisionRadius effects on an engine-slot part must also count toward the run-wide total")
end

-- Item 9/14 (A) hullDurability gap: gear.equippedTotals has additively
-- summed a part's hullDurability effect since item 14's very first slice,
-- and the bundled hull_parts.json pool has carried 9 hullDurability cards
-- (hull_scrap_plate, hull_titan_frame, etc.) since item 9's 24-card
-- expansion -- but refreshShipStats(run) (the ONLY place run.maxDurability
-- is (re)computed, on M.new/M.launch's meta-wipe/buyDurabilityUpgrade/
-- selectShip) never read gear.equippedTotals at all, so every one of those
-- 9 cards was equippable with zero actual effect on the ship's maximum
-- hull points -- the same "documented but silently dead" gap pattern this
-- lane's audit slices have repeatedly found and closed for
-- sampleSellValue/sellMultiplier, irradiated-synergy, noSlotCost, and
-- boostCharge consumption.
local function testGearHullDurabilityRunWiring()
    local expedition = require("game.expedition")

    -- No gear equipped: maxDurability must equal the unmodified
    -- base+ship+upgrade formula (regression baseline, matching every other
    -- gear run-wrapper's "unequipped == pre-wiring behavior" guarantee).
    local bareRun = expedition.new({ durability = 3 })
    assert(bareRun.maxDurability == 3,
        "an unequipped fresh run's maxDurability must equal its base durability 3, got "
            .. tostring(bareRun.maxDurability))

    -- Equipping a hull card with hullDurability +2 must raise maxDurability
    -- by exactly that amount immediately (refreshShipStats already runs
    -- synchronously inside M.new/M.launch/buyDurabilityUpgrade/selectShip;
    -- equipGear itself doesn't call it, so this asserts through launch,
    -- which is how a real playthrough would pick up new gear anyway).
    local durabilityCard = {
        id = "hull-durability-fixture", name = "Plating", nameKo = "Plating", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 2 } },
    }
    local run = expedition.new({ durability = 3 })
    assert(expedition.equipGear(run, "hull", durabilityCard))
    expedition.launch(run)
    assert(run.maxDurability == 5,
        "equipping a hullDurability +2 hull card must raise maxDurability from 3 to 5 through launch's "
            .. "refreshShipStats recompute, got " .. tostring(run.maxDurability))
    assert(run.durability == 5,
        "launch must also refill current durability to the new (gear-boosted) maxDurability, got "
            .. tostring(run.durability))

    -- Sanity: an ENGINE-slot card carrying hullDurability must NOT count --
    -- item 9 explicitly scopes hullDurability's use case to hull ("선체")
    -- parts (unlike the category-agnostic (C)/(E)/(D)-collisionRadius
    -- wrappers), so this stays hull-only like climbSpeed/sampleSellValue.
    local engineRun = expedition.new({ durability = 3 })
    local engineDurabilityCard = {
        id = "engine-durability-fixture", name = "EngineDur", nameKo = "EngineDur", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 2 } },
    }
    assert(expedition.equipGear(engineRun, "engine", engineDurabilityCard))
    expedition.launch(engineRun)
    assert(engineRun.maxDurability == 3,
        "hullDurability effects on an engine-slot part must NOT count toward maxDurability "
            .. "(item 9 scopes this stat to hull gear), got " .. tostring(engineRun.maxDurability))

    -- The durability upgrade axis and equipped gear must stack additively,
    -- not one replacing the other.
    local stackedRun = expedition.new({ durability = 3, durabilityUpgradeAmount = 1 })
    assert(expedition.equipGear(stackedRun, "hull", durabilityCard))
    stackedRun.phase = "settlement"
    stackedRun.money = 100
    assert(expedition.buyDurabilityUpgrade(stackedRun))
    assert(stackedRun.maxDurability == 6,
        "gear hullDurability (+2) and the durability upgrade (+1) must stack on top of base 3, got "
            .. tostring(stackedRun.maxDurability))
end

-- Item 9/14 (A) gap audit continued: `hullDurability` (previous slice) and
-- `sampleSellValue`/`sellMultiplier` (slice before that) were both found to
-- be validated-and-loaded but never actually READ by any run-state
-- function -- this lane's recurring "문서-코드 정합성 감사" pattern. The
-- original item 14 (A) list has five additive types
-- (speed/sampleSellValue/money/climbSpeed/hullDurability); climbSpeed,
-- sampleSellValue and hullDurability are now all wired, but `speed` (a hull
-- card's contribution to the ship's steering/maneuvering rate, distinct
-- from engine parts' percentage-based `steeringResponsiveness` (G)) has
-- never been read by `M.steeringSpeed(run)` -- every bundled `speed` hull
-- card (7 of them per docs/GEAR_SCHEMA.md/hull_parts.json) is equippable
-- but has zero effect on actual in-flight steering. This test closes that
-- gap the same way hullDurability closed its own: hull-scoped (matching
-- climbSpeed/sampleSellValue/hullDurability's hull-only design), additive
-- on top of the existing base+upgrade formula, stacking with (not
-- replacing) the engine-part percentage multiplier already applied.
local function testGearHullSpeedRunWiring()
    local expedition = require("game.expedition")

    -- No gear equipped: steeringSpeed must equal the unmodified pre-wiring
    -- base+upgrade formula (regression baseline).
    local bareRun = expedition.new({ baseSteeringSpeed = 55, steeringUpgradeLevel = 0 })
    local baseline = expedition.steeringSpeed(bareRun)
    assert(baseline == 55,
        "an unequipped fresh run's steeringSpeed must equal baseSteeringSpeed 55, got "
            .. tostring(baseline))

    -- Equipping a hull card with a `speed` effect must raise steeringSpeed
    -- by exactly that additive amount.
    local speedCard = {
        id = "hull-speed-fixture", name = "Thruster Fins", nameKo = "Thruster Fins", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "speed", value = 8 } },
    }
    local run = expedition.new({ baseSteeringSpeed = 55, steeringUpgradeLevel = 0 })
    assert(expedition.equipGear(run, "hull", speedCard))
    local boosted = expedition.steeringSpeed(run)
    assert(boosted == 63,
        "equipping a speed +8 hull card must raise steeringSpeed from 55 to 63, got "
            .. tostring(boosted))

    -- Sanity: an ENGINE-slot card carrying `speed` must NOT count -- item 9
    -- scopes this additive stat to hull parts (unlike the engine-only (G)
    -- `steeringResponsiveness` percentage effect it stacks alongside).
    local engineRun = expedition.new({ baseSteeringSpeed = 55, steeringUpgradeLevel = 0 })
    local engineSpeedCard = {
        id = "engine-speed-fixture", name = "EngineSpeed", nameKo = "EngineSpeed", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "speed", value = 8 } },
    }
    assert(expedition.equipGear(engineRun, "engine", engineSpeedCard))
    local engineResult = expedition.steeringSpeed(engineRun)
    assert(engineResult == 55,
        "speed effects on an engine-slot part must NOT count toward steeringSpeed "
            .. "(item 9 scopes this stat to hull gear), got " .. tostring(engineResult))

    -- Must stack additively with the existing engine-part percentage
    -- multiplier (gear.effectiveSteeringRate), not replace it: base 55 +
    -- hull speed 8 = 63, then engine steeringResponsiveness +50% -> 94.5.
    local stackedRun = expedition.new({ baseSteeringSpeed = 55, steeringUpgradeLevel = 0 })
    assert(expedition.equipGear(stackedRun, "hull", speedCard))
    local steeringPercentCard = {
        id = "engine-steering-fixture", name = "SteerBoost", nameKo = "SteerBoost", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "steeringResponsiveness", value = 50 } },
    }
    assert(expedition.equipGear(stackedRun, "engine", steeringPercentCard))
    local stacked = expedition.steeringSpeed(stackedRun)
    assert(math.abs(stacked - 94.5) < 0.001,
        "hull speed (+8, additive) and engine steeringResponsiveness (+50%, multiplicative) "
            .. "must both apply, expected 94.5, got " .. tostring(stacked))
end

-- Item 9/14 (A) `money` gap: gear.equippedTotals has additively summed a
-- part's `money` effect since item 14's very first slice, and the bundled
-- hull_parts.json pool has carried 3 `money` cards (hull_reserve_tank +2
-- more) since item 9's expansion (plus several engine_parts.json cards),
-- but until this slice NOTHING in expedition.lua ever read that total --
-- the very last of the original five (A) additive types
-- (speed/sampleSellValue/money/climbSpeed/hullDurability) named in item 14
-- to still be silently dead content, exactly matching the pattern already
-- found and closed for speed/hullDurability/sampleSellValue above. `money`
-- is a direct settlement payout bonus (not a per-sample or per-tick rate
-- like its siblings), so it is wired into `settle(run)` -- the single
-- place a run's `money` balance is credited for a completed expedition --
-- rather than into a per-frame/per-sample function like the others.
local function testGearMoneyRunWiring()
    local expedition = require("game.expedition")

    -- No gear equipped: settling a run with pending sample/slot value must
    -- credit exactly that payout, unmodified (regression baseline matching
    -- every other gear run-wrapper's "unequipped == pre-wiring behavior").
    local bareRun = expedition.new({ money = 0 })
    bareRun.phase = "returning"
    bareRun.pendingSampleValue = 40
    bareRun.pendingSlotReward = 10
    bareRun.altitude = 0
    expedition.update(bareRun, 0.001)
    assert(bareRun.money == 50,
        "an unequipped run's settlement payout must equal pending sample+slot value 50, got "
            .. tostring(bareRun.money))

    -- Equipping a hull card with a `money` effect must add that flat bonus
    -- on top of the sample/slot settlement payout, hull-only (matching
    -- climbSpeed/sampleSellValue/hullDurability/speed's hull-scoped design,
    -- since item 9 calls these the "선체(조커형)" combo payoff stats).
    local moneyCard = {
        id = "hull-money-fixture", name = "Cargo Broker", nameKo = "Cargo Broker", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "money", value = 15 } },
    }
    local run = expedition.new({ money = 0 })
    assert(expedition.equipGear(run, "hull", moneyCard))
    run.phase = "returning"
    run.pendingSampleValue = 40
    run.pendingSlotReward = 10
    run.altitude = 0
    expedition.update(run, 0.001)
    assert(run.money == 65,
        "a money +15 hull card must raise the settlement payout from 50 to 65, got "
            .. tostring(run.money))

    -- Sanity: an ENGINE-slot card carrying `money` must NOT count -- item 9
    -- scopes this additive stat to hull parts, matching `speed`.
    local engineRun = expedition.new({ money = 0 })
    local engineMoneyCard = {
        id = "engine-money-fixture", name = "EngineMoney", nameKo = "EngineMoney", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "money", value = 15 } },
    }
    assert(expedition.equipGear(engineRun, "engine", engineMoneyCard))
    engineRun.phase = "returning"
    engineRun.pendingSampleValue = 40
    engineRun.pendingSlotReward = 10
    engineRun.altitude = 0
    expedition.update(engineRun, 0.001)
    assert(engineRun.money == 50,
        "money effects on an engine-slot part must NOT count toward the settlement bonus "
            .. "(item 9 scopes this stat to hull gear), got " .. tostring(engineRun.money))
end

-- Item 14(B) streakMultiplier wiring: docs/GEAR_SCHEMA.md and item 14's
-- own text named this as "defined in the schema... but its consumer...
-- lives in gameplay code" -- a gap this test closes by verifying an
-- equipped streakMultiplier card actually raises expedition.streakMultiplier's
-- per-step growth rate above the base 0.2, and that collectSample's
-- returned multiplier reflects the boosted rate for a real run.
local function testGearStreakMultiplierWiring()
    local expedition = require("game.expedition")

    -- No gear equipped: base rate (0.2 per step) must be unchanged,
    -- matching the pre-item-14 hardcoded constant exactly.
    local bareRun = expedition.new()
    assert(math.abs(expedition.streakBonusPerStep(bareRun) - 0.2) < 1e-9,
        "an unequipped run's streak bonus per step must equal the base 0.2 rate")
    assert(math.abs(expedition.streakMultiplier(3, bareRun) - 1.4) < 1e-9,
        "an unequipped run's streakMultiplier(3) must match the pre-wiring baseline 1.4")
    -- Calling with no run argument at all (legacy 1-arg call site) must
    -- still fall back to the base rate rather than erroring.
    assert(math.abs(expedition.streakMultiplier(3) - 1.4) < 1e-9,
        "streakMultiplier must still work with no run argument (base rate fallback)")

    -- Equip the bundled hull_combo_matrix card (streakMultiplier +10,
    -- i.e. +10 percentage points per step) and confirm the per-step rate
    -- rises to 0.3 and streakMultiplier(3) rises accordingly (1 + 2*0.3 = 1.6,
    -- not the unboosted 1.4).
    local boostedRun = expedition.new()
    local comboCard = {
        id = "hull_combo_matrix", name = "Combo Matrix", nameKo = "콤보 매트릭스", icon = "▦",
        rarity = "rare", tags = { "economy", "control" }, editions = {},
        effects = { { type = "streakMultiplier", value = 10 } },
    }
    assert(expedition.equipGear(boostedRun, "hull", comboCard))
    assert(math.abs(expedition.streakBonusPerStep(boostedRun) - 0.3) < 1e-9,
        "an equipped +10 streakMultiplier card must raise the per-step rate to 0.3")
    assert(math.abs(expedition.streakMultiplier(3, boostedRun) - 1.6) < 1e-9,
        "streakMultiplier(3) with the boosted rate must be 1.6 (1 + 2*0.3), got "
            .. tostring(expedition.streakMultiplier(3, boostedRun)))

    -- An engine-slot streakMultiplier card must count too (item 14's (C)/(E)
    -- category-agnostic combinedGearList design applies equally to this
    -- (B) wiring, since streakMultiplier isn't restricted to hull cards
    -- in the schema).
    local engineBoostedRun = expedition.new()
    assert(expedition.equipGear(engineBoostedRun, "engine", comboCard))
    assert(math.abs(expedition.streakBonusPerStep(engineBoostedRun) - 0.3) < 1e-9,
        "an engine-slot streakMultiplier card must also raise the per-step rate")

    -- End-to-end through collectSample: three consecutive same-hue-family
    -- collections on the boosted run must return the boosted multiplier on
    -- the third call (mult grows 1.0 -> 1.3 -> 1.6).
    boostedRun.phase = "ascending"
    local ok1, _, mult1 = expedition.collectSample(boostedRun, 100, "azure")
    local ok2, _, mult2 = expedition.collectSample(boostedRun, 100, "azure")
    local ok3, _, mult3 = expedition.collectSample(boostedRun, 100, "azure")
    assert(ok1 and ok2 and ok3)
    assert(math.abs(mult1 - 1) < 1e-9)
    assert(math.abs(mult2 - 1.3) < 1e-9, "second same-family collect must use the boosted rate: got " .. tostring(mult2))
    assert(math.abs(mult3 - 1.6) < 1e-9, "third same-family collect must use the boosted rate: got " .. tostring(mult3))
end

-- Item 14 (C) chainTrigger consumption gap audit: expedition.chainTriggerCount
-- (above, testGearRunEffectWiring) has existed only as a stateless re-derived
-- COUNT since item 14's (C)/(E) run-wiring slice -- exactly the same "count
-- exists but nothing ever actually retriggers anything" gap this lane found
-- and closed for rerollBonus (M.spendReroll) and boostCharge (M.spendBoost).
-- Per item 14's own description ("특정 조건마다 다른 장착 카드 효과 재발동,
-- 발라트로 Blueprint/Brainstorm 컨셉"), chainTrigger's actual payoff is
-- re-applying a sample collection's value gain -- so this wires it into
-- M.collectSample: each point of chainTriggerCount(run) re-triggers the
-- collected sample's awarded value once more (awarded * (1 + retriggers)),
-- leaving the streak/sample-count bookkeeping (one collection event) intact.
local function testGearChainTriggerConsumptionWiring()
    local expedition = require("game.expedition")

    -- No gear equipped: chainTriggerCount == 0 must leave collectSample's
    -- awarded value completely unchanged (regression safety against the
    -- pre-wiring baseline computed from streak/yield alone).
    local bareRun = expedition.new()
    bareRun.phase = "ascending"
    local ok, awarded, _, retriggers = expedition.collectSample(bareRun, 100, "azure")
    assert(ok, "collectSample must succeed while ascending")
    assert(awarded == 100, "an unequipped run's awarded sample value must be unchanged, got " .. tostring(awarded))
    assert(retriggers == 0, "an unequipped run must report zero chain retriggers, got " .. tostring(retriggers))

    -- Equip a chainTrigger +1 card: the same base collection must now award
    -- double (1 base application + 1 retrigger), and collectSample must
    -- report the retrigger count actually applied.
    local run = expedition.new()
    run.phase = "ascending"
    local chainCard = {
        id = "chain-fixture", name = "Chain", nameKo = "Chain", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "chainTrigger", value = 1 } },
    }
    assert(expedition.equipGear(run, "hull", chainCard))
    local ok2, awarded2, _, retriggers2 = expedition.collectSample(run, 100, "azure")
    assert(ok2)
    assert(retriggers2 == 1, "a +1 chainTrigger card must report exactly one retrigger, got " .. tostring(retriggers2))
    assert(awarded2 == 200,
        "a +1 chainTrigger card must double the awarded sample value (1 base + 1 retrigger), got " .. tostring(awarded2))
    -- A retrigger must not create a second collection event: sampleCount
    -- still advances by exactly one per collectSample call.
    assert(run.sampleCount == 1, "chain-retriggering a sample must not double-count sampleCount, got " .. tostring(run.sampleCount))

    -- An engine-slot chainTrigger card must count too (category-agnostic,
    -- same combinedGearList design as the other (C)/(E) wrappers).
    local engineRun = expedition.new()
    engineRun.phase = "ascending"
    assert(expedition.equipGear(engineRun, "engine", chainCard))
    local ok3, awarded3 = expedition.collectSample(engineRun, 100, "azure")
    assert(ok3 and awarded3 == 200, "an engine-slot chainTrigger card must also double the awarded value, got " .. tostring(awarded3))
end

-- Item 9(c): "카드 획득... 과 교체가 잦아지는 루프를 설계한다." With a fixed
-- 6/3-slot loadout, M.sellGear is the swap-loop's release valve -- it frees
-- an equipped slot and refunds money in one atomic action, scaled by
-- gear.raritySellValue/editionSellBonus, restricted to the
-- settlement/shop phase so it can't be abused mid-flight.
local function testGearSlotSwapEconomyWiring()
    local expedition = require("game.expedition")

    -- gear.sellValue: rarity scales the refund, and an edition adds a flat
    -- premium on top of the base rarity value.
    assert(gear.sellValue({ rarity = "common" }) == 4)
    assert(gear.sellValue({ rarity = "uncommon" }) == 9)
    assert(gear.sellValue({ rarity = "rare" }) == 18)
    assert(gear.sellValue({ rarity = "legendary" }) == 40)
    assert(gear.sellValue({ rarity = "legendary", edition = "irradiated" }) == 46,
        "an edition-carrying legendary card must sell for base(40) + editionSellBonus(6)")
    -- Unknown/missing rarity falls back to the common tier instead of
    -- erroring (defensive, not schema validation).
    assert(gear.sellValue({}) == 4)

    -- Selling is only allowed during settlement -- attempting mid-flight
    -- must fail without moving money or touching the slot list.
    local flightRun = expedition.new({ money = 50 })
    local commonCard = {
        id = "hull_scrap_plate", name = "Scrap Plate", nameKo = "고철 장갑판", icon = "▭",
        rarity = "common", tags = { "defense" }, editions = {},
        effects = { { type = "hullDurability", value = 1 } },
    }
    assert(expedition.equipGear(flightRun, "hull", commonCard))
    flightRun.phase = "ascending"
    local flightOk, flightErr = expedition.sellGear(flightRun, "hull", "hull_scrap_plate")
    assert(not flightOk, "selling gear must be rejected outside the settlement phase")
    assert(flightErr and #flightErr > 0)
    assert(flightRun.money == 50, "a rejected sell must not change money")
    assert(#flightRun.equippedGear == 1, "a rejected sell must not remove the equipped card")

    -- During settlement, selling an equipped hull card must remove it AND
    -- credit exactly its sell value.
    local shopRun = expedition.new({ money = 20 })
    assert(expedition.equipGear(shopRun, "hull", commonCard))
    shopRun.phase = "settlement"
    local ok, value = expedition.sellGear(shopRun, "hull", "hull_scrap_plate")
    assert(ok, "selling an equipped hull card during settlement must succeed")
    assert(value == 4, "returned sell value must match gear.sellValue: got " .. tostring(value))
    assert(shopRun.money == 24, "money must increase by exactly the sell value: got " .. tostring(shopRun.money))
    assert(#shopRun.equippedGear == 0, "the sold card must be removed from the hull slot list")

    -- Selling an engine-slot card must not touch the hull list, matching
    -- item 10's slot-independence guarantee.
    local engineShopRun = expedition.new({ money = 0 })
    local rareEngineCard = {
        id = "engine_test_thruster", name = "Test Thruster", nameKo = "테스트 추진기", icon = "◬",
        rarity = "rare", tags = { "speed" }, editions = {},
        effects = { { type = "speed", value = 5 } },
    }
    assert(expedition.equipGear(engineShopRun, "hull", commonCard))
    assert(expedition.equipGear(engineShopRun, "engine", rareEngineCard))
    engineShopRun.phase = "settlement"
    local engineOk, engineValue = expedition.sellGear(engineShopRun, "engine", "engine_test_thruster")
    assert(engineOk and engineValue == 18)
    assert(#engineShopRun.equippedEngineParts == 0, "the sold engine card must be removed from the engine slot list")
    assert(#engineShopRun.equippedGear == 1, "selling an engine card must not affect the hull slot list")

    -- Selling an unequipped/unknown id must fail cleanly (no money change).
    local missRun = expedition.new({ money = 7 })
    missRun.phase = "settlement"
    local missOk, missErr = expedition.sellGear(missRun, "hull", "hull_does_not_exist")
    assert(not missOk and missErr)
    assert(missRun.money == 7)
end

-- Item 12's "irradiated" edition ("⚠️ 방사능처리(Irradiated) — 시너지 태그
-- 매칭 시 보너스 추가 증폭") has carried a pure conversion function,
-- gear.editionSynergyBonusAdd(editionId), since the item 12 slice -- but
-- item 9's actual synergy engine (gear.tagSynergyMultiplier/equippedTotals)
-- never once consulted it. A part's `edition` field was completely ignored
-- by the per-shared-tag-pair bonus math, so "irradiated"'s headline
-- gameplay promise (amplified synergy) was dead: equipping an irradiated
-- card produced the exact same multiplier as an un-edition'd one. This
-- closes that gap -- gear.tagSynergyMultiplier now adds
-- gear.editionSynergyBonusAdd(a.edition) + gear.editionSynergyBonusAdd(b.edition)
-- on top of the flat M.synergyBonusPerSharedPair for every shared-tag pair,
-- so an irradiated part contributes extra amplification to every synergy
-- pair it participates in (and two irradiated parts sharing a tag stack
-- both bonuses), while editions never create synergy out of thin air for
-- non-overlapping tags.
local function testGearIrradiatedSynergyBonusWiring()
    local baseA = { id = "synA", tags = { "altitude" }, edition = nil, effects = { { type = "climbSpeed", value = 4 } } }
    local baseB = { id = "synB", tags = { "altitude" }, edition = nil, effects = { { type = "climbSpeed", value = 8 } } }
    local baseline = gear.tagSynergyMultiplier({ baseA, baseB })

    local irradA = { id = "synA2", tags = { "altitude" }, edition = "irradiated", effects = { { type = "climbSpeed", value = 4 } } }
    local irradB = { id = "synB2", tags = { "altitude" }, edition = nil, effects = { { type = "climbSpeed", value = 8 } } }
    local boosted = gear.tagSynergyMultiplier({ irradA, irradB })
    assert(boosted > baseline,
        "an irradiated-edition part in a shared-tag pair must add extra synergy bonus beyond the plain per-pair amount, baseline="
            .. tostring(baseline) .. " boosted=" .. tostring(boosted))
    assert(math.abs(boosted - baseline - gear.editionSynergyBonusAdd("irradiated")) < 1e-9,
        "the extra bonus over baseline must equal exactly gear.editionSynergyBonusAdd('irradiated')")

    -- Editions only AMPLIFY existing synergy -- they must never create
    -- synergy out of thin air for parts with no shared tag at all.
    local loneIrrad = { id = "lone-irrad", tags = { "void" }, edition = "irradiated", effects = {} }
    local otherTag = { id = "other-tag", tags = { "economy" }, edition = nil, effects = {} }
    assert(gear.tagSynergyMultiplier({ loneIrrad, otherTag }) == 1,
        "an irradiated part must not create synergy when tags don't overlap")

    -- Two irradiated parts sharing a tag must stack BOTH of their synergy
    -- bonus contributions on top of the flat per-pair amount.
    local doubleIrradA = { id = "di-a", tags = { "ember" }, edition = "irradiated", effects = {} }
    local doubleIrradB = { id = "di-b", tags = { "ember" }, edition = "irradiated", effects = {} }
    local doubleBoosted = gear.tagSynergyMultiplier({ doubleIrradA, doubleIrradB })
    local expectedDouble = 1 + gear.synergyBonusPerSharedPair + 2 * gear.editionSynergyBonusAdd("irradiated")
    assert(math.abs(doubleBoosted - expectedDouble) < 1e-9,
        "two irradiated parts sharing a tag must stack both parts' synergy bonus additions, expected "
            .. tostring(expectedDouble) .. " got " .. tostring(doubleBoosted))
end

-- Item 12's "refined" edition reserves `noSlotCost = true` metadata (a
-- Balatro-Negative-style "슬롯을 소모하지 않음" concept) that had been
-- documented in docs/GEAR_SCHEMA.md/game/gear.lua's M.editionEffects table
-- since the item 12 slice but never actually consulted by any slot
-- bookkeeping -- a "refined" card occupied a slot exactly like a normal
-- one. This regression-checks the wiring that closes that gap:
-- gear.isNoSlotCost + engine_parts.equip/isFull.
local function testGearNoSlotCostEditionWiring()
    -- gear.isNoSlotCost is a pure predicate over an edition id.
    assert(gear.isNoSlotCost("refined") == true,
        "the 'refined' edition must be flagged noSlotCost per its M.editionEffects entry")
    assert(gear.isNoSlotCost("irradiated") == false,
        "editions without noSlotCost=true must resolve to false")
    assert(gear.isNoSlotCost(nil) == false, "no edition must resolve to false")

    local enginePartsModule = require("game.engine_parts")
    local loadout = enginePartsModule.newLoadout()

    -- Fill the hull category to its normal capacity (6) with plain,
    -- no-edition cards -- these DO consume slots as before.
    for i = 1, enginePartsModule.hullSlotCount do
        local ok = enginePartsModule.equip(loadout, "hull", {
            id = "hull_fixture_" .. i, name = "Fixture", nameKo = "픽스처", icon = "*",
            rarity = "common", edition = nil, tags = {}, editions = {},
            effects = { { type = "hullDurability", value = 1 } },
        })
        assert(ok, "filling the hull loadout to its normal capacity must succeed")
    end
    assert(enginePartsModule.isFull(loadout, "hull"),
        "the hull loadout must report full once occupiedSlotCount reaches hullSlotCount")

    -- A normal (non-refined) card must still be rejected once full --
    -- baseline behavior must be unchanged by this slice.
    local rejectOk, rejectErr = enginePartsModule.equip(loadout, "hull", {
        id = "hull_fixture_overflow", name = "Overflow", nameKo = "오버플로우", icon = "*",
        rarity = "common", edition = nil, tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 1 } },
    })
    assert(not rejectOk and rejectErr, "a normal card must still be rejected once the hull loadout is at capacity")

    -- A "refined"-edition card, however, must be equippable PAST capacity
    -- (item 12's noSlotCost concept), and must not itself count toward
    -- isFull for a SUBSEQUENT normal-card equip check.
    local refinedOk = enginePartsModule.equip(loadout, "hull", {
        id = "hull_fixture_refined", name = "Refined Fixture", nameKo = "정제된 픽스처", icon = "*",
        rarity = "common", edition = "refined", tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 0.5 } },
    })
    assert(refinedOk, "a noSlotCost (refined-edition) card must be equippable even when the loadout is otherwise full")
    assert(#loadout.hull == enginePartsModule.hullSlotCount + 1,
        "the refined card must actually be appended to the slot list")
    assert(enginePartsModule.isFull(loadout, "hull") == true,
        "isFull must still report full (unaffected by the extra noSlotCost card) since the 6 normal cards still occupy all 6 slots")

    -- Unequipping one normal card must free exactly one slot even with the
    -- refined card present, confirming occupiedSlotCount excludes it from
    -- the count in both directions.
    assert(enginePartsModule.unequip(loadout, "hull", "hull_fixture_1"))
    assert(not enginePartsModule.isFull(loadout, "hull"),
        "removing one normal card must make room for exactly one more normal card, refined card notwithstanding")
    local refillOk = enginePartsModule.equip(loadout, "hull", {
        id = "hull_fixture_refill", name = "Refill", nameKo = "리필", icon = "*",
        rarity = "common", edition = nil, tags = {}, editions = {},
        effects = { { type = "hullDurability", value = 1 } },
    })
    assert(refillOk, "a normal card must be able to re-fill the slot freed by unequipping")

    -- Engine-slot independence must be preserved: filling hull with a
    -- refined overflow card must not affect the engine category's
    -- capacity/fullness at all.
    assert(not enginePartsModule.isFull(loadout, "engine"),
        "hull-category noSlotCost bookkeeping must never leak into the independent engine category")
end

function M.run()
    require("game.i18n").setLocale("en")
    assert(viewport.width == 180 and viewport.height == 320)
    local scale, x, y = viewport.fit(720, 1280, false)
    assert(scale == 4 and x == 0 and y == 0)
    local gx, gy, inside = viewport.toGame(360, 640, 720, 1280, false)
    assert(gx == 90 and gy == 160 and inside)

    local ship = shipModule.new()
    shipModule.update(ship, 1, { thrust = true })
    assert(ship.y < 0 and ship.fuel < 100)
    local before = ship.angle
    shipModule.update(ship, 1, { right = true })
    assert(ship.angle > before)

    local a = world.planets(7, -3)
    local b = world.planets(7, -3)
    assert(#a == #b)
    for i = 1, #a do
        assert(a[i].id == b[i].id and a[i].x == b[i].x and a[i].y == b[i].y)
    end
    local sx, sy = world.sectorAt(-1, -193)
    assert(sx == -1 and sy == -2)
    assert(world.sampleValue({ y = -500 }) > world.sampleValue({ y = -50 }))
    assert(world.collisionDamage({ y = -499 }) == 1)
    assert(world.collisionDamage({ y = -500 }) == 2)
    assert(world.collisionDamage({ y = -1500 }) == 4)

    assert(world.sampleTier({ y = -50 }) == "common")
    assert(world.sampleTier({ y = -299 }) == "common")
    assert(world.sampleTier({ y = -300 }) == "rare")
    assert(world.sampleTier({ y = -799 }) == "rare")
    assert(world.sampleTier({ y = -800 }) == "epic")

    -- Specimen catalog (9 = 3 hue families x 3 tiers): every entry has a
    -- unique id, and specimenKind maps a planet to a stable id/label pair
    -- that matches the catalog exactly.
    local catalog = world.specimenCatalog()
    assert(#catalog == 9)
    local seenIds = {}
    for _, entry in ipairs(catalog) do
        assert(not seenIds[entry.id], "duplicate specimen id " .. entry.id)
        seenIds[entry.id] = true
    end
    local azureCommonId, azureCommonLabel = world.specimenKind({ hue = 0.1, y = -50 })
    assert(azureCommonId == "azure_common")
    assert(azureCommonLabel == "AZURE DUST")
    local emberRareId, emberRareLabel = world.specimenKind({ hue = 0.5, y = -500 })
    assert(emberRareId == "ember_rare")
    assert(emberRareLabel == "EMBER SHARD")
    local voidEpicId, voidEpicLabel = world.specimenKind({ hue = 0.9, y = -900 })
    assert(voidEpicId == "void_epic")
    assert(voidEpicLabel == "VOID CORE")
    assert(world.sampleTier({ y = -5000 }) == "epic")

    local commonR, commonG, commonB = PlayScene.sampleTierColor("common")
    local rareR, rareG, rareB = PlayScene.sampleTierColor("rare")
    local epicR, epicG, epicB = PlayScene.sampleTierColor("epic")
    assert(commonR and commonG and commonB)
    assert(rareR and rareG and rareB)
    assert(epicR and epicG and epicB)
    assert(commonR ~= rareR or commonG ~= rareG or commonB ~= rareB)
    assert(rareR ~= epicR or rareG ~= epicG or rareB ~= epicB)

    -- Balatro-style visual punch-up (2026-09-02 pending feedback): each
    -- sample tier gets a distinct particle-burst density and glow strength
    -- so common/rare/epic planets read as increasingly valuable at a
    -- glance, not just by ring color.
    local commonEffect = PlayScene.sampleTierEffect("common")
    local rareEffect = PlayScene.sampleTierEffect("rare")
    local epicEffect = PlayScene.sampleTierEffect("epic")
    assert(commonEffect.particleCount < rareEffect.particleCount
        and rareEffect.particleCount < epicEffect.particleCount,
        "particle density must increase common < rare < epic")
    assert(commonEffect.glowAlpha < rareEffect.glowAlpha
        and rareEffect.glowAlpha < epicEffect.glowAlpha,
        "glow intensity must increase common < rare < epic")

    local particleScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    assert(#particleScene.particles == 0)
    assert(particleScene.shipPunch == 0)
    particleScene:spawnSampleParticles(0, -500, "epic")
    assert(#particleScene.particles == PlayScene.sampleTierEffect("epic").particleCount,
        "spawnSampleParticles must create a tier-scaled particle burst")
    assert(particleScene.shipPunch == PlayScene.shipPunchDuration,
        "sample pickup must start a ship scale-punch")
    local firstParticle = particleScene.particles[1]
    particleScene:update(0.1)
    assert(math.abs(firstParticle.timer - 0.4) < 1e-9)
    assert(particleScene.shipPunch < PlayScene.shipPunchDuration and particleScene.shipPunch > 0)
    particleScene:update(1.0)
    assert(#particleScene.particles == 0, "expired particles must be removed")
    assert(particleScene.shipPunch == 0)

    -- Balatro-style twinkle/sparkle animation (2026-09-02 pending feedback,
    -- "너무 밋밋하다"): undiscovered planets should shimmer over time, with
    -- higher tiers sparkling faster, brighter and with more points so the
    -- card-like glow feels alive rather than a static ring.
    local commonSparkle = PlayScene.sampleTierSparkle("common")
    local rareSparkle = PlayScene.sampleTierSparkle("rare")
    local epicSparkle = PlayScene.sampleTierSparkle("epic")
    assert(commonSparkle.count < rareSparkle.count and rareSparkle.count < epicSparkle.count,
        "sparkle point count must increase common < rare < epic")
    assert(commonSparkle.speed < rareSparkle.speed and rareSparkle.speed < epicSparkle.speed,
        "sparkle animation speed must increase common < rare < epic")
    assert(commonSparkle.amplitude < rareSparkle.amplitude and rareSparkle.amplitude < epicSparkle.amplitude,
        "sparkle brightness swing must increase common < rare < epic")

    -- sparkleAlpha(tier, time, seed) must oscillate deterministically around
    -- the tier's base brightness so draw code can sample it every frame.
    local a0 = PlayScene.sparkleAlpha("epic", 0, 0)
    assert(math.abs(a0 - epicSparkle.base) < 1e-9, "sparkleAlpha at t=0,seed=0 must equal the tier base")
    local aQuarter = PlayScene.sparkleAlpha("epic", (math.pi / 2) / epicSparkle.speed, 0)
    assert(math.abs(aQuarter - (epicSparkle.base + epicSparkle.amplitude)) < 1e-6,
        "sparkleAlpha must peak at base+amplitude a quarter period in")
    assert(a0 >= 0 and a0 <= 1)

    -- PlayScene:update must accumulate elapsed time so draw can animate
    -- sparkles smoothly across frames instead of resetting each draw call.
    local sparkleScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    assert(sparkleScene.time == 0)
    sparkleScene:update(0.25)
    assert(math.abs(sparkleScene.time - 0.25) < 1e-9, "scene time must accumulate across update calls")
    sparkleScene:update(0.25)
    assert(math.abs(sparkleScene.time - 0.5) < 1e-9)

    -- Anticipation glow acceleration (INBOX 2026-09-02 후속 확정 사항 #6,
    -- "불확실성 속의 기대감"): as the ship closes in on an undiscovered
    -- planet's collection radius, the twinkle should visibly speed up so
    -- the player feels rising tension right before the sample is grabbed,
    -- instead of a constant-speed shimmer regardless of proximity.
    assert(PlayScene.sparkleAnticipationRange > 0)
    assert(PlayScene.sparkleAnticipationMaxMultiplier > 1,
        "anticipation multiplier must exceed 1x so the sparkle actually accelerates")
    local collectRadius = 14
    local atCollectEdge = PlayScene.sparkleAnticipationMultiplier(collectRadius, collectRadius)
    assert(math.abs(atCollectEdge - PlayScene.sparkleAnticipationMaxMultiplier) < 1e-9,
        "multiplier must peak at the collection radius edge")
    local farAway = PlayScene.sparkleAnticipationMultiplier(
        collectRadius + PlayScene.sparkleAnticipationRange + 50, collectRadius)
    assert(math.abs(farAway - 1) < 1e-9,
        "multiplier must settle to 1x once far outside the anticipation range")
    local midway = PlayScene.sparkleAnticipationMultiplier(
        collectRadius + PlayScene.sparkleAnticipationRange / 2, collectRadius)
    assert(midway > 1 and midway < PlayScene.sparkleAnticipationMaxMultiplier,
        "multiplier must interpolate strictly between 1x and the max inside the range")
    assert(midway > farAway and midway < atCollectEdge)
    local insideCollectRadius = PlayScene.sparkleAnticipationMultiplier(5, collectRadius)
    assert(math.abs(insideCollectRadius - PlayScene.sparkleAnticipationMaxMultiplier) < 1e-9,
        "multiplier must stay clamped at max once already inside the collection radius")

    -- Collision impact should trigger a brief ship shake so hits feel more
    -- physical, mirroring how the sample pickup triggers a scale-punch.
    local shakeScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    shakeScene.expedition.phase = "ascending"
    shakeScene.expedition.altitude = 500
    shakeScene.expedition.durability = 3
    shakeScene.ship.x = 0
    shakeScene.ship.y = -500
    assert(shakeScene.shipShake == 0)
    local shakeNearby = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "shake-test", x = 0, y = -500, radius = 7 } }
    end
    shakeScene:update(0)
    world.nearbyPlanets = shakeNearby
    assert(shakeScene.shipShake == PlayScene.shipShakeDuration,
        "planet collision must trigger a ship shake")

    -- Score-proportional screen shake (INBOX 2026-09-02 후속 확정 사항 #3):
    -- a collision with a higher sample-tier planet must feel bigger than a
    -- collision with a common one, so the shake magnitude scales with
    -- world.sampleTier(planet) the same way particle density/glow already
    -- do (common < rare < epic).
    local commonMagnitude = PlayScene.sampleTierShakeMultiplier("common")
    local rareMagnitude = PlayScene.sampleTierShakeMultiplier("rare")
    local epicMagnitude = PlayScene.sampleTierShakeMultiplier("epic")
    assert(commonMagnitude < rareMagnitude and rareMagnitude < epicMagnitude,
        "shake magnitude must increase common < rare < epic")
    assert(shakeScene.shipShakeMagnitude == rareMagnitude,
        "collision at height 500 (rare tier) must set shipShakeMagnitude to the rare multiplier")

    local commonShakeScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    commonShakeScene.expedition.phase = "ascending"
    commonShakeScene.expedition.altitude = 0
    commonShakeScene.expedition.durability = 3
    commonShakeScene.ship.x = 0
    commonShakeScene.ship.y = 0
    local commonNearby = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "shake-test-common", x = 0, y = 0, radius = 7 } }
    end
    commonShakeScene:update(0)
    world.nearbyPlanets = commonNearby
    assert(commonShakeScene.shipShakeMagnitude == commonMagnitude,
        "collision at height 0 (common tier) must set shipShakeMagnitude to the common multiplier")

    local riskScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    riskScene.expedition.phase = "ascending"
    riskScene.expedition.altitude = 500
    riskScene.expedition.durability = 3
    local warning = riskScene:collisionRisk({ y = -500 })
    assert(warning.damage == 2 and not warning.lethal and warning.label == "RISK -2")
    assert(warning.sampleValue == 35 and warning.sampleLabel == "SAMPLE $35")
    local lethalWarning = riskScene:collisionRisk({ y = -1000 })
    assert(lethalWarning.damage == 3 and lethalWarning.lethal and lethalWarning.label == "LETHAL -3")
    assert(lethalWarning.sampleValue == 60 and lethalWarning.sampleLabel == "SAMPLE $60")
    -- The SAMPLE YIELD upgrade multiplies the actual money awarded by
    -- expedition.collectSample (see collectSample's `awarded` return value
    -- and its use in PlayScene's floating "+$N" text), but the RISK/SAMPLE
    -- approach-warning preview label was still built directly from
    -- world.sampleValue(planet), ignoring the multiplier. That made the
    -- preview understate the real payout once a player owned any SAMPLE
    -- YIELD level, so it must also apply expedition.sampleYieldMultiplier.
    riskScene.expedition.sampleYieldUpgradeLevel = 1
    local yieldWarning = riskScene:collisionRisk({ y = -500 })
    assert(yieldWarning.sampleValue == 44 and yieldWarning.sampleLabel == "SAMPLE $44",
        "collisionRisk sampleValue/sampleLabel must apply the SAMPLE YIELD multiplier ("
            .. tostring(yieldWarning.sampleValue) .. " " .. tostring(yieldWarning.sampleLabel) .. ")")
    riskScene.expedition.sampleYieldUpgradeLevel = 0
    riskScene.expedition.phase = "returning"
    local returningPlanet = { id = "return-warning", y = -500 }
    local returningWarning = riskScene:approachWarning(returningPlanet, 205, 185)
    assert(returningWarning.damage == 2 and not returningWarning.lethal
        and returningWarning.label == "RISK -2")
    assert(returningWarning.sampleValue == nil and returningWarning.sampleLabel == nil)
    local returningLethalWarning = riskScene:approachWarning({ y = -1000 }, 205, 185)
    assert(returningLethalWarning.damage == 3 and returningLethalWarning.lethal
        and returningLethalWarning.label == "LETHAL -3")
    assert(riskScene:approachWarning(returningPlanet, 165, 185) == nil)
    riskScene.collided[returningPlanet.id] = true
    assert(riskScene:approachWarning(returningPlanet, 205, 185) == nil)
    riskScene.expedition.altitude = 725
    riskScene.expedition.returnDistance = 1000
    riskScene.expedition.returnSpeed = 45
    riskScene.expedition.sampleCount = 3
    riskScene.expedition.pendingSampleValue = 95
    local returningHud = riskScene:hudLines()
    assert(returningHud.samples == "SAMPLES 03  AT RISK $95")
    assert(returningHud.earth == "EARTH IN 725")
    assert(returningHud.returnProgress == "RETURN 28%  17s LEFT")
    -- docs/feedback/INBOX.md UI/HUD item 5: the small slot-odds line drawn
    -- above the minimap during the returning phase needs its own reserved
    -- vertical space in the HUD box (PlayScene.hudOddsLineHeight); without
    -- it, that line visually collided with the RETURN %%/s-left text right
    -- above it (confirmed via a real LÖVE runtime capture,
    -- GAME_CAPTURE_PHASE=returning-odds).
    assert(PlayScene.hudOddsLineHeight and PlayScene.hudOddsLineHeight > 0,
        "PlayScene.hudOddsLineHeight must exist and reserve room for the slot-odds line")
    assert(PlayScene.hudHeight("returning", returningHud, 0)
        == 70 + PlayScene.hudPrimaryStatusGap + PlayScene.hudOddsLineHeight,
        "returning HUD band height must grow by hudOddsLineHeight to fit the slot-odds line above the minimap")

    -- docs/feedback/INBOX.md UI/HUD item 4: the "개발 임시본"/"DEV PLACEHOLDER"
    -- footer is a permanent dev-only disclaimer, not gameplay info, so it
    -- must render smaller and dimmer than ordinary HUD text instead of
    -- competing with the message line above it (real LÖVE runtime capture
    -- previously showed it at full 14px default font and 0.85 alpha).
    assert(PlayScene.devPlaceholderFontSize and PlayScene.devPlaceholderFontSize < 14,
        "devPlaceholderFontSize must exist and be smaller than the default HUD font size")
    assert(PlayScene.devPlaceholderAlpha and PlayScene.devPlaceholderAlpha < 0.85,
        "devPlaceholderAlpha must exist and be dimmer than the previous 0.85 opacity")
    riskScene.expedition.altitude = 250
    assert(riskScene:hudLines().returnProgress == "RETURN 75%  6s LEFT")
    riskScene.expedition.phase = "settlement"
    -- Fuel is no longer a flight constraint (game/expedition.lua's
    -- M.maneuverFuel/M.burnManeuverFuel are no-ops), so the HUD status line
    -- no longer shows a "F%03d" fuel readout that implied a fuel cap still
    -- gated flight (docs/feedback/INBOX.md UI/HUD item 3).
    assert(riskScene:hudLines().status == "H3/3 SETTLE S00")
    assert(not riskScene:hudLines().status:find("F%d"),
        "hud status must not show a misleading fuel-cap readout")
    -- docs/feedback/INBOX.md UI/HUD item 4: during the launch phase the
    -- slot forecast (S%02d) is always 0 because no return trip has
    -- happened yet, so "LAUNCH S00" reads as confusing dead weight. Drop
    -- the slot segment for the launch phase only; every other phase
    -- (including SETTLE, asserted above) keeps showing it.
    riskScene.expedition.phase = "launch"
    assert(riskScene:hudLines().status == "H3/3 LAUNCH",
        "launch-phase status must omit the always-zero slot forecast: "
        .. tostring(riskScene:hudLines().status))
    assert(not riskScene:hudLines().status:find("S%d%d"),
        "launch-phase status must not show a slot count segment")
    riskScene.expedition.phase = "ascending"
    local ascendingHud = riskScene:hudLines()
    assert(ascendingHud.samples == "SAMPLES 03  AT RISK $95")
    -- "고도(ALT)" -> "거리(DIST)" relabel (docs/feedback/INBOX.md item 2,
    -- 2026-09-03): the user misread the ALT/CASH line + adjacent fuel
    -- status line as "fuel gates altitude". hud_distance must no longer say
    -- ALT, and drawing the status line must leave an explicit gap
    -- (PlayScene.hudPrimaryStatusGap) below the samples line so the fuel
    -- gauge visually separates from the distance-from-Earth readout.
    -- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
    -- third slice): the CASH readout gets a small coin icon paired with it,
    -- mirroring the shield icon added for hull durability. hudLines() must
    -- expose the DIST and CASH segments separately (instead of one combined
    -- "primary" string) so draw() can insert the coin icon between them.
    assert(ascendingHud.distance:match("^DIST %d") ~= nil,
        "hudLines().distance must read DIST: " .. tostring(ascendingHud.distance))
    assert(not ascendingHud.distance:find("ALT"),
        "hudLines().distance must not contain the old ALT label: "
        .. tostring(ascendingHud.distance))
    assert(ascendingHud.cash:match("^CASH %$%d") ~= nil,
        "hudLines().cash must read CASH $N: " .. tostring(ascendingHud.cash))
    assert(PlayScene.hudPrimaryStatusGap and PlayScene.hudPrimaryStatusGap > 0,
        "PlayScene.hudPrimaryStatusGap must exist and separate DIST/CASH from the fuel status line")
    assert(PlayScene.hudHeight("ascending", ascendingHud, 0)
        == 46 + PlayScene.hudPrimaryStatusGap,
        "ascending HUD band height must grow by hudPrimaryStatusGap to fit the added gap")
    assert(ascendingHud.earth == nil)
    assert(ascendingHud.returnProgress == nil)
    riskScene.expedition.altitude = 500
    riskScene.ship.y = -500
    local nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "risk-test", x = 0, y = -500, radius = 7 } }
    end
    assert(#riskScene.floatingTexts == 0)
    riskScene:update(0)
    world.nearbyPlanets = nearbyPlanets
    assert(riskScene.expedition.durability == 1)
    assert(riskScene.message == "COLLISION -2  HULL 1/3")
    local damageFloatingText
    for _, ft in ipairs(riskScene.floatingTexts) do
        if ft.kind == "damage" then damageFloatingText = ft end
    end
    assert(damageFloatingText)
    assert(damageFloatingText.text == "-2")
    -- Offset from ship.x (see play.lua's collision handling) so the damage
    -- text never renders stacked on top of a same-frame sample text.
    assert(damageFloatingText.x == riskScene.ship.x + 60)
    assert(damageFloatingText.y == riskScene.ship.y)

    assert(PlayScene.clampLabelX(90, 92, 180) == 44)
    assert(PlayScene.clampLabelX(178, 92, 180) == 86)
    assert(PlayScene.clampLabelX(2, 92, 180) == 2)
    assert(PlayScene.clampLabelX(90, 44, 180) == 68)

    local returnCollisionScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 750 end, save = function() return false end },
    })
    returnCollisionScene.expedition.phase = "settlement"
    returnCollisionScene.expedition.money = returnCollisionScene.expedition.fuelUpgradeCost
        + returnCollisionScene.expedition.durabilityUpgradeCost
        + returnCollisionScene.expedition.scoutShipCost + 25
    assert(expedition.buyFuelUpgrade(returnCollisionScene.expedition))
    assert(expedition.buyDurabilityUpgrade(returnCollisionScene.expedition))
    assert(expedition.buyShip(returnCollisionScene.expedition, "scout"))
    assert(expedition.selectShip(returnCollisionScene.expedition, "scout"))
    assert(expedition.launch(returnCollisionScene.expedition))
    returnCollisionScene.expedition.phase = "returning"
    returnCollisionScene.expedition.altitude = 500
    returnCollisionScene.expedition.returnDistance = 500
    returnCollisionScene.expedition.durability = 2
    returnCollisionScene.expedition.sampleCount = 2
    returnCollisionScene.expedition.pendingSampleValue = 80
    returnCollisionScene.expedition.slotOpportunities = 3
    returnCollisionScene.expedition.slotSpins = 1
    returnCollisionScene.expedition.pendingSlotReward = 75
    returnCollisionScene.expedition.lastSlotSymbols = { "STAR", "STAR", "STAR" }
    returnCollisionScene.expedition.lastSlotReward = 75
    returnCollisionScene.ship.y = -500
    nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "return-collision", x = 0, y = -500, radius = 7 } }
    end
    returnCollisionScene:update(0)
    world.nearbyPlanets = nearbyPlanets
    local wipedReturn = returnCollisionScene.expedition
    assert(wipedReturn.phase == "destroyed" and wipedReturn.durability == 0)
    assert(wipedReturn.money == 0 and wipedReturn.sampleCount == 0
        and wipedReturn.pendingSampleValue == 0 and wipedReturn.pendingSlotReward == 0)
    assert(wipedReturn.slotOpportunities == 0 and wipedReturn.slotSpins == 0
        and wipedReturn.lastSlotSymbols == nil and wipedReturn.lastSlotReward == 0)
    assert(wipedReturn.fuelUpgradeLevel == 0 and wipedReturn.durabilityUpgradeLevel == 0)
    assert(wipedReturn.selectedShipId == "starter" and not wipedReturn.ownedShips.scout)
    assert(wipedReturn.bestAltitude == 750)
    assert(returnCollisionScene.message == "SHIP DESTROYED  BEST 750  META RESET")
    assert(wipedReturn.lastLostSampleCount == 2 and wipedReturn.lastLostSampleValue == 80)
    assert(wipedReturn.lastLostSlotSpinsCount == 1 and wipedReturn.lastLostSlotValue == 75)
    assert(expedition.launch(wipedReturn))
    assert(wipedReturn.lastLostSampleCount == 0 and wipedReturn.lastLostSampleValue == 0)
    assert(wipedReturn.lastLostSlotSpinsCount == 0 and wipedReturn.lastLostSlotValue == 0)

    local basicSlotRolls = { 1, 6, 10, 6, 10, 1 }
    local nextBasicSlotRoll = 0
    local run = expedition.new({
        fuel = 2,
        fuelBurnRate = 1,
        climbSpeed = 60,
        returnSpeed = 50,
        slotDistance = 100,
        slotRandom = function()
            nextBasicSlotRoll = nextBasicSlotRoll + 1
            return basicSlotRolls[nextBasicSlotRoll]
        end,
    })
    assert(run.phase == "launch" and run.altitude == 0 and run.slotOpportunities == 0)
    assert(expedition.launch(run) and run.phase == "ascending")
    expedition.update(run, 1)
    assert(run.phase == "ascending" and run.fuel == 2 and run.altitude == 60)
    assert(expedition.collectSample(run, 75))
    assert(run.sampleCount == 1 and run.pendingSampleValue == 75 and run.money == 0)
    expedition.update(run, 1)
    assert(run.phase == "ascending" and run.fuel == 2 and run.altitude == 120)
    assert(expedition.beginReturn(run))
    assert(run.phase == "returning" and run.altitude == 120)
    assert(run.maxAltitude == 120 and run.returnDistance == 120 and run.slotOpportunities == 2)
    assert(expedition.useSlot(run) and run.slotOpportunities == 1 and run.slotSpins == 1)
    assert(expedition.useSlot(run) and run.slotOpportunities == 0 and run.slotSpins == 2)
    assert(not expedition.useSlot(run) and run.slotOpportunities == 0 and run.slotSpins == 2)
    expedition.update(run, 1)
    assert(run.phase == "returning" and run.altitude == 70)
    expedition.update(run, 2)
    assert(run.phase == "settlement" and run.altitude == 0)
    assert(run.money == 85 and run.lastSettlement == 85)
    assert(run.lastSampleSettlement == 75 and run.lastSlotSettlement == 10)
    assert(run.sampleCount == 0 and run.pendingSampleValue == 0 and run.pendingSlotReward == 0)
    assert(run.lastSampleCount == 1 and run.lastSlotSpinsCount == 2)
    assert(run.lastAltitude == 120)
    assert(run.lastNewBest == true)
    expedition.update(run, 1)
    assert(run.money == 85 and run.lastSettlement == 85)
    assert(run.lastSampleSettlement == 75 and run.lastSlotSettlement == 10)
    assert(run.lastAltitude == 120)
    assert(run.lastNewBest == true)
    assert(expedition.launch(run) and run.lastSampleCount == 0 and run.lastSlotSpinsCount == 0)
    assert(run.lastAltitude == 0)

    local lowerRun = expedition.new({ bestAltitude = 500 })
    lowerRun.phase = "returning"
    lowerRun.altitude = 5
    lowerRun.maxAltitude = 300
    lowerRun.returnSpeed = 10
    expedition.update(lowerRun, 1)
    assert(lowerRun.phase == "settlement" and lowerRun.lastAltitude == 300)
    assert(lowerRun.lastNewBest == false)
    assert(lowerRun.bestAltitude == 500)

    local slotRolls = { 10, 10, 10, 1, 1, 6, 10, 10, 10 }
    local nextSlotRoll = 0
    local slotRun = expedition.new({
        returnSpeed = 100,
        slotRandom = function()
            nextSlotRoll = nextSlotRoll + 1
            return slotRolls[nextSlotRoll]
        end,
    })
    slotRun.phase = "returning"
    slotRun.altitude = 10
    slotRun.slotOpportunities = 2
    slotRun.pendingSampleValue = 40
    assert(expedition.useSlot(slotRun))
    assert(table.concat(slotRun.lastSlotSymbols, "-") == "STAR-STAR-STAR")
    assert(slotRun.lastSlotReward == 75 and slotRun.pendingSlotReward == 75)
    assert(expedition.useSlot(slotRun))
    assert(table.concat(slotRun.lastSlotSymbols, "-") == "COMET-COMET-PLANET")
    assert(slotRun.lastSlotReward == 15 and slotRun.pendingSlotReward == 90)
    expedition.update(slotRun, 1)
    assert(slotRun.phase == "settlement" and slotRun.money == 130 and slotRun.lastSettlement == 130)
    assert(slotRun.lastSampleSettlement == 40 and slotRun.lastSlotSettlement == 90)
    assert(slotRun.pendingSlotReward == 0 and slotRun.lastSlotReward == 15)
    assert(expedition.launch(slotRun))
    assert(slotRun.lastSampleSettlement == 0 and slotRun.lastSlotSettlement == 0)
    slotRun.phase = "returning"
    slotRun.slotOpportunities = 1
    assert(expedition.useSlot(slotRun) and slotRun.pendingSlotReward == 75)
    assert(expedition.damage(slotRun, slotRun.durability))
    assert(slotRun.phase == "destroyed" and slotRun.money == 0 and slotRun.pendingSlotReward == 0)
    assert(slotRun.lastSampleSettlement == 0 and slotRun.lastSlotSettlement == 0)
    assert(slotRun.lastSlotSymbols == nil and slotRun.lastSlotReward == 0)

    local shopRun = expedition.new({
        fuel = 10,
        fuelUpgradeAmount = 5,
        fuelUpgradeCost = 50,
        money = 75,
    })
    assert(not expedition.buyFuelUpgrade(shopRun))
    shopRun.phase = "settlement"
    assert(expedition.buyFuelUpgrade(shopRun))
    assert(shopRun.money == 25 and shopRun.fuelUpgradeLevel == 1 and shopRun.maxFuel == 15)
    assert(not expedition.buyFuelUpgrade(shopRun))
    shopRun.maxAltitude = 120
    assert(expedition.launch(shopRun) and shopRun.phase == "ascending")
    assert(shopRun.fuel == 15 and shopRun.altitude == 0 and shopRun.maxAltitude == 0 and shopRun.lastSettlement == 0)

    local hullShopRun = expedition.new({
        durability = 2,
        durabilityUpgradeCost = 60,
        money = 85,
    })
    assert(not expedition.buyDurabilityUpgrade(hullShopRun))
    hullShopRun.phase = "settlement"
    assert(expedition.buyDurabilityUpgrade(hullShopRun))
    assert(hullShopRun.money == 25 and hullShopRun.durabilityUpgradeLevel == 1 and hullShopRun.maxDurability == 3)
    assert(not expedition.buyDurabilityUpgrade(hullShopRun))
    assert(expedition.launch(hullShopRun) and hullShopRun.phase == "ascending")
    assert(hullShopRun.durability == 3)

    local yieldRun = expedition.new({
        sampleYieldUpgradeCost = 60,
        sampleYieldUpgradeAmount = 0.25,
        money = 45,
    })
    assert(not expedition.buySampleYieldUpgrade(yieldRun))
    yieldRun.phase = "settlement"
    assert(not expedition.buySampleYieldUpgrade(yieldRun))
    yieldRun.money = 60
    assert(expedition.buySampleYieldUpgrade(yieldRun))
    assert(yieldRun.money == 0 and yieldRun.sampleYieldUpgradeLevel == 1)
    assert(expedition.sampleYieldMultiplier(yieldRun) == 1.25)
    assert(expedition.launch(yieldRun) and yieldRun.phase == "ascending")
    local ok, awarded = expedition.collectSample(yieldRun, 20)
    assert(ok and awarded == 25 and yieldRun.pendingSampleValue == 25 and yieldRun.sampleCount == 1)
    assert(expedition.damage(yieldRun, yieldRun.durability))
    assert(yieldRun.phase == "destroyed" and yieldRun.sampleYieldUpgradeLevel == 0)
    assert(expedition.sampleYieldMultiplier(yieldRun) == 1)

    -- docs/feedback/INBOX.md's Balatro core-mechanics porting plan item 1
    -- ("점진적 시너지/빌드업") asks for a multiplicative STREAK bonus when the
    -- player collects consecutive same-hue-family samples. collectSample's
    -- optional third argument is the hueKey (game/world.lua's
    -- specimenKind/hueFamily); consecutive calls with the same hueKey should
    -- grow the streak multiplier (x1.0, x1.2, x1.4, ...), and a different
    -- hueKey (or no hueKey) should reset the streak back to x1.0.
    local streakRun = expedition.new({})
    streakRun.phase = "ascending"
    assert(expedition.streakMultiplier(0) == 1)
    assert(expedition.streakMultiplier(1) == 1)
    assert(expedition.streakMultiplier(2) == 1.2)
    assert(expedition.streakMultiplier(3) == 1.4)
    local ok1, awarded1, mult1 = expedition.collectSample(streakRun, 100, "azure")
    assert(ok1 and awarded1 == 100 and mult1 == 1,
        "first azure sample must award base value at x1.0 streak (" .. tostring(awarded1) .. ")")
    local ok2, awarded2, mult2 = expedition.collectSample(streakRun, 100, "azure")
    assert(ok2 and awarded2 == 120 and mult2 == 1.2,
        "second consecutive azure sample must award x1.2 streak (" .. tostring(awarded2) .. ")")
    local ok3, awarded3, mult3 = expedition.collectSample(streakRun, 100, "azure")
    assert(ok3 and awarded3 == 140 and mult3 == 1.4,
        "third consecutive azure sample must award x1.4 streak (" .. tostring(awarded3) .. ")")
    local ok4, awarded4, mult4 = expedition.collectSample(streakRun, 100, "ember")
    assert(ok4 and awarded4 == 100 and mult4 == 1,
        "switching hue family must reset the streak back to x1.0 (" .. tostring(awarded4) .. ")")
    assert(streakRun.pendingSampleValue == 100 + 120 + 140 + 100
        and streakRun.sampleCount == 4)
    assert(expedition.damage(streakRun, streakRun.durability))
    assert(streakRun.phase == "destroyed" and streakRun.sampleStreakCount == 0
        and streakRun.sampleStreakFamily == nil)
    assert(expedition.launch(streakRun) and streakRun.phase == "ascending")
    assert(streakRun.sampleStreakCount == 0 and streakRun.sampleStreakFamily == nil)

    -- GAME_DESIGN.md's meta loop lists four upgrade axes ("연료·내구도·조종·
    -- 표본 수익을 강화": fuel, hull, steering, sample yield), but only three
    -- (fuel/hull/sample yield) existed until now. STEERING is the missing
    -- fourth axis: it scales the ship's left/right steering speed used
    -- during ascending/returning, giving players a fourth strategic EARTH
    -- SHOP purchase that improves planet-collision avoidance rather than
    -- capacity or money yield.
    local steeringRun = expedition.new({
        steeringUpgradeCost = 65,
        steeringUpgradeAmount = 15,
        money = 40,
    })
    assert(expedition.steeringSpeed(steeringRun) == 55)
    assert(not expedition.buySteeringUpgrade(steeringRun))
    steeringRun.phase = "settlement"
    assert(not expedition.buySteeringUpgrade(steeringRun))
    steeringRun.money = 65
    assert(expedition.buySteeringUpgrade(steeringRun))
    assert(steeringRun.money == 0 and steeringRun.steeringUpgradeLevel == 1)
    assert(expedition.steeringSpeed(steeringRun) == 70)
    assert(expedition.launch(steeringRun) and steeringRun.phase == "ascending")
    assert(expedition.steeringSpeed(steeringRun) == 70,
        "steering upgrade must persist across relaunch like fuel/hull upgrades")
    assert(expedition.damage(steeringRun, steeringRun.durability))
    assert(steeringRun.phase == "destroyed" and steeringRun.steeringUpgradeLevel == 0)
    assert(expedition.steeringSpeed(steeringRun) == 55,
        "steering upgrade must reset to base speed on destruction like the other upgrades")

    local steeringMoveScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    steeringMoveScene.expedition.phase = "ascending"
    steeringMoveScene.expedition.steeringUpgradeLevel = 1
    steeringMoveScene.touches["upgraded-steer"] = { x = 160, y = 10 }
    local shipXBefore = steeringMoveScene.ship.x
    steeringMoveScene:update(1)
    assert(math.abs(steeringMoveScene.ship.x - shipXBefore - 70) < 1e-9,
        "ascending steering must move the ship at expedition.steeringSpeed(run), not a fixed constant ("
            .. tostring(steeringMoveScene.ship.x - shipXBefore) .. ")")

    local steeringShopScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    steeringShopScene.expedition.phase = "settlement"
    steeringShopScene.expedition.money = steeringShopScene.expedition.steeringUpgradeCost
    steeringShopScene:keypressed("g")
    assert(steeringShopScene.expedition.steeringUpgradeLevel == 1,
        "keypressed('g') in settlement must purchase the STEERING upgrade")
    assert(steeringShopScene.expedition.money == 0)
    steeringShopScene:keypressed("g")
    assert(steeringShopScene.expedition.steeringUpgradeLevel == 1,
        "a second STEERING purchase attempt without enough money must fail")

    local shipShopRun = expedition.new({
        fuel = 10,
        durability = 3,
        scoutShipCost = 90,
        scoutFuelBonus = 5,
        scoutDurabilityBonus = -1,
        money = 100,
    })
    assert(not expedition.buyShip(shipShopRun, "scout"))
    shipShopRun.phase = "settlement"
    assert(expedition.buyShip(shipShopRun, "scout"))
    assert(shipShopRun.money == 10 and shipShopRun.ownedShips.scout)
    assert(shipShopRun.selectedShipId == "starter")
    assert(not expedition.buyShip(shipShopRun, "scout") and shipShopRun.money == 10)
    assert(expedition.selectShip(shipShopRun, "scout"))
    assert(shipShopRun.selectedShipId == "scout")
    assert(shipShopRun.maxFuel == 15 and shipShopRun.maxDurability == 2)
    assert(expedition.launch(shipShopRun) and shipShopRun.fuel == 15 and shipShopRun.durability == 2)
    assert(not expedition.damage(shipShopRun, 1))
    assert(expedition.damage(shipShopRun, 1))
    assert(shipShopRun.phase == "destroyed")
    assert(shipShopRun.selectedShipId == "starter" and shipShopRun.ownedShips.starter)
    assert(not shipShopRun.ownedShips.scout)
    assert(shipShopRun.maxFuel == 10 and shipShopRun.maxDurability == 3)

    local shopScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    shopScene.expedition.phase = "settlement"
    shopScene.expedition.money = shopScene.expedition.fuelUpgradeCost + 30
    shopScene:keypressed("f")
    assert(shopScene.expedition.fuelUpgradeLevel == 1 and shopScene.expedition.maxFuel == 120)
    assert(shopScene.expedition.money == 30)
    assert(shopScene.message
        == "FUEL TANK UPGRADED  LV.1  MAX 120  REACH 720  SLOTS 8  BALANCE $30")
    shopScene.expedition.money = shopScene.expedition.durabilityUpgradeCost + 10
    shopScene:keypressed("h")
    assert(shopScene.expedition.durabilityUpgradeLevel == 1 and shopScene.expedition.maxDurability == 4)
    assert(shopScene.expedition.money == 10)
    assert(shopScene.message
        == "HULL UPGRADED  LV.1  HULL 4  REACH 720  SLOTS 8  BALANCE $10")
    shopScene.expedition.money = shopScene.expedition.sampleYieldUpgradeCost + 15
    shopScene:keypressed("y")
    assert(shopScene.expedition.sampleYieldUpgradeLevel == 1)
    assert(shopScene.expedition.money == 15)
    assert(shopScene.message == "SAMPLE YIELD UPGRADED  LV.1  x1.25  BALANCE $15")
    shopScene.expedition.money = 0
    shopScene:keypressed("y")
    assert(shopScene.expedition.sampleYieldUpgradeLevel == 1)
    assert(shopScene.message == string.format("NEED $%d MORE FOR SAMPLE YIELD UPGRADE",
        shopScene.expedition.sampleYieldUpgradeCost))
    shopScene.expedition.money = shopScene.expedition.scoutShipCost + 20
    shopScene:touchpressed("ship", 90, 244)
    assert(shopScene.expedition.ownedShips.scout and shopScene.expedition.selectedShipId == "scout")
    assert(shopScene.expedition.money == 20)
    assert(shopScene.message
        == "SCOUT PURCHASED AND SELECTED  HULL 3  REACH 960  SLOTS 10  BALANCE $20")

    local scoutFuelMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scoutFuelMessageScene.expedition.phase = "settlement"
    scoutFuelMessageScene.expedition.money = scoutFuelMessageScene.expedition.scoutShipCost
        + scoutFuelMessageScene.expedition.fuelUpgradeCost + 20
    scoutFuelMessageScene:keypressed("v")
    assert(scoutFuelMessageScene.expedition.selectedShipId == "scout")
    scoutFuelMessageScene:keypressed("f")
    assert(scoutFuelMessageScene.expedition.fuelUpgradeLevel == 1
        and scoutFuelMessageScene.expedition.maxFuel == 160)
    assert(scoutFuelMessageScene.expedition.money == 20)
    assert(scoutFuelMessageScene.message
        == "FUEL TANK UPGRADED  LV.1  MAX 160  REACH 960  SLOTS 10  BALANCE $20")

    local scoutHullMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scoutHullMessageScene.expedition.phase = "settlement"
    scoutHullMessageScene.expedition.money = scoutHullMessageScene.expedition.scoutShipCost
        + scoutHullMessageScene.expedition.durabilityUpgradeCost + 20
    scoutHullMessageScene:keypressed("v")
    assert(scoutHullMessageScene.expedition.selectedShipId == "scout")
    scoutHullMessageScene:keypressed("h")
    assert(scoutHullMessageScene.expedition.durabilityUpgradeLevel == 1
        and scoutHullMessageScene.expedition.maxDurability == 3)
    assert(scoutHullMessageScene.expedition.money == 20)
    assert(scoutHullMessageScene.message
        == "HULL UPGRADED  LV.1  HULL 3  REACH 840  SLOTS 9  BALANCE $20")

    local repeatedUpgradeMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    repeatedUpgradeMessageScene.expedition.phase = "settlement"
    repeatedUpgradeMessageScene.expedition.money = 250
    repeatedUpgradeMessageScene:keypressed("f")
    repeatedUpgradeMessageScene:keypressed("f")
    assert(repeatedUpgradeMessageScene.message
        == "FUEL TANK UPGRADED  LV.2  MAX 140  REACH 840  SLOTS 9  BALANCE $150")
    repeatedUpgradeMessageScene:keypressed("h")
    repeatedUpgradeMessageScene:keypressed("h")
    assert(repeatedUpgradeMessageScene.message
        == "HULL UPGRADED  LV.2  HULL 5  REACH 840  SLOTS 9  BALANCE $0")

    local shortfallScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    shortfallScene.expedition.phase = "settlement"
    shortfallScene.expedition.money = 20
    shortfallScene:keypressed("f")
    assert(shortfallScene.expedition.fuelUpgradeLevel == 0)
    assert(shortfallScene.message == "NEED $30 MORE FOR FUEL UPGRADE")
    shortfallScene:keypressed("h")
    assert(shortfallScene.expedition.durabilityUpgradeLevel == 0)
    assert(shortfallScene.message == "NEED $55 MORE FOR HULL UPGRADE")
    shortfallScene:touchpressed("ship", 90, 244)
    assert(not shortfallScene.expedition.ownedShips.scout)
    assert(shortfallScene.message == "NEED $105 MORE FOR SCOUT")

    local touchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    touchScene:touchpressed("launch", 90, 280)
    assert(touchScene.expedition.phase == "ascending")
    local idleAscendSteering = touchScene:steeringButtonState()
    assert(not idleAscendSteering.leftActive and not idleAscendSteering.rightActive)
    touchScene:touchpressed("steer-left", 20, 160)
    local leftAscendSteering = touchScene:steeringButtonState()
    assert(leftAscendSteering.leftActive and not leftAscendSteering.rightActive)
    touchScene:update(1)
    assert(touchScene.ship.x == -55)
    touchScene:touchreleased("steer-left")
    local releasedAscendSteering = touchScene:steeringButtonState()
    assert(not releasedAscendSteering.leftActive and not releasedAscendSteering.rightActive)
    touchScene:update(1)
    touchScene:touchpressed("steer-right", 160, 160)
    local rightAscendSteering = touchScene:steeringButtonState()
    assert(not rightAscendSteering.leftActive and rightAscendSteering.rightActive)
    local xBeforeRight = touchScene.ship.x
    touchScene:update(1)
    assert(touchScene.ship.x > xBeforeRight,
        "holding right must still increase ship.x while main thrust follows heading")
    touchScene:touchreleased("steer-right")
    touchScene.expedition.phase = "returning"
    touchScene.expedition.altitude = 500
    touchScene.expedition.returnDistance = 500
    touchScene.expedition.returnSpeed = 0
    touchScene.expedition.slotOpportunities = 2
    touchScene.expedition.slotRandom = function() return 10 end
    local returnStartX = touchScene.ship.x
    nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function() return {} end
    local idleReturnSteering = touchScene:steeringButtonState()
    assert(not idleReturnSteering.leftActive and not idleReturnSteering.rightActive)
    touchScene:touchpressed("return-left", 20, 266)
    local leftReturnSteering = touchScene:steeringButtonState()
    assert(leftReturnSteering.leftActive and not leftReturnSteering.rightActive)
    assert(touchScene.expedition.slotSpins == 0 and touchScene.expedition.slotOpportunities == 2)
    touchScene:update(1)
    assert(touchScene.ship.x == returnStartX - 55)
    touchScene:touchreleased("return-left")
    local releasedReturnSteering = touchScene:steeringButtonState()
    assert(not releasedReturnSteering.leftActive and not releasedReturnSteering.rightActive)
    touchScene:update(1)
    assert(touchScene.ship.x == returnStartX - 55)
    touchScene:touchpressed("slot", 90, 266)
    assert(touchScene.expedition.slotSpins == 1 and touchScene.expedition.slotOpportunities == 1)
    local returnSteeredX = touchScene.ship.x
    touchScene:update(1)
    assert(touchScene.ship.x == returnSteeredX)
    touchScene:touchpressed("return-right", 160, 266)
    local rightReturnSteering = touchScene:steeringButtonState()
    assert(not rightReturnSteering.leftActive and rightReturnSteering.rightActive)
    assert(touchScene.expedition.slotSpins == 1 and touchScene.expedition.slotOpportunities == 1)
    touchScene:update(1)
    assert(touchScene.ship.x == returnSteeredX + 55)
    touchScene:touchreleased("return-right")
    world.nearbyPlanets = nearbyPlanets

    local returnAvoidanceScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    returnAvoidanceScene.expedition.phase = "returning"
    returnAvoidanceScene.expedition.altitude = 500
    returnAvoidanceScene.expedition.returnDistance = 500
    returnAvoidanceScene.ship.y = -500
    local avoidablePlanet = { id = "return-avoid", x = 0, y = -455, radius = 7 }
    nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function() return { avoidablePlanet } end
    returnAvoidanceScene:touchpressed("avoid-left", 20, 266)
    returnAvoidanceScene:update(1)
    world.nearbyPlanets = nearbyPlanets
    assert(returnAvoidanceScene.ship.x == -55)
    assert(returnAvoidanceScene.expedition.durability == 3)
    assert(not returnAvoidanceScene.collided[avoidablePlanet.id])

    assert(table.concat(touchScene.expedition.lastSlotSymbols, " ") == "STAR STAR STAR")
    assert(touchScene.message == "STAR STAR STAR +$75  1 LEFT")
    local readySlotButton = touchScene:slotButtonState()
    assert(readySlotButton.enabled and readySlotButton.label == "TAP: SLOT SPIN  1 LEFT")
    touchScene:touchpressed("last-slot", 90, 266)
    assert(touchScene.expedition.slotSpins == 2 and touchScene.expedition.slotOpportunities == 0)
    local spinningSlotButton = touchScene:slotButtonState()
    assert(not spinningSlotButton.enabled and spinningSlotButton.label == "SLOT SPINNING...")
    touchScene:update(1)
    local emptySlotButton = touchScene:slotButtonState()
    assert(not emptySlotButton.enabled and emptySlotButton.label == "NO SLOT CHANCES")
    touchScene:touchpressed("empty-slot", 90, 266)
    assert(touchScene.expedition.slotSpins == 2 and touchScene.expedition.slotOpportunities == 0)
    touchScene.expedition.phase = "settlement"
    touchScene.expedition.money = touchScene.expedition.fuelUpgradeCost
        + touchScene.expedition.durabilityUpgradeCost + touchScene.expedition.scoutShipCost
    touchScene:touchpressed("fuel", 90, 174)
    touchScene:touchpressed("hull", 45, 208)
    touchScene:touchpressed("ship", 90, 244)
    assert(touchScene.expedition.fuelUpgradeLevel == 1)
    assert(touchScene.expedition.durabilityUpgradeLevel == 1)
    assert(touchScene.expedition.ownedShips.scout and touchScene.expedition.selectedShipId == "scout")
    touchScene:touchpressed("relaunch", 90, 300)
    assert(touchScene.expedition.phase == "ascending")

    local loadoutScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    local starterLoadout = loadoutScene:loadoutLines()
    -- docs/feedback/INBOX.md UI/HUD item 4: the ship-name line is dead
    -- weight while only the single default STARTER hull is owned (no real
    -- choice exists yet), so loadoutLines().ship is nil until a second
    -- ship (scout) is actually owned -- only then does naming the current
    -- ship carry any meaning.
    assert(starterLoadout.ship == nil,
        "loadout ship line should be hidden while only STARTER is owned")
    assert(starterLoadout.stats == "HULL 3")
    assert(starterLoadout.upgrades == "FUEL LV.0  HULL LV.0")
    assert(starterLoadout.forecast == "REACH 600  SLOTS 6")
    assert(starterLoadout.steering == "STEER SPEED 55")
    loadoutScene.expedition.phase = "settlement"
    loadoutScene.expedition.money = loadoutScene.expedition.fuelUpgradeCost
        + loadoutScene.expedition.durabilityUpgradeCost + loadoutScene.expedition.scoutShipCost
        + loadoutScene.expedition.steeringUpgradeCost
    assert(expedition.buyFuelUpgrade(loadoutScene.expedition))
    assert(expedition.buyDurabilityUpgrade(loadoutScene.expedition))
    assert(expedition.buyShip(loadoutScene.expedition, "scout"))
    assert(expedition.selectShip(loadoutScene.expedition, "scout"))
    assert(expedition.buySteeringUpgrade(loadoutScene.expedition))
    local upgradedLoadout = loadoutScene:loadoutLines()
    assert(upgradedLoadout.ship == "SHIP SCOUT")
    assert(upgradedLoadout.stats == "HULL 3")
    assert(upgradedLoadout.upgrades == "FUEL LV.1  HULL LV.1")
    assert(upgradedLoadout.forecast == "REACH 960  SLOTS 10")
    assert(upgradedLoadout.steering == "STEER SPEED 70")
    assert(expedition.launch(loadoutScene.expedition))
    assert(expedition.damage(loadoutScene.expedition, loadoutScene.expedition.maxDurability))
    local resetLoadout = loadoutScene:loadoutLines()
    -- Destruction wipes ownedShips back down to only STARTER, so the ship
    -- line is hidden again post-reset for the same reason as above.
    assert(resetLoadout.ship == nil,
        "loadout ship line should be hidden again after a meta-wipe reset")
    assert(resetLoadout.stats == "HULL 3")
    assert(resetLoadout.upgrades == "FUEL LV.0  HULL LV.0")
    assert(resetLoadout.steering == "STEER SPEED 55")

    local nextLaunchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    nextLaunchScene.expedition.phase = "settlement"
    local starterNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(starterNextLaunch.ship == "NEXT STARTER")
    assert(starterNextLaunch.stats == "HULL 3")
    assert(starterNextLaunch.upgrades == "FUEL LV.0  HULL LV.0")
    assert(starterNextLaunch.forecast == "REACH 600  SLOTS 6")
    assert(starterNextLaunch.scoutTradeoff[1] == "SCOUT GAINS +40 FUEL")
    assert(starterNextLaunch.scoutTradeoff[2] == "LOSSES -1 HULL")
    assert(starterNextLaunch.shipAction == "BUY SCOUT $125")
    assert(starterNextLaunch.shipPreview == "SCOUT HULL 2")
    assert(starterNextLaunch.shipPreviewForecast == "REACH 840  SLOTS 9")
    assert(starterNextLaunch.fuelAction == "T/F FUEL LV.0>1 $50")
    assert(starterNextLaunch.fuelPreviewForecast == "REACH 720  SLOTS 8")
    assert(starterNextLaunch.fuelStatus == "SHORT $50" and not starterNextLaunch.fuelAffordable)
    assert(starterNextLaunch.hullAction == "T/H HULL LV.0>1 $75")
    assert(starterNextLaunch.hullPreview == "HULL 4")
    assert(starterNextLaunch.hullPreviewForecast == "REACH 600  SLOTS 6")
    assert(starterNextLaunch.hullStatus == "SHORT $75" and not starterNextLaunch.hullAffordable)
    assert(starterNextLaunch.shipStatus == "SHORT $125" and not starterNextLaunch.shipAffordable)
    assert(starterNextLaunch.yieldAction == "T/Y YIELD LV.0>1 $60")
    assert(starterNextLaunch.yieldPreview == "YIELD x1.25")
    assert(starterNextLaunch.yieldStatus == "SHORT $60" and not starterNextLaunch.yieldAffordable)
    assert(starterNextLaunch.steeringAction == "T/G STEER LV.0>1 $65")
    assert(starterNextLaunch.steeringPreview == "STEER SPEED 70")
    assert(starterNextLaunch.steeringStatus == "SHORT $65" and not starterNextLaunch.steeringAffordable)
    -- Compact column labels for the HULL/STEERING shared touch row (see
    -- settlementTouchRows: HULL occupies the left half, STEERING the right
    -- half of one 90px-wide column). The existing hullAction/steeringAction
    -- strings ("T/H HULL LV.0>1 $75", 91-96px measured) are too wide to sit
    -- side-by-side in a single 90 canvas px column, so these shorter
    -- "H:"/"G:" prefixed variants (measured 58-63px via GAME_FONTPROBE) are
    -- drawn in the column instead, without changing the existing full
    -- strings other callers may still rely on.
    assert(starterNextLaunch.hullActionCompact == "H:LV.0>1 $75")
    assert(starterNextLaunch.steeringActionCompact == "G:LV.0>1 $65")
    assert(starterNextLaunch.hullPreviewCompact == "HULL 4")
    assert(starterNextLaunch.steeringPreviewCompact == "SPD 70")
    -- Same compact treatment for the YIELD/SHIP shared touch row (see
    -- settlementTouchRows: YIELD occupies the left half, SHIP the right
    -- half). yieldAction ("T/Y YIELD LV.0>1 $60", 92-97px) and shipAction
    -- ("BUY SCOUT $125"/"SELECT STARTER"/"SELECT SCOUT", 63-72px) are both
    -- too wide for a 90px column once a "T/V "/"T/Y " prefix and a
    -- side-by-side status line are added, so compact "Y:"/"V:" variants
    -- (measured 38-62px) are drawn in the column instead.
    assert(starterNextLaunch.yieldActionCompact == "Y:LV.0>1 $60")
    assert(starterNextLaunch.shipActionCompact == "V:BUY $125")
    nextLaunchScene.expedition.money = nextLaunchScene.expedition.fuelUpgradeCost
    local fuelReadyNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(fuelReadyNextLaunch.fuelStatus == "LEFT $0" and fuelReadyNextLaunch.fuelAffordable)
    assert(fuelReadyNextLaunch.hullStatus == "SHORT $25" and not fuelReadyNextLaunch.hullAffordable)
    assert(fuelReadyNextLaunch.shipStatus == "SHORT $75" and not fuelReadyNextLaunch.shipAffordable)
    assert(fuelReadyNextLaunch.yieldStatus == "SHORT $10" and not fuelReadyNextLaunch.yieldAffordable)
    assert(fuelReadyNextLaunch.steeringStatus == "SHORT $15" and not fuelReadyNextLaunch.steeringAffordable)
    nextLaunchScene.expedition.money = 200
    local balancePreviewNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(balancePreviewNextLaunch.fuelStatus == "LEFT $150" and balancePreviewNextLaunch.fuelAffordable)
    assert(balancePreviewNextLaunch.hullStatus == "LEFT $125" and balancePreviewNextLaunch.hullAffordable)
    assert(balancePreviewNextLaunch.shipStatus == "LEFT $75" and balancePreviewNextLaunch.shipAffordable)
    assert(balancePreviewNextLaunch.yieldStatus == "LEFT $140" and balancePreviewNextLaunch.yieldAffordable)
    assert(balancePreviewNextLaunch.steeringStatus == "LEFT $135" and balancePreviewNextLaunch.steeringAffordable)
    nextLaunchScene.expedition.money = nextLaunchScene.expedition.fuelUpgradeCost
        + nextLaunchScene.expedition.durabilityUpgradeCost + nextLaunchScene.expedition.scoutShipCost
        + nextLaunchScene.expedition.sampleYieldUpgradeCost
    nextLaunchScene:keypressed("f")
    local fueledNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(fueledNextLaunch.stats == "HULL 3")
    assert(fueledNextLaunch.upgrades == "FUEL LV.1  HULL LV.0")
    assert(fueledNextLaunch.forecast == "REACH 720  SLOTS 8")
    assert(fueledNextLaunch.fuelAction == "T/F FUEL LV.1>2 $50")
    assert(fueledNextLaunch.hullAction == "T/H HULL LV.0>1 $75")
    assert(fueledNextLaunch.shipPreviewForecast == "REACH 960  SLOTS 10")
    assert(fueledNextLaunch.fuelPreviewForecast == "REACH 840  SLOTS 9")
    assert(fueledNextLaunch.hullPreview == "HULL 4")
    assert(fueledNextLaunch.hullPreviewForecast == "REACH 720  SLOTS 8")
    nextLaunchScene:keypressed("h")
    local reinforcedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reinforcedNextLaunch.stats == "HULL 4")
    assert(reinforcedNextLaunch.upgrades == "FUEL LV.1  HULL LV.1")
    assert(reinforcedNextLaunch.fuelAction == "T/F FUEL LV.1>2 $50")
    assert(reinforcedNextLaunch.hullAction == "T/H HULL LV.1>2 $75")
    assert(reinforcedNextLaunch.shipPreview == "SCOUT HULL 3")
    nextLaunchScene:keypressed("y")
    local yieldedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(yieldedNextLaunch.yieldAction == "T/Y YIELD LV.1>2 $60")
    assert(yieldedNextLaunch.yieldPreview == "YIELD x1.50")
    nextLaunchScene:keypressed("v")
    local scoutNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(scoutNextLaunch.ship == "NEXT SCOUT")
    assert(scoutNextLaunch.stats == "HULL 3")
    assert(scoutNextLaunch.upgrades == "FUEL LV.1  HULL LV.1")
    assert(scoutNextLaunch.forecast == "REACH 960  SLOTS 10")
    assert(scoutNextLaunch.shipPreviewForecast == "REACH 720  SLOTS 8")
    assert(scoutNextLaunch.fuelAction == "T/F FUEL LV.1>2 $50")
    assert(scoutNextLaunch.fuelPreviewForecast == "REACH 1080  SLOTS 11")
    assert(scoutNextLaunch.hullAction == "T/H HULL LV.1>2 $75")
    assert(scoutNextLaunch.hullPreview == "HULL 4")
    assert(scoutNextLaunch.hullPreviewForecast == "REACH 960  SLOTS 10")
    assert(scoutNextLaunch.scoutTradeoff[1] == "SCOUT GAINS +40 FUEL")
    assert(scoutNextLaunch.scoutTradeoff[2] == "LOSSES -1 HULL")
    assert(scoutNextLaunch.shipAction == "SELECT STARTER")
    assert(scoutNextLaunch.shipStatus == "OWNED" and scoutNextLaunch.shipAffordable)
    nextLaunchScene:keypressed("v")
    local reselectedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reselectedNextLaunch.ship == "NEXT STARTER")
    assert(reselectedNextLaunch.stats == "HULL 4")
    assert(reselectedNextLaunch.upgrades == "FUEL LV.1  HULL LV.1")
    assert(reselectedNextLaunch.fuelPreviewForecast == "REACH 840  SLOTS 9")
    assert(reselectedNextLaunch.shipAction == "SELECT SCOUT")
    assert(nextLaunchScene.message
        == "STARTER SELECTED  HULL 4  REACH 720  SLOTS 8")
    nextLaunchScene:touchpressed("ship", 90, 244)
    assert(nextLaunchScene.expedition.selectedShipId == "scout")
    assert(nextLaunchScene.message
        == "SCOUT SELECTED  HULL 3  REACH 960  SLOTS 10")
    assert(nextLaunchScene:shopLoadoutLines().shipAction == "SELECT STARTER")

    local destroyedRun = expedition.new({
        fuel = 10,
        durability = 2,
        fuelBurnRate = 1,
        climbSpeed = 80,
        fuelUpgradeAmount = 5,
        fuelUpgradeCost = 50,
        durabilityUpgradeCost = 40,
        money = 140,
    })
    destroyedRun.phase = "settlement"
    assert(expedition.buyFuelUpgrade(destroyedRun))
    assert(expedition.buyDurabilityUpgrade(destroyedRun))
    assert(expedition.launch(destroyedRun))
    expedition.update(destroyedRun, 1)
    assert(expedition.collectSample(destroyedRun, 70))
    assert(not expedition.damage(destroyedRun, 1))
    assert(destroyedRun.durability == 2 and destroyedRun.phase == "ascending")
    assert(not expedition.damage(destroyedRun, 1))
    assert(destroyedRun.durability == 1 and destroyedRun.phase == "ascending")
    assert(expedition.damage(destroyedRun, 1))
    assert(destroyedRun.phase == "destroyed" and destroyedRun.durability == 0)
    assert(destroyedRun.money == 0 and destroyedRun.sampleCount == 0 and destroyedRun.pendingSampleValue == 0)
    assert(destroyedRun.fuelUpgradeLevel == 0 and destroyedRun.maxFuel == destroyedRun.baseFuel)
    assert(destroyedRun.durabilityUpgradeLevel == 0 and destroyedRun.maxDurability == destroyedRun.baseDurability)
    assert(destroyedRun.bestAltitude == 80)
    assert(destroyedRun.lastLostSampleCount == 1 and destroyedRun.lastLostSampleValue == 70)
    assert(destroyedRun.lastLostSlotSpinsCount == 0 and destroyedRun.lastLostSlotValue == 0)
    assert(destroyedRun.lastLostAltitude == 80)
    assert(destroyedRun.lastLostNewBest == true)
    assert(expedition.launch(destroyedRun) and destroyedRun.phase == "ascending")
    assert(destroyedRun.altitude == 0 and destroyedRun.durability == destroyedRun.maxDurability)
    assert(destroyedRun.bestAltitude == 80)
    assert(destroyedRun.lastLostSampleCount == 0 and destroyedRun.lastLostSampleValue == 0)
    assert(destroyedRun.lastLostNewBest == false)

    local testSave = "self-test-best-altitude.txt"
    love.filesystem.remove(testSave)
    local altitudeStore = bestAltitudeStore.new(testSave)
    assert(altitudeStore:load() == 0)
    assert(altitudeStore:save(125.5))
    local restartedStore = bestAltitudeStore.new(testSave)
    assert(restartedStore:load() == 125.5)
    assert(not restartedStore:save(80))
    assert(bestAltitudeStore.new(testSave):load() == 125.5)

    local persistedRun = expedition.new({ bestAltitude = restartedStore:load(), money = 100 })
    persistedRun.phase = "ascending"
    persistedRun.durability = 1
    assert(expedition.damage(persistedRun, 1))
    assert(persistedRun.money == 0 and persistedRun.bestAltitude == 125.5)
    assert(bestAltitudeStore.new(testSave):load() == 125.5)
    assert(love.filesystem.remove(testSave))

    -- collection_store: persists discovered specimen ids across instances
    -- (mirrors best_altitude_store's file-round-trip test above), and
    -- record() only reports true (a "new" discovery) the first time a
    -- given id is seen.
    local testCollection = "self-test-specimen-collection.txt"
    love.filesystem.remove(testCollection)
    local specimenStore = collectionStore.new(testCollection)
    local emptyIds = specimenStore:load()
    assert(next(emptyIds) == nil)
    assert(specimenStore:record("azure_common") == true)
    assert(specimenStore:record("azure_common") == false)
    assert(specimenStore:record("ember_rare") == true)
    local reloadedStore = collectionStore.new(testCollection)
    local reloadedIds = reloadedStore:load()
    assert(reloadedIds.azure_common == true)
    assert(reloadedIds.ember_rare == true)
    assert(reloadedIds.void_epic == nil)
    assert(reloadedStore:record("azure_common") == false)
    assert(love.filesystem.remove(testCollection))

    -- PlayScene wires collectionStore into collectedSpecimens on
    -- construction and drawSpecimenStrip/specimenProgress read from it
    -- without erroring even when nothing has been collected yet.
    local specimenScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
        collectionStore = { load = function() return { azure_common = true } end, record = function() return true end },
    })
    assert(specimenScene.collectedSpecimens.azure_common == true)
    local found, total = specimenScene:specimenProgress()
    assert(found == 1 and total == 9)

    local savedBest = 40
    local fakeStore = {
        load = function() return savedBest end,
        save = function(_, altitude)
            if altitude <= savedBest then return false end
            savedBest = altitude
            return true
        end,
    }
    local persistedScene = PlayScene.new({ bestAltitudeStore = fakeStore })
    assert(persistedScene.expedition.bestAltitude == 40)
    assert(persistedScene:hudLines().best == "PERSONAL BEST 0040")
    persistedScene.expedition.phase = "settlement"
    assert(persistedScene:hudLines().best == "PERSONAL BEST 0040")
    persistedScene.expedition.phase = "launch"
    persistedScene.expedition.fuel = 1
    persistedScene.expedition.maxFuel = 1
    persistedScene.expedition.fuelBurnRate = 1
    persistedScene.expedition.climbSpeed = 60
    assert(expedition.launch(persistedScene.expedition))
    persistedScene.expedition.altitude = 60
    persistedScene.expedition.maxAltitude = 60
    persistedScene.expedition.bestAltitude = 60
    persistedScene.expedition.fuel = 0
    persistedScene.expedition.phase = "returning"
    persistedScene:persistBestAltitude()
    assert(persistedScene.expedition.phase == "returning" and savedBest == 60)
    local restartedScene = PlayScene.new({ bestAltitudeStore = fakeStore })
    assert(restartedScene.expedition.bestAltitude == 60)
    assert(restartedScene:hudLines().best == "PERSONAL BEST 0060")

    local floatingTextScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    assert(#floatingTextScene.floatingTexts == 0)
    floatingTextScene.expedition.phase = "ascending"
    floatingTextScene.expedition.altitude = 500
    floatingTextScene.ship.y = -500
    floatingTextScene.collided["floating-text-sample"] = true
    local floatingTextNearby = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "floating-text-sample", x = 0, y = -500, radius = 7 } }
    end
    floatingTextScene:update(0)
    world.nearbyPlanets = floatingTextNearby
    assert(#floatingTextScene.floatingTexts == 1)
    local sampleFloatingText = floatingTextScene.floatingTexts[1]
    -- Numeric roll-up feedback (docs/feedback/INBOX.md 2026-09-02 후속
    -- 확정 사항 #2): "+$N" no longer pops in at its final value instantly.
    -- It starts at "+$0" and counts up over sampleRollupDuration (0.3s)
    -- like a slot-machine reel settling, then holds the final value.
    assert(sampleFloatingText.text == "+$0",
        "sample floating text must start its roll-up at +$0: " .. tostring(sampleFloatingText.text))
    assert(sampleFloatingText.timer == 1.0)
    local startingFloatingY = sampleFloatingText.y
    floatingTextScene:update(0.15)
    assert(#floatingTextScene.floatingTexts == 1)
    assert(math.abs(sampleFloatingText.timer - 0.85) < 1e-9)
    assert(sampleFloatingText.y < startingFloatingY)
    assert(sampleFloatingText.text == "+$18",
        "sample floating text must show a partial roll-up value mid-animation: "
            .. tostring(sampleFloatingText.text))
    floatingTextScene:update(0.15)
    assert(sampleFloatingText.text == "+$35",
        "sample floating text must reach the full awarded amount once the roll-up duration elapses: "
            .. tostring(sampleFloatingText.text))
    floatingTextScene:update(0.35)
    assert(#floatingTextScene.floatingTexts == 1)
    assert(sampleFloatingText.text == "+$35", "roll-up value must hold steady after completion")
    floatingTextScene:update(0.36)
    assert(#floatingTextScene.floatingTexts == 0)

    assert(expedition.slotTotalWeight == 10)
    assert(math.abs(expedition.slotSymbolProbability("COMET") - 0.5) < 1e-9)
    assert(math.abs(expedition.slotSymbolProbability("PLANET") - 0.4) < 1e-9)
    assert(math.abs(expedition.slotSymbolProbability("STAR") - 0.1) < 1e-9)
    assert(expedition.weightedSlotSymbol(1) == "COMET")
    assert(expedition.weightedSlotSymbol(5) == "COMET")
    assert(expedition.weightedSlotSymbol(6) == "PLANET")
    assert(expedition.weightedSlotSymbol(9) == "PLANET")
    assert(expedition.weightedSlotSymbol(10) == "STAR")
    local ev, probabilitySum = expedition.slotExpectedValue()
    assert(math.abs(probabilitySum - 1) < 1e-9)
    assert(ev > 0 and ev < 25)
    assert(math.abs(ev - 18.585) < 0.01)

    local slotOddsScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    assert(slotOddsScene:slotOddsLine() == "C50 P40 S10  EV $18.58")

    local oddsLoadoutScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    local launchLoadoutOdds = oddsLoadoutScene:loadoutLines()
    assert(launchLoadoutOdds.odds == "C50 P40 S10  EV $18.58")
    oddsLoadoutScene.expedition.phase = "settlement"
    local shopLoadoutOdds = oddsLoadoutScene:shopLoadoutLines()
    assert(shopLoadoutOdds.odds == "C50 P40 S10  EV $18.58")

    for _, row in ipairs(PlayScene.settlementTouchRows) do
        assert(row.bottom - row.top >= 34,
            "settlement touch row " .. (row.key or "columns") .. " is under the 34px minimum")
    end

    -- EARTH SHOP fuel/hull/steering/yield/ship rows print an action string
    -- (left column) and a status string (right column, "LEFT $N"/"SHORT $N"/
    -- "OWNED") side by side. A real LÖVE font probe (GAME_FONTPROBE=1 love .)
    -- against the small scene-cached font (love.graphics.newFont(8)) measured
    -- the widest action string ("T/G STEER LV.9>10 $65") at 100px and the
    -- widest status string ("SHORT $125") at 52px. Verify the drawn columns
    -- clear both measured worst cases so long status text cannot wrap onto a
    -- second line and overlap the row spaced only 9px below.
    assert(PlayScene.shopActionColumnW >= 100,
        "EARTH SHOP action column is under the measured worst-case action text width")
    assert(PlayScene.shopStatusColumnW >= 52,
        "EARTH SHOP status column is under the measured worst-case status text width")
    assert(PlayScene.shopStatusColumnX >= PlayScene.shopActionColumnX + PlayScene.shopActionColumnW,
        "EARTH SHOP status column overlaps the action column")

    -- EARTH SHOP touch rows are shaded with a faint alternating background
    -- (drawn behind, never on top of, the already-verified text) purely as a
    -- visual affordance for which rows respond to touch. Verify every row
    -- resolves a valid RGBA color and adjacent rows alternate.
    for index = 1, #PlayScene.settlementTouchRows do
        local color = PlayScene.settlementRowBackgroundColor(index)
        assert(type(color) == "table" and #color == 4,
            "settlement row background color must be an RGBA table")
        for _, channel in ipairs(color) do
            assert(channel >= 0 and channel <= 1, "settlement row background channel out of range")
        end
    end
    assert(PlayScene.settlementRowBackgroundColor(1) ~= PlayScene.settlementRowBackgroundColor(2),
        "adjacent settlement rows must use different background colors")
    assert(PlayScene.settlementRowBackgroundColor(1) == PlayScene.settlementRowBackgroundColor(3),
        "background colors should alternate in a fixed two-color cycle")

    -- The smallest supported window (integer scale 1, e.g. 180x320) at a 1x
    -- device pixel ratio is the worst case for touch-target accessibility.
    -- iOS/Android guidelines require ~44pt minimum; verify every settlement
    -- row actually clears that bar via the real canvas-to-points conversion,
    -- not just the previously-checked 34px minimum.
    for _, row in ipairs(PlayScene.settlementTouchRows) do
        local heightPoints = viewport.canvasPixelsToPoints(row.bottom - row.top, 180, 320, 1, false)
        assert(heightPoints >= 44,
            "settlement touch row " .. (row.key or "columns")
                .. " is under the 44pt accessibility minimum at scale 1 (" .. heightPoints .. "pt)")
        if row.columns then
            for _, column in ipairs(row.columns) do
                local widthPoints = viewport.canvasPixelsToPoints(column.right - column.left, 180, 320, 1, false)
                assert(widthPoints >= 44,
                    "settlement touch column " .. column.key
                        .. " is under the 44pt accessibility minimum width at scale 1 (" .. widthPoints .. "pt)")
            end
        end
    end
    local rowTouchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    rowTouchScene.expedition.phase = "settlement"
    rowTouchScene.expedition.money = rowTouchScene.expedition.fuelUpgradeCost
        + rowTouchScene.expedition.durabilityUpgradeCost + rowTouchScene.expedition.scoutShipCost
        + rowTouchScene.expedition.sampleYieldUpgradeCost + rowTouchScene.expedition.steeringUpgradeCost
    for _, row in ipairs(PlayScene.settlementTouchRows) do
        if row.columns then
            for _, column in ipairs(row.columns) do
                rowTouchScene:touchpressed(column.key,
                    column.left + math.floor((column.right - column.left) / 2),
                    row.top + math.floor((row.bottom - row.top) / 2))
            end
        else
            rowTouchScene:touchpressed(row.key, 90, row.top + math.floor((row.bottom - row.top) / 2))
        end
    end
    assert(rowTouchScene.expedition.fuelUpgradeLevel == 1)
    assert(rowTouchScene.expedition.durabilityUpgradeLevel == 1)
    assert(rowTouchScene.expedition.sampleYieldUpgradeLevel == 1)
    assert(rowTouchScene.expedition.steeringUpgradeLevel == 1)
    assert(rowTouchScene.expedition.ownedShips.scout and rowTouchScene.expedition.selectedShipId == "scout")
    assert(rowTouchScene.expedition.phase == "ascending")

    -- The returning-phase LEFT/RIGHT/SPIN band was a 24px-tall row (only
    -- ~24pt at the smallest supported window), well under the same 44pt
    -- accessibility minimum settlementTouchRows was fixed to meet. Verify
    -- the widened band clears 44pt and that touches at its top/bottom
    -- edges (not just its vertical center) still register steering and
    -- slot input.
    local returnControls = PlayScene.returnControls
    assert(returnControls.bottom - returnControls.top >= 34,
        "returning control band is under the 34px minimum")
    local returnBandPoints = viewport.canvasPixelsToPoints(
        returnControls.bottom - returnControls.top, 180, 320, 1, false)
    assert(returnBandPoints >= 44,
        "returning control band is under the 44pt accessibility minimum at scale 1 (" .. returnBandPoints .. "pt)")

    local returnEdgeScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    returnEdgeScene.expedition.phase = "returning"
    returnEdgeScene.expedition.altitude = 500
    returnEdgeScene.expedition.returnDistance = 500
    returnEdgeScene.expedition.returnSpeed = 0
    returnEdgeScene.expedition.slotOpportunities = 2
    returnEdgeScene.expedition.slotRandom = function() return 10 end
    local edgeNearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function() return {} end
    returnEdgeScene:touchpressed("edge-left", 20, returnControls.top)
    local edgeLeftSteering = returnEdgeScene:steeringButtonState()
    assert(edgeLeftSteering.leftActive and not edgeLeftSteering.rightActive,
        "returning band top edge did not register left steering")
    returnEdgeScene:touchreleased("edge-left")
    returnEdgeScene:touchpressed("edge-right", 160, returnControls.bottom - 1)
    local edgeRightSteering = returnEdgeScene:steeringButtonState()
    assert(not edgeRightSteering.leftActive and edgeRightSteering.rightActive,
        "returning band bottom edge did not register right steering")
    returnEdgeScene:touchreleased("edge-right")
    returnEdgeScene:touchpressed("edge-slot", 90, returnControls.top)
    assert(returnEdgeScene.expedition.slotSpins == 1 and returnEdgeScene.expedition.slotOpportunities == 1,
        "returning band top edge did not register slot spin at slot x range")
    world.nearbyPlanets = edgeNearbyPlanets

    local destroyedArea = PlayScene.destroyedTouchArea
    assert(destroyedArea.bottom - destroyedArea.top >= 34,
        "destroyed touch area height is under the 34px minimum")
    assert(destroyedArea.right - destroyedArea.left >= 34,
        "destroyed touch area width is under the 34px minimum")
    local destroyedCorners = {
        { x = destroyedArea.left, y = destroyedArea.top },
        { x = destroyedArea.right - 1, y = destroyedArea.top },
        { x = destroyedArea.left, y = destroyedArea.bottom - 1 },
        { x = destroyedArea.right - 1, y = destroyedArea.bottom - 1 },
        { x = math.floor((destroyedArea.left + destroyedArea.right) / 2),
          y = math.floor((destroyedArea.top + destroyedArea.bottom) / 2) },
    }
    for _, point in ipairs(destroyedCorners) do
        local destroyedTouchScene = PlayScene.new({
            bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
        })
        destroyedTouchScene.expedition.phase = "destroyed"
        destroyedTouchScene:touchpressed("destroyed-tap", point.x, point.y)
        assert(destroyedTouchScene.expedition.phase == "ascending",
            "destroyed tap at (" .. point.x .. "," .. point.y .. ") did not restart the run")
    end

    -- LAUNCH phase's TAP TO LAUNCH action already accepts any tap on the
    -- internal canvas regardless of x/y (unconditional touchpressed branch),
    -- so the functional touch target has always spanned the full 180x320
    -- canvas -- but unlike destroyedTouchArea, this was never given a named
    -- constant or an explicit corner-touch regression test. Documented and
    -- tested here to close out the remaining unverified touch surface noted
    -- in docs/STATUS.md's next-slice note.
    local launchArea = PlayScene.launchTouchArea
    assert(launchArea.bottom - launchArea.top >= 34,
        "launch touch area height is under the 34px minimum")
    assert(launchArea.right - launchArea.left >= 34,
        "launch touch area width is under the 34px minimum")
    local launchAreaPoints = viewport.canvasPixelsToPoints(
        launchArea.bottom - launchArea.top, 180, 320, 1, false)
    assert(launchAreaPoints >= 44,
        "launch touch area is under the 44pt accessibility minimum at scale 1 (" .. launchAreaPoints .. "pt)")
    local launchCorners = {
        { x = launchArea.left, y = launchArea.top },
        { x = launchArea.right - 1, y = launchArea.top },
        { x = launchArea.left, y = launchArea.bottom - 1 },
        { x = launchArea.right - 1, y = launchArea.bottom - 1 },
        { x = math.floor((launchArea.left + launchArea.right) / 2),
          y = math.floor((launchArea.top + launchArea.bottom) / 2) },
    }
    for _, point in ipairs(launchCorners) do
        local launchTouchScene = PlayScene.new({
            bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
        })
        launchTouchScene:touchpressed("launch-tap", point.x, point.y)
        assert(launchTouchScene.expedition.phase == "ascending",
            "launch tap at (" .. point.x .. "," .. point.y .. ") did not start the run")
    end

    -- Regression: a real LÖVE runtime capture after the launch-screen
    -- text/layout cleanup still showed a faint blue crescent peeking out
    -- above the LAUNCH LOADOUT card's opaque box -- the top edge of the
    -- Earth disc drawn behind the scene (center y=75-cameraY, radius 58)
    -- pokes above the box's top edge by a couple of pixels. Assert the
    -- box's top y is at or above the Earth disc's topmost extent for a
    -- ship parked at the world origin (the launch-phase ship position),
    -- so the disc can never render above the box again.
    local shipScreenY = math.floor(320 * 0.58)
    local cameraY = 0 - shipScreenY
    local earthY = math.floor(75 - cameraY)
    local earthTopY = earthY - 58
    assert(PlayScene.launchLoadoutBoxTop <= earthTopY,
        "launch loadout box top (" .. PlayScene.launchLoadoutBoxTop ..
        ") does not fully cover the Earth disc's top edge (" .. earthTopY .. ")")

    -- docs/feedback/INBOX.md UI/HUD item 4: the "LAUNCH LOADOUT"/"발사 장비"
    -- panel title itself was flagged for removal -- the card's contents
    -- (hull/upgrades/forecast/steering/odds) are self-explanatory once
    -- rendered inside an obviously bordered box directly below the Earth
    -- disc, so a redundant caption line just eats vertical space without
    -- adding information. M.showLaunchLoadoutTitle gates the title printf
    -- in draw(); this regression pins it to false so the caption line and
    -- its row-step gap stay removed.
    assert(PlayScene.showLaunchLoadoutTitle == false,
        "launch loadout panel title should stay hidden (docs/feedback item 4)")

    -- Ascending no longer draws HOLD LEFT/HOLD RIGHT boxes; the full
    -- canvas is still a tap-hold fallback (left half / right half).
    local ascendControls = PlayScene.ascendControls
    local ascendEdgeScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    ascendEdgeScene.expedition.phase = "ascending"
    ascendEdgeScene:touchpressed("ascend-edge-left", 20, ascendControls.top)
    local ascendEdgeLeftSteering = ascendEdgeScene:steeringButtonState()
    assert(ascendEdgeLeftSteering.leftActive and not ascendEdgeLeftSteering.rightActive,
        "ascending tap on the left half must still register left steering")
    ascendEdgeScene:touchreleased("ascend-edge-left")
    ascendEdgeScene:touchpressed("ascend-edge-right", 160, ascendControls.bottom - 1)
    local ascendEdgeRightSteering = ascendEdgeScene:steeringButtonState()
    assert(not ascendEdgeRightSteering.leftActive and ascendEdgeRightSteering.rightActive,
        "ascending tap on the right half must still register right steering")
    ascendEdgeScene:touchreleased("ascend-edge-right")

    -- docs/GAME_DESIGN.md's 귀환 슬롯 section lists repair vouchers
    -- (수리권) as one of the reward kinds a return slot spin can grant,
    -- alongside money. Only money payouts existed until now. A STAR-STAR-
    -- STAR jackpot is the rarest/most valuable combo (10% per reel, 0.1%
    -- overall), so it also restores 1 durability point (capped at
    -- run.maxDurability) as its repair-voucher bonus on top of the $75
    -- money reward. Non-jackpot combos grant no repair.
    local repairRun = expedition.new({
        slotRandom = function() return 10 end, -- always STAR (weight cumulative 10)
    })
    repairRun.durability = 1
    repairRun.phase = "returning"
    repairRun.slotOpportunities = 1
    assert(expedition.useSlot(repairRun))
    assert(table.concat(repairRun.lastSlotSymbols, "-") == "STAR-STAR-STAR")
    assert(repairRun.lastSlotReward == 75 and repairRun.pendingSlotReward == 75)
    assert(repairRun.durability == 2, "STAR triple must repair 1 durability point")
    assert(repairRun.lastSlotRepair == 1, "lastSlotRepair must report the actual repair applied")

    local repairAtCapRun = expedition.new({
        durability = 3,
        slotRandom = function() return 10 end,
    })
    repairAtCapRun.phase = "returning"
    repairAtCapRun.slotOpportunities = 1
    assert(expedition.useSlot(repairAtCapRun))
    assert(repairAtCapRun.durability == 3, "repair must not exceed maxDurability")
    assert(repairAtCapRun.lastSlotRepair == 0, "no repair should be reported once durability is already full")

    local noRepairRolls = { 1, 6, 10 } -- COMET-PLANET-STAR, no match, no repair
    local nextNoRepairRoll = 0
    local noRepairRun = expedition.new({
        slotRandom = function()
            nextNoRepairRoll = nextNoRepairRoll + 1
            return noRepairRolls[nextNoRepairRoll]
        end,
    })
    noRepairRun.durability = 1
    noRepairRun.phase = "returning"
    noRepairRun.slotOpportunities = 1
    assert(expedition.useSlot(noRepairRun))
    assert(noRepairRun.durability == 1, "non-jackpot combos must not repair durability")
    assert(noRepairRun.lastSlotRepair == 0)

    -- relaunch and destruction must reset the repair receipt like the
    -- other last-spin fields (lastSlotReward, lastSlotSymbols).
    repairRun.phase = "settlement"
    assert(expedition.launch(repairRun))
    assert(repairRun.lastSlotRepair == 0, "relaunch must clear the previous spin's repair receipt")
    repairRun.phase = "returning"
    repairRun.slotOpportunities = 1
    repairRun.durability = 1
    assert(expedition.useSlot(repairRun))
    assert(repairRun.lastSlotRepair == 1)
    assert(expedition.damage(repairRun, repairRun.durability))
    assert(repairRun.phase == "destroyed" and repairRun.lastSlotRepair == 0,
        "destruction must clear the repair receipt like other pending/last-spin fields")

    -- The returning-phase slot result message should surface the repair
    -- bonus so players can see it landed, alongside the existing money
    -- win/pending text.
    local repairMessageRolls = { 10, 10, 10 }
    local nextRepairMessageRoll = 0
    local repairMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    repairMessageScene.expedition.slotRandom = function()
        nextRepairMessageRoll = nextRepairMessageRoll + 1
        return repairMessageRolls[nextRepairMessageRoll]
    end
    repairMessageScene.expedition.phase = "returning"
    repairMessageScene.expedition.altitude = 500
    repairMessageScene.expedition.durability = 1
    repairMessageScene.expedition.slotOpportunities = 1
    repairMessageScene:keypressed("up")
    repairMessageScene:update(repairMessageScene.slotSpin.duration + 0.01)
    assert(repairMessageScene.message == "STAR STAR STAR +$75 REPAIR +1  0 LEFT",
        "slot spin completion message must include the repair bonus: " .. tostring(repairMessageScene.message))

    -- docs/GAME_DESIGN.md's 귀환 슬롯 section also lists "다음 원정 연료
    -- 보너스" (next-expedition fuel bonus) as one of the reward kinds a
    -- return slot spin can grant. Only money and repair vouchers existed
    -- until now. A PLANET-PLANET-PLANET triple (40% per reel, 6.4%
    -- overall -- rarer than any generic triple's $40 payout but more
    -- common than the STAR jackpot) grants a fuel bonus that is banked at
    -- safe settlement and applied to the *next* expedition's starting
    -- fuel (not the current one, since the ship has already exhausted its
    -- fuel by the time it is returning).
    local fuelBonusRun = expedition.new({
        slotRandom = function() return 6 end, -- PLANET (cumulative 6..9)
    })
    fuelBonusRun.phase = "returning"
    fuelBonusRun.slotOpportunities = 1
    assert(expedition.useSlot(fuelBonusRun))
    assert(table.concat(fuelBonusRun.lastSlotSymbols, "-") == "PLANET-PLANET-PLANET")
    assert(fuelBonusRun.lastSlotReward == 40 and fuelBonusRun.pendingSlotReward == 40)
    assert(fuelBonusRun.lastSlotFuelBonus == 15, "PLANET triple must grant a 15 fuel bonus")
    assert(fuelBonusRun.pendingFuelBonus == 15, "fuel bonus must accumulate as pending until settlement")
    assert(fuelBonusRun.bankedFuelBonus == 0, "fuel bonus must not be banked before safe settlement")

    -- Non-jackpot, non-PLANET-triple combos grant no fuel bonus.
    assert(noRepairRun.lastSlotFuelBonus == 0)
    assert((noRepairRun.pendingFuelBonus or 0) == 0)

    -- Safe settlement banks the pending fuel bonus for the next launch and
    -- clears the pending counter; the current settlement's fuel is
    -- untouched (it only applies at the *next* M.launch).
    fuelBonusRun.altitude = 1
    expedition.update(fuelBonusRun, 1) -- drives altitude to 0 and calls settle()
    assert(fuelBonusRun.phase == "settlement")
    assert(fuelBonusRun.bankedFuelBonus == 15, "safe settlement must bank the pending fuel bonus")
    assert(fuelBonusRun.pendingFuelBonus == 0, "pending fuel bonus must clear once banked")

    -- The next launch applies the banked fuel bonus on top of maxFuel and
    -- clears the bank so it cannot be reused on a later launch.
    assert(expedition.launch(fuelBonusRun))
    assert(fuelBonusRun.fuel == fuelBonusRun.maxFuel + 15,
        "next launch must add the banked fuel bonus to starting fuel")
    assert(fuelBonusRun.bankedFuelBonus == 0, "banked fuel bonus must be consumed by the launch it funds")

    -- A second launch (no new bonus earned) must not carry over a bonus.
    fuelBonusRun.phase = "settlement"
    assert(expedition.launch(fuelBonusRun))
    assert(fuelBonusRun.fuel == fuelBonusRun.maxFuel,
        "launches without a freshly banked bonus must start at plain maxFuel")

    -- Destruction forfeits any pending/banked fuel bonus like the other
    -- pending rewards (samples, slot money, repair).
    local destroyedFuelBonusRun = expedition.new({
        slotRandom = function() return 6 end,
    })
    destroyedFuelBonusRun.phase = "returning"
    destroyedFuelBonusRun.slotOpportunities = 1
    assert(expedition.useSlot(destroyedFuelBonusRun))
    assert(destroyedFuelBonusRun.pendingFuelBonus == 15)
    assert(expedition.damage(destroyedFuelBonusRun, destroyedFuelBonusRun.durability))
    assert(destroyedFuelBonusRun.phase == "destroyed")
    assert(destroyedFuelBonusRun.pendingFuelBonus == 0, "destruction must forfeit the pending fuel bonus")
    assert(destroyedFuelBonusRun.bankedFuelBonus == 0, "destruction must forfeit any banked fuel bonus too")
    assert(destroyedFuelBonusRun.lastSlotFuelBonus == 0, "destruction must clear the last-spin fuel bonus receipt")

    -- The returning-phase slot result message should surface the fuel
    -- bonus alongside money/repair, and the launch message should surface
    -- the banked bonus actually applied to the new expedition.
    local fuelBonusMessageRolls = { 6, 6, 6 }
    local nextFuelBonusMessageRoll = 0
    local fuelBonusMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    fuelBonusMessageScene.expedition.slotRandom = function()
        nextFuelBonusMessageRoll = nextFuelBonusMessageRoll + 1
        return fuelBonusMessageRolls[nextFuelBonusMessageRoll]
    end
    fuelBonusMessageScene.expedition.phase = "returning"
    fuelBonusMessageScene.expedition.altitude = 500
    fuelBonusMessageScene.expedition.slotOpportunities = 1
    fuelBonusMessageScene:keypressed("up")
    fuelBonusMessageScene:update(fuelBonusMessageScene.slotSpin.duration + 0.01)
    assert(fuelBonusMessageScene.message == "PLANET PLANET PLANET +$40 FUEL +15  0 LEFT",
        "slot spin completion message must include the fuel bonus: " .. tostring(fuelBonusMessageScene.message))

    -- The EARTH SHOP summary card (settlement phase) must surface a
    -- banked next-expedition fuel bonus so the player can see the reward
    -- they earned before relaunching, mirroring how SAMPLES/SPINS/PEAK
    -- ALT/NEW BEST already summarize other settlement outcomes.
    local fuelBonusSummaryScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    fuelBonusSummaryScene.expedition.bankedFuelBonus = 0
    assert(fuelBonusSummaryScene:summaryFuelBonusLine() == nil,
        "no fuel bonus banked must show no summary line")
    fuelBonusSummaryScene.expedition.bankedFuelBonus = 15
    assert(fuelBonusSummaryScene:summaryFuelBonusLine() == "NEXT LAUNCH FUEL +15",
        "banked fuel bonus must be summarized as NEXT LAUNCH FUEL +N: "
            .. tostring(fuelBonusSummaryScene:summaryFuelBonusLine()))

    -- Real LOVE runtime capture (GAME_CAPTURE_PHASE=ascending-damage-text,
    -- 1440x2560) showed the green "+$N" sample floating text and the red
    -- "-N" damage floating text spawning at the exact same screen point
    -- when a ship overlaps a planet closely enough to trigger both the
    -- sample-collection and the collision thresholds on the same update:
    -- both used planet.x/y or ship.x/y directly with no separation, so the
    -- two texts rendered stacked on top of each other and were unreadable
    -- ("+$?5" mangled by an overlapping red glyph). Verify the two texts
    -- created in the same frame are horizontally separated by at least the
    -- width of the 60px-wide centered text box so neither can overlap the
    -- other, regardless of how close the ship and planet positions are.
    local overlapScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    overlapScene.expedition.phase = "ascending"
    overlapScene.expedition.altitude = 500
    overlapScene.expedition.durability = 3
    overlapScene.ship.x = 0
    overlapScene.ship.y = -500
    local overlapNearby = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "overlap-test", x = 0, y = -500, radius = 7 } }
    end
    overlapScene:update(0)
    world.nearbyPlanets = overlapNearby
    assert(#overlapScene.floatingTexts == 2,
        "same-frame sample+collision must create both floating texts")
    local overlapSample, overlapDamage
    for _, ft in ipairs(overlapScene.floatingTexts) do
        if ft.kind == "sample" then overlapSample = ft end
        if ft.kind == "damage" then overlapDamage = ft end
    end
    assert(overlapSample and overlapDamage)
    assert(math.abs(overlapSample.x - overlapDamage.x) >= 60,
        "sample and damage floating texts spawned in the same frame must be"
            .. " horizontally separated by at least the 60px text box width ("
            .. tostring(overlapSample.x) .. " vs " .. tostring(overlapDamage.x) .. ")")

    -- docs/GAME_DESIGN.md's 귀환 슬롯 section also lists "표본 보너스"
    -- (sample bonus) as one of the four slot reward kinds, alongside money
    -- multiples, repair vouchers and the fuel bonus above. It was the only
    -- one of the four still unimplemented. A COMET-COMET-COMET triple (50%
    -- per reel, 12.5% overall -- the most common triple, since COMET is the
    -- common filler symbol) grants a flat sample-value bonus. Unlike the
    -- fuel bonus, this stacks directly into the current expedition's
    -- pendingSampleValue immediately (it does not need to wait for the next
    -- launch, since sample value can still help the expedition that is
    -- already returning).
    local sampleBonusRun = expedition.new({
        slotRandom = function() return 1 end, -- COMET (cumulative 1..5)
    })
    sampleBonusRun.phase = "returning"
    sampleBonusRun.slotOpportunities = 1
    assert(expedition.useSlot(sampleBonusRun))
    assert(table.concat(sampleBonusRun.lastSlotSymbols, "-") == "COMET-COMET-COMET")
    assert(sampleBonusRun.lastSlotReward == 40 and sampleBonusRun.pendingSlotReward == 40)
    assert(sampleBonusRun.lastSlotSampleBonus == 25, "COMET triple must grant a 25 sample bonus")
    assert(sampleBonusRun.pendingSampleValue == 25,
        "sample bonus must accumulate into pendingSampleValue immediately")

    -- Non-jackpot, non-COMET-triple combos grant no sample bonus.
    assert(noRepairRun.lastSlotSampleBonus == 0)

    -- Safe settlement confirms the accumulated sample bonus as part of the
    -- normal sample settlement, same as any other pending sample value.
    sampleBonusRun.altitude = 1
    expedition.update(sampleBonusRun, 1) -- drives altitude to 0 and calls settle()
    assert(sampleBonusRun.phase == "settlement")
    assert(sampleBonusRun.lastSampleSettlement == 25,
        "safe settlement must confirm the slot sample bonus as sample settlement")

    -- Destruction forfeits the pending sample bonus like any other pending
    -- sample value.
    local destroyedSampleBonusRun = expedition.new({
        slotRandom = function() return 1 end,
    })
    destroyedSampleBonusRun.phase = "returning"
    destroyedSampleBonusRun.slotOpportunities = 1
    assert(expedition.useSlot(destroyedSampleBonusRun))
    assert(destroyedSampleBonusRun.pendingSampleValue == 25)
    assert(expedition.damage(destroyedSampleBonusRun, destroyedSampleBonusRun.durability))
    assert(destroyedSampleBonusRun.phase == "destroyed")
    assert(destroyedSampleBonusRun.lastLostSampleValue == 25,
        "destruction must report the forfeited sample bonus as lost sample value")
    assert(destroyedSampleBonusRun.lastSlotSampleBonus == 0,
        "destruction must clear the last-spin sample bonus receipt")

    -- The returning-phase slot result message should surface the sample
    -- bonus alongside money/repair/fuel.
    local sampleBonusMessageRolls = { 1, 1, 1 }
    local nextSampleBonusMessageRoll = 0
    local sampleBonusMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    sampleBonusMessageScene.expedition.slotRandom = function()
        nextSampleBonusMessageRoll = nextSampleBonusMessageRoll + 1
        return sampleBonusMessageRolls[nextSampleBonusMessageRoll]
    end
    sampleBonusMessageScene.expedition.phase = "returning"
    sampleBonusMessageScene.expedition.altitude = 500
    sampleBonusMessageScene.expedition.slotOpportunities = 1
    sampleBonusMessageScene:keypressed("up")
    sampleBonusMessageScene:update(sampleBonusMessageScene.slotSpin.duration + 0.01)
    assert(sampleBonusMessageScene.message == "COMET COMET COMET +$40 SAMPLE +$25  0 LEFT",
        "slot spin completion message must include the sample bonus: "
            .. tostring(sampleBonusMessageScene.message))

    -- Omnidirectional joystick movement (docs/GAME_DESIGN.md 이동 방식 개선
    -- 항목 1, "조이스틱을 통해 전방향으로 이동 가능함").
    testJoystick()
    testManeuverFuel()
    testGalaxyStructure()
    testMinimap()
    testDebris()
    testBackgroundStars()
    testLaunchRocketIcon()
    testHullShieldIcon()
    testCashCoinIcon()
    testGearJsonLoader()
    testGearSynergyEngine()
    testEnginePartsSlotSeparation()
    testGearRarityAndEditionSystem()
    testGearEditorEditionAndRaritySync()
    testGearEditorEditionEffectPreviewSync()
    testGearEffectSchemaExpansion()
    testEnginePropulsionSpecialization()
    testGearEffectTypeContentCoverage()
    testEngineCardsHaveNonHullOnlyEffect()
    testHullCardsHaveNonEngineOnlyEffect()
    testEngineCardsHaveCategoryAgnosticEffectCoverage()
    testGearRunWiring()
    testGearPropulsionRunWiring()
    testGearSurvivalAndEconomyWiring()
    testGearOfferRolling()
    testGearRunEffectWiring()
    testGearCollisionRadiusRunWiring()
    testGearHullDurabilityRunWiring()
    testGearHullSpeedRunWiring()
    testGearMoneyRunWiring()
    testGearStreakMultiplierWiring()
    testGearChainTriggerConsumptionWiring()
    testGearSlotSwapEconomyWiring()
    testGearNoSlotCostEditionWiring()
    testGearIrradiatedSynergyBonusWiring()

    print("SPACESHIP_UNIT_OK")
end

return M
