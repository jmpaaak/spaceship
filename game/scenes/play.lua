local shipModule = require("game.ship")
local expedition = require("game.expedition")
local bestAltitudeStore = require("game.best_altitude_store")
local collectionStore = require("game.collection_store")
local viewport = require("game.viewport")
local world = require("game.world")
local joystick = require("game.joystick")
local minimap = require("game.minimap")
local i18n = require("game.i18n")
local fonts = require("game.fonts")
local M = {}
M.__index = M

-- Omnidirectional movement, slice 1 (docs/GAME_DESIGN.md 이동 방식 개선 항목
-- 1, "조이스틱을 통해 전방향으로 이동 가능함"): the ship's horizontal
-- steering (self.ship.x) already used the full expedition.steeringSpeed
-- axis. This adds a vertical maneuvering axis (self.verticalOffset) driven
-- by the same joystick's Y component, layered on top of the still-
-- automatic altitude/fuel economy (game/expedition.lua) so a player can
-- dodge/collect in any direction around the auto-advancing flight line
-- without changing the fuel/distance economy itself. Slice 2 (은하계 기반
-- 우주 구조, per user's agreed plan) will replace the automatic altitude
-- line with real free-roam position entirely.
local verticalOffsetLimit = 90
M.verticalOffsetLimit = verticalOffsetLimit

-- Keyboard yaw rate (rad/s). No angular clamp — holding left/right
-- spins the ship continuously. Stick heading uses atan2 of the drag
-- vector, also unclamped, so the nose can point any direction.
local steerTurnRate = 0.9
M.steerTurnRate = steerTurnRate
-- Stick heading follow rate (1/s). Was 14 — nearly snapped to the stick
-- every frame. Slow enough that the hull turns like it's fighting thrust.
local stickTurnFollow = 1.8
M.stickTurnFollow = stickTurnFollow
local rcsPuffDuration = 1.32
M.rcsPuffDuration = rcsPuffDuration

function M.headingFromStick(dx, dy)
    return math.atan2(dy or 0, dx or 0)
end

local function shortestAngleDelta(from, to)
    local d = to - from
    while d > math.pi do d = d - 2 * math.pi end
    while d < -math.pi do d = d + 2 * math.pi end
    return d
end
M.shortestAngleDelta = shortestAngleDelta

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

-- Launch-screen text size/layout cleanup (docs/feedback 2026-09-02, user
-- confirmed, top priority). A real LÖVE runtime capture
-- (GAME_CAPTURE_PHASE=launch) showed two real rendering defects: (1) the
-- top HUD used the default 14px font across three lines (46px tall, ~14%
-- of the 320px canvas, oversized relative to the 48px minimap chart and
-- 8px specimen-strip squares below it); (2) the LAUNCH LOADOUT card's
-- title/ship/stats/upgrades lines also used the default 14px font inside
-- a 90px-tall box (204-294) that stopped short of the Earth disc drawn
-- behind it (radius 58 centered near y=260 for a ship at the world
-- origin, extending to y=318), leaving a sliver of blue Earth visible
-- directly behind the TAP TO LAUNCH message and DEV PLACEHOLDER footer --
-- the "text overlapping a circular element" the user reported.
--
-- Fix: shrink the launch-phase HUD to the small 8px scene font at a
-- tighter 32px band (down from 46px), and switch every LOADOUT line to
-- the same small font inside a background box extended all the way to
-- the canvas bottom (viewport.height) so the Earth disc can no longer
-- show through below the box.
M.launchHudHeight = 32
-- Regression fix (2026-09-02, same feedback item, follow-up capture): the
-- Earth disc drawn behind the scene (center y=75-cameraY for a ship parked
-- at the world origin, radius 58) tops out at y=202, two pixels above the
-- box's previous 204px top -- a real LÖVE runtime capture showed a faint
-- blue crescent peeking out just above the LAUNCH LOADOUT card. Raised the
-- box top to 202 so it fully covers the disc's topmost extent.
M.launchLoadoutBoxTop = 202
M.launchLoadoutRowStep = 10

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

-- Balatro-style card-game visual punch-up requested by the user (2026-09-02
-- pending feedback): stronger rim glow, a burst of tier-colored particles,
-- and a ship scale-punch/shake on sample pickup and collision impact. This
-- only adds a Lua rendering layer on top of the existing DEV PLACEHOLDER
-- shapes (per game/effect-studio's impact/particles/lighting recipes) -- it
-- is not a final-art texture swap, so it is exempt from the AetherAI-only
-- asset policy and can ship immediately. Higher sample tiers get more
-- particles, more glow rings and a brighter glow alpha so common/rare/epic
-- are visually distinct at a glance, not just by ring color.
local sampleTierEffects = {
    common = { particleCount = 6, glowRings = 1, glowAlpha = 0.35 },
    rare = { particleCount = 10, glowRings = 2, glowAlpha = 0.5 },
    epic = { particleCount = 16, glowRings = 3, glowAlpha = 0.75 },
}

local function sampleTierEffect(tier)
    return sampleTierEffects[tier] or sampleTierEffects.common
end
M.sampleTierEffect = sampleTierEffect

-- Twinkle/sparkle animation parameters per sample tier: higher tiers pulse
-- faster, with a wider brightness swing (amplitude) around a higher base
-- alpha, and are drawn with more sparkle points so an undiscovered epic
-- planet visibly shimmers more than a common one instead of a static ring.
local sampleTierSparkles = {
    common = { count = 2, speed = 2.2, base = 0.35, amplitude = 0.15 },
    rare = { count = 3, speed = 3.0, base = 0.5, amplitude = 0.25 },
    epic = { count = 5, speed = 4.2, base = 0.65, amplitude = 0.35 },
}

local function sampleTierSparkle(tier)
    return sampleTierSparkles[tier] or sampleTierSparkles.common
end
M.sampleTierSparkle = sampleTierSparkle

-- Deterministic oscillating alpha for a sparkle point: base brightness plus
-- a sine wave offset by `seed` (per-point phase) so multiple sparkle points
-- on the same planet twinkle out of sync with each other.
local function sparkleAlpha(tier, time, seed)
    local sparkle = sampleTierSparkle(tier)
    return sparkle.base + math.sin(time * sparkle.speed + (seed or 0)) * sparkle.amplitude
end
M.sparkleAlpha = sparkleAlpha

-- Anticipation glow acceleration (docs/feedback/INBOX.md 2026-09-02 후속
-- 확정 사항 #6, "불확실성 속의 기대감"): the slot-spin animation already
-- gives a short "settling" beat for slot rewards; sample discovery had no
-- equivalent tension beat. Accelerate the twinkle animation speed as the
-- ship closes in on an undiscovered planet's collection radius so the
-- shimmer visibly speeds up right before the sample is grabbed. Within
-- `sparkleAnticipationRange` of the collection radius edge, the speed
-- multiplier ramps linearly from 1x up to the max; once inside the
-- collection radius (or closer) it stays clamped at the max.
local sparkleAnticipationRange = 60
local sparkleAnticipationMaxMultiplier = 3.0
M.sparkleAnticipationRange = sparkleAnticipationRange
M.sparkleAnticipationMaxMultiplier = sparkleAnticipationMaxMultiplier

local function sparkleAnticipationMultiplier(distance, collectRadius)
    local edgeDistance = distance - collectRadius
    if edgeDistance <= 0 then return sparkleAnticipationMaxMultiplier end
    if edgeDistance >= sparkleAnticipationRange then return 1 end
    local progress = 1 - edgeDistance / sparkleAnticipationRange
    return 1 + progress * (sparkleAnticipationMaxMultiplier - 1)
end
M.sparkleAnticipationMultiplier = sparkleAnticipationMultiplier

-- Duration (seconds) of the ship scale-punch on sample pickup and the
-- ship/camera shake on collision impact.
local shipPunchDuration = 0.2
local shipShakeDuration = 0.25
M.shipPunchDuration = shipPunchDuration
M.shipShakeDuration = shipShakeDuration

-- Score-proportional screen shake (docs/feedback/INBOX.md 2026-09-02 후속
-- 확정 사항 #3): the collision shake used to be a fixed magnitude
-- regardless of what was hit. Scale the shake strength by the tier of the
-- planet collided with (world.sampleTier) so a bigger/rarer planet "hits
-- harder" and the player feels the difference through shake alone, the
-- same way particle density/glow already differ by tier.
local sampleTierShakeMultipliers = {
    common = 1.0,
    rare = 1.6,
    epic = 2.4,
}

local function sampleTierShakeMultiplier(tier)
    return sampleTierShakeMultipliers[tier] or sampleTierShakeMultipliers.common
end
M.sampleTierShakeMultiplier = sampleTierShakeMultiplier

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

-- Numeric roll-up feedback (docs/feedback/INBOX.md 2026-09-02 후속 확정
-- 사항 #2): rather than a sample's "+$N" floating text popping in at its
-- final value instantly, it now counts up from $0 to the awarded amount
-- over this duration, like a slot-machine reel/chip counter settling on
-- its result, before holding steady for the rest of its lifetime.
local sampleRollupDuration = 0.3
M.sampleRollupDuration = sampleRollupDuration

-- Computes the "in progress" displayed roll-up value for a sample floating
-- text: 0 at elapsed<=0, linearly interpolated up to the full awarded
-- amount at elapsed>=duration (rounded to the nearest whole dollar so the
-- counter reads as discrete ticking digits, not fractional cents).
local function rollupAmount(awarded, elapsed, duration)
    if duration <= 0 then return awarded end
    local progress = math.max(0, math.min(1, elapsed / duration))
    return math.floor(awarded * progress + 0.5)
end
M.rollupAmount = rollupAmount

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

-- Split-column layout for the two settlementTouchRows entries that share a
-- single 44px band between two keys (HULL/STEERING, then YIELD/SHIP; see
-- settlementTouchRows' `columns` sub-tables, left=0..90, right=90..180 in
-- full canvas coordinates). Two prior cycles tried moving the *existing*
-- full-width action/status printf calls to sit flush inside these bands and
-- both were reverted after a real LÖVE capture showed the two items'
-- full-width centered text overlapping (see docs/STATUS.md "이번 사이클
-- 시도 및 되돌림 기록"). This cycle takes a narrower, additive fix instead
-- of repositioning the existing verified rows: only the compact
-- hullActionCompact/steeringActionCompact/yieldActionCompact/
-- shipActionCompact action strings (measured 38-63px via GAME_FONTPROBE,
-- see shopLoadoutLines) and their purchaseStatus() results (measured
-- <=52px, same as shopStatusColumnW) are drawn confined to each item's own
-- half of the shared row, so a row's left half always shows the key whose
-- touch column is settlementTouchRows[n].columns[1] (left=0,right=90) and
-- the right half always shows columns[2] (left=90,right=180). The existing
-- full-width preview/forecast lines below each shared row are left
-- untouched (they are advisory text, not the tap target itself, and were
-- already verified not to overlap).
local shopColumnLeftX, shopColumnLeftW = 16, 68
local shopColumnRightX, shopColumnRightW = 88, 68
M.shopColumnLeftX = shopColumnLeftX
M.shopColumnLeftW = shopColumnLeftW
M.shopColumnRightX = shopColumnRightX
M.shopColumnRightW = shopColumnRightW

-- EARTH SHOP touch-row background shading. Two prior cycles tried to move
-- the shop's text lines to sit flush inside each settlementTouchRows band
-- and both attempts were reverted after a real LÖVE capture showed shared
-- HULL/STEERING and YIELD/SHIP columns' full-width centered text
-- overlapping (see docs/STATUS.md "이번 사이클 시도 및 되돌림 기록"). This
-- takes the safer path: instead of repositioning the already-verified,
-- non-overlapping text, it draws a faint alternating background band behind
-- each settlementTouchRows entry so the four tappable rows are visually
-- distinguishable at a glance, without touching a single printf call.
local settlementRowBackgroundColors = {
    { 0.08, 0.14, 0.22, 0.35 },
    { 0.05, 0.09, 0.15, 0.2 },
}
M.settlementRowBackgroundColors = settlementRowBackgroundColors

function M.settlementRowBackgroundColor(index)
    return settlementRowBackgroundColors[(index - 1) % #settlementRowBackgroundColors + 1]
end

function M.new(options)
    options = options or {}
    local ship = shipModule.new()
    local altitudeStore = options.bestAltitudeStore or bestAltitudeStore.new()
    local specimenStore = options.collectionStore or collectionStore.new()
    if love.graphics then
        love.graphics.setFont(fonts.get(14))
    end
    return setmetatable({
        ship = ship,
        expedition = expedition.new({ bestAltitude = altitudeStore:load() }),
        bestAltitudeStore = altitudeStore,
        collectionStore = specimenStore,
        collectedSpecimens = specimenStore:load(),
        newSpecimenBanner = nil,
        newSpecimenBannerTimer = 0,
        discovered = {},
        collided = {},
        discoveredCount = 0,
        floatingTexts = {},
        particles = {},
        time = 0,
        shipPunch = 0,
        shipShake = 0,
        shipShakeMagnitude = sampleTierShakeMultiplier("common"),
        slotSpin = nil,
        touches = {},
        verticalOffset = 0,
        rcsCooldown = 0,
        message = i18n.t("launch_tap_to_launch"),
    }, M)
end

-- Spawns a tier-scaled burst of short-lived particles at (x, y) using the
-- tier's rim-glow color, and starts a brief ship scale-punch so pickups feel
-- impactful (Balatro-style card pop) instead of a flat sprite swap.
function M:spawnSampleParticles(x, y, tier)
    local effect = sampleTierEffect(tier)
    local r, g, b = sampleTierColor(tier)
    for i = 1, effect.particleCount do
        local angle = (i / effect.particleCount) * math.pi * 2 + math.random() * 0.4
        local speed = 40 + math.random() * 50
        table.insert(self.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            timer = 0.5,
            maxTimer = 0.5,
            r = r,
            g = g,
            b = b,
        })
    end
    self.shipPunch = shipPunchDuration
end

function M:persistBestAltitude()
    return self.bestAltitudeStore:save(self.expedition.bestAltitude)
end

-- Draws the compact "탐험 도감" (specimen log) strip: one small square per
-- catalog entry (9 total), filled with its tier color plus a soft glow
-- (Balatro-style card rim glow, scaled down) when discovered, and a dim
-- outline placeholder when not. A small "SPECIMENS n/9" label sits above
-- the row so the strip reads as a collection, not a random decoration.
-- Placed over the open starfield/Earth view above the LAUNCH LOADOUT
-- card so exploration trophies decorate the otherwise-empty space under
-- the title screen without competing with any HUD or loadout text.
function M:drawSpecimenStrip(y)
    local catalog = world.specimenCatalog()
    local box = 8
    local gap = 3
    local totalWidth = #catalog * box + (#catalog - 1) * gap
    local startX = math.floor((viewport.width - totalWidth) / 2)
    self.tinyFont = self.tinyFont or fonts.get(7)
    local previousFont = love.graphics.getFont()
    love.graphics.setFont(self.tinyFont)
    local found = self:specimenProgress()
    love.graphics.setColor(0.55, 0.65, 0.85, 0.9)
    love.graphics.printf(i18n.t("specimens_count_label", found, #catalog),
        0, y - 10, viewport.width, "center")
    for i, entry in ipairs(catalog) do
        local x = startX + (i - 1) * (box + gap)
        if self.collectedSpecimens[entry.id] then
            local r, g, b = sampleTierColor(entry.tier)
            love.graphics.setColor(r, g, b, 0.35)
            love.graphics.rectangle("fill", x - 2, y - 2, box + 4, box + 4)
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", x, y, box, box)
        else
            love.graphics.setColor(0.3, 0.35, 0.45, 0.6)
            love.graphics.rectangle("line", x, y, box, box)
        end
    end
    love.graphics.setFont(previousFont)
end

-- Count of specimen kinds discovered out of the full 9-entry catalog.
function M:specimenProgress()
    local total = 0
    local catalog = world.specimenCatalog()
    for _, entry in ipairs(catalog) do
        if self.collectedSpecimens[entry.id] then total = total + 1 end
    end
    return total, #catalog
end

function M:collisionRisk(planet)
    local phase = self.expedition.phase
    if phase ~= "ascending" and phase ~= "returning" then return nil end
    local damage = world.collisionDamage(planet)
    local lethal = damage >= self.expedition.durability
    local risk = {
        damage = damage,
        lethal = lethal,
        label = string.format(lethal and i18n.t("risk_lethal") or i18n.t("risk_normal"), damage),
    }
    if phase == "ascending" then
        local baseValue = world.sampleValue(planet)
        risk.sampleValue = math.floor(baseValue * expedition.sampleYieldMultiplier(self.expedition) + 0.5)
        risk.sampleLabel = string.format(i18n.t("sample_value_label"), risk.sampleValue)
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
        samples = i18n.t("hud_samples", run.sampleCount, run.pendingSampleValue)
        if run.phase == "returning" then
            earth = i18n.t("hud_earth", math.ceil(run.altitude))
            local progress = 1
            if run.returnDistance > 0 then
                progress = math.max(0, math.min(1, 1 - run.altitude / run.returnDistance))
            end
            local secondsLeft = run.returnSpeed > 0 and math.ceil(run.altitude / run.returnSpeed) or 0
            returnProgress = i18n.t("hud_return_progress",
                math.floor(progress * 100 + 0.5), secondsLeft)
        end
    elseif run.phase == "launch" or run.phase == "settlement" then
        best = i18n.t("hud_personal_best", math.floor(run.bestAltitude))
    end
    return {
        primary = i18n.t("hud_primary", math.floor(run.altitude), run.money),
        samples = samples,
        best = best,
        earth = earth,
        returnProgress = returnProgress,
        status = i18n.t("hud_status", math.floor(run.fuel), run.durability,
            run.maxDurability, i18n.phaseAbbrev(run.phase), run.slotOpportunities),
        galaxy = (run.phase == "ascending" or run.phase == "returning" or run.phase == "launch")
            and (world.galaxyContaining(self.ship.x, self.ship.y) or {}).name
            or nil,
    }
end

local function launchForecastLine(run, maxFuel)
    local forecastAltitude, forecastSlots = expedition.launchForecast(run, maxFuel)
    return i18n.t("forecast_line", math.floor(forecastAltitude), forecastSlots)
end

function M:loadoutLines()
    local run = self.expedition
    return {
        ship = i18n.t("loadout_ship", string.upper(run.selectedShipId)),
        stats = i18n.t("stats_line", run.maxFuel, run.maxDurability),
        upgrades = i18n.t("upgrades_line",
            run.fuelUpgradeLevel, run.durabilityUpgradeLevel),
        forecast = launchForecastLine(run),
        steering = i18n.t("steer_speed_line", expedition.steeringSpeed(run)),
        odds = self:slotOddsLine(),
    }
end

function M:summaryFuelBonusLine()
    local bonus = self.expedition.bankedFuelBonus or 0
    if bonus <= 0 then return nil end
    return i18n.t("fuel_bonus_line", bonus)
end

local function purchaseStatus(money, cost)
    if money >= cost then return i18n.t("purchase_left", money - cost), true end
    return i18n.t("purchase_short", cost - money), false
end

local function purchaseShortfallMessage(money, cost, item)
    return i18n.t("purchase_shortfall_message", cost - money, item)
end

-- Formats the SCOUT ship trade-off using the same explicit
-- "GAINS <label> <value>" / "LOSSES <label> <value>" numeric format the
-- planet-style-editor tool uses for its GAINS/LOSSES rows, so future
-- per-planet-style risk/reward can reuse the same on-screen convention.
-- Returned as two short lines (rather than one combined line) because the
-- combined string measures 176px at the shop's small font, wider than the
-- 148px full-width shop column (measured via GAME_FONTPROBE=1) and would
-- wrap and overlap the next row.
function M.scoutTradeoffLines(run)
    local tradeoff = expedition.shipTradeoff(run, "scout")
    local gain = tradeoff.gains[1]
    local loss = tradeoff.losses[1]
    return {
        i18n.t("scout_gains_line", gain.value, gain.label),
        i18n.t("scout_losses_line", loss.value, loss.label),
    }
end

function M:shopLoadoutLines()
    local run = self.expedition
    local shipAction
    local shipActionCompact
    local shipAffordable
    local shipStatus
    local previewShipId
    if not run.ownedShips.scout then
        shipAction = i18n.t("buy_scout", run.scoutShipCost)
        shipActionCompact = i18n.t("buy_scout_compact", run.scoutShipCost)
        shipStatus, shipAffordable = purchaseStatus(run.money, run.scoutShipCost)
        previewShipId = "scout"
    elseif run.selectedShipId == "scout" then
        shipAction = i18n.t("select_starter")
        shipActionCompact = i18n.t("select_starter_compact")
        shipAffordable = true
        shipStatus = i18n.t("owned_label")
        previewShipId = "starter"
    else
        shipAction = i18n.t("select_scout")
        shipActionCompact = i18n.t("select_scout_compact")
        shipAffordable = true
        shipStatus = i18n.t("owned_label")
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
        ship = i18n.t("next_ship_label", string.upper(run.selectedShipId)),
        stats = i18n.t("stats_line", run.maxFuel, run.maxDurability),
        upgrades = i18n.t("upgrades_line",
            run.fuelUpgradeLevel, run.durabilityUpgradeLevel),
        forecast = launchForecastLine(run),
        scoutTradeoff = self.scoutTradeoffLines(run),
        shipAction = shipAction,
        shipActionCompact = shipActionCompact,
        shipStatus = shipStatus,
        shipAffordable = shipAffordable,
        shipPreview = i18n.t("ship_preview_line",
            string.upper(previewShipId), previewFuel, previewDurability),
        shipPreviewCompact = i18n.t("ship_preview_compact",
            string.upper(previewShipId), previewFuel, previewDurability),
        shipPreviewForecast = launchForecastLine(run, previewFuel),
        fuelAction = i18n.t("fuel_action_line",
            run.fuelUpgradeLevel, run.fuelUpgradeLevel + 1, run.fuelUpgradeCost),
        fuelPreviewForecast = launchForecastLine(run, run.maxFuel + run.fuelUpgradeAmount),
        fuelStatus = fuelStatus,
        fuelAffordable = fuelAffordable,
        hullAction = i18n.t("hull_action_line",
            run.durabilityUpgradeLevel, run.durabilityUpgradeLevel + 1,
            run.durabilityUpgradeCost),
        hullActionCompact = i18n.t("hull_action_compact",
            run.durabilityUpgradeLevel, run.durabilityUpgradeLevel + 1,
            run.durabilityUpgradeCost),
        hullPreview = i18n.t("stats_line",
            run.maxFuel, run.maxDurability + run.durabilityUpgradeAmount),
        hullPreviewCompact = i18n.t("hull_preview_compact",
            run.maxDurability + run.durabilityUpgradeAmount),
        hullPreviewForecast = launchForecastLine(run),
        hullStatus = hullStatus,
        hullAffordable = hullAffordable,
        yieldAction = i18n.t("yield_action_line",
            run.sampleYieldUpgradeLevel, run.sampleYieldUpgradeLevel + 1, run.sampleYieldUpgradeCost),
        yieldActionCompact = i18n.t("yield_action_compact",
            run.sampleYieldUpgradeLevel, run.sampleYieldUpgradeLevel + 1, run.sampleYieldUpgradeCost),
        yieldPreview = i18n.t("yield_preview_line",
            1 + (run.sampleYieldUpgradeLevel + 1) * run.sampleYieldUpgradeAmount),
        yieldStatus = yieldStatus,
        yieldAffordable = yieldAffordable,
        steeringAction = i18n.t("steering_action_line",
            run.steeringUpgradeLevel, run.steeringUpgradeLevel + 1, run.steeringUpgradeCost),
        steeringActionCompact = i18n.t("steering_action_compact",
            run.steeringUpgradeLevel, run.steeringUpgradeLevel + 1, run.steeringUpgradeCost),
        steeringPreview = i18n.t("steer_speed_line",
            run.baseSteeringSpeed + (run.steeringUpgradeLevel + 1) * run.steeringUpgradeAmount),
        steeringPreviewCompact = i18n.t("steering_preview_compact",
            run.baseSteeringSpeed + (run.steeringUpgradeLevel + 1) * run.steeringUpgradeAmount),
        steeringStatus = steeringStatus,
        steeringAffordable = steeringAffordable,
        odds = self:slotOddsLine(),
    }
end

function M:slotOddsLine()
    local ev = expedition.slotExpectedValue()
    return i18n.t("slot_odds_line",
        math.floor(expedition.slotSymbolProbability("COMET") * 100 + 0.5),
        math.floor(expedition.slotSymbolProbability("PLANET") * 100 + 0.5),
        math.floor(expedition.slotSymbolProbability("STAR") * 100 + 0.5),
        ev)
end

function M:slotButtonState()
    local chances = self.expedition.slotOpportunities
    if self.slotSpin then
        return { enabled = false, label = i18n.t("slot_spinning_label"), compactLabel = i18n.t("spinning_compact") }
    end
    if self.expedition.phase ~= "returning" or chances <= 0 then
        return { enabled = false, label = i18n.t("no_slot_chances_label"), compactLabel = i18n.t("no_slots_compact") }
    end
    return {
        enabled = true,
        label = i18n.t("slot_spin_prompt", chances),
        compactLabel = i18n.t("spin_compact_label", chances),
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
    self.message = i18n.t("slot_spinning_label")
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
    local up = love.keyboard.isDown("up", "w")
    local down = love.keyboard.isDown("down", "s")
    for _, touch in pairs(self.touches) do
        if touch.x < viewport.width / 2 then
            left = true
        else
            right = true
        end
    end
    return { leftActive = left, rightActive = right, upActive = up, downActive = down }
end

-- Omnidirectional joystick vector (docs/GAME_DESIGN.md 이동 방식 개선 항목 1):
-- reads the drag distance of any active touch from its press origin
-- (game/joystick.lua) so the ship can move in any direction, not just
-- along the left/right axis. Touches that haven't been dragged past the
-- deadzone (including every touch created directly in tests without an
-- origin, and simple taps that never moved) report magnitude 0, so
-- callers should fall back to the legacy binary left/right steering in
-- that case -- this keeps existing tap-and-hold controls working exactly
-- as before while adding full-direction control once a player actually
-- drags.
function M:joystickVector()
    for _, touch in pairs(self.touches) do
        if touch.originX then
            local dx, dy, magnitude = joystick.vector(touch.originX, touch.originY, touch.x, touch.y)
            if magnitude > 0 then
                return dx, dy, magnitude
            end
        end
    end
    return 0, 0, 0
end

function M:joystickKnob()
    for _, touch in pairs(self.touches) do
        if touch.originX then
            local dx, dy, magnitude = joystick.vector(touch.originX, touch.originY, touch.x, touch.y)
            if magnitude > 0 then
                local reach = magnitude * joystick.visualRadius
                return touch.originX, touch.originY, touch.originX + dx * reach, touch.originY + dy * reach, magnitude
            end
        end
    end
    return nil
end

-- Desktop fallback: if love.mousepressed was missed, poll the mouse each
-- frame and feed the same "mouse" touch id. Skipped during GAME_UNIT tests
-- so injected touches["mouse"] are not cleared by isDown()==false.
function M:pollDesktopMouse()
    if os.getenv("GAME_UNIT") == "1" then return end
    if not love.mouse or not love.mouse.isDown then return end
    if self.expedition.phase ~= "ascending" and self.expedition.phase ~= "returning"
        and self.expedition.phase ~= "launch" then
        return
    end
    if not love.mouse.isDown(1) then
        self.touches.mouse = nil
        return
    end
    if not love.graphics or not love.graphics.getDimensions then return end
    local mx, my = love.mouse.getPosition()
    local ww, wh = love.graphics.getDimensions()
    local gx, gy = viewport.toGame(mx, my, ww, wh, false)
    if gx < 0 then gx = 0 elseif gx > viewport.width then gx = viewport.width end
    if gy < 0 then gy = 0 elseif gy > viewport.height then gy = viewport.height end
    if not self.touches.mouse then
        self.touches.mouse = { x = gx, y = gy, originX = gx, originY = gy }
        if self.expedition.phase == "launch" then
            self:keypressed("space")
        end
    else
        self.touches.mouse.x = gx
        self.touches.mouse.y = gy
    end
end

local function clampVerticalOffset(value)
    if value > verticalOffsetLimit then return verticalOffsetLimit end
    if value < -verticalOffsetLimit then return -verticalOffsetLimit end
    return value
end
M.clampVerticalOffset = clampVerticalOffset

function M:update(dt)
    self.time = self.time + dt
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
    if self.slotSpin then
        self.slotSpin.elapsed = self.slotSpin.elapsed + dt
        if self.slotSpin.elapsed >= self.slotSpin.duration then
            if self.slotSpin.repair and self.slotSpin.repair > 0 then
                self.message = i18n.t("slot_result_repair",
                    table.concat(self.slotSpin.symbols, " "),
                    self.slotSpin.reward,
                    self.slotSpin.repair,
                    self.slotSpin.opportunitiesAfter)
            elseif self.slotSpin.fuelBonus and self.slotSpin.fuelBonus > 0 then
                self.message = i18n.t("slot_result_fuel",
                    table.concat(self.slotSpin.symbols, " "),
                    self.slotSpin.reward,
                    self.slotSpin.fuelBonus,
                    self.slotSpin.opportunitiesAfter)
            elseif self.slotSpin.sampleBonus and self.slotSpin.sampleBonus > 0 then
                self.message = i18n.t("slot_result_sample",
                    table.concat(self.slotSpin.symbols, " "),
                    self.slotSpin.reward,
                    self.slotSpin.sampleBonus,
                    self.slotSpin.opportunitiesAfter)
            else
                self.message = i18n.t("slot_result_plain",
                    table.concat(self.slotSpin.symbols, " "),
                    self.slotSpin.reward,
                    self.slotSpin.opportunitiesAfter)
            end
            self.slotSpin = nil
        end
    end
    if self.expedition.phase == "ascending" or self.expedition.phase == "returning" then
        local joyDx, joyDy, joyMagnitude = self:joystickVector()
        local startX, startOffset = self.ship.x, self.verticalOffset
        local thrustAngle = self.ship.angle
        if joyMagnitude > 0 then
            local speed = expedition.steeringSpeed(self.expedition)
            self.ship.x = self.ship.x + joyDx * speed * joyMagnitude * dt
            self.verticalOffset = clampVerticalOffset(
                self.verticalOffset + joyDy * speed * joyMagnitude * dt)
        else
            local speed = expedition.steeringSpeed(self.expedition)
            self.ship.x = self.ship.x
                + ((steering.rightActive and 1 or 0) - (steering.leftActive and 1 or 0))
                * speed * dt
            self.verticalOffset = clampVerticalOffset(
                self.verticalOffset
                    + ((steering.downActive and 1 or 0) - (steering.upActive and 1 or 0))
                    * speed * dt)
        end
        local extraDx = self.ship.x - startX
        local extraDy = self.verticalOffset - startOffset
        local extraDistance = math.sqrt(extraDx * extraDx + extraDy * extraDy)
        local steeringHoriz = (steering.rightActive and 1 or 0) - (steering.leftActive and 1 or 0)
        local steeringVert = (steering.downActive and 1 or 0) - (steering.upActive and 1 or 0)
        local thrusting = joyMagnitude > 0 or steeringHoriz ~= 0 or steeringVert ~= 0
        if thrusting then
            expedition.burnManeuverFuel(self.expedition, extraDistance)
        end
        if joyMagnitude > 0 then
            local targetAngle = M.headingFromStick(joyDx, joyDy)
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
        local xBeforeThrust, yBeforeThrust = self.ship.x, self.ship.y
        if thrusting then
            local altBefore = self.expedition.altitude
            expedition.update(self.expedition, dt)
            self.ship.fuel = self.expedition.fuel
            if previousPhase == "ascending" then
                local step = self.expedition.altitude - altBefore
                if step < 0 then step = 0 end
                self.ship.x = self.ship.x + math.cos(thrustAngle) * step
                self.ship.y = self.ship.y + math.sin(thrustAngle) * step + extraDy
            end
            if dt > 0 then
                self.ship.vx = (self.ship.x - xBeforeThrust) / dt
                self.ship.vy = (self.ship.y - yBeforeThrust) / dt
            end
        elseif previousPhase == "ascending" then
            -- Coast on stored velocity. No stick/keys → no fuel burn.
            self.ship.x = self.ship.x + (self.ship.vx or 0) * dt
            self.ship.y = self.ship.y + (self.ship.vy or 0) * dt
            self.ship.fuel = self.expedition.fuel
        else
            expedition.update(self.expedition, dt)
            self.ship.fuel = self.expedition.fuel
        end
        if self.expedition.phase == "returning" then
            self.ship.y = -self.expedition.altitude + self.verticalOffset
        end
        self.rcsCooldown = math.max(0, (self.rcsCooldown or 0) - dt)
        local bank = self.steerBank or 0
        local lift = self.steerLift or 0
        if thrusting and self.rcsCooldown == 0
            and (math.abs(bank) > 0.12 or math.abs(lift) > 0.12) then
            self.rcsCooldown = 0.045
            if math.abs(bank) > 0.12 then
                local side = bank > 0 and -1 or 1
                self.particles[#self.particles + 1] = {
                    x = self.ship.x + side * 6,
                    y = self.ship.y + 3,
                    vx = side * (16 + math.random() * 10),
                    vy = 6 + math.random() * 10,
                    timer = rcsPuffDuration,
                    maxTimer = rcsPuffDuration,
                    r = 0.7,
                    g = 0.88,
                    b = 1,
                }
            end
            if math.abs(lift) > 0.12 then
                -- Opposite vertical jet: stick-down puffs above, stick-up below.
                local vside = lift > 0 and -1 or 1
                self.particles[#self.particles + 1] = {
                    x = self.ship.x + (math.random() * 4 - 2),
                    y = self.ship.y + vside * 6,
                    vx = (math.random() * 8 - 4),
                    vy = vside * (16 + math.random() * 10),
                    timer = rcsPuffDuration,
                    maxTimer = rcsPuffDuration,
                    r = 0.7,
                    g = 0.88,
                    b = 1,
                }
            end
        end
    end
    if previousPhase ~= self.expedition.phase and self.expedition.phase == "returning" then
        self:persistBestAltitude()
        self.message = i18n.t("returning_message", self.expedition.slotOpportunities)
    elseif previousPhase ~= self.expedition.phase and self.expedition.phase == "settlement" then
        self.message = i18n.t("settled_message", self.expedition.lastSettlement, self.expedition.money)
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
                local hueKey = world.hueFamily(planet.hue or 0).key
                local _, awarded, streakMultiplier = expedition.collectSample(self.expedition, value, hueKey)
                awarded = awarded or value
                table.insert(self.floatingTexts, {
                    text = i18n.t("floating_sample_gain", rollupAmount(awarded, 0, sampleRollupDuration)),
                    x = planet.x,
                    y = planet.y,
                    timer = 1.0,
                    kind = "sample",
                    awarded = awarded,
                    rollupElapsed = 0,
                })
                self:spawnSampleParticles(planet.x, planet.y, world.sampleTier(planet))
                if streakMultiplier and streakMultiplier > 1 then
                    self.message = i18n.t("sample_streak_message", awarded, streakMultiplier, planet.id)
                else
                    self.message = i18n.t("sample_message", awarded, planet.id)
                end
                local specimenId, specimenLabel = world.specimenKind(planet)
                if self.collectionStore:record(specimenId) then
                    self.collectedSpecimens[specimenId] = true
                    self.newSpecimenBanner = i18n.t("new_specimen_label", specimenLabel)
                    self.newSpecimenBannerTimer = 2.0
                end
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
                self.message = i18n.t("collision_message", damage, self.expedition.durability, self.expedition.maxDurability)
            end
        end
        for _, junk in ipairs(world.nearbyDebris(self.ship.x, self.ship.y, 1, self.time)) do
            local dx, dy = junk.x - self.ship.x, junk.y - self.ship.y
            if dx * dx + dy * dy <= (junk.radius + 5) ^ 2 and not self.collided[junk.id] then
                self.collided[junk.id] = true
                local damage = self.expedition.durability
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
    if self.expedition.phase ~= "ascending" and self.expedition.phase ~= "returning" then
        self.touches = {}
    end
end

function M:keypressed(key)
    if self.expedition.phase == "settlement" and (key == "f" or key == "down" or key == "s") then
        if expedition.buyFuelUpgrade(self.expedition) then
            self.message = i18n.t("fuel_upgraded_message",
                self.expedition.fuelUpgradeLevel, self.expedition.maxFuel,
                launchForecastLine(self.expedition), self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                self.expedition.fuelUpgradeCost, i18n.t("item_fuel_upgrade"))
        end
        return
    end
    if self.expedition.phase == "settlement" and (key == "h" or key == "right" or key == "d") then
        if expedition.buyDurabilityUpgrade(self.expedition) then
            self.message = i18n.t(
                "hull_upgraded_message",
                self.expedition.durabilityUpgradeLevel, self.expedition.maxFuel,
                self.expedition.maxDurability,
                launchForecastLine(self.expedition), self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                self.expedition.durabilityUpgradeCost, i18n.t("item_hull_upgrade"))
        end
        return
    end
    if self.expedition.phase == "settlement" and key == "y" then
        if expedition.buySampleYieldUpgrade(self.expedition) then
            self.message = i18n.t(
                "yield_upgraded_message",
                self.expedition.sampleYieldUpgradeLevel,
                expedition.sampleYieldMultiplier(self.expedition),
                self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                self.expedition.sampleYieldUpgradeCost, i18n.t("item_yield_upgrade"))
        end
        return
    end
    if self.expedition.phase == "settlement" and key == "g" then
        if expedition.buySteeringUpgrade(self.expedition) then
            self.message = i18n.t(
                "steering_upgraded_message",
                self.expedition.steeringUpgradeLevel,
                expedition.steeringSpeed(self.expedition),
                self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                self.expedition.steeringUpgradeCost, i18n.t("item_steering_upgrade"))
        end
        return
    end
    if self.expedition.phase == "settlement" and key == "v" then
        if not self.expedition.ownedShips.scout then
            if expedition.buyShip(self.expedition, "scout") then
                expedition.selectShip(self.expedition, "scout")
                self.message = i18n.t(
                    "scout_purchased_message",
                    self.expedition.maxFuel, self.expedition.maxDurability,
                    launchForecastLine(self.expedition), self.expedition.money)
            else
                self.message = purchaseShortfallMessage(self.expedition.money,
                    self.expedition.scoutShipCost, i18n.t("item_scout"))
            end
        else
            local shipId = self.expedition.selectedShipId == "scout" and "starter" or "scout"
            expedition.selectShip(self.expedition, shipId)
            self.message = i18n.t("ship_selected_message",
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
                    self.verticalOffset = 0
                    self.discovered = {}
                    self.collided = {}
                    self.discoveredCount = 0
                    self.floatingTexts = {}
                end
                self.message = i18n.t("ascending_message")
            end
        end
    end
end

function M:touchpressed(id, x, y)
    if self.expedition.phase == "ascending" then
        self.touches[id] = { x = x, y = y, originX = x, originY = y }
        return
    end
    if self.expedition.phase == "returning" then
        local inControlRow = y >= returnControls.top and y <= returnControls.bottom
        if inControlRow and x >= returnControls.slotMinX and x <= returnControls.slotMaxX then
            self:keypressed("space")
        elseif inControlRow and (x <= returnControls.leftMaxX or x >= returnControls.rightMinX) then
            self.touches[id] = { x = x, y = y, originX = x, originY = y }
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

function M:drawJoystickStick()
    local ox, oy, kx, ky = self:joystickKnob()
    if not ox then return end
    local radius = joystick.visualRadius
    local knob = joystick.visualKnobRadius
    love.graphics.setColor(0.35, 0.55, 0.8, joystick.visualFillAlpha)
    love.graphics.circle("fill", ox, oy, radius)
    love.graphics.setColor(0.65, 0.85, 1, joystick.visualLineAlpha)
    love.graphics.circle("line", ox, oy, radius)
    love.graphics.setColor(0.9, 0.95, 1, joystick.visualKnobAlpha)
    love.graphics.circle("fill", kx, ky, knob)
end

-- Circular galaxy chart (docs/GAME_DESIGN.md 이동 방식 개선 항목 2·3).
-- Drawn top-right so it sits on the HUD bar without covering the
-- left-aligned ALT/CASH text. Settlement/destroyed overlays already
-- cover the playfield, so the chart is hidden there.
function M:drawMinimap()
    if self.expedition.phase == "settlement" or self.expedition.phase == "destroyed" then
        return
    end
    local hud = self:hudLines()
    local galaxyShift = hud.galaxy and 10 or 0
    local hudHeight = (self.expedition.phase == "launch" and M.launchHudHeight
        or (hud.returnProgress and 70 or ((hud.samples or hud.best) and 46 or 34))) + galaxyShift
    local view = minimap.view(self.ship.x, self.ship.y)
    local size = minimap.size
    local cx = viewport.width - size / 2 - 3
    local cy = hudHeight + size / 2 + 2
    love.graphics.setColor(0.02, 0.04, 0.1, 1)
    love.graphics.circle("fill", cx, cy, size / 2)
    love.graphics.setColor(0.35, 0.55, 0.8, 1)
    love.graphics.circle("line", cx, cy, size / 2)
    for _, ring in ipairs(view.rings or {}) do
        if ring.kind == "orbit" then
            love.graphics.setColor(0.85, 0.7, 0.25, 0.55)
            love.graphics.circle("line", cx + ring.x, cy + ring.y, ring.radius)
        elseif ring.inside ~= false then
            if ring.id == "milkyway" then
                love.graphics.setColor(0.3, 0.55, 0.95, 0.55)
            else
                love.graphics.setColor(0.9, 0.75, 0.3, 0.5)
            end
            love.graphics.circle("line", cx + ring.x, cy + ring.y, ring.radius)
        end
    end
    if view.sun then
        love.graphics.setColor(1, 0.85, 0.25)
        love.graphics.circle("fill", cx + view.sun.x, cy + view.sun.y, 2.6)
    end
    for _, galaxy in ipairs(view.galaxies) do
        if galaxy.inside then
            if galaxy.id == "milkyway" then
                love.graphics.setColor(0.25, 0.55, 1)
                love.graphics.circle("fill", cx + galaxy.x, cy + galaxy.y, 2.2)
            else
                love.graphics.setColor(0.9, 0.75, 0.3)
                love.graphics.circle("fill", cx + galaxy.x, cy + galaxy.y, 1.5)
            end
        end
    end
    love.graphics.setColor(0.3, 0.85, 1)
    love.graphics.circle("fill", cx + view.earth.x, cy + view.earth.y, 2)
    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", cx + view.player.x, cy + view.player.y, 1.7)
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("line", cx + view.player.x, cy + view.player.y, 2.4)
    if view.beyond then
        love.graphics.setColor(1, 0.55, 0.3)
        local rim = size / 2 - 5
        love.graphics.circle("fill", cx + view.returnDx * rim, cy + view.returnDy * rim, 2.2)
        local label = i18n.t("minimap_out", math.floor(view.distanceBeyond + 0.5))
        love.graphics.printf(label, viewport.width - size - 6, cy + size / 2 + 1, size + 4, "right")
    end
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
            if not self.discovered[planet.id] then
                -- Balatro-style outer rim glow: several soft, low-alpha
                -- rings outside the sample-tier ring, scaled by tier so
                -- rare/epic planets read as more valuable at a glance
                -- before the player even reads the SAMPLE $N label.
                local tier = world.sampleTier(planet)
                local effect = sampleTierEffect(tier)
                local glowR, glowG, glowB = sampleTierColor(tier)
                for ring = effect.glowRings, 1, -1 do
                    local ringAlpha = effect.glowAlpha * (ring / effect.glowRings) * 0.5
                    love.graphics.setColor(glowR, glowG, glowB, ringAlpha)
                    love.graphics.circle("fill", x, y, planet.radius + 3 + ring * 4)
                end
            end
            -- Soft drop shadow: a low-alpha dark circle offset toward the
            -- lower-right, opposite the highlight, so planets read as
            -- slightly raised cards instead of flat painted circles.
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.circle("fill", x + planet.radius * 0.22, y + planet.radius * 0.22, planet.radius * 1.02)
            -- Saturated gradient fill: a darker base circle with a brighter
            -- highlight offset toward the upper-left, approximating a soft
            -- directional light instead of a single flat fill color.
            local baseR, baseG, baseB = planetColor(planet.hue)
            love.graphics.setColor(baseR * 0.7, baseG * 0.7, baseB * 0.7)
            love.graphics.circle("fill", x, y, planet.radius)
            love.graphics.setColor(math.min(1, baseR * 1.25), math.min(1, baseG * 1.25), math.min(1, baseB * 1.25))
            love.graphics.circle("fill", x - planet.radius * 0.3, y - planet.radius * 0.3, planet.radius * 0.55)
            if not self.discovered[planet.id] then
                love.graphics.setColor(sampleTierColor(world.sampleTier(planet)))
                love.graphics.circle("line", x, y, planet.radius + 3)
                -- Balatro-style twinkle: a handful of small points orbiting
                -- just outside the rim glow, each with its own phase so the
                -- shimmer isn't perfectly synchronized across points.
                local tier = world.sampleTier(planet)
                local sparkle = sampleTierSparkle(tier)
                local sr, sg, sb = sampleTierColor(tier)
                local shipDx, shipDy = planet.x - self.ship.x, planet.y - self.ship.y
                local shipDistance = math.sqrt(shipDx * shipDx + shipDy * shipDy)
                local anticipation = sparkleAnticipationMultiplier(shipDistance, planet.radius + 14)
                for i = 1, sparkle.count do
                    local seed = (planet.id and (tostring(planet.id):len() * 7) or 0) + i * 2.4
                    local angle = self.time * (sparkle.speed * 0.4 * anticipation) + seed
                    local sparkleRadius = planet.radius + 6 + (i % 3) * 3
                    local px = x + math.cos(angle) * sparkleRadius
                    local py = y + math.sin(angle) * sparkleRadius
                    local alpha = math.max(0, math.min(1, sparkleAlpha(tier, self.time, seed)))
                    love.graphics.setColor(math.min(1, sr + 0.2), math.min(1, sg + 0.2), math.min(1, sb + 0.2), alpha)
                    love.graphics.circle("fill", px, py, 1.2)
                end
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
    for _, junk in ipairs(world.nearbyDebris(self.ship.x, self.ship.y, 1, self.time)) do
        local x, y = math.floor(junk.x - cameraX), math.floor(junk.y - cameraY)
        if x > -20 and x < viewport.width + 20 and y > -20 and y < viewport.height + 20 then
            if junk.kind == "can" then
                love.graphics.setColor(0.72, 0.76, 0.7)
                love.graphics.rectangle("fill", x - junk.radius, y - junk.radius * 1.4,
                    junk.radius * 2, junk.radius * 2.8)
                love.graphics.setColor(0.45, 0.5, 0.42)
                love.graphics.rectangle("line", x - junk.radius, y - junk.radius * 1.4,
                    junk.radius * 2, junk.radius * 2.8)
            elseif junk.kind == "scrap" then
                love.graphics.setColor(0.55, 0.38, 0.22)
                love.graphics.polygon("fill",
                    x, y - junk.radius,
                    x + junk.radius, y + junk.radius * 0.6,
                    x - junk.radius, y + junk.radius * 0.6)
            else
                love.graphics.setColor(0.45, 0.42, 0.4)
                love.graphics.circle("fill", x, y, junk.radius)
                love.graphics.setColor(0.32, 0.3, 0.28)
                love.graphics.circle("fill", x - junk.radius * 0.3, y - junk.radius * 0.2, junk.radius * 0.45)
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
    for _, particle in ipairs(self.particles) do
        local px, py = math.floor(particle.x - cameraX), math.floor(particle.y - cameraY)
        local alpha = math.max(0, particle.timer / particle.maxTimer)
        love.graphics.setColor(particle.r, particle.g, particle.b, alpha)
        love.graphics.circle("fill", px, py, 1.5)
    end
    love.graphics.push()
    local shakeX, shakeY = 0, 0
    if self.shipShake > 0 then
        local shakeStrength = (self.shipShake / shipShakeDuration) * 3 * self.shipShakeMagnitude
        shakeX = (math.random() * 2 - 1) * shakeStrength
        shakeY = (math.random() * 2 - 1) * shakeStrength
    end
    love.graphics.translate(shipScreenX + shakeX, shipScreenY + shakeY)
    love.graphics.rotate(self.ship.angle + math.pi / 2)
    if self.shipPunch > 0 then
        local punchScale = 1 + (self.shipPunch / shipPunchDuration) * 0.35
        love.graphics.scale(punchScale, punchScale)
    end
    love.graphics.setColor(0.8, 0.95, 1)
    love.graphics.polygon("fill", 0, -7, -5, 6, 0, 3, 5, 6)
    if self.expedition.phase == "ascending" then
        love.graphics.setColor(1, 0.55, 0.15)
        love.graphics.polygon("fill", -2, 5, 0, 11, 2, 5)
    end
    love.graphics.pop()

    local hud = self:hudLines()
    local isLaunchHud = self.expedition.phase == "launch"
    local galaxyShift = hud.galaxy and 10 or 0
    local hudHeight = (isLaunchHud and M.launchHudHeight
        or (hud.returnProgress and 70 or ((hud.samples or hud.best) and 46 or 34))) + galaxyShift
    love.graphics.setColor(0.02, 0.03, 0.08, 0.85)
    love.graphics.rectangle("fill", 0, 0, viewport.width, hudHeight)
    local previousHudFont
    if isLaunchHud then
        self.smallFont = self.smallFont or fonts.get(8)
        previousHudFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
    end
    love.graphics.setColor(0.7, 0.9, 1)
    local hudY = 4
    if hud.galaxy then
        love.graphics.setColor(1, 0.85, 0.4)
        love.graphics.print(hud.galaxy, 5, hudY)
        hudY = hudY + 10
        love.graphics.setColor(0.7, 0.9, 1)
    end
    love.graphics.print(hud.primary, 5, hudY)
    if hud.samples then
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.print(hud.samples, 5, 16 + galaxyShift)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.print(hud.status, 5, 30 + galaxyShift)
        if hud.earth then
            love.graphics.setColor(0.4, 0.85, 1)
            love.graphics.print(hud.earth, 5, 43 + galaxyShift)
            love.graphics.print(hud.returnProgress, 5, 55 + galaxyShift)
        end
    elseif hud.best then
        love.graphics.print(hud.status, 5, (isLaunchHud and 13 or 18) + galaxyShift)
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.print(hud.best, 5, (isLaunchHud and 22 or 30) + galaxyShift)
    else
        love.graphics.print(hud.status, 5, 18 + galaxyShift)
    end
    if isLaunchHud then
        love.graphics.setFont(previousHudFont)
    end
    self:drawMinimap()
    if self.expedition.phase == "launch" then
        -- Specimen log strip sits in the empty space between the HUD and
        -- the LAUNCH LOADOUT card, over the open starfield/Earth view, so
        -- it never competes with loadout numbers or the TAP TO LAUNCH
        -- message below the panel.
        self:drawSpecimenStrip(184)
        local loadout = self:loadoutLines()
        -- The card box now extends all the way to the canvas bottom
        -- (viewport.height) instead of stopping at y=294: a real LÖVE
        -- runtime capture showed the Earth disc drawn behind the scene
        -- (radius 58, extending to y=318 for a ship at the world origin)
        -- peeking out below the old box, directly behind the TAP TO
        -- LAUNCH message and DEV PLACEHOLDER footer text.
        love.graphics.setColor(0.02, 0.03, 0.08, 0.92)
        love.graphics.rectangle("fill", 12, M.launchLoadoutBoxTop, viewport.width - 24,
            viewport.height - M.launchLoadoutBoxTop)
        -- Every LOADOUT line now uses the small 8px scene-cached font
        -- (previously the default 14px font) so the text sizes relative
        -- to the small circular minimap chart/specimen-strip squares
        -- above it, with a tightened row step so six lines fit in the
        -- freed vertical space without overlapping each other or the
        -- TAP TO LAUNCH message drawn separately below.
        self.smallFont = self.smallFont or fonts.get(8)
        local previousLaunchFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        local row = M.launchLoadoutBoxTop + 4
        local rowStep = M.launchLoadoutRowStep
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf(i18n.t("launch_loadout_title"), 16, row, viewport.width - 32, "center")
        row = row + rowStep
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(loadout.ship, 16, row, viewport.width - 32, "center")
        row = row + rowStep
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(loadout.stats, 16, row, viewport.width - 32, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(loadout.upgrades, 16, row, viewport.width - 32, "center")
        row = row + rowStep
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(loadout.forecast, 16, row, viewport.width - 32, "center")
        row = row + rowStep
        love.graphics.setColor(0.6, 1, 0.85)
        love.graphics.printf(loadout.steering, 16, row, viewport.width - 32, "center")
        row = row + rowStep
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(loadout.odds, 16, row, viewport.width - 32, "center")
        love.graphics.setFont(previousLaunchFont)
    elseif self.expedition.phase == "settlement" then
        -- The summary card is drawn with the same scene-cached small font as
        -- the shop rows (instead of the default 14px font) and tightened to
        -- a 9px line step. This frees enough vertical room above the fixed
        -- 320px canvas bottom for PlayScene.settlementTouchRows to grow each
        -- row to the 44pt real-device accessibility minimum (see
        -- game/self_test.lua) at the smallest supported window (integer
        -- scale 1), not just the previous 34px minimum.
        self.smallFont = self.smallFont or fonts.get(8)
        local previousFont = love.graphics.getFont()
        love.graphics.setColor(0.02, 0.03, 0.08, 0.94)
        love.graphics.rectangle("fill", 12, 70, viewport.width - 24, 250)
        -- Faint alternating background bands behind each tappable
        -- settlementTouchRows entry. Drawn before any text so it never
        -- overlaps or obscures the already real-capture-verified printf
        -- calls below; purely a visual affordance for which rows respond
        -- to touch (see settlementRowBackgroundColor comment above).
        for index, touchRow in ipairs(settlementTouchRows) do
            love.graphics.setColor(M.settlementRowBackgroundColor(index))
            love.graphics.rectangle("fill", 12, touchRow.top, viewport.width - 24, touchRow.bottom - touchRow.top)
        end
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf(i18n.t("earth_shop_title"), 16, 74, viewport.width - 32, "center")
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
            summaryExtraLine = i18n.t("newbest_fuel_combined", self.expedition.bankedFuelBonus)
        elseif self.expedition.lastNewBest then
            summaryExtraLine = i18n.t("newbest_label")
        elseif fuelBonusLine then
            summaryExtraLine = fuelBonusLine
        end
        love.graphics.setColor(0.04, 0.08, 0.16, 0.85)
        love.graphics.rectangle("fill", 18, 88, viewport.width - 36, 46)
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(i18n.t("total_label", self.expedition.lastSettlement), 22, 91, viewport.width - 44, "center")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(i18n.t("samples_settlement_line", self.expedition.lastSampleCount or 0, self.expedition.lastSampleSettlement), 22, 100, viewport.width - 44, "center")
        love.graphics.printf(i18n.t("spins_settlement_line", self.expedition.lastSlotSpinsCount or 0, self.expedition.lastSlotSettlement), 22, 109, viewport.width - 44, "center")
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(i18n.t("peak_alt_line", math.floor(self.expedition.lastAltitude or 0)), 22, 118, viewport.width - 44, "center")
        if summaryExtraLine then
            love.graphics.setColor(1, 0.95, 0.3)
            love.graphics.printf(summaryExtraLine, 22, 127, viewport.width - 44, "center")
        end
        local nextLaunch = self:shopLoadoutLines()
        local actionX, actionW = shopActionColumnX, shopActionColumnW
        local statusX, statusW = shopStatusColumnX, shopStatusColumnW
        local fullX, fullW = 16, viewport.width - 32
        local row = 140
        -- Was 9px until the SCOUT trade-off gained a second line (GAINS/
        -- LOSSES split, see M.scoutTradeoffLines), pushing the 20-row total
        -- past the y=307 DEV PLACEHOLDER footer (measured via a real LÖVE
        -- capture: TAP: RELAUNCH landed at y=311, overlapping the footer).
        -- Tightened to 8px so the last row (TAP: RELAUNCH) lands at
        -- y=140+19*8=292, comfortably above the footer again.
        local rowStep = 8
        row = 156
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.fuelAction, actionX, row, actionW, "left")
        love.graphics.setColor(nextLaunch.fuelAffordable and 0.45 or 1,
            nextLaunch.fuelAffordable and 1 or 0.4, nextLaunch.fuelAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.fuelStatus, statusX, row, statusW, "right")
        row = row + rowStep
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(nextLaunch.fuelPreviewForecast, fullX, row, fullW, "center")
        row = row + rowStep
        -- HULL and STEERING
        row = 180
        rowStep = 8
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.hullActionCompact, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.printf(nextLaunch.steeringActionCompact, shopColumnRightX, row, shopColumnRightW, "center")
        row = row + rowStep
        
        love.graphics.setColor(nextLaunch.hullAffordable and 0.45 or 1,
            nextLaunch.hullAffordable and 1 or 0.4, nextLaunch.hullAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.hullStatus, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.setColor(nextLaunch.steeringAffordable and 0.45 or 1,
            nextLaunch.steeringAffordable and 1 or 0.4, nextLaunch.steeringAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.steeringStatus, shopColumnRightX, row, shopColumnRightW, "center")
        row = row + rowStep
        
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(nextLaunch.hullPreviewCompact, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.printf(nextLaunch.steeringPreviewCompact, shopColumnRightX, row, shopColumnRightW, "center")
        row = row + rowStep

        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(nextLaunch.hullPreviewForecast, fullX, row, fullW, "center")

        -- YIELD and SHIP
        row = 216
        rowStep = 8
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.yieldActionCompact, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.printf(nextLaunch.shipActionCompact, shopColumnRightX, row, shopColumnRightW, "center")
        row = row + rowStep
        
        love.graphics.setColor(nextLaunch.yieldAffordable and 0.45 or 1,
            nextLaunch.yieldAffordable and 1 or 0.4, nextLaunch.yieldAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.yieldStatus, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.setColor(nextLaunch.shipAffordable and 0.45 or 1,
            nextLaunch.shipAffordable and 1 or 0.4, nextLaunch.shipAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.shipStatus, shopColumnRightX, row, shopColumnRightW, "center")
        row = row + rowStep

        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(nextLaunch.yieldPreview, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.printf(nextLaunch.shipPreviewCompact, shopColumnRightX, row, shopColumnRightW, "center")
        row = row + rowStep
        
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.scoutTradeoff[1], fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf(nextLaunch.scoutTradeoff[2], fullX, row, fullW, "center")
        row = row + rowStep
        
        love.graphics.setColor(0.45, 1, 0.6)
        love.graphics.printf(nextLaunch.shipPreviewForecast, fullX, row, fullW, "center")
        
        row = 264
        rowStep = 8
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
        love.graphics.printf(i18n.t("tap_relaunch"), fullX, row, fullW, "center")
        love.graphics.setFont(previousFont)
    elseif self.expedition.phase == "destroyed" then
        local loadout = self:loadoutLines()
        love.graphics.setColor(0.08, 0.02, 0.03, 0.94)
        love.graphics.rectangle("fill", 12, 174, viewport.width - 24, 134)
        self.smallFont = self.smallFont or fonts.get(8)
        local previousFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        local fullX, fullW = 16, viewport.width - 32
        local row = 178
        local rowStep = 11
        love.graphics.setColor(1, 0.55, 0.45)
        love.graphics.printf(i18n.t("ship_destroyed_title"), fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(i18n.t("lost_total_line",
            (self.expedition.lastLostSampleValue or 0) + (self.expedition.lastLostSlotValue or 0)),
            fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(i18n.t("samples_settlement_line",
            self.expedition.lastLostSampleCount or 0, self.expedition.lastLostSampleValue or 0),
            fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf(i18n.t("spins_settlement_line",
            self.expedition.lastLostSlotSpinsCount or 0, self.expedition.lastLostSlotValue or 0),
            fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(i18n.t("peak_alt_line", math.floor(self.expedition.lastLostAltitude or 0)),
            fullX, row, fullW, "center")
        row = row + rowStep
        if self.expedition.lastLostNewBest then
            love.graphics.setColor(1, 0.95, 0.3)
            love.graphics.printf(i18n.t("newbest_label"), fullX, row, fullW, "center")
            row = row + rowStep
        end
        love.graphics.setColor(1, 0.55, 0.45)
        love.graphics.printf(i18n.t("meta_reset_line", math.floor(self.expedition.bestAltitude)), fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(i18n.t("next_ship_line", loadout.ship), fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(loadout.upgrades, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf(i18n.t("tap_start_over"), fullX, row, fullW, "center")
        love.graphics.setFont(previousFont)
    elseif self.expedition.phase == "ascending" then
        self:drawJoystickStick()
    elseif self.expedition.phase == "returning" then
        self.smallFont = self.smallFont or fonts.get(8)
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
            love.graphics.printf(i18n.t("spinning_label"), 20, 231, 140, "center")
        elseif self.expedition.lastSlotSymbols then
            love.graphics.setColor(0.02, 0.03, 0.08, 0.9)
            love.graphics.rectangle("fill", 18, 210, 144, 34)
            love.graphics.setColor(0.85, 0.95, 1)
            love.graphics.printf(table.concat(self.expedition.lastSlotSymbols, "  "), 20, 216, 140, "center")
            love.graphics.setColor(1, 0.8, 0.3)
            if self.expedition.lastSlotRepair and self.expedition.lastSlotRepair > 0 then
                love.graphics.printf(i18n.t("win_repair_line",
                    self.expedition.lastSlotReward,
                    self.expedition.lastSlotRepair), 20, 231, 140, "center")
            elseif self.expedition.lastSlotFuelBonus and self.expedition.lastSlotFuelBonus > 0 then
                love.graphics.printf(i18n.t("win_fuel_line",
                    self.expedition.lastSlotReward,
                    self.expedition.lastSlotFuelBonus), 20, 231, 140, "center")
            elseif self.expedition.lastSlotSampleBonus and self.expedition.lastSlotSampleBonus > 0 then
                love.graphics.printf(i18n.t("win_sample_line",
                    self.expedition.lastSlotReward,
                    self.expedition.lastSlotSampleBonus), 20, 231, 140, "center")
            else
                love.graphics.printf(i18n.t("win_pending_line",
                    self.expedition.lastSlotReward,
                    self.expedition.pendingSlotReward), 20, 231, 140, "center")
            end
        end
        love.graphics.setFont(previousOddsFont)
        local slotButton = self:slotButtonState()
        local returnBandHeight = returnControls.bottom - returnControls.top
        local returnLabelY = returnControls.top + math.floor((returnBandHeight - 10) / 2)
        if slotButton.enabled then
            love.graphics.setColor(0.25, 0.55, 0.8, 0.6)
        else
            love.graphics.setColor(0.18, 0.2, 0.25, 0.75)
        end
        love.graphics.rectangle("fill", 60, returnControls.top, 60, returnBandHeight)
        self.smallFont = self.smallFont or fonts.get(8)
        local previousReturnButtonFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        if slotButton.enabled then
            love.graphics.setColor(0.85, 0.95, 1)
        else
            love.graphics.setColor(0.55, 0.58, 0.65)
        end
        love.graphics.printf(slotButton.compactLabel, 60, returnLabelY, 60, "center")
        love.graphics.setFont(previousReturnButtonFont)
        self:drawJoystickStick()
    end
    love.graphics.setColor(0.85, 0.9, 1)
    local messageY = (self.expedition.phase == "settlement" or self.expedition.phase == "destroyed") and 50 or viewport.height - 30
    love.graphics.printf(self.message, 4, messageY, viewport.width - 8, "center")
    if self.newSpecimenBanner then
        local alpha = math.min(1, self.newSpecimenBannerTimer / 0.4)
        love.graphics.setColor(0.05, 0.06, 0.12, 0.85 * alpha)
        love.graphics.rectangle("fill", 12, 60, viewport.width - 24, 16)
        love.graphics.setColor(1, 0.85, 0.3, alpha)
        love.graphics.printf(self.newSpecimenBanner, 12, 64, viewport.width - 24, "center")
    end
    love.graphics.setColor(1, 0.65, 0.2, 0.85)
    love.graphics.printf(i18n.t("dev_placeholder"), 4, viewport.height - 13, viewport.width - 8, "center")
end

return M
