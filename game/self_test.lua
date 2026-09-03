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

    expedition.beginReturn(run)
    assert(run.phase == "returning")
    assert(run.returnDistance == run.maxAltitude)
    assert(run.slotOpportunities >= 1)

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
    assert(home.name == nil,
        "galaxy tables must not carry a hardcoded display string (docs/feedback/INBOX.md i18n gap)")

    -- docs/feedback/INBOX.md 국제화 누락 항목: galaxy display names must be
    -- resolved through i18n.t(), not hardcoded, so switching locale changes
    -- the label without touching game/world.lua.
    local i18n = require("game.i18n")
    local prevLocale = i18n.getLocale()
    i18n.setLocale("en")
    assert(world.galaxyName(home) == "SOLAR SYSTEM")
    i18n.setLocale("ko")
    assert(world.galaxyName(home) == "태양계" or world.galaxyName(home) == i18n.t("galaxy_home"),
        "ko galaxy_home must resolve through i18n, not a hardcoded English string")
    i18n.setLocale(prevLocale)
    assert(world.galaxyName(nil) == nil)

    -- Deterministic real galaxy names (docs/feedback/INBOX.md)
    -- The name must depend deterministically on gx, gy, and exhaust combinations using suffixes.
    local name1 = world.galaxyName(41, -17)
    local name2 = world.galaxyName(41, -17)
    assert(name1 == name2, "galaxyName must be deterministic for the same coordinates")
    
    local nameOther = world.galaxyName(42, -17)
    assert(name1 ~= nameOther, "different coordinates should likely yield different names")
    
    local dummyGalaxy = { gx = 41, gy = -17 }
    assert(world.galaxyName(dummyGalaxy) == name1, "passing the galaxy table should yield the same name as passing gx, gy")


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

    -- Galaxy rings: home view includes the solar-system orbit rings plus
    -- the galaxy disk. docs/feedback/INBOX.md item 1 part 3: the sun is no
    -- longer pinned to Earth's origin -- it has its own deterministic
    -- offset (world.sunPosition) so Earth reads as an orbiting planet.
    assert(originView.sun and (originView.sun.x ~= 0 or originView.sun.y ~= 0),
        "the sun marker must sit away from Earth's origin (item 1 part 3)")
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

    -- Spiral-arm minimap glyph (docs/feedback/INBOX.md item 1 part 1):
    -- the same galaxy must always regenerate the identical spiral point
    -- list (determinism), and a different galaxy overwhelmingly produces a
    -- different shape (arm count and/or rotation).
    local home = world.galaxy(0, 0)
    local spiralA = minimap.spiralPoints(home)
    local spiralB = minimap.spiralPoints(home)
    assert(#spiralA > 0, "spiralPoints must produce points for a real galaxy")
    assert(#spiralA == #spiralB, "spiralPoints must be deterministic (same point count)")
    for i = 1, #spiralA do
        assert(math.abs(spiralA[i].x - spiralB[i].x) < 1e-9 and math.abs(spiralA[i].y - spiralB[i].y) < 1e-9,
            "spiralPoints must be deterministic (same coordinates)")
    end
    local otherSpiral = minimap.spiralPoints(foundGalaxy)
    local sameArmCount = minimap.spiralArmCount(home) == minimap.spiralArmCount(foundGalaxy)
    local sameRotation = math.abs(minimap.spiralRotation(home) - minimap.spiralRotation(foundGalaxy)) < 1e-9
    assert(not (sameArmCount and sameRotation),
        "two different galaxies must not produce an identical spiral arm count + rotation")

    -- Crossing into a different galaxy swaps view.spiral/spiralGalaxyId to
    -- that galaxy's own shape.
    local homeSpiralView = minimap.view(0, 0)
    assert(homeSpiralView.spiralGalaxyId == "milkyway")
    assert(homeSpiralView.spiral and #homeSpiralView.spiral > 0)
    local otherGalaxyView = minimap.view(foundGalaxy.x, foundGalaxy.y)
    assert(otherGalaxyView.spiralGalaxyId == foundGalaxy.id,
        "minimap.view must report the containing galaxy's own id for its spiral")
    assert(otherGalaxyView.spiralGalaxyId ~= homeSpiralView.spiralGalaxyId,
        "moving into a different galaxy must switch which spiral is drawn")

    -- Sun-centered solar system (item 1 part 3): the home galaxy's sun sits
    -- at its own deterministic point distinct from Earth (world origin),
    -- and the milkyway spiral must pivot on that sun, not on (0, 0).
    local homeSun = world.sunPosition(home)
    assert(homeSun and (math.abs(homeSun.x) > 1e-6 or math.abs(homeSun.y) > 1e-6),
        "the sun must not sit exactly on Earth's origin")
    local homeSunAgain = world.sunPosition(world.galaxy(0, 0))
    assert(math.abs(homeSun.x - homeSunAgain.x) < 1e-9 and math.abs(homeSun.y - homeSunAgain.y) < 1e-9,
        "sunPosition must be deterministic for the same galaxy")
    -- Every home-galaxy spiral point must be measured from the sun, not
    -- from Earth: at t=1 (outermost arm sample) the point sits `radius`
    -- world-units from the sun, not from the origin.
    local homeSpiralPoints = minimap.spiralPoints(home)
    local outer = homeSpiralPoints[minimap.spiralPointsPerArm]
    local distFromSun = math.sqrt((outer.x - homeSun.x) ^ 2 + (outer.y - homeSun.y) ^ 2)
    assert(math.abs(distFromSun - home.radius) < 1e-6,
        "milkyway spiral arms must be centered on the sun, not on Earth's origin")
    -- Every other galaxy's "sun" is just its own center (galaxy.x, galaxy.y)
    -- -- it's already the pivot both the spiral and the checkpoint hub use.
    local otherSun = world.sunPosition(foundGalaxy)
    assert(otherSun.x == foundGalaxy.x and otherSun.y == foundGalaxy.y,
        "a non-home galaxy's sun is simply its own center")
    -- minimap.view()'s reported sun marker must differ from its Earth
    -- marker for a ship sitting at Earth (world origin) -- previously both
    -- were the same point.
    assert(homeSpiralView.sun.x ~= homeSpiralView.earth.x or homeSpiralView.sun.y ~= homeSpiralView.earth.y,
        "the sun marker must be a different chart position than the Earth marker")

    -- Checkpoint star glyph (item 1 part 2): a small, distinct polygon
    -- (10 points for a 5-point star) rather than the old oversized ring.
    local starPts = minimap.starPoints(0, 0, 10)
    assert(#starPts == 20, "star glyph must have 5 spikes = 10 vertices = 20 flat coords")
    assert(minimap.markerGalaxyHubRadius < minimap.markerGalaxyHubRingRadius,
        "checkpoint marker glyph radius must be smaller than the old oversized ring radius it replaces")
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

-- docs/feedback/INBOX.md "UI 대개편 6건" item 5: the launch rocket icon /
-- yellow arrow reads as crude. Gate it off and leave only a smaller, darker
-- translucent-gray "TAP TO LAUNCH"/"탭하여 발사" line with a restrained
-- sine wobble + fade pulse. Pure helpers so this stays headless-testable.
local function testLaunchPromptCue()
    local PlayScene = require("game.scenes.play")
    assert(PlayScene.showLaunchRocketIcon == false,
        "launch rocket/arrow icon should stay hidden (docs/feedback UI overhaul item 5)")
    assert(PlayScene.launchPromptFontSize ~= nil
            and PlayScene.launchPromptFontSize < PlayScene.smallFontSize,
        "launch prompt text must be smaller than the scene small font")
    assert(PlayScene.launchPromptFontSize < PlayScene.hudFontSize,
        "launch prompt text must be smaller than the HUD font")
    local rgb = PlayScene.launchPromptRgb
    assert(type(rgb) == "table" and #rgb >= 3,
        "launchPromptRgb must be an {r,g,b} table")
    for i = 1, 3 do
        assert(rgb[i] > 0 and rgb[i] < 0.6,
            "launch prompt color must be a dark gray, not bright/yellow")
    end
    local spread = math.max(rgb[1], rgb[2], rgb[3]) - math.min(rgb[1], rgb[2], rgb[3])
    assert(spread < 0.12, "launch prompt color must be gray (low chroma), not yellow")

    local a0 = PlayScene.launchPromptAlpha(0)
    local a1 = PlayScene.launchPromptAlpha(0.8)
    local a2 = PlayScene.launchPromptAlpha(0)
    assert(a0 == a2, "launchPromptAlpha must be deterministic")
    assert(a0 > 0.2 and a0 < 0.75, "launchPromptAlpha(0) out of restrained translucent range")
    assert(a1 > 0.2 and a1 < 0.75, "launchPromptAlpha(0.8) out of restrained translucent range")
    assert(a0 ~= a1, "launchPromptAlpha must pulse over time")
    assert(a0 < 1 and a1 < 1, "launch prompt must stay translucent")

    local x0, y0 = PlayScene.launchPromptOffset(0)
    local x1, y1 = PlayScene.launchPromptOffset(0.7)
    local x2, y2 = PlayScene.launchPromptOffset(0)
    assert(x0 == x2 and y0 == y2, "launchPromptOffset must be deterministic")
    assert(math.abs(x0) <= 6 and math.abs(y0) <= 6,
        "launchPromptOffset(0) wobble must stay a few pixels")
    assert(math.abs(x1) <= 6 and math.abs(y1) <= 6,
        "launchPromptOffset(0.7) wobble must stay a few pixels")
    assert(x0 ~= x1 or y0 ~= y1, "launchPromptOffset must wobble over time")
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

-- docs/feedback/INBOX.md UI/HUD item 2 leftover (STATUS next slice):
-- HUD distance already says DIST/거리, but EARTH SHOP and SHIP DESTROYED
-- summary cards still printed PEAK ALT / 최고고도. User-facing copy must
-- match the distance-from-Earth wording; format arg stays a single integer.
local function testPeakDistLine()
    local i18n = require("game.i18n")
    i18n.setLocale("en")
    local en = i18n.t("peak_dist_line", 400)
    assert(en == "PEAK DIST 400",
        "en settlement peak line must read PEAK DIST N: " .. tostring(en))
    assert(not en:find("ALT"),
        "en peak line must not keep the old ALT label: " .. tostring(en))
    i18n.setLocale("ko")
    local ko = i18n.t("peak_dist_line", 400)
    assert(ko == "최고거리 400",
        "ko settlement peak line must read 최고거리 N: " .. tostring(ko))
    assert(not ko:find("고도"),
        "ko peak line must not keep the old 고도 label: " .. tostring(ko))
    i18n.setLocale("en")
    assert(i18n.locales.en.peak_alt_line == nil,
        "old peak_alt_line key must be removed so leftover ALT copy cannot return")
    assert(i18n.locales.ko.peak_alt_line == nil,
        "old ko peak_alt_line key must be removed")
end

-- docs/feedback/INBOX.md UI/HUD item 3 leftover + STATUS next slice:
-- bankedFuelBonus is consumed as a no-op at launch (no run.fuel field),
-- but settlement/returning still advertise "NEXT LAUNCH FUEL +N" /
-- "WIN +$N FUEL +N". Hide that copy, then delete the gated i18n keys
-- themselves so the leftover fuel framing cannot return. Engine bonus
-- fields stay (econ item 15 owns any later redefinition of the
-- PLANET-triple reward).
local function testFuelBonusTextHidden()
    local i18n = require("game.i18n")
    assert(PlayScene.showFuelBonusText == nil,
        "dead showFuelBonusText gate must be removed, not left false")
    assert(PlayScene.summaryFuelBonusLine == nil,
        "dead summaryFuelBonusLine helper must be removed")
    local leftoverFuelKeys = {
        "fuel_bonus_line",
        "win_fuel_line",
        "slot_result_fuel",
        "newbest_fuel_combined",
    }
    for _, key in ipairs(leftoverFuelKeys) do
        assert(i18n.locales.en[key] == nil,
            "en leftover fuel key must be removed: " .. key)
        assert(i18n.locales.ko[key] == nil,
            "ko leftover fuel key must be removed: " .. key)
    end

    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scene.expedition.bankedFuelBonus = 15
    assert(scene.summaryFuelBonusLine == nil,
        "settlement must not expose a fuel-bonus summary helper")

    local rolls = { 6, 6, 6 }
    local nextRoll = 0
    local fuelScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    fuelScene.expedition.slotRandom = function()
        nextRoll = nextRoll + 1
        return rolls[nextRoll]
    end
    fuelScene.expedition.phase = "returning"
    fuelScene.expedition.altitude = 500
    fuelScene.expedition.slotOpportunities = 1
    fuelScene:keypressed("up")
    fuelScene:update(fuelScene.slotSpin.duration + 0.01)
    assert(fuelScene.message == "PLANET PLANET PLANET +$40  0 LEFT",
        "planet-triple slot message must drop FUEL framing: " .. tostring(fuelScene.message))
    assert(not tostring(fuelScene.message):find("FUEL"),
        "slot completion must not mention FUEL")

    fuelScene.expedition.lastSlotFuelBonus = 15
    fuelScene.expedition.lastSlotReward = 40
    fuelScene.expedition.pendingSlotReward = 40
    fuelScene.expedition.lastSlotRepair = 0
    fuelScene.expedition.lastSlotSampleBonus = 0
    local winLine = PlayScene.slotWinLine(fuelScene.expedition)
    assert(winLine == "WIN +$40  PENDING $40",
        "fuel-bonus WIN line must fall through to pending money: " .. tostring(winLine))
    assert(not winLine:find("FUEL"),
        "slot WIN line must not mention FUEL: " .. tostring(winLine))
end

-- STATUS next slice / UI/HUD item 3 leftover: EARTH SHOP still advertises
-- "SCOUT GAINS +40 FUEL" even though fuel no longer constrains flight.
-- Hide that gain copy in PlayScene. Leave expedition.shipTradeoff alone
-- (econ / item 10 owns any later engine redefinition of scoutFuelBonus).
local function testScoutFuelGainHidden()
    local run = expedition.new()
    local engineTradeoff = expedition.shipTradeoff(run, "scout")
    assert(engineTradeoff.gains[1] and engineTradeoff.gains[1].label == "FUEL",
        "engine scout tradeoff must keep its FUEL gain field for econ/item 10")
    assert(engineTradeoff.losses[1] and engineTradeoff.losses[1].label == "HULL",
        "engine scout hull loss must stay")

    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    scene.expedition.phase = "settlement"
    local lines = PlayScene.scoutTradeoffLines(scene.expedition)
    local joined = table.concat(lines, " | ")
    assert(not joined:find("FUEL"),
        "EARTH SHOP scout tradeoff must not advertise FUEL: " .. joined)
    assert(#lines == 1, "only the still-real hull loss should remain: " .. joined)
    assert(lines[1] == "LOSSES -1 HULL",
        "hull-loss line must stay visible: " .. tostring(lines[1]))

    local shop = scene:shopLoadoutLines()
    assert(shop.scoutTradeoff[1] == "LOSSES -1 HULL")
    assert(shop.scoutTradeoff[2] == nil)
    assert(not table.concat(shop.scoutTradeoff, " "):find("FUEL"))
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
local function testLaunchForecastRemoved()
    -- docs/feedback/INBOX.md UI/HUD item 11(a)
    assert(expedition.launchForecast == nil, "M.launchForecast must be completely removed")
    
    local PlayScene = require("game.scenes.play")
    -- Check that loadout lines do not contain forecast
    local scene = PlayScene.new(expedition.new())
    local loadout = scene:loadoutLines()
    assert(loadout.forecast == nil, "loadout.forecast must be removed")
    
    local shopLoadout = scene:shopLoadoutLines()
    assert(shopLoadout.shipPreviewForecast == nil, "shopLoadout.shipPreviewForecast must be removed")
    assert(shopLoadout.hullPreviewForecast == nil, "shopLoadout.hullPreviewForecast must be removed")
    assert(shopLoadout.forecast == nil, "shopLoadout.forecast must be removed")
end

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

local function testSpecimenSprites()
    local catalog = world.specimenCatalog()
    for _, entry in ipairs(catalog) do
        local path = "assets/sprites/specimens/" .. entry.id .. ".png"
        local info = love.filesystem.getInfo(path, "file")
        assert(info ~= nil, "missing AetherAI free-asset specimen sprite for " .. entry.id)
        assert(info.size > 0)
    end
end

-- docs/feedback/INBOX.md 처리대기 항목: ComfyUI로 실제 에셋 작업 진행 --
-- the ComfyUI-generated ship_default.png (see docs/GENERATED_ASSET_LOG.md)
-- must actually be wired into the running PlayScene as the ship's visual,
-- not just sit unused under assets/. Verify the file exists AND that
-- PlayScene.new() records it as self.shipImagePath (the load target
-- shipImage:draw() actually uses whenever love.graphics is available).
-- shipImage itself cannot be asserted here: conf.lua turns the graphics
-- module fully off under GAME_HEADLESS=1 (this engine-hosted test's own
-- runtime), so love.graphics.newImage never exists and shipImage always
-- stays nil in this process regardless of wiring correctness.
local function testShipSprite()
    local path = "assets/ship/ship_default.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated ship sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.shipImagePath == path,
        "PlayScene must load assets/ship/ship_default.png into self.shipImagePath")
end

-- docs/feedback/INBOX.md 처리대기 항목: ComfyUI로 실제 에셋 작업 진행 --
-- next slice after the ship sprite: the ComfyUI-generated planet texture
-- (assets/planet/planet_generic.png, see docs/GENERATED_ASSET_LOG.md) must
-- be recorded as a real load target on PlayScene, mirroring testShipSprite.
-- planetImage itself cannot be asserted here for the same GAME_HEADLESS=1
-- reason documented above testShipSprite.
local function testPlanetSprite()
    local path = "assets/planet/planet_generic.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated planet sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.planetImagePath == path,
        "PlayScene must load assets/planet/planet_generic.png into self.planetImagePath")
end

-- docs/feedback/INBOX.md 처리대기 항목: ComfyUI로 실제 에셋 작업 진행 --
-- next slice after ship/planet: the launch-screen Earth disc is still two
-- flat love.graphics.circle() fills (ocean blue + two green "continent"
-- blobs), not a ComfyUI-generated texture, even though the AetherAI-only
-- asset rule explicitly lists Earth among the required final visuals.
-- Mirror testShipSprite/testPlanetSprite: verify the file exists AND that
-- PlayScene.new() records it as self.earthImagePath (the load target
-- :draw() actually uses whenever love.graphics is available). earthImage
-- itself cannot be asserted here for the same GAME_HEADLESS=1 reason
-- documented above testShipSprite.
local function testEarthSprite()
    local path = "assets/earth/earth_generic.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated earth sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.earthImagePath == path,
        "PlayScene must load assets/earth/earth_generic.png into self.earthImagePath")
end

-- docs/feedback/INBOX.md 처리대기 항목: ComfyUI로 실제 에셋 작업 진행 --
-- next slice after ship/planet/earth: sample-pickup particles are still
-- plain love.graphics.circle("fill") dots tinted by tier color, not a
-- ComfyUI-generated texture, even though the AetherAI-only asset rule
-- explicitly lists "effects" among the required final visuals. Mirror
-- testShipSprite/testPlanetSprite/testEarthSprite: verify the file exists
-- AND that PlayScene.new() records it as self.sampleEffectImagePath (the
-- load target :draw() actually uses whenever love.graphics is available).
local function testSampleEffectSprite()
    local path = "assets/effects/sample_sparkle.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated sample effect sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.sampleEffectImagePath == path,
        "PlayScene must load assets/effects/sample_sparkle.png into self.sampleEffectImagePath")
end

-- docs/feedback/INBOX.md 처리대기 항목: ComfyUI로 실제 에셋 작업 진행 --
-- next slice after ship/planet/earth/effect: the deep-space backdrop
-- (world.backgroundStars() layer drawn in PlayScene:draw()) is still a
-- Lua love.graphics.points() dot field, not a ComfyUI-generated texture,
-- even though the AetherAI-only asset rule explicitly lists "backgrounds"
-- among the required final visuals. Mirror testSampleEffectSprite: verify
-- the file exists AND that PlayScene.new() records it as
-- self.backgroundImagePath (the load target :draw() actually uses
-- whenever love.graphics is available).
local function testBackgroundSprite()
    local path = "assets/backgrounds/deep_space_tile.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated background sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.backgroundImagePath == path,
        "PlayScene must load assets/backgrounds/deep_space_tile.png into self.backgroundImagePath")
