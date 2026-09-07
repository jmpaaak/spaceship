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
local leaderboardClient = require("game.leaderboard_client")
local sfx = require("game.sfx")
local M = {}
M.__index = M

-- Minimap + ship-stats overlay extracted to play_minimap.lua (MODULE_STRUCTURE).
-- install() copies drawMinimap, drawShipStatsSummary, galaxyChartLineColor/FillColor,
-- drawMinimapSprite, rimMarker constants, shipStats constants back onto M so
-- existing callers / tests keep working unchanged.
require("game.scenes.play_minimap").install(M)

-- Settlement shop + destroyed overlay extracted to play_shop.lua (MODULE_STRUCTURE).
-- install() copies drawSettlementOverlay, drawDestroyedOverlay, rarityRgb onto M.
require("game.scenes.play_shop").install(M)
-- Gear popup + pause overlay extracted to play_hud.lua (MODULE_STRUCTURE).
-- install() copies drawGearPopup, drawPauseOverlay onto M.
require("game.scenes.play_hud").install(M)
-- Boost logic extracted to play_boost.lua (MODULE_STRUCTURE).
require("game.scenes.play_boost").install(M)
-- Destroyed-phase layout + keep-one card + Balatro card draw extracted to play_gameover.lua (MODULE_STRUCTURE).
require("game.scenes.play_gameover").install(M)

-- Omnidirectional movement: both horizontal (ship.x) and vertical (ship.y)
-- are driven directly by joystick/keyboard input at effectiveSpeed, with no
-- clamping. The old verticalOffset ±90 clamp was removed in item 32 so
-- vertical steering matches horizontal (unlimited).

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

-- Mobile-UI sub-item (4): settlement panel vertically centered on 1280px
-- canvas with 12px font (was 8px crammed into 70-320 at the top). Touch
-- rows expanded to 70px each (well above 44pt iOS HIG minimum). Columns
-- widened to fill the 720px canvas.
M.settlementFontSize = 22
M.settlementRowStep = 44  -- vertical px between successive text lines in the shop
M.settlementSummaryRowStep = 40  -- vertical px between summary stat lines
-- Vertical layout anchors (all in 720×1280 canvas coordinates):
M.settlementPanelTop = 200
M.settlementPanelHeight = 1080
M.settlementTitleY = 210
M.settlementSummaryBgTop = 240
M.settlementSummaryBgHeight = 170
M.settlementTotalY = 248
M.settlementSamplesY = 288
M.settlementPeakAltY = 328
M.settlementNewBestY = 368
-- Touch rows: variable-height rows starting after the summary section.
-- Row 3 (gear text) is compact (70px) to reduce the gap between cards and slot.
local settlementTouchRowTop = 400
local settlementTouchRowHeight = 170
local settlementGearRowHeight = 70   -- INBOX 61(18): compact row for gear text
local settlementSlotRowHeight = 200  -- slot machine gets the space saved from row3
local settlementTouchRows = {
    {
        top = settlementTouchRowTop, bottom = settlementTouchRowTop + settlementTouchRowHeight,
        columns = {
            { key = "hull", left = 0, right = 360 },
            { key = "steering", left = 360, right = 720 },
        },
    },
    {
        top = settlementTouchRowTop + settlementTouchRowHeight,
        bottom = settlementTouchRowTop + settlementTouchRowHeight * 2,
        columns = {
            { key = "yield", left = 0, right = 360 },
            { key = "ship", left = 360, right = 720 },
        },
    },
    { key = "gear",
      top = settlementTouchRowTop + settlementTouchRowHeight * 2,
      bottom = settlementTouchRowTop + settlementTouchRowHeight * 2 + settlementGearRowHeight },
    { key = "slot",
      top = settlementTouchRowTop + settlementTouchRowHeight * 2 + settlementGearRowHeight,
      bottom = settlementTouchRowTop + settlementTouchRowHeight * 2 + settlementGearRowHeight + settlementSlotRowHeight },
    { key = "relaunch",
      top = settlementTouchRowTop + settlementTouchRowHeight * 2 + settlementGearRowHeight + settlementSlotRowHeight,
      bottom = settlementTouchRowTop + settlementTouchRowHeight * 2 + settlementGearRowHeight + settlementSlotRowHeight + settlementTouchRowHeight },
}
M.settlementTouchRows = settlementTouchRows
M.settlementTouchRowHeight = settlementTouchRowHeight
M.settlementShopLayout = function()
    return {
        slot = { top = M.settlementTouchRows[4].top, bottom = M.settlementTouchRows[4].bottom },
        slotResult = { top = M.settlementTouchRows[4].top, bottom = M.settlementTouchRows[4].bottom },
        gear = { top = M.settlementTouchRows[3].top, bottom = M.settlementTouchRows[3].bottom },
        scout = { top = M.settlementTouchRows[2].top, bottom = M.settlementTouchRows[2].bottom },
        relaunch = { top = M.settlementTouchRows[5].top, bottom = M.settlementTouchRows[5].bottom }
    }
end

-- SHIP DESTROYED restart touch target. Unlike EARTH SHOP's four stacked
-- rows, this phase has a single action (restart), so touchpressed accepts
-- any tap on the full 180x320 internal canvas rather than a narrow band.
-- destroyedTouchArea → moved to game/scenes/play_gameover.lua (installed on M at top of file)

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

-- Pause button (top-right corner, ascending phase only).
-- 44×44 touch area with 8px margin from right and top edges.
local pauseButton = {
    x = 720 - 44 - 8,  -- 668
    y = 8,
    w = 44,
    h = 44,
}
M.pauseButton = pauseButton

-- INBOX 61(21): Pause menu button rects (restart / main menu).
function M.pauseMenuRects()
    local cx = viewport.width / 2
    local btnW = 300
    local btnH = 56
    local gap = 20
    local baseY = viewport.height / 2 + 10
    return {
        restart = { x = cx - btnW / 2, y = baseY, w = btnW, h = btnH },
        mainMenu = { x = cx - btnW / 2, y = baseY + btnH + gap, w = btnW, h = btnH },
    }
end

-- Dev admin cheat buttons: stacked below pause (speed / hull / yield).
local adminButtons = {
    { kind = "speed", labelKey = "admin_speed" },
    { kind = "hull",  labelKey = "admin_hull" },
    { kind = "yield", labelKey = "admin_yield" },
}
local function adminButtonRect(index, pauseY)
    local w, h, gap = 72, 36, 6
    local x = 720 - w - 8
    local y = (pauseY or 8) + 44 + 8 + (index - 1) * (h + gap)
    return x, y, w, h
end

-- Ascending-phase RETURN TO EARTH button. A 48px-tall strip at the bottom
-- of the canvas (above the status message at viewport.height-30=1250).
-- Centered horizontally, 300px wide — comfortably above the 80×44pt mobile
-- minimum and easy to hit with a thumb.
-- Mobile-UI sub-item (7): widened 200→300px, height 44→48px for mobile.
local ascendReturnButton = { top = 1186, bottom = 1234, left = 210, right = 510 }
-- Item 2: ascendReturnButton kept as dead layout constant for backwards
-- compat; the draw/touch code that referenced it is removed.
M.ascendReturnButton = ascendReturnButton

-- Item 2: Earth proximity auto-settle constants.
-- Earth world center is (0, 75); visual radius 58px; settle radius
-- includes a 30px margin matching the gravity/collection range convention.
M.earthCenterX = 0
M.earthCenterY = 75
M.earthVisualRadius = 68  -- 90 * 0.75 (user 2026-09-06)
M.earthSettleRadius = 68
-- Spawn / relaunch outside the settle disk.
M.launchSpawnX = 0
M.launchSpawnY = 75 - 68 - 20  -- -13  (INBOX 23: margin 50→20)
-- INBOX (5)(a): atmospheric reentry starts outside settle range.
M.earthReentryRadius = 145  -- (INBOX 23: shrink from 174)
M.reentryShakeMax = 6

-- INBOX (14): undiscovered-planet collect orbit is a faint thin line.
-- Collection still uses radius+30; only the ring visual is thinned.
M.collectRadiusPadding = 30
M.collectOrbitRingAlpha = 0.3
M.collectOrbitRingLineWidth = 1
M.useCollectOrbitRimSprite = false

function M.collectOrbitRadius(planetRadius, run)
    local base = (planetRadius or 0) + M.collectRadiusPadding
    if run then
        local expedition = require("game.expedition")
        return expedition.collectOrbitRadius(run, base)
    end
    return base
end

function M.reentryDrawOffsetX(time, magnitude)
    return math.sin(time * 60) * (magnitude or 0)
end

function M.reentryShakeFromDistance(dist)
    local radius = M.earthReentryRadius
    if dist >= radius then
        return 0
    end
    if dist <= 0 then
        return M.reentryShakeMax
    end
    return M.reentryShakeMax * (1 - dist / radius)
end

function M.reentryHeatVignetteAlpha(dist)
    local radius = M.earthReentryRadius
    if dist >= radius then
        return 0
    end
    if dist <= 0 then
        return 0.3
    end
    return 0.3 * (1 - dist / radius)
end

local function pulseHaptic(self, intensity)
    -- Sustained rumble, not staccato taps. LÖVE 11 vibrate(seconds);
    -- refresh just before the previous rumble ends so it feels continuous.
    if not love or not love.system or not love.system.vibrate then return end
    local now = self.time or 0
    if now - (self.lastHapticTime or 0) < 0.55 then return end
    self.lastHapticTime = now
    local dur = math.max(0.45, math.min(0.7, (intensity or 0.04) * 8))
    pcall(love.system.vibrate, dur)
end

-- LAUNCH phase's TAP TO LAUNCH touch target. touchpressed for this phase
-- already accepts any tap on the internal canvas regardless of x/y (see the
-- "launch" branch below), so the functional touch target has always spanned
-- the full 180x320 canvas -- far beyond the 44pt accessibility minimum.
-- Named and exposed to close out the last remaining touch surface that was
-- accepted unconditionally but never given an explicit constant or
-- corner-touch regression test, matching destroyedTouchArea's pattern.
local launchTouchArea = { top = 0, bottom = 1280, left = 0, right = 720 }
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
-- Mobile-UI sub-item (1): HUD font enlarged from 8px to 14px; every HUD
-- band height scales proportionally so text lines never overlap and the
-- minimap sits below the taller band.
M.hudFontSize = 22   -- item 41: same font across all phases (was 44 launch-only)
M.hudLineStep = 30   -- item 41: proportional step for 22px font
-- Regression fix (2026-09-02, same feedback item, follow-up capture): the
-- Earth disc drawn behind the scene (center y=75-cameraY for a ship parked
-- at the world origin, radius 58) tops out at y=202, two pixels above the
-- box's previous 204px top -- a real LÖVE runtime capture showed a faint
-- blue crescent peeking out just above the LAUNCH LOADOUT card. Raised the
-- box top to 202 so it fully covers the disc's topmost extent.
M.launchLoadoutBoxTop = 750
M.launchLoadoutRowStep = 32
-- Mobile-UI sub-item (5): loadout font enlarged from 8px to 12px for
-- mobile readability on 720×1280 canvas.
M.launchLoadoutFontSize = 22

-- Mobile-UI sub-item (5): gear slot box dimensions exposed as module
-- constants (1.5× the old 10×14 boxes) for testability.
M.launchGearBoxW = 15
M.launchGearBoxH = 21

-- Shop-planet modal layout (720×1280). Titles use 22px Galmuri with 36px
-- line gaps so Korean HUD font does not collide. Buy/Leave sit centered.


-- HUD gear-slot hitboxes (same math as drawHudGearSlots).
function M.hudGearSlotLayout(hudHeight)
    local slotSize = M.hudGearSlotSize
    local gap = M.hudGearSlotGap
    local groupGap = 8
    local labelY = (hudHeight or 0) + 2
    local gridStartY = labelY + M.hudGearLabelFontSize + 4
    local startX = 5
    local hull = {}
    for i = 1, 6 do
        hull[i] = {
            x = startX,
            y = gridStartY + (i - 1) * (slotSize + gap),
            w = slotSize, h = slotSize,
        }
    end
    local engineLabelY = gridStartY + 6 * (slotSize + gap) + groupGap
    local engineStartY = engineLabelY + M.hudGearLabelFontSize + 4
    local engine = {}
    for i = 1, 3 do
        engine[i] = {
            x = startX,
            y = engineStartY + (i - 1) * (slotSize + gap),
            w = slotSize, h = slotSize,
        }
    end
    return { hull = hull, engine = engine, labelY = labelY, engineLabelY = engineLabelY }
