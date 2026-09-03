require("game.i18n").setLocale("en")
local viewport = require("game.viewport")
local shipModule = require("game.ship")
local world = require("game.world")
local expedition = require("game.expedition")
local bestAltitudeStore = require("game.best_altitude_store")
local collectionStore = require("game.collection_store")
local PlayScene = require("game.scenes.play")
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
    headingThrustScene:update(1)
    assert(headingThrustScene.ship.x > hx, "nose-right climb must move +x")
    assert(math.abs(headingThrustScene.ship.y - hy) < 1e-6,
        "nose-right climb must not keep forcing the ship straight up")
    assert(headingThrustScene.expedition.fuel == nil,
        "thrusting must not resurrect a dead fuel field; fuel is no longer a flight constraint")
    local coastX = headingThrustScene.ship.x
    headingThrustScene.touches["stick"] = nil
    headingThrustScene:update(1)
    assert(headingThrustScene.expedition.fuel == nil,
        "coasting must not resurrect a dead fuel field")
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
-- docs/feedback/INBOX.md 항목 11(c) 잔여: maneuverFuel/burnManeuverFuel were
-- dead no-op functions (always returned 0, never touched any state) kept
-- around only so older call sites would still compile. Now that they have
-- no call sites left (game/scenes/play.lua's burnManeuverFuel call is
-- removed alongside this), the dead API is removed entirely rather than
-- kept as a permanent no-op shim.
local function testManeuverFuel()
    local expedition = require("game.expedition")
    local run = expedition.new()
    assert(expedition.maneuverFuel == nil,
        "dead no-op maneuverFuel API must be removed, not kept as a shim")
    assert(expedition.burnManeuverFuel == nil,
        "dead no-op burnManeuverFuel API must be removed, not kept as a shim")
    -- docs/feedback/INBOX.md 처리대기 항목 11(a): M.launchForecast (and its
    -- "maxFuel" parameter name) framed the REACH/SLOTS estimate as
    -- "how far this fuel tank carries you" -- misleading since fuel does
    -- not constrain flight. It was renamed to M.rangeForecast(run,
    -- capacity); the old fuel-framed name must not survive even as an
    -- alias, and the renamed function must compute the identical value.
    assert(expedition.launchForecast == nil,
        "fuel-framed launchForecast name must not exist (item 11a rename)")
    assert(type(expedition.rangeForecast) == "function",
        "rangeForecast must exist as the renamed replacement")
    local forecastRun = expedition.new({ fuelBurnRate = 5, climbSpeed = 30, slotDistance = 100 })
    local altitude, slots = expedition.rangeForecast(forecastRun)
    assert(altitude == 600 and slots == 6,
        "rangeForecast must compute the same value the old launchForecast did")
    -- docs/feedback/INBOX.md 항목 11(c): run.fuel was a dead state field --
    -- only ever written (by M.launch/M.destroy), never read by any flight
    -- decision (altitude ticks by climbSpeed unconditionally). It must not
    -- exist at all, matching the earlier ship.fuel == nil precedent.
    assert(run.fuel == nil,
        "dead run.fuel state field must be removed, not just left unread")

    expedition.launch(run)
    expedition.update(run, 5)
    assert(run.fuel == nil, "launch/update must never resurrect a fuel field")
    assert(run.phase == "ascending", "ascent must not auto-return when fuel is unconstrained")
    assert(run.altitude > 0)

    -- docs/feedback/INBOX.md 처리대기 항목 15(a): the manually-declared
    -- beginReturn/"returning" phase and in-flight slot machine
    -- (useSlot/slotSpin) have been fully removed -- expedition.beginReturn
    -- and expedition.useSlot must not exist at all.
    assert(expedition.beginReturn == nil, "expedition.beginReturn must not exist (item 15a removal)")
    assert(expedition.useSlot == nil, "expedition.useSlot must not exist (item 15a removal)")

    local idleScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    idleScene.expedition.phase = "ascending"
    idleScene:update(1)
    assert(idleScene.expedition.fuel == nil,
        "coasting must not resurrect a dead fuel field")
    assert(idleScene.expedition.phase == "ascending")

    local steerScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    steerScene.expedition.phase = "ascending"
    steerScene.touches["hold"] = { x = 20, y = 160, originX = 20, originY = 160 }
    steerScene:update(1)
    assert(steerScene.expedition.fuel == nil,
        "steering must not resurrect a dead fuel field")
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

    -- docs/feedback/INBOX.md 처리대기 항목 7-a -- every non-home galaxy also
    -- has a deterministic 상점 행성 (shop planet) distinct from its hub
    -- checkpoint, discoverable via nearbyPlanets like the hub is.
    assert(world.shopPlanet(home) == nil, "milkyway has no extra shop planet -- EARTH SHOP fills that role")
    local shop = world.shopPlanet(foreignGalaxy)
    assert(shop and shop.shop and shop.galaxyId == foreignGalaxy.id)
    assert(shop.id == "shop:" .. foreignGalaxy.id)
    assert(shop.x ~= hub.x or shop.y ~= hub.y,
        "shop planet must sit at a different position than the hub checkpoint")
    local shopA = world.shopPlanet(foreignGalaxy)
    assert(shopA.x == shop.x and shopA.y == shop.y, "shop planet position must be deterministic")
    local shopsNearby = world.nearbyPlanets(shop.x, shop.y, 1)
    local sawShop = false
    for _, planet in ipairs(shopsNearby) do
        if planet.id == shop.id then sawShop = true end
    end
    assert(sawShop, "nearbyPlanets near a galaxy's shop planet must include that shop planet")
end