end

-- docs/feedback/INBOX.md 처리대기 항목: ComfyUI로 실제 에셋 작업 진행 --
-- next slice after ship/planet/earth/effect/background: the returning-phase
-- slot machine reel (COMET/PLANET/STAR) is still plain text
-- (table.concat(reels, "  ")), not a ComfyUI-generated icon, even though the
-- AetherAI-only asset rule explicitly lists "slot symbols" among the
-- required final visuals. Mirror testShipSprite/testBackgroundSprite:
-- verify all three symbol files exist AND PlayScene.new() records them as
-- self.slotSymbolImagePaths[symbol] (the load target :draw() actually uses
-- whenever love.graphics is available).
local function testSlotSymbolSprites()
    local play = require("game.scenes.play")
    local scene = play.new()
    local expected = {
        COMET = "assets/slot_symbols/comet.png",
        PLANET = "assets/slot_symbols/planet.png",
        STAR = "assets/slot_symbols/star.png",
    }
    for symbol, path in pairs(expected) do
        local info = love.filesystem.getInfo(path, "file")
        assert(info ~= nil, "missing ComfyUI-generated slot symbol sprite at " .. path)
        assert(info.size > 0)
        assert(scene.slotSymbolImagePaths and scene.slotSymbolImagePaths[symbol] == path,
            "PlayScene must load " .. path .. " into self.slotSymbolImagePaths." .. symbol)
    end
end

-- docs/feedback/INBOX.md "ComfyUI로 실제 에셋 작업 진행" — last remaining
-- piece (shop icons). Same file-existence + always-set-path regression
-- pattern as testSlotSymbolSprites above.
local function testShopIconSprites()
    local play = require("game.scenes.play")
    local scene = play.new()
    local expected = {
        hull = "assets/shop_icons/hull.png",
        steering = "assets/shop_icons/steering.png",
        yield = "assets/shop_icons/yield.png",
        ship = "assets/shop_icons/ship.png",
    }
    for key, path in pairs(expected) do
        local info = love.filesystem.getInfo(path, "file")
        assert(info ~= nil, "missing ComfyUI-generated shop icon sprite at " .. path)
        assert(info.size > 0)
        assert(scene.shopIconImagePaths and scene.shopIconImagePaths[key] == path,
            "PlayScene must load " .. path .. " into self.shopIconImagePaths." .. key)
    end
end

-- GAME_DESIGN.md drifting asteroids/cans/scrap are still Lua shapes, not
-- ComfyUI textures. Same file-existence + always-set-path pattern as
-- testShopIconSprites. Graphics-gated debrisImages cannot be asserted
-- under GAME_HEADLESS=1.
local function testDebrisSprites()
    local play = require("game.scenes.play")
    local scene = play.new()
    local expected = {
        asteroid = "assets/debris/asteroid.png",
        can = "assets/debris/can.png",
        scrap = "assets/debris/scrap.png",
    }
    for kind, path in pairs(expected) do
        local info = love.filesystem.getInfo(path, "file")
        assert(info ~= nil, "missing ComfyUI-generated debris sprite at " .. path)
        assert(info.size > 0)
        assert(scene.debrisImagePaths and scene.debrisImagePaths[kind] == path,
            "PlayScene must load " .. path .. " into self.debrisImagePaths." .. kind)
    end
end

-- Planet-approach twinkle points around undiscovered planets are still
-- love.graphics.circle("fill", ..., 1.2) dots. Same file-existence +
-- always-set-path pattern as testSampleEffectSprite. Graphics-gated
-- planetTwinkleImage cannot be asserted under GAME_HEADLESS=1.
local function testPlanetTwinkleSprite()
    local path = "assets/effects/planet_twinkle.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated planet twinkle sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.planetTwinkleImagePath == path,
        "PlayScene must load assets/effects/planet_twinkle.png into self.planetTwinkleImagePath")
end

-- Collision impact and RCS/main-engine thrust particles are still Lua
-- circles / a triangle plume. Same file-existence + always-set-path
-- pattern as testPlanetTwinkleSprite. Graphics-gated images cannot be
-- asserted under GAME_HEADLESS=1.
local function testCollisionEffectSprite()
    local path = "assets/effects/collision_spark.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated collision effect sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.collisionEffectImagePath == path,
        "PlayScene must load assets/effects/collision_spark.png into self.collisionEffectImagePath")
end

local function testThrustEffectSprite()
    local path = "assets/effects/thrust_plume.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated thrust effect sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.thrustEffectImagePath == path,
        "PlayScene must load assets/effects/thrust_plume.png into self.thrustEffectImagePath")
end

-- Undiscovered-planet rim glow is still stacked love.graphics.circle
-- fills. Same file-existence + always-set-path pattern as
-- testThrustEffectSprite. Graphics-gated planetGlowImage cannot be
-- asserted under GAME_HEADLESS=1.
local function testPlanetGlowSprite()
    local path = "assets/effects/planet_glow.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated planet rim glow sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.planetGlowImagePath == path,
        "PlayScene must load assets/effects/planet_glow.png into self.planetGlowImagePath")
end

-- Planet drop shadows are still a single love.graphics.circle fill.
-- Same file-existence + always-set-path pattern as testPlanetGlowSprite.
-- Graphics-gated planetShadowImage cannot be asserted under GAME_HEADLESS=1.
local function testPlanetShadowSprite()
    local path = "assets/effects/planet_shadow.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated planet drop shadow sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.planetShadowImagePath == path,
        "PlayScene must load assets/effects/planet_shadow.png into self.planetShadowImagePath")
end

-- Minimap chart disc is still a Lua circle fill + line. Same
-- file-existence + always-set-path pattern as testPlanetShadowSprite.
-- Graphics-gated minimapDiscImage cannot be asserted under GAME_HEADLESS=1.
local function testMinimapDiscSprite()
    local path = "assets/effects/minimap_disc.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap disc sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.minimapDiscImagePath == path,
        "PlayScene must load assets/effects/minimap_disc.png into self.minimapDiscImagePath")