end

function M.hitHudGearSlot(scene, x, y)
    if not scene or not scene.expedition then return nil end
    local hud = scene.hudLines and scene:hudLines() or {}
    local hudHeight = M.hudHeight(scene.expedition.phase, hud, 0)
    local layout = M.hudGearSlotLayout(hudHeight)
    local hullGear = scene.expedition.equippedGear or {}
    local engineGear = scene.expedition.equippedEngineParts or {}
    for i, rect in ipairs(layout.hull) do
        if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
            if hullGear[i] then
                return { part = hullGear[i], category = "hull", index = i, rect = rect }
            end
            return nil
        end
    end
    for i, rect in ipairs(layout.engine) do
        if x >= rect.x and x < rect.x + rect.w and y >= rect.y and y < rect.y + rect.h then
            if engineGear[i] then
                return { part = engineGear[i], category = "engine", index = i, rect = rect }
            end
            return nil
        end
    end
    return nil
end

-- destroyedPanelY/H, destroyedRestartTextY, destroyedKeepPartRects,
-- keepConfirmPopupW/H/BtnH, keepConfirmButtons, rarityRgb, drawBalatroCard
-- → moved to game/scenes/play_gameover.lua (installed on M at top of file)

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
M.hullIconSize = 16   -- item 41: icon size matching 22px font (was 32)
M.hullIconGap = 4     -- item 41: proportional gap (was 8)

-- Item 38c: HP block rendering — small rectangles instead of text status.
M.hpBlockSize = 12    -- 12×12px per HP block
M.hpBlockGap = 3      -- gap between blocks

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
M.cashIconSize = 16   -- item 41: icon size matching 22px font (was 32)
M.cashIconGap = 4     -- item 41: proportional gap (was 8)

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

-- drawMinimapSprite / rimMarker* / galaxyChartLineColor / galaxyChartFillColor
-- → moved to game/scenes/play_minimap.lua (installed on M at top of file)

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

-- Faint thin collect-orbit ring. Opaque rim sprites stay off so the
-- fallback 1px alpha line is what the player sees on mobile.
local function drawCollectOrbitRing(x, y, planetRadius, r, g, b, rimImage)
    local radius = M.collectOrbitRadius(planetRadius)
    local alpha = M.collectOrbitRingAlpha
    if M.useCollectOrbitRimSprite and rimImage then
        if drawPlanetEffectSprite(rimImage, x, y, radius * 2, r, g, b, alpha) then
            return true
        end
    end
    local prevWidth = 1
    if love.graphics.getLineWidth then
        prevWidth = love.graphics.getLineWidth()
    end
    if love.graphics.setLineWidth then
        love.graphics.setLineWidth(M.collectOrbitRingLineWidth)
    end
    love.graphics.setColor(r or 1, g or 1, b or 1, alpha)
    love.graphics.circle("line", x, y, radius)
    if love.graphics.setLineWidth then
        love.graphics.setLineWidth(prevWidth)
    end
    return false
end
M.drawCollectOrbitRing = drawCollectOrbitRing

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
M.hudPrimaryStatusGap = 6   -- item 41: gap matching 22px font (was 12)
M.hudGalaxyShift = 30       -- item 41: one lineStep when galaxy name shown (was 52)

-- docs/feedback/INBOX.md UI/HUD item 5: the returning-phase slot-odds line
-- (C%/P%/S%/AVG$ above the minimap) was removed when item-15(a) abolished
-- in-flight slots. The hudOddsLineHeight that used to reserve 10px for it is
-- no longer needed; the returning HUD band height is now 70 + hudPrimaryStatusGap
-- (same as the ascending phase with returnProgress showing).
-- Constant kept as a zero-read alias for any call site that referenced it,
-- so old assertions that check "hudOddsLineHeight > 0" will need updating to
-- reflect item-15(a). See self_test.lua item-15(a) follow-up assertion.
M.hudOddsLineHeight = 0

-- Shared HUD background-box height so the minimap placement (drawMinimap)
-- and the actual text draw (draw) never disagree about how tall the top
-- HUD band is.
function M.hudHeight(phase, hud, galaxyShift)
    -- Item 38b: one stat per line. Count lines: dist + cash + status = 3 base,
    -- +1 if galaxy, +1 if best. Height = 4 + lines * hudLineStep.
    -- galaxyShift is no longer used (galaxy is counted as a line), kept for API compat.
    local lines = 3  -- distance, cash, status
    if hud and hud.galaxy then lines = lines + 1 end
    if hud and hud.best then lines = lines + 1 end
    return 4 + lines * M.hudLineStep
end

-- INBOX (16): HUD fill is left-text width only (icons + padding), never a
-- full-width 720px black band. hudHeight() still anchors the minimap.
M.hudBackgroundMaxWidth = 280  -- item 41: narrower for 22px font (was 500)
M.hudBackgroundPad = 8

function M.hudBackgroundWidth(hud, font)
    hud = hud or {}
    local function textW(s)
        if not s or s == "" then return 0 end
        if font and font.getWidth then
            return font:getWidth(s)
        end
        return 0
    end
    local icon = M.hullIconSize
    local gap = M.hullIconGap
    local left = 5
    local widest = 0
    local function consider(right)
        if right > widest then widest = right end
    end
    if hud.galaxy then
        consider(left + icon + gap + textW(hud.galaxy))
    end
    -- Item 38b: cash is its own line now, not appended after distance.
    consider(left + icon + gap + textW(hud.distance))
    consider(left + icon + gap + textW(hud.cash))
    -- Item 38c: status uses HP blocks now, so calculate their visual width.
    if hud.maxDurability then
        local blocksW = (hud.maxDurability * M.hpBlockSize) + math.max(0, hud.maxDurability - 1) * M.hpBlockGap
        consider(left + icon + gap + blocksW)
    elseif hud.status then
        consider(left + icon + gap + textW(hud.status))
    end
    if hud.best then
        consider(left + icon + gap + textW(hud.best))
    end
    if hud.earth then
        consider(left + icon + gap + textW(hud.earth))
    end
    if hud.returnProgress then
        consider(left + icon + gap + textW(hud.returnProgress))
    end
    local w = widest + M.hudBackgroundPad
    if w > M.hudBackgroundMaxWidth then
        return M.hudBackgroundMaxWidth
    end
    return w
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
-- Mobile-UI sub-item (4): columns widened for 720px canvas + 12px font.
-- Action column takes the left ~60%, status the right ~40%.
local shopActionColumnX, shopActionColumnW = 24, 400
local shopStatusColumnX, shopStatusColumnW = 430, 260
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
-- Mobile-UI sub-item (4): split columns widened for 720px canvas + 12px font.
-- Each half is ~330px wide within the 696px panel.
local shopColumnLeftX, shopColumnLeftW = 24, 330
local shopColumnRightX, shopColumnRightW = 370, 320
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
    if love.filesystem and love.filesystem.newFile then
        local file = love.filesystem.newFile(path)
        local ok, err = file:open("r")
        if ok then
            data = file:read(33)
            file:close()
        end
    end
    if not data then
        local handle = io.open(path, "rb")
        if handle then
            data = handle:read(33)
            handle:close()
        end
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

-- Part icon cache: loads assets/part_icons/<id>.png on first access.
local partIconCache = {}
local function getPartIcon(partId)
    if not partId then return nil end
    if partIconCache[partId] ~= nil then
        return partIconCache[partId] or nil
    end
    local img = loadSprite("assets/part_icons/" .. partId .. ".png")
    partIconCache[partId] = img or false
    return img
end
M.getPartIcon = getPartIcon

-- Deterministic per-planet visual variation from planet.id.
-- Returns rotation (radians, 0..2π) and scaleFactor (0.85..1.15).
-- Same id always gives the same result; different ids give different values.
function M.planetVariation(planet)
    if not planet or not planet.id then return 0, 1.0 end
    -- Simple deterministic hash from the planet id string
    local idStr = tostring(planet.id)
    local h = 0
    for i = 1, #idStr do
        h = (h * 31 + idStr:byte(i)) % 65521
    end
    local rotation = (h % 360) * (math.pi / 180)        -- 0..2π
    local scaleFactor = 0.85 + (h % 100) / 100 * 0.30   -- 0.85..1.15
    return rotation, scaleFactor
end

-- Resolve the planet image path based on starType / hub / shop flags.
-- Used by self_test to verify wiring without requiring love.graphics.
function M.planetImagePathForPlanet(planet)
    local ppTypes = { ice = true, lava = true, dry = true, gas = true, earth = true, bare = true }
    -- Hub and shop planets use pp_<starType> when their galaxy has a known starType,
    -- falling back to dedicated planet_hub/planet_shop sprites otherwise.
    if planet.hub then
        if planet.galaxyStarType and ppTypes[planet.galaxyStarType] then
            return "assets/planet/pp_" .. planet.galaxyStarType .. ".png"
        end
        return "assets/planet/planet_hub.png"
    elseif planet.isShop then
        if planet.galaxyStarType and ppTypes[planet.galaxyStarType] then
            return "assets/planet/pp_" .. planet.galaxyStarType .. ".png"
        end
        return "assets/planet/planet_shop.png"
    elseif planet.galaxyStarType and ppTypes[planet.galaxyStarType] then
        return "assets/planet/pp_" .. planet.galaxyStarType .. ".png"
    else
        return "assets/planet/planet_generic.png"
    end