-- docs/feedback/INBOX.md 처리대기 항목 7 (장비 획득 경로 3원화) + 항목 8
-- (행성 탐사는 표본만, 정산은 체크포인트/지구에서만). Own top-level
-- function for the same 200-local limit as testJoystick.
local function testGearAndCheckpointSettlement()
    local world = require("game.world")
    local expedition = require("game.expedition")

    -- Item 7-b: exploring a galaxy's checkpoint hub planet grants a
    -- guaranteed, non-random unique gear part exactly once.
    local run = expedition.new()
    run.phase = "ascending"
    local galaxyId = "galaxy:9:9"
    local granted, gearId = expedition.exploreCheckpoint(run, galaxyId)
    assert(granted and gearId == expedition.galaxyGearId(galaxyId))
    assert(run.ownedGear[gearId], "exploring a checkpoint must grant its unique gear")
    -- Re-exploring the same checkpoint must not grant a duplicate/second drop.
    local grantedAgain, gearIdAgain = expedition.exploreCheckpoint(run, galaxyId)
    assert(not grantedAgain and gearIdAgain == nil, "re-exploring the same checkpoint must not re-grant gear")

    -- Item 7-a/7-c: buying gear costs money and cannot be bought twice.
    local buyRun = expedition.new({ money = 100 })
    assert(expedition.buyGear(buyRun, "shop:test-gear", 60))
    assert(buyRun.money == 40 and buyRun.ownedGear["shop:test-gear"])
    assert(not expedition.buyGear(buyRun, "shop:test-gear", 60), "cannot buy the same gear id twice")
    assert(not expedition.buyGear(buyRun, "too-expensive", 1000), "cannot buy gear without enough money")

    -- Item 8: EARTH SHOP only sells the generic catalog -- a
    -- galaxy-unique gear id (from exploreCheckpoint) must never be
    -- purchasable there.
    assert(#expedition.genericGearCatalog >= 1)
    local earthRun = expedition.new({ money = 1000 })
    local firstGeneric = expedition.genericGearCatalog[1]
    assert(expedition.buyEarthGear(earthRun, firstGeneric.id))
    assert(earthRun.ownedGear[firstGeneric.id])
    assert(not expedition.buyEarthGear(earthRun, expedition.galaxyGearId(galaxyId)),
        "EARTH SHOP must reject a galaxy-unique gear id")

    -- Item 7-a: a galaxy's 상점 행성 sells that galaxy's own unique gear
    -- part for money -- a paid alternative to the free checkpoint drop.
    local shopBuyRun = expedition.new({ money = expedition.shopGearCost })
    local shopBought, shopGearId = expedition.buyShopGear(shopBuyRun, galaxyId)
    assert(shopBought and shopGearId == expedition.galaxyGearId(galaxyId))
    assert(shopBuyRun.ownedGear[shopGearId], "buying at the shop planet must grant the galaxy-unique gear")
    assert(shopBuyRun.money == 0)
    local shopBoughtAgain = expedition.buyShopGear(shopBuyRun, galaxyId)
    assert(not shopBoughtAgain, "cannot buy the same galaxy's shop gear twice")
    local poorShopRun = expedition.new({ money = 1 })
    assert(not expedition.buyShopGear(poorShopRun, "galaxy:other"),
        "buying shop gear without enough money must fail")

    -- Item 8: an ordinary planet sample must not become money on its
    -- own -- only checkpointSettle/Earth settle convert it.
    local sampleRun = expedition.new()
    sampleRun.phase = "ascending"
    local ok, awarded = expedition.collectSample(sampleRun, 20)
    assert(ok and awarded > 0)
    assert(sampleRun.money == 0, "collecting a sample must not directly award money")
    assert(sampleRun.pendingSampleValue == awarded)

    -- Item 8: docking at a galaxy checkpoint mid-expedition settles the
    -- pending sample value into money without ending the expedition.
    local settled, amount = expedition.checkpointSettle(sampleRun)
    assert(settled and amount == awarded)
    assert(sampleRun.money == awarded, "checkpoint settlement must bank pending sample value as money")
    assert(sampleRun.pendingSampleValue == 0)
    assert(sampleRun.phase == "ascending", "checkpoint settlement must not end the expedition")

    -- Calling checkpointSettle again with nothing pending must be a no-op.
    local settledAgain, amountAgain = expedition.checkpointSettle(sampleRun)
    assert(not settledAgain and amountAgain == 0)

    -- Item 8: checkpointSettle must not fire outside the ascending phase
    -- (mirrors "일반 행성 근접만으로는 정산되지 않는다" -- no settlement
    -- source other than an explicit checkpoint/Earth trigger).
    local launchPhaseRun = expedition.new()
    launchPhaseRun.pendingSampleValue = 50
    local blockedOk = expedition.checkpointSettle(launchPhaseRun)
    assert(not blockedOk, "checkpointSettle must require the ascending phase")

    -- Item 9 rule preserved: full meta wipe (destroy) also clears gear
    -- ownership and explored checkpoints, consistent with ownedShips.
    local wipeRun = expedition.new()
    wipeRun.phase = "ascending"
    wipeRun.durability = 1
    expedition.exploreCheckpoint(wipeRun, galaxyId)
    assert(next(wipeRun.ownedGear) ~= nil)
    expedition.damage(wipeRun, 5)
    assert(wipeRun.phase == "destroyed")
    assert(next(wipeRun.ownedGear) == nil, "destruction must wipe owned gear")
    assert(next(wipeRun.exploredCheckpoints) == nil, "destruction must wipe explored checkpoints")
end

-- docs/feedback/INBOX.md 처리대기 항목 15(a): M.returnToEarth is the new,
-- additive immediate-settlement entry point that lets the ascending phase
-- go straight to settlement (mirroring item 8's checkpoint-settle model)
-- without the manually-declared beginReturn/"returning" phase travel-down
-- step or its in-flight slot machine. It must settle pending sample AND
-- slot-reward value exactly like the existing returning-phase-reaches-
-- altitude-0 path, only from "ascending" directly.
local function testReturnToEarth()
    local expedition = require("game.expedition")

    local run = expedition.new()
    expedition.launch(run)
    run.altitude = 250
    run.maxAltitude = 250
    run.pendingSampleValue = 60
    assert(expedition.returnToEarth(run), "returnToEarth must succeed from the ascending phase")
    assert(run.phase == "settlement", "returnToEarth must settle immediately, skipping the returning phase")
    assert(run.money == 60, "returnToEarth must pay out pending sample value, like the old returning-phase settle")
    assert(run.pendingSampleValue == 0)
    assert(run.lastSettlement == 60)
    assert(run.lastAltitude == 250)

    -- Only valid from the ascending phase -- launch/settlement/destroyed/
    -- returning must all reject it (no state mutation).
    local launchRun = expedition.new()
    assert(not expedition.returnToEarth(launchRun), "returnToEarth must require the ascending phase (launch)")
    local settledRun = expedition.new()
    expedition.launch(settledRun)
    settledRun.altitude = 10
    settledRun.maxAltitude = 10
    expedition.returnToEarth(settledRun)
    assert(not expedition.returnToEarth(settledRun),
        "returnToEarth must require the ascending phase (already settlement)")
end

-- docs/feedback/INBOX.md 처리대기 항목 15(b)/(c): the EARTH SHOP now hosts
-- its own paid slot-machine minigame (M.spinEarthShopSlot), separate from
-- the in-flight returning-phase slot machine, whose odds vary by which
-- galaxy's checkpoint was most recently explored this expedition
-- (M.galaxySlotProfile / run.lastCheckpointGalaxyId).
local function testEarthShopSlotMachine()
    local expedition = require("game.expedition")

    -- No checkpoint explored yet, or the home galaxy explicitly, both use
    -- the standard (in-flight) odds table.
    assert(expedition.galaxySlotProfile(nil) == expedition.homeSlotProfile)
    assert(expedition.galaxySlotProfile("milkyway") == expedition.homeSlotProfile)

    -- Exploring a galaxy checkpoint records it as the most recent for the
    -- EARTH SHOP slot machine's odds lookup.
    local run = expedition.new()
    run.phase = "ascending"
    local galaxyId = "galaxy:9:9"
    expedition.exploreCheckpoint(run, galaxyId)
    assert(run.lastCheckpointGalaxyId == galaxyId)
    -- Re-exploring the same checkpoint (a no-op for the gear grant) still
    -- keeps the most-recent-galaxy bookkeeping current.
    expedition.exploreCheckpoint(run, galaxyId)
    assert(run.lastCheckpointGalaxyId == galaxyId)

    -- galaxySlotProfile is deterministic (same id -> same table every call)
    -- and always one of the three known tables.
    local profileA = expedition.galaxySlotProfile(galaxyId)
    local profileB = expedition.galaxySlotProfile(galaxyId)
    assert(profileA == profileB, "galaxySlotProfile must be deterministic for the same galaxy id")
    assert(profileA == expedition.safeSlotProfile or profileA == expedition.riskySlotProfile,
        "a non-home galaxy must use one of the two variant tables, never the home table")

    -- Find at least one galaxy id hashing into each variant bucket so both
    -- tables are exercised (not just whichever one galaxyId happens to hit).
    local sawSafe, sawRisky = false, false
    for i = 1, 200 do
        local candidateId = "galaxy:" .. i .. ":test"
        local profile = expedition.galaxySlotProfile(candidateId)
        if profile == expedition.safeSlotProfile then sawSafe = true end
        if profile == expedition.riskySlotProfile then sawRisky = true end
    end
    assert(sawSafe and sawRisky, "galaxySlotProfile must produce both variant tables across many galaxy ids")

    -- The risky/high-payout table must have a strictly higher expected
    -- value than the safe table (matching "고배당/위험부담형" from the brief).
    local safeEv = expedition.earthShopSlotExpectedValue("__force_safe__")
    local riskyEv = expedition.earthShopSlotExpectedValue("__force_risky__")
    -- Not guaranteed which bucket these two ids land in, so instead compare
    -- the known tables' EVs directly via the home/safe/risky profiles.
    local function evOf(profile)
        local totalWeight = 0
        for symbol, weight in pairs(profile) do totalWeight = totalWeight + weight end
        local total = 0
        for _, a in ipairs(expedition.slotSymbols) do
            for _, b in ipairs(expedition.slotSymbols) do
                for _, c in ipairs(expedition.slotSymbols) do
                    local p = (profile[a] / totalWeight) * (profile[b] / totalWeight) * (profile[c] / totalWeight)
                    total = total + p * expedition.slotReward({ a, b, c })
                end
            end
        end
        return total
    end
    assert(evOf(expedition.riskySlotProfile) > evOf(expedition.safeSlotProfile),
        "the risky galaxy odds table must pay out more on average than the safe table")
    assert(safeEv > 0 and riskyEv > 0)

    -- M.spinEarthShopSlot only works in the settlement phase, costs a flat
    -- fee, and uses whichever galaxy's odds table was last explored.
    local shopRun = expedition.new({ money = 100 })
    shopRun.lastCheckpointGalaxyId = galaxyId
    assert(not expedition.spinEarthShopSlot(shopRun), "EARTH SHOP slot must require the settlement phase")
    shopRun.phase = "settlement"
    local rolls = { 5, 5, 5 }
    local nextRoll = 0
    shopRun.slotRandom = function()
        nextRoll = nextRoll + 1
        return rolls[nextRoll]
    end
    local spun, symbols, reward = expedition.spinEarthShopSlot(shopRun)
    assert(spun and symbols and reward >= 0)
    assert(shopRun.money == 100 - expedition.earthShopSlotCost + reward)
    assert(shopRun.lastEarthShopSlotGalaxyId == galaxyId)

    -- Cannot spin without enough money for the flat fee.
    local poorRun = expedition.new({ money = expedition.earthShopSlotCost - 1 })
    poorRun.phase = "settlement"
    assert(not expedition.spinEarthShopSlot(poorRun), "EARTH SHOP slot must require enough money for the fee")
end

-- docs/feedback/INBOX.md 처리대기 항목 7/8 UI 연결부: PlayScene.update must
-- actually dock at a galaxy's hub/shop landmarks discovered via
-- world.nearbyPlanets -- exploring the hub grants gear + settles pending
-- samples, and proximity to the shop planet unlocks the "b" buy-gear key.
-- Own top-level function for the same 200-local limit as testJoystick.
local function testCheckpointAndShopDocking()
    local world = require("game.world")
    local expedition = require("game.expedition")

    -- Find a non-home galaxy so hubPlanet/shopPlanet are non-nil.
    local galaxy
    for gx = -20, 20 do
        for gy = -20, 20 do
            if not (gx == 0 and gy == 0) then
                local candidate = world.galaxy(gx, gy)
                if candidate then galaxy = candidate; break end
            end
        end
        if galaxy then break end
    end
    assert(galaxy, "need at least one non-home galaxy for docking test")
    local hub = world.hubPlanet(galaxy)
    local shop = world.shopPlanet(galaxy)

    -- Docking at the checkpoint hub while ascending grants the galaxy's
    -- unique gear and settles any pending sample value into money without
    -- ending the expedition.
    local hubScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    hubScene.expedition.phase = "ascending"
    hubScene.expedition.pendingSampleValue = 30
    hubScene.ship.x, hubScene.ship.y = hub.x, hub.y
    hubScene:update(0)
    local expectedGearId = expedition.galaxyGearId(galaxy.id)
    assert(hubScene.expedition.ownedGear[expectedGearId],
        "docking at the hub checkpoint must grant the galaxy's unique gear")
    assert(hubScene.expedition.money == 30,
        "docking at the hub checkpoint while ascending must settle pending sample value")
    assert(hubScene.expedition.pendingSampleValue == 0)
    assert(hubScene.expedition.phase == "ascending",
        "checkpoint docking must not end the expedition")

    -- Re-visiting the same hub in the same run must not re-grant gear or
    -- re-settle (idempotent -- discovered[] guards it once per run).
    hubScene.expedition.pendingSampleValue = 10
    hubScene:update(0)
    assert(hubScene.expedition.money == 30, "re-docking at the same hub must not double-settle")

    -- Docking at a galaxy's shop planet does not auto-grant gear, but does
    -- track proximity so keypressed("b") can offer a paid purchase.
    local shopScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    shopScene.expedition.phase = "ascending"
    shopScene.expedition.money = expedition.shopGearCost
    shopScene.ship.x, shopScene.ship.y = shop.x, shop.y
    shopScene:update(0)
    assert(shopScene.dockedShopPlanetId == shop.id,
        "proximity to the shop planet must record it as docked")
    assert(not shopScene.expedition.ownedGear[expedition.galaxyGearId(galaxy.id)],
        "arriving at the shop planet must not auto-grant gear (payment required)")
    shopScene:keypressed("b")
    assert(shopScene.expedition.ownedGear[expedition.galaxyGearId(galaxy.id)],
        "pressing b while docked at the shop planet must buy the galaxy's unique gear")
    assert(shopScene.expedition.money == 0)

    -- Moving away from the shop planet clears the docked flag so the buy
    -- key no longer applies.
    shopScene.ship.x, shopScene.ship.y = shop.x + 5000, shop.y + 5000
    shopScene:update(0)
    assert(shopScene.dockedShopPlanetId == nil,
        "leaving the shop planet's vicinity must clear the docked flag")
end

-- docs/feedback/INBOX.md 처리대기 항목 15(b) UI wiring: the settlement
-- phase's "m" key must actually reach expedition.spinEarthShopSlot through
-- PlayScene:keypressed, since the engine-only entry point added by a prior
-- slice was not yet reachable from real play. Own top-level function for
-- the same 200-local limit as testJoystick.
-- docs/feedback/INBOX.md 처리대기 항목 7-c UI wiring: EARTH SHOP's generic
-- gear purchase path (expedition.buyEarthGear/nextBuyableEarthGear) had a
-- complete engine API since the first item-7 slice but was never called
-- from PlayScene:keypressed, leaving it unreachable from real play (only
-- the galaxy-unique shop-planet purchase, "b", and checkpoint drops were
-- wired). Own top-level function for the same 200-local limit as
-- testJoystick.
local function testEarthGearShopUiWiring()
    local expedition = require("game.expedition")

    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scene.expedition.phase = "settlement"
    scene.expedition.money = 1000
    local firstGeneric = expedition.genericGearCatalog[1]
    scene:keypressed("n")
    assert(scene.expedition.ownedGear[firstGeneric.id],
        "settlement 'n' key must buy the first unowned generic EARTH SHOP gear part")
    assert(scene.expedition.money == 1000 - firstGeneric.cost)
    assert(scene.message:find("EARTH GEAR BOUGHT"), "purchase message must confirm the bought item: " .. tostring(scene.message))

    -- Pressing "n" again buys the next unowned generic part, not the same one.
    local secondGeneric = expedition.genericGearCatalog[2]
    scene:keypressed("n")
    assert(scene.expedition.ownedGear[secondGeneric.id],
        "second 'n' press must buy the next unowned generic part, skipping the already-owned first one")

    -- Once every generic part is owned, "n" reports that state instead of
    -- silently no-op'ing or erroring.
    for _, entry in ipairs(expedition.genericGearCatalog) do
        scene.expedition.ownedGear[entry.id] = true
    end
    scene:keypressed("n")
    assert(scene.message:find("ALL EARTH GEAR OWNED"), "message must report all generic gear owned: " .. tostring(scene.message))

    -- Insufficient funds surfaces the same shortfall messaging pattern used
    -- by the other settlement purchase keys, rather than silently no-op'ing.
    local poorScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    poorScene.expedition.phase = "settlement"
    poorScene.expedition.money = expedition.genericGearCatalog[1].cost - 1
    poorScene:keypressed("n")
    assert(not poorScene.expedition.ownedGear[expedition.genericGearCatalog[1].id],
        "insufficient funds must not grant the gear")
    assert(poorScene.expedition.money == expedition.genericGearCatalog[1].cost - 1,
        "insufficient funds must not deduct any money")
    assert(poorScene.message:find("EARTH GEAR"), "shortfall message must name the earth gear item: " .. tostring(poorScene.message))

    -- Wrong phase (e.g. ascending) must not buy at all.
    local flightScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    flightScene.expedition.phase = "ascending"
    flightScene.expedition.money = 1000
    flightScene:keypressed("n")
    assert(not flightScene.expedition.ownedGear or not flightScene.expedition.ownedGear[expedition.genericGearCatalog[1].id],
        "'n' key must be a no-op outside the settlement phase")
    assert(flightScene.expedition.money == 1000, "'n' key must not deduct money outside the settlement phase")
end

local function testEarthShopSlotUiWiring()
    local expedition = require("game.expedition")

    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scene.expedition.phase = "settlement"
    scene.expedition.money = 100
    scene.expedition.lastCheckpointGalaxyId = nil
    scene:keypressed("m")
    assert(scene.expedition.money == 100 - expedition.earthShopSlotCost + scene.expedition.lastEarthShopSlotReward,
        "settlement 'm' key must spin the EARTH SHOP slot machine and reflect its payout")
    assert(scene.message:find("SLOT"), "spin result message must mention the slot outcome: " .. tostring(scene.message))

    -- Insufficient funds surfaces the same shortfall messaging pattern used
    -- by the other settlement purchase keys, rather than silently no-op'ing.
    local poorScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    poorScene.expedition.phase = "settlement"
    poorScene.expedition.money = expedition.earthShopSlotCost - 1
    poorScene:keypressed("m")
    assert(poorScene.expedition.money == expedition.earthShopSlotCost - 1,
        "insufficient funds must not deduct the slot fee")
    assert(poorScene.message:find("SLOT SPIN"), "shortfall message must name the slot spin item: " .. tostring(poorScene.message))

    -- Wrong phase (e.g. ascending) must not spin at all.
    local flightScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    flightScene.expedition.phase = "ascending"
    flightScene.expedition.money = 100
    flightScene:keypressed("m")
    assert(flightScene.expedition.money == 100, "'m' key must be a no-op outside the settlement phase")
end

-- docs/feedback/INBOX.md 처리대기 항목 15(a) UI wiring: the additive
-- expedition.returnToEarth(run) engine entry point (prior slice) must
-- actually be reachable from real play via an explicit ascending-phase
-- "return" action, rather than only being exercised directly by
-- game/self_test.lua's testReturnToEarth(). The old beginReturn/"returning"
-- phase and in-flight slot machine have since been fully removed (item
-- 15a completion), so "r" is now the sole return-to-Earth action.
local function testReturnToEarthUiWiring()
    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scene.expedition.phase = "ascending"
    scene.expedition.pendingSampleValue = 40
    scene.expedition.maxAltitude = 250
    scene.expedition.bestAltitude = 250
    scene:keypressed("r")
    assert(scene.expedition.phase == "settlement",
        "'r' while ascending must immediately settle the run at Earth via returnToEarth")
    assert(scene.expedition.money == 40,
        "returnToEarth via 'r' must pay out pending sample value: "
            .. tostring(scene.expedition.money))
    assert(scene.message:find("SETTLED"),
        "settling via 'r' must surface the same settled_message as the old returning path: "
            .. tostring(scene.message))

    -- 'r' must be a no-op outside the ascending phase (e.g. launch).
    local launchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    launchScene.expedition.phase = "launch"
    launchScene:keypressed("r")
    assert(launchScene.expedition.phase == "launch", "'r' must not act outside the ascending phase")
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

-- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
-- fourth/final slice): the LAUNCH LOADOUT STEER SPEED readout gets a small
-- speedometer icon paired with it. Pure-geometry regression test mirroring
-- testHullShieldIcon/testCashCoinIcon: even-length flat polygon list, at
-- least a triangle, spans above and below cy, and horizontally symmetric
-- around cx.
-- docs/feedback/INBOX.md UI/HUD item 6: reassigned to the spaceship-gear
-- lane (2026-09-03 lane-conflict notice) which is rebuilding game/gear.lua
-- as a JSON-backed data loader (item 13). The engine-only prototype catalog
-- this main-lane slice added has been removed to avoid a file conflict at
-- integration time; testGearCatalog() removed along with it.

local function testSteerSpeedIcon()
    local PlayScene = require("game.scenes.play")
    local points = PlayScene.speedIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "speedometer silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "speedometer must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "speedometer outline must be horizontally symmetric around cx")
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
    debrisScene.expedition.durabilityUpgradeLevel = 1
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
    assert(wiped.durabilityUpgradeLevel == 0)
    assert(wiped.bestAltitude == 400)
    assert(debrisScene.message == "SHIP DESTROYED  BEST 400  META RESET")