end

-- Virtual joystick pad is still a Lua circle fill + line. Same
-- file-existence + always-set-path pattern as testMinimapDiscSprite.
-- Graphics-gated joystickPadImage cannot be asserted under GAME_HEADLESS=1.
local function testJoystickPadSprite()
    local path = "assets/effects/joystick_pad.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated joystick pad sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.joystickPadImagePath == path,
        "PlayScene must load assets/effects/joystick_pad.png into self.joystickPadImagePath")
end

-- Virtual joystick knob is still a Lua circle fill. Same
-- file-existence + always-set-path pattern as testJoystickPadSprite.
-- Graphics-gated joystickKnobImage cannot be asserted under GAME_HEADLESS=1.
local function testJoystickKnobSprite()
    local path = "assets/effects/joystick_knob.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated joystick knob sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.joystickKnobImagePath == path,
        "PlayScene must load assets/effects/joystick_knob.png into self.joystickKnobImagePath")
end

-- HUD CASH coin is still a Lua octagon polygon. Same file-existence +
-- always-set-path pattern as testJoystickKnobSprite. Graphics-gated
-- cashIconImage cannot be asserted under GAME_HEADLESS=1.
local function testCashIconSprite()
    local path = "assets/effects/hud_coin.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated HUD coin sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.cashIconImagePath == path,
        "PlayScene must load assets/effects/hud_coin.png into self.cashIconImagePath")
end

-- HUD hull durability shield is still a Lua pentagon polygon. Same
-- file-existence + always-set-path pattern as testCashIconSprite.
-- Graphics-gated hullIconImage cannot be asserted under GAME_HEADLESS=1.
local function testHullIconSprite()
    local path = "assets/effects/hud_shield.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated HUD shield sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.hullIconImagePath == path,
        "PlayScene must load assets/effects/hud_shield.png into self.hullIconImagePath")
end

-- HUD steering-speed meter is still a Lua semicircle+needle polygon. Same
-- file-existence + always-set-path pattern as testHullIconSprite.
-- Graphics-gated speedIconImage cannot be asserted under GAME_HEADLESS=1.
local function testSpeedIconSprite()
    local path = "assets/effects/hud_speed.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated HUD speedometer sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.speedIconImagePath == path,
        "PlayScene must load assets/effects/hud_speed.png into self.speedIconImagePath")
end

-- Minimap checkpoint-galaxy marker is still a Lua 5-point star polygon
-- (minimap.starPoints). Same file-existence + always-set-path pattern as
-- testSpeedIconSprite. Graphics-gated checkpointStarImage cannot be
-- asserted under GAME_HEADLESS=1.
local function testCheckpointStarSprite()
    local path = "assets/effects/minimap_checkpoint_star.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap checkpoint star sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.checkpointStarImagePath == path,
        "PlayScene must load assets/effects/minimap_checkpoint_star.png into self.checkpointStarImagePath")
end

-- Off-chart checkpoint direction marker is still a Lua circle+triangle
-- polygon. Same file-existence + always-set-path pattern as
-- testCheckpointStarSprite. Graphics-gated checkpointArrowImage cannot
-- be asserted under GAME_HEADLESS=1.
local function testCheckpointArrowSprite()
    local path = "assets/effects/minimap_checkpoint_arrow.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap checkpoint arrow sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.checkpointArrowImagePath == path,
        "PlayScene must load assets/effects/minimap_checkpoint_arrow.png into self.checkpointArrowImagePath")
end

-- Minimap player location marker is still a Lua filled circle + outline.
-- Same file-existence + always-set-path pattern as
-- testCheckpointArrowSprite. Graphics-gated playerMarkerImage cannot
-- be asserted under GAME_HEADLESS=1.
local function testMinimapPlayerSprite()
    local path = "assets/effects/minimap_player.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap player marker sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.playerMarkerImagePath == path,
        "PlayScene must load assets/effects/minimap_player.png into self.playerMarkerImagePath")
end

-- Minimap sun marker is still a Lua filled circle (markerSunRadius).
-- Same file-existence + always-set-path pattern as
-- testMinimapPlayerSprite. Graphics-gated sunMarkerImage cannot
-- be asserted under GAME_HEADLESS=1.
local function testMinimapSunSprite()
    local path = "assets/effects/minimap_sun.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap sun marker sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.sunMarkerImagePath == path,
        "PlayScene must load assets/effects/minimap_sun.png into self.sunMarkerImagePath")
end

-- Minimap Earth marker is still a Lua filled circle (markerEarthRadius).
-- Same file-existence + always-set-path pattern as
-- testMinimapSunSprite. Graphics-gated earthMarkerImage cannot
-- be asserted under GAME_HEADLESS=1.
local function testMinimapEarthSprite()
    local path = "assets/effects/minimap_earth.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap earth marker sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.earthMarkerImagePath == path,
        "PlayScene must load assets/effects/minimap_earth.png into self.earthMarkerImagePath")
end

-- Minimap home-galaxy (milkyway) marker is still a Lua filled circle
-- (markerGalaxyHomeRadius). Same file-existence + always-set-path
-- pattern as testMinimapEarthSprite. Graphics-gated
-- galaxyHomeMarkerImage cannot be asserted under GAME_HEADLESS=1.
local function testMinimapGalaxyHomeSprite()
    local path = "assets/effects/minimap_galaxy_home.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap home-galaxy marker sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.galaxyHomeMarkerImagePath == path,
        "PlayScene must load assets/effects/minimap_galaxy_home.png into self.galaxyHomeMarkerImagePath")
end

-- Minimap generic (non-home, non-checkpoint) galaxy marker is still a
-- Lua filled circle (markerGalaxyPlainRadius). Same file-existence +
-- always-set-path pattern as testMinimapGalaxyHomeSprite. Graphics-gated
-- galaxyPlainMarkerImage cannot be asserted under GAME_HEADLESS=1.
local function testMinimapGalaxyPlainSprite()
    local path = "assets/effects/minimap_galaxy_plain.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap generic-galaxy marker sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.galaxyPlainMarkerImagePath == path,
        "PlayScene must load assets/effects/minimap_galaxy_plain.png into self.galaxyPlainMarkerImagePath")
end

-- Off-chart Earth-return rim marker is still a Lua filled circle
-- (markerBeyondRadius). Same file-existence + always-set-path pattern as
-- testMinimapGalaxyPlainSprite. Graphics-gated earthReturnMarkerImage
-- cannot be asserted under GAME_HEADLESS=1.
local function testMinimapEarthReturnSprite()
    local path = "assets/effects/minimap_earth_return.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap earth-return marker sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.earthReturnMarkerImagePath == path,
        "PlayScene must load assets/effects/minimap_earth_return.png into self.earthReturnMarkerImagePath")
end

-- Minimap galaxy spiral-arm points are still Lua filled circles (radius
-- 1.4). Same file-existence + always-set-path pattern as
-- testMinimapEarthReturnSprite. Graphics-gated spiralArmImage cannot
-- be asserted under GAME_HEADLESS=1.
local function testMinimapSpiralArmSprite()
    local path = "assets/effects/minimap_spiral_star.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap spiral-arm star sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.spiralArmImagePath == path,
        "PlayScene must load assets/effects/minimap_spiral_star.png into self.spiralArmImagePath")
end

-- Minimap solar-system orbit rings are still Lua line circles (radii
-- 4/7/11). Same file-existence + always-set-path pattern as
-- testMinimapSpiralArmSprite. Graphics-gated orbitRingImage cannot
-- be asserted under GAME_HEADLESS=1.
local function testMinimapOrbitRingSprite()
    local path = "assets/effects/minimap_orbit_ring.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap orbit-ring sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.orbitRingImagePath == path,
        "PlayScene must load assets/effects/minimap_orbit_ring.png into self.orbitRingImagePath")
end

-- Minimap galaxy-disk rings (kind ~= "orbit") are still Lua line circles.
-- Same file-existence + always-set-path pattern as
-- testMinimapOrbitRingSprite. Graphics-gated galaxyRingImage cannot
-- be asserted under GAME_HEADLESS=1.
local function testMinimapGalaxyRingSprite()
    local path = "assets/effects/minimap_galaxy_ring.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated minimap galaxy-disk ring sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.galaxyRingImagePath == path,
        "PlayScene must load assets/effects/minimap_galaxy_ring.png into self.galaxyRingImagePath")
end

-- Galaxy hub/checkpoint planets still reuse the generic planet sprite
-- (planet_generic.png). Same file-existence + always-set-path pattern as
-- testMinimapGalaxyRingSprite. Graphics-gated hubPlanetImage cannot
-- be asserted under GAME_HEADLESS=1.
local function testHubPlanetSprite()
    local path = "assets/planet/planet_hub.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated hub/checkpoint planet sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.hubPlanetImagePath == path,
        "PlayScene must load assets/planet/planet_hub.png into self.hubPlanetImagePath")
end

-- Galaxy shop planets still reuse the generic planet sprite
-- (planet_generic.png). Same file-existence + always-set-path pattern as
-- testHubPlanetSprite. Graphics-gated shopPlanetImage cannot
-- be asserted under GAME_HEADLESS=1.
local function testShopPlanetSprite()
    local path = "assets/planet/planet_shop.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated shop planet sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.shopPlanetImagePath == path,
        "PlayScene must load assets/planet/planet_shop.png into self.shopPlanetImagePath")
end

-- Top HUD status bar is still a Lua fill rectangle. Same file-existence
-- + always-set-path pattern as testShopPlanetSprite. Graphics-gated
-- hudPanelImage cannot be asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue cap.
local function testHudPanelSprite()
    local path = "assets/effects/hud_panel.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated HUD panel sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.hudPanelImagePath == path,
        "PlayScene must load assets/effects/hud_panel.png into self.hudPanelImagePath")
end

-- Launch LOADOUT card is still a Lua fill rectangle. Same file-existence
-- + always-set-path pattern as testHudPanelSprite. Graphics-gated
-- loadoutPanelImage cannot be asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue cap.
local function testLoadoutPanelSprite()
    local path = "assets/effects/loadout_panel.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated loadout panel sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.loadoutPanelImagePath == path,
        "PlayScene must load assets/effects/loadout_panel.png into self.loadoutPanelImagePath")
end

-- EARTH SHOP card is still a Lua fill rectangle. Same file-existence
-- + always-set-path pattern as testLoadoutPanelSprite. Graphics-gated
-- shopPanelImage cannot be asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue cap.
local function testShopPanelSprite()
    local path = "assets/effects/shop_panel.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated shop panel sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.shopPanelImagePath == path,
        "PlayScene must load assets/effects/shop_panel.png into self.shopPanelImagePath")
end

-- Destroyed-phase summary card is still a Lua fill rectangle. Same
-- file-existence + always-set-path pattern as testShopPanelSprite.
-- Graphics-gated destroyedPanelImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run() stays
-- under Lua's 60-upvalue cap.
local function testDestroyedPanelSprite()
    local path = "assets/effects/destroyed_panel.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated destroyed panel sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.destroyedPanelImagePath == path,
        "PlayScene must load assets/effects/destroyed_panel.png into self.destroyedPanelImagePath")
end

-- Returning-phase slot result box is still a Lua fill rectangle. Same
-- file-existence + always-set-path pattern as testDestroyedPanelSprite.
-- Graphics-gated slotResultPanelImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run() stays
-- under Lua's 60-upvalue cap.
local function testSlotResultPanelSprite()
    local path = "assets/effects/slot_result_panel.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated slot result panel sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.slotResultPanelImagePath == path,
        "PlayScene must load assets/effects/slot_result_panel.png into self.slotResultPanelImagePath")
end

-- Returning-phase slot SPIN button is still a Lua fill rectangle. Same
-- file-existence + always-set-path pattern as testSlotResultPanelSprite.
-- Graphics-gated slotSpinButtonImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run() stays
-- under Lua's 60-upvalue cap.
local function testSlotSpinButtonSprite()
    local path = "assets/effects/slot_spin_button.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated slot spin button sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.slotSpinButtonImagePath == path,
        "PlayScene must load assets/effects/slot_spin_button.png into self.slotSpinButtonImagePath")
end

-- New-specimen banner box is still a Lua fill rectangle. Same
-- file-existence + always-set-path pattern as testSlotSpinButtonSprite.
-- Graphics-gated specimenBannerImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run() stays
-- under Lua's 60-upvalue cap.
local function testSpecimenBannerSprite()
    local path = "assets/effects/specimen_banner.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated specimen banner sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.specimenBannerImagePath == path,
        "PlayScene must load assets/effects/specimen_banner.png into self.specimenBannerImagePath")
end

-- EARTH SHOP settlement summary inner box is still a Lua fill rectangle.
-- Same file-existence + always-set-path pattern as testSpecimenBannerSprite.
-- Graphics-gated settlementSummaryPanelImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run() stays
-- under Lua's 60-upvalue cap.
local function testSettlementSummaryPanelSprite()
    local path = "assets/effects/settlement_summary_panel.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated settlement summary panel sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.settlementSummaryPanelImagePath == path,
        "PlayScene must load assets/effects/settlement_summary_panel.png into self.settlementSummaryPanelImagePath")
