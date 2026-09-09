local M = {}

function M.install(scene, deps)
    local world = deps.world
    local expedition = deps.expedition
    local sfx = deps.sfx
    local i18n = deps.i18n
    local shortestAngleDelta = deps.shortestAngleDelta
    local sampleRollupDuration = deps.sampleRollupDuration
    local rollupAmount = deps.rollupAmount
    local stickTurnFollow = deps.stickTurnFollow
    local steerTurnRate = deps.steerTurnRate
    local sampleTierShakeMultiplier = deps.sampleTierShakeMultiplier
    local shipShakeDuration = deps.shipShakeDuration
    local shipPunchDuration = deps.shipPunchDuration
    local rcsPuffDuration = deps.rcsPuffDuration
    local pulseHaptic = deps.pulseHaptic
    local viewport = deps.viewport

function scene:update(dt)
    -- Item 18: when paused during ascending, zero dt to freeze game state.
    -- We still allow time/collectFlash to be updated for visual continuity,
    -- but the main game tick gets dt=0.
    if self.paused and self.expedition.phase == "ascending" then
        return
    end
    -- Gear popup freezes the game too (user 2026-09-07)
    if self.gearPopup and self.expedition.phase == "ascending" then
        return
    end
    -- INBOX (48): help overlay freezes like pause; pause menu stays closed.
    if self:shouldFreezeUpdate() then
        return
    end
    -- Auto-unpause if phase changed away from ascending while paused.
    if self.paused and self.expedition.phase ~= "ascending" then
        self.paused = false
    end

    if not self.launchInputArmed then
        local anyTouch = next(self.touches) ~= nil
        local mouse = love.mouse and love.mouse.isDown(1)
        local space = love.keyboard and love.keyboard.isDown("space")
        if not anyTouch and not mouse and not space then
            self.launchInputArmed = true
        end
    end

    local rawDt = dt
    if self.timeSlip then
        self.timeSlip.timer = self.timeSlip.timer - rawDt
        if self.timeSlip.timer <= 0 then
            self.timeSlip = nil
        else
            dt = dt * self.timeSlip.scale
        end
    end
    if self.collectFlash and self.collectFlash > 0 then
        self.collectFlash = math.max(0, self.collectFlash - rawDt)
    end
    if self.collectZoom then
        self.collectZoom.timer = self.collectZoom.timer - rawDt
        if self.collectZoom.timer <= 0 then
            self.collectZoom = nil
        end
    end
    self.time = self.time + dt

    self:updateSlotMachine(dt, rawDt)

    self:pollDesktopMouse()
    local steering = self:steeringButtonState()
    local previousPhase = self.expedition.phase
    for i = #self.floatingTexts, 1, -1 do
        local ft = self.floatingTexts[i]
        ft.timer = ft.timer - dt
        ft.y = ft.y - 20 * dt
        if ft.kind == "sample" and ft.awarded and ft.rollupElapsed < sampleRollupDuration then
            ft.rollupElapsed = math.min(sampleRollupDuration, ft.rollupElapsed + dt)
            ft.text = i18n.t("floating_sample_gain", rollupAmount(ft.awarded, ft.rollupElapsed, sampleRollupDuration))
        end
        if ft.timer <= 0 then
            table.remove(self.floatingTexts, i)
        end
    end
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.timer = particle.timer - dt
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        if particle.timer <= 0 then
            table.remove(self.particles, i)
        end
    end
    if self.shipPunch > 0 then
        self.shipPunch = math.max(0, self.shipPunch - dt)
    end
    if self.shipShake > 0 then
        self.shipShake = math.max(0, self.shipShake - dt)
    end
    if self.newSpecimenBannerTimer > 0 then
        self.newSpecimenBannerTimer = math.max(0, self.newSpecimenBannerTimer - dt)
        if self.newSpecimenBannerTimer == 0 then
            self.newSpecimenBanner = nil
        end
    end
    if self.shopModal then
        return
    end
    -- Item 2: returning phase abolished; only ascending has steering/movement.
    if self.expedition.phase == "ascending" then
        local xBeforeThrust, yBeforeThrust = self.ship.x, self.ship.y
        local joyDx, joyDy, joyMagnitude = self:joystickVector()
        local thrustAngle = self.ship.angle
        local speed = expedition.effectiveSpeed(self.expedition)
        -- Boost active: multiply speed temporarily
        if self.boostActive then
            self.boostActive.timer = self.boostActive.timer - dt
            if self.boostActive.timer <= 0 then
                self.boostActive = nil
            else
                speed = speed * self.boostActive.speedMultiplier
            end
        end
        self:updateBoostSpeedLines(dt)
        local wellGalaxy = world.galaxyContaining(self.ship.x, self.ship.y)
        -- INBOX 61(36): galaxy discover SFX — once per galaxy
        if wellGalaxy then sfx.playGalaxyDiscover(wellGalaxy) end
        local wellSun = wellGalaxy and world.sunPosition(wellGalaxy)
        if wellSun then
            local wdx, wdy = wellSun.x - self.ship.x, wellSun.y - self.ship.y
            if wdx * wdx + wdy * wdy < world.starWellRadius * world.starWellRadius then
                speed = world.starWellSpeed(wellGalaxy)
            end
        end
        if joyMagnitude > 0 then
            self.ship.x = self.ship.x + joyDx * speed * joyMagnitude * dt
            self.ship.y = self.ship.y + joyDy * speed * joyMagnitude * dt
        else
            self.ship.x = self.ship.x
                + ((steering.rightActive and 1 or 0) - (steering.leftActive and 1 or 0))
                * speed * dt
            self.ship.y = self.ship.y
                    + ((steering.downActive and 1 or 0) - (steering.upActive and 1 or 0))
                    * speed * dt
        end
        local steeringHoriz = (steering.rightActive and 1 or 0) - (steering.leftActive and 1 or 0)
        local steeringVert = (steering.downActive and 1 or 0) - (steering.upActive and 1 or 0)
        local thrusting = joyMagnitude > 0 or steeringHoriz ~= 0 or steeringVert ~= 0
        if joyMagnitude > 0 then
            local targetAngle = self.headingFromStick(joyDx, joyDy)
            local delta = shortestAngleDelta(self.ship.angle, targetAngle)
            local turnRate = math.min(1, stickTurnFollow * dt)
            self.ship.angle = self.ship.angle + delta * turnRate
            self.steerBank = joyDx * joyMagnitude
            self.steerLift = joyDy * joyMagnitude
        elseif steeringHoriz ~= 0 or steeringVert ~= 0 then
            self.ship.angle = self.ship.angle + steeringHoriz * steerTurnRate * dt
            self.steerBank = steeringHoriz
            self.steerLift = steeringVert
        else
            self.steerBank = 0
            self.steerLift = 0
        end
        if thrusting then
            expedition.update(self.expedition, dt)
            if dt > 0 then
                self.ship.vx = (self.ship.x - xBeforeThrust) / dt
                self.ship.vy = (self.ship.y - yBeforeThrust) / dt
            end
        elseif previousPhase == "ascending" then
            -- Coast on stored velocity.
            self.ship.x = self.ship.x + (self.ship.vx or 0) * dt
            self.ship.y = self.ship.y + (self.ship.vy or 0) * dt
        else
            expedition.update(self.expedition, dt)
        end

        self.rcsCooldown = math.max(0, (self.rcsCooldown or 0) - dt)
        local bank = self.steerBank or 0
        local lift = self.steerLift or 0
        local stickMag = math.sqrt(bank * bank + lift * lift)
        if thrusting and self.rcsCooldown == 0 and stickMag > 0.12 then
            self.rcsCooldown = self.boostActive and 0.02 or 0.045
            -- Single RCS puff in the opposite direction of the stick vector.
            local dirX = -bank / stickMag
            local dirY = -lift / stickMag
            -- Continuous 0–999 speed gradient (white→red→blue→rainbow).
            local rcsR, rcsG, rcsB, rcsRad = expedition.rcsVisual(
                self.expedition, self.time or 0, #self.particles)
            local speedMult = 1
            if self.boostActive then
                rcsR, rcsG, rcsB = 1, 0.85, 0.3
                rcsRad = rcsRad * 2.5
                speedMult = 2
            end
            self.particles[#self.particles + 1] = {
                x = self.ship.x + dirX * 6,
                y = self.ship.y + dirY * 6,
                vx = dirX * (16 + math.random() * 10) * speedMult,
                vy = dirY * (16 + math.random() * 10) * speedMult,
                timer = rcsPuffDuration,
                maxTimer = rcsPuffDuration,
                r = rcsR,
                g = rcsG,
                b = rcsB,
                radius = rcsRad,
            }
        end
    end
    if previousPhase ~= self.expedition.phase and self.expedition.phase == "settlement" then
        self:persistBestAltitude()
        self.message = i18n.t("settled_message", self.expedition.lastSettlement, self.expedition.money)
        -- Item 7(c): Roll one Earth-shop gear offer on settlement entry.
        -- Uses gear.earthShopPool to exclude galaxy-exclusive parts (those
        -- are only obtainable via hub exploration — item 7(b)).
        if not self.earthShopGearOffer then
            local gearMod = require("game.gear")
            local hull = gearMod.loadHullParts() or {}
            local engine = gearMod.loadEngineParts() or {}
            local combined = {}
            for _, p in ipairs(hull) do combined[#combined+1] = p end
            for _, p in ipairs(engine) do combined[#combined+1] = p end
            -- Hub settlements use full pool (incl. galaxyExclusive);
            -- Earth uses earthShopPool (excludes galaxyExclusive+slotExclusive).
            -- Both exclude slotExclusive (INBOX 61(15): slot-only parts).
            local isHub = self.expedition.lastVisitedGalaxyId ~= nil
            local hubPool = {}
            if isHub then
                for _, p in ipairs(combined) do
                    if not p.slotExclusive then hubPool[#hubPool+1] = p end
                end
            end
            local pool = isHub and hubPool or gearMod.earthShopPool(combined)
            local rolls = {
                rarity = math.random(),
                pick = math.random(),
                editionChance = math.random(),
                editionPick = math.random(),
            }
            self.earthShopGearOffer = expedition.rollGearOffer(self.expedition, pool, rolls)
        end
    end
    if self.expedition.phase == "ascending" then
        local dx = self.ship.x - self.earthCenterX
        local dy = self.ship.y - self.earthCenterY
        local earthDistSq = dx * dx + dy * dy
        local earthDist = math.sqrt(earthDistSq)
        self.reentryShake = self.reentryShakeFromDistance(earthDist)
        self.reentryHeatAlpha = self.reentryHeatVignetteAlpha(earthDist)
        -- Vibrate once when first entering Earth proximity, not every frame
        if self.reentryHeatAlpha > 0.04 then
            if not self.earthHapticFired then
                self.earthHapticFired = true
                pulseHaptic(self, 0.06)
            end
        else
            self.earthHapticFired = false
        end

        -- self.earthVisualRadius * 1.5 is 87, but settle is 88. To trigger BEFORE settle,
        -- use a slightly larger radius, e.g. self.earthSettleRadius + 15 (103).
        if not self.hasReentrySlowmo and earthDist < self.earthSettleRadius + 15 then
            self.hasReentrySlowmo = true
            self.timeSlip = {timer = 0.6, scale = 0.5}
        end

        if earthDistSq > self.earthSettleRadius * self.earthSettleRadius then
            if not self.hasLeftEarth then
                self.leftEarthTime = self.time or 0
            end
            self.hasLeftEarth = true
        elseif self.hasLeftEarth then
            expedition.settle(self.expedition)
            self.hasLeftEarth = false
            self.reentryShake = 0
            self.reentryHeatAlpha = 0
        end

        -- Item 9: Central star gravity well — pull, DoT, 10s sample
        do
            local galaxy = world.galaxyContaining(self.ship.x, self.ship.y)
            local sun = galaxy and world.sunPosition(galaxy)
            local inWell = false
            if sun then
                local sdx, sdy = sun.x - self.ship.x, sun.y - self.ship.y
                local sunDist = math.sqrt(sdx * sdx + sdy * sdy)
                if sunDist < world.starWellRadius then
                    inWell = true
                    sfx.play("star_sample")
                    -- Pull can never exceed 80% of helm speed so the player
                    -- always makes slow progress outward, but near the center
                    -- it's a real struggle.
                    if sunDist > 1 then
                        local t = math.max(0, 1 - sunDist / world.starWellRadius)
                        local helmSpeed = world.starWellSpeed(wellGalaxy)
                        -- Linear in t, capped at 80% of helm so always escapable
                        local pullStrength = helmSpeed * 0.8 * t
                        local nx, ny = sdx / sunDist, sdy / sunDist
                        self.ship.x = self.ship.x + nx * pullStrength * dt
                        self.ship.y = self.ship.y + ny * pullStrength * dt
                    end
                    -- Gentle continuous shake + red vignette like Earth reentry
                    self.starWellShake = 0.4
                    self.starWellHeatAlpha = math.max(0.08, 0.32 * (1 - sunDist / world.starWellRadius))
                    pulseHaptic(self, 0.05)
                    -- DoT damage accumulator
                    self.starDotAccum = self.starDotAccum + dt
                    while self.starDotAccum >= world.starDotInterval do
                        self.starDotAccum = self.starDotAccum - world.starDotInterval
                        table.insert(self.floatingTexts, {
                            text = i18n.t("floating_damage_text", 1),
                            x = self.ship.x + 60,
                            y = self.ship.y,
                            timer = 1.0,
                            kind = "damage",
                        })
                        self.shipShake = shipShakeDuration * 0.5
                        self.shipShakeMagnitude = 0.6
                        if expedition.damage(self.expedition, 1) then
                            self:persistBestAltitude()
                            self.message = i18n.t("ship_destroyed_message",
                                math.floor(self.expedition.bestAltitude))
                            inWell = false
                            break
                        end
                    end
                    -- 10-second survival timer
                    if inWell and not self.starWellSampled[galaxy.id] then
                        self.starWellTimer = self.starWellTimer + dt
                        if self.starWellTimer >= world.starSurvivalTime then
                            self.starWellSampled[galaxy.id] = true
                            local value = world.sampleValue({ y = sun.y })
                            local _, awarded = expedition.collectSample(
                                self.expedition, value, "star")
                            table.insert(self.floatingTexts, {
                                text = i18n.t("star_well_sample")
                                    .. " +$" .. (awarded or value),
                                x = self.ship.x,
                                y = self.ship.y - 20,
                                timer = 3.0,
                                kind = "sample",
                                awarded = awarded or value,
                                rollupElapsed = 0,
                            })
                            -- Engine part drop on star sample (same as hub explore)
                            local gearMod = require("game.gear")
                            local enginePool = gearMod.loadEngineParts() or {}
                            if #enginePool > 0 then
                                local drop = expedition.exploreHub(self.expedition, galaxy.id, enginePool, {
                                    editionChance = love.math.random(),
                                    editionPick = love.math.random()
                                })
                                if drop then
                                    local ok = expedition.equipGear(self.expedition, "engine", drop)
                                    if ok then
                                        self.gearPopup = { part = drop, category = "engine" }
                                        table.insert(self.floatingTexts, {
                                            text = i18n.t("floating_hub_gear", i18n.partName(drop)),
                                            x = self.ship.x,
                                            y = self.ship.y - 40,
                                            timer = 3.0,
                                            kind = "sample",
                                            awarded = 0,
                                            rollupElapsed = 0,
                                        })
                                    end
                                end
                            end
                        end
                    end
                end
            end
            if not inWell then
                sfx.stop("star_sample")
                self.starWellTimer = 0
                self.starDotAccum = 0
                self.starWellShake = math.max(0, (self.starWellShake or 0) - dt * 2)
                self.starWellHeatAlpha = math.max(0, (self.starWellHeatAlpha or 0) - dt * 1.5)
            end
        end
        -- Hub checkpoint proximity: same green vignette + haptic as Earth
        do
            local nearestHubDist = math.huge
            local hubRadius = 80
            for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 4)) do
                if planet.hub then
                    local hdx = planet.x - self.ship.x
                    local hdy = planet.y - self.ship.y
                    local hd = math.sqrt(hdx * hdx + hdy * hdy)
                    local range = math.max(planet.radius * 3, 90)
                    if hd < nearestHubDist then
                        nearestHubDist = hd
                        hubRadius = range
                    end
                end
            end
            if nearestHubDist < hubRadius then
                local wasOutside = (self.hubHeatAlpha or 0) <= 0
                self.hubHeatAlpha = 0.3 * (1 - nearestHubDist / hubRadius)
                -- Vibrate once on first entry, not every frame
                if wasOutside then
                    pulseHaptic(self, 0.06)
                end
            else
                self.hubHeatAlpha = math.max(0, (self.hubHeatAlpha or 0) - dt * 1.5)
            end
        end
        for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 4)) do
            local dx, dy = planet.x - self.ship.x, planet.y - self.ship.y
            local distanceSquared = dx * dx + dy * dy
            if self.expedition.phase == "ascending"
                and distanceSquared <= (self.collectOrbitRadius(planet.radius, self.expedition)) ^ 2
                and not self.discovered[planet.id] then
                self.discovered[planet.id] = true
                self.discoveredCount = self.discoveredCount + 1

                if planet.hub then
                    -- INBOX (47): hub planets open full settlement shop.
                    -- 1. exploreHub for gear drop (before settlement changes phase)
                    if not self.expedition.hubExplored[planet.galaxyId] then
                        sfx.play("hub_sample")
                        local gear = require("game.gear")
                        local pool = {}
                        local hull = gear.loadHullParts() or {}
                        local engine = gear.loadEngineParts() or {}
                        for _, p in ipairs(hull) do pool[#pool+1] = p end
                        for _, p in ipairs(engine) do pool[#pool+1] = p end
                        local drop = expedition.exploreHub(self.expedition, planet.galaxyId, pool, {
                            editionChance = love.math.random(),
                            editionPick = love.math.random()
                        })
                        if drop then
                            local cat = "hull"
                            if gear.findById(engine, drop.id) then cat = "engine" end
                            local ok = expedition.equipGear(self.expedition, cat, drop)
                            if ok then
                                -- Show Balatro-style part detail popup on acquisition
                                self.gearPopup = { part = drop, category = cat }
                                table.insert(self.floatingTexts, {
                                    text = i18n.t("floating_hub_gear", i18n.partName(drop)),
                                    x = planet.x,
                                    y = planet.y + 20,
                                    timer = 3.0,
                                    kind = "sample",
                                    awarded = 0,
                                    rollupElapsed = 0,
                                })
                            end
                        end
                    end
                    -- 2. Store hub position for relaunch spawn
                    self.expedition.lastHubX = planet.x
                    self.expedition.lastHubY = planet.y
                    -- 3. Enter full settlement (same as Earth return)
                    expedition.settle(self.expedition)
                    self.hasLeftEarth = false
                    self.reentryShake = 0
                    self.reentryHeatAlpha = 0
                elseif planet.isShop then
                    if not self.shopModal then
                        local gearMod = require("game.gear")
                        local pool = {}
                        local hull = gearMod.loadHullParts() or {}
                        local engine = gearMod.loadEngineParts() or {}
                        for _, p in ipairs(hull) do
                            if not p.slotExclusive then pool[#pool+1] = p end
                        end
                        for _, p in ipairs(engine) do
                            if not p.slotExclusive then pool[#pool+1] = p end
                        end

                        local prng = love.math.newRandomGenerator()
                        prng:setSeed(world.hash(planet.x, planet.y, 900) * 1000000)

                        local rolls = {
                            rarity = prng:random(),
                            pick = prng:random(),
                            editionChance = prng:random(),
                            editionPick = prng:random()
                        }

                        local offer = expedition.rollGearOffer(self.expedition, pool, rolls)
                        if offer then
                            local cat = "hull"
                            if gearMod.findById(engine, offer.id) then cat = "engine" end
                            self.shopModal = {
                                planet = planet,
                                gear = offer,
                                category = cat,
                                price = expedition.shopPrice(self.expedition, gearMod.buyPrice(offer))
                            }
                        end
                    end
                else
                    local value = world.sampleValue(planet)
                    local hueKey = world.hueFamily(planet.hue or 0).key
                    local _, awarded, streakMultiplier = expedition.collectSample(self.expedition, value, hueKey)
                    awarded = awarded or value
                    sfx.play("collect")
                    table.insert(self.floatingTexts, {
                        text = i18n.t("floating_sample_gain", rollupAmount(awarded, 0, sampleRollupDuration)),
                        x = planet.x,
                        y = planet.y,
                        timer = 1.0,
                        kind = "sample",
                        awarded = awarded,
                        rollupElapsed = 0,
                    })
                    local tier = world.sampleTier(planet)
                    self:spawnSampleParticles(planet.x, planet.y, tier)
                    self.timeSlip = { timer = 0.4, scale = 0.24 }
                    self.shipShake = 0.25
                    if tier == "epic" then
                        self.shipShakeMagnitude = 1.4
                    elseif tier == "rare" then
                        self.shipShakeMagnitude = 1.0
                    else
                        self.shipShakeMagnitude = 0.6
                    end
                    self.collectFlash = 0.15
                    self.collectZoom = { timer = 0.5, scale = 1.12, planetX = planet.x, planetY = planet.y }
                    if streakMultiplier and streakMultiplier > 1 then
                        self.message = ""
                    else
                        self.message = ""
                    end
                    local specimenId, specimenLabel = world.specimenKind(planet)
                    if self.collectionStore:record(specimenId) then
                        self.collectedSpecimens[specimenId] = true
                        self.newSpecimenBanner = i18n.t("new_specimen_label", specimenLabel)
                        self.newSpecimenBannerTimer = 2.0
                    end
                end
            end
            if distanceSquared <= (planet.radius + 5) ^ 2 and not self.collided[planet.id] and not planet.hub and not planet.isShop then
                self.collided[planet.id] = true
                local damage = world.collisionDamage(planet)
                sfx.play("collision")
                -- rendering stacked directly on top of the green "+$N"
                -- sample text when both fire on the same update (ship and
                -- planet positions coincide closely enough to cross both
                -- thresholds at once). Offset the damage text horizontally
                -- from the ship position so the two 60px-wide centered text
                -- boxes never overlap regardless of how close ship/planet
                -- are.
                table.insert(self.floatingTexts, {
                    text = i18n.t("floating_damage_text", damage),
                    x = self.ship.x + 60,
                    y = self.ship.y,
                    timer = 1.0,
                    kind = "damage",
                })
                self.shipShake = shipShakeDuration
                self.shipShakeMagnitude = sampleTierShakeMultiplier(world.sampleTier(planet))
                if expedition.damage(self.expedition, damage) then
                    self:persistBestAltitude()
                    self.message = i18n.t("ship_destroyed_message", math.floor(self.expedition.bestAltitude))
                    break
                end
                self.message = ""
            end
        end
        -- INBOX (37): moon collection/collision
        if self.expedition.phase == "ascending" then
            for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 4)) do
                local moon = world.moonForPlanet(planet, self.time)
                if moon then
                    local dx, dy = moon.x - self.ship.x, moon.y - self.ship.y
                    local distanceSquared = dx * dx + dy * dy
                    -- Collection radius: uses base (pre-shrink) radius + 15
                    local moonCollectRadius = (moon.collectRadius or moon.radius) + 15
                    if distanceSquared <= moonCollectRadius ^ 2
                        and not self.moonDiscovered[moon.id] then
                        self.moonDiscovered[moon.id] = true
                        local value = world.moonSampleValue(moon)
                        local _, awarded = expedition.collectSample(self.expedition, value, world.hueFamily(moon.hue or 0).key)
                        awarded = awarded or value
                        sfx.play("collect")
                        table.insert(self.floatingTexts, {
                            text = i18n.t("floating_sample_gain", rollupAmount(awarded, 0, sampleRollupDuration)),
                            x = moon.x,
                            y = moon.y,
                            timer = 1.5,
                            kind = "sample",
                            awarded = awarded,
                            rollupElapsed = 0,
                        })
                        self.timeSlip = { timer = 0.4, scale = 0.24 }
                        self.shipShake = 0.25
                        self.shipShakeMagnitude = 1.2
                        self.collectFlash = 0.15
                        self.collectZoom = { timer = 0.5, scale = 1.12, planetX = moon.x, planetY = moon.y }
                        self.message = ""
                    end
                    if distanceSquared <= ((moon.collectRadius or moon.radius) + 5) ^ 2
                        and not self.moonCollided[moon.id] then
                        self.moonCollided[moon.id] = true
                        local damage = world.moonCollisionDamage(moon)
                        table.insert(self.floatingTexts, {
                            text = i18n.t("floating_damage_text", damage),
                            x = self.ship.x + 60,
                            y = self.ship.y,
                            timer = 1.0,
                            kind = "damage",
                        })
                        self.shipShake = shipShakeDuration
                        self.shipShakeMagnitude = 1.2
                        if expedition.damage(self.expedition, damage) then
                            self:persistBestAltitude()
                            self.message = i18n.t("ship_destroyed_message", math.floor(self.expedition.bestAltitude))
                            break
                        end
                        self.message = ""
                    end
                end
            end
        end
        -- INBOX (35): comet spawning + collection/collision
        if self.expedition.phase == "ascending" then
            world.tickCometSpawn(self.time, self.ship.x, self.ship.y, viewport.width, viewport.height)
            for _, comet in ipairs(world.nearbyComets(self.ship.x, self.ship.y, self.time, viewport.width, viewport.height)) do
                local dx, dy = comet.x - self.ship.x, comet.y - self.ship.y
                local distanceSquared = dx * dx + dy * dy
                -- Collection: same radius formula as planets (radius + 30)
                if distanceSquared <= (self.collectOrbitRadius(comet.radius, self.expedition)) ^ 2
                    and not self.cometDiscovered[comet.id] then
                    self.cometDiscovered[comet.id] = true
                    local value = world.cometSampleValue(comet)
                    local _, awarded = expedition.collectSample(self.expedition, value, "ember")
                    awarded = awarded or value
                    sfx.play("collect")
                    table.insert(self.floatingTexts, {
                        text = i18n.t("floating_sample_gain", rollupAmount(awarded, 0, sampleRollupDuration)),
                        x = comet.x,
                        y = comet.y,
                        timer = 1.5,
                        kind = "sample",
                        awarded = awarded,
                        rollupElapsed = 0,
                    })
                    self.timeSlip = { timer = 0.4, scale = 0.24 }
                    self.shipShake = 0.25
                    self.shipShakeMagnitude = 1.4
                    self.collectFlash = 0.15
                    self.collectZoom = { timer = 0.5, scale = 1.12, planetX = comet.x, planetY = comet.y }
                    self.message = ""
                end
                -- Collision damage: same radius as planets (radius + 5)
                if distanceSquared <= (comet.radius + 5) ^ 2
                    and not self.cometCollided[comet.id] then
                    self.cometCollided[comet.id] = true
                    local damage = world.cometCollisionDamage(comet)
                    table.insert(self.floatingTexts, {
                        text = i18n.t("floating_damage_text", damage),
                        x = self.ship.x + 60,
                        y = self.ship.y,
                        timer = 1.0,
                        kind = "damage",
                    })
                    self.shipShake = shipShakeDuration
                    self.shipShakeMagnitude = 1.4
                    if expedition.damage(self.expedition, damage) then
                        self:persistBestAltitude()
                        self.message = i18n.t("ship_destroyed_message", math.floor(self.expedition.bestAltitude))
                        break
                    end
                    self.message = ""
                end
            end
        end
        for _, junk in ipairs(world.nearbyDebris(self.ship.x, self.ship.y, 4, self.time)) do
            local dx, dy = junk.x - self.ship.x, junk.y - self.ship.y
            if dx * dx + dy * dy <= (junk.radius + 5) ^ 2 and not self.collided[junk.id] then
                self.collided[junk.id] = true
                sfx.play("collision", nil, 0.9)
                local damage = 1
                table.insert(self.floatingTexts, {
                    text = i18n.t("floating_damage_text", damage),
                    x = self.ship.x + 60,
                    y = self.ship.y,
                    timer = 1.0,
                    kind = "damage",
                })
                self.shipShake = shipShakeDuration
                self.shipShakeMagnitude = 1.4
                if expedition.damage(self.expedition, damage) then
                    self:persistBestAltitude()
                    self.message = i18n.t("ship_destroyed_message", math.floor(self.expedition.bestAltitude))
                    break
                end
            end
        end
    end
    if self.expedition.phase ~= "ascending" then
        self.touches = {}
    end
end

end
return M
