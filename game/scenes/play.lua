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
-- by the same joystick's Y component so a player can dodge/collect in any
-- direction around the auto-advancing flight line. Slice 2 (은하계 기반
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

-- Returning-phase LEFT/RIGHT touch band. Was a 24px-tall row
-- (254-278), which only clears ~24pt at the smallest supported window
-- (integer scale 1, 1x device pixel ratio) -- well under the iOS/Android
-- ~44pt accessibility minimum PlayScene.settlementTouchRows was already
-- fixed to meet (see game/self_test.lua's canvasPixelsToPoints check).
-- Widened to a 44 canvas px band (244-288).
local returnControls = {
    top = 244,
    bottom = 288,
    leftMaxX = 55,
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
-- YIELD and SHIP
-- share one 44px-tall row, split left/right at x=90 (each half is 90
-- canvas px wide, far past the 44pt accessibility minimum on the width
-- axis too), keeping all four rows at the full 44 canvas px band height.
-- STEERING is the fourth GAME_DESIGN.md meta upgrade axis (see
-- game/self_test.lua's steeringRun scenario); it reuses the same
-- column-split pattern by sharing the HULL row (left=HULL, right=STEERING)
-- instead of adding a fifth 36px-tall row that would fall back under the
-- 44pt accessibility minimum.
-- Item 15(b): EARTH SLOT SPIN row added above RELAUNCH. The former full-height
-- relaunch zone (232-320 = 88px) is split into two 44px rows: SLOT at 232-276
-- and RELAUNCH at 276-320, both still clearing the 44pt minimum.
local settlementTouchRows = {
    {
        top = 144, bottom = 188,
        columns = {
            { key = "hull", left = 0, right = 90 },
            { key = "steering", left = 90, right = 180 },
        },
    },
    {
        top = 188, bottom = 232,
        columns = {
            { key = "yield", left = 0, right = 90 },
            { key = "ship", left = 90, right = 180 },
        },
    },
    { key = "slot", top = 232, bottom = 276 },
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

-- docs/feedback/INBOX.md UI/HUD item 4: the "LAUNCH LOADOUT"/"발사 장비"
-- panel caption itself was flagged for removal during the "remove
-- unnecessary text" review -- the card's own contents (hull/upgrades/
-- steering/odds numbers) are self-explanatory once shown inside
-- an obviously bordered box directly under the Earth disc, so the extra
-- caption line was pure redundant text eating a row of vertical space.
-- Kept as a named flag (rather than deleting the printf outright) so a
-- future cycle can re-enable it cheaply if real-device feedback disagrees.
M.showLaunchLoadoutTitle = false

-- docs/feedback/INBOX.md UI/HUD item 3 (아이콘 기반 HUD 간소화, first slice):
-- the launch phase's "TAP TO LAUNCH"/"탭하여 발사" action was a bare text
-- line with no visual affordance beyond the words themselves. Drawing a
-- small upward-pointing rocket silhouette directly above the message
-- gives the tap target an icon+short-text pairing (the pattern the
-- feedback asked for hull/cash/speed too, to follow in later slices)
-- without needing any AetherAI-gated final art -- this is DEV PLACEHOLDER
-- Lua-shape geometry, not a final visual asset.
--
-- Pure function (no love.graphics calls) so game/self_test.lua can verify
-- the point geometry deterministically headless; draw() feeds the
-- returned flat {x1,y1,x2,y2,...} list straight into love.graphics.polygon.
function M.rocketIconPoints(cx, cy, size)
    local halfWidth = size * 0.35
    local noseY = cy - size * 0.6
    local baseY = cy + size * 0.4
    local finY = cy + size * 0.6
    local finSpread = size * 0.55
    return {
        cx, noseY,
        cx + halfWidth, baseY,
        cx + finSpread, finY,
        cx, baseY,
        cx - finSpread, finY,
        cx - halfWidth, baseY,
    }
end

-- Icon diameter and the vertical gap between the icon's center and the
-- message text's top edge, both in internal-canvas pixels.
M.launchIconSize = 14
M.launchIconGap = 12

-- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
-- second slice): pair the hull-durability readout (the "H%d/%d" segment of
-- hud.status) with a small shield silhouette so durability reads as an
-- icon+number at a glance instead of a bare letter prefix. Pure function
-- (no love.graphics calls) so self_test can verify the geometry headless:
-- a pentagon-ish shield outline (flat top, pointed bottom) that is
-- horizontally symmetric around cx and spans above and below cy.
function M.shieldIconPoints(cx, cy, size)
    local halfWidth = size * 0.45
    local topY = cy - size * 0.5
    local midY = cy
    local pointY = cy + size * 0.5
    return {
        cx - halfWidth, topY,
        cx + halfWidth, topY,
        cx + halfWidth, midY,
        cx, pointY,
        cx - halfWidth, midY,
    }
end

-- Diameter of the shield icon and the horizontal gap between the icon's
-- right edge and the status text's left edge, both in internal-canvas
-- pixels. The status text draw x shifts right by this much whenever the
-- icon is drawn so the icon never overlaps the "H%d/%d ..." text.
M.hullIconSize = 8
M.hullIconGap = 4

-- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
-- third slice): a small coin icon paired with the CASH readout, mirroring
-- shieldIconPoints/rocketIconPoints. Drawn as a flat octagon silhouette
-- (rather than love.graphics.circle, whose segment count is implicit and
-- not something a headless test can pin down exactly) so its geometry can
-- be regression tested the same way as the other icons: even-length flat
-- {x,y,...} list, horizontally symmetric around cx, spans above and below
-- cy.
function M.coinIconPoints(cx, cy, size)
    local r = size * 0.5
    local rDiag = r * 0.7071
    return {
        cx, cy - r,
        cx + rDiag, cy - rDiag,
        cx + r, cy,
        cx + rDiag, cy + rDiag,
        cx, cy + r,
        cx - rDiag, cy + rDiag,
        cx - r, cy,
        cx - rDiag, cy - rDiag,
    }
end

-- Icon footprint (px) + gap (px) reserved between the coin icon's right
-- edge and the CASH text's left edge, mirroring M.hullIconSize/hullIconGap.
M.cashIconSize = 8
M.cashIconGap = 4

-- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
-- final slice): a small speedometer-like gauge icon paired with the steering
-- speed readout. Drawn as a half-circle base polygon with a negative-space
-- needle cut out from the bottom.
function M.speedIconPoints(cx, cy, size)
    local r = size * 0.5
    local rDiag = r * 0.7071
    return {
        cx - r, cy,
        cx - rDiag, cy - rDiag,
        cx, cy - r,
        cx + rDiag, cy - rDiag,
        cx + r, cy,
        cx + r * 0.2, cy,
        cx + r * 0.5, cy - r * 0.5,
        cx - r * 0.2, cy,
    }
end

M.speedIconSize = 8
M.speedIconGap = 4

function M.drawCenteredIconText(iconPointsFn, iconSize, iconGap, text, x, y, w)
    local font = love.graphics.getFont()
    local textWidth = font:getWidth(text)
    local totalWidth = iconSize + iconGap + textWidth
    local startX = x + w / 2 - totalWidth / 2
    local iconCenterX = startX + iconSize / 2
    local iconCenterY = y + font:getHeight() / 2
    
    love.graphics.polygon("fill", iconPointsFn(iconCenterX, iconCenterY, iconSize))
    love.graphics.print(text, startX + iconSize + iconGap, y)
end

-- Draw a HUD sprite icon at (cx, cy) scaled to fit `size` px.
-- If image is nil, falls back to drawing the polygon produced by pointsFn.
-- Call with the icon color already set.
local function drawHudSpriteOrPoly(image, pointsFn, cx, cy, size)
    if image then
        local iw, ih = image:getDimensions()
        local scale = size / math.max(iw, ih)
        love.graphics.draw(image, cx - iw * scale / 2, cy - ih * scale / 2, 0, scale, scale)
    elseif pointsFn then
        love.graphics.polygon("fill", pointsFn(cx, cy, size))
    end
end
M.drawHudSpriteOrPoly = drawHudSpriteOrPoly

-- Draw a minimap sprite icon centered on (cx, cy), scaled so its largest
-- dimension matches targetDiameter. If image is nil, no fallback is needed
-- here -- the caller keeps the original polygon draw.
local function drawMinimapSprite(image, cx, cy, targetDiameter)
    if not image then return false end
    local iw, ih = image:getDimensions()
    local scale = targetDiameter / math.max(iw, ih)
    love.graphics.draw(image, cx - iw * scale / 2, cy - ih * scale / 2, 0, scale, scale)
    return true
end
M.drawMinimapSprite = drawMinimapSprite

-- Draw a planet-effect overlay sprite centered on (cx, cy), scaled so its
-- largest dimension matches diameter. tint (r,g,b,a) is applied before draw.
-- Returns true if the image was drawn, false if image is nil (caller keeps
-- original polygon fallback).
local function drawPlanetEffectSprite(image, cx, cy, diameter, r, g, b, a)
    if not image then return false end
    local iw, ih = image:getDimensions()
    local scale = diameter / math.max(iw, ih)
    love.graphics.setColor(r or 1, g or 1, b or 1, a or 1)
    love.graphics.draw(image, cx - iw * scale / 2, cy - ih * scale / 2, 0, scale, scale)
    return true
end
M.drawPlanetEffectSprite = drawPlanetEffectSprite

-- Draw a floating-text icon sprite to the left of a floating text label.
-- image: the icon (may be nil -> no icon drawn). cx, cy: center of the icon.
-- size: target pixel size of the icon. alpha: overall opacity 0-1.
-- Returns true if drawn, false if image is nil.
local function drawFloatingIconSprite(image, cx, cy, size, alpha)
    if not image then return false end
    local iw, ih = image:getDimensions()
    local scale = size / math.max(iw, ih)
    love.graphics.draw(image, cx - iw * scale / 2, cy - ih * scale / 2, 0, scale, scale)
    return true
end
M.drawFloatingIconSprite = drawFloatingIconSprite

-- Draw a panel/overlay sprite at native pixel size (never stretch to fill
-- dest w/h). Stretching 64x64 RGB panels to viewport.width (720) is what
-- turned launch into a full-bleed red/cyan blur (INBOX 2026-09-04 regen
-- item 0). image may be nil -> caller draws its original rectangle.
-- w, h stay in the signature for callers / a later 9-slice or tile path.
-- Returns true if drawn, false if image is nil.
local function drawPanelSprite(image, x, y, _w, _h)
    if not image then return false end
    love.graphics.draw(image, x, y)
    return true
end
M.drawPanelSprite = drawPanelSprite

-- Draw a shop-icon sprite centered at (cx, cy), scaled to `size` px.
-- Used to place a small icon badge to the left of a shop row's text.
-- Returns true if drawn, false if image is nil (caller keeps the text-only row).
local function drawShopIconSprite(image, cx, cy, size)
    if not image then return false end
    local iw, ih = image:getDimensions()
    local scale = size / math.max(iw, ih)
    love.graphics.draw(image, cx - iw * scale / 2, cy - ih * scale / 2, 0, scale, scale)
    return true
end
M.drawShopIconSprite = drawShopIconSprite

-- Draw a star-point sprite centered at (x, y), scaled to `size` px.
-- Used instead of love.graphics.points for background/foreground stars.
-- Returns true if drawn, false if image is nil (caller keeps love.graphics.points).
local function drawStarPointSprite(image, x, y, size)
    if not image then return false end
    local iw, ih = image:getDimensions()
    local scale = size / math.max(iw, ih)
    love.graphics.draw(image, x - iw * scale / 2, y - ih * scale / 2, 0, scale, scale)
    return true
end
M.drawStarPointSprite = drawStarPointSprite

-- Draw a PixelPlanets sprite frame centered at (x,y), scaled so the frame
-- appears `size` pixels wide.  frameIdx is 0-based.
-- Returns true if drawn, false if image is nil (caller falls back to rectangle).
local function drawPixelStar(image, x, y, frameW, frameH, frameCount, frameIdx, size, r, g, b, a)
    if not image then return false end
    local iw, ih = image:getDimensions()
    local fi = frameIdx % frameCount
    local quad = love.graphics.newQuad(fi * frameW, 0, frameW, frameH, iw, ih)
    local scale = size / math.max(frameW, frameH)
    love.graphics.setColor(r, g, b, a)
    love.graphics.draw(image, quad,
        x - frameW * scale / 2,
        y - frameH * scale / 2,
        0, scale, scale)
    return true
end
M.drawPixelStar = drawPixelStar

-- "고도(ALT)" mislabeling fix (docs/feedback/INBOX.md item 2, 2026-09-03):
-- hud_primary is relabeled ALT->DIST ("고도"->"거리") below. This gap keeps
-- the primary distance/cash row visually separate from secondary status.
M.hudPrimaryStatusGap = 6

-- docs/feedback/INBOX.md UI/HUD item 5: the returning-phase slot-odds line
-- (C%/P%/S%/AVG$ above the minimap) was removed when item-15(a) abolished
-- in-flight slots. The hudOddsLineHeight that used to reserve 10px for it is
-- no longer needed; the returning HUD band height is now 70 + hudPrimaryStatusGap
-- (same as the ascending phase with returnProgress showing).
-- Constant kept as a zero-read alias for any call site that referenced it,
-- so old assertions that check "hudOddsLineHeight > 0" will need updating to
-- reflect item-15(a). See self_test.lua item-15(a) follow-up assertion.
M.hudOddsLineHeight = 0

-- docs/feedback/INBOX.md UI/HUD item 4: the "개발 임시본"/"DEV PLACEHOLDER"
-- footer text is a permanent dev-only disclaimer (kept until real AetherAI
-- assets land), not gameplay information, so it should read as a quiet
-- watermark instead of competing with the message line above it. Smaller
-- font + lower alpha than the default text keeps it legible but visually
-- de-emphasized.
M.devPlaceholderFontSize = 7
M.devPlaceholderAlpha = 0.4

-- Shared HUD background-box height so the minimap placement (drawMinimap)
-- and the actual text draw (draw) never disagree about how tall the top
-- HUD band is.
function M.hudHeight(phase, hud, galaxyShift)
    if phase == "launch" then
        return M.launchHudHeight + galaxyShift
    end
    if hud.returnProgress then
        return 70 + M.hudPrimaryStatusGap + galaxyShift
    end
    if hud.samples then
        return 46 + M.hudPrimaryStatusGap + galaxyShift
    end
    if hud.best then
        return 46 + galaxyShift
    end
    return 34 + galaxyShift
end

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

-- EARTH SHOP action/status two-column layout for the hull/steering/
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
-- full-width preview lines below each shared row are left
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


-- PNG IHDR color type (byte 26): 2 = RGB (opaque square blobs), 6 = RGBA.
-- INBOX 2026-09-05 item (1): RGB ComfyUI PNGs stay on disk but must not
-- load; draw helpers already fall back to Lua polygons when image is nil.
local function pngColorType(path)
    if type(path) ~= "string" or path == "" then
        return nil
    end
    local data
    if love.filesystem and love.filesystem.read then
        local ok, contents = pcall(love.filesystem.read, path)
        if ok then
            data = contents
        end
    end
    if not data then
        local handle = io.open(path, "rb")
        if not handle then
            return nil
        end
        data = handle:read(33)
        handle:close()
    end
    if type(data) ~= "string" or #data < 26 then
        return nil
    end
    if data:sub(1, 8) ~= "\137PNG\r\n\26\n" then
        return nil
    end
    return data:byte(26)
end

local function shouldLoadRuntimeSprite(path)
    return pngColorType(path) == 6
end

local function loadSprite(path)
    if not shouldLoadRuntimeSprite(path) then
        return nil
    end
    if not (love.graphics and love.graphics.newImage) then
        return nil
    end
    local ok, img = pcall(love.graphics.newImage, path)
    if ok and img then
        img:setFilter("nearest", "nearest")
        return img
    end
    return nil
end
M.pngColorType = pngColorType
M.shouldLoadRuntimeSprite = shouldLoadRuntimeSprite
M.loadSprite = loadSprite

local function loadSpriteMap(paths)
    local images = {}
    for key, path in pairs(paths) do
        images[key] = loadSprite(path)
    end
    return images
end

function M.new(options)
    options = options or {}
    local ship = shipModule.new()
    local altitudeStore = options.bestAltitudeStore or bestAltitudeStore.new()
    local specimenStore = options.collectionStore or collectionStore.new()
    if love.graphics then
        love.graphics.setFont(fonts.get(14))
    end

    local shipImagePath = "assets/ship/ship_default.png"
    local planetImagePath = "assets/planet/planet_generic.png"
    local earthImagePath = "assets/earth/earth_generic.png"
    local backgroundImagePath = "assets/backgrounds/deep_space_tile.png"
    local sampleEffectImagePath = "assets/effects/sample_sparkle.png"
    local collisionEffectImagePath = "assets/effects/collision_spark.png"
    local thrustEffectImagePath = "assets/effects/thrust_plume.png"
    local hubPlanetImagePath = "assets/planet/planet_hub.png"
    local shopPlanetImagePath = "assets/planet/planet_shop.png"
    local scoutShipImagePath = "assets/ship/ship_scout.png"
    local shipSilhouetteImagePath = "assets/effects/ship_silhouette.png"
    local slotSymbolImagePaths = {
        COMET = "assets/slot_symbols/comet.png",
        PLANET = "assets/slot_symbols/planet.png",
        STAR = "assets/slot_symbols/star.png",
    }
    local shopIconImagePaths = {
        hull = "assets/shop_icons/hull.png",
        steering = "assets/shop_icons/steering.png",
        yield = "assets/shop_icons/yield.png",
        ship = "assets/shop_icons/ship.png",
    }
    local debrisImagePaths = {
        asteroid = "assets/debris/asteroid.png",
        can = "assets/debris/can.png",
        scrap = "assets/debris/scrap.png",
    }
    -- Floating text icon images (group 4 of ComfyUI asset wiring)
    local floatingSampleIconImagePath = "assets/effects/floating_sample.png"
    local floatingDamageIconImagePath = "assets/effects/floating_damage.png"
    local messageBannerIconImagePath   = "assets/effects/message_banner.png"
    -- Panel/overlay images (group 5 of ComfyUI asset wiring)
    local launchRocketIconImagePath   = "assets/effects/launch_rocket.png"
    local loadoutPanelImagePath       = "assets/effects/loadout_panel.png"
    local loadoutShipImagePath        = "assets/effects/loadout_ship.png"
    local settlementPanelImagePath    = "assets/effects/settlement_summary_panel.png"
    local destroyedPanelImagePath     = "assets/effects/destroyed_panel.png"
    local relaunChImagePath           = "assets/effects/relaunch.png"
    local slotResultPanelImagePath    = "assets/effects/slot_result_panel.png"
    local slotSpinButtonImagePath     = "assets/effects/slot_spin_button.png"
    -- Group 6 of ComfyUI asset wiring: joystick, specimen banner, star point
    local joystickPadImagePath     = "assets/effects/joystick_pad.png"
    local joystickKnobImagePath    = "assets/effects/joystick_knob.png"
    local specimenBannerImagePath  = "assets/effects/specimen_banner.png"
    local starPointImagePath       = "assets/effects/star_point.png"
    -- Group 7 of ComfyUI asset wiring: destroyed-phase row icons
    local destroyedTitleIconImagePath              = "assets/effects/destroyed_title.png"
    local destroyedLostTotalIconImagePath          = "assets/effects/destroyed_lost_total.png"
    local destroyedSamplesSettlementIconImagePath  = "assets/effects/destroyed_samples_settlement.png"
    local destroyedSpinsSettlementIconImagePath    = "assets/effects/destroyed_spins_settlement.png"
    local destroyedPeakDistIconImagePath           = "assets/effects/destroyed_peak_dist.png"
    local destroyedNewBestIconImagePath            = "assets/effects/destroyed_new_best.png"
    local destroyedMetaResetIconImagePath          = "assets/effects/destroyed_meta_reset.png"
    local destroyedNextShipIconImagePath           = "assets/effects/destroyed_next_ship.png"
    local destroyedTapStartOverIconImagePath       = "assets/effects/destroyed_tap_start_over.png"
    local shipImage = loadSprite(shipImagePath)
    local planetImage = loadSprite(planetImagePath)
    local earthImage = loadSprite(earthImagePath)
    local backgroundImage = loadSprite(backgroundImagePath)
    if backgroundImage then
        pcall(backgroundImage.setWrap, backgroundImage, "repeat", "repeat")
    end
    local sampleEffectImage = loadSprite(sampleEffectImagePath)
    local collisionEffectImage = loadSprite(collisionEffectImagePath)
    local thrustEffectImage = loadSprite(thrustEffectImagePath)
    local hubPlanetImage = loadSprite(hubPlanetImagePath)
    local shopPlanetImage = loadSprite(shopPlanetImagePath)
    local scoutShipImage = loadSprite(scoutShipImagePath)
    local shipSilhouetteImage = loadSprite(shipSilhouetteImagePath)
    local slotSymbolImages = loadSpriteMap(slotSymbolImagePaths)
    local shopIconImages = loadSpriteMap(shopIconImagePaths)
    local debrisImages = loadSpriteMap(debrisImagePaths)
    -- Floating text icon images (group 4 of ComfyUI asset wiring)
    local floatingSampleIconImage = loadSprite(floatingSampleIconImagePath)
    local floatingDamageIconImage = loadSprite(floatingDamageIconImagePath)
    local messageBannerIconImage  = loadSprite(messageBannerIconImagePath)
    -- Panel/overlay images (group 5 of ComfyUI asset wiring)
    local launchRocketIconImage   = loadSprite(launchRocketIconImagePath)
    local loadoutPanelImage       = loadSprite(loadoutPanelImagePath)
    local loadoutShipImage        = loadSprite(loadoutShipImagePath)
    local settlementPanelImage    = loadSprite(settlementPanelImagePath)
    local destroyedPanelImage     = loadSprite(destroyedPanelImagePath)
    local relaunChImage           = loadSprite(relaunChImagePath)
    local slotResultPanelImage    = loadSprite(slotResultPanelImagePath)
    local slotSpinButtonImage     = loadSprite(slotSpinButtonImagePath)
    -- Group 6 of ComfyUI asset wiring: joystick, specimen banner, star point
    local joystickPadImage    = loadSprite(joystickPadImagePath)
    local joystickKnobImage   = loadSprite(joystickKnobImagePath)
    local specimenBannerImage = loadSprite(specimenBannerImagePath)
    local starPointImage      = loadSprite(starPointImagePath)
    -- PixelPlanets pixel-art star sprites (INBOX 2026-09-05)
    local pixelStarsImage        = loadSprite("assets/space/pixelplanets_stars.png")
    local pixelStarsSpecialImage = loadSprite("assets/space/pixelplanets_stars_special.png")
    -- Group 7 of ComfyUI asset wiring: destroyed-phase row icons
    local destroyedTitleIconImage             = loadSprite(destroyedTitleIconImagePath)
    local destroyedLostTotalIconImage         = loadSprite(destroyedLostTotalIconImagePath)
    local destroyedSamplesSettlementIconImage = loadSprite(destroyedSamplesSettlementIconImagePath)
    local destroyedSpinsSettlementIconImage   = loadSprite(destroyedSpinsSettlementIconImagePath)
    local destroyedPeakDistIconImage          = loadSprite(destroyedPeakDistIconImagePath)
    local destroyedNewBestIconImage           = loadSprite(destroyedNewBestIconImagePath)
    local destroyedMetaResetIconImage         = loadSprite(destroyedMetaResetIconImagePath)
    local destroyedNextShipIconImage          = loadSprite(destroyedNextShipIconImagePath)
    local destroyedTapStartOverIconImage      = loadSprite(destroyedTapStartOverIconImagePath)
    -- Minimap marker images (group 2 of ComfyUI asset wiring)
    local minimapImages = loadSpriteMap({
        disc           = "assets/effects/minimap_disc.png",
        player         = "assets/effects/minimap_player.png",
        sun            = "assets/effects/minimap_sun.png",
        earth          = "assets/effects/minimap_earth.png",
        earthReturn    = "assets/effects/minimap_earth_return.png",
        galaxyHome     = "assets/effects/minimap_galaxy_home.png",
        galaxyPlain    = "assets/effects/minimap_galaxy_plain.png",
        checkpointStar = "assets/effects/minimap_checkpoint_star.png",
        checkpointArrow= "assets/effects/minimap_checkpoint_arrow.png",
        spiralStar     = "assets/effects/minimap_spiral_star.png",
        orbitRing      = "assets/effects/minimap_orbit_ring.png",
        galaxyRing     = "assets/effects/minimap_galaxy_ring.png",
    })
    -- HUD icon images (group 1 of ComfyUI asset wiring)
    local hudIconImages = loadSpriteMap({
        cash     = "assets/effects/hud_coin.png",
        hull     = "assets/effects/hud_shield.png",
        speed    = "assets/effects/hud_speed.png",
        distance = "assets/effects/hud_distance.png",
        best     = "assets/effects/hud_best.png",
        samples  = "assets/effects/hud_samples.png",
        galaxy   = "assets/effects/hud_galaxy.png",
        returnIc = "assets/effects/hud_return.png",
        earth    = "assets/effects/hud_earth.png",
    })
    -- Planet effect images (group 3 of ComfyUI asset wiring)
    local planetEffectImages = loadSpriteMap({
        glow        = "assets/effects/planet_glow.png",
        shadow      = "assets/effects/planet_shadow.png",
        rim         = "assets/effects/planet_rim.png",
        twinkle     = "assets/effects/planet_twinkle.png",
        sampleValue = "assets/effects/planet_sample.png",
        risk        = "assets/effects/planet_risk.png",
    })
    -- Shop/HUD panel images (group 8 of ComfyUI asset wiring): settlement shop
    -- row icons and HUD background panel.
    local shopEffectImages = loadSpriteMap({
        hudPanel        = "assets/effects/hud_panel.png",
        shopPanel       = "assets/effects/shop_panel.png",
        shopTitle       = "assets/effects/shop_title.png",
        shopTouchRow    = "assets/effects/shop_touch_row.png",
        shopStats       = "assets/effects/shop_stats.png",
        shopNextShip    = "assets/effects/shop_next_ship.png",
        hullAction      = "assets/effects/shop_hull_action.png",
        steeringAction  = "assets/effects/shop_steering_action.png",
        yieldAction     = "assets/effects/shop_yield_action.png",
        shipAction      = "assets/effects/shop_ship_action.png",
        hullStatus      = "assets/effects/shop_hull_status.png",
        steeringStatus  = "assets/effects/shop_steering_status.png",
        yieldStatus     = "assets/effects/shop_yield_status.png",
        shipStatus      = "assets/effects/shop_ship_status.png",
        hullPreview     = "assets/effects/shop_hull_preview.png",
        steeringPreview = "assets/effects/shop_steering_preview.png",
        yieldPreview    = "assets/effects/shop_yield_preview.png",
        shipPreview     = "assets/effects/shop_ship_preview.png",
    })

    return setmetatable({
        ship = ship,
        shipImage = shipImage,
        shipImagePath = shipImagePath,
        planetImage = planetImage,
        planetImagePath = planetImagePath,
        earthImage = earthImage,
        earthImagePath = earthImagePath,
        backgroundImage = backgroundImage,
        backgroundImagePath = backgroundImagePath,
        sampleEffectImage = sampleEffectImage,
        sampleEffectImagePath = sampleEffectImagePath,
        collisionEffectImage = collisionEffectImage,
        collisionEffectImagePath = collisionEffectImagePath,
        thrustEffectImage = thrustEffectImage,
        thrustEffectImagePath = thrustEffectImagePath,
        hubPlanetImage = hubPlanetImage,
        hubPlanetImagePath = hubPlanetImagePath,
        shopPlanetImage = shopPlanetImage,
        shopPlanetImagePath = shopPlanetImagePath,
        scoutShipImage = scoutShipImage,
        scoutShipImagePath = scoutShipImagePath,
        shipSilhouetteImage = shipSilhouetteImage,
        shipSilhouetteImagePath = shipSilhouetteImagePath,
        slotSymbolImages = slotSymbolImages,
        slotSymbolImagePaths = slotSymbolImagePaths,
        shopIconImages = shopIconImages,
        shopIconImagePaths = shopIconImagePaths,
        debrisImages = debrisImages,
        debrisImagePaths = debrisImagePaths,
        hudIconImages = hudIconImages,
        minimapImages = minimapImages,
        planetEffectImages = planetEffectImages,
        -- Shop/HUD panel images (group 8 of ComfyUI asset wiring)
        shopEffectImages = shopEffectImages,
        -- Floating text icon images (group 4 of ComfyUI asset wiring)
        floatingSampleIconImage = floatingSampleIconImage,
        floatingSampleIconImagePath = floatingSampleIconImagePath,
        floatingDamageIconImage = floatingDamageIconImage,
        floatingDamageIconImagePath = floatingDamageIconImagePath,
        messageBannerIconImage = messageBannerIconImage,
        messageBannerIconImagePath = messageBannerIconImagePath,
        -- Panel/overlay images (group 5 of ComfyUI asset wiring)
        launchRocketIconImage = launchRocketIconImage,
        launchRocketIconImagePath = launchRocketIconImagePath,
        loadoutPanelImage = loadoutPanelImage,
        loadoutPanelImagePath = loadoutPanelImagePath,
        loadoutShipImage = loadoutShipImage,
        loadoutShipImagePath = loadoutShipImagePath,
        settlementPanelImage = settlementPanelImage,
        settlementPanelImagePath = settlementPanelImagePath,
        destroyedPanelImage = destroyedPanelImage,
        destroyedPanelImagePath = destroyedPanelImagePath,
        relaunChImage = relaunChImage,
        relaunChImagePath = relaunChImagePath,
        slotResultPanelImage = slotResultPanelImage,
        slotResultPanelImagePath = slotResultPanelImagePath,
        slotSpinButtonImage = slotSpinButtonImage,
        slotSpinButtonImagePath = slotSpinButtonImagePath,
        -- Group 6 of ComfyUI asset wiring: joystick, specimen banner, star point
        joystickPadImage = joystickPadImage,
        joystickPadImagePath = joystickPadImagePath,
        joystickKnobImage = joystickKnobImage,
        joystickKnobImagePath = joystickKnobImagePath,
        specimenBannerImage = specimenBannerImage,
        specimenBannerImagePath = specimenBannerImagePath,
        starPointImage = starPointImage,
        starPointImagePath = starPointImagePath,
        -- PixelPlanets pixel-art star sprites (INBOX 2026-09-05)
        pixelStarsImage = pixelStarsImage,
        pixelStarsSpecialImage = pixelStarsSpecialImage,
        -- Group 7 of ComfyUI asset wiring: destroyed-phase row icons
        destroyedTitleIconImage             = destroyedTitleIconImage,
        destroyedTitleIconImagePath         = destroyedTitleIconImagePath,
        destroyedLostTotalIconImage         = destroyedLostTotalIconImage,
        destroyedLostTotalIconImagePath     = destroyedLostTotalIconImagePath,
        destroyedSamplesSettlementIconImage = destroyedSamplesSettlementIconImage,
        destroyedSamplesSettlementIconImagePath = destroyedSamplesSettlementIconImagePath,
        destroyedSpinsSettlementIconImage   = destroyedSpinsSettlementIconImage,
        destroyedSpinsSettlementIconImagePath = destroyedSpinsSettlementIconImagePath,
        destroyedPeakDistIconImage          = destroyedPeakDistIconImage,
        destroyedPeakDistIconImagePath      = destroyedPeakDistIconImagePath,
        destroyedNewBestIconImage           = destroyedNewBestIconImage,
        destroyedNewBestIconImagePath       = destroyedNewBestIconImagePath,
        destroyedMetaResetIconImage         = destroyedMetaResetIconImage,
        destroyedMetaResetIconImagePath     = destroyedMetaResetIconImagePath,
        destroyedNextShipIconImage          = destroyedNextShipIconImage,
        destroyedNextShipIconImagePath      = destroyedNextShipIconImagePath,
        destroyedTapStartOverIconImage      = destroyedTapStartOverIconImage,
        destroyedTapStartOverIconImagePath  = destroyedTapStartOverIconImagePath,
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
        touches = {},
        verticalOffset = 0,
        rcsCooldown = 0,
        message = i18n.t("launch_tap_to_launch"),
        -- Item 15(b): Earth shop slot state. Holds the last earthSlotSpin
        -- result during the settlement phase so draw() can render it.
        earthShopSlotResult = nil,
        -- Item 7(c): Earth shop gear offer. Rolled once on settlement entry;
        -- cleared on purchase or relaunch.
        earthShopGearOffer = nil,
    }, M)
end

-- Item 15(c): earthSlotSpin returns rewardProfile as a plain string
-- ("solar"/"fringe"/"void"), not a table. Format it as an uppercase
-- "SOLAR ODDS" badge for the Earth shop slot UI. Returns nil when there
-- is no profile so draw() can skip the badge without a `.name` lookup
-- that would always be nil on a string.
function M.earthSlotProfileLabel(rewardProfile)
    if type(rewardProfile) ~= "string" or rewardProfile == "" then
        return nil
    end
    return string.upper(rewardProfile) .. " ODDS"
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

-- Draws equipped gear slots (Item 6): up to 6 hull parts and 3 engine parts
-- displayed as Balatro-style card icons in the launch screen, replacing the
-- old specimen log.
function M:drawGearSlots(y)
    local hullSlots = 6
    local engineSlots = 3
    local boxW = 10
    local boxH = 14
    local gap = 3
    local groupGap = 8
    
    local run = self.expedition
    local hullGear = run.equippedGear or {}
    local engineGear = run.equippedEngineParts or {}

    local totalWidth = (hullSlots * boxW + (hullSlots - 1) * gap) + groupGap + (engineSlots * boxW + (engineSlots - 1) * gap)
    local startX = math.floor((viewport.width - totalWidth) / 2)
    
    self.tinyFont = self.tinyFont or fonts.get(7)
    local previousFont = love.graphics.getFont()
    love.graphics.setFont(self.tinyFont)
    
    for i = 1, hullSlots do
        local x = startX + (i - 1) * (boxW + gap)
        local part = hullGear[i]
        if part then
            if part.rarity == "legendary" then love.graphics.setColor(1, 0.6, 0)
            elseif part.rarity == "rare" then love.graphics.setColor(0.3, 0.6, 1)
            elseif part.rarity == "uncommon" then love.graphics.setColor(0.4, 0.8, 0.4)
            else love.graphics.setColor(0.7, 0.7, 0.7) end
            love.graphics.rectangle("fill", x, y, boxW, boxH)
            
            love.graphics.setColor(1, 1, 1, 0.5)
            local pts = M.shieldIconPoints(x + boxW/2, y + boxH/2, 4)
            if pts then love.graphics.polygon("fill", pts) end
            
            if part.edition and part.edition ~= "base" then
                love.graphics.setColor(1, 1, 0.5, 0.8)
                love.graphics.rectangle("line", x-1, y-1, boxW+2, boxH+2)
            else
                love.graphics.setColor(0.1, 0.1, 0.1, 1)
                love.graphics.rectangle("line", x, y, boxW, boxH)
            end
        else
            love.graphics.setColor(0.3, 0.35, 0.45, 0.6)
            love.graphics.rectangle("line", x, y, boxW, boxH)
        end
    end
    
    local engineStartX = startX + (hullSlots * boxW + (hullSlots - 1) * gap) + groupGap
    
    for i = 1, engineSlots do
        local x = engineStartX + (i - 1) * (boxW + gap)
        local part = engineGear[i]
        if part then
            if part.rarity == "legendary" then love.graphics.setColor(1, 0.6, 0)
            elseif part.rarity == "rare" then love.graphics.setColor(0.3, 0.6, 1)
            elseif part.rarity == "uncommon" then love.graphics.setColor(0.4, 0.8, 0.4)
            else love.graphics.setColor(0.7, 0.7, 0.7) end
            love.graphics.rectangle("fill", x, y, boxW, boxH)
            
            love.graphics.setColor(1, 1, 1, 0.5)
            local pts = M.rocketIconPoints(x + boxW/2, y + boxH/2, 4)
            if pts then love.graphics.polygon("fill", pts) end
            
            if part.edition and part.edition ~= "base" then
                love.graphics.setColor(1, 1, 0.5, 0.8)
                love.graphics.rectangle("line", x-1, y-1, boxW+2, boxH+2)
            else
                love.graphics.setColor(0.1, 0.1, 0.1, 1)
                love.graphics.rectangle("line", x, y, boxW, boxH)
            end
        else
            love.graphics.setColor(0.45, 0.35, 0.3, 0.6)
            love.graphics.rectangle("line", x, y, boxW, boxH)
        end
    end
    
    love.graphics.setColor(0.6, 0.7, 0.8, 0.9)
    love.graphics.printf(i18n.t("equipped_gear_label"), 0, y - 10, viewport.width, "center")
    love.graphics.setFont(previousFont)
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
        distance = i18n.t("hud_distance", math.floor(run.altitude)),
        cash = i18n.t("hud_cash", run.money),
        samples = samples,
        best = best,
        earth = earth,
        returnProgress = returnProgress,
        -- docs/feedback/INBOX.md UI/HUD item 4: the launch phase's slot
        -- forecast (S%02d) is always 0 because no return trip has
        -- Item 11: both launch and non-launch phases now use the same
        -- hud_status_no_slots format — the S%02d slot segment was removed
        -- from hud_status since item-15 abolished in-flight slots and
        -- slotOpportunities is always 0 (dead/misleading UI).
        status = i18n.t("hud_status_no_slots", run.durability,
            run.maxDurability, i18n.phaseAbbrev(run.phase)),
        galaxy = (run.phase == "ascending" or run.phase == "returning" or run.phase == "launch")
            and (world.galaxyContaining(self.ship.x, self.ship.y) or {}).name
            or nil,
    }