end

-- docs/feedback/INBOX.md item 11(b): fuel is no longer a flight
-- constraint, so the EARTH SHOP "fuel tank upgrade" purchase (the item
-- that told players "buy more fuel to go further/safer") must not appear
-- as a shop row, touch target, or keyboard purchase. The engine-level
-- expedition.buyFuelUpgrade/fuelUpgradeLevel/fuelUpgradeCost fields have
-- since been removed entirely (see item 11(b) STATUS slice); this test
-- now verifies those symbols are simply gone rather than merely hidden.
local function testFuelUpgradeHiddenFromShop()
    local PlayScene = require("game.scenes.play")
    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scene.expedition.phase = "settlement"
    scene.expedition.money = scene.expedition.durabilityUpgradeCost + 10
    local shop = scene:shopLoadoutLines()
    assert(shop.fuelAction == nil, "EARTH SHOP must not expose a fuel-upgrade action line")
    assert(shop.fuelPreviewForecast == nil, "EARTH SHOP must not preview a fuel-upgrade forecast")
    assert(shop.fuelStatus == nil, "EARTH SHOP must not show a fuel-upgrade affordability status")
    local hasFuelRow = false
    for _, row in ipairs(PlayScene.settlementTouchRows) do
        if row.key == "fuel" then hasFuelRow = true end
        if row.columns then
            for _, column in ipairs(row.columns) do
                if column.key == "fuel" then hasFuelRow = true end
            end
        end
    end
    assert(not hasFuelRow, "settlementTouchRows must not include a fuel purchase target")
    assert(scene.expedition.fuelUpgradeLevel == nil,
        "run.fuelUpgradeLevel must not exist -- the fuel-tank shop upgrade was removed entirely")
    local moneyBefore = scene.expedition.money
    scene:keypressed("f")
    assert(scene.expedition.fuelUpgradeLevel == nil,
        "keypressed('f') must not purchase a fuel upgrade")
    assert(scene.expedition.money == moneyBefore,
        "keypressed('f') must not spend money on a fuel upgrade")