end

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
    ship.x = M.launchSpawnX
    ship.y = M.launchSpawnY
    local altitudeStore = options.bestAltitudeStore or bestAltitudeStore.new()
    local specimenStore = options.collectionStore or collectionStore.new()
    if love.graphics then
        love.graphics.setFont(fonts.get(22))
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
    local slotMachineImagePath = "assets/slot_symbols/machine.png"
    local slotSymbolImagePaths = {
        MONEY = "assets/slot_symbols/money.png",
        PART = "assets/slot_symbols/part.png",
        SPEED = "assets/slot_symbols/speed.png",
        DURABILITY = "assets/slot_symbols/durability.png",
        HARVEST = "assets/slot_symbols/harvest.png",
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
    local slotSpinButtonImagePath     = "assets/slot_symbols/spin_button.png"
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
    -- PixelPlanets per-starType sprites (INBOX 12 wiring)
    local ppPlanetImagePaths = {
        ice   = "assets/planet/pp_ice.png",
        lava  = "assets/planet/pp_lava.png",
        dry   = "assets/planet/pp_dry.png",
        gas   = "assets/planet/pp_gas.png",
        earth = "assets/planet/pp_earth.png",
        bare  = "assets/planet/pp_bare.png",
    }
    local ppPlanetImages = loadSpriteMap(ppPlanetImagePaths)
    -- Central star sprites per starType (PIL gen_stars.py)
    local starImagePaths = {
        sun   = "assets/star/star_sun.png",
        ice   = "assets/star/star_ice.png",
        lava  = "assets/star/star_lava.png",
        dry   = "assets/star/star_dry.png",
        gas   = "assets/star/star_gas.png",
        bare  = "assets/star/star_bare.png",
    }
    local starTypeImages = loadSpriteMap(starImagePaths)
    -- Rotation sprite sheets (4 frames, 64x256 vertical strip)
    local starSheetPaths = {
        sun   = "assets/star/star_sun_sheet.png",
        ice   = "assets/star/star_ice_sheet.png",
        lava  = "assets/star/star_lava_sheet.png",
        dry   = "assets/star/star_dry_sheet.png",
        gas   = "assets/star/star_gas_sheet.png",
        bare  = "assets/star/star_bare_sheet.png",
    }
    local starSheetImages = loadSpriteMap(starSheetPaths)
    local planetSheetPaths = {
        ice   = "assets/planet/pp_ice_sheet.png",
        lava  = "assets/planet/pp_lava_sheet.png",
        dry   = "assets/planet/pp_dry_sheet.png",
        gas   = "assets/planet/pp_gas_sheet.png",
        earth = "assets/planet/pp_earth_sheet.png",
        bare  = "assets/planet/pp_bare_sheet.png",
    }
    local planetSheetImages = loadSpriteMap(planetSheetPaths)
    local hubSheetImage = loadSprite("assets/planet/hub_sheet.png")
    local scoutShipImage = loadSprite(scoutShipImagePath)
    local shipSilhouetteImage = loadSprite(shipSilhouetteImagePath)
    local slotMachineImage = loadSprite(slotMachineImagePath)
    local slotSymbolImages = loadSpriteMap(slotSymbolImagePaths)
    local shopIconImages = loadSpriteMap(shopIconImagePaths)
    local debrisImages = loadSpriteMap(debrisImagePaths)
    local moonImage = loadSprite("assets/moon/moon_generic.png")
    local cometImage = loadSprite("assets/comet/comet_generic.png")
    local suitIconImages = loadSpriteMap({
        solar = "assets/suit_icons/solar.png",
        nebula = "assets/suit_icons/nebula.png",
        void = "assets/suit_icons/void.png",
        pulsar = "assets/suit_icons/pulsar.png",
    })
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
        orbitRing      = "assets/effects/minimap_orbit_ring.png",
        galaxyRing     = "assets/effects/minimap_galaxy_ring.png",
    })
    -- HUD icon images (group 1 of ComfyUI asset wiring)
    local hudIconImages = loadSpriteMap({
        cash     = "assets/hud/icon_cash.png",
        hull     = "assets/hud/icon_durability.png",
        speed    = "assets/effects/hud_speed.png",
        distance = "assets/hud/icon_distance.png",
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
        ppPlanetImages = ppPlanetImages,
        ppPlanetImagePaths = ppPlanetImagePaths,
        starTypeImages = starTypeImages,
        starImagePaths = starImagePaths,
        starSheetImages = starSheetImages,
        planetSheetImages = planetSheetImages,
        hubSheetImage = hubSheetImage,
        scoutShipImage = scoutShipImage,
        scoutShipImagePath = scoutShipImagePath,
        shipSilhouetteImage = shipSilhouetteImage,
        shipSilhouetteImagePath = shipSilhouetteImagePath,
        slotMachineImage = slotMachineImage,
        slotSymbolImages = slotSymbolImages,
        slotSymbolImagePaths = slotSymbolImagePaths,
        shopIconImages = shopIconImages,
        shopIconImagePaths = shopIconImagePaths,
        debrisImages = debrisImages,
        debrisImagePaths = debrisImagePaths,
        moonImage = moonImage,
        cometImage = cometImage,
        suitIconImages = suitIconImages,
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
        reentryShake = 0,
        touches = {},
        rcsCooldown = 0,
        message = i18n.t("launch_tap_to_launch"),
        -- Item 15(b): Earth shop slot state. Holds the last earthSlotSpin
        -- result during the settlement phase so draw() can render it.
        earthShopSlotResult = nil,
        -- Item 7(c): Earth shop gear offer. Rolled once on settlement entry;
        -- cleared on purchase or relaunch.
        earthShopGearOffer = nil,
        -- Item 9: Central star gravity well state
        starWellTimer = 0,        -- continuous seconds inside the well
        starDotAccum = 0,         -- accumulator for DoT ticks
        starWellSampled = {},     -- galaxyId → true once sample awarded
        starWellShake = 0,        -- gentle continuous shake while in well
        starWellHeatAlpha = 0,    -- red vignette while sampling the central star
        hubHeatAlpha = 0,         -- green vignette approaching a hub checkpoint
        lastHapticTime = 0,
        earthHapticFired = false,
        gearPopup = nil,          -- equipped-part detail popup {part, category}
        distanceMilestone = 0,    -- last 1000-step milestone reached
        distanceMilestoneFlash = 0, -- flash timer for milestone effect
        hasLeftEarth = false,     -- must leave Earth disk before auto-settle
        leftEarthTime = 0,       -- time when ship first left Earth disk
        paused = false,           -- Item 18: pause toggle (ascending only)
        boostActive = nil,        -- { timer, speedMultiplier } when boost is active
        -- INBOX (35): comet state
        cometDiscovered = {},     -- comet.id → true
        cometCollided = {},       -- comet.id → true
        cometTailParticles = {},  -- tail trail particles for visual effect
        -- INBOX (37): moon state
        moonDiscovered = {},      -- moon.id → true
        shopVisited = {},         -- shop planet.id → true after a successful buy
        moonCollided = {},        -- moon.id → true
        hoverRow = nil,           -- settlement row being hovered/touched
        hoverCol = nil,           -- "left" or "right" column
        onMainMenu = options.onMainMenu,  -- INBOX 61(21): callback to return to title
    }, M)
end

-- Item 15(c): earthSlotSpin returns rewardProfile as a plain string
-- ("solar"/"fringe"/"void"), not a table. Format it as an uppercase
-- "SOLAR ODDS" badge for the Earth shop slot UI. Returns nil when there
-- is no profile so draw() can skip the badge without a `.name` lookup
-- that would always be nil on a string.
function M.earthSlotProfileLabel(rewardProfile)
    return nil -- removed: user found "SOLAR ODDS" confusing
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
    local saved = self.bestAltitudeStore:save(self.expedition.bestAltitude)
    -- INBOX 61(23) remaining: auto-post score on settle/destroy when best
    -- altitude was updated. Fire-and-forget; silent on server failure.
    if leaderboardClient.isNewBest(self.expedition) then
        leaderboardClient.submitScore("Player", self.expedition.bestAltitude)
    end
    return saved
end

-- Draws equipped gear slots (Item 6): up to 6 hull parts and 3 engine parts
-- displayed as Balatro-style card icons in the launch screen, replacing the
-- old specimen log.
function M:drawGearSlots(y)
    local hullSlots = 6
    local engineSlots = 3
    local boxW = M.launchGearBoxW
    local boxH = M.launchGearBoxH
    local gap = 5
    local groupGap = 12
    
    local run = self.expedition
    local hullGear = run.equippedGear or {}
    local engineGear = run.equippedEngineParts or {}

    local totalWidth = (hullSlots * boxW + (hullSlots - 1) * gap) + groupGap + (engineSlots * boxW + (engineSlots - 1) * gap)
    local startX = math.floor((viewport.width - totalWidth) / 2)
    
    self.tinyFont = self.tinyFont or fonts.get(22)
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
            
            -- Part icon (replaces shield fallback)
            local icon = getPartIcon(part.id)
            if icon then
                love.graphics.setColor(1, 1, 1, 0.8)
                local iw, ih = icon:getDimensions()
                local sc = (math.min(boxW, boxH) - 2) / math.max(iw, ih)
                love.graphics.draw(icon, x + boxW/2, y + boxH/2, 0, sc, sc, iw/2, ih/2)
            end
            
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
            
            -- Part icon (replaces rocket fallback)
            local icon = getPartIcon(part.id)
            if icon then
                love.graphics.setColor(1, 1, 1, 0.8)
                local iw, ih = icon:getDimensions()
                local sc = (math.min(boxW, boxH) - 2) / math.max(iw, ih)
                love.graphics.draw(icon, x + boxW/2, y + boxH/2, 0, sc, sc, iw/2, ih/2)
            end
            
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
    love.graphics.printf(i18n.t("equipped_gear_label"), 0, y - 28, viewport.width, "center")
    love.graphics.setFont(previousFont)
end

function M:collisionRisk(planet)
    local phase = self.expedition.phase
    -- Item 2: returning phase abolished; only ascending has collision risk.
    if phase ~= "ascending" then return nil end
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
    -- Item 2: returning phase abolished; only ascending approach warnings.
    local approaching = phase == "ascending" and planetScreenY >= 40 and planetScreenY < shipScreenY
    if not approaching then return nil end
    return self:collisionRisk(planet)
end

function M:hudDistanceRaw()
    local dx = self.ship.x - M.earthCenterX
    local dy = self.ship.y - M.earthCenterY
    return math.sqrt(dx * dx + dy * dy)
end

function M:hudLines()
    local run = self.expedition
    -- Item 38d: best record shown in all phases (was launch/settlement only).
    local best = i18n.t("hud_personal_best", math.floor(run.bestAltitude or 0))
    -- Item 21: HUD distance = euclidean distance from Earth center to ship.
    local dx = self.ship.x - M.earthCenterX
    local dy = self.ship.y - M.earthCenterY
    local dist = math.sqrt(dx * dx + dy * dy)
    return {
        distance = i18n.t("hud_distance", math.floor(dist)),
        cash = i18n.t("hud_cash", run.money),
        best = best,
        -- docs/feedback/INBOX.md UI/HUD item 4: the launch phase's slot
        -- forecast (S%02d) is always 0 because no return trip has
        -- Item 11: both launch and non-launch phases now use the same
        -- hud_status_no_slots format — the S%02d slot segment was removed
        -- from hud_status since item-15 abolished in-flight slots and
        -- slotOpportunities is always 0 (dead/misleading UI).
        status = i18n.t("hud_status_no_slots", run.durability,
            run.maxDurability, i18n.phaseAbbrev(run.phase)),
        galaxy = (function()
            if run.phase ~= "ascending" and run.phase ~= "launch" then return nil end
            local g = world.galaxyContaining(self.ship.x, self.ship.y)
            if not g then return nil end
            return world.galaxyName(g)
        end)(),
        maxDurability = run.maxDurability,
    }
end


-- INBOX-40: gear slots grid constants for the HUD (below left stats).
-- 32×32px slots, hull 6 + engine 3 = 9 max, horizontal row, with a
-- small "GEAR" label above the grid in 22px font.
M.hudGearSlotSize = 48
M.gearPopupChipVertical = true  -- INBOX 61(7): chips stacked vertically
M.hudGearSlotGap  = 4
M.hudGearLabelFontSize = 22

-- INBOX-40: draw the equipped gear grid below the left HUD stats band.
-- Called from draw() for non-settlement/destroyed phases.
function M:drawHudGearSlots(hudHeight)
    local run = self.expedition
    local hullGear = run.equippedGear or {}
    local engineGear = run.equippedEngineParts or {}
    local hullSlots = 6
    local engineSlots = 3
    local slotSize = M.hudGearSlotSize
    local gap = M.hudGearSlotGap
    local groupGap = 8

    -- Hull label
    self.hudGearLabelFont = self.hudGearLabelFont or fonts.get(M.hudGearLabelFontSize)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(self.hudGearLabelFont)
    local labelY = hudHeight + 2
    love.graphics.setColor(0.5, 0.6, 0.7, 0.7)
    love.graphics.printf(i18n.t("hud_hull_label"), 5, labelY, 200, "left")

    local gridStartY = labelY + M.hudGearLabelFontSize + 4
    local startX = 5

    -- Draw hull gear slots (vertical column)
    for i = 1, hullSlots do
        local y = gridStartY + (i - 1) * (slotSize + gap)
        local part = hullGear[i]
        if part then
            if part.rarity == "legendary" then love.graphics.setColor(1, 0.6, 0, 0.7)
            elseif part.rarity == "rare" then love.graphics.setColor(0.3, 0.6, 1, 0.7)
            elseif part.rarity == "uncommon" then love.graphics.setColor(0.4, 0.8, 0.4, 0.7)
            else love.graphics.setColor(0.5, 0.5, 0.5, 0.7) end
            love.graphics.rectangle("fill", startX, y, slotSize, slotSize)
            -- Part icon (replaces shield fallback)
            local icon = getPartIcon(part.id)
            if icon then
                love.graphics.setColor(1, 1, 1, 0.9)
                local iw, ih = icon:getDimensions()
                local sc = (slotSize - 4) / math.max(iw, ih)
                love.graphics.draw(icon, startX + slotSize/2, y + slotSize/2, 0, sc, sc, iw/2, ih/2)
            end
            love.graphics.setColor(0.1, 0.1, 0.1, 1)
            love.graphics.rectangle("line", startX, y, slotSize, slotSize)
        else
            love.graphics.setColor(0.3, 0.35, 0.45, 0.5)
            love.graphics.rectangle("line", startX, y, slotSize, slotSize)
        end
    end

    -- Engine gear slots (below hull with engine label)
    local engineStartY = gridStartY + hullSlots * (slotSize + gap) + groupGap
    love.graphics.setColor(0.5, 0.6, 0.7, 0.7)
    love.graphics.printf(i18n.t("hud_engine_label"), 5, engineStartY, 200, "left")
    engineStartY = engineStartY + M.hudGearLabelFontSize + 4
    for i = 1, engineSlots do
        local y = engineStartY + (i - 1) * (slotSize + gap)
        local part = engineGear[i]
        if part then
            if part.rarity == "legendary" then love.graphics.setColor(1, 0.6, 0, 0.7)
            elseif part.rarity == "rare" then love.graphics.setColor(0.3, 0.6, 1, 0.7)
            elseif part.rarity == "uncommon" then love.graphics.setColor(0.4, 0.8, 0.4, 0.7)
            else love.graphics.setColor(0.5, 0.5, 0.5, 0.7) end
            love.graphics.rectangle("fill", startX, y, slotSize, slotSize)
            -- Part icon (replaces circle fallback)
            local icon = getPartIcon(part.id)
            if icon then
                love.graphics.setColor(1, 1, 1, 0.9)
                local iw, ih = icon:getDimensions()
                local sc = (slotSize - 4) / math.max(iw, ih)
                love.graphics.draw(icon, startX + slotSize/2, y + slotSize/2, 0, sc, sc, iw/2, ih/2)
            end
            love.graphics.setColor(0.1, 0.1, 0.1, 1)
            love.graphics.rectangle("line", startX, y, slotSize, slotSize)
        else
            love.graphics.setColor(0.3, 0.35, 0.45, 0.5)
            love.graphics.rectangle("line", startX, y, slotSize, slotSize)
        end
    end
    if prevFont then love.graphics.setFont(prevFont) end