end

-- EARTH SHOP tappable settlementTouchRows bands are still Lua fill
-- rectangles. Same file-existence + always-set-path pattern as
-- testSettlementSummaryPanelSprite. Graphics-gated shopTouchRowImage
-- cannot be asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue cap.
local function testShopTouchRowSprite()
    local path = "assets/effects/shop_touch_row.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated shop touch-row sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.shopTouchRowImagePath == path,
        "PlayScene must load assets/effects/shop_touch_row.png into self.shopTouchRowImagePath")
end

-- Planet rim rings are still Lua circle("line") outlines. Same
-- file-existence + always-set-path pattern as testShopTouchRowSprite.
-- Graphics-gated planetRimImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run() stays
-- under Lua's 60-upvalue cap.
local function testPlanetRimSprite()
    local path = "assets/effects/planet_rim.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated planet rim sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.planetRimImagePath == path,
        "PlayScene must load assets/effects/planet_rim.png into self.planetRimImagePath")
end

-- Playfield background/foreground stars are still Lua points(). Same
-- file-existence + always-set-path pattern as testPlanetRimSprite.
-- Graphics-gated starPointImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run() stays
-- under Lua's 60-upvalue cap.
local function testStarPointSprite()
    local path = "assets/effects/star_point.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated star point sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.starPointImagePath == path,
        "PlayScene must load assets/effects/star_point.png into self.starPointImagePath")
end

-- Ship body fallback is still a Lua triangle polygon (0,-28 / -20,24 /
-- 0,12 / 20,24) when shipImage failed to load. Same file-existence +
-- always-set-path pattern as testStarPointSprite. Graphics-gated
-- shipSilhouetteImage cannot be asserted under GAME_HEADLESS=1. Invoked
-- from testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue cap.
local function testShipSilhouetteSprite()
    local path = "assets/effects/ship_silhouette.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated ship silhouette sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.shipSilhouetteImagePath == path,
        "PlayScene must load assets/effects/ship_silhouette.png into self.shipSilhouetteImagePath")
end

-- Launch TAP-TO-LAUNCH rocket icon is still a Lua polygon
-- (M.rocketIconPoints) when showLaunchRocketIcon is true. Same
-- file-existence + always-set-path pattern as testShipSilhouetteSprite.
-- Graphics-gated launchRocketImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run() stays
-- under Lua's 60-upvalue cap.
local function testLaunchRocketSprite()
    local path = "assets/effects/launch_rocket.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated launch rocket sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.launchRocketImagePath == path,
        "PlayScene must load assets/effects/launch_rocket.png into self.launchRocketImagePath")
end

-- SCOUT is a second purchasable hull (EARTH SHOP) but still draws the
-- STARTER sprite. Same file-existence + always-set-path pattern as
-- testLaunchRocketSprite. Graphics-gated scoutShipImage cannot be
-- asserted under GAME_HEADLESS=1. Invoked from testCanvasLayoutScale
-- so M.run() stays under Lua's 60-upvalue cap.
local function testScoutShipSprite()
    local path = "assets/ship/ship_scout.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated scout ship sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.scoutShipImagePath == path,
        "PlayScene must load assets/ship/ship_scout.png into self.scoutShipImagePath")
end

-- DIST HUD readout is still bare text (hud_distance) while CASH/HULL/STEER
-- already have ComfyUI icons. Same file-existence + always-set-path
-- pattern as testScoutShipSprite, plus Lua diamond fallback geometry
-- (even-length, spans cy, horizontally symmetric) so headless tests can
-- pin the silhouette. Graphics-gated distanceIconImage cannot be
-- asserted under GAME_HEADLESS=1. Invoked from testCanvasLayoutScale
-- so M.run() stays under Lua's 60-upvalue cap.
local function testDistanceIconSprite()
    local path = "assets/effects/hud_distance.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated DIST HUD icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.distanceIconImagePath == path,
        "PlayScene must load assets/effects/hud_distance.png into self.distanceIconImagePath")
    assert(play.distanceIconSize == 32 and play.distanceIconGap == 16)
    local points = play.distanceIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "distance silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "distance icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "distance outline must be horizontally symmetric around cx")
    end
end

-- PERSONAL BEST HUD readout is still bare gold text (hud_personal_best)
-- while DIST/CASH/HULL/STEER already have ComfyUI icons. Same
-- file-existence + always-set-path pattern as testDistanceIconSprite,
-- plus Lua trophy fallback geometry (even-length, spans cy,
-- horizontally symmetric). Graphics-gated bestIconImage cannot be
-- asserted under GAME_HEADLESS=1. Invoked from testCanvasLayoutScale
-- so M.run() stays under Lua's 60-upvalue cap.
local function testBestIconSprite()
    local path = "assets/effects/hud_best.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated BEST HUD icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.bestIconImagePath == path,
        "PlayScene must load assets/effects/hud_best.png into self.bestIconImagePath")
    assert(play.bestIconSize == 32 and play.bestIconGap == 16)
    local points = play.bestIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "best silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "best icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "best outline must be horizontally symmetric around cx")
    end
end

-- Galaxy-name HUD readout is still bare gold text (hud.galaxy) while
-- DIST/CASH/HULL/STEER/BEST/SAMPLES already have ComfyUI icons. Same
-- file-existence + always-set-path pattern as testSamplesIconSprite,
-- plus Lua 8-point star fallback geometry (even-length, spans cy,
-- horizontally symmetric). Graphics-gated galaxyIconImage cannot be
-- asserted under GAME_HEADLESS=1. Invoked from testCanvasLayoutScale
-- so M.run() stays under Lua's 60-upvalue cap.
local function testGalaxyIconSprite()
    local path = "assets/effects/hud_galaxy.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated GALAXY HUD icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.galaxyIconImagePath == path,
        "PlayScene must load assets/effects/hud_galaxy.png into self.galaxyIconImagePath")
    assert(play.galaxyIconSize == 32 and play.galaxyIconGap == 16)
    local points = play.galaxyIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "galaxy silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "galaxy icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "galaxy outline must be horizontally symmetric around cx")
    end
end

-- Returning-phase RETURN progress HUD readout is still bare cyan text
-- (hud_return_progress) while DIST/CASH/HULL/STEER/BEST/SAMPLES/galaxy
-- already have ComfyUI icons. Same file-existence + always-set-path
-- pattern as testGalaxyIconSprite, plus Lua downward-chevron fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated returnIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run() stays
-- under Lua's 60-upvalue cap.
local function testReturnIconSprite()
    local path = "assets/effects/hud_return.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated RETURN HUD icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.returnIconImagePath == path,
        "PlayScene must load assets/effects/hud_return.png into self.returnIconImagePath")
    assert(play.returnIconSize == 32 and play.returnIconGap == 16)
    local points = play.returnIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "return silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "return icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "return outline must be horizontally symmetric around cx")
    end
end

-- Returning-phase EARTH-distance HUD readout is still bare cyan text
-- (hud_earth / hud.earth) while DIST/CASH/HULL/STEER/BEST/SAMPLES/galaxy
-- /RETURN already have ComfyUI icons. Same file-existence + always-set-path
-- pattern as testReturnIconSprite, plus Lua globe fallback geometry
-- (even-length, spans cy, horizontally symmetric).
-- Graphics-gated earthIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run() stays
-- under Lua's 60-upvalue cap.
local function testEarthIconSprite()
    local path = "assets/effects/hud_earth.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated EARTH HUD icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.earthIconImagePath == path,
        "PlayScene must load assets/effects/hud_earth.png into self.earthIconImagePath")
    assert(play.earthIconSize == 32 and play.earthIconGap == 16)
    local points = play.earthIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "earth silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "earth icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "earth outline must be horizontally symmetric around cx")
    end
end

-- Planet approach SAMPLE $N labels are still bare cyan text
-- (sample_value_label) while DIST/CASH/HULL/STEER/BEST/SAMPLES/galaxy
-- /RETURN/EARTH HUD already have ComfyUI icons. Same file-existence +
-- always-set-path pattern as testEarthIconSprite, plus Lua hexagonal
-- crystal fallback geometry (even-length, spans cy, horizontally
-- symmetric). Graphics-gated sampleValueIconImage cannot be asserted
-- under GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testPlanetSampleValueIconSprite()
    local path = "assets/effects/planet_sample.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated planet SAMPLE $N icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.sampleValueIconImagePath == path,
        "PlayScene must load assets/effects/planet_sample.png into self.sampleValueIconImagePath")
    assert(play.sampleValueIconSize == 24 and play.sampleValueIconGap == 8)
    local points = play.sampleValueIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "sample-value silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "sample-value icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "sample-value outline must be horizontally symmetric around cx")
    end
end

-- Planet approach RISK/LETHAL labels are still bare red/amber text
-- (risk_lethal/risk_normal) while DIST/CASH/HULL/STEER/BEST/SAMPLES
-- /galaxy/RETURN/EARTH/SAMPLE $N already have ComfyUI icons. Same
-- file-existence + always-set-path pattern as
-- testPlanetSampleValueIconSprite, plus Lua warning-triangle fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated riskIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testPlanetRiskIconSprite()
    local path = "assets/effects/planet_risk.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated planet RISK/LETHAL icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.riskIconImagePath == path,
        "PlayScene must load assets/effects/planet_risk.png into self.riskIconImagePath")
    assert(play.riskIconSize == 24 and play.riskIconGap == 8)
    local points = play.riskIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "risk silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "risk icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "risk outline must be horizontally symmetric around cx")
    end
end

-- Floating sample-pickup "+$N" labels are still bare green text
-- (floating_sample_gain) while planet-approach SAMPLE $N / RISK
-- already have ComfyUI icons. Same file-existence + always-set-path
-- pattern as testPlanetRiskIconSprite, plus Lua plus-badge fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated floatingSampleIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testFloatingSampleIconSprite()
    local path = "assets/effects/floating_sample.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated floating sample-pickup icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.floatingSampleIconImagePath == path,
        "PlayScene must load assets/effects/floating_sample.png into self.floatingSampleIconImagePath")
    assert(play.floatingSampleIconSize == 24 and play.floatingSampleIconGap == 8)
    local points = play.floatingSampleIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "floating-sample silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "floating-sample icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "floating-sample outline must be horizontally symmetric around cx")
    end
end

-- Floating damage "-N" labels are still bare red text
-- (floating_damage_text) while sample-pickup "+$N" already has a
-- ComfyUI plus-badge. Same file-existence + always-set-path pattern
-- as testFloatingSampleIconSprite, plus Lua minus-badge fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated floatingDamageIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testFloatingDamageIconSprite()
    local path = "assets/effects/floating_damage.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated floating damage icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.floatingDamageIconImagePath == path,
        "PlayScene must load assets/effects/floating_damage.png into self.floatingDamageIconImagePath")
    assert(play.floatingDamageIconSize == 24 and play.floatingDamageIconGap == 8)
    local points = play.floatingDamageIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "floating-damage silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "floating-damage icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "floating-damage outline must be horizontally symmetric around cx")
    end
end

-- Collision/message banners are still bare centered printf text
-- (self.message / collision_message) while floating sample-pickup
-- "+$N" and floating damage "-N" already have ComfyUI icons. Same
-- file-existence + always-set-path pattern as
-- testFloatingDamageIconSprite, plus Lua burst-star fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated messageBannerIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testMessageBannerIconSprite()
    local path = "assets/effects/message_banner.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated collision/message banner icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.messageBannerIconImagePath == path,
        "PlayScene must load assets/effects/message_banner.png into self.messageBannerIconImagePath")
    assert(play.messageBannerIconSize == 24 and play.messageBannerIconGap == 8)
    local points = play.messageBannerIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "message-banner silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "message-banner icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "message-banner outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP panel title is still bare centered printf text
-- (earth_shop_title) while collision/message banners already have a
-- ComfyUI burst-star. Same file-existence + always-set-path pattern
-- as testMessageBannerIconSprite, plus Lua storefront-awning fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated shopTitleIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testShopTitleIconSprite()
    local path = "assets/effects/shop_title.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated EARTH SHOP title icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.shopTitleIconImagePath == path,
        "PlayScene must load assets/effects/shop_title.png into self.shopTitleIconImagePath")
    assert(play.shopTitleIconSize == 24 and play.shopTitleIconGap == 8)
    local points = play.shopTitleIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "shop-title silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "shop-title icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "shop-title outline must be horizontally symmetric around cx")
    end
end

-- Destroyed-phase panel title is still bare centered printf text
-- (ship_destroyed_title) while EARTH SHOP title already has a
-- ComfyUI storefront. Same file-existence + always-set-path pattern
-- as testShopTitleIconSprite, plus Lua cracked-hull fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated destroyedTitleIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testDestroyedTitleIconSprite()
    local path = "assets/effects/destroyed_title.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated destroyed-title icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.destroyedTitleIconImagePath == path,
        "PlayScene must load assets/effects/destroyed_title.png into self.destroyedTitleIconImagePath")
    assert(play.destroyedTitleIconSize == 24 and play.destroyedTitleIconGap == 8)
    local points = play.destroyedTitleIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "destroyed-title silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "destroyed-title icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "destroyed-title outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP TAP: RELAUNCH row is still bare centered printf text