end

-- docs/feedback/INBOX.md item 11(c): once the fuel-tank purchase UI row
-- was removed from EARTH SHOP (item 11b, testFuelUpgradeHiddenFromShop
-- above), the three i18n message keys that only that removed UI surface
-- ever formatted (the "T/F FUEL LV.n>n+1 $50" action line, the
-- "FUEL TANK UPGRADED ..." confirmation message, and the "FUEL UPGRADE"
-- shortfall-message item label) became permanently dead strings with no
-- remaining call site in game/scenes/play.lua. Assert they are gone from
-- both locales so this leftover UI text cannot resurface or mislead a
-- future reader of game/i18n.lua into thinking the purchase still exists.
local function testFuelUpgradeMessagingRemoved()
    local i18n = require("game.i18n")
    local savedLocale = i18n.getLocale()
    for _, locale in ipairs({ "en", "ko" }) do
        i18n.setLocale(locale)
        for _, key in ipairs({ "fuel_action_line", "fuel_upgraded_message", "item_fuel_upgrade" }) do
            local ok = pcall(i18n.t, key)
            assert(not ok, key .. " must be removed from the " .. locale .. " locale")
        end
    end
    i18n.setLocale(savedLocale)
end

-- docs/feedback/INBOX.md 처리대기 항목 11(c): "연료 소진 관련 잔재 UI/문구 전면
-- 제거" and item 15's already-completed removal of the in-flight return
-- phase / slot machine (beginReturn/useSlot/spinSlot/slotFuelBonus/etc.)
-- left several i18n string templates behind that no game/scenes/play.lua
-- call site references anymore -- pure dead strings implying flight is
-- still fuel-gated ("NEXT LAUNCH FUEL +%d", "NEW BEST! FUEL +%d") or that
-- the old in-flight slot machine still exists ("SPINNING...",
-- "WIN +$%d REPAIR +%d", "WIN +$%d FUEL +%d", "WIN +$%d SAMPLE +$%d",
-- "WIN +$%d PENDING $%d", "SPINS (%d) $%d"). Verified via grep across every
-- .lua file in this repo that none of these keys are referenced outside
-- their own game/i18n.lua definitions.
local function testDeadFuelAndSlotMessagingRemoved()
    local i18n = require("game.i18n")
    local savedLocale = i18n.getLocale()
    local deadKeys = {
        "fuel_bonus_line", "newbest_fuel_combined", "spinning_label",
        "win_repair_line", "win_fuel_line", "win_sample_line",
        "win_pending_line", "spins_settlement_line",
    }
    for _, locale in ipairs({ "en", "ko" }) do
        i18n.setLocale(locale)
        for _, key in ipairs(deadKeys) do
            local ok = pcall(i18n.t, key)
            assert(not ok, key .. " must be removed from the " .. locale .. " locale")
        end
    end
    i18n.setLocale(savedLocale)