end

function M:loadoutLines()
    local run = self.expedition
    -- Stellar Origin sub-item 4: collect active synergy display labels.
    local gearMod = require("game.gear")
    local syn = gearMod.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    -- Ordered list so the display is deterministic.
    local synergyOrder = {
        "solarSystem", "nebulaField", "eventHorizon",
        "pulsarBurst", "binaryStar", "supernova", "darkMatter",
    }
    local synergyLabels = {}
    for _, key in ipairs(synergyOrder) do
        if syn[key] then
            synergyLabels[#synergyLabels + 1] = i18n.t("synergy_" .. key)
        end
    end
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
        steering = i18n.t("steer_speed_line", expedition.effectiveSpeed(run)),
        synergies = synergyLabels,
    }
end


local function purchaseStatus(money, cost)
    if money >= cost then return i18n.t("purchase_left", money - cost), true end
    return i18n.t("purchase_short", cost - money), false
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
    local shipHidden = false
    if not run.ownedShips.scout then
        shipAction = i18n.t("buy_scout", run.scoutShipCost)
        shipActionCompact = i18n.t("buy_scout_compact", run.scoutShipCost)
        shipStatus, shipAffordable = purchaseStatus(run.money, run.scoutShipCost)
        previewShipId = "scout"
    elseif run.selectedShipId == "scout" then
        -- INBOX-30: scout owned+selected → hide ship row entirely
        shipHidden = true
        previewShipId = "scout"
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
        scoutTradeoff = shipHidden and {} or self.scoutTradeoffLines(run),
        shipHidden = shipHidden,
        shipAction = shipAction,
        shipActionCompact = shipActionCompact,
        shipStatus = shipStatus,
        shipAffordable = shipAffordable,
        shipTradeoffLine = (not shipHidden) and i18n.t("scout_tradeoff_compact",
            run.scoutClimbSpeedBonus, run.scoutDurabilityBonus) or "",
        shipPreview = i18n.t("ship_preview_line",
            string.upper(previewShipId), previewDurability),
        shipPreviewCompact = i18n.t("ship_preview_compact",
            string.upper(previewShipId), previewDurability),
        hullAction = i18n.t("hull_action_line",
            run.durabilityUpgradeLevel, run.durabilityUpgradeLevel + 1,
            expedition.upgradeCost(run, run.durabilityUpgradeCost, run.durabilityUpgradeLevel)),
        hullActionCompact = i18n.t("hull_action_compact",
            run.maxDurability, run.maxDurability + run.durabilityUpgradeAmount,
            expedition.upgradeCost(run, run.durabilityUpgradeCost, run.durabilityUpgradeLevel)),
        hullPreview = i18n.t("stats_line",
            run.maxDurability + run.durabilityUpgradeAmount),
        hullPreviewCompact = i18n.t("hull_preview_compact",
            run.maxDurability + run.durabilityUpgradeAmount),
        hullStatus = hullStatus,
        hullAffordable = hullAffordable,
        yieldAction = i18n.t("yield_action_line",
            run.sampleYieldUpgradeLevel, run.sampleYieldUpgradeLevel + 1,
            expedition.upgradeCost(run, run.sampleYieldUpgradeCost, run.sampleYieldUpgradeLevel)),
        yieldActionCompact = i18n.t("yield_action_compact",
            expedition.sampleYieldMultiplier(run),
            1 + (run.sampleYieldUpgradeLevel + 1) * run.sampleYieldUpgradeAmount,
            expedition.upgradeCost(run, run.sampleYieldUpgradeCost, run.sampleYieldUpgradeLevel)),
        yieldPreview = i18n.t("yield_preview_line",
            1 + (run.sampleYieldUpgradeLevel + 1) * run.sampleYieldUpgradeAmount),
        yieldStatus = yieldStatus,
        yieldAffordable = yieldAffordable,
        steeringAction = i18n.t("steering_action_line",
            run.steeringUpgradeLevel, run.steeringUpgradeLevel + 1,
            expedition.upgradeCost(run, run.steeringUpgradeCost, run.steeringUpgradeLevel)),
        steeringActionCompact = i18n.t("steering_action_compact",
            expedition.effectiveSpeed(run),
            expedition.effectiveSpeed(run) + run.steeringUpgradeAmount,
            expedition.upgradeCost(run, run.steeringUpgradeCost, run.steeringUpgradeLevel)),
        steeringPreview = i18n.t("steer_speed_line",
            expedition.effectiveSpeed(run) + run.steeringUpgradeAmount),
        steeringPreviewCompact = i18n.t("steering_preview_compact",
            expedition.effectiveSpeed(run) + run.steeringUpgradeAmount),
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
    if self.expedition.phase ~= "ascending"
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

function M:update(dt)
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
    -- Auto-unpause if phase changed away from ascending while paused.
    if self.paused and self.expedition.phase ~= "ascending" then
        self.paused = false
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

    if self.slotState and self.slotState.spinning then
        local allStopped = true
        for i, r in ipairs(self.slotState.reels) do
            if r.stopping then
                r.speed = math.max(100, r.speed - rawDt * 1500)
                r.y = r.y + r.speed * rawDt
                if r.speed <= 100 then
                    local snap = math.floor(r.y / 32) * 32
                    if math.abs(r.y - snap) < 5 then
                        r.y = snap
                        r.speed = 0
                        r.stopping = false
                        r.stopped = true
                        pcall(love.system.vibrate, 0.03)
                        self.slotShake = 0.15
                        -- Short sparkles
                        for k = 1, 3 do
                            self.particles[#self.particles + 1] = {
                                x = viewport.width / 2 + (i - 2) * 45 + (math.random() - 0.5) * 20,
                                y = M.settlementTouchRows[4].top + 20 + (math.random() - 0.5) * 20,
                                vx = (math.random() - 0.5) * 40,
                                vy = (math.random() - 0.5) * 40,
                                timer = 0.3 + math.random() * 0.2,
                                maxTimer = 0.5,
                                r = 1, g = 0.9, b = 0.5,
                                radius = 2 + math.random() * 2,
                                hud = true,
                            }
                        end
                    end
                end
                allStopped = false
            elseif not r.stopped then
                r.y = r.y + r.speed * rawDt
                allStopped = false
            end
        end
        if allStopped then
            self.slotState.spinning = false
            local result = self.earthShopSlotResult
            if result then
                local rt = result.rewardType or "money"
                local rv = result.rewardValue or 0
                local won = rt ~= "money" or rv > 0
                if rt == "money" then
                    self.expedition.money = self.expedition.money + result.reward
                    if result.reward > 0 then
                        self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n+$" .. result.reward
                    else
                        self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n꽝"
                    end
                elseif rt == "speed" then
                    self.expedition.slotSpeedBonus = (self.expedition.slotSpeedBonus or 0) + rv
                    self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n속도 +" .. rv
                elseif rt == "durability" then
                    self.expedition.durabilityUpgradeLevel = (self.expedition.durabilityUpgradeLevel or 0) + rv
                    self.expedition.maxDurability = (self.expedition.maxDurability or 3) + rv
                    self.expedition.durability = math.min(self.expedition.durability + rv, self.expedition.maxDurability)
                    self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n내구 +" .. rv
                elseif rt == "harvest" then
                    self.expedition.sampleYieldUpgradeLevel = (self.expedition.sampleYieldUpgradeLevel or 0) + 1
                    self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n수확 +" .. string.format("%.2f", rv)
                elseif rt == "part" then
                    local drop = result.rewardPart
                    if drop then
                        local alreadyEquipped = false
                        for _, p in ipairs(self.expedition.equippedGear or {}) do
                            if p.id == drop.id then alreadyEquipped = true; break end
                        end
                        for _, p in ipairs(self.expedition.equippedEngineParts or {}) do
                            if p.id == drop.id then alreadyEquipped = true; break end
                        end
                        local spinCost = expedition.slotSpinCostFor(self.expedition, self.expedition.lastVisitedGalaxyId)
                        if alreadyEquipped then
                            self.expedition.money = self.expedition.money + spinCost
                            self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n" .. i18n.partName(drop) .. "\n(중복 환불 +$" .. spinCost .. ")"
                        else
                            local gearMod = require("game.gear")
                            local engineParts = require("game.engine_parts")
                            local isEngine = gearMod.findById(gearMod.loadEngineParts() or {}, drop.id)
                            local cat = isEngine and "engine" or "hull"
                            local isFull = (cat == "hull" and engineParts.isFull(self.expedition.gearLoadout, "hull"))
                                or (cat == "engine" and engineParts.isFull(self.expedition.gearLoadout, "engine"))
                            
                            if isFull then
                                self.shopModal = { gear = drop, category = cat, price = 0, isReplacement = true }
                                self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n" .. i18n.partName(drop) .. "\n(교체 대기중)"
                            else
                                local ok = expedition.equipGear(self.expedition, cat, drop)
                                if ok then
                                    self.gearPopup = { part = drop, category = cat }
                                end
                                self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n" .. i18n.partName(drop)
                            end
                        end
                    else
                        self.slotResultMessage = table.concat(result.symbols, "  ") .. "\n부품 획득 실패!"
                    end
                end
                if won then
                    pcall(love.system.vibrate, 0.12)
                    self.slotShake = 0.3
                    for k = 1, 8 do
                        self.particles[#self.particles + 1] = {
                            x = viewport.width / 2 + (math.random() - 0.5) * 160,
                            y = (M.settlementTouchRows[4].top or 600) + 40,
                            vx = (math.random() - 0.5) * 80,
                            vy = -40 - math.random() * 50,
                            timer = 0.7 + math.random() * 0.3,
                            maxTimer = 1.0,
                            r = 1, g = 0.85, b = 0.2,
                            radius = 2 + math.random() * 2,
                            hud = true,
                        }
                    end
                else
                    pcall(love.system.vibrate, 0.04)
                end
            end
        end
    end
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
        if wellGalaxy then sfx.play("galaxy_discover", wellGalaxy.id) end
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
        local dx = self.ship.x - M.earthCenterX
        local dy = self.ship.y - M.earthCenterY
        local earthDistSq = dx * dx + dy * dy
        local earthDist = math.sqrt(earthDistSq)
        self.reentryShake = M.reentryShakeFromDistance(earthDist)
        self.reentryHeatAlpha = M.reentryHeatVignetteAlpha(earthDist)
        -- Vibrate once when first entering Earth proximity, not every frame
        if self.reentryHeatAlpha > 0.04 then
            if not self.earthHapticFired then
                self.earthHapticFired = true
                pulseHaptic(self, 0.06)
            end
        else
            self.earthHapticFired = false
        end

        -- M.earthVisualRadius * 1.5 is 87, but settle is 88. To trigger BEFORE settle,
        -- use a slightly larger radius, e.g. M.earthSettleRadius + 15 (103).
        if not self.hasReentrySlowmo and earthDist < M.earthSettleRadius + 15 then
            self.hasReentrySlowmo = true
            self.timeSlip = {timer = 0.6, scale = 0.5}
        end

        if earthDistSq > M.earthSettleRadius * M.earthSettleRadius then
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
                and distanceSquared <= (M.collectOrbitRadius(planet.radius, self.expedition)) ^ 2
                and not self.discovered[planet.id] then
                self.discovered[planet.id] = true
                self.discoveredCount = self.discoveredCount + 1

                if planet.hub then
                    -- INBOX (47): hub planets open full settlement shop.
                    -- 1. exploreHub for gear drop (before settlement changes phase)
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
                self.message = i18n.t("collision_message", damage, self.expedition.durability, self.expedition.maxDurability)
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
                        self.message = i18n.t("collision_message", damage, self.expedition.durability, self.expedition.maxDurability)
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
                if distanceSquared <= (M.collectOrbitRadius(comet.radius, self.expedition)) ^ 2
                    and not self.cometDiscovered[comet.id] then
                    self.cometDiscovered[comet.id] = true
                    local value = world.cometSampleValue(comet)
                    local _, awarded = expedition.collectSample(self.expedition, value, "ember")
                    awarded = awarded or value
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
                    self.message = i18n.t("collision_message", damage, self.expedition.durability, self.expedition.maxDurability)
                end
            end
        end
        for _, junk in ipairs(world.nearbyDebris(self.ship.x, self.ship.y, 4, self.time)) do
            local dx, dy = junk.x - self.ship.x, junk.y - self.ship.y
            if dx * dx + dy * dy <= (junk.radius + 5) ^ 2 and not self.collided[junk.id] then
                self.collided[junk.id] = true
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