-- (tap_relaunch) while EARTH SHOP / SHIP DESTROYED titles already have
-- ComfyUI icons. Same file-existence + always-set-path pattern as
-- testDestroyedTitleIconSprite, plus Lua upward-chevron fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated relaunchIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testRelaunchIconSprite()
    local path = "assets/effects/relaunch.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated TAP RELAUNCH icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.relaunchIconImagePath == path,
        "PlayScene must load assets/effects/relaunch.png into self.relaunchIconImagePath")
    assert(play.relaunchIconSize == 24 and play.relaunchIconGap == 8)
    local points = play.relaunchIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "relaunch silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "relaunch icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "relaunch outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP hull compact action (hull_action_compact) is still a
-- bare centered printf while TAP: RELAUNCH already has a ComfyUI
-- icon. Shop-row drawShopIcon sits in the margin and does not
-- replace this label. Same file-existence + always-set-path pattern
-- as testRelaunchIconSprite, plus Lua shield-plate fallback geometry
-- (even-length, spans cy, horizontally symmetric). Graphics-gated
-- hullActionIconImage cannot be asserted under GAME_HEADLESS=1.
-- Invoked from testCanvasLayoutScale so M.run() stays under Lua's
-- 60-upvalue cap.
local function testHullActionIconSprite()
    local path = "assets/effects/shop_hull_action.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated hull compact-action icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.hullActionIconImagePath == path,
        "PlayScene must load assets/effects/shop_hull_action.png into self.hullActionIconImagePath")
    assert(play.hullActionIconSize == 24 and play.hullActionIconGap == 8)
    local points = play.hullActionIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "hull-action silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "hull-action icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "hull-action outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP steering compact action (steering_action_compact) is
-- still a bare centered printf while hull_action_compact already
-- has a ComfyUI icon. Shop-row drawShopIcon sits in the margin and
-- does not replace this label. Same file-existence + always-set-path
-- pattern as testHullActionIconSprite, plus Lua gyro-hexagon fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated steeringActionIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testSteeringActionIconSprite()
    local path = "assets/effects/shop_steering_action.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated steering compact-action icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.steeringActionIconImagePath == path,
        "PlayScene must load assets/effects/shop_steering_action.png into self.steeringActionIconImagePath")
    assert(play.steeringActionIconSize == 24 and play.steeringActionIconGap == 8)
    local points = play.steeringActionIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "steering-action silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "steering-action icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "steering-action outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP yield compact action (yield_action_compact) is still a
-- bare centered printf while hull/steering compact actions already
-- have ComfyUI icons. Shop-row drawShopIcon sits in the margin and
-- does not replace this label. Same file-existence + always-set-path
-- pattern as testSteeringActionIconSprite, plus Lua sample-crystal
-- diamond fallback geometry (even-length, spans cy, horizontally
-- symmetric). Graphics-gated yieldActionIconImage cannot be asserted
-- under GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so
-- M.run() stays under Lua's 60-upvalue cap.
local function testYieldActionIconSprite()
    local path = "assets/effects/shop_yield_action.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated yield compact-action icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.yieldActionIconImagePath == path,
        "PlayScene must load assets/effects/shop_yield_action.png into self.yieldActionIconImagePath")
    assert(play.yieldActionIconSize == 24 and play.yieldActionIconGap == 8)
    local points = play.yieldActionIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "yield-action silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "yield-action icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "yield-action outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP ship compact action (shipActionCompact) is still a
-- bare centered printf while hull/steering/yield compact actions
-- already have ComfyUI icons. Shop-row drawShopIcon sits in the
-- margin and does not replace this label. Same file-existence +
-- always-set-path pattern as testYieldActionIconSprite, plus Lua
-- ship-dart fallback geometry (even-length, spans cy, horizontally
-- symmetric). Graphics-gated shipActionIconImage cannot be asserted
-- under GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so
-- M.run() stays under Lua's 60-upvalue cap.
local function testShipActionIconSprite()
    local path = "assets/effects/shop_ship_action.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated ship compact-action icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.shipActionIconImagePath == path,
        "PlayScene must load assets/effects/shop_ship_action.png into self.shipActionIconImagePath")
    assert(play.shipActionIconSize == 24 and play.shipActionIconGap == 8)
    local points = play.shipActionIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "ship-action silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "ship-action icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "ship-action outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP nextLaunch.stats (stats_line, "HULL n") already
-- pairs the hull-plate icon with the label. LAUNCH LOADOUT
-- loadout.stats is still a bare centered printf. Same
-- file-existence + always-set-path pattern as
-- testShipActionIconSprite, plus Lua hull-plate hexagon fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated statsIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testStatsIconSprite()
    local path = "assets/effects/shop_stats.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated shop stats icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.statsIconImagePath == path,
        "PlayScene must load assets/effects/shop_stats.png into self.statsIconImagePath")
    assert(play.statsIconSize == 24 and play.statsIconGap == 8)
    assert(play.drawLoadoutStatsIcon == true,
        "LAUNCH LOADOUT loadout.stats must pair HULL n with the hull-plate icon")
    assert(type(play.statsIconLabelLayout) == "function",
        "PlayScene must expose a shared stats icon+label layout helper")
    local layout = play.statsIconLabelLayout(100, 64, 592)
    assert(layout.iconSpan == play.statsIconSize + play.statsIconGap)
    assert(layout.labelX == layout.startX + layout.iconSpan)
    assert(layout.iconCenterX == layout.startX + play.statsIconSize / 2)
    local total = layout.iconSpan + 100
    assert(math.abs(layout.startX - (64 + (592 - total) / 2)) < 0.01,
        "icon+label pair must stay centered in the loadout/shop box")
    local points = play.statsIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "stats silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "stats icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "stats outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP hullStatus (SHORT $n / LEFT $n) is still a bare
-- centered printf while compact action rows and nextLaunch.stats
-- already have ComfyUI icons. Shop-row drawShopIcon sits in the
-- margin and does not replace this label. Same file-existence +
-- always-set-path pattern as testStatsIconSprite, plus Lua coin
-- hexagon fallback geometry (even-length, spans cy, horizontally
-- symmetric). Graphics-gated hullStatusIconImage cannot be
-- asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue
-- cap.
local function testHullStatusIconSprite()
    local path = "assets/effects/shop_hull_status.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated hull status icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.hullStatusIconImagePath == path,
        "PlayScene must load assets/effects/shop_hull_status.png into self.hullStatusIconImagePath")
    assert(play.hullStatusIconSize == 24 and play.hullStatusIconGap == 8)
    local points = play.hullStatusIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "hull-status silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "hull-status icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "hull-status outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP steeringStatus (SHORT $n / LEFT $n) is still a bare
-- centered printf while hullStatus already has a ComfyUI icon.
-- Shop-row drawShopIcon sits in the margin and does not replace
-- this label. Same file-existence + always-set-path pattern as
-- testHullStatusIconSprite, plus Lua gyro-coin octagon fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated steeringStatusIconImage cannot be asserted
-- under GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so
-- M.run() stays under Lua's 60-upvalue cap.
local function testSteeringStatusIconSprite()
    local path = "assets/effects/shop_steering_status.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated steering status icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.steeringStatusIconImagePath == path,
        "PlayScene must load assets/effects/shop_steering_status.png into self.steeringStatusIconImagePath")
    assert(play.steeringStatusIconSize == 24 and play.steeringStatusIconGap == 8)
    local points = play.steeringStatusIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "steering-status silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "steering-status icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "steering-status outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP yieldStatus (SHORT $n / LEFT $n) is still a bare
-- centered printf while hullStatus and steeringStatus already
-- have ComfyUI icons. Shop-row drawShopIcon sits in the margin
-- and does not replace this label. Same file-existence +
-- always-set-path pattern as testSteeringStatusIconSprite, plus
-- Lua crystal-coin hexagon fallback geometry (even-length, spans
-- cy, horizontally symmetric). Graphics-gated yieldStatusIconImage
-- cannot be asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue
-- cap.
local function testYieldStatusIconSprite()
    local path = "assets/effects/shop_yield_status.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated yield status icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.yieldStatusIconImagePath == path,
        "PlayScene must load assets/effects/shop_yield_status.png into self.yieldStatusIconImagePath")
    assert(play.yieldStatusIconSize == 24 and play.yieldStatusIconGap == 8)
    local points = play.yieldStatusIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "yield-status silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "yield-status icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "yield-status outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP shipStatus (SHORT $n / LEFT $n / OWNED) is still a bare
-- centered printf while hullStatus, steeringStatus, and yieldStatus
-- already have ComfyUI icons. Shop-row drawShopIcon sits in the margin
-- and does not replace this label. Same file-existence +
-- always-set-path pattern as testYieldStatusIconSprite, plus Lua
-- ship-coin diamond fallback geometry (even-length, spans cy,
-- horizontally symmetric). Graphics-gated shipStatusIconImage cannot
-- be asserted under GAME_HEADLESS=1. Invoked from testCanvasLayoutScale
-- so M.run() stays under Lua's 60-upvalue cap.
local function testShipStatusIconSprite()
    local path = "assets/effects/shop_ship_status.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated ship status icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.shipStatusIconImagePath == path,
        "PlayScene must load assets/effects/shop_ship_status.png into self.shipStatusIconImagePath")
    assert(play.shipStatusIconSize == 24 and play.shipStatusIconGap == 8)
    local points = play.shipStatusIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "ship-status silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "ship-status icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "ship-status outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP hullPreviewCompact (HULL n after upgrade) is still a
-- bare centered printf while hullStatus already has a ComfyUI icon.
-- Shop-row drawShopIcon sits in the margin and does not replace
-- this label. Same file-existence + always-set-path pattern as
-- testShipStatusIconSprite, plus Lua layered hull-plate fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated hullPreviewIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testHullPreviewIconSprite()
    local path = "assets/effects/shop_hull_preview.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated hull preview icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.hullPreviewIconImagePath == path,
        "PlayScene must load assets/effects/shop_hull_preview.png into self.hullPreviewIconImagePath")
    assert(play.hullPreviewIconSize == 24 and play.hullPreviewIconGap == 8)
    local points = play.hullPreviewIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "hull-preview silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "hull-preview icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "hull-preview outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP steeringPreviewCompact (SPD n after upgrade) is still a
-- bare centered printf while hullPreviewCompact already has a ComfyUI
-- icon. Shop-row drawShopIcon sits in the margin and does not replace
-- this label. Same file-existence + always-set-path pattern as
-- testHullPreviewIconSprite, plus Lua 4-point gyro-star fallback
-- geometry (even-length, spans cy, horizontally symmetric).
-- Graphics-gated steeringPreviewIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testSteeringPreviewIconSprite()
    local path = "assets/effects/shop_steering_preview.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated steering preview icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.steeringPreviewIconImagePath == path,
        "PlayScene must load assets/effects/shop_steering_preview.png into self.steeringPreviewIconImagePath")
    assert(play.steeringPreviewIconSize == 24 and play.steeringPreviewIconGap == 8)
    local points = play.steeringPreviewIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "steering-preview silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "steering-preview icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "steering-preview outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP yieldPreview (YIELD xn after upgrade) is still a
-- bare centered printf while steeringPreviewCompact already has a
-- ComfyUI icon. Shop-row drawShopIcon sits in the margin and does
-- not replace this label. Same file-existence + always-set-path
-- pattern as testSteeringPreviewIconSprite, plus Lua faceted
-- sample-crystal fallback geometry (even-length, spans cy,
-- horizontally symmetric). Graphics-gated yieldPreviewIconImage
-- cannot be asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue cap.
local function testYieldPreviewIconSprite()
    local path = "assets/effects/shop_yield_preview.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated yield preview icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.yieldPreviewIconImagePath == path,
        "PlayScene must load assets/effects/shop_yield_preview.png into self.yieldPreviewIconImagePath")
    assert(play.yieldPreviewIconSize == 24 and play.yieldPreviewIconGap == 8)
    local points = play.yieldPreviewIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "yield-preview silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "yield-preview icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "yield-preview outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP shipPreviewCompact (SHIP Hn after switch) is still a
-- bare centered printf while yieldPreview already has a ComfyUI
-- icon. Shop-row drawShopIcon sits in the margin and does not
-- replace this label. Same file-existence + always-set-path
-- pattern as testYieldPreviewIconSprite, plus Lua arrowhead
-- scout-hull fallback geometry (even-length, spans cy,
-- horizontally symmetric). Graphics-gated shipPreviewIconImage
-- cannot be asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue cap.
local function testShipPreviewIconSprite()
    local path = "assets/effects/shop_ship_preview.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated ship preview icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.shipPreviewIconImagePath == path,
        "PlayScene must load assets/effects/shop_ship_preview.png into self.shipPreviewIconImagePath")
    assert(play.shipPreviewIconSize == 24 and play.shipPreviewIconGap == 8)
    local points = play.shipPreviewIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "ship-preview silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "ship-preview icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "ship-preview outline must be horizontally symmetric around cx")
    end