end

function M.run()
    require("game.i18n").setLocale("en")
    assert(viewport.width == 180 and viewport.height == 320)
    local scale, x, y = viewport.fit(720, 1280, false)
    assert(scale == 4 and x == 0 and y == 0)
    local gx, gy, inside = viewport.toGame(360, 640, 720, 1280, false)
    assert(gx == 90 and gy == 160 and inside)

    local ship = shipModule.new()
    -- docs/feedback/INBOX.md 처리대기 항목 11(c): game/ship.lua's standalone
    -- fuel field and "if ship.fuel > 0" thrust gate were a leftover from the
    -- old fuel-gated-flight design (game/expedition.lua's real flight loop
    -- has never fuel-gated altitude -- see its "Fuel is no longer a flight
    -- constraint" comment). ship.new()/ship.update() are only ever exercised
    -- directly here in tests (game/scenes/play.lua drives its own movement
    -- and only ever *wrote* a dead ship.fuel mirror, never read it), so this
    -- module-local fuel simulation was pure unreachable/misleading residue.
    -- Thrust must now apply unconditionally and the ship table must carry no
    -- fuel field at all.
    shipModule.update(ship, 1, { thrust = true })
    assert(ship.y < 0, "thrust must move the ship regardless of any fuel state")
    assert(ship.fuel == nil,
        "ship must not carry a dead fuel field; flight is fuel-unconstrained")
    local before = ship.angle
    shipModule.update(ship, 1, { right = true })
    assert(ship.angle > before)

    -- docs/feedback/INBOX.md item 11(c): fuel is no longer a flight
    -- constraint anywhere in the game (game/expedition.lua's
    -- maneuverFuel/burnManeuverFuel are no-ops), but game/ship.lua's
    -- M.update still gated thrust on ship.fuel > 0 and locally drained it
    -- -- dead logic modeling the old fuel-limited-flight design. Thrust
    -- must still work with zero fuel, and the `fuel` field (kept only as a
    -- display value synced from run.fuel by game/scenes/play.lua) must not
    -- be drained by thrusting.
    do
        local zeroFuelShip = shipModule.new()
        zeroFuelShip.fuel = 0
        shipModule.update(zeroFuelShip, 1, { thrust = true })
        assert(zeroFuelShip.y < 0, "thrust must work even at zero fuel")
        assert(zeroFuelShip.fuel == 0, "ship.update must not itself drain fuel")
    end

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
    -- docs/feedback/INBOX.md 처리대기 항목 15(a): the manually-declared
    -- beginReturn/"returning" phase, its approachWarning sample-preview
    -- suppression, and the in-flight slot-odds HUD line have all been
    -- fully removed -- approachWarning only ever fires during "ascending"
    -- now (asserted below via collisionRisk's own phase gate), and there
    -- is no more "returning" phase to test HUD earn/returnProgress
    -- fields for (hudLines() no longer produces them in any phase).
    assert(riskScene:approachWarning({ id = "no-returning-phase", y = -500 }, 165, 185) ~= nil,
        "approachWarning must still fire during ascending")
    riskScene.expedition.sampleCount = 3
    riskScene.expedition.pendingSampleValue = 95

    -- docs/feedback/INBOX.md UI/HUD item 4: the "개발 임시본"/"DEV PLACEHOLDER"
    -- footer is a permanent dev-only disclaimer, not gameplay info, so it
    -- must render smaller and dimmer than ordinary HUD text instead of
    -- competing with the message line above it (real LÖVE runtime capture
    -- previously showed it at full 14px default font and 0.85 alpha).
    assert(PlayScene.devPlaceholderFontSize and PlayScene.devPlaceholderFontSize < 14,
        "devPlaceholderFontSize must exist and be smaller than the default HUD font size")
    assert(PlayScene.devPlaceholderAlpha and PlayScene.devPlaceholderAlpha < 0.85,
        "devPlaceholderAlpha must exist and be dimmer than the previous 0.85 opacity")
    riskScene.expedition.phase = "settlement"
    -- Fuel is no longer a flight constraint (game/expedition.lua's
    -- M.maneuverFuel/M.burnManeuverFuel are no-ops), so the HUD status line
    -- no longer shows a "F%03d" fuel readout that implied a fuel cap still
    -- gated flight (docs/feedback/INBOX.md UI/HUD item 3).
    assert(riskScene:hudLines().status == "H3/3 SETTLE")
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
    returnCollisionScene.expedition.money = returnCollisionScene.expedition.durabilityUpgradeCost
        + returnCollisionScene.expedition.scoutShipCost + 25
    assert(expedition.buyDurabilityUpgrade(returnCollisionScene.expedition))
    assert(expedition.buyShip(returnCollisionScene.expedition, "scout"))
    assert(expedition.selectShip(returnCollisionScene.expedition, "scout"))
    assert(expedition.launch(returnCollisionScene.expedition))
    -- docs/feedback/INBOX.md 처리대기 항목 15(a): the manually-declared
    -- "returning" phase no longer exists -- destruction is exercised here
    -- during "ascending" (the only phase a lethal collision can now
    -- happen in) instead.
    returnCollisionScene.expedition.altitude = 500
    returnCollisionScene.expedition.durability = 2
    returnCollisionScene.expedition.sampleCount = 2
    returnCollisionScene.expedition.pendingSampleValue = 80
    returnCollisionScene.ship.y = -500
    -- Mark the planet already-discovered so this update only exercises the
    -- collision/damage path below, not the ascending-phase sample-pickup
    -- branch (both are keyed off the same proximity check now that this
    -- collision happens during "ascending" instead of the removed
    -- "returning" phase -- see comment above).
    returnCollisionScene.discovered["return-collision"] = true
    nearbyPlanets = world.nearbyPlanets
    world.nearbyPlanets = function()
        return { { id = "return-collision", x = 0, y = -500, radius = 7 } }
    end
    returnCollisionScene:update(0)
    world.nearbyPlanets = nearbyPlanets
    local wipedReturn = returnCollisionScene.expedition
    assert(wipedReturn.phase == "destroyed" and wipedReturn.durability == 0)
    assert(wipedReturn.money == 0 and wipedReturn.sampleCount == 0
        and wipedReturn.pendingSampleValue == 0)
    assert(wipedReturn.durabilityUpgradeLevel == 0)
    assert(wipedReturn.selectedShipId == "starter" and not wipedReturn.ownedShips.scout)
    assert(wipedReturn.bestAltitude == 750)
    assert(returnCollisionScene.message == "SHIP DESTROYED  BEST 750  META RESET")
    assert(wipedReturn.lastLostSampleCount == 2 and wipedReturn.lastLostSampleValue == 80)
    assert(expedition.launch(wipedReturn))
    assert(wipedReturn.lastLostSampleCount == 0 and wipedReturn.lastLostSampleValue == 0)

    local run = expedition.new({
        fuel = 2,
        fuelBurnRate = 1,
        climbSpeed = 60,
        slotDistance = 100,
    })
    assert(run.phase == "launch" and run.altitude == 0)
    assert(expedition.launch(run) and run.phase == "ascending")
    expedition.update(run, 1)
    assert(run.phase == "ascending" and run.fuel == nil and run.altitude == 60)
    assert(expedition.collectSample(run, 75))
    assert(run.sampleCount == 1 and run.pendingSampleValue == 75 and run.money == 0)
    expedition.update(run, 1)
    assert(run.phase == "ascending" and run.fuel == nil and run.altitude == 120)
    -- docs/feedback/INBOX.md 처리대기 항목 15(a): returnToEarth is the sole
    -- return-to-Earth entry point now (beginReturn/"returning"/useSlot
    -- fully removed) -- it settles immediately from "ascending".
    assert(expedition.returnToEarth(run))
    assert(run.phase == "settlement" and run.altitude == 0)
    assert(run.money == 75 and run.lastSettlement == 75)
    assert(run.lastSampleSettlement == 75)
    assert(run.sampleCount == 0 and run.pendingSampleValue == 0)
    assert(run.lastSampleCount == 1)
    assert(run.lastAltitude == 120)
    assert(run.lastNewBest == true)
    expedition.update(run, 1)
    assert(run.money == 75 and run.lastSettlement == 75)
    assert(run.lastSampleSettlement == 75)
    assert(run.lastAltitude == 120)
    assert(run.lastNewBest == true)
    assert(expedition.launch(run) and run.lastSampleCount == 0)
    assert(run.lastAltitude == 0)

    -- docs/feedback/INBOX.md item 11(b): the fuel-tank shop upgrade
    -- (buyFuelUpgrade/fuelUpgradeLevel/fuelUpgradeCost/fuelUpgradeAmount)
    -- has been removed entirely -- maxFuel is fixed by the selected ship
    -- alone and no longer purchasable.
    local shopRun = expedition.new({
        fuel = 10,
        money = 75,
    })
    assert(expedition.buyFuelUpgrade == nil, "expedition.buyFuelUpgrade must not exist")
    assert(shopRun.fuelUpgradeLevel == nil and shopRun.fuelUpgradeCost == nil
        and shopRun.fuelUpgradeAmount == nil)
    shopRun.phase = "settlement"
    assert(shopRun.maxFuel == 10, "maxFuel must stay at the base ship value with no upgrade path")
    shopRun.maxAltitude = 120
    assert(expedition.launch(shopRun) and shopRun.phase == "ascending")
    assert(shopRun.fuel == nil and shopRun.altitude == 0 and shopRun.maxAltitude == 0 and shopRun.lastSettlement == 0)

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
    assert(expedition.launch(shipShopRun) and shipShopRun.fuel == nil and shipShopRun.durability == 2)
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
    -- docs/feedback/INBOX.md item 11(b): fuel-tank purchase is no longer a
    -- shop/keyboard action, nor an engine API at all -- maxFuel is fixed
    -- at the selected ship's base value and never varies from a purchase.
    assert(expedition.buyFuelUpgrade == nil, "expedition.buyFuelUpgrade must not exist")
    shopScene.expedition.money = shopScene.expedition.durabilityUpgradeCost + 10
    shopScene:keypressed("h")
    assert(shopScene.expedition.durabilityUpgradeLevel == 1 and shopScene.expedition.maxDurability == 4)
    assert(shopScene.expedition.money == 10)
    assert(shopScene.message
        == "HULL UPGRADED  LV.1  HULL 4  REACH 600  SLOTS 6  BALANCE $10")
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
    -- docs/feedback/INBOX.md item 11(b): with the fuel-tank shop upgrade
    -- removed, the scout's REACH forecast here reflects its base+bonus
    -- fuel alone (100 base + 40 scout bonus = 140 fuel), not a previously
    -- purchased fuel tank.
    assert(shopScene.message
        == "SCOUT PURCHASED AND SELECTED  HULL 3  REACH 840  SLOTS 9  BALANCE $20")

    local scoutFuelMessageScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scoutFuelMessageScene.expedition.phase = "settlement"
    scoutFuelMessageScene.expedition.money = scoutFuelMessageScene.expedition.scoutShipCost + 20
    scoutFuelMessageScene:keypressed("v")
    assert(scoutFuelMessageScene.expedition.selectedShipId == "scout")
    -- docs/feedback/INBOX.md item 11(b): fuel is no longer purchasable, so
    -- maxFuel varies only with the scout ship's own fuel bonus now.
    assert(scoutFuelMessageScene.expedition.maxFuel == 140)
    assert(scoutFuelMessageScene.expedition.money == 20)

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
    -- docs/feedback/INBOX.md item 11(b): fuel is no longer purchasable, so
    -- exercise the repeated-upgrade message path with durability instead.
    repeatedUpgradeMessageScene.expedition.money = 250
    repeatedUpgradeMessageScene:keypressed("h")
    repeatedUpgradeMessageScene:keypressed("h")
    assert(repeatedUpgradeMessageScene.expedition.durabilityUpgradeLevel == 2)
    assert(repeatedUpgradeMessageScene.message
        == "HULL UPGRADED  LV.2  HULL 5  REACH 600  SLOTS 6  BALANCE $100")

    local shortfallScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    shortfallScene.expedition.phase = "settlement"
    shortfallScene.expedition.money = 20
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
    touchScene.expedition.phase = "settlement"
    touchScene.expedition.money = touchScene.expedition.durabilityUpgradeCost
        + touchScene.expedition.scoutShipCost
    touchScene:touchpressed("hull", 45, 208)
    touchScene:touchpressed("ship", 90, 244)
    assert(touchScene.expedition.fuelUpgradeLevel == nil)
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
    assert(starterLoadout.upgrades == "HULL LV.0")
    assert(starterLoadout.forecast == "REACH 600  SLOTS 6")
    assert(starterLoadout.steering == "STEER SPEED 55")
    loadoutScene.expedition.phase = "settlement"
    loadoutScene.expedition.money = loadoutScene.expedition.durabilityUpgradeCost
        + loadoutScene.expedition.scoutShipCost + loadoutScene.expedition.steeringUpgradeCost
    assert(expedition.buyDurabilityUpgrade(loadoutScene.expedition))
    assert(expedition.buyShip(loadoutScene.expedition, "scout"))
    assert(expedition.selectShip(loadoutScene.expedition, "scout"))
    assert(expedition.buySteeringUpgrade(loadoutScene.expedition))
    local upgradedLoadout = loadoutScene:loadoutLines()
    assert(upgradedLoadout.ship == "SHIP SCOUT")
    assert(upgradedLoadout.stats == "HULL 3")
    assert(upgradedLoadout.upgrades == "HULL LV.1")
    assert(upgradedLoadout.forecast == "REACH 840  SLOTS 9")
    assert(upgradedLoadout.steering == "STEER SPEED 70")
    assert(expedition.launch(loadoutScene.expedition))
    assert(expedition.damage(loadoutScene.expedition, loadoutScene.expedition.maxDurability))
    local resetLoadout = loadoutScene:loadoutLines()
    -- Destruction wipes ownedShips back down to only STARTER, so the ship
    -- line is hidden again post-reset for the same reason as above.
    assert(resetLoadout.ship == nil,
        "loadout ship line should be hidden again after a meta-wipe reset")
    assert(resetLoadout.stats == "HULL 3")
    assert(resetLoadout.upgrades == "HULL LV.0")
    assert(resetLoadout.steering == "STEER SPEED 55")

    local nextLaunchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    nextLaunchScene.expedition.phase = "settlement"
    local starterNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(starterNextLaunch.ship == "NEXT STARTER")
    assert(starterNextLaunch.stats == "HULL 3")
    assert(starterNextLaunch.upgrades == "HULL LV.0")
    assert(starterNextLaunch.forecast == "REACH 600  SLOTS 6")
    assert(starterNextLaunch.scoutTradeoff[1] == "SCOUT GAINS +40 FUEL")
    assert(starterNextLaunch.scoutTradeoff[2] == "LOSSES -1 HULL")
    assert(starterNextLaunch.shipAction == "BUY SCOUT $125")
    assert(starterNextLaunch.shipPreview == "SCOUT HULL 2")
    assert(starterNextLaunch.shipPreviewForecast == "REACH 600  SLOTS 6")
    assert(starterNextLaunch.fuelAction == nil)
    assert(starterNextLaunch.fuelPreviewForecast == nil)
    assert(starterNextLaunch.fuelStatus == nil)
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
    nextLaunchScene.expedition.money = 50
    local fuelReadyNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(fuelReadyNextLaunch.fuelAction == nil)
    assert(fuelReadyNextLaunch.hullStatus == "SHORT $25" and not fuelReadyNextLaunch.hullAffordable)
    assert(fuelReadyNextLaunch.shipStatus == "SHORT $75" and not fuelReadyNextLaunch.shipAffordable)
    assert(fuelReadyNextLaunch.yieldStatus == "SHORT $10" and not fuelReadyNextLaunch.yieldAffordable)
    assert(fuelReadyNextLaunch.steeringStatus == "SHORT $15" and not fuelReadyNextLaunch.steeringAffordable)
    nextLaunchScene.expedition.money = 200
    local balancePreviewNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(balancePreviewNextLaunch.fuelAction == nil)
    assert(balancePreviewNextLaunch.hullStatus == "LEFT $125" and balancePreviewNextLaunch.hullAffordable)
    assert(balancePreviewNextLaunch.shipStatus == "LEFT $75" and balancePreviewNextLaunch.shipAffordable)
    assert(balancePreviewNextLaunch.yieldStatus == "LEFT $140" and balancePreviewNextLaunch.yieldAffordable)
    assert(balancePreviewNextLaunch.steeringStatus == "LEFT $135" and balancePreviewNextLaunch.steeringAffordable)
    nextLaunchScene.expedition.money = nextLaunchScene.expedition.durabilityUpgradeCost
        + nextLaunchScene.expedition.scoutShipCost + nextLaunchScene.expedition.sampleYieldUpgradeCost
    local fueledNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(fueledNextLaunch.stats == "HULL 3")
    assert(fueledNextLaunch.upgrades == "HULL LV.0")
    assert(fueledNextLaunch.forecast == "REACH 600  SLOTS 6")
    assert(fueledNextLaunch.fuelAction == nil)
    assert(fueledNextLaunch.hullAction == "T/H HULL LV.0>1 $75")
    assert(fueledNextLaunch.shipPreviewForecast == "REACH 600  SLOTS 6")
    assert(fueledNextLaunch.fuelPreviewForecast == nil)
    assert(fueledNextLaunch.hullPreview == "HULL 4")
    assert(fueledNextLaunch.hullPreviewForecast == "REACH 600  SLOTS 6")
    nextLaunchScene:keypressed("h")
    local reinforcedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reinforcedNextLaunch.stats == "HULL 4")
    assert(reinforcedNextLaunch.upgrades == "HULL LV.1")
    assert(reinforcedNextLaunch.fuelAction == nil)
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
    assert(scoutNextLaunch.upgrades == "HULL LV.1")
    assert(scoutNextLaunch.forecast == "REACH 840  SLOTS 9")
    assert(scoutNextLaunch.shipPreviewForecast == "REACH 840  SLOTS 9")
    assert(scoutNextLaunch.fuelAction == nil)
    assert(scoutNextLaunch.fuelPreviewForecast == nil)
    assert(scoutNextLaunch.hullAction == "T/H HULL LV.1>2 $75")
    assert(scoutNextLaunch.hullPreview == "HULL 4")
    assert(scoutNextLaunch.hullPreviewForecast == "REACH 840  SLOTS 9")
    assert(scoutNextLaunch.scoutTradeoff[1] == "SCOUT GAINS +40 FUEL")
    assert(scoutNextLaunch.scoutTradeoff[2] == "LOSSES -1 HULL")
    assert(scoutNextLaunch.shipAction == "SELECT STARTER")
    assert(scoutNextLaunch.shipStatus == "OWNED" and scoutNextLaunch.shipAffordable)
    nextLaunchScene:keypressed("v")
    local reselectedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reselectedNextLaunch.ship == "NEXT STARTER")
    assert(reselectedNextLaunch.stats == "HULL 4")
    assert(reselectedNextLaunch.upgrades == "HULL LV.1")
    assert(reselectedNextLaunch.fuelPreviewForecast == nil)
    assert(reselectedNextLaunch.shipAction == "SELECT SCOUT")
    -- docs/feedback/INBOX.md item 11(b): with the fuel-tank shop upgrade
    -- removed, these REACH forecasts reflect each ship's base+bonus fuel
    -- alone (starter 100, scout 140), never a previously purchased tank.
    assert(nextLaunchScene.message
        == "STARTER SELECTED  HULL 4  REACH 600  SLOTS 6")
    nextLaunchScene:touchpressed("ship", 90, 244)
    assert(nextLaunchScene.expedition.selectedShipId == "scout")
    assert(nextLaunchScene.message
        == "SCOUT SELECTED  HULL 3  REACH 840  SLOTS 9")
    assert(nextLaunchScene:shopLoadoutLines().shipAction == "SELECT STARTER")

    local destroyedRun = expedition.new({
        fuel = 10,
        durability = 2,
        fuelBurnRate = 1,
        climbSpeed = 80,
        durabilityUpgradeCost = 40,
        money = 140,
    })
    destroyedRun.phase = "settlement"
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
    assert(destroyedRun.maxFuel == destroyedRun.baseFuel)
    assert(destroyedRun.durabilityUpgradeLevel == 0 and destroyedRun.maxDurability == destroyedRun.baseDurability)
    assert(destroyedRun.bestAltitude == 80)
    assert(destroyedRun.lastLostSampleCount == 1 and destroyedRun.lastLostSampleValue == 70)
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
    persistedScene.expedition.climbSpeed = 60
    assert(expedition.launch(persistedScene.expedition))
    persistedScene.expedition.altitude = 60
    persistedScene.expedition.maxAltitude = 60
    persistedScene.expedition.bestAltitude = 60
    -- "returning" as a run phase was removed by item 15(a) (immediate
    -- settlement replaced it); this just needs any non-launch/settlement
    -- phase to prove persistBestAltitude doesn't depend on or mutate phase.
    persistedScene.expedition.phase = "ascending"
    persistedScene:persistBestAltitude()
    assert(persistedScene.expedition.phase == "ascending" and savedBest == 60)
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
    rowTouchScene.expedition.money = rowTouchScene.expedition.durabilityUpgradeCost
        + rowTouchScene.expedition.scoutShipCost
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
    assert(rowTouchScene.expedition.fuelUpgradeLevel == nil)
    assert(rowTouchScene.expedition.durabilityUpgradeLevel == 1)
    assert(rowTouchScene.expedition.sampleYieldUpgradeLevel == 1)
    assert(rowTouchScene.expedition.steeringUpgradeLevel == 1)
    assert(rowTouchScene.expedition.ownedShips.scout and rowTouchScene.expedition.selectedShipId == "scout")
    assert(rowTouchScene.expedition.phase == "ascending")

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

    -- Omnidirectional joystick movement (docs/GAME_DESIGN.md 이동 방식 개선
    -- 항목 1, "조이스틱을 통해 전방향으로 이동 가능함").
    testJoystick()
    testManeuverFuel()
    testGalaxyStructure()
    testGearAndCheckpointSettlement()
    testReturnToEarth()
    testReturnToEarthUiWiring()
    testEarthShopSlotMachine()
    testCheckpointAndShopDocking()
    testEarthGearShopUiWiring()
    testEarthShopSlotUiWiring()
    testMinimap()
    testDebris()
    testBackgroundStars()
    testLaunchRocketIcon()
    testHullShieldIcon()
    testCashCoinIcon()
    testSteerSpeedIcon()
    testFuelUpgradeHiddenFromShop()
    testFuelUpgradeMessagingRemoved()
    testDeadFuelAndSlotMessagingRemoved()

    print("SPACESHIP_UNIT_OK")
end

return M