function M:keypressed(key)
    if self.gearPopup then
        if key == "escape" or key == "n" or key == "space" then
            self.gearPopup = nil
        end
        return
    end
    if self.shopModal then
        if key == "y" then
            local ok, err = expedition.buyGearFromShopPlanet(self.expedition, self.shopModal.category, self.shopModal.gear)
            if ok then
                -- Show Balatro-style part detail popup on purchase
                self.gearPopup = { part = self.shopModal.gear, category = self.shopModal.category }
                table.insert(self.floatingTexts, {
                    text = i18n.t("floating_hub_gear", i18n.partName(self.shopModal.gear)),
                    x = self.shopModal.planet.x,
                    y = self.shopModal.planet.y + 20,
                    timer = 3.0,
                    kind = "sample",
                    awarded = 0,
                    rollupElapsed = 0,
                })
                self.shopVisited[self.shopModal.planet.id] = true
                self.shopModal = nil
            else
                self.shopModal.errorText = i18n.shopError(err)
            end
        elseif key == "n" then
            self.shopModal = nil
        end
        return
    end
    if self.expedition.phase == "settlement" and (key == "h" or key == "right" or key == "d") then
        expedition.buyDurabilityUpgrade(self.expedition)
        self.message = "" -- shop cards already show values (user 2026-09-07)
        return
    end
    if self.expedition.phase == "settlement" and key == "y" then
        expedition.buySampleYieldUpgrade(self.expedition)
        self.message = ""
        return
    end
    if self.expedition.phase == "settlement" and key == "g" then
        expedition.buySteeringUpgrade(self.expedition)
        self.message = ""
        return
    end
    if self.expedition.phase == "settlement" and key == "v" then
        if not self.expedition.ownedShips.scout then
            if expedition.buyShip(self.expedition, "scout") then
                expedition.selectShip(self.expedition, "scout")
            end
        elseif self.expedition.selectedShipId ~= "scout" then
            expedition.selectShip(self.expedition, "scout")
        end
        self.message = ""
        return
    end
    -- Item 15(b): Earth shop slot machine. "l" triggers a slot spin during
    -- settlement using the galaxy-aware earthSlotSpin pure function (item 15(c)).
    -- Spin costs expedition.slotSpinCostFor(run, galaxyId) up front; miss reward is 0 so a
    -- miss is a real loss. Reward is applied after the cost is deducted.
    if self.expedition.phase == "settlement" and key == "l" then
        if self.slotState and self.slotState.spinning then
            if self.slotState.stopNext then self.slotState:stopNext() end
            return
        end
        local spinCost = expedition.slotSpinCostFor(self.expedition, self.expedition.lastVisitedGalaxyId)
        if self.expedition.money < spinCost then
            self.message = i18n.t("earth_slot_broke", spinCost - self.expedition.money)
            return
        end
        local reels = {}
        local tw = expedition.earthSlotTotalWeight(self.expedition, self.expedition.lastVisitedGalaxyId)
        for i = 1, 3 do reels[i] = math.random(0, tw - 1) end
        local result = expedition.earthSlotSpin(self.expedition, self.expedition.lastVisitedGalaxyId, {
            reels = reels,
            partRarity = math.random(),
            partPick = math.random(),
            partEditionChance = math.random(),
            partEditionPick = math.random()
        })
        self.earthShopSlotResult = result
        self.expedition.money = self.expedition.money - spinCost
        pcall(love.system.vibrate, 0.05)
        self.slotShake = 0.1
        self.slotLeverPull = 1.0  -- lever pull animation
        self.slotState = {
            spinning = true,
            startTime = self.time or 0,
            stopIndex = 1,
            reels = {
                { y = 0, speed = 800, stopping = false, stopped = false, sym = result.symbols[1] },
                { y = 0, speed = 1000, stopping = false, stopped = false, sym = result.symbols[2] },
                { y = 0, speed = 1200, stopping = false, stopped = false, sym = result.symbols[3] }
            },
            stopNext = function(st)
                if st.stopIndex <= 3 then
                    st.reels[st.stopIndex].stopping = true
                    st.stopIndex = st.stopIndex + 1
                end
            end
        }
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
    -- INBOX 61(16): hub restock — re-roll gear offer at hub settlement
    if self.expedition.phase == "settlement" and key == "r" then
        if self.expedition.lastVisitedGalaxyId and not self.earthShopGearOffer then
            local gearMod = require("game.gear")
            local hull = gearMod.loadHullParts() or {}
            local engine = gearMod.loadEngineParts() or {}
            local pool = {}
            for _, p in ipairs(hull) do
                if not p.slotExclusive then pool[#pool+1] = p end
            end
            for _, p in ipairs(engine) do
                if not p.slotExclusive then pool[#pool+1] = p end
            end
            local rolls = {
                rarity = math.random(),
                pick = math.random(),
                editionChance = math.random(),
                editionPick = math.random(),
            }
            local ok, offer = expedition.hubRestock(self.expedition, pool, rolls)
            if ok then
                self.earthShopGearOffer = offer
                self.message = ""
            else
                self.message = offer or "RESTOCK FAILED"
            end
        end
        return
    end
    if key == "space" or key == "return" or key == "up" or key == "w" then
        -- Item 15(a): in-flight slot machine removed. Space/return during
        -- returning phase no longer triggers a slot spin. Settlement happens
        -- automatically when altitude reaches 0 (expedition.update).
        local relaunching = self.expedition.phase == "settlement" or self.expedition.phase == "destroyed"
        -- INBOX (47): capture hub position before launch clears it
        local hubX = self.expedition.lastHubX
        local hubY = self.expedition.lastHubY
        -- INBOX 61(24): capture checkpoint position before launch clears hub fields
        local wasDestroyed = self.expedition.phase == "destroyed"
        local cpX, cpY = expedition.lastCheckpointOrEarth(self.expedition)
        if expedition.launch(self.expedition) then
            if relaunching then
                if wasDestroyed then
                    -- INBOX 61(24): after destruction, respawn at last checkpoint
                    -- (could be a hub or Earth). The checkpoint is preserved
                    -- across destroy, unlike lastHubX/Y which is wiped.
                    if cpX == 0 and cpY == 75 then
                        -- Earth checkpoint: use standard launch spawn
                        self.ship.x = M.launchSpawnX
                        self.ship.y = M.launchSpawnY
                        self.hasLeftEarth = false
                    else
                        -- Hub checkpoint: spawn near the checkpoint
                        self.ship.x = cpX
                        self.ship.y = cpY - 80
                        self.hasLeftEarth = true
                    end
                elseif hubX and hubY then
                    -- Relaunch near the hub planet in the same galaxy
                    self.ship.x = hubX
                    self.ship.y = hubY - 80  -- spawn outside the hub collectOrbitRadius
                    self.hasLeftEarth = true  -- already away from Earth
                else
                    self.ship.x = M.launchSpawnX
                    self.ship.y = M.launchSpawnY
                    self.hasLeftEarth = false
                end
                self.discovered = {}
                self.collided = {}
                self.discoveredCount = 0
                self.floatingTexts = {}
                self.earthShopSlotResult = nil
                self.earthShopGearOffer = nil
                -- INBOX (35): reset comet state on relaunch
                self.cometDiscovered = {}
                self.cometCollided = {}
                self.cometTailParticles = {}
                -- INBOX (37): reset moon state on relaunch
                self.moonDiscovered = {}
                self.moonCollided = {}
                world.resetComets(self.time)
            end
            self.message = ""
        end
    end
    -- Item 2: Return-to-Earth 'r' keybinding removed. Direct steering only.
end

-- Mobile-UI sub-item (3): when a touch starts inside the fixed joystick
-- anchor zone, snap its origin to the anchor so the pad stays in a
-- predictable bottom-left position.
local function joystickOrigin(x, y)
    local dx = x - joystick.anchorX
    local dy = y - joystick.anchorY
    if dx * dx + dy * dy <= joystick.touchZoneRadius * joystick.touchZoneRadius then
        return joystick.anchorX, joystick.anchorY
    end
    return x, y
end


function M:touchpressed(id, x, y)
    if self.gearPopup then
        -- Check if tapping another gear slot → switch popup instead of closing
        local hit = M.hitHudGearSlot(self, x, y)
        if hit then
            hit.slotRect = hit.rect
            self.gearPopup = hit
            pcall(love.system.vibrate, 0.02)
        else
            self.gearPopup = nil
        end
        return
    end
    if self.shopModal then
        local slotHit = M.hitShopModalGearSlot(self, x, y)
        if slotHit and self.shopModal.isReplacement and slotHit.category == self.shopModal.category then
            -- Replace gear
            pcall(love.system.vibrate, 0.05)
            local expeditionMod = require("game.expedition")
            local list = slotHit.category == "engine" and self.expedition.equippedEngineParts or self.expedition.equippedGear
            table.remove(list, slotHit.index)
            expeditionMod.equipGear(self.expedition, slotHit.category, self.shopModal.gear)
            self.shopModal = nil
            self.slotResultMessage = (self.slotResultMessage or "") .. "\n(교체 완료)"
            return
        end

        local buy, skip = M.shopModalButtonRects()
        if not self.shopModal.isReplacement and x >= buy.x and x < buy.x + buy.w and y >= buy.y and y < buy.y + buy.h then
            pcall(love.system.vibrate, 0.02)
            self:keypressed("y")
        elseif x >= skip.x and x < skip.x + skip.w and y >= skip.y and y < skip.y + skip.h then
            pcall(love.system.vibrate, 0.02)
            if self.shopModal.isReplacement then self.shopModal = nil end
            self:keypressed("n")
        end
        return
    end
    if self.expedition.phase == "ascending" then
        -- Item 18: pause button check (top-right corner).
        local pb = pauseButton
        if x >= pb.x and x < pb.x + pb.w and y >= pb.y and y < pb.y + pb.h then
            self.paused = not self.paused
            pcall(love.system.vibrate, 0.02)
            return
        end
        for i, btn in ipairs(adminButtons) do
            local ax, ay, aw, ah = adminButtonRect(i, pb.y)
            if x >= ax and x < ax + aw and y >= ay and y < ay + ah then
                expedition.adminUpgrade(self.expedition, btn.kind)
                return
            end
        end
        local hit = M.hitHudGearSlot(self, x, y)
        if hit then
            -- Balatro: tapping another slot switches instantly
            hit.slotRect = hit.rect
            self.gearPopup = hit
            pcall(love.system.vibrate, 0.02)
            return
        end
        -- If paused, check pause menu buttons first, then unpause.
        if self.paused then
            local rects = M.pauseMenuRects()
            -- Restart button
            if x >= rects.restart.x and x < rects.restart.x + rects.restart.w
                and y >= rects.restart.y and y < rects.restart.y + rects.restart.h then
                self.paused = false
                expedition.launch(self.expedition)
                self.ship.x = M.launchSpawnX
                self.ship.y = M.launchSpawnY
                self.expedition.phase = "launch"
                self.floatingTexts = {}
                self.particles = {}
                pcall(love.system.vibrate, 0.05)
                return
            end
            -- Main menu button
            if x >= rects.mainMenu.x and x < rects.mainMenu.x + rects.mainMenu.w
                and y >= rects.mainMenu.y and y < rects.mainMenu.y + rects.mainMenu.h then
                self.paused = false
                if self.onMainMenu then self.onMainMenu() end
                pcall(love.system.vibrate, 0.05)
                return
            end
            self.paused = false
            return
        end
        local ox, oy = joystickOrigin(x, y)
        -- Boost button: tap right side of screen (above joystick zone, below minimap)
        if x > viewport.width * 0.6 and y > viewport.height * 0.5 and expedition.boostsRemaining(self.expedition) > 0 and not self.boostActive then
            local ok = expedition.spendBoost(self.expedition)
            if ok then
                self.boostActive = { timer = 0.8, speedMultiplier = 3.0 }
                pcall(love.system.vibrate, 0.1)
                return
            end
        end
        self.touches[id] = { x = x, y = y, originX = ox, originY = oy }
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
                elseif key == "gear" then
                    -- INBOX 61(16): hub restock when no active gear offer
                    if self.expedition.lastVisitedGalaxyId and not self.earthShopGearOffer then
                        self:keypressed("r")
                    else
                        self:keypressed("b")
                    end
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
        local hit = M.hitHudGearSlot(self, x, y)
        if hit then
            -- Balatro: tapping another slot switches instantly
            hit.slotRect = hit.rect
            self.gearPopup = hit
            pcall(love.system.vibrate, 0.02)
            return
        end
        self:keypressed("space")
        return
    end
    if self.expedition.phase == "destroyed" then
        M.handleDestroyedTouch(self, x, y)
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
    local radius = joystick.visualRadius
    local knob = joystick.visualKnobRadius
    -- No ghost pad when not dragging — joystick only appears on touch
    if not ox then return end
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

-- drawMinimap + drawShipStatsSummary → game/scenes/play_minimap.lua


function M:draw()
    local galaxy = world.galaxyContaining(self.ship.x, self.ship.y)
    love.graphics.clear(world.galaxyBackgroundColor(galaxy))
    local shipScreenX, shipScreenY = viewport.width / 2, math.floor(viewport.height * 0.58)
    local cameraX, cameraY = self.ship.x - shipScreenX, self.ship.y - shipScreenY
    -- INBOX (24)(a): zoom-in on sample collect
    local collectZoomScale = 1
    local collectZoomFocusX, collectZoomFocusY = shipScreenX, shipScreenY
    if self.collectZoom then
        local t = self.collectZoom.timer / 0.5  -- 1 → 0
        collectZoomScale = 1 + (self.collectZoom.scale - 1) * t
        local planetSX = self.collectZoom.planetX - cameraX
        local planetSY = self.collectZoom.planetY - cameraY
        collectZoomFocusX = (shipScreenX + planetSX) / 2
        collectZoomFocusY = (shipScreenY + planetSY) / 2
    end
    if collectZoomScale ~= 1 then
        love.graphics.push()
        love.graphics.translate(collectZoomFocusX, collectZoomFocusY)
        love.graphics.scale(collectZoomScale, collectZoomScale)
        love.graphics.translate(-collectZoomFocusX, -collectZoomFocusY)
    end
    -- Background image disabled: deep_space_tile.png is not seamless, causing
    -- visible grid lines at edges. Using procedural star layers only.
    -- if self.backgroundImage then ... end
    local sx, sy = world.sectorAt(self.ship.x, self.ship.y)
    -- Galaxy shared star type: all special stars inside the same galaxy use the same frame.
    -- starTypeIdx is 0-based (0..5) matching the 6 frames of pixelplanets_stars_special.png.
    local galaxySpecialFrame = galaxy and galaxy.starTypeIdx or 0
    -- UI/HUD cleanup item 1 (docs/feedback/INBOX.md, 2026-09-02): a dense,
    -- near-static background star layer drawn behind the streaking-meteor
    -- foreground layer below. Reduced parallax (0.4x camera motion) makes
    -- it read as a distant, almost-still Milky Way backdrop rather than
    -- more meteors, and dim/small points keep it from competing visually
    -- with the foreground streaks or gameplay elements.
    local bgCameraX, bgCameraY = cameraX * 0.4, cameraY * 0.4
    local bsx, bsy = world.sectorAt(bgCameraX, bgCameraY)
    local bgScanR = math.max(4, math.ceil(viewport.height / 2 / world.sectorSize) + 2)
    for oy = -bgScanR, bgScanR do
        for ox = -bgScanR, bgScanR do
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
                        -- Special pixel star: 6 frames, 25x25 each, size 4-5px, golden.
                        -- All special stars in the same galaxy share the same frame (starType).
                        local frameIdx = galaxySpecialFrame
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
    local fgScanR = math.max(4, math.ceil(viewport.height / 2 / world.sectorSize) + 2)
    for oy = -fgScanR, fgScanR do
        for ox = -fgScanR, fgScanR do
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
                        -- Special pixel star: size 5-6px, golden.
                        -- All special stars in the same galaxy share the same frame (starType).
                        local frameIdx = galaxySpecialFrame
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
            local scale = (M.earthVisualRadius * 2) / math.max(imgW, imgH)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(self.earthImage, earthX, earthY, 0, scale, scale, imgW / 2, imgH / 2)
        else
            love.graphics.setColor(0.15, 0.45, 0.9)
            love.graphics.circle("fill", earthX, earthY, M.earthVisualRadius)
            love.graphics.setColor(0.25, 0.8, 0.45)
            love.graphics.circle("fill", earthX - 18, earthY - 18, 15)
            love.graphics.circle("fill", earthX + 21, earthY - 5, 12)
        end
        local prevEarthFont = love.graphics.getFont()
        love.graphics.setFont(fonts.get(11))
        local sell = i18n.t("checkpoint_hint_sell")
        local repair = i18n.t("checkpoint_hint_repair")
        local upgrade = i18n.t("checkpoint_hint_upgrade")
        local bob = math.sin(self.time * 2) * 3
        local f = love.graphics.getFont()
        local lineH = 14
        -- Hints always below Earth/hub body (user 2026-09-07)
        local topY = earthY + M.earthVisualRadius + 8 + bob
        love.graphics.setColor(0.65, 0.68, 0.72, 0.7)
        love.graphics.print(sell, earthX - f:getWidth(sell) / 2, topY)
        love.graphics.print(repair, earthX - f:getWidth(repair) / 2, topY + lineH)
        love.graphics.print(upgrade, earthX - f:getWidth(upgrade) / 2, topY + lineH * 2)
        love.graphics.setFont(prevEarthFont)
    end
    -- Item 9: Draw star gravity well ring around the central star
    do
        local wellGalaxy = world.galaxyContaining(self.ship.x, self.ship.y)
        local wellSun = wellGalaxy and world.sunPosition(wellGalaxy)
        if wellSun then
            local sx, sy = math.floor(wellSun.x - cameraX), math.floor(wellSun.y - cameraY)
            if sx > -world.starWellRadius - 10 and sx < viewport.width + world.starWellRadius + 10
                and sy > -world.starWellRadius - 10 and sy < viewport.height + world.starWellRadius + 10 then
                -- Orange/red well ring
                local pulse = 0.6 + 0.15 * math.sin(self.time * 3)
                love.graphics.setColor(1.0, 0.45, 0.15, pulse * 0.35)
                love.graphics.circle("line", sx, sy, world.starWellRadius)
                love.graphics.setColor(1.0, 0.25, 0.1, pulse * 0.15)
                love.graphics.circle("line", sx, sy, world.starWellRadius * 0.7)
                -- Inner glow
                love.graphics.setColor(1.0, 0.85, 0.25, pulse * 0.08)
                -- Draw star sprite: prefer rotation sheet (4-frame), fallback to static
                local starType = (wellGalaxy and wellGalaxy.starType) or "sun"
                local starSheet = self.starSheetImages and self.starSheetImages[starType]
                if starSheet then
                    local sw, sh = starSheet:getDimensions()
                    local frameH = sw  -- each frame is sw x sw (64x64 in a 64x256 sheet)
                    local frameCount = math.floor(sh / frameH)
                    local frameIdx = math.floor((self.time or 0) * 2) % frameCount
                    local quad = love.graphics.newQuad(0, frameIdx * frameH, sw, frameH, sw, sh)
                    local starScale = (world.starRadius * 2) / sw
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(starSheet, quad, sx - world.starRadius, sy - world.starRadius, 0, starScale, starScale)
                else
                    local starImg = self.starTypeImages and self.starTypeImages[starType]
                    if not starImg and self.starTypeImages then starImg = self.starTypeImages["sun"] end
                    if starImg then
                        local iw, ih = starImg:getDimensions()
                        local starScale = (world.starRadius * 2) / math.max(iw, ih)
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(starImg, sx, sy, 0, starScale, starScale, iw / 2, ih / 2)
                    else
                        love.graphics.circle("fill", sx, sy, world.starRadius)
                    end
                end
                -- INBOX 61(22): "DANGER" blinking red text near the well boundary
                do
                    local sdx = wellSun.x - self.ship.x
                    local sdy = wellSun.y - self.ship.y
                    local shipDist = math.sqrt(sdx * sdx + sdy * sdy)
                    local dangerOuter = world.starWellRadius * world.starDangerTextMultiplier
                    if shipDist < dangerOuter then
                        local blink = 0.55 + 0.45 * math.sin(self.time * 6)
                        love.graphics.setColor(1, 0.15, 0.1, blink)
                        local dangerText = i18n.t("danger_warning")
                        local df = love.graphics.getFont()
                        -- Draw at 4 positions around the well ring
                        local ringR = world.starWellRadius + 12
                        for i = 0, 3 do
                            local angle = (i * math.pi / 2) + self.time * 0.3
                            local tx = sx + math.cos(angle) * ringR - df:getWidth(dangerText) / 2
                            local ty = sy + math.sin(angle) * ringR - df:getHeight() / 2
                            love.graphics.print(dangerText, math.floor(tx), math.floor(ty))
                        end
                    end
                end
            end
        end
    end
    for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 4)) do
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
            -- PixelPlanets per-starType sprite wiring (INBOX 12)
            local ppImages = self.ppPlanetImages or {}
            if planet.hub then
                -- Prefer pp_<starType> for hub; fall back to dedicated hubPlanetImage
                if planet.galaxyStarType and ppImages[planet.galaxyStarType] then
                    planetSprite = ppImages[planet.galaxyStarType]
                elseif self.hubPlanetImage then
                    planetSprite = self.hubPlanetImage
                end
            elseif planet.isShop then
                -- Prefer pp_<starType> for shop; fall back to dedicated shopPlanetImage
                if planet.galaxyStarType and ppImages[planet.galaxyStarType] then
                    planetSprite = ppImages[planet.galaxyStarType]
                elseif self.shopPlanetImage then
                    planetSprite = self.shopPlanetImage
                end
            elseif planet.galaxyStarType and ppImages[planet.galaxyStarType] then
                planetSprite = ppImages[planet.galaxyStarType]
            end
            -- Per-planet rotation & scale variation from planet id
            local rot, scaleMul = M.planetVariation(planet)
            -- Light tint: blend toward white so PixelPlanets palette shows through
            local tR = math.min(1, baseR * 0.35 + 0.65)
            local tG = math.min(1, baseG * 0.35 + 0.65)
            local tB = math.min(1, baseB * 0.35 + 0.65)
            love.graphics.setColor(tR, tG, tB)
            -- INBOX-61(14): Prefer rotation sheet first, independent of
            -- planetSprite, so sheets render even when pp_* static PNGs
            -- fail to load.
            local sheetType = planet.galaxyStarType
            local sheetImg = nil
            if planet.hub then
                sheetImg = self.hubSheetImage
            elseif sheetType then
                sheetImg = self.planetSheetImages and self.planetSheetImages[sheetType]
            end
            if sheetImg then
                local sw, sh = sheetImg:getDimensions()
                local frameH = sw
                local frameCount = math.max(1, math.floor(sh / frameH))
                local frameIdx = math.floor((self.time or 0) * 1.5) % frameCount
                local quad = love.graphics.newQuad(0, frameIdx * frameH, sw, frameH, sw, sh)
                local sScale = (planet.radius * 2) / sw * scaleMul
                love.graphics.draw(sheetImg, quad, x, y, rot, sScale, sScale, sw / 2, frameH / 2)
            elseif planetSprite then
                local iw, ih = planetSprite:getDimensions()
                local baseScale = (planet.radius * 2) / math.max(iw, ih)
                local scale = baseScale * scaleMul
                love.graphics.draw(planetSprite, x, y, rot, scale, scale, iw / 2, ih / 2)
            else
                love.graphics.setColor(baseR * 0.7, baseG * 0.7, baseB * 0.7)
                love.graphics.circle("fill", x, y, planet.radius)
                love.graphics.setColor(math.min(1, baseR * 1.25), math.min(1, baseG * 1.25), math.min(1, baseB * 1.25))
                love.graphics.circle("fill", x - planet.radius * 0.3, y - planet.radius * 0.3, planet.radius * 0.55)
            end
            if not self.discovered[planet.id] then
                local pe3 = self.planetEffectImages or {}
                local cr, cg, cb = sampleTierColor(world.sampleTier(planet))
                drawCollectOrbitRing(x, y, planet.radius, cr, cg, cb, pe3.rim)
                -- Balatro-style twinkle: a handful of small points orbiting
                -- just outside the rim glow, each with its own phase so the
                -- shimmer isn't perfectly synchronized across points.
                local tier = world.sampleTier(planet)
                local sparkle = sampleTierSparkle(tier)
                local sr, sg, sb = sampleTierColor(tier)
                local shipDx, shipDy = planet.x - self.ship.x, planet.y - self.ship.y
                local shipDistance = math.sqrt(shipDx * shipDx + shipDy * shipDy)
                local anticipation = sparkleAnticipationMultiplier(shipDistance, M.collectOrbitRadius(planet.radius))
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
            local prevLblFont = love.graphics.getFont()
            love.graphics.setFont(fonts.get(11))
            local bob = math.sin(self.time * 2) * 3
            local f = love.graphics.getFont()
            local lineH = 14
            if planet.hub then
                if not self.expedition.hubExplored[planet.galaxyId] then
                    local engineStr = i18n.t("engine_part_available")
                    love.graphics.setColor(0.85, 0.35, 0.95, 0.85)
                    love.graphics.print(engineStr, x - f:getWidth(engineStr) / 2, y + planet.radius + 8 + lineH * 2 + bob)
                end
                -- Hub: sell + upgrade only. No hull repair (INBOX 61(31)).
                local sell = i18n.t("checkpoint_hint_sell")
                local upgrade = i18n.t("checkpoint_hint_upgrade")
                local topY = y + planet.radius + 8 + bob
                love.graphics.setColor(0.65, 0.68, 0.72, 0.7)
                love.graphics.print(sell, x - f:getWidth(sell) / 2, topY)
                love.graphics.print(upgrade, x - f:getWidth(upgrade) / 2, topY + lineH)
            elseif planet.isShop then
                if not self.shopVisited[planet.id] then
                    local hullStr = i18n.t("hull_part_available")
                    love.graphics.setColor(0.3, 0.9, 0.95, 0.85)
                    love.graphics.print(hullStr, x - f:getWidth(hullStr) / 2, y - planet.radius - 8 - lineH + bob)
                end
            end
            love.graphics.setFont(prevLblFont)
        end
    end
    -- INBOX (37): draw moons orbiting planets
    for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 4)) do
        local moon = world.moonForPlanet(planet, self.time)
        if moon then
            local mx, my = math.floor(moon.x - cameraX), math.floor(moon.y - cameraY)
            if mx > -20 and mx < viewport.width + 20 and my > -20 and my < viewport.height + 20 then
                local moonSprite = self.moonImage
                if moonSprite then
                    local iw, ih = moonSprite:getDimensions()
                    local scale = (moon.radius * 2) / math.max(iw, ih)
                    local baseR, baseG, baseB = planetColor(moon.hue)
                    love.graphics.setColor(math.min(1, baseR * 0.4 + 0.7),
                                           math.min(1, baseG * 0.4 + 0.7),
                                           math.min(1, baseB * 0.4 + 0.7))
                    love.graphics.draw(moonSprite, mx, my, 0, scale, scale, iw / 2, ih / 2)
                else
                    local baseR, baseG, baseB = planetColor(moon.hue)
                    local brightR = math.min(1, baseR * 0.5 + 0.5)
                    local brightG = math.min(1, baseG * 0.5 + 0.5)
                    local brightB = math.min(1, baseB * 0.5 + 0.5)
                    love.graphics.setColor(brightR, brightG, brightB)
                    love.graphics.circle("fill", mx, my, moon.radius)
                    love.graphics.setColor(math.min(1, brightR + 0.3), math.min(1, brightG + 0.3), math.min(1, brightB + 0.3))
                    love.graphics.circle("fill", mx - moon.radius * 0.25, my - moon.radius * 0.25, moon.radius * 0.5)
                end
                -- Collection ring: white (slow) → red (fast) based on speedFactor
                if not self.moonDiscovered[moon.id] then
                    local sf = moon.speedFactor or 0.5
                    love.graphics.setColor(1, 1 - sf * 0.7, 1 - sf * 0.8, 0.6)
                    love.graphics.circle("line", mx, my, (moon.collectRadius or moon.radius) + 15)
                end
                -- Outline
                love.graphics.setColor(0.9, 0.95, 1, 0.35)
                love.graphics.circle("line", mx, my, moon.radius + 1)
            end
        end
    end
    for _, junk in ipairs(world.nearbyDebris(self.ship.x, self.ship.y, 4, self.time)) do
        local x, y = math.floor(junk.x - cameraX), math.floor(junk.y - cameraY)
        if x > -20 and x < viewport.width + 20 and y > -20 and y < viewport.height + 20 then
            local debrisSprite = self.debrisImages and self.debrisImages[junk.kind]
            if debrisSprite then
                local iw, ih = debrisSprite:getDimensions()
                local scale = (junk.radius * 2) / math.max(iw, ih)
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(debrisSprite, x, y, junk.rotation or 0, scale, scale, iw / 2, ih / 2)
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
    -- INBOX (35): draw comets with tail particles
    for _, comet in ipairs(world.nearbyComets(self.ship.x, self.ship.y, self.time, viewport.width, viewport.height)) do
        local cx, cy = math.floor(comet.x - cameraX), math.floor(comet.y - cameraY)
        if cx > -60 and cx < viewport.width + 60 and cy > -60 and cy < viewport.height + 60 then
            -- Draw tail: gradient from yellow to red, length 40-60px behind comet
            local tailLen = 40 + comet.radius * 2
            local speed = math.sqrt(comet.vx * comet.vx + comet.vy * comet.vy)
            local ndx, ndy = 0, 0
            if speed > 0 then
                ndx = -comet.vx / speed
                ndy = -comet.vy / speed
            end
            for i = 1, 12 do
                local t = i / 12
                local tx = cx + ndx * tailLen * t
                local ty = cy + ndy * tailLen * t
                local alpha = (1 - t) * 0.7
                -- Yellow→red gradient
                local tr = 1
                local tg = 0.85 * (1 - t * 0.8)
                local tb = 0.1 * (1 - t)
                local pr = math.max(1, comet.radius * (1 - t * 0.6))
                love.graphics.setColor(tr, tg, tb, alpha)
                love.graphics.circle("fill", tx, ty, pr)
            end
            -- Draw comet body (sprite if available, else bright yellow-white disc)
            if self.cometImage then
                local iw, ih = self.cometImage:getDimensions()
                local scale = (comet.radius * 2) / math.max(iw, ih)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(self.cometImage, cx, cy, 0, scale, scale, iw / 2, ih / 2)
            else
                love.graphics.setColor(1, 0.95, 0.7)
                love.graphics.circle("fill", cx, cy, comet.radius)
                love.graphics.setColor(1, 1, 0.9)
                love.graphics.circle("fill", cx - comet.radius * 0.25, cy - comet.radius * 0.25, comet.radius * 0.6)
            end
            -- Collection ring for undiscovered comets
            if not self.cometDiscovered[comet.id] then
                love.graphics.setColor(1, 0.85, 0.25, 0.5)
                love.graphics.setLineWidth(1)
                love.graphics.circle("line", cx, cy, M.collectOrbitRadius(comet.radius))
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
            love.graphics.circle("fill", px, py, particle.radius or 1.5)
        end
    end
    love.graphics.push()
    local shakeX, shakeY = 0, 0
    if self.shipShake > 0 then
        local shakeStrength = (self.shipShake / shipShakeDuration) * 3 * self.shipShakeMagnitude
        shakeX = (math.random() * 2 - 1) * shakeStrength
        shakeY = (math.random() * 2 - 1) * shakeStrength
    end
    -- INBOX (5)(a): persistent reentry x-offset, independent of shipShake.
    if (self.reentryShake or 0) > 0 then
        shakeX = shakeX + M.reentryDrawOffsetX(self.time, self.reentryShake)
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
    -- INBOX (24)(a): end collectZoom transform (before HUD)
    if collectZoomScale ~= 1 then
        love.graphics.pop()
    end

    local hud = self:hudLines()
    local galaxyShift = hud.galaxy and M.hudGalaxyShift or 0
    local hudHeight = M.hudHeight(self.expedition.phase, hud, galaxyShift)
    -- Item 41: no per-phase font override; all phases use the default 22px font
    -- set at init, ensuring launch and ascending HUD look identical.
    -- INBOX (16): left-text width only so stars/planets show on the right.
    local hudBgWidth = M.hudBackgroundWidth(hud, love.graphics.getFont())
    local shopEff = self.shopEffectImages or {}
    love.graphics.setColor(1, 1, 1, 0.85)
    if not drawPanelSprite(shopEff.hudPanel, 0, 0, hudBgWidth, hudHeight) then
        love.graphics.setColor(0.02, 0.03, 0.08, 0.85)
        love.graphics.rectangle("fill", 0, 0, hudBgWidth, hudHeight)
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
        hudY = hudY + M.hudLineStep
        love.graphics.setColor(0.7, 0.9, 1)
    end
    if hud.best then
        love.graphics.setColor(1, 0.8, 0.3)
        local hudIcons = self.hudIconImages or {}
        local bestIconSize = M.hullIconSize
        drawHudSpriteOrPoly(hudIcons.best, nil,
            5 + bestIconSize / 2, hudY + bestIconSize / 2, bestIconSize)
        love.graphics.print(hud.best, 5 + bestIconSize + M.hullIconGap, hudY)
        hudY = hudY + M.hudLineStep
        love.graphics.setColor(0.7, 0.9, 1)
    end
    -- ComfyUI HUD wiring (group 1): distance icon before distance text
    -- Item 38b: distance is its own line.
    do
        local hudIconsTmp2 = self.hudIconImages or {}
        local distIconSize = M.hullIconSize
        drawHudSpriteOrPoly(hudIconsTmp2.distance, nil,
            5 + distIconSize / 2, hudY + distIconSize / 2, distIconSize)
        -- Distance milestone flash: Balatro-style punch + sparkle when crossing 1000-unit boundaries
        local dist = self:hudDistanceRaw()
        local currentMilestone = math.floor(dist / 1000)
        if currentMilestone > (self.distanceMilestone or 0) then
            self.distanceMilestone = currentMilestone
            self.distanceMilestoneFlash = 1.0
            -- Spawn sparkle particles around the distance text
            for k = 1, 6 do
                local px = 5 + distIconSize + M.hullIconGap + math.random(0, 120)
                local py = hudY + math.random(-8, 8)
                self.particles[#self.particles + 1] = {
                    x = px, y = py,
                    vx = (math.random() - 0.5) * 40,
                    vy = -20 - math.random() * 30,
                    timer = 0.6 + math.random() * 0.3,
                    maxTimer = 0.9,
                    r = 1, g = 0.85 + math.random() * 0.15, b = 0.2,
                    radius = 1.5 + math.random() * 1.5,
                    hud = true, -- flag: drawn in screen space, not world space
                }
            end
            pcall(love.system.vibrate, 0.04)
        end
        if (self.distanceMilestoneFlash or 0) > 0 then
            local dt2 = love.timer and love.timer.getDelta() or 0.016
            self.distanceMilestoneFlash = self.distanceMilestoneFlash - dt2
            local flash = math.max(0, self.distanceMilestoneFlash)
            -- Scale punch: text grows then shrinks back
            local punchScale = 1.0 + flash * 0.4  -- 1.4x at start, 1.0x at end
            local textX2 = 5 + distIconSize + M.hullIconGap
            local textCenterX = textX2 + 60
            local textCenterY = hudY + 11
            love.graphics.push()
            love.graphics.translate(textCenterX, textCenterY)
            love.graphics.scale(punchScale, punchScale)
            love.graphics.translate(-textCenterX, -textCenterY)
            love.graphics.setColor(1, 0.85, 0.25, 0.6 + flash * 0.4)
            love.graphics.print(hud.distance, textX2, hudY)
            love.graphics.pop()
        else
            love.graphics.setColor(0.7, 0.9, 1)
            love.graphics.print(hud.distance, 5 + distIconSize + M.hullIconGap, hudY)
        end
        hudY = hudY + M.hudLineStep
    end
    -- Item 38b: cash is its own line (was combined with distance).
    do
        love.graphics.setColor(1, 0.85, 0.3)
        local hudIcons = self.hudIconImages or {}
        drawHudSpriteOrPoly(hudIcons.cash, M.coinIconPoints,
            5 + M.cashIconSize / 2, hudY + M.cashIconSize / 2, M.cashIconSize)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.print(hud.cash, 5 + M.cashIconSize + M.cashIconGap, hudY)
        hudY = hudY + M.hudLineStep
    end
    -- Item 38c: durability HP blocks (colored rectangles instead of text).
    do
        local hudIcons = self.hudIconImages or {}
        local iconCenterX = 5 + M.hullIconSize / 2
        local iconCenterY = hudY + M.hudLineStep / 2
        love.graphics.setColor(0.6, 0.85, 1)
        drawHudSpriteOrPoly(hudIcons.hull, M.shieldIconPoints,
            iconCenterX, iconCenterY, M.hullIconSize)
        -- Draw HP blocks: maxDurability rectangles, filled for current HP.
        -- When maxDurability >= 10, use "big blocks" worth 10 HP each + remainder.
        local run = self.expedition
        local blockX = 5 + M.hullIconSize + M.hullIconGap
        local blockY = hudY + (M.hudLineStep - M.hpBlockSize) / 2
        local function hpColor(cur, mx)
            if cur <= math.ceil(mx * 0.33) then
                return 0.9, 0.2, 0.15
            elseif cur <= math.ceil(mx * 0.66) then
                return 1, 0.85, 0.2
            else
                return 0.2, 0.85, 0.3
            end
        end
        if run.maxDurability >= 10 then
            -- Each big block = 10 HP; draw filled/partial/empty
            local bigCount = math.ceil(run.maxDurability / 10)
            for i = 1, bigCount do
                local blockMin = (i - 1) * 10 + 1
                local blockMax = math.min(i * 10, run.maxDurability)
                local blockCapacity = 10
                local blockFilled = math.max(0, math.min(run.durability - blockMin + 1, blockMax - blockMin + 1))
                if blockFilled >= blockCapacity then
                    -- Full 10x block: filled + diagonal shine stripes
                    local hr, hg, hb = hpColor(run.durability, run.maxDurability)
                    love.graphics.setColor(hr, hg, hb)
                    love.graphics.rectangle("fill", blockX, blockY, M.hpBlockSize, M.hpBlockSize)
                    -- Diagonal shine lines (brighter, semi-transparent)
                    love.graphics.setColor(math.min(1, hr + 0.3), math.min(1, hg + 0.3), math.min(1, hb + 0.3), 0.45)
                    local sz = M.hpBlockSize
                    for s = 3, sz, 5 do
                        love.graphics.line(blockX + s, blockY, blockX, blockY + s)
                    end
                    for s = 3, sz, 5 do
                        love.graphics.line(blockX + sz, blockY + s, blockX + s, blockY + sz)
                    end
                    -- Bright border to distinguish from 1x blocks
                    love.graphics.setColor(math.min(1, hr + 0.2), math.min(1, hg + 0.2), math.min(1, hb + 0.2), 0.8)
                    love.graphics.rectangle("line", blockX, blockY, M.hpBlockSize, M.hpBlockSize)
                elseif blockFilled > 0 then
                    -- Partially filled: outline + partial fill
                    love.graphics.setColor(0.3, 0.3, 0.35)
                    love.graphics.rectangle("line", blockX, blockY, M.hpBlockSize, M.hpBlockSize)
                    local frac = blockFilled / blockCapacity
                    local fillH = math.max(1, math.floor(M.hpBlockSize * frac))
                    love.graphics.setColor(hpColor(run.durability, run.maxDurability))
                    love.graphics.rectangle("fill", blockX, blockY + M.hpBlockSize - fillH, M.hpBlockSize, fillH)
                else
                    love.graphics.setColor(0.3, 0.3, 0.35)
                    love.graphics.rectangle("line", blockX, blockY, M.hpBlockSize, M.hpBlockSize)
                end
                blockX = blockX + M.hpBlockSize + M.hpBlockGap
            end
        else
            for i = 1, run.maxDurability do
                if i <= run.durability then
                    love.graphics.setColor(hpColor(run.durability, run.maxDurability))
                    love.graphics.rectangle("fill", blockX, blockY, M.hpBlockSize, M.hpBlockSize)
                else
                    love.graphics.setColor(0.3, 0.3, 0.35)
                    love.graphics.rectangle("line", blockX, blockY, M.hpBlockSize, M.hpBlockSize)
                end
                blockX = blockX + M.hpBlockSize + M.hpBlockGap
            end
        end
        hudY = hudY + M.hudLineStep
    end

    -- INBOX-40: gear slots grid below left HUD stats (ascending/returning/launch)
    if self.expedition.phase ~= "settlement" and self.expedition.phase ~= "destroyed" then
        self:drawHudGearSlots(hudHeight)
    end
    self:drawMinimap()
    -- INBOX-44: ship stats summary below minimap right side (ascending only)
    self:drawShipStatsSummary()
    -- Item 9: Star well HUD timer (ascending only, inside well, not yet sampled)
    if self.expedition.phase == "ascending" and self.starWellTimer > 0 then
        local wellGalaxy = world.galaxyContaining(self.ship.x, self.ship.y)
        if wellGalaxy and not self.starWellSampled[wellGalaxy.id] then
            local remain = math.max(0, world.starSurvivalTime - self.starWellTimer)
            local starLabel = world.starName(wellGalaxy) or i18n.t("central_star_label")
            local prevWellFont = love.graphics.getFont()
            love.graphics.setFont(fonts.get(33))
            if remain <= 3 then
                love.graphics.setColor(1.0, 0.25, 0.2)
            else
                love.graphics.setColor(1.0, 0.75, 0.25)
            end
            local bob = math.sin(self.time * 6) * 2
            love.graphics.printf(
                i18n.t("star_well_timer", starLabel, remain),
                0, viewport.height - 72 + bob, viewport.width, "center")
            love.graphics.setFont(prevWellFont)
        end
    end
    if self.expedition.phase == "launch" then
        -- Launch screen: just "tap to launch" text, no loadout panel or dark overlay.
        -- The gear slots on the left HUD and ship stats below minimap
        -- already show the player's equipment during all phases.
    elseif self.expedition.phase == "settlement" then
        self:drawSettlementOverlay()
    elseif self.expedition.phase == "destroyed" then
        self:drawDestroyedOverlay()
    elseif self.expedition.phase == "ascending" then
        self:drawJoystickStick()
        self:drawBoostButton()
    end
    self:drawBoostSpeedLines()
    self:drawGearPopup()
    love.graphics.setColor(0.85, 0.9, 1)
    local messageY
    if self.expedition.phase == "launch" then
        -- INBOX (39): "tap to launch" text above the loadout panel with
        -- gentle float animation; rocket icon moves together.
        local floatOffset = math.sin(self.time * 2) * 4
        messageY = M.launchLoadoutBoxTop - 50 + floatOffset
        love.graphics.setColor(1, 0.75, 0.25)
        if not drawHudSpriteOrPoly(self.launchRocketIconImage, M.rocketIconPoints,
                viewport.width / 2, messageY - M.launchIconGap, M.launchIconSize) then
            love.graphics.polygon("fill", M.rocketIconPoints(
                viewport.width / 2, messageY - M.launchIconGap, M.launchIconSize))
        end
        love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
    elseif self.expedition.phase == "settlement" or self.expedition.phase == "destroyed" then
        messageY = 50
    else
        messageY = viewport.height - 30
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
    if self.collectFlash and self.collectFlash > 0 then
        love.graphics.setColor(1, 1, 1, 0.3 * (self.collectFlash / 0.15))
        love.graphics.rectangle("fill", 0, 0, viewport.width, viewport.height)
    end
    -- Item 18: Pause button icon (ascending phase only) — below minimap.
    if self.expedition.phase == "ascending" then
        local mmBot = self.minimapBottom or 300
        local pb = pauseButton
        pb.y = mmBot + 8  -- dynamic: just below minimap
        local bx, by, bw, bh = pb.x, pb.y, pb.w, pb.h
        -- Pause icon: two vertical bars, centered in the touch area.
        local barW = 6
        local barH = 22
        local gap = 4
        local iconCx = bx + bw / 2
        local iconCy = by + bh / 2
        if self.paused then
            love.graphics.setColor(1, 1, 1, 0.9)
        else
            love.graphics.setColor(1, 1, 1, 0.5)
        end
        love.graphics.rectangle("fill",
            iconCx - gap / 2 - barW, iconCy - barH / 2, barW, barH)
        love.graphics.rectangle("fill",
            iconCx + gap / 2, iconCy - barH / 2, barW, barH)
        -- Admin cheat buttons below pause
        local prevAdminFont = love.graphics.getFont()
        local adminFont = fonts.get(22)
        love.graphics.setFont(adminFont)
        for i, btn in ipairs(adminButtons) do
            local ax, ay, aw, ah = adminButtonRect(i, pb.y)
            love.graphics.setColor(0.15, 0.18, 0.28, 0.75)
            love.graphics.rectangle("fill", ax, ay, aw, ah, 6, 6)
            love.graphics.setColor(0.85, 0.9, 1, 0.85)
            love.graphics.rectangle("line", ax, ay, aw, ah, 6, 6)
            love.graphics.printf(i18n.t(btn.labelKey), ax, ay + 6, aw, "center")
        end
        love.graphics.setFont(prevAdminFont)
    end
    -- drawPauseOverlay → game/scenes/play_hud.lua
    self:drawPauseOverlay()
    if self.shopModal then
        self:drawShopModal()
    end
    -- drawGearPopup → game/scenes/play_hud.lua
    self:drawGearPopup()
    if self.reentryHeatAlpha and self.reentryHeatAlpha > 0 then
        local prevLineWidth = love.graphics.getLineWidth()
        love.graphics.setColor(0.2, 1, 0.4, self.reentryHeatAlpha)
        love.graphics.setLineWidth(60)
        love.graphics.rectangle("line", 0, 0, viewport.width, viewport.height)
        love.graphics.setLineWidth(prevLineWidth)
    end
    if self.hubHeatAlpha and self.hubHeatAlpha > 0 then
        local prevLineWidth = love.graphics.getLineWidth()
        love.graphics.setColor(0.2, 1, 0.4, self.hubHeatAlpha)
        love.graphics.setLineWidth(60)
        love.graphics.rectangle("line", 0, 0, viewport.width, viewport.height)
        love.graphics.setLineWidth(prevLineWidth)
    end
    if self.starWellHeatAlpha and self.starWellHeatAlpha > 0 then
        local prevLineWidth = love.graphics.getLineWidth()
        love.graphics.setColor(1, 0.25, 0.1, self.starWellHeatAlpha)
        love.graphics.setLineWidth(60)
        love.graphics.rectangle("line", 0, 0, viewport.width, viewport.height)
        love.graphics.setLineWidth(prevLineWidth)
    end

end

return M