end

-- EARTH SHOP nextLaunch.ship (NEXT STARTER / NEXT SCOUT) is still a
-- bare centered printf while shipPreviewCompact already has a ComfyUI
-- icon. Shop-row drawShopIcon sits in the margin and does not
-- replace this label. Same file-existence + always-set-path
-- pattern as testShipPreviewIconSprite, plus Lua hangar-roof
-- pentagon fallback geometry (even-length, spans cy,
-- horizontally symmetric). Graphics-gated nextShipIconImage
-- cannot be asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue cap.
local function testNextShipIconSprite()
    local path = "assets/effects/shop_next_ship.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated next-ship icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.nextShipIconImagePath == path,
        "PlayScene must load assets/effects/shop_next_ship.png into self.nextShipIconImagePath")
    assert(play.nextShipIconSize == 24 and play.nextShipIconGap == 8)
    local points = play.nextShipIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "next-ship silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "next-ship icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "next-ship outline must be horizontally symmetric around cx")
    end
end

-- LAUNCH LOADOUT loadout.ship (selected hull name, shown once SCOUT
-- is owned) is still a bare centered printf while shop
-- nextLaunch.ship already has a ComfyUI hangar-roof icon. Same
-- file-existence + always-set-path pattern as testNextShipIconSprite,
-- plus Lua hexagonal nameplate fallback geometry (even-length,
-- spans cy, horizontally symmetric). Graphics-gated
-- loadoutShipIconImage cannot be asserted under GAME_HEADLESS=1.
-- Invoked from testCanvasLayoutScale so M.run() stays under Lua's
-- 60-upvalue cap.
local function testLoadoutShipIconSprite()
    local path = "assets/effects/loadout_ship.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated loadout-ship icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.loadoutShipIconImagePath == path,
        "PlayScene must load assets/effects/loadout_ship.png into self.loadoutShipIconImagePath")
    assert(play.loadoutShipIconSize == 24 and play.loadoutShipIconGap == 8)
    local points = play.loadoutShipIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "loadout-ship silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "loadout-ship icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "loadout-ship outline must be horizontally symmetric around cx")
    end
end

-- Destroyed-phase next_ship_line (NEXT STARTER after meta wipe) is
-- still a bare centered printf while launch loadout.ship already
-- has a ComfyUI hexagonal nameplate. Same file-existence +
-- always-set-path pattern as testLoadoutShipIconSprite, plus Lua
-- restart-hull dart fallback geometry (even-length, spans cy,
-- horizontally symmetric). Graphics-gated
-- destroyedNextShipIconImage cannot be asserted under
-- GAME_HEADLESS=1. Invoked from testCanvasLayoutScale so M.run()
-- stays under Lua's 60-upvalue cap.
local function testDestroyedNextShipIconSprite()
    local path = "assets/effects/destroyed_next_ship.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated destroyed next-ship icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.destroyedNextShipIconImagePath == path,
        "PlayScene must load assets/effects/destroyed_next_ship.png into self.destroyedNextShipIconImagePath")
    assert(play.destroyedNextShipIconSize == 24 and play.destroyedNextShipIconGap == 8)
    local points = play.destroyedNextShipIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "destroyed next-ship silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "destroyed next-ship icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "destroyed next-ship outline must be horizontally symmetric around cx")
    end
end

-- Destroyed-phase tap_start_over (TAP: START OVER after meta wipe) is
-- still a bare centered printf while next_ship_line already has a
-- ComfyUI restart-hull dart. Same file-existence + always-set-path
-- pattern as testDestroyedNextShipIconSprite, plus Lua restart-loop
-- hexagon fallback geometry (even-length, spans cy, horizontally
-- symmetric). Graphics-gated destroyedTapStartOverIconImage cannot
-- be asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue cap.
local function testDestroyedTapStartOverIconSprite()
    local path = "assets/effects/destroyed_tap_start_over.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated destroyed tap-start-over icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.destroyedTapStartOverIconImagePath == path,
        "PlayScene must load assets/effects/destroyed_tap_start_over.png into self.destroyedTapStartOverIconImagePath")
    assert(play.destroyedTapStartOverIconSize == 24 and play.destroyedTapStartOverIconGap == 8)
    local points = play.destroyedTapStartOverIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "destroyed tap-start-over silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "destroyed tap-start-over icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "destroyed tap-start-over outline must be horizontally symmetric around cx")
    end
end

-- Destroyed-phase lost_total_line (LOST TOTAL $N after meta wipe) is
-- still a bare centered printf while tap_start_over already has a
-- ComfyUI restart-loop hexagon. Same file-existence + always-set-path
-- pattern as testDestroyedTapStartOverIconSprite, plus Lua cracked-coin
-- octagon fallback geometry (even-length, spans cy, horizontally
-- symmetric). Graphics-gated destroyedLostTotalIconImage cannot
-- be asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue cap.
local function testDestroyedLostTotalIconSprite()
    local path = "assets/effects/destroyed_lost_total.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated destroyed lost-total icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.destroyedLostTotalIconImagePath == path,
        "PlayScene must load assets/effects/destroyed_lost_total.png into self.destroyedLostTotalIconImagePath")
    assert(play.destroyedLostTotalIconSize == 24 and play.destroyedLostTotalIconGap == 8)
    local points = play.destroyedLostTotalIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "destroyed lost-total silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "destroyed lost-total icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "destroyed lost-total outline must be horizontally symmetric around cx")
    end
end

-- Destroyed-phase samples_settlement_line (SAMPLES (n) $N of wiped
-- unbanked samples) is still a bare centered printf while
-- lost_total_line already has a ComfyUI cracked-coin octagon. Same
-- file-existence + always-set-path pattern as
-- testDestroyedLostTotalIconSprite, plus Lua hexagonal sample-crystal
-- fallback geometry (even-length, spans cy, horizontally
-- symmetric). Graphics-gated destroyedSamplesSettlementIconImage cannot
-- be asserted under GAME_HEADLESS=1. Invoked from
-- testCanvasLayoutScale so M.run() stays under Lua's 60-upvalue cap.
local function testDestroyedSamplesSettlementIconSprite()
    local path = "assets/effects/destroyed_samples_settlement.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated destroyed samples-settlement icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.destroyedSamplesSettlementIconImagePath == path,
        "PlayScene must load assets/effects/destroyed_samples_settlement.png into self.destroyedSamplesSettlementIconImagePath")
    assert(play.destroyedSamplesSettlementIconSize == 24 and play.destroyedSamplesSettlementIconGap == 8)
    local points = play.destroyedSamplesSettlementIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "destroyed samples-settlement silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "destroyed samples-settlement icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "destroyed samples-settlement outline must be horizontally symmetric around cx")
    end
end