end


function M:loadoutLines()
    local run = self.expedition
    return {
        -- docs/feedback/INBOX.md UI/HUD item 4: naming the current ship is
        -- meaningless dead text while STARTER is the only hull ever
        -- owned (there is no choice to announce). Only show the ship
        -- line once a second ship (scout) has actually been purchased,
        -- when "which ship is selected" becomes real information.
        ship = run.ownedShips.scout
            and i18n.t("loadout_ship", string.upper(run.selectedShipId))
            or nil,
        -- shipLabel is always present (used by the destroyed-screen
        -- "NEXT %s" line, which needs to name the fresh loadout even when
        -- it is the single default STARTER hull).
        shipLabel = string.upper(run.selectedShipId),
        stats = i18n.t("stats_line", run.maxDurability),
        upgrades = i18n.t("upgrades_line",
            run.durabilityUpgradeLevel),
        steering = i18n.t("steer_speed_line", expedition.steeringSpeed(run)),
    }
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
    local previewDurability = run.baseDurability
        + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
    if previewShipId == "scout" then
        previewDurability = previewDurability + run.scoutDurabilityBonus
    end
    local hullStatus, hullAffordable = purchaseStatus(run.money, run.durabilityUpgradeCost)
    local yieldStatus, yieldAffordable = purchaseStatus(run.money, run.sampleYieldUpgradeCost)
    local steeringStatus, steeringAffordable = purchaseStatus(run.money, run.steeringUpgradeCost)
    return {
        ship = i18n.t("next_ship_label", string.upper(run.selectedShipId)),
        stats = i18n.t("stats_line", run.maxDurability),
        upgrades = i18n.t("upgrades_line",
            run.durabilityUpgradeLevel),
        scoutTradeoff = self.scoutTradeoffLines(run),
        shipAction = shipAction,
        shipActionCompact = shipActionCompact,
        shipStatus = shipStatus,
        shipAffordable = shipAffordable,
        shipPreview = i18n.t("ship_preview_line",
            string.upper(previewShipId), previewDurability),
        shipPreviewCompact = i18n.t("ship_preview_compact",
            string.upper(previewShipId), previewDurability),
        hullAction = i18n.t("hull_action_line",
            run.durabilityUpgradeLevel, run.durabilityUpgradeLevel + 1,
            run.durabilityUpgradeCost),
        hullActionCompact = i18n.t("hull_action_compact",
            run.durabilityUpgradeLevel, run.durabilityUpgradeLevel + 1,
            run.durabilityUpgradeCost),
        hullPreview = i18n.t("stats_line",
            run.maxDurability + run.durabilityUpgradeAmount),
        hullPreviewCompact = i18n.t("hull_preview_compact",
            run.maxDurability + run.durabilityUpgradeAmount),
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
    }
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
    if self.shopModal then
        return
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
            -- Coast on stored velocity.
            self.ship.x = self.ship.x + (self.ship.vx or 0) * dt
            self.ship.y = self.ship.y + (self.ship.vy or 0) * dt
        else
            expedition.update(self.expedition, dt)
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
        -- Item 11/15(a): in-flight slot count removed from returning message.
        self.message = i18n.t("returning_message")
    elseif previousPhase ~= self.expedition.phase and self.expedition.phase == "settlement" then
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
            local earthPool = gearMod.earthShopPool(combined)
            local rolls = {
                rarity = math.random(),
                pick = math.random(),
                editionChance = math.random(),
                editionPick = math.random(),
            }
            self.earthShopGearOffer = expedition.rollGearOffer(self.expedition, earthPool, rolls)
        end
    end
    if self.expedition.phase == "ascending" or self.expedition.phase == "returning" then
        for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 1)) do
            local dx, dy = planet.x - self.ship.x, planet.y - self.ship.y
            local distanceSquared = dx * dx + dy * dy
            if self.expedition.phase == "ascending"
                and distanceSquared <= (planet.radius + 30) ^ 2
                and not self.discovered[planet.id] then
                self.discovered[planet.id] = true
                self.discoveredCount = self.discoveredCount + 1

                if planet.hub then
                    if self.expedition.pendingSampleValue > 0 then
                        local payout = expedition.settleAtHub(self.expedition)
                        if payout and payout > 0 then
                            table.insert(self.floatingTexts, {
                                text = i18n.t("floating_hub_settle", payout),
                                x = planet.x,
                                y = planet.y - 20,
                                timer = 3.0,
                                kind = "sample",
                                awarded = payout,
                                rollupElapsed = 0,
                            })
                        end
                    end
                    if not self.expedition.hubExplored[planet.galaxyId] then
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
                            expedition.equipGear(self.expedition, cat, drop)
                            table.insert(self.floatingTexts, {
                                text = i18n.t("floating_hub_gear", drop.name),
                                x = planet.x,
                                y = planet.y + 20,
                                timer = 3.0,
                                kind = "sample",
                                awarded = 0,
                                rollupElapsed = 0,
                            })
                        end
                    end
                elseif planet.isShop then
                    if not self.shopModal then
                        local gearMod = require("game.gear")
                        local pool = {}
                        local hull = gearMod.loadHullParts() or {}
                        local engine = gearMod.loadEngineParts() or {}
                        for _, p in ipairs(hull) do pool[#pool+1] = p end
                        for _, p in ipairs(engine) do pool[#pool+1] = p end

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
    if self.shopModal then
        if key == "y" then
            local ok, err = expedition.buyGearFromShopPlanet(self.expedition, self.shopModal.category, self.shopModal.gear)
            if ok then
                table.insert(self.floatingTexts, {
                    text = i18n.t("floating_hub_gear", self.shopModal.gear.name),
                    x = self.shopModal.planet.x,
                    y = self.shopModal.planet.y + 20,
                    timer = 3.0,
                    kind = "sample",
                    awarded = 0,
                    rollupElapsed = 0,
                })
                self.shopModal = nil
            else
                self.shopModal.errorText = err
            end
        elseif key == "n" then
            self.shopModal = nil
        end
        return
    end
    if self.expedition.phase == "settlement" and (key == "h" or key == "right" or key == "d") then
        if expedition.buyDurabilityUpgrade(self.expedition) then
            self.message = i18n.t(
                "hull_upgraded_message",
                self.expedition.durabilityUpgradeLevel,
                self.expedition.maxDurability,
                self.expedition.money)
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
                    self.expedition.maxDurability,
                    self.expedition.money)
            else
                self.message = purchaseShortfallMessage(self.expedition.money,
                    self.expedition.scoutShipCost, i18n.t("item_scout"))
            end
        else
            local shipId = self.expedition.selectedShipId == "scout" and "starter" or "scout"
            expedition.selectShip(self.expedition, shipId)
            self.message = i18n.t("ship_selected_message",
                string.upper(shipId), self.expedition.maxDurability)
        end
        return
    end
    -- Item 15(b): Earth shop slot machine. "l" triggers a slot spin during
    -- settlement using the galaxy-aware earthSlotSpin pure function (item 15(c)).
    -- The result is stored in self.earthShopSlotResult for draw() to render.
    -- Money reward is applied immediately to run.money.
    if self.expedition.phase == "settlement" and key == "l" then
        -- Item 15(b): earthSlotSpin expects rolls.reels (not a plain array).
        -- Building the table with the reels key ensures random values are used
        -- instead of the silent fallback to {0,0,0} that a plain array causes.
        local reels = {}
        for i = 1, 3 do reels[i] = math.random(1, 10) end
        local result = expedition.earthSlotSpin(self.expedition, self.expedition.lastVisitedGalaxyId, { reels = reels })
        self.earthShopSlotResult = result
        if result.reward > 0 then
            self.expedition.money = self.expedition.money + result.reward
            self.message = i18n.t("earth_slot_result",
                table.concat(result.symbols, " "), result.reward)
        else
            self.message = i18n.t("earth_slot_miss",
                table.concat(result.symbols, " "))
        end
        return
    end
    -- Item 7(c): Earth shop gear buy. "b" buys the current gear offer
    -- (rolled on settlement entry) using expedition.buyGear. Galaxy-exclusive
    -- parts are never in the earth pool (gear.earthShopPool filtered them),
    -- so buyGear will always accept the offer at settlement phase.
    if self.expedition.phase == "settlement" and key == "b" then
        local offer = self.earthShopGearOffer
        if offer then
            local gearMod = require("game.gear")
            local engine = gearMod.loadEngineParts() or {}
            local cat = gearMod.findById(engine, offer.id) and "engine" or "hull"
            local price = expedition.shopPrice(self.expedition, gearMod.buyPrice(offer))
            local engineParts = require("game.engine_parts")
            local slotsFull = (cat == "hull" and engineParts.isFull(self.expedition.gearLoadout, "hull"))
                or (cat == "engine" and engineParts.isFull(self.expedition.gearLoadout, "engine"))
            if slotsFull then
                self.message = i18n.t("earth_gear_full")
            elseif self.expedition.money < price then
                self.message = i18n.t("earth_gear_broke", price - self.expedition.money)
            else
                local ok, err = expedition.buyGear(self.expedition, cat, offer)
                if ok then
                    self.earthShopGearOffer = nil
                    self.message = i18n.t("earth_gear_bought", offer.name, self.expedition.money)
                else
                    self.message = err or "PURCHASE FAILED"
                end
            end
        end
        return
    end
    if key == "space" or key == "return" or key == "up" or key == "w" then
        -- Item 15(a): in-flight slot machine removed. Space/return during
        -- returning phase no longer triggers a slot spin. Settlement happens
        -- automatically when altitude reaches 0 (expedition.update).
        local relaunching = self.expedition.phase == "settlement" or self.expedition.phase == "destroyed"
        if expedition.launch(self.expedition) then
            if relaunching then
                self.ship.x = 0
                self.ship.y = 0
                self.verticalOffset = 0
                self.discovered = {}
                self.collided = {}
                self.discoveredCount = 0
                self.floatingTexts = {}
                self.earthShopSlotResult = nil
                self.earthShopGearOffer = nil
            end
            self.message = i18n.t("ascending_message")
        end
    end
end

function M:touchpressed(id, x, y)
    if self.shopModal then
        local btnY = 220
        if y >= btnY and y <= btnY + 30 then
            if x >= 15 and x < 85 then
                self:keypressed("y")
            elseif x >= 95 and x <= 165 then
                self:keypressed("n")
            end
        end
        return
    end
    if self.expedition.phase == "ascending" then
        self.touches[id] = { x = x, y = y, originX = x, originY = y }
        return
    end
    if self.expedition.phase == "returning" then
        -- Item 15(a): in-flight slot machine removed. The returning phase only
        -- has steering controls; slot-spin zone removed.
        local inControlRow = y >= returnControls.top and y <= returnControls.bottom
        if inControlRow and (x <= returnControls.leftMaxX or x >= returnControls.rightMinX) then
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
                if key == "hull" then
                    self:keypressed("h")
                elseif key == "steering" then
                    self:keypressed("g")
                elseif key == "yield" then
                    self:keypressed("y")
                elseif key == "ship" then
                    self:keypressed("v")
                elseif key == "slot" then
                    self:keypressed("l")
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
    -- Group 6 wiring: joystick_pad.png as the pad background, joystick_knob.png as the cap.
    -- Falls back to filled/outlined circles when images are nil.
    love.graphics.setColor(0.35, 0.55, 0.8, joystick.visualFillAlpha)
    if not drawShopIconSprite(self.joystickPadImage, ox, oy, radius * 2) then
        love.graphics.circle("fill", ox, oy, radius)
    end
    love.graphics.setColor(0.65, 0.85, 1, joystick.visualLineAlpha)
    if not self.joystickPadImage then
        love.graphics.circle("line", ox, oy, radius)
    end
    love.graphics.setColor(0.9, 0.95, 1, joystick.visualKnobAlpha)
    if not drawShopIconSprite(self.joystickKnobImage, kx, ky, knob * 2) then
        love.graphics.circle("fill", kx, ky, knob)
    end
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
    local hudHeight = M.hudHeight(self.expedition.phase, hud, galaxyShift)
    local view = minimap.view(self.ship.x, self.ship.y)
    local size = minimap.size
    local cx = viewport.width - size / 2 - 3
    local cy = hudHeight + size / 2 + 2
    local mm = self.minimapImages or {}
    -- Background disc: sprite or filled circle
    love.graphics.setColor(1, 1, 1, 1)
    if not drawMinimapSprite(mm.disc, cx, cy, size) then
        love.graphics.setColor(0.02, 0.04, 0.1, 1)
        love.graphics.circle("fill", cx, cy, size / 2)
        love.graphics.setColor(0.35, 0.55, 0.8, 1)
        love.graphics.circle("line", cx, cy, size / 2)
    end
    -- Rings: galaxy rings and orbit rings (sprites drawn per ring type)
    for _, ring in ipairs(view.rings or {}) do
        if ring.kind == "orbit" then
            love.graphics.setColor(0.85, 0.7, 0.25, 0.55)
            local ringImg = mm.orbitRing
            if ringImg then
                love.graphics.setColor(1, 1, 1, 0.55)
                local diam = ring.radius * 2
                drawMinimapSprite(ringImg, cx + ring.x, cy + ring.y, diam)
            else
                love.graphics.circle("line", cx + ring.x, cy + ring.y, ring.radius)
            end
        elseif ring.inside ~= false then
            local ringImg = mm.galaxyRing
            if ringImg then
                if ring.id == "milkyway" then
                    love.graphics.setColor(0.3, 0.55, 0.95, 0.55)
                else
                    love.graphics.setColor(0.9, 0.75, 0.3, 0.5)
                end
                drawMinimapSprite(ringImg, cx + ring.x, cy + ring.y, ring.radius * 2)
            else
                if ring.id == "milkyway" then
                    love.graphics.setColor(0.3, 0.55, 0.95, 0.55)
                else
                    love.graphics.setColor(0.9, 0.75, 0.3, 0.5)
                end
                love.graphics.circle("line", cx + ring.x, cy + ring.y, ring.radius)
            end
        end
    end
    -- Sun marker
    if view.sun then
        love.graphics.setColor(1, 0.85, 0.25, 1)
        if not drawMinimapSprite(mm.sun, cx + view.sun.x, cy + view.sun.y, minimap.markerSunRadius * 2) then
            love.graphics.circle("fill", cx + view.sun.x, cy + view.sun.y, 2.6)
        end
    end
    -- Galaxy markers
    for _, galaxy in ipairs(view.galaxies) do
        if galaxy.inside then
            if galaxy.id == "milkyway" then
                love.graphics.setColor(0.25, 0.55, 1, 1)
                if not drawMinimapSprite(mm.galaxyHome, cx + galaxy.x, cy + galaxy.y, minimap.markerGalaxyHomeRadius * 2) then
                    love.graphics.circle("fill", cx + galaxy.x, cy + galaxy.y, 2.2)
                end
            elseif galaxy.hub then
                -- Checkpoint galaxy: sprite or pulsing dot+ring
                local pulse = 0.45 + 0.35 * math.abs(math.sin((self.time or 0) * 2.4))
                if mm.checkpointStar then
                    love.graphics.setColor(0.9, 0.75, 0.3, pulse * 0.7 + 0.3)
                    drawMinimapSprite(mm.checkpointStar, cx + galaxy.x, cy + galaxy.y, minimap.markerGalaxyHubRadius * 3)
                else
                    love.graphics.setColor(0.9, 0.75, 0.3)
                    love.graphics.circle("fill", cx + galaxy.x, cy + galaxy.y, 2.3)
                    love.graphics.setColor(1, 0.95, 0.6, pulse)
                    love.graphics.circle("line", cx + galaxy.x, cy + galaxy.y, 4)
                end
            else
                love.graphics.setColor(0.9, 0.75, 0.3, 1)
                if not drawMinimapSprite(mm.galaxyPlain, cx + galaxy.x, cy + galaxy.y, minimap.markerGalaxyPlainRadius * 2) then
                    love.graphics.circle("fill", cx + galaxy.x, cy + galaxy.y, 1.5)
                end
            end
        end
    end
    -- Earth marker
    love.graphics.setColor(0.3, 0.85, 1, 1)
    if not drawMinimapSprite(mm.earth, cx + view.earth.x, cy + view.earth.y, minimap.markerEarthRadius * 2) then
        love.graphics.circle("fill", cx + view.earth.x, cy + view.earth.y, 2)
    end
    -- Player marker
    love.graphics.setColor(1, 1, 1, 1)
    if not drawMinimapSprite(mm.player, cx + view.player.x, cy + view.player.y, minimap.markerPlayerLineRadius * 2) then
        love.graphics.circle("fill", cx + view.player.x, cy + view.player.y, 1.7)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("line", cx + view.player.x, cy + view.player.y, 2.4)
    end
    -- Beyond-chart earth-return arrow
    if view.beyond then
        love.graphics.setColor(1, 0.55, 0.3, 1)
        local rim = size / 2 - 5
        local bx = cx + view.returnDx * rim
        local by = cy + view.returnDy * rim
        local angle = math.atan2(view.returnDy, view.returnDx) + math.pi / 2
        if mm.earthReturn then
            local iw, ih = mm.earthReturn:getDimensions()
            local bscale = (minimap.markerBeyondRadius * 2) / math.max(iw, ih)
            love.graphics.draw(mm.earthReturn, bx, by, angle, bscale, bscale, iw / 2, ih / 2)
        else
            love.graphics.circle("fill", bx, by, 2.2)
        end
        local label = i18n.t("minimap_out", math.floor(view.distanceBeyond + 0.5))
        love.graphics.setColor(1, 0.55, 0.3, 1)
        love.graphics.printf(label, viewport.width - size - 6, cy + size / 2 + 1, size + 4, "right")
    end
    if self.expedition.phase == "returning" then
        -- Item 15(a): in-flight slot machine removed; the slot-odds line
        -- (C%/P%/S%/AVG$ readout above the minimap) no longer exists.
        -- The 10px hudOddsLineHeight reservation was zeroed out accordingly.
    end
    if view.checkpointBeyond then
        -- Nearest off-chart checkpoint galaxy arrow (item 1). Distinct
        -- magenta from the orange Earth-return marker above, and offset
        -- slightly inward on the rim so the two never overlap when both
        -- are showing at once.
        love.graphics.setColor(0.85, 0.35, 0.95, 1)
        local rim = size / 2 - 9
        local tipX = cx + view.checkpointDx * rim
        local tipY = cy + view.checkpointDy * rim
        local angle = math.atan2(view.checkpointDy, view.checkpointDx) + math.pi / 2
        if mm.checkpointArrow then
            local iw, ih = mm.checkpointArrow:getDimensions()
            local bscale = (minimap.markerCheckpointTipRadius * 2) / math.max(iw, ih)
            love.graphics.draw(mm.checkpointArrow, tipX, tipY, angle, bscale, bscale, iw / 2, ih / 2)
        else
            love.graphics.circle("fill", tipX, tipY, 1.8)
            local perpX, perpY = -view.checkpointDy, view.checkpointDx
            love.graphics.polygon("fill",
                tipX + view.checkpointDx * 3, tipY + view.checkpointDy * 3,
                tipX - view.checkpointDx * 1.5 + perpX * 1.6, tipY - view.checkpointDy * 1.5 + perpY * 1.6,
                tipX - view.checkpointDx * 1.5 - perpX * 1.6, tipY - view.checkpointDy * 1.5 - perpY * 1.6)
        end
    end
end

function M:draw()
    local galaxy = world.galaxyContaining(self.ship.x, self.ship.y)
    love.graphics.clear(world.galaxyBackgroundColor(galaxy))
    local shipScreenX, shipScreenY = viewport.width / 2, math.floor(viewport.height * 0.58)
    local cameraX, cameraY = self.ship.x - shipScreenX, self.ship.y - shipScreenY
    -- Background image disabled: deep_space_tile.png is not seamless, causing
    -- visible grid lines at edges. Using procedural star layers only.
    -- if self.backgroundImage then ... end
    local sx, sy = world.sectorAt(self.ship.x, self.ship.y)
    -- UI/HUD cleanup item 1 (docs/feedback/INBOX.md, 2026-09-02): a dense,
    -- near-static background star layer drawn behind the streaking-meteor
    -- foreground layer below. Reduced parallax (0.4x camera motion) makes
    -- it read as a distant, almost-still Milky Way backdrop rather than
    -- more meteors, and dim/small points keep it from competing visually
    -- with the foreground streaks or gameplay elements.
    local bgCameraX, bgCameraY = cameraX * 0.4, cameraY * 0.4
    local bsx, bsy = world.sectorAt(bgCameraX, bgCameraY)
    for oy = -1, 1 do
        for ox = -1, 1 do
            for _, star in ipairs(world.backgroundStars(bsx + ox, bsy + oy)) do
                local x, y = math.floor(star.x - bgCameraX), math.floor(star.y - bgCameraY)
                if x >= 0 and x < viewport.width and y >= 0 and y < viewport.height then
                    -- Stable frame index from star position
                    local starHash = (math.floor(star.x) * 92837 + math.floor(star.y) * 689287) % 10000007
                    if star.bright < 0.4 then
                        -- Regular pixel star: 17 frames, 9x9 each, size 2-3px, white, semi-transparent
                        local frameIdx = starHash % 17
                        local sz = 2 + (starHash % 2)
                        local opacity = 0.15 + star.bright * 0.4
                        if not drawPixelStar(self.pixelStarsImage, x, y, 9, 9, 17, frameIdx, sz, 1, 1, 1, opacity) then
                            love.graphics.setColor(0.12 + star.bright * 0.4, 0.12 + star.bright * 0.4, math.min(1, 0.2 + star.bright * 0.4), opacity)
                            love.graphics.rectangle("fill", x - 1, y - 1, 2, 2)
                        end
                    else
                        -- Special pixel star: 6 frames, 25x25 each, size 4-5px, golden
                        local frameIdx = starHash % 6
                        local sz = 4 + (starHash % 2)
                        local opacity = 0.5 + star.bright * 0.5
                        if not drawPixelStar(self.pixelStarsSpecialImage, x, y, 25, 25, 6, frameIdx, sz, 1, 0.937, 0.620, opacity) then
                            local c = 0.12 + star.bright * 0.4
                            love.graphics.setColor(c, c, math.min(1, c + 0.08))
                            love.graphics.rectangle("fill", x - 1, y - 1, 2, 2)
                        end
                    end
                end
            end
        end
    end
    for oy = -1, 1 do
        for ox = -1, 1 do
            for _, star in ipairs(world.stars(sx + ox, sy + oy)) do
                local x, y = math.floor(star.x - cameraX), math.floor(star.y - cameraY)
                if x >= 0 and x < viewport.width and y >= 0 and y < viewport.height then
                    -- Stable frame index from star position
                    local starHash = (math.floor(star.x) * 92837 + math.floor(star.y) * 689287) % 10000007
                    if star.bright < 0.4 then
                        -- Regular pixel star: size 3-4px, white, semi-transparent
                        local frameIdx = starHash % 17
                        local sz = 3 + (starHash % 2)
                        local opacity = 0.15 + star.bright * 0.4
                        if not drawPixelStar(self.pixelStarsImage, x, y, 9, 9, 17, frameIdx, sz, 1, 1, 1, opacity) then
                            love.graphics.setColor(0.35 + star.bright * 0.65, 0.35 + star.bright * 0.65, math.min(1, 0.43 + star.bright * 0.65))
                            love.graphics.rectangle("fill", x - 1, y - 1, 2, 2)
                        end
                    else
                        -- Special pixel star: size 5-6px, golden
                        local frameIdx = starHash % 6
                        local sz = 5 + (starHash % 2)
                        local opacity = 0.5 + star.bright * 0.5
                        if not drawPixelStar(self.pixelStarsSpecialImage, x, y, 25, 25, 6, frameIdx, sz, 1, 0.937, 0.620, opacity) then
                            local c = 0.35 + star.bright * 0.65
                            love.graphics.setColor(c, c, math.min(1, c + 0.1))
                            love.graphics.rectangle("fill", x - 1, y - 1, 2, 2)
                        end
                    end
                end
            end
        end
    end
    local earthX, earthY = math.floor(-cameraX), math.floor(75 - cameraY)
    if earthY < viewport.height + 64 then
        if self.earthImage then
            local imgW, imgH = self.earthImage:getDimensions()
            local scale = 116 / math.max(imgW, imgH)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(self.earthImage, earthX, earthY, 0, scale, scale, imgW / 2, imgH / 2)
        else
            love.graphics.setColor(0.15, 0.45, 0.9)
            love.graphics.circle("fill", earthX, earthY, 58)
            love.graphics.setColor(0.25, 0.8, 0.45)
            love.graphics.circle("fill", earthX - 18, earthY - 18, 15)
            love.graphics.circle("fill", earthX + 21, earthY - 5, 12)
        end
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
                local pe = self.planetEffectImages or {}
                local glowDiam = (planet.radius + 3 + effect.glowRings * 4) * 2
                if not drawPlanetEffectSprite(pe.glow, x, y, glowDiam, glowR, glowG, glowB, effect.glowAlpha) then
                    for ring = effect.glowRings, 1, -1 do
                        local ringAlpha = effect.glowAlpha * (ring / effect.glowRings) * 0.5
                        love.graphics.setColor(glowR, glowG, glowB, ringAlpha)
                        love.graphics.circle("fill", x, y, planet.radius + 3 + ring * 4)
                    end
                end
            end
            -- Soft drop shadow: a low-alpha dark circle offset toward the
            -- lower-right, opposite the highlight, so planets read as
            -- slightly raised cards instead of flat painted circles.
            local pe2 = self.planetEffectImages or {}
            local shadowDiam = planet.radius * 2 * 1.02
            if not drawPlanetEffectSprite(pe2.shadow,
                    x + planet.radius * 0.22, y + planet.radius * 0.22,
                    shadowDiam, 0, 0, 0, 0.25) then
                love.graphics.setColor(0, 0, 0, 0.25)
                love.graphics.circle("fill", x + planet.radius * 0.22, y + planet.radius * 0.22, planet.radius * 1.02)
            end
            -- Saturated gradient fill: a darker base circle with a brighter
            -- highlight offset toward the upper-left, approximating a soft
            -- directional light instead of a single flat fill color.
            local baseR, baseG, baseB = planetColor(planet.hue)
            local planetSprite = self.planetImage
            if planet.hub and self.hubPlanetImage then
                planetSprite = self.hubPlanetImage
            elseif planet.isShop and self.shopPlanetImage then
                planetSprite = self.shopPlanetImage
            end
            if planetSprite then
                local iw, ih = planetSprite:getDimensions()
                local scale = (planet.radius * 2) / math.max(iw, ih)
                love.graphics.setColor(baseR, baseG, baseB)
                love.graphics.draw(planetSprite, x, y, 0, scale, scale, iw / 2, ih / 2)
            else
                love.graphics.setColor(baseR * 0.7, baseG * 0.7, baseB * 0.7)
                love.graphics.circle("fill", x, y, planet.radius)
                love.graphics.setColor(math.min(1, baseR * 1.25), math.min(1, baseG * 1.25), math.min(1, baseB * 1.25))
                love.graphics.circle("fill", x - planet.radius * 0.3, y - planet.radius * 0.3, planet.radius * 0.55)
            end
            if not self.discovered[planet.id] then
                love.graphics.setColor(sampleTierColor(world.sampleTier(planet)))
                local pe3 = self.planetEffectImages or {}
                local rimDiam = (planet.radius + 30) * 2
                if not drawPlanetEffectSprite(pe3.rim, x, y, rimDiam,
                        sampleTierColor(world.sampleTier(planet))) then
                    love.graphics.circle("line", x, y, planet.radius + 30)
                end
                -- Balatro-style twinkle: a handful of small points orbiting
                -- just outside the rim glow, each with its own phase so the
                -- shimmer isn't perfectly synchronized across points.
                local tier = world.sampleTier(planet)
                local sparkle = sampleTierSparkle(tier)
                local sr, sg, sb = sampleTierColor(tier)
                local shipDx, shipDy = planet.x - self.ship.x, planet.y - self.ship.y
                local shipDistance = math.sqrt(shipDx * shipDx + shipDy * shipDy)
                local anticipation = sparkleAnticipationMultiplier(shipDistance, planet.radius + 30)
                local pe4 = self.planetEffectImages or {}
                for i = 1, sparkle.count do
                    local seed = (planet.id and (tostring(planet.id):len() * 7) or 0) + i * 2.4
                    local angle = self.time * (sparkle.speed * 0.4 * anticipation) + seed
                    local sparkleRadius = planet.radius + 6 + (i % 3) * 3
                    local px = x + math.cos(angle) * sparkleRadius
                    local py = y + math.sin(angle) * sparkleRadius
                    local alpha = math.max(0, math.min(1, sparkleAlpha(tier, self.time, seed)))
                    local tr = math.min(1, sr + 0.2)
                    local tg = math.min(1, sg + 0.2)
                    local tb = math.min(1, sb + 0.2)
                    if not drawPlanetEffectSprite(pe4.twinkle, px, py, 4, tr, tg, tb, alpha) then
                        love.graphics.setColor(tr, tg, tb, alpha)
                        love.graphics.circle("fill", px, py, 1.2)
                    end
                end
            end
            love.graphics.setColor(0.9, 0.95, 1, 0.45)
            love.graphics.circle("line", x, y, planet.radius + 2)
            local risk = self:approachWarning(planet, y, shipScreenY)
            if risk then
                local font = love.graphics.getFont()
                local previewY
                local pe5 = self.planetEffectImages or {}
                if risk.sampleLabel then
                    previewY = math.max(48, y - planet.radius - 24)
                    love.graphics.setColor(0.45, 0.95, 1)
                    local lx = clampLabelX(x, font:getWidth(risk.sampleLabel), viewport.width)
                    -- planet_sample.png icon to the left of sample value label
                    local iconSize = 9
                    if pe5.sampleValue then
                        drawPlanetEffectSprite(pe5.sampleValue, lx - iconSize * 0.5 - 1, previewY + iconSize * 0.5, iconSize, 0.45, 0.95, 1, 1)
                        love.graphics.setColor(0.45, 0.95, 1)
                    end
                    love.graphics.print(risk.sampleLabel, lx, previewY)
                    previewY = previewY + 11
                else
                    previewY = math.max(72, y - planet.radius - 12)
                end
                if risk.lethal then
                    love.graphics.setColor(1, 0.3, 0.25)
                else
                    love.graphics.setColor(1, 0.8, 0.25)
                end
                local rlx = clampLabelX(x, font:getWidth(risk.label), viewport.width)
                -- planet_risk.png icon to the left of risk label
                local rIconSize = 9
                local rr, rg, rb = risk.lethal and 1 or 1, risk.lethal and 0.3 or 0.8, risk.lethal and 0.25 or 0.25
                if pe5.risk then
                    drawPlanetEffectSprite(pe5.risk, rlx - rIconSize * 0.5 - 1, previewY + rIconSize * 0.5, rIconSize, rr, rg, rb, 1)
                    if risk.lethal then
                        love.graphics.setColor(1, 0.3, 0.25)
                    else
                        love.graphics.setColor(1, 0.8, 0.25)
                    end
                end
                love.graphics.print(risk.label, rlx, previewY)
            end
        end
    end
    for _, junk in ipairs(world.nearbyDebris(self.ship.x, self.ship.y, 1, self.time)) do
        local x, y = math.floor(junk.x - cameraX), math.floor(junk.y - cameraY)
        if x > -20 and x < viewport.width + 20 and y > -20 and y < viewport.height + 20 then
            local debrisSprite = self.debrisImages and self.debrisImages[junk.kind]
            if debrisSprite then
                local iw, ih = debrisSprite:getDimensions()
                local scale = (junk.radius * 2) / math.max(iw, ih)
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(debrisSprite, x, y, 0, scale, scale, iw / 2, ih / 2)
            elseif junk.kind == "can" then
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
            local iconImg
            if ft.kind == "damage" then
                love.graphics.setColor(1, 0.35, 0.3, alpha)
                iconImg = self.floatingDamageIconImage
            else
                love.graphics.setColor(0.45, 1, 0.6, alpha)
                iconImg = self.floatingSampleIconImage
            end
            -- Draw icon to left of text when sprite available (8px icon, 4px gap)
            local iconSize = 8
            local iconGap  = 4
            if iconImg then
                drawFloatingIconSprite(iconImg, fx - 30 + iconSize * 0.5, fy - 4, iconSize, alpha)
                love.graphics.setColor(ft.kind == "damage" and 1 or 0.45,
                                       ft.kind == "damage" and 0.35 or 1,
                                       ft.kind == "damage" and 0.3 or 0.6, alpha)
                love.graphics.printf(ft.text, fx - 30 + iconSize + iconGap, fy - 10, 60 - iconSize - iconGap, "left")
            else
                love.graphics.printf(ft.text, fx - 30, fy - 10, 60, "center")
            end
        end
    end
    for _, particle in ipairs(self.particles) do
        local px, py = math.floor(particle.x - cameraX), math.floor(particle.y - cameraY)
        local alpha = math.max(0, particle.timer / particle.maxTimer)
        love.graphics.setColor(particle.r, particle.g, particle.b, alpha)
        local sprite = self.sampleEffectImage
        if particle.kind == "collision" then
            sprite = self.collisionEffectImage
        elseif particle.kind == "thrust" then
            sprite = self.thrustEffectImage
        end
        if sprite then
            local iw, ih = sprite:getDimensions()
            local scale = 3 / math.max(iw, ih)
            love.graphics.draw(sprite, px, py, 0, scale, scale, iw / 2, ih / 2)
        else
            love.graphics.circle("fill", px, py, 1.5)
        end
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
    local hullImage = self.shipImage
    if self.expedition.selectedShipId == "scout" and self.scoutShipImage then
        hullImage = self.scoutShipImage
    end
    if hullImage then
        local iw, ih = hullImage:getWidth(), hullImage:getHeight()
        local targetSize = 64
        local scale = targetSize / math.max(iw, ih)
        love.graphics.draw(hullImage, 0, 0, 0, scale, scale, iw / 2, ih / 2)
    elseif self.shipSilhouetteImage then
        local iw, ih = self.shipSilhouetteImage:getWidth(), self.shipSilhouetteImage:getHeight()
        local targetSize = 64
        local scale = targetSize / math.max(iw, ih)
        love.graphics.draw(self.shipSilhouetteImage, 0, 0, 0, scale, scale, iw / 2, ih / 2)
    else
        love.graphics.polygon("fill", 0, -7, -5, 6, 0, 3, 5, 6)
    end
    if self.expedition.phase == "ascending" then
        love.graphics.setColor(1, 0.55, 0.15)
        if self.thrustEffectImage then
            local iw, ih = self.thrustEffectImage:getDimensions()
            local scale = 28 / math.max(iw, ih)
            love.graphics.draw(self.thrustEffectImage, 0, 32, 0, scale, scale, iw / 2, ih / 2)
        else
            love.graphics.polygon("fill", -2, 5, 0, 11, 2, 5)
        end
    end
    love.graphics.pop()

    local hud = self:hudLines()
    local isLaunchHud = self.expedition.phase == "launch"
    local galaxyShift = hud.galaxy and 10 or 0
    local hudHeight = M.hudHeight(self.expedition.phase, hud, galaxyShift)
    -- Group 8 wiring: hud_panel.png as HUD background; fallback dark rectangle.
    local shopEff = self.shopEffectImages or {}
    love.graphics.setColor(1, 1, 1, 0.85)
    if not drawPanelSprite(shopEff.hudPanel, 0, 0, viewport.width, hudHeight) then
        love.graphics.setColor(0.02, 0.03, 0.08, 0.85)
        love.graphics.rectangle("fill", 0, 0, viewport.width, hudHeight)
    end
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
        -- ComfyUI HUD wiring (group 1): galaxy icon before galaxy name
        local hudIconsTmp = self.hudIconImages or {}
        local galaxyIconSize = M.hullIconSize
        drawHudSpriteOrPoly(hudIconsTmp.galaxy, nil,
            5 + galaxyIconSize / 2, hudY + galaxyIconSize / 2, galaxyIconSize)
        love.graphics.print(hud.galaxy, 5 + galaxyIconSize + M.hullIconGap, hudY)
        hudY = hudY + 10
        love.graphics.setColor(0.7, 0.9, 1)
    end
    -- ComfyUI HUD wiring (group 1): distance icon before distance text
    do
        local hudIconsTmp2 = self.hudIconImages or {}
        local distIconSize = M.hullIconSize
        drawHudSpriteOrPoly(hudIconsTmp2.distance, nil,
            5 + distIconSize / 2, hudY + distIconSize / 2, distIconSize)
        love.graphics.print(hud.distance, 5 + distIconSize + M.hullIconGap, hudY)
    end
    -- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
    -- third slice): pair the CASH readout with a small coin icon, mirroring
    -- the shield icon paired with the hull status line below. The coin sits
    -- right after the DIST text (measured via the currently active HUD
    -- font, so this works for both the 14px default and the launch phase's
    -- 8px small font) with the CASH text shifted right of the coin's
    -- footprint so nothing overlaps.
    local distanceWidth = love.graphics.getFont():getWidth(hud.distance)
    -- Distance text now starts after the distance icon, so cash icon needs
    -- to account for the distance icon prefix too.
    local distIconOffset = M.hullIconSize + M.hullIconGap
    local cashIconCenterX = 5 + distIconOffset + distanceWidth + 8 + M.cashIconSize / 2
    local cashIconCenterY = hudY + (love.graphics.getFont():getHeight() / 2)
    love.graphics.setColor(1, 0.85, 0.3)
    -- ComfyUI HUD wiring (group 1): use hud_coin.png if loaded, else polygon
    local hudIcons = self.hudIconImages or {}
    drawHudSpriteOrPoly(hudIcons.cash, M.coinIconPoints,
        cashIconCenterX, cashIconCenterY, M.cashIconSize)
    love.graphics.setColor(0.7, 0.9, 1)
    love.graphics.print(hud.cash,
        5 + distIconOffset + distanceWidth + 8 + M.cashIconSize + M.cashIconGap, hudY)
    -- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
    -- second slice): pair the hull-durability status text with a small
    -- shield icon drawn just to its left, then shift the text right by
    -- the icon's footprint so it never overlaps the shield.
    local function drawStatusWithShield(y)
        local iconCenterX = 5 + M.hullIconSize / 2
        local iconCenterY = y + M.hullIconSize / 2
        love.graphics.setColor(0.6, 0.85, 1)
        -- ComfyUI HUD wiring (group 1): use hud_shield.png if loaded, else polygon
        drawHudSpriteOrPoly(hudIcons.hull, M.shieldIconPoints,
            iconCenterX, iconCenterY, M.hullIconSize)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.print(hud.status, 5 + M.hullIconSize + M.hullIconGap, y)
    end
    if hud.samples then
        -- Extra vertical gap (M.hudPrimaryStatusGap) below the samples line
        -- separates the secondary hull/slot status from DIST/CASH.
        love.graphics.setColor(1, 0.8, 0.3)
        -- ComfyUI HUD wiring (group 1): samples icon left of sample count text
        local samplesY = 16 + galaxyShift
        local samplesIconSize = M.hullIconSize
        local samplesIconCenterX = 5 + samplesIconSize / 2
        local samplesIconCenterY = samplesY + samplesIconSize / 2
        drawHudSpriteOrPoly(hudIcons.samples, nil,
            samplesIconCenterX, samplesIconCenterY, samplesIconSize)
        love.graphics.print(hud.samples, 5 + samplesIconSize + M.hullIconGap, samplesY)
        drawStatusWithShield(30 + M.hudPrimaryStatusGap + galaxyShift)
        if hud.earth then
            love.graphics.setColor(0.4, 0.85, 1)
            -- ComfyUI HUD wiring (group 1): earth + return icons
            local earthY = 43 + M.hudPrimaryStatusGap + galaxyShift
            local earthIconSize = M.hullIconSize
            drawHudSpriteOrPoly(hudIcons.earth, nil,
                5 + earthIconSize / 2, earthY + earthIconSize / 2, earthIconSize)
            love.graphics.print(hud.earth, 5 + earthIconSize + M.hullIconGap, earthY)
            local returnY = 55 + M.hudPrimaryStatusGap + galaxyShift
            drawHudSpriteOrPoly(hudIcons.returnIc, nil,
                5 + earthIconSize / 2, returnY + earthIconSize / 2, earthIconSize)
            love.graphics.print(hud.returnProgress, 5 + earthIconSize + M.hullIconGap, returnY)
        end
    elseif hud.best then
        drawStatusWithShield((isLaunchHud and 13 or 18) + galaxyShift)
        love.graphics.setColor(1, 0.8, 0.3)
        -- ComfyUI HUD wiring (group 1): best-altitude icon
        local bestY = (isLaunchHud and 22 or 30) + galaxyShift
        local bestIconSize = M.hullIconSize
        drawHudSpriteOrPoly(hudIcons.best, nil,
            5 + bestIconSize / 2, bestY + bestIconSize / 2, bestIconSize)
        love.graphics.print(hud.best, 5 + bestIconSize + M.hullIconGap, bestY)
    else
        drawStatusWithShield(18 + galaxyShift)
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
        self:drawGearSlots(184)
        local loadout = self:loadoutLines()
        -- The card box now extends all the way to the canvas bottom
        -- (viewport.height) instead of stopping at y=294: a real LÖVE
        -- runtime capture showed the Earth disc drawn behind the scene
        -- (radius 58, extending to y=318 for a ship at the world origin)
        -- peeking out below the old box, directly behind the TAP TO
        -- LAUNCH message and DEV PLACEHOLDER footer text.
        local panelX = 12
        local panelY = M.launchLoadoutBoxTop
        local panelW = viewport.width - 24
        local panelH = viewport.height - M.launchLoadoutBoxTop
        love.graphics.setColor(1, 1, 1, 0.92)
        if not drawPanelSprite(self.loadoutPanelImage, panelX, panelY, panelW, panelH) then
            love.graphics.setColor(0.02, 0.03, 0.08, 0.92)
            love.graphics.rectangle("fill", panelX, panelY, panelW, panelH)
        end
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
        if M.showLaunchLoadoutTitle then
            love.graphics.setColor(0.7, 0.9, 1)
            love.graphics.printf(i18n.t("launch_loadout_title"), 16, row, viewport.width - 32, "center")
            row = row + rowStep
        end
        if loadout.ship then
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.printf(loadout.ship, 16, row, viewport.width - 32, "center")
            row = row + rowStep
        end
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(loadout.stats, 16, row, viewport.width - 32, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(loadout.upgrades, 16, row, viewport.width - 32, "center")
        row = row + rowStep
        love.graphics.setColor(0.6, 1, 0.85)
        M.drawCenteredIconText(M.speedIconPoints, M.speedIconSize, M.speedIconGap, loadout.steering, 16, row, viewport.width - 32)
        if loadout.odds then
            row = row + rowStep
            love.graphics.setColor(0.6, 0.8, 1)
            love.graphics.printf(loadout.odds, 16, row, viewport.width - 32, "center")
        end
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
        -- Group 5 wiring: settlement_summary_panel.png as background; fallback rect.
        love.graphics.setColor(1, 1, 1, 0.94)
        if not drawPanelSprite(self.settlementPanelImage, 12, 70, viewport.width - 24, 250) then
            love.graphics.setColor(0.02, 0.03, 0.08, 0.94)
            love.graphics.rectangle("fill", 12, 70, viewport.width - 24, 250)
        end
        -- Faint alternating background bands behind each tappable
        -- settlementTouchRows entry. Drawn before any text so it never
        -- overlaps or obscures the already real-capture-verified printf
        -- calls below; purely a visual affordance for which rows respond
        -- to touch (see settlementRowBackgroundColor comment above).
        local shopEff = self.shopEffectImages or {}
        -- Faint alternating background bands behind each tappable
        -- settlementTouchRows entry. Drawn before any text so it never
        -- overlaps or obscures the already real-capture-verified printf
        -- calls below; purely a visual affordance for which rows respond
        -- to touch (see settlementRowBackgroundColor comment above).
        for index, touchRow in ipairs(settlementTouchRows) do
            love.graphics.setColor(M.settlementRowBackgroundColor(index))
            if not drawPanelSprite(shopEff.shopTouchRow, 12, touchRow.top, viewport.width - 24, touchRow.bottom - touchRow.top) then
                love.graphics.rectangle("fill", 12, touchRow.top, viewport.width - 24, touchRow.bottom - touchRow.top)
            end
        end
        love.graphics.setColor(1, 1, 1, 0.9)
        drawPanelSprite(shopEff.shopTitle, 16, 74 - 2, viewport.width - 32, 14)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf(i18n.t("earth_shop_title"), 16, 74, viewport.width - 32, "center")
        -- The previously-verified capture (build/spaceship-runtime-preview-
        -- settlement-newbest-*.png) fit exactly one extra summary line
        -- (NEW BEST!) at y=127 with shop rows starting unshifted at
        -- row=140 and the last shop line (TAP: RELAUNCH) landing just
        -- above the y=307 DEV PLACEHOLDER footer.
        local summaryExtraLine
        if self.expedition.lastNewBest then
            summaryExtraLine = i18n.t("newbest_label")
        end
        love.graphics.setColor(1, 1, 1, 0.9)
        if not drawPanelSprite(shopEff.shopStats, 18, 88, viewport.width - 36, 46) then
            love.graphics.setColor(0.04, 0.08, 0.16, 0.85)
            love.graphics.rectangle("fill", 18, 88, viewport.width - 36, 46)
        end
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(i18n.t("total_label", self.expedition.lastSettlement), 22, 91, viewport.width - 44, "center")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(i18n.t("samples_settlement_line", self.expedition.lastSampleCount or 0, self.expedition.lastSampleSettlement), 22, 100, viewport.width - 44, "center")
        -- Item 15/11: spins_settlement_line removed (in-flight slots abolished)
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(i18n.t("peak_alt_line", math.floor(self.expedition.lastAltitude or 0)), 22, 109, viewport.width - 44, "center")
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
        -- HULL and STEERING
        rowStep = 8
        
        -- Group 8 wiring: action backgrounds
        love.graphics.setColor(1, 1, 1, 0.85)
        drawPanelSprite(shopEff.hullAction, shopColumnLeftX, row, shopColumnLeftW, rowStep)
        drawPanelSprite(shopEff.steeringAction, shopColumnRightX, row, shopColumnRightW, rowStep)
        
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.hullActionCompact, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.printf(nextLaunch.steeringActionCompact, shopColumnRightX, row, shopColumnRightW, "center")
        -- Group 6 wiring: hull/steering icons to the left of each action sub-column
        local shopIcons = self.shopIconImages or {}
        local iconSz = 7
        drawShopIconSprite(shopIcons.hull, shopColumnLeftX + 2, row + iconSz * 0.5, iconSz)
        drawShopIconSprite(shopIcons.steering, shopColumnRightX + 2, row + iconSz * 0.5, iconSz)
        row = row + rowStep
        
        -- Group 8 wiring: status backgrounds
        love.graphics.setColor(1, 1, 1, 0.85)
        drawPanelSprite(shopEff.hullStatus, shopColumnLeftX, row, shopColumnLeftW, rowStep)
        drawPanelSprite(shopEff.steeringStatus, shopColumnRightX, row, shopColumnRightW, rowStep)
        
        love.graphics.setColor(nextLaunch.hullAffordable and 0.45 or 1,
            nextLaunch.hullAffordable and 1 or 0.4, nextLaunch.hullAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.hullStatus, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.setColor(nextLaunch.steeringAffordable and 0.45 or 1,
            nextLaunch.steeringAffordable and 1 or 0.4, nextLaunch.steeringAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.steeringStatus, shopColumnRightX, row, shopColumnRightW, "center")
        row = row + rowStep
        
        -- Group 8 wiring: preview backgrounds
        love.graphics.setColor(1, 1, 1, 0.85)
        drawPanelSprite(shopEff.hullPreview, shopColumnLeftX, row, shopColumnLeftW, rowStep)
        drawPanelSprite(shopEff.steeringPreview, shopColumnRightX, row, shopColumnRightW, rowStep)
        
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(nextLaunch.hullPreviewCompact, shopColumnLeftX, row, shopColumnLeftW, "center")
        M.drawCenteredIconText(M.speedIconPoints, M.speedIconSize, M.speedIconGap, nextLaunch.steeringPreviewCompact, shopColumnRightX, row, shopColumnRightW)
        row = row + rowStep

        -- YIELD and SHIP
        row = 216
        rowStep = 8
        
        -- Group 8 wiring: action backgrounds
        love.graphics.setColor(1, 1, 1, 0.85)
        drawPanelSprite(shopEff.yieldAction, shopColumnLeftX, row, shopColumnLeftW, rowStep)
        drawPanelSprite(shopEff.shipAction, shopColumnRightX, row, shopColumnRightW, rowStep)
        
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.yieldActionCompact, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.printf(nextLaunch.shipActionCompact, shopColumnRightX, row, shopColumnRightW, "center")
        -- Group 6 wiring: yield/ship icons to the left of each action sub-column
        local shopIconsYS = self.shopIconImages or {}
        drawShopIconSprite(shopIconsYS.yield, shopColumnLeftX + 2, row + iconSz * 0.5, iconSz)
        drawShopIconSprite(shopIconsYS.ship, shopColumnRightX + 2, row + iconSz * 0.5, iconSz)
        row = row + rowStep
        
        -- Group 8 wiring: status backgrounds
        love.graphics.setColor(1, 1, 1, 0.85)
        drawPanelSprite(shopEff.yieldStatus, shopColumnLeftX, row, shopColumnLeftW, rowStep)
        drawPanelSprite(shopEff.shipStatus, shopColumnRightX, row, shopColumnRightW, rowStep)
        
        love.graphics.setColor(nextLaunch.yieldAffordable and 0.45 or 1,
            nextLaunch.yieldAffordable and 1 or 0.4, nextLaunch.yieldAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.yieldStatus, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.setColor(nextLaunch.shipAffordable and 0.45 or 1,
            nextLaunch.shipAffordable and 1 or 0.4, nextLaunch.shipAffordable and 0.55 or 0.35)
        love.graphics.printf(nextLaunch.shipStatus, shopColumnRightX, row, shopColumnRightW, "center")
        row = row + rowStep

        -- Group 8 wiring: preview backgrounds
        love.graphics.setColor(1, 1, 1, 0.85)
        drawPanelSprite(shopEff.yieldPreview, shopColumnLeftX, row, shopColumnLeftW, rowStep)
        drawPanelSprite(shopEff.shipPreview, shopColumnRightX, row, shopColumnRightW, rowStep)
        
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(nextLaunch.yieldPreview, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.printf(nextLaunch.shipPreviewCompact, shopColumnRightX, row, shopColumnRightW, "center")
        row = row + rowStep
        
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.scoutTradeoff[1], fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf(nextLaunch.scoutTradeoff[2], fullX, row, fullW, "center")
        row = row + rowStep
        row = 236
        rowStep = 10
        -- Item 7(c): Earth shop gear offer line.
        if self.earthShopGearOffer then
            local offer = self.earthShopGearOffer
            local gearMod = require("game.gear")
            local price = expedition.shopPrice(self.expedition, gearMod.buyPrice(offer))
            love.graphics.setColor(0.4, 1, 0.7)
            love.graphics.printf(i18n.t("earth_gear_offer", offer.name, price), fullX, row, fullW, "center")
            row = row + rowStep
        end
        if self.earthShopSlotResult then
            -- Group 5 wiring: slot_result_panel.png behind the result area.
            love.graphics.setColor(1, 1, 1, 0.85)
            drawPanelSprite(self.slotResultPanelImage, fullX, row - 2, fullW, rowStep * 2 + 2)
            love.graphics.setColor(0.85, 0.95, 1)
            love.graphics.printf(table.concat(self.earthShopSlotResult.symbols, "  "), fullX, row, fullW, "center")
            row = row + rowStep
            local profileLabel = M.earthSlotProfileLabel(self.earthShopSlotResult.rewardProfile)
            if profileLabel then
                love.graphics.setColor(1, 0.55, 0.45)
                love.graphics.printf(profileLabel, fullX, row, fullW, "center")
            end
        else
            -- Group 5 wiring: slot_spin_button.png behind the spin prompt text.
            love.graphics.setColor(1, 1, 1, 0.85)
            drawPanelSprite(self.slotSpinButtonImage, fullX, row - 2, fullW, rowStep + 4)
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.printf(i18n.t("earth_slot_spin_prompt"), fullX, row, fullW, "center")
        end

        row = 280
        rowStep = 8
        
        -- Group 8 wiring: next ship panel background
        love.graphics.setColor(1, 1, 1, 0.9)
        drawPanelSprite(shopEff.shopNextShip, fullX, row - 2, fullW, rowStep * 3 + 2)
        
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(nextLaunch.ship, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.stats, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf(nextLaunch.upgrades, fullX, row, fullW, "center")
        row = row + rowStep
        -- Group 5 wiring: relaunch.png behind the TAP: RELAUNCH button text.
        love.graphics.setColor(1, 1, 1, 0.9)
        drawPanelSprite(self.relaunChImage, fullX, row - 2, fullW, rowStep + 4)
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(i18n.t("tap_relaunch"), fullX, row, fullW, "center")
        love.graphics.setFont(previousFont)
    elseif self.expedition.phase == "destroyed" then
        local loadout = self:loadoutLines()
        -- Group 5 wiring: destroyed_panel.png as background; fallback rect.
        love.graphics.setColor(1, 1, 1, 0.94)
        if not drawPanelSprite(self.destroyedPanelImage, 12, 174, viewport.width - 24, 134) then
            love.graphics.setColor(0.08, 0.02, 0.03, 0.94)
            love.graphics.rectangle("fill", 12, 174, viewport.width - 24, 134)
        end
        self.smallFont = self.smallFont or fonts.get(8)
        local previousFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        local fullX, fullW = 16, viewport.width - 32
        local row = 178
        local rowStep = 11
        local dIconSz = 9  -- destroyed-phase row icon size
        local dIconGap = 2 -- gap between icon and text
        love.graphics.setColor(1, 0.55, 0.45)
        drawHudSpriteOrPoly(self.destroyedTitleIconImage, nil,
            fullX + dIconSz * 0.5, row + dIconSz * 0.5, dIconSz)
        love.graphics.printf(i18n.t("ship_destroyed_title"), fullX + dIconSz + dIconGap, row, fullW - dIconSz - dIconGap, "center")
        row = row + rowStep
        love.graphics.setColor(1, 0.8, 0.3)
        drawHudSpriteOrPoly(self.destroyedLostTotalIconImage, nil,
            fullX + dIconSz * 0.5, row + dIconSz * 0.5, dIconSz)
        love.graphics.printf(i18n.t("lost_total_line",
            (self.expedition.lastLostSampleValue or 0)),
            fullX + dIconSz + dIconGap, row, fullW - dIconSz - dIconGap, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        drawHudSpriteOrPoly(self.destroyedSamplesSettlementIconImage, nil,
            fullX + dIconSz * 0.5, row + dIconSz * 0.5, dIconSz)
        love.graphics.printf(i18n.t("samples_settlement_line",
            self.expedition.lastLostSampleCount or 0, self.expedition.lastLostSampleValue or 0),
            fullX + dIconSz + dIconGap, row, fullW - dIconSz - dIconGap, "center")
        row = row + rowStep
        -- Item 15/11: spins_settlement_line removed (in-flight slots abolished)
        love.graphics.setColor(0.6, 0.8, 1)
        drawHudSpriteOrPoly(self.destroyedPeakDistIconImage, nil,
            fullX + dIconSz * 0.5, row + dIconSz * 0.5, dIconSz)
        love.graphics.printf(i18n.t("peak_alt_line", math.floor(self.expedition.lastLostAltitude or 0)),
            fullX + dIconSz + dIconGap, row, fullW - dIconSz - dIconGap, "center")
        row = row + rowStep
        if self.expedition.lastLostNewBest then
            love.graphics.setColor(1, 0.95, 0.3)
            drawHudSpriteOrPoly(self.destroyedNewBestIconImage, nil,
                fullX + dIconSz * 0.5, row + dIconSz * 0.5, dIconSz)
            love.graphics.printf(i18n.t("newbest_label"), fullX + dIconSz + dIconGap, row, fullW - dIconSz - dIconGap, "center")
            row = row + rowStep
        end
        love.graphics.setColor(1, 0.55, 0.45)
        drawHudSpriteOrPoly(self.destroyedMetaResetIconImage, nil,
            fullX + dIconSz * 0.5, row + dIconSz * 0.5, dIconSz)
        love.graphics.printf(i18n.t("meta_reset_line", math.floor(self.expedition.bestAltitude)), fullX + dIconSz + dIconGap, row, fullW - dIconSz - dIconGap, "center")
        row = row + rowStep
        love.graphics.setColor(1, 0.8, 0.3)
        drawHudSpriteOrPoly(self.destroyedNextShipIconImage, nil,
            fullX + dIconSz * 0.5, row + dIconSz * 0.5, dIconSz)
        love.graphics.printf(i18n.t("next_ship_line", loadout.shipLabel), fullX + dIconSz + dIconGap, row, fullW - dIconSz - dIconGap, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(loadout.upgrades, fullX, row, fullW, "center")
        row = row + rowStep
        drawHudSpriteOrPoly(self.destroyedTapStartOverIconImage, nil,
            fullX + dIconSz * 0.5, row + dIconSz * 0.5, dIconSz)
        love.graphics.printf(i18n.t("tap_start_over"), fullX + dIconSz + dIconGap, row, fullW - dIconSz - dIconGap, "center")
        love.graphics.setFont(previousFont)
    elseif self.expedition.phase == "ascending" then
        self:drawJoystickStick()
    elseif self.expedition.phase == "returning" then
        self:drawJoystickStick()
    end
    love.graphics.setColor(0.85, 0.9, 1)
    local messageY = (self.expedition.phase == "settlement" or self.expedition.phase == "destroyed") and 50 or viewport.height - 30
    if self.expedition.phase == "launch" then
        -- docs/feedback/INBOX.md UI/HUD item 3: pair the TAP TO LAUNCH
        -- action with a small rocket icon above it instead of bare text.
        -- Group 5 wiring: use launch_rocket.png sprite when available,
        -- fall back to original polygon.
        love.graphics.setColor(1, 0.75, 0.25)
        if not drawHudSpriteOrPoly(self.launchRocketIconImage, M.rocketIconPoints,
                viewport.width / 2, messageY - M.launchIconGap, M.launchIconSize) then
            love.graphics.polygon("fill", M.rocketIconPoints(
                viewport.width / 2, messageY - M.launchIconGap, M.launchIconSize))
        end
        love.graphics.setColor(0.85, 0.9, 1)
    end
    love.graphics.printf(self.message, 4, messageY, viewport.width - 8, "center")
    -- message_banner icon: draw amber burst-star icon to the left of the message
    -- for non-launch phases (launch already has a rocket icon polygon).
    if self.expedition.phase ~= "launch" and self.messageBannerIconImage then
        local bannerIconSize = 10
        love.graphics.setColor(1, 0.82, 0.25)
        drawFloatingIconSprite(self.messageBannerIconImage,
            4 + bannerIconSize * 0.5, messageY + 5, bannerIconSize, 1)
        love.graphics.setColor(0.85, 0.9, 1)
    end
    if self.newSpecimenBanner then
        local alpha = math.min(1, self.newSpecimenBannerTimer / 0.4)
        -- Group 6 wiring: specimen_banner.png behind the discovery banner; fallback rect.
        love.graphics.setColor(1, 1, 1, 0.9 * alpha)
        if not drawPanelSprite(self.specimenBannerImage, 12, 60, viewport.width - 24, 16) then
            love.graphics.setColor(0.05, 0.06, 0.12, 0.85 * alpha)
            love.graphics.rectangle("fill", 12, 60, viewport.width - 24, 16)
        end
        love.graphics.setColor(1, 0.85, 0.3, alpha)
        love.graphics.printf(self.newSpecimenBanner, 12, 64, viewport.width - 24, "center")
    end
    if self.shopModal then
        love.graphics.setColor(0, 0, 0, 0.85)
        love.graphics.rectangle("fill", 0, 0, viewport.width, viewport.height)
        
        love.graphics.setColor(0.08, 0.14, 0.22, 1)
        love.graphics.rectangle("fill", 10, 30, viewport.width - 20, 240)
        love.graphics.setColor(0.3, 0.6, 1, 1)
        love.graphics.rectangle("line", 10, 30, viewport.width - 20, 240)
        
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(i18n.t("shop_modal_title"), 10, 40, viewport.width - 20, "center")
        
        love.graphics.setColor(0.7, 0.8, 1)
        love.graphics.printf(self.shopModal.gear.name, 10, 60, viewport.width - 20, "center")
        
        self:drawGearSlots(100)
        
        local btnY = 220
        love.graphics.setColor(0.2, 0.4, 0.2, 1)
        love.graphics.rectangle("fill", 15, btnY, 70, 30)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(i18n.t("shop_modal_buy", self.shopModal.price), 15, btnY + 8, 70, "center")
        
        love.graphics.setColor(0.4, 0.2, 0.2, 1)
        love.graphics.rectangle("fill", 95, btnY, 70, 30)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(i18n.t("shop_modal_skip"), 95, btnY + 8, 70, "center")
        
        if self.shopModal.errorText then
            self.tinyFont = self.tinyFont or fonts.get(M.devPlaceholderFontSize)
            local prevFont = love.graphics.getFont()
            love.graphics.setFont(self.tinyFont)
            love.graphics.setColor(1, 0.3, 0.3)
            love.graphics.printf(self.shopModal.errorText, 12, 160, viewport.width - 24, "center")
            love.graphics.setFont(prevFont)
        end
    end
    self.tinyFont = self.tinyFont or fonts.get(M.devPlaceholderFontSize)
    local previousFooterFont = love.graphics.getFont()
    love.graphics.setFont(self.tinyFont)
    love.graphics.setColor(1, 0.65, 0.2, M.devPlaceholderAlpha)
    love.graphics.printf(i18n.t("dev_placeholder"), 4, viewport.height - 11, viewport.width - 8, "center")
    love.graphics.setFont(previousFooterFont)
end

return M
