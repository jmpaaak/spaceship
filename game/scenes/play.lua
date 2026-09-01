local shipModule = require("game.ship")
local expedition = require("game.expedition")
local bestAltitudeStore = require("game.best_altitude_store")
local viewport = require("game.viewport")
local world = require("game.world")
local M = {}
M.__index = M

-- Returning-phase LEFT/RIGHT/SPIN touch band. Was a 24px-tall row
-- (254-278), which only clears ~24pt at the smallest supported window
-- (integer scale 1, 1x device pixel ratio) -- well under the iOS/Android
-- ~44pt accessibility minimum PlayScene.settlementTouchRows was already
-- fixed to meet (see game/self_test.lua's canvasPixelsToPoints check).
-- Widened to a 44 canvas px band (244-288). The slot-reel result box above
-- was shrunk from 36px to 34px tall (210-244) so it stops exactly where
-- this band starts, and the message text below still starts at
-- viewport.height - 30 == 290, 2px clear of this band's bottom (288).
local returnControls = {
    top = 244,
    bottom = 288,
    leftMaxX = 55,
    slotMinX = 60,
    slotMaxX = 120,
    rightMinX = 125,
}
M.returnControls = returnControls

-- Settlement (EARTH SHOP) touch rows, top-to-bottom. Each row's height is a
-- Actual finger touch target on the device, not just a text layout band.
-- Evenly split across the 140-320 canvas range (180px / 4 = 45px each) so
-- every row clears the 44pt accessibility minimum (see
-- game/self_test.lua's canvasPixelsToPoints check) at the smallest
-- supported window (integer scale 1, 1x device pixel ratio), superseding
-- the previous 150-320/42px rows that only cleared the lower 34px bar.
-- The settlement panel's summary-card font/spacing was shrunk to free the
-- extra 10px of vertical room this needed. See game/self_test.lua for the
-- device-scale check.
-- Added the SAMPLE YIELD upgrade as a fifth touch target alongside
-- fuel/hull/ship/relaunch. A straight 5-way vertical split of the same
-- 140-320 canvas range would only give 36px/row -- under the 44pt
-- accessibility minimum this table was previously fixed to meet (see
-- game/self_test.lua's canvasPixelsToPoints check). Instead YIELD and SHIP
-- share one 44px-tall row, split left/right at x=90 (each half is 90
-- canvas px wide, far past the 44pt accessibility minimum on the width
-- axis too), keeping all four rows at the full 44 canvas px band height.
-- STEERING is the fourth GAME_DESIGN.md meta upgrade axis (see
-- game/self_test.lua's steeringRun scenario); it reuses the same
-- column-split pattern by sharing the HULL row (left=HULL, right=STEERING)
-- instead of adding a fifth 36px-tall row that would fall back under the
-- 44pt accessibility minimum.
local settlementTouchRows = {
    { key = "fuel", top = 144, bottom = 188 },
    {
        top = 188, bottom = 232,
        columns = {
            { key = "hull", left = 0, right = 90 },
            { key = "steering", left = 90, right = 180 },
        },
    },
    {
        top = 232, bottom = 276,
        columns = {
            { key = "yield", left = 0, right = 90 },
            { key = "ship", left = 90, right = 180 },
        },
    },
    { key = "relaunch", top = 276, bottom = 320 },
}
M.settlementTouchRows = settlementTouchRows

-- SHIP DESTROYED restart touch target. Unlike EARTH SHOP's four stacked
-- rows, this phase has a single action (restart), so touchpressed accepts
-- any tap on the full 180x320 internal canvas rather than a narrow band.
-- Documented and engine-tested explicitly so this stays true if the
-- destroyed phase ever grows per-row touch targets like settlement did.
local destroyedTouchArea = { top = 0, bottom = 320, left = 0, right = 180 }
M.destroyedTouchArea = destroyedTouchArea

-- Ascending-phase HOLD LEFT/HOLD RIGHT steering buttons. touchpressed for
-- this phase already accepts a tap anywhere on the internal canvas (no y
-- restriction; see the "ascending" branch below), so the *functional*
-- touch target already spans the full 180x320 canvas -- far beyond the
-- 44pt accessibility minimum. This constant only documents/tests the
-- *visual* button box drawn on screen, which was a 24px-tall row
-- (254-278, only ~24pt at the smallest supported window, integer scale 1,
-- 1x device pixel ratio) -- under the same 44pt bar returnControls and
-- settlementTouchRows were widened to meet. Widened to match
-- returnControls exactly (244-288, 44 canvas px) for visual consistency,
-- even though it does not gate touch acceptance.
local ascendControls = { top = 244, bottom = 288, leftMaxX = 81, rightMinX = 99 }
M.ascendControls = ascendControls

-- LAUNCH phase's TAP TO LAUNCH touch target. touchpressed for this phase
-- already accepts any tap on the internal canvas regardless of x/y (see the
-- "launch" branch below), so the functional touch target has always spanned
-- the full 180x320 canvas -- far beyond the 44pt accessibility minimum.
-- Named and exposed to close out the last remaining touch surface that was
-- accepted unconditionally but never given an explicit constant or
-- corner-touch regression test, matching destroyedTouchArea's pattern.
local launchTouchArea = { top = 0, bottom = 320, left = 0, right = 180 }
M.launchTouchArea = launchTouchArea

local function planetColor(hue)
    if hue < 0.33 then return 0.35, 0.75, 1 end
    if hue < 0.66 then return 0.95, 0.55, 0.3 end
    return 0.65, 0.45, 0.95
end

local sampleTierColors = {
    common = { 0.75, 0.8, 0.85 },
    rare = { 0.35, 0.75, 1 },
    epic = { 0.95, 0.7, 0.15 },
}

local function sampleTierColor(tier)
    local color = sampleTierColors[tier] or sampleTierColors.common
    return color[1], color[2], color[3]
end
M.sampleTierColor = sampleTierColor

local warningLabelMargin = 2

local function clampLabelX(centerX, textWidth, viewportWidth, margin)
    margin = margin or warningLabelMargin
    local x = centerX - textWidth / 2
    local maxX = viewportWidth - margin - textWidth
    if x > maxX then x = maxX end
    if x < margin then x = margin end
    return x
end
M.clampLabelX = clampLabelX

local slotReelStagger = 0.15
local slotSpinDuration = slotReelStagger * 3

-- EARTH SHOP action/status two-column layout for the fuel/hull/steering/
-- yield/ship rows. Measured with a real LÖVE font probe
-- (GAME_FONTPROBE=1 love .) against the small scene-cached font
-- (love.graphics.newFont(8)): the widest action string
-- ("T/G STEER LV.9>10 $65") is 100px and the widest status string
-- ("SHORT $125") is 52px. The previous actionW=102/statusX=120/statusW=48
-- columns left the status column only 48px -- 4px under its own worst
-- case -- so a wide "SHORT $N" status could wrap to a second line inside
-- its own printf box and overlap the row drawn immediately below (only
-- 9px of row spacing). The panel background spans x=12..168
-- (viewport.width - 24 wide from x=12), so the two columns are sized to
-- exactly cover their measured worst case within that inner width with
-- no wasted margin: action 16..116 (100px), status 116..168 (52px).
local shopActionColumnX, shopActionColumnW = 16, 100
local shopStatusColumnX, shopStatusColumnW = 116, 52
M.shopActionColumnX = shopActionColumnX
M.shopActionColumnW = shopActionColumnW
M.shopStatusColumnX = shopStatusColumnX
M.shopStatusColumnW = shopStatusColumnW

function M.new(options)
    options = options or {}
    local ship = shipModule.new()
    local altitudeStore = options.bestAltitudeStore or bestAltitudeStore.new()
    return setmetatable({
        ship = ship,
        expedition = expedition.new({ bestAltitude = altitudeStore:load() }),
        bestAltitudeStore = altitudeStore,
        discovered = {},
        collided = {},
        discoveredCount = 0,
        floatingTexts = {},
        slotSpin = nil,
        touches = {},
        message = "TAP TO LAUNCH",
    }, M)
end

function M:persistBestAltitude()
    return self.bestAltitudeStore:save(self.expedition.bestAltitude)
end

function M:collisionRisk(planet)
    local phase = self.expedition.phase
    if phase ~= "ascending" and phase ~= "returning" then return nil end
    local damage = world.collisionDamage(planet)
    local lethal = damage >= self.expedition.durability
    local risk = {
        damage = damage,
        lethal = lethal,
        label = string.format(lethal and "LETHAL -%d" or "RISK -%d", damage),
    }
    if phase == "ascending" then
        local baseValue = world.sampleValue(planet)
        risk.sampleValue = math.floor(baseValue * expedition.sampleYieldMultiplier(self.expedition) + 0.5)
        risk.sampleLabel = string.format("SAMPLE $%d", risk.sampleValue)
    end
    return risk
end

function M:approachWarning(planet, planetScreenY, shipScreenY)
    if planet.id and self.collided[planet.id] then return nil end
    local phase = self.expedition.phase
    local approaching = phase == "ascending" and planetScreenY >= 40 and planetScreenY < shipScreenY
        or phase == "returning" and planetScreenY > shipScreenY and planetScreenY < viewport.height
    if not approaching then return nil end
    return self:collisionRisk(planet)
end

function M:hudLines()
    local run = self.expedition
    local samples
    local best
    local earth
    local returnProgress
    if run.phase == "ascending" or run.phase == "returning" then
        samples = string.format("SAMPLES %02d  AT RISK $%d", run.sampleCount, run.pendingSampleValue)
        if run.phase == "returning" then
            earth = string.format("EARTH IN %d", math.ceil(run.altitude))
            local progress = 1
            if run.returnDistance > 0 then
                progress = math.max(0, math.min(1, 1 - run.altitude / run.returnDistance))
            end
            local secondsLeft = run.returnSpeed > 0 and math.ceil(run.altitude / run.returnSpeed) or 0
            returnProgress = string.format("RETURN %d%%  %ds LEFT",
                math.floor(progress * 100 + 0.5), secondsLeft)
        end
    elseif run.phase == "launch" or run.phase == "settlement" then
        best = string.format("PERSONAL BEST %04d", math.floor(run.bestAltitude))
    end
    return {
        primary = string.format("ALT %04d  CASH $%d", math.floor(run.altitude), run.money),
        samples = samples,
        best = best,
        earth = earth,
        returnProgress = returnProgress,
        status = string.format("F%03d H%d/%d %-6s S%02d", math.floor(run.fuel), run.durability,
            run.maxDurability, string.upper(run.phase):sub(1, 6), run.slotOpportunities),
    }
end

local function launchForecastLine(run, maxFuel)
    local forecastAltitude, forecastSlots = expedition.launchForecast(run, maxFuel)
    return string.format("NO-HIT %d  SLOTS %d", math.floor(forecastAltitude), forecastSlots)
end

function M:loadoutLines()
    local run = self.expedition
    return {
        ship = string.format("SHIP %s", string.upper(run.selectedShipId)),
        stats = string.format("MAX FUEL %d  HULL %d", run.maxFuel, run.maxDurability),
        upgrades = string.format("FUEL LV.%d  HULL LV.%d",
            run.fuelUpgradeLevel, run.durabilityUpgradeLevel),
        forecast = launchForecastLine(run),
        steering = string.format("STEER SPEED %d", expedition.steeringSpeed(run)),
        odds = self:slotOddsLine(),
    }
end

function M:summaryFuelBonusLine()
    local bonus = self.expedition.bankedFuelBonus or 0
    if bonus <= 0 then return nil end
    return string.format("NEXT LAUNCH FUEL +%d", bonus)
end

local function purchaseStatus(money, cost)
    if money >= cost then return string.format("LEFT $%d", money - cost), true end
    return string.format("SHORT $%d", cost - money), false
end

local function purchaseShortfallMessage(money, cost, item)
    return string.format("NEED $%d MORE FOR %s", cost - money, item)
end

function M:shopLoadoutLines()
    local run = self.expedition
    local shipAction
    local shipAffordable
    local shipStatus
    local previewShipId
    if not run.ownedShips.scout then
        shipAction = string.format("BUY SCOUT $%d", run.scoutShipCost)
        shipStatus, shipAffordable = purchaseStatus(run.money, run.scoutShipCost)
        previewShipId = "scout"
    elseif run.selectedShipId == "scout" then
        shipAction = "SELECT STARTER"
        shipAffordable = true
        shipStatus = "OWNED"
        previewShipId = "starter"
    else
        shipAction = "SELECT SCOUT"
        shipAffordable = true
        shipStatus = "OWNED"
        previewShipId = "scout"
    end
    local previewFuel = run.baseFuel + run.fuelUpgradeLevel * run.fuelUpgradeAmount
    local previewDurability = run.baseDurability
        + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
    if previewShipId == "scout" then
        previewFuel = previewFuel + run.scoutFuelBonus
        previewDurability = previewDurability + run.scoutDurabilityBonus
    end
    local fuelStatus, fuelAffordable = purchaseStatus(run.money, run.fuelUpgradeCost)
    local hullStatus, hullAffordable = purchaseStatus(run.money, run.durabilityUpgradeCost)
    local yieldStatus, yieldAffordable = purchaseStatus(run.money, run.sampleYieldUpgradeCost)
    local steeringStatus, steeringAffordable = purchaseStatus(run.money, run.steeringUpgradeCost)
    return {
        ship = string.format("NEXT %s", string.upper(run.selectedShipId)),
        stats = string.format("MAX FUEL %d  HULL %d", run.maxFuel, run.maxDurability),
        upgrades = string.format("FUEL LV.%d  HULL LV.%d",
            run.fuelUpgradeLevel, run.durabilityUpgradeLevel),
        forecast = launchForecastLine(run),
        scoutTradeoff = string.format("SCOUT %+d FUEL / %+d HULL",
            run.scoutFuelBonus, run.scoutDurabilityBonus),
        shipAction = shipAction,
        shipStatus = shipStatus,
        shipAffordable = shipAffordable,
        shipPreview = string.format("%s MAX FUEL %d  HULL %d",
            string.upper(previewShipId), previewFuel, previewDurability),
        shipPreviewForecast = launchForecastLine(run, previewFuel),
        fuelAction = string.format("T/F FUEL LV.%d>%d $%d",
            run.fuelUpgradeLevel, run.fuelUpgradeLevel + 1, run.fuelUpgradeCost),
        fuelPreviewForecast = launchForecastLine(run, run.maxFuel + run.fuelUpgradeAmount),
        fuelStatus = fuelStatus,
        fuelAffordable = fuelAffordable,
        hullAction = string.format("T/H HULL LV.%d>%d $%d",
            run.durabilityUpgradeLevel, run.durabilityUpgradeLevel + 1,
            run.durabilityUpgradeCost),
        hullPreview = string.format("MAX FUEL %d  HULL %d",
            run.maxFuel, run.maxDurability + run.durabilityUpgradeAmount),
        hullPreviewForecast = launchForecastLine(run),
        hullStatus = hullStatus,
        hullAffordable = hullAffordable,
        yieldAction = string.format("T/Y YIELD LV.%d>%d $%d",
            run.sampleYieldUpgradeLevel, run.sampleYieldUpgradeLevel + 1, run.sampleYieldUpgradeCost),
        yieldPreview = string.format("YIELD x%.2f",
            1 + (run.sampleYieldUpgradeLevel + 1) * run.sampleYieldUpgradeAmount),
        yieldStatus = yieldStatus,
        yieldAffordable = yieldAffordable,
        steeringAction = string.format("T/G STEER LV.%d>%d $%d",
            run.steeringUpgradeLevel, run.steeringUpgradeLevel + 1, run.steeringUpgradeCost),
        steeringPreview = string.format("STEER SPEED %d",
            run.baseSteeringSpeed + (run.steeringUpgradeLevel + 1) * run.steeringUpgradeAmount),
        steeringStatus = steeringStatus,
        steeringAffordable = steeringAffordable,
        odds = self:slotOddsLine(),
    }
end

function M:slotOddsLine()
    local ev = expedition.slotExpectedValue()
    return string.format("C%d P%d S%d  AVG $%.2f",
        math.floor(expedition.slotSymbolProbability("COMET") * 100 + 0.5),
        math.floor(expedition.slotSymbolProbability("PLANET") * 100 + 0.5),
        math.floor(expedition.slotSymbolProbability("STAR") * 100 + 0.5),
        ev)
end

function M:slotButtonState()
    local chances = self.expedition.slotOpportunities
    if self.slotSpin then
        return { enabled = false, label = "SLOT SPINNING...", compactLabel = "SPINNING" }
    end
    if self.expedition.phase ~= "returning" or chances <= 0 then
        return { enabled = false, label = "NO SLOT CHANCES", compactLabel = "NO SLOTS" }
    end
    return {
        enabled = true,
        label = string.format("TAP: SLOT SPIN  %d LEFT", chances),
        compactLabel = string.format("SPIN %d", chances),
    }
end

function M:beginSlotSpin()
    self.slotSpin = {
        elapsed = 0,
        reelStagger = slotReelStagger,
        duration = slotSpinDuration,
        symbols = self.expedition.lastSlotSymbols,
        reward = self.expedition.lastSlotReward,
        repair = self.expedition.lastSlotRepair,
        fuelBonus = self.expedition.lastSlotFuelBonus,
        sampleBonus = self.expedition.lastSlotSampleBonus,
        opportunitiesAfter = self.expedition.slotOpportunities,
    }
    self.message = "SLOT SPINNING..."
end

function M:currentSlotReels()
    if not self.slotSpin then
        return self.expedition.lastSlotSymbols
    end
    local reels = {}
    for i = 1, 3 do
        local stopTime = i * self.slotSpin.reelStagger
        if self.slotSpin.elapsed >= stopTime then
            reels[i] = self.slotSpin.symbols[i]
        else
            local cycle = math.floor(self.slotSpin.elapsed * 12) + i
            reels[i] = expedition.slotSymbols[(cycle % #expedition.slotSymbols) + 1]
        end
    end
    return reels
end

function M:steeringButtonState()
    local left = love.keyboard.isDown("left", "a")
    local right = love.keyboard.isDown("right", "d")
    for _, touch in pairs(self.touches) do
        if touch.x < viewport.width / 2 then
            left = true
        else
            right = true
        end
    end
    return { leftActive = left, rightActive = right }
end

function M:update(dt)
    local steering = self:steeringButtonState()
    local previousPhase = self.expedition.phase
    for i = #self.floatingTexts, 1, -1 do
        local ft = self.floatingTexts[i]
        ft.timer = ft.timer - dt
        ft.y = ft.y - 20 * dt
        if ft.timer <= 0 then
            table.remove(self.floatingTexts, i)
        end
    end
    if self.slotSpin then
        self.slotSpin.elapsed = self.slotSpin.elapsed + dt
        if self.slotSpin.elapsed >= self.slotSpin.duration then
            if self.slotSpin.repair and self.slotSpin.repair > 0 then
                self.message = string.format("%s +$%d REPAIR +%d  %d LEFT",
                    table.concat(self.slotSpin.symbols, " "),
                    self.slotSpin.reward,
                    self.slotSpin.repair,
                    self.slotSpin.opportunitiesAfter)
            elseif self.slotSpin.fuelBonus and self.slotSpin.fuelBonus > 0 then
                self.message = string.format("%s +$%d FUEL +%d  %d LEFT",
                    table.concat(self.slotSpin.symbols, " "),
                    self.slotSpin.reward,
                    self.slotSpin.fuelBonus,
                    self.slotSpin.opportunitiesAfter)
            elseif self.slotSpin.sampleBonus and self.slotSpin.sampleBonus > 0 then
                self.message = string.format("%s +$%d SAMPLE +$%d  %d LEFT",
                    table.concat(self.slotSpin.symbols, " "),
                    self.slotSpin.reward,
                    self.slotSpin.sampleBonus,
                    self.slotSpin.opportunitiesAfter)
            else
                self.message = string.format("%s +$%d  %d LEFT",
                    table.concat(self.slotSpin.symbols, " "),
                    self.slotSpin.reward,
                    self.slotSpin.opportunitiesAfter)
            end
            self.slotSpin = nil
        end
    end
    if self.expedition.phase == "ascending" or self.expedition.phase == "returning" then
        self.ship.x = self.ship.x
            + ((steering.rightActive and 1 or 0) - (steering.leftActive and 1 or 0))
            * expedition.steeringSpeed(self.expedition) * dt
    end
    if self.expedition.phase == "ascending" or self.expedition.phase == "returning" then
        expedition.update(self.expedition, dt)
        self.ship.y = -self.expedition.altitude
        self.ship.fuel = self.expedition.fuel
    end
    if previousPhase ~= self.expedition.phase and self.expedition.phase == "returning" then
        self:persistBestAltitude()
        self.message = string.format("RETURNING  %d SLOT CHANCES", self.expedition.slotOpportunities)
    elseif previousPhase ~= self.expedition.phase and self.expedition.phase == "settlement" then
        self.message = string.format("SETTLED +$%d  BALANCE $%d", self.expedition.lastSettlement, self.expedition.money)
    end
    if self.expedition.phase == "ascending" or self.expedition.phase == "returning" then
        for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 1)) do
            local dx, dy = planet.x - self.ship.x, planet.y - self.ship.y
            local distanceSquared = dx * dx + dy * dy
            if self.expedition.phase == "ascending"
                and distanceSquared <= (planet.radius + 14) ^ 2
                and not self.discovered[planet.id] then
                self.discovered[planet.id] = true
                self.discoveredCount = self.discoveredCount + 1
                local value = world.sampleValue(planet)
                local _, awarded = expedition.collectSample(self.expedition, value)
                awarded = awarded or value
                table.insert(self.floatingTexts, {
                    text = string.format("+$%d", awarded),
                    x = planet.x,
                    y = planet.y,
                    timer = 1.0,
                    kind = "sample",
                })
                self.message = string.format("SAMPLE +$%d  %s", awarded, planet.id)
            end
            if distanceSquared <= (planet.radius + 5) ^ 2 and not self.collided[planet.id] then
                self.collided[planet.id] = true
                local damage = world.collisionDamage(planet)
                -- Real LOVE runtime capture showed this "-N" damage text
                -- rendering stacked directly on top of the green "+$N"
                -- sample text when both fire on the same update (ship and
                -- planet positions coincide closely enough to cross both
                -- thresholds at once). Offset the damage text horizontally
                -- from the ship position so the two 60px-wide centered text
                -- boxes never overlap regardless of how close ship/planet
                -- are.
                table.insert(self.floatingTexts, {
                    text = string.format("-%d", damage),
                    x = self.ship.x + 60,
                    y = self.ship.y,
                    timer = 1.0,
                    kind = "damage",
                })
                if expedition.damage(self.expedition, damage) then
                    self:persistBestAltitude()
                    self.message = string.format("SHIP DESTROYED  BEST %d  META RESET", math.floor(self.expedition.bestAltitude))
                    break
                end
                self.message = string.format("COLLISION -%d  HULL %d/%d", damage, self.expedition.durability, self.expedition.maxDurability)
            end
        end
    end
    if self.expedition.phase ~= "ascending" and self.expedition.phase ~= "returning" then
        self.touches = {}
    end
end

function M:keypressed(key)
    if self.expedition.phase == "settlement" and (key == "f" or key == "down" or key == "s") then
        if expedition.buyFuelUpgrade(self.expedition) then
            self.message = string.format("FUEL TANK UPGRADED  LV.%d  MAX %d  %s  BALANCE $%d",
                self.expedition.fuelUpgradeLevel, self.expedition.maxFuel,
                launchForecastLine(self.expedition), self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                self.expedition.fuelUpgradeCost, "FUEL UPGRADE")
        end
        return
    end
    if self.expedition.phase == "settlement" and (key == "h" or key == "right" or key == "d") then
        if expedition.buyDurabilityUpgrade(self.expedition) then
            self.message = string.format(
                "HULL UPGRADED  LV.%d  MAX FUEL %d  HULL %d  %s  BALANCE $%d",
                self.expedition.durabilityUpgradeLevel, self.expedition.maxFuel,
                self.expedition.maxDurability,
                launchForecastLine(self.expedition), self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                self.expedition.durabilityUpgradeCost, "HULL UPGRADE")
        end
        return
    end
    if self.expedition.phase == "settlement" and key == "y" then
        if expedition.buySampleYieldUpgrade(self.expedition) then
            self.message = string.format(
                "SAMPLE YIELD UPGRADED  LV.%d  x%.2f  BALANCE $%d",
                self.expedition.sampleYieldUpgradeLevel,
                expedition.sampleYieldMultiplier(self.expedition),
                self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                self.expedition.sampleYieldUpgradeCost, "SAMPLE YIELD UPGRADE")
        end
        return
    end
    if self.expedition.phase == "settlement" and key == "g" then
        if expedition.buySteeringUpgrade(self.expedition) then
            self.message = string.format(
                "STEERING UPGRADED  LV.%d  SPEED %d  BALANCE $%d",
                self.expedition.steeringUpgradeLevel,
                expedition.steeringSpeed(self.expedition),
                self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                self.expedition.steeringUpgradeCost, "STEERING UPGRADE")
        end
        return
    end
    if self.expedition.phase == "settlement" and key == "v" then
        if not self.expedition.ownedShips.scout then
            if expedition.buyShip(self.expedition, "scout") then
                expedition.selectShip(self.expedition, "scout")
                self.message = string.format(
                    "SCOUT PURCHASED AND SELECTED  MAX FUEL %d  HULL %d  %s  BALANCE $%d",
                    self.expedition.maxFuel, self.expedition.maxDurability,
                    launchForecastLine(self.expedition), self.expedition.money)
            else
                self.message = purchaseShortfallMessage(self.expedition.money,
                    self.expedition.scoutShipCost, "SCOUT")
            end
        else
            local shipId = self.expedition.selectedShipId == "scout" and "starter" or "scout"
            expedition.selectShip(self.expedition, shipId)
            self.message = string.format("%s SELECTED  MAX FUEL %d  HULL %d  %s",
                string.upper(shipId), self.expedition.maxFuel, self.expedition.maxDurability,
                launchForecastLine(self.expedition))
        end
        return
    end
    if key == "space" or key == "return" or key == "up" or key == "w" then
        if self.expedition.phase == "returning" and not self.slotSpin and expedition.useSlot(self.expedition) then
            self:beginSlotSpin()
        else
            local relaunching = self.expedition.phase == "settlement" or self.expedition.phase == "destroyed"
            if expedition.launch(self.expedition) then
                if relaunching then
                    self.ship.x = 0
                    self.ship.y = 0
                    self.ship.fuel = self.expedition.fuel
                    self.discovered = {}
                    self.collided = {}
                    self.discoveredCount = 0
                    self.floatingTexts = {}
                end
                self.message = "ASCENDING  STEER LEFT / RIGHT"
            end
        end
    end
end

function M:touchpressed(id, x, y)
    if self.expedition.phase == "ascending" then
        self.touches[id] = { x = x, y = y }
        return
    end
    if self.expedition.phase == "returning" then
        local inControlRow = y >= returnControls.top and y <= returnControls.bottom
        if inControlRow and x >= returnControls.slotMinX and x <= returnControls.slotMaxX then
            self:keypressed("space")
        elseif inControlRow and (x <= returnControls.leftMaxX or x >= returnControls.rightMinX) then
            self.touches[id] = { x = x, y = y }
        end
        return
    end
    if self.expedition.phase == "settlement" then
        for _, row in ipairs(settlementTouchRows) do
            if y >= row.top and y < row.bottom then
                local key = row.key
                if row.columns then
                    for _, column in ipairs(row.columns) do
                        if x >= column.left and x < column.right then
                            key = column.key
                            break
                        end
                    end
                end
                if key == "fuel" then
                    self:keypressed("f")
                elseif key == "hull" then
                    self:keypressed("h")
                elseif key == "steering" then
                    self:keypressed("g")
                elseif key == "yield" then
                    self:keypressed("y")
                elseif key == "ship" then
                    self:keypressed("v")
                elseif key == "relaunch" then
                    self:keypressed("space")
                end
                break
            end
        end
        return
    end
    if self.expedition.phase == "launch" then
        self:keypressed("space")
        return
    end
    if self.expedition.phase == "destroyed" then
        local area = destroyedTouchArea
        if x >= area.left and x < area.right and y >= area.top and y < area.bottom then
            self:keypressed("space")
        end
    end
end

function M:touchmoved(id, x, y)
    if self.touches[id] then
        self.touches[id].x = x
        self.touches[id].y = y
    end
end

function M:touchreleased(id)
    self.touches[id] = nil
end

function M:draw()
    love.graphics.clear(0.015, 0.02, 0.055)
    local shipScreenX, shipScreenY = viewport.width / 2, math.floor(viewport.height * 0.58)
    local cameraX, cameraY = self.ship.x - shipScreenX, self.ship.y - shipScreenY
    local sx, sy = world.sectorAt(self.ship.x, self.ship.y)
    for oy = -1, 1 do
        for ox = -1, 1 do
            for _, star in ipairs(world.stars(sx + ox, sy + oy)) do
                local x, y = math.floor(star.x - cameraX), math.floor(star.y - cameraY)
                if x >= 0 and x < viewport.width and y >= 0 and y < viewport.height then
                    local c = 0.35 + star.bright * 0.65
                    love.graphics.setColor(c, c, math.min(1, c + 0.1))
                    love.graphics.points(x, y)
                end
            end
        end
    end
    local earthX, earthY = math.floor(-cameraX), math.floor(75 - cameraY)
    if earthY < viewport.height + 64 then
        love.graphics.setColor(0.15, 0.45, 0.9)
        love.graphics.circle("fill", earthX, earthY, 58)
        love.graphics.setColor(0.25, 0.8, 0.45)
        love.graphics.circle("fill", earthX - 18, earthY - 18, 15)
        love.graphics.circle("fill", earthX + 21, earthY - 5, 12)
    end
    for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 1)) do
        local x, y = math.floor(planet.x - cameraX), math.floor(planet.y - cameraY)
        if x > -24 and x < viewport.width + 24 and y > -24 and y < viewport.height + 24 then
            love.graphics.setColor(planetColor(planet.hue))
            love.graphics.circle("fill", x, y, planet.radius)
            if not self.discovered[planet.id] then
                love.graphics.setColor(sampleTierColor(world.sampleTier(planet)))
                love.graphics.circle("line", x, y, planet.radius + 3)
            end
            love.graphics.setColor(0.9, 0.95, 1, 0.45)
            love.graphics.circle("line", x, y, planet.radius + 2)
            local risk = self:approachWarning(planet, y, shipScreenY)
            if risk then
                local font = love.graphics.getFont()
                local previewY
                if risk.sampleLabel then
                    previewY = math.max(48, y - planet.radius - 24)
                    love.graphics.setColor(0.45, 0.95, 1)
                    love.graphics.print(risk.sampleLabel,
                        clampLabelX(x, font:getWidth(risk.sampleLabel), viewport.width), previewY)
                    previewY = previewY + 11
                else
                    previewY = math.max(72, y - planet.radius - 12)
                end
                if risk.lethal then
                    love.graphics.setColor(1, 0.3, 0.25)
                else
                    love.graphics.setColor(1, 0.8, 0.25)
                end
                love.graphics.print(risk.label,
                    clampLabelX(x, font:getWidth(risk.label), viewport.width), previewY)
            end
        end
    end
    for _, ft in ipairs(self.floatingTexts) do
        local fx, fy = math.floor(ft.x - cameraX), math.floor(ft.y - cameraY)
        if fx >= -30 and fx <= viewport.width + 30 and fy >= -20 and fy <= viewport.height + 20 then
            local alpha = math.max(0, math.min(1, ft.timer))
            if ft.kind == "damage" then
                love.graphics.setColor(1, 0.35, 0.3, alpha)
            else
                love.graphics.setColor(0.45, 1, 0.6, alpha)
            end
            love.graphics.printf(ft.text, fx - 30, fy - 10, 60, "center")
        end
    end
    love.graphics.push()
    love.graphics.translate(shipScreenX, shipScreenY)
    love.graphics.rotate(self.ship.angle + math.pi / 2)
    love.graphics.setColor(0.8, 0.95, 1)
    love.graphics.polygon("fill", 0, -7, -5, 6, 0, 3, 5, 6)
    if self.expedition.phase == "ascending" then
        love.graphics.setColor(1, 0.55, 0.15)
        love.graphics.polygon("fill", -2, 5, 0, 11, 2, 5)
    end
    love.graphics.pop()

    local hud = self:hudLines()
    local hudHeight = hud.returnProgress and 70 or ((hud.samples or hud.best) and 46 or 34)
    love.graphics.setColor(0.02, 0.03, 0.08, 0.85)
    love.graphics.rectangle("fill", 0, 0, viewport.width, hudHeight)
    love.graphics.setColor(0.7, 0.9, 1)
    love.graphics.print(hud.primary, 5, 4)
    if hud.samples then
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.print(hud.samples, 5, 16)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.print(hud.status, 5, 30)
        if hud.earth then
            love.graphics.setColor(0.4, 0.85, 1)
            love.graphics.print(hud.earth, 5, 43)
            love.graphics.print(hud.returnProgress, 5, 55)
        end
    elseif hud.best then
        love.graphics.print(hud.status, 5, 18)
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.print(hud.best, 5, 30)
    else
        love.graphics.print(hud.status, 5, 18)
    end
    if self.expedition.phase == "launch" then
        local loadout = self:loadoutLines()
        love.graphics.setColor(0.02, 0.03, 0.08, 0.92)
        love.graphics.rectangle("fill", 12, 204, viewport.width - 24, 90)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf("LAUNCH LOADOUT", 16, 208, viewport.width - 32, "center")
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(loadout.ship, 16, 222, viewport.width - 32, "center")
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(loadout.stats, 16, 234, viewport.width - 32, "center")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(loadout.upgrades, 16, 246, viewport.width - 32, "center")
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousLaunchFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(loadout.forecast, 16, 258, viewport.width - 32, "center")
        love.graphics.setColor(0.6, 1, 0.85)
        love.graphics.printf(loadout.steering, 16, 268, viewport.width - 32, "center")
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(loadout.odds, 16, 278, viewport.width - 32, "center")
        love.graphics.setFont(previousLaunchFont)
    elseif self.expedition.phase == "settlement" then
        -- The summary card is drawn with the same scene-cached small font as
        -- the shop rows (instead of the default 14px font) and tightened to
        -- a 9px line step. This frees enough vertical room above the fixed
        -- 320px canvas bottom for PlayScene.settlementTouchRows to grow each
        -- row to the 44pt real-device accessibility minimum (see
        -- game/self_test.lua) at the smallest supported window (integer
        -- scale 1), not just the previous 34px minimum.
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousFont = love.graphics.getFont()
        love.graphics.setColor(0.02, 0.03, 0.08, 0.94)
        love.graphics.rectangle("fill", 12, 70, viewport.width - 24, 250)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf("EARTH SHOP", 16, 74, viewport.width - 32, "center")
        local fuelBonusLine = self:summaryFuelBonusLine()
        -- The previously-verified capture (build/spaceship-runtime-preview-
        -- settlement-newbest-*.png) fit exactly one extra summary line
        -- (NEW BEST!) at y=127 with shop rows starting unshifted at
        -- row=140 and the last shop line (TAP: RELAUNCH) landing just
        -- above the y=307 DEV PLACEHOLDER footer. A second real capture
        -- of both NEW BEST! and the new NEXT LAUNCH FUEL bonus stacked as
        -- separate lines pushed TAP: RELAUNCH into the footer (found and
        -- reverted in this slice; see docs/STATUS.md). To keep the
        -- verified-safe unshifted baseline, when both are present they
        -- share a single combined line instead of adding a second row.
        local summaryExtraLine
        if self.expedition.lastNewBest and fuelBonusLine then
            summaryExtraLine = "NEW BEST!  FUEL +" .. tostring(self.expedition.bankedFuelBonus)
        elseif self.expedition.lastNewBest then
            summaryExtraLine = "NEW BEST!"
        elseif fuelBonusLine then
            summaryExtraLine = fuelBonusLine
        end
        love.graphics.setColor(0.04, 0.08, 0.16, 0.85)
        love.graphics.rectangle("fill", 18, 88, viewport.width - 36, 46)
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(string.format("TOTAL $%d", self.expedition.lastSettlement), 22, 91, viewport.width - 44, "center")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(string.format("SAMPLES (%d) $%d", self.expedition.lastSampleCount or 0, self.expedition.lastSampleSettlement), 22, 100, viewport.width - 44, "center")
        love.graphics.printf(string.format("SPINS (%d) $%d", self.expedition.lastSlotSpinsCount or 0, self.expedition.lastSlotSettlement), 22, 109, viewport.width - 44, "center")
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(string.format("PEAK ALT %d", math.floor(self.expedition.lastAltitude or 0)), 22, 118, viewport.width - 44, "center")
        if summaryExtraLine then
            love.graphics.setColor(1, 0.95, 0.3)
            love.graphics.printf(summaryExtraLine, 22, 127, viewport.width - 44, "center")
        end
        local nextLaunch = self:shopLoadoutLines()
        local actionX, actionW = shopActionColumnX, shopActionColumnW
        local statusX, statusW = shopStatusColumnX, shopStatusColumnW
        local fullX, fullW = 16, viewport.width - 32
        local row = 140
        local rowStep = 9
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.fuelAction, actionX, row, actionW, "left")
        love.graphics.setColor(nextLaunch.fuelAffordable and 0.45 or 1,
            nextLaunch.fuelAffordable and 1 or 0.4, nextLaunch.fuelAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.fuelStatus, statusX, row, statusW, "right")
        row = row + rowStep
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(nextLaunch.fuelPreviewForecast, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.hullAction, actionX, row, actionW, "left")
        love.graphics.setColor(nextLaunch.hullAffordable and 0.45 or 1,
            nextLaunch.hullAffordable and 1 or 0.4, nextLaunch.hullAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.hullStatus, statusX, row, statusW, "right")
        row = row + rowStep
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(nextLaunch.hullPreview, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(nextLaunch.hullPreviewForecast, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.steeringAction, actionX, row, actionW, "left")
        love.graphics.setColor(nextLaunch.steeringAffordable and 0.45 or 1,
            nextLaunch.steeringAffordable and 1 or 0.4, nextLaunch.steeringAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.steeringStatus, statusX, row, statusW, "right")
        row = row + rowStep
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(nextLaunch.steeringPreview, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.yieldAction, actionX, row, actionW, "left")
        love.graphics.setColor(nextLaunch.yieldAffordable and 0.45 or 1,
            nextLaunch.yieldAffordable and 1 or 0.4, nextLaunch.yieldAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.yieldStatus, statusX, row, statusW, "right")
        row = row + rowStep
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(nextLaunch.yieldPreview, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.scoutTradeoff, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(nextLaunch.shipPreview, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(nextLaunch.shipPreviewForecast, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf("T/V " .. nextLaunch.shipAction, actionX, row, actionW, "left")
        love.graphics.setColor(nextLaunch.shipAffordable and 0.45 or 1,
            nextLaunch.shipAffordable and 1 or 0.4, nextLaunch.shipAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.shipStatus, statusX, row, statusW, "right")
        row = row + rowStep
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(nextLaunch.ship, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.stats, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf(nextLaunch.upgrades, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(nextLaunch.forecast, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(nextLaunch.odds, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf("TAP: RELAUNCH", fullX, row, fullW, "center")
        love.graphics.setFont(previousFont)
    elseif self.expedition.phase == "destroyed" then
        local loadout = self:loadoutLines()
        love.graphics.setColor(0.08, 0.02, 0.03, 0.94)
        love.graphics.rectangle("fill", 12, 174, viewport.width - 24, 134)
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        local fullX, fullW = 16, viewport.width - 32
        local row = 178
        local rowStep = 11
        love.graphics.setColor(1, 0.55, 0.45)
        love.graphics.printf("SHIP DESTROYED", fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(string.format("LOST TOTAL $%d",
            (self.expedition.lastLostSampleValue or 0) + (self.expedition.lastLostSlotValue or 0)),
            fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(string.format("SAMPLES (%d) $%d",
            self.expedition.lastLostSampleCount or 0, self.expedition.lastLostSampleValue or 0),
            fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf(string.format("SPINS (%d) $%d",
            self.expedition.lastLostSlotSpinsCount or 0, self.expedition.lastLostSlotValue or 0),
            fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(string.format("PEAK ALT %d", math.floor(self.expedition.lastLostAltitude or 0)),
            fullX, row, fullW, "center")
        row = row + rowStep
        if self.expedition.lastLostNewBest then
            love.graphics.setColor(1, 0.95, 0.3)
            love.graphics.printf("NEW BEST!", fullX, row, fullW, "center")
            row = row + rowStep
        end
        love.graphics.setColor(1, 0.55, 0.45)
        love.graphics.printf(string.format("META RESET  BEST %d", math.floor(self.expedition.bestAltitude)), fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf("NEXT " .. loadout.ship, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(loadout.upgrades, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf("TAP: START OVER", fullX, row, fullW, "center")
        love.graphics.setFont(previousFont)
    elseif self.expedition.phase == "ascending" then
        local steering = self:steeringButtonState()
        if steering.leftActive then
            love.graphics.setColor(0.35, 0.9, 1, 0.8)
        else
            love.graphics.setColor(0.25, 0.55, 0.8, 0.45)
        end
        local ascendBandHeight = ascendControls.bottom - ascendControls.top
        love.graphics.rectangle("fill", 5, ascendControls.top, 76, ascendBandHeight)
        if steering.rightActive then
            love.graphics.setColor(0.35, 0.9, 1, 0.8)
        else
            love.graphics.setColor(0.25, 0.55, 0.8, 0.45)
        end
        love.graphics.rectangle("fill", 99, ascendControls.top, 76, ascendBandHeight)
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousSteeringFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        local ascendLabelY = ascendControls.top + math.floor((ascendBandHeight - 10) / 2)
        love.graphics.setColor(steering.leftActive and 0.05 or 0.85,
            steering.leftActive and 0.15 or 0.95, steering.leftActive and 0.2 or 1)
        love.graphics.printf("HOLD LEFT", 5, ascendLabelY, 76, "center")
        love.graphics.setColor(steering.rightActive and 0.05 or 0.85,
            steering.rightActive and 0.15 or 0.95, steering.rightActive and 0.2 or 1)
        love.graphics.printf("HOLD RIGHT", 99, ascendLabelY, 76, "center")
        love.graphics.setFont(previousSteeringFont)
    elseif self.expedition.phase == "returning" then
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousOddsFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(self:slotOddsLine(), 12, 197, viewport.width - 24, "center")
        -- The slot result panel's symbol/WIN lines previously used the
        -- default font (measured 160px for "PLANET  PLANET  PLANET" and
        -- 155px for "WIN +$40  PENDING $40" via GAME_FONTPROBE) inside a
        -- 140px-wide printf box, which auto-wrapped the widest strings to
        -- a second line and collided with the fixed y=231 WIN row below
        -- (confirmed via a real LÖVE runtime capture,
        -- GAME_CAPTURE_PHASE=returning-fuelbonus). The same small font
        -- (8px, measured max 108px symbol row / 103px WIN row) already
        -- used for the ODDS line above fits both rows without wrapping.
        if self.slotSpin then
            love.graphics.setColor(0.02, 0.03, 0.08, 0.9)
            love.graphics.rectangle("fill", 18, 210, 144, 34)
            love.graphics.setColor(0.85, 0.95, 1)
            love.graphics.printf(table.concat(self:currentSlotReels(), "  "), 20, 216, 140, "center")
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.printf("SPINNING...", 20, 231, 140, "center")
        elseif self.expedition.lastSlotSymbols then
            love.graphics.setColor(0.02, 0.03, 0.08, 0.9)
            love.graphics.rectangle("fill", 18, 210, 144, 34)
            love.graphics.setColor(0.85, 0.95, 1)
            love.graphics.printf(table.concat(self.expedition.lastSlotSymbols, "  "), 20, 216, 140, "center")
            love.graphics.setColor(1, 0.8, 0.3)
            if self.expedition.lastSlotRepair and self.expedition.lastSlotRepair > 0 then
                love.graphics.printf(string.format("WIN +$%d  REPAIR +%d",
                    self.expedition.lastSlotReward,
                    self.expedition.lastSlotRepair), 20, 231, 140, "center")
            elseif self.expedition.lastSlotFuelBonus and self.expedition.lastSlotFuelBonus > 0 then
                love.graphics.printf(string.format("WIN +$%d  FUEL +%d",
                    self.expedition.lastSlotReward,
                    self.expedition.lastSlotFuelBonus), 20, 231, 140, "center")
            elseif self.expedition.lastSlotSampleBonus and self.expedition.lastSlotSampleBonus > 0 then
                love.graphics.printf(string.format("WIN +$%d  SAMPLE +$%d",
                    self.expedition.lastSlotReward,
                    self.expedition.lastSlotSampleBonus), 20, 231, 140, "center")
            else
                love.graphics.printf(string.format("WIN +$%d  PENDING $%d",
                    self.expedition.lastSlotReward,
                    self.expedition.pendingSlotReward), 20, 231, 140, "center")
            end
        end
        love.graphics.setFont(previousOddsFont)
        local slotButton = self:slotButtonState()
        local steering = self:steeringButtonState()
        local returnBandHeight = returnControls.bottom - returnControls.top
        local returnLabelY = returnControls.top + math.floor((returnBandHeight - 10) / 2)
        if steering.leftActive then
            love.graphics.setColor(0.35, 0.9, 1, 0.95)
        else
            love.graphics.setColor(0.25, 0.55, 0.8, 0.6)
        end
        love.graphics.rectangle("fill", 5, returnControls.top, 50, returnBandHeight)
        if steering.rightActive then
            love.graphics.setColor(0.35, 0.9, 1, 0.95)
        else
            love.graphics.setColor(0.25, 0.55, 0.8, 0.6)
        end
        love.graphics.rectangle("fill", 125, returnControls.top, 50, returnBandHeight)
        if slotButton.enabled then
            love.graphics.setColor(0.25, 0.55, 0.8, 0.6)
        else
            love.graphics.setColor(0.18, 0.2, 0.25, 0.75)
        end
        love.graphics.rectangle("fill", 60, returnControls.top, 60, returnBandHeight)
        self.smallFont = self.smallFont or love.graphics.newFont(8)
        local previousReturnButtonFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(steering.leftActive and 0.05 or 0.85,
            steering.leftActive and 0.15 or 0.95, steering.leftActive and 0.2 or 1)
        love.graphics.printf("LEFT", 5, returnLabelY, 50, "center")
        love.graphics.setColor(steering.rightActive and 0.05 or 0.85,
            steering.rightActive and 0.15 or 0.95, steering.rightActive and 0.2 or 1)
        love.graphics.printf("RIGHT", 125, returnLabelY, 50, "center")
        if slotButton.enabled then
            love.graphics.setColor(0.85, 0.95, 1)
        else
            love.graphics.setColor(0.55, 0.58, 0.65)
        end
        love.graphics.printf(slotButton.compactLabel, 60, returnLabelY, 60, "center")
        love.graphics.setFont(previousReturnButtonFont)
    end
    love.graphics.setColor(0.85, 0.9, 1)
    local messageY = (self.expedition.phase == "settlement" or self.expedition.phase == "destroyed") and 50 or viewport.height - 30
    love.graphics.printf(self.message, 4, messageY, viewport.width - 8, "center")
    love.graphics.setColor(1, 0.65, 0.2, 0.85)
    love.graphics.printf("DEV PLACEHOLDER", 4, viewport.height - 13, viewport.width - 8, "center")
end

return M