-- SAMPLES HUD readout is still bare gold text (hud_samples) while
-- DIST/CASH/HULL/STEER/BEST already have ComfyUI icons. Same
-- file-existence + always-set-path pattern as testBestIconSprite,
-- plus Lua vial fallback geometry (even-length, spans cy,
-- horizontally symmetric). Graphics-gated samplesIconImage cannot be
-- asserted under GAME_HEADLESS=1. Invoked from testCanvasLayoutScale
-- so M.run() stays under Lua's 60-upvalue cap.
local function testSamplesIconSprite()
    local path = "assets/effects/hud_samples.png"
    local info = love.filesystem.getInfo(path, "file")
    assert(info ~= nil, "missing ComfyUI-generated SAMPLES HUD icon sprite at " .. path)
    assert(info.size > 0)
    local play = require("game.scenes.play")
    local scene = play.new()
    assert(scene.samplesIconImagePath == path,
        "PlayScene must load assets/effects/hud_samples.png into self.samplesIconImagePath")
    assert(play.samplesIconSize == 32 and play.samplesIconGap == 16)
    local points = play.samplesIconPoints(20, 20, 8)
    assert(#points % 2 == 0, "polygon point list must have paired x,y coordinates")
    assert(#points >= 6, "samples silhouette needs at least 3 vertices")
    local minY, maxY = math.huge, -math.huge
    for i = 1, #points, 2 do
        local y = points[i + 1]
        minY = math.min(minY, y)
        maxY = math.max(maxY, y)
    end
    assert(minY < 20 and maxY > 20, "samples icon must span above and below its center")
    local seen = {}
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        seen[string.format("%.2f,%.2f", x, y)] = true
    end
    for i = 1, #points, 2 do
        local x, y = points[i], points[i + 1]
        local mirroredKey = string.format("%.2f,%.2f", 40 - x, y)
        assert(seen[mirroredKey],
            "samples outline must be horizontally symmetric around cx")
    end
end

-- docs/feedback/INBOX.md 처리대기 항목 "내부 해상도를 발라트로 수준으로 상향"
-- second slice: HUD/touch/minimap/joystick/font/shop/earth/loadout absolute
-- pixels must be ×4 of the old 180×320 layout (or canvas-ratio equivalent)
-- so they keep the same screen fraction on 720×1280. Own top-level function
-- because M.run() is already at Lua's 200-local cap.
local function testCanvasLayoutScale()
    testHudPanelSprite()
    testLoadoutPanelSprite()
    testShopPanelSprite()
    testDestroyedPanelSprite()
    testSlotResultPanelSprite()
    testSlotSpinButtonSprite()
    testSpecimenBannerSprite()
    testSettlementSummaryPanelSprite()
    testShopTouchRowSprite()
    testPlanetRimSprite()
    testStarPointSprite()
    testShipSilhouetteSprite()
    testLaunchRocketSprite()
    testScoutShipSprite()
    testDistanceIconSprite()
    testBestIconSprite()
    testSamplesIconSprite()
    testGalaxyIconSprite()
    testReturnIconSprite()
    testEarthIconSprite()
    testPlanetSampleValueIconSprite()
    testPlanetRiskIconSprite()
    testFloatingSampleIconSprite()
    testFloatingDamageIconSprite()
    testMessageBannerIconSprite()
    testShopTitleIconSprite()
    testDestroyedTitleIconSprite()
    testRelaunchIconSprite()
    testHullActionIconSprite()
    testSteeringActionIconSprite()
    testYieldActionIconSprite()
    testShipActionIconSprite()
    testStatsIconSprite()
    testHullStatusIconSprite()
    testSteeringStatusIconSprite()
    testYieldStatusIconSprite()
    testShipStatusIconSprite()
    testHullPreviewIconSprite()
    testSteeringPreviewIconSprite()
    testYieldPreviewIconSprite()
    testShipPreviewIconSprite()
    testNextShipIconSprite()
    testLoadoutShipIconSprite()
    testDestroyedNextShipIconSprite()
    testDestroyedTapStartOverIconSprite()
    testDestroyedLostTotalIconSprite()
    testDestroyedSamplesSettlementIconSprite()
    local joystick = require("game.joystick")
    local minimap = require("game.minimap")
    local rows = PlayScene.settlementTouchRows
    assert(rows[1].top == 752 and rows[1].bottom == 928)
    assert(rows[1].columns[1].left == 0 and rows[1].columns[1].right == 360)
    assert(rows[1].columns[2].left == 360 and rows[1].columns[2].right == 720)
    assert(rows[2].top == 928 and rows[2].bottom == 1104)
    assert(rows[3].key == "relaunch" and rows[3].top == 1104 and rows[3].bottom == 1280)
    local rc = PlayScene.returnControls
    assert(rc.top == 976 and rc.bottom == 1152)
    assert(rc.leftMaxX == 220 and rc.slotMinX == 240 and rc.slotMaxX == 480 and rc.rightMinX == 500)
    local ac = PlayScene.ascendControls
    assert(ac.top == 976 and ac.bottom == 1152)
    assert(ac.leftMaxX == 324 and ac.rightMinX == 396)
    assert(minimap.size == 192 and minimap.inset == 16)
    assert(joystick.deadzone == 24 and joystick.maxRadius == 160)
    assert(joystick.visualRadius == 56 and joystick.visualKnobRadius == 12)
    assert(PlayScene.launchHudHeight == 128)
    assert(PlayScene.launchLoadoutBoxTop == 808)
    assert(PlayScene.launchLoadoutRowStep == 40)
    assert(PlayScene.earthCenterY == 300 and PlayScene.earthRadius == 232)
    assert(PlayScene.smallFontSize == 32 and PlayScene.hudFontSize == 56)
    assert(PlayScene.devPlaceholderFontSize == 28)
    assert(PlayScene.hudPrimaryStatusGap == 24)
    assert(PlayScene.hudOddsLineHeight == 40)
    assert(PlayScene.launchIconSize == 56 and PlayScene.launchIconGap == 48)
    assert(PlayScene.hullIconSize == 32 and PlayScene.cashIconSize == 32 and PlayScene.speedIconSize == 32)
    assert(PlayScene.shopActionColumnX == 64 and PlayScene.shopActionColumnW == 400)
    assert(PlayScene.shopStatusColumnX == 464 and PlayScene.shopStatusColumnW == 208)
    assert(PlayScene.shopColumnLeftX == 64 and PlayScene.shopColumnLeftW == 272)
    assert(PlayScene.shopColumnRightX == 352 and PlayScene.shopColumnRightW == 272)
    -- Remaining decorative px flagged by the previous slice's "남은 작업"
    -- note: the floating "+$N"/"-N" text box and the minimap's small marker
    -- dot/ring radii were still the old 180x320-era pixel sizes. ×4 them so
    -- they keep the same screen fraction on the 720x1280 canvas.
    assert(PlayScene.floatingTextBoxHalfWidth == 120 and PlayScene.floatingTextBoxTopOffset == 40)
    assert(minimap.markerSunRadius == 10.4)
    assert(minimap.markerGalaxyHomeRadius == 8.8)
    -- markerGalaxyHubRadius shrunk (docs/feedback/INBOX.md item 1 part 2:
    -- checkpoint marker now a small star glyph, not an oversized dot+ring).
    assert(minimap.markerGalaxyHubRadius == 5.6 and minimap.markerGalaxyHubRingRadius == 16)
    assert(minimap.markerGalaxyPlainRadius == 6)
    assert(minimap.markerEarthRadius == 8)
    assert(minimap.markerPlayerFillRadius == 6.8 and minimap.markerPlayerLineRadius == 9.6)
    assert(minimap.markerBeyondRadius == 8.8)
    assert(minimap.markerCheckpointTipRadius == 7.2)
end

function M.run()
    require("game.i18n").setLocale("en")
    -- docs/feedback/INBOX.md 처리대기 항목 "내부 해상도를 발라트로 수준으로 상향":
    -- internal canvas is 720x1280 (old 180x320 x4). Integer-scale 1 window
    -- is now 720x1280; a 4x window is 2880x5120.
    assert(viewport.width == 720 and viewport.height == 1280)
    local scale, x, y = viewport.fit(2880, 5120, false)
    assert(scale == 4 and x == 0 and y == 0)
    local gx, gy, inside = viewport.toGame(1440, 2560, 2880, 5120, false)
    assert(gx == 360 and gy == 640 and inside)
    -- Reuse the existing locals: M.run already sits on Lua's 200-local cap.
    scale, x, y = viewport.fit(720, 1280, false)
    assert(scale == 1 and x == 0 and y == 0)

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
    -- Omnidirectional thrust test (docs/feedback/INBOX.md)
    do
        local function thrustMagnitude(input)
            local s = shipModule.new()
            shipModule.update(s, 1, input)
            return math.sqrt(s.vx * s.vx + s.vy * s.vy)
        end
        
        local rightMag = thrustMagnitude({ right = true })
        assert(rightMag > 0)
        assert(math.abs(rightMag - thrustMagnitude({ left = true })) < 1e-5, "thrust magnitude must be equal for all directions")
        assert(math.abs(rightMag - thrustMagnitude({ up = true })) < 1e-5, "thrust magnitude must be equal for all directions")
        assert(math.abs(rightMag - thrustMagnitude({ down = true })) < 1e-5, "thrust magnitude must be equal for all directions")
        assert(math.abs(rightMag - thrustMagnitude({ right = true, up = true })) < 1e-5, "diagonal thrust must be normalized to same magnitude")
    end


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

    -- docs/feedback/INBOX.md 국제화 누락 + 발라트로식 점수 연출 + HUD 약자 정리 항목 (2):
    -- Balatro-style score punch for the DIST HUD number: the moment
    -- run.bestAltitude (the all-time record) increases, the scene must
    -- start a distancePunch countdown, mirroring the sample-pickup
    -- shipPunch pattern above.
    do
        local distanceScale = PlayScene.distancePunchScale
        assert(distanceScale(PlayScene.distancePunchDuration, PlayScene.distancePunchDuration) == 1.5,
            "punch scale must peak at 1.5x the instant the punch starts")
        assert(distanceScale(0, PlayScene.distancePunchDuration) == 1,
            "punch scale must settle back to 1x (no scale) once the countdown reaches zero")
        local midScale = distanceScale(PlayScene.distancePunchDuration / 2, PlayScene.distancePunchDuration)
        assert(midScale > 1 and midScale < 1.5, "punch scale must interpolate between 1x and 1.5x mid-countdown")

        local punchScene = PlayScene.new({
            bestAltitudeStore = { load = function() return 100 end, save = function() return false end },
        })
        assert(punchScene.expedition.bestAltitude == 100)
        assert(punchScene.distancePunch == 0, "distancePunch must start at rest with no fresh record")
        punchScene:update(0.1)
        assert(punchScene.distancePunch == 0,
            "distancePunch must stay at rest when bestAltitude does not increase")
        -- Simulate an external bestAltitude increase (the same effect an
        -- ascending run's expedition.update would produce) and confirm the
        -- next scene update notices the jump and starts the punch.
        punchScene.expedition.bestAltitude = 150
        punchScene:update(0.05)
        assert(punchScene.distancePunch == PlayScene.distancePunchDuration,
            "a bestAltitude increase must start the distance punch at full duration")
        punchScene:update(0.05)
        assert(punchScene.distancePunch < PlayScene.distancePunchDuration and punchScene.distancePunch > 0,
            "distancePunch must count down toward zero")
        punchScene:update(10)
        assert(punchScene.distancePunch == 0, "distancePunch must settle back to zero once expired")
    end

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
    -- Returning is the only phase where slot chances are live, so the
    -- S%02d segment must still appear there (docs/feedback/INBOX.md
    -- UI/HUD item 4 follow-up: hide S00 dead weight everywhere else).
    riskScene.expedition.slotOpportunities = 3
    local returningHud = riskScene:hudLines()
    assert(returningHud.samples == "SAMPLES 03  AT RISK $95")
    assert(returningHud.earth == "EARTH IN 725")
    assert(returningHud.returnProgress == "RETURN 28%  17s LEFT")
    assert(returningHud.status == "HULL 3/3 RETURN S03",
        "returning-phase status must keep the live slot count: "
        .. tostring(returningHud.status))
    -- docs/feedback/INBOX.md UI/HUD item 5: the small slot-odds line drawn
    -- above the minimap during the returning phase needs its own reserved
    -- vertical space in the HUD box (PlayScene.hudOddsLineHeight); without
    -- it, that line visually collided with the RETURN %%/s-left text right
    -- above it (confirmed via a real LÖVE runtime capture,
    -- GAME_CAPTURE_PHASE=returning-odds).
    assert(PlayScene.hudOddsLineHeight and PlayScene.hudOddsLineHeight > 0,
        "PlayScene.hudOddsLineHeight must exist and reserve room for the slot-odds line")
    assert(PlayScene.hudHeight("returning", returningHud, 0)
        == 280 + PlayScene.hudPrimaryStatusGap + PlayScene.hudOddsLineHeight,
        "returning HUD band height must grow by hudOddsLineHeight to fit the slot-odds line above the minimap")

    -- docs/feedback/INBOX.md UI/HUD item 4: the "개발 임시본"/"DEV PLACEHOLDER"
    -- footer is a permanent dev-only disclaimer, not gameplay info, so it
    -- must render smaller and dimmer than ordinary HUD text instead of
    -- competing with the message line above it (real LÖVE runtime capture
    -- previously showed it at full 14px default font and 0.85 alpha).
    assert(PlayScene.devPlaceholderFontSize and PlayScene.devPlaceholderFontSize < PlayScene.hudFontSize,
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
    -- docs/feedback/INBOX.md HUD 약자 정리 항목: "H%d/%d" read as a bare,
    -- unexplained abbreviation in real runtime captures. Spell out "HULL"
    -- (en) / read cleanly in ko via i18n.t rather than a single letter.
    -- docs/feedback/INBOX.md UI/HUD item 4 follow-up: settlement has no
    -- live slot chances (they were spent or wiped on the return), so
    -- "SETTLE S00" is the same dead-weight forecast launch used to show.
    assert(riskScene:hudLines().status == "HULL 3/3 SETTLE",
        "hud status must use a readable 'HULL' label and omit the always-zero slot forecast: "
        .. tostring(riskScene:hudLines().status))
    assert(not riskScene:hudLines().status:find("F%d"),
        "hud status must not show a misleading fuel-cap readout")
    assert(not riskScene:hudLines().status:find("S%d%d"),
        "settlement-phase status must not show a slot count segment")
    -- docs/feedback/INBOX.md UI/HUD item 4: during launch/ascending the
    -- slot forecast (S%02d) is always 0 because no return trip has
    -- happened yet, so "LAUNCH S00"/"ASCEND S00" reads as confusing dead
    -- weight. Drop the slot segment for every phase except returning,
    -- where the count is live.
    riskScene.expedition.phase = "launch"
    assert(riskScene:hudLines().status == "HULL 3/3 LAUNCH",
        "launch-phase status must omit the always-zero slot forecast: "
        .. tostring(riskScene:hudLines().status))
    assert(not riskScene:hudLines().status:find("S%d%d"),
        "launch-phase status must not show a slot count segment")
    riskScene.expedition.phase = "ascending"
    local ascendingHud = riskScene:hudLines()
    assert(ascendingHud.status == "HULL 3/3 ASCEND",
        "ascending-phase status must omit the always-zero slot forecast: "
        .. tostring(ascendingHud.status))
    assert(not ascendingHud.status:find("S%d%d"),
        "ascending-phase status must not show a slot count segment")
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
        == 184 + PlayScene.hudPrimaryStatusGap,
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
    assert(wipedReturn.durabilityUpgradeLevel == 0)
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
    assert(run.phase == "ascending" and run.fuel == nil and run.altitude == 60)
    assert(expedition.collectSample(run, 75))
    assert(run.sampleCount == 1 and run.pendingSampleValue == 75 and run.money == 0)
    expedition.update(run, 1)
    assert(run.phase == "ascending" and run.fuel == nil and run.altitude == 120)
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
    steeringMoveScene.touches["upgraded-steer"] = { x = 640, y = 10 }
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
        == "HULL UPGRADED  LV.1  HULL 4  BALANCE $10")
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
    shopScene:touchpressed("ship", 540, 1016)
    assert(shopScene.expedition.ownedShips.scout and shopScene.expedition.selectedShipId == "scout")
    assert(shopScene.expedition.money == 20)
    -- docs/feedback/INBOX.md item 11(b): with the fuel-tank shop upgrade
    -- fuel alone (100 base + 40 scout bonus = 140 fuel), not a previously
    -- purchased fuel tank.
    assert(shopScene.message
        == "SCOUT PURCHASED AND SELECTED  HULL 3  BALANCE $20")

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
        == "HULL UPGRADED  LV.1  HULL 3  BALANCE $20")

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
        == "HULL UPGRADED  LV.2  HULL 5  BALANCE $100")

    local shortfallScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    shortfallScene.expedition.phase = "settlement"
    shortfallScene.expedition.money = 20
    shortfallScene:keypressed("h")
    assert(shortfallScene.expedition.durabilityUpgradeLevel == 0)
    assert(shortfallScene.message == "NEED $55 MORE FOR HULL UPGRADE")
    shortfallScene:touchpressed("ship", 540, 1016)
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
    touchScene:touchpressed("steer-right", 640, 160)
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
    touchScene:touchpressed("return-left", 80, 1064)
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
    touchScene:touchpressed("slot", 360, 1064)
    assert(touchScene.expedition.slotSpins == 1 and touchScene.expedition.slotOpportunities == 1)
    local returnSteeredX = touchScene.ship.x
    touchScene:update(1)
    assert(touchScene.ship.x == returnSteeredX)
    touchScene:touchpressed("return-right", 640, 1064)
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
    returnAvoidanceScene:touchpressed("avoid-left", 80, 1064)
    returnAvoidanceScene:update(1)
    world.nearbyPlanets = nearbyPlanets
    assert(returnAvoidanceScene.ship.x == -55)
    assert(returnAvoidanceScene.expedition.durability == 3)
    assert(not returnAvoidanceScene.collided[avoidablePlanet.id])

    assert(table.concat(touchScene.expedition.lastSlotSymbols, " ") == "STAR STAR STAR")
    assert(touchScene.message == "STAR STAR STAR +$75  1 LEFT")
    local readySlotButton = touchScene:slotButtonState()
    assert(readySlotButton.enabled and readySlotButton.label == "TAP: SLOT SPIN  1 LEFT")
    touchScene:touchpressed("last-slot", 360, 1064)
    assert(touchScene.expedition.slotSpins == 2 and touchScene.expedition.slotOpportunities == 0)
    local spinningSlotButton = touchScene:slotButtonState()
    assert(not spinningSlotButton.enabled and spinningSlotButton.label == "SLOT SPINNING...")
    touchScene:update(1)
    local emptySlotButton = touchScene:slotButtonState()
    assert(not emptySlotButton.enabled and emptySlotButton.label == "NO SLOT CHANCES")
    touchScene:touchpressed("empty-slot", 360, 1064)
    assert(touchScene.expedition.slotSpins == 2 and touchScene.expedition.slotOpportunities == 0)
    touchScene.expedition.phase = "settlement"
    touchScene.expedition.money = touchScene.expedition.durabilityUpgradeCost
        + touchScene.expedition.scoutShipCost
    touchScene:touchpressed("hull", 180, 832)
    touchScene:touchpressed("ship", 540, 1016)
    assert(touchScene.expedition.fuelUpgradeLevel == nil)
    assert(touchScene.expedition.durabilityUpgradeLevel == 1)
    assert(touchScene.expedition.ownedShips.scout and touchScene.expedition.selectedShipId == "scout")
    touchScene:touchpressed("relaunch", 360, 1200)
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
    assert(starterLoadout.upgrades == nil,
        "docs/feedback/INBOX.md UI 대개편 6건 item 2: HULL LV.n line removed, durability shown top-left instead")
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
    assert(upgradedLoadout.upgrades == nil)
    assert(upgradedLoadout.steering == "STEER SPEED 70")
    assert(expedition.launch(loadoutScene.expedition))
    assert(expedition.damage(loadoutScene.expedition, loadoutScene.expedition.maxDurability))
    local resetLoadout = loadoutScene:loadoutLines()
    -- Destruction wipes ownedShips back down to only STARTER, so the ship
    -- line is hidden again post-reset for the same reason as above.
    assert(resetLoadout.ship == nil,
        "loadout ship line should be hidden again after a meta-wipe reset")
    assert(resetLoadout.stats == "HULL 3")
    assert(resetLoadout.upgrades == nil)
    assert(resetLoadout.steering == "STEER SPEED 55")

    local nextLaunchScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    nextLaunchScene.expedition.phase = "settlement"
    local starterNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(starterNextLaunch.ship == "NEXT STARTER")
    assert(starterNextLaunch.stats == "HULL 3")
    assert(starterNextLaunch.upgrades == nil)
    assert(starterNextLaunch.scoutTradeoff[1] == "LOSSES -1 HULL")
    assert(starterNextLaunch.scoutTradeoff[2] == nil)
    assert(starterNextLaunch.shipAction == "BUY SCOUT $125")
    assert(starterNextLaunch.shipPreview == "SCOUT HULL 2")
    assert(starterNextLaunch.shipPreviewForecast == nil)
    assert(starterNextLaunch.fuelAction == nil)
    assert(starterNextLaunch.fuelPreviewForecast == nil)
    assert(starterNextLaunch.fuelStatus == nil)
    assert(starterNextLaunch.hullAction == "T/H HULL LV.0>1 $75")
    assert(starterNextLaunch.hullPreview == "HULL 4")
    assert(starterNextLaunch.hullPreviewForecast == nil)
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
    assert(fueledNextLaunch.upgrades == nil)
    assert(fueledNextLaunch.fuelAction == nil)
    assert(fueledNextLaunch.hullAction == "T/H HULL LV.0>1 $75")
    assert(fueledNextLaunch.shipPreviewForecast == nil)
    assert(fueledNextLaunch.fuelPreviewForecast == nil)
    assert(fueledNextLaunch.hullPreview == "HULL 4")
    assert(fueledNextLaunch.hullPreviewForecast == nil)
    nextLaunchScene:keypressed("h")
    local reinforcedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reinforcedNextLaunch.stats == "HULL 4")
    assert(reinforcedNextLaunch.upgrades == nil)
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
    assert(scoutNextLaunch.upgrades == nil)
    assert(scoutNextLaunch.shipPreviewForecast == nil)
    assert(scoutNextLaunch.fuelAction == nil)
    assert(scoutNextLaunch.fuelPreviewForecast == nil)
    assert(scoutNextLaunch.hullAction == "T/H HULL LV.1>2 $75")
    assert(scoutNextLaunch.hullPreview == "HULL 4")
    assert(scoutNextLaunch.hullPreviewForecast == nil)
    assert(scoutNextLaunch.scoutTradeoff[1] == "LOSSES -1 HULL")
    assert(scoutNextLaunch.scoutTradeoff[2] == nil)
    assert(scoutNextLaunch.shipAction == "SELECT STARTER")
    assert(scoutNextLaunch.shipStatus == "OWNED" and scoutNextLaunch.shipAffordable)
    nextLaunchScene:keypressed("v")
    local reselectedNextLaunch = nextLaunchScene:shopLoadoutLines()
    assert(reselectedNextLaunch.ship == "NEXT STARTER")
    assert(reselectedNextLaunch.stats == "HULL 4")
    assert(reselectedNextLaunch.upgrades == nil)
    assert(reselectedNextLaunch.fuelPreviewForecast == nil)
    assert(reselectedNextLaunch.shipAction == "SELECT SCOUT")
    -- docs/feedback/INBOX.md item 11(b): with the fuel-tank shop upgrade
    -- alone (starter 100, scout 140), never a previously purchased tank.
    assert(nextLaunchScene.message
        == "STARTER SELECTED  HULL 4")
    nextLaunchScene:touchpressed("ship", 540, 1016)
    assert(nextLaunchScene.expedition.selectedShipId == "scout")
    assert(nextLaunchScene.message
        == "SCOUT SELECTED  HULL 3")
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
    persistedScene.expedition.climbSpeed = 60
    assert(expedition.launch(persistedScene.expedition))
    persistedScene.expedition.altitude = 60
    persistedScene.expedition.maxAltitude = 60
    persistedScene.expedition.bestAltitude = 60
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

    -- docs/feedback/INBOX.md UI 대개편 6건 item 4: the "C50 P40 S10  EV
    -- $18.58" slot-odds text near the minimap was unclear enough that the
    -- user mistook it for coordinates and it lost meaning once the slot
    -- machine moved to the Earth shop (item 15). PlayScene:slotOddsLine()
    -- and the "odds" fields on loadoutLines()/shopLoadoutLines() are
    -- removed entirely -- replaced by a small always-shown ship-coordinate
    -- readout near the minimap (M.shipCoordsLine below).
    assert(PlayScene.slotOddsLine == nil, "slotOddsLine must be fully removed, not just unused")

    local oddsLoadoutScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    local launchLoadoutOdds = oddsLoadoutScene:loadoutLines()
    assert(launchLoadoutOdds.odds == nil, "loadoutLines() must no longer expose a slot-odds line")
    oddsLoadoutScene.expedition.phase = "settlement"
    local shopLoadoutOdds = oddsLoadoutScene:shopLoadoutLines()
    assert(shopLoadoutOdds.odds == nil, "shopLoadoutLines() must no longer expose a slot-odds line")

    -- New: a small "(x, y)" ship-coordinate readout replaces the removed
    -- slot-odds line near the minimap, always shown (not gated to the
    -- returning phase like the old odds line was).
    assert(PlayScene.shipCoordsLine(120, -340) == "(120, -340)")
    assert(PlayScene.shipCoordsLine(0, 0) == "(0, 0)")
    assert(PlayScene.shipCoordsLine(119.6, -339.6) == "(120, -340)",
        "coordinates must round to the nearest integer")
    assert(PlayScene.shipCoordsLine(-0.4, 0.4) == "(0, 0)",
        "rounding must not produce a signed zero or off-by-one near zero")

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

    -- The smallest supported window (integer scale 1, e.g. 720x1280) at a 1x
    -- device pixel ratio is the worst case for touch-target accessibility.
    -- iOS/Android guidelines require ~44pt minimum; verify every settlement
    -- row actually clears that bar via the real canvas-to-points conversion,
    -- not just the previously-checked 34px minimum.
    for _, row in ipairs(PlayScene.settlementTouchRows) do
        local heightPoints = viewport.canvasPixelsToPoints(row.bottom - row.top, 720, 1280, 1, false)
        assert(heightPoints >= 44,
            "settlement touch row " .. (row.key or "columns")
                .. " is under the 44pt accessibility minimum at scale 1 (" .. heightPoints .. "pt)")
        if row.columns then
            for _, column in ipairs(row.columns) do
                local widthPoints = viewport.canvasPixelsToPoints(column.right - column.left, 720, 1280, 1, false)
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
        returnControls.bottom - returnControls.top, 720, 1280, 1, false)
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
    returnEdgeScene:touchpressed("edge-right", 640, returnControls.bottom - 1)
    local edgeRightSteering = returnEdgeScene:steeringButtonState()
    assert(not edgeRightSteering.leftActive and edgeRightSteering.rightActive,
        "returning band bottom edge did not register right steering")
    returnEdgeScene:touchreleased("edge-right")
    returnEdgeScene:touchpressed("edge-slot", math.floor((returnControls.slotMinX + returnControls.slotMaxX) / 2), returnControls.top)
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
    -- so the functional touch target has always spanned the full 720x1280
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
        launchArea.bottom - launchArea.top, 720, 1280, 1, false)
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
    local shipScreenY = math.floor(viewport.height * 0.58)
    local cameraY = 0 - shipScreenY
    local earthY = math.floor(PlayScene.earthCenterY - cameraY)
    local earthTopY = earthY - PlayScene.earthRadius
    assert(PlayScene.launchLoadoutBoxTop <= earthTopY,
        "launch loadout box top (" .. PlayScene.launchLoadoutBoxTop ..
        ") does not fully cover the Earth disc's top edge (" .. earthTopY .. ")")

    -- docs/feedback/INBOX.md "UI 대개편 6건" item 1: the "SPECIMENS n/9"
    -- specimen log strip is pure decoration with no gameplay effect (user
    -- ruling, 2026-09-03) and should be fully removed from the launch
    -- screen. M.showSpecimenStrip gates the drawSpecimenStrip() call in
    -- draw(); this regression pins it to false so the strip stays gone.
    assert(PlayScene.showSpecimenStrip == false,
        "launch screen specimen strip should stay hidden (docs/feedback UI overhaul item 1)")

    -- docs/feedback/INBOX.md "UI 대개편 6건" item 6: user wants the "DEV
    -- PLACEHOLDER"/"개발 임시본" footer fully invisible (not just smaller/
    -- dimmer, which an earlier cycle already did). M.showDevPlaceholder
    -- gates the conditional draw() call; pin it false so the footer stays
    -- fully gone.
    assert(PlayScene.showDevPlaceholder == false,
        "dev placeholder footer should be fully hidden (docs/feedback UI overhaul item 6)")

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
    ascendEdgeScene:touchpressed("ascend-edge-right", 640, ascendControls.bottom - 1)
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

    -- The next launch clears the banked bonus (no fuel field exists to
    -- apply it to any more -- see docs/feedback/INBOX.md 항목 11(c)/15).
    assert(expedition.launch(fuelBonusRun))
    assert(fuelBonusRun.fuel == nil,
        "launch must never resurrect a dead fuel field even with a banked bonus")
    assert(fuelBonusRun.bankedFuelBonus == 0, "banked fuel bonus must be consumed by the launch it funds")

    -- A second launch (no new bonus earned) must not carry over a bonus.
    fuelBonusRun.phase = "settlement"
    assert(expedition.launch(fuelBonusRun))
    assert(fuelBonusRun.fuel == nil,
        "launches must never carry a fuel field, banked bonus or not")

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
    assert(fuelBonusMessageScene.message == "PLANET PLANET PLANET +$40  0 LEFT",
        "slot spin completion must drop no-op FUEL framing: " .. tostring(fuelBonusMessageScene.message))

    -- The EARTH SHOP summary card hides the banked next-expedition fuel
    -- bonus while launch consumes it as a no-op (no run.fuel field).
    local fuelBonusSummaryScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    fuelBonusSummaryScene.expedition.bankedFuelBonus = 0
    assert(PlayScene.summaryFuelBonusLine == nil,
        "no fuel bonus banked must show no summary helper")
    fuelBonusSummaryScene.expedition.bankedFuelBonus = 15
    assert(fuelBonusSummaryScene.summaryFuelBonusLine == nil,
        "banked fuel bonus must not expose a settlement summary helper")

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
    testGearAndCheckpointSettlement()
    testCheckpointAndShopDocking()
    testMinimap()
    testDebris()
    testBackgroundStars()
    testLaunchRocketIcon()
    testLaunchPromptCue()
    testHullShieldIcon()
    testCashCoinIcon()
    testSteerSpeedIcon()
    testPeakDistLine()
    testFuelBonusTextHidden()
    testScoutFuelGainHidden()
    testLaunchForecastRemoved()
    testFuelUpgradeHiddenFromShop()
    testFuelUpgradeMessagingRemoved()
    testSpecimenSprites()
    testShipSprite()
    testPlanetSprite()
    testEarthSprite()
    testSampleEffectSprite()
    testBackgroundSprite()
    testSlotSymbolSprites()
    testShopIconSprites()
    testDebrisSprites()
    testPlanetTwinkleSprite()
    testCollisionEffectSprite()
    testThrustEffectSprite()
    testPlanetGlowSprite()
    testPlanetShadowSprite()
    testMinimapDiscSprite()
    testJoystickPadSprite()
    testJoystickKnobSprite()
    testCashIconSprite()
    testHullIconSprite()
    testSpeedIconSprite()
    testCheckpointStarSprite()
    testCheckpointArrowSprite()
    testMinimapPlayerSprite()
    testMinimapSunSprite()
    testMinimapEarthSprite()
    testMinimapGalaxyHomeSprite()
    testMinimapGalaxyPlainSprite()
    testMinimapEarthReturnSprite()
    testMinimapSpiralArmSprite()
    testMinimapOrbitRingSprite()
    testMinimapGalaxyRingSprite()
    testHubPlanetSprite()
    testShopPlanetSprite()
    testCanvasLayoutScale()

    print("SPACESHIP_UNIT_OK")
end

return M
