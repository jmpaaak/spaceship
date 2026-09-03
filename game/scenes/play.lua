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

-- Returning-phase LEFT/RIGHT/SPIN touch band. Old 180×320 values
-- (244-288, 44 canvas px) ×4 for the 720×1280 canvas so the band stays
-- at the same screen fraction and still clears the 44pt bar (176 canvas
-- px at integer scale 1). Slot-reel box and message y are scaled with it.
local returnControls = {
    top = 976,
    bottom = 1152,
    leftMaxX = 220,
    slotMinX = 240,
    slotMaxX = 480,
    rightMinX = 500,
}
M.returnControls = returnControls

-- Settlement (EARTH SHOP) touch rows, top-to-bottom. Old 180×320 bands
-- (188-232 / 232-276 / 276-320, half-width 90) ×4 onto 720×1280 so the
-- shop stays pinned to the canvas bottom and each band still clears the
-- 44pt accessibility minimum (176 canvas px at integer scale 1).
-- docs/feedback/INBOX.md item 11(b): the fuel-tank upgrade purchase was
-- removed from EARTH SHOP because fuel no longer constrains flight, so
-- buying more tank capacity implied a safety that does not exist. The
-- remaining four actions (HULL, STEERING, YIELD, SHIP) plus RELAUNCH
-- still occupy three stacked bands. HULL/STEERING share one row and
-- YIELD/SHIP share the next.
local settlementTouchRows = {
    {
        top = 752, bottom = 928,
        columns = {
            { key = "hull", left = 0, right = 360 },
            { key = "steering", left = 360, right = 720 },
        },
    },
    {
        top = 928, bottom = 1104,
        columns = {
            { key = "yield", left = 0, right = 360 },
            { key = "ship", left = 360, right = 720 },
        },
    },
    { key = "relaunch", top = 1104, bottom = 1280 },
}
M.settlementTouchRows = settlementTouchRows

-- SHIP DESTROYED restart touch target. Unlike EARTH SHOP's four stacked
-- rows, this phase has a single action (restart), so touchpressed accepts
-- any tap on the full 720x1280 internal canvas rather than a narrow band.
-- Documented and engine-tested explicitly so this stays true if the
-- destroyed phase ever grows per-row touch targets like settlement did.
local destroyedTouchArea = { top = 0, bottom = viewport.height, left = 0, right = viewport.width }
M.destroyedTouchArea = destroyedTouchArea

-- Ascending-phase HOLD LEFT/HOLD RIGHT steering buttons. touchpressed for
-- this phase already accepts a tap anywhere on the internal canvas (no y
-- restriction; see the "ascending" branch below), so the *functional*
-- touch target already spans the full 720x1280 canvas -- far beyond the
-- 44pt accessibility minimum. This constant only documents/tests the
-- *visual* button box drawn on screen, which was a 24px-tall row
-- (254-278, only ~24pt at the smallest supported window, integer scale 1,
-- 1x device pixel ratio) -- under the same 44pt bar returnControls and
-- settlementTouchRows were widened to meet. Widened to match
-- returnControls exactly (244-288, 44 canvas px) for visual consistency,
-- even though it does not gate touch acceptance.
local ascendControls = { top = 976, bottom = 1152, leftMaxX = 324, rightMinX = 396 }
M.ascendControls = ascendControls

-- LAUNCH phase's TAP TO LAUNCH touch target. touchpressed for this phase
-- already accepts any tap on the internal canvas regardless of x/y (see the
-- "launch" branch below), so the functional touch target has always spanned
-- the full 720x1280 canvas -- far beyond the 44pt accessibility minimum.
-- Named and exposed to close out the last remaining touch surface that was
-- accepted unconditionally but never given an explicit constant or
-- corner-touch regression test, matching destroyedTouchArea's pattern.
local launchTouchArea = { top = 0, bottom = viewport.height, left = 0, right = viewport.width }
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
M.launchHudHeight = 128
-- Regression fix (2026-09-02, same feedback item, follow-up capture): the
-- Earth disc drawn behind the scene (center y=75-cameraY for a ship parked
-- at the world origin, radius 58) tops out at y=202, two pixels above the
-- box's previous 204px top -- a real LÖVE runtime capture showed a faint
-- blue crescent peeking out just above the LAUNCH LOADOUT card. Raised the
-- box top to 202 so it fully covers the disc's topmost extent.
M.launchLoadoutBoxTop = 808
M.launchLoadoutRowStep = 40

-- docs/feedback/INBOX.md UI 대개편 6건 item 1: the "SPECIMENS n/9" specimen
-- log strip is pure decoration with zero effect on gameplay numbers (user
-- ruling, 2026-09-03) -- gate the launch-screen draw call behind this flag
-- (kept named, not deleted, mirroring M.showLaunchLoadoutTitle above) so a
-- future cycle can revive it cheaply if the collection mechanic gets a
-- real gameplay hook later. The underlying collectionStore/specimenCatalog
-- persistence stays untouched -- only the launch-screen render is removed.
M.showSpecimenStrip = false

-- docs/feedback/INBOX.md "UI 대개편 6건" item 6: the "DEV PLACEHOLDER"
-- footer had already been shrunk/dimmed in an earlier cycle, but the user
-- confirmed (2026-09-03) they want it fully invisible, not just quieter.
-- Named flag follows the same pattern as M.showSpecimenStrip /
-- M.showLaunchLoadoutTitle: the conditional draw call itself is gated off
-- rather than deleting the printf plumbing, so it can be re-enabled for a
-- future dev build without re-threading render code.
M.showDevPlaceholder = false

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
M.launchIconSize = 56
M.launchIconGap = 48

-- docs/feedback/INBOX.md "UI 대개편 6건" item 5: the launch rocket polygon
-- (orange/yellow, reads as a crude arrow) is gated off. Named flag, same
-- pattern as M.showSpecimenStrip / M.showDevPlaceholder, so a later cycle
-- can restore the icon without re-threading draw(). The remaining cue is
-- the TAP TO LAUNCH / "탭하여 발사" line itself: smaller than the scene
-- small font, dark translucent gray, with a restrained sine wobble and
-- fade pulse instead of a bright static prompt.
M.showLaunchRocketIcon = false
M.launchPromptFontSize = 24
M.launchPromptRgb = {0.42, 0.44, 0.48}
M.launchPromptWobblePx = 2.5

function M.launchPromptAlpha(time)
    local t = time or 0
    return 0.40 + 0.12 * math.sin(t * 2.2)
end

function M.launchPromptOffset(time)
    local t = time or 0
    local amp = M.launchPromptWobblePx
    return math.sin(t * 1.7) * amp, math.sin(t * 1.1 + 1.3) * amp * 0.6
end

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
M.hullIconSize = 32
M.hullIconGap = 16

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
M.cashIconSize = 32
M.cashIconGap = 16

-- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
-- fourth/final slice): pair the LAUNCH LOADOUT steering-speed readout
-- (STEER SPEED %d / 조종속도 %d) with a small speedometer silhouette,
-- mirroring shieldIconPoints/coinIconPoints. Drawn as a flat semicircular
-- dial outline with a needle (an even-length {x,y,...} polygon list, no
-- love.graphics calls) so its geometry can be regression tested the same
-- way as the other three icons: horizontally symmetric around cx, spans
-- above and below cy.
function M.speedIconPoints(cx, cy, size)
    local r = size * 0.5
    local baseY = cy + r * 0.6
    return {
        cx - r, baseY,
        cx - r * 0.7071, baseY - r * 0.7071,
        cx, baseY - r,
        cx + r * 0.7071, baseY - r * 0.7071,
        cx + r, baseY,
        cx + r * 0.18, baseY,
        cx, baseY - r * 0.85,
        cx - r * 0.18, baseY,
    }
end

-- Icon footprint (px) + gap (px) reserved between the speedometer icon's
-- right edge and the STEER SPEED text's left edge, mirroring
-- M.hullIconSize/hullIconGap and M.cashIconSize/cashIconGap.
M.speedIconSize = 32
M.speedIconGap = 16

-- DIST HUD icon (icon-based HUD simplification follow-on): pair the
-- "DIST %04d" / "거리 %04d" readout with a small nav-diamond silhouette,
-- mirroring coin/shield/speed. Drawn as a flat 4-point diamond (even-length
-- {x,y,...} list, no love.graphics calls) so headless tests can pin
-- geometry: horizontally symmetric around cx, spans above and below cy.
function M.distanceIconPoints(cx, cy, size)
    local r = size * 0.5
    return {
        cx, cy - r,
        cx + r, cy,
        cx, cy + r,
        cx - r, cy,
    }
end

-- Icon footprint (px) + gap (px) reserved between the diamond icon's
-- right edge and the DIST text's left edge, mirroring
-- M.cashIconSize/cashIconGap.
M.distanceIconSize = 32
M.distanceIconGap = 16

-- PERSONAL BEST HUD icon (icon-based HUD simplification follow-on): pair
-- the "PERSONAL BEST %04d" / "최고기록 %04d" readout with a small trophy
-- silhouette, mirroring coin/shield/speed/distance. Drawn as a flat cup
-- polygon (even-length {x,y,...} list, no love.graphics calls) so
-- headless tests can pin geometry: horizontally symmetric around cx,
-- spans above and below cy.
function M.bestIconPoints(cx, cy, size)
    local r = size * 0.5
    return {
        cx - r * 0.70, cy - r,
        cx + r * 0.70, cy - r,
        cx + r * 0.55, cy - r * 0.15,
        cx + r * 0.18, cy + r * 0.15,
        cx + r * 0.45, cy + r * 0.35,
        cx + r * 0.45, cy + r,
        cx - r * 0.45, cy + r,
        cx - r * 0.45, cy + r * 0.35,
        cx - r * 0.18, cy + r * 0.15,
        cx - r * 0.55, cy - r * 0.15,
    }
end

-- Icon footprint (px) + gap (px) reserved between the trophy icon's
-- right edge and the BEST text's left edge, mirroring
-- M.distanceIconSize/distanceIconGap.
M.bestIconSize = 32
M.bestIconGap = 16

-- SAMPLES HUD icon (icon-based HUD simplification follow-on): pair the
-- "SAMPLES %02d  AT RISK $%d" / "표본 %02d  위험 $%d" readout with a
-- small specimen-vial silhouette, mirroring coin/shield/speed/distance/
-- best. Drawn as a flat flask polygon (even-length {x,y,...} list, no
-- love.graphics calls) so headless tests can pin geometry: horizontally
-- symmetric around cx, spans above and below cy.
function M.samplesIconPoints(cx, cy, size)
    local r = size * 0.5
    return {
        cx - r * 0.22, cy - r,
        cx + r * 0.22, cy - r,
        cx + r * 0.22, cy - r * 0.45,
        cx + r * 0.70, cy - r * 0.25,
        cx + r * 0.70, cy + r,
        cx - r * 0.70, cy + r,
        cx - r * 0.70, cy - r * 0.25,
        cx - r * 0.22, cy - r * 0.45,
    }
end

-- Icon footprint (px) + gap (px) reserved between the vial icon's
-- right edge and the SAMPLES text's left edge, mirroring
-- M.bestIconSize/bestIconGap.
M.samplesIconSize = 32
M.samplesIconGap = 16

-- Galaxy-name HUD icon (icon-based HUD simplification follow-on): pair
-- the gold galaxy-name readout with a small 8-point star silhouette,
-- mirroring coin/shield/speed/distance/best/samples. Drawn as a flat
-- star polygon (even-length {x,y,...} list, no love.graphics calls) so
-- headless tests can pin geometry: horizontally symmetric around cx,
-- spans above and below cy.
function M.galaxyIconPoints(cx, cy, size)
    local r = size * 0.5
    local inner = r * 0.38
    return {
        cx, cy - r,
        cx + inner * 0.45, cy - inner,
        cx + r * 0.72, cy - r * 0.72,
        cx + inner, cy - inner * 0.45,
        cx + r, cy,
        cx + inner, cy + inner * 0.45,
        cx + r * 0.72, cy + r * 0.72,
        cx + inner * 0.45, cy + inner,
        cx, cy + r,
        cx - inner * 0.45, cy + inner,
        cx - r * 0.72, cy + r * 0.72,
        cx - inner, cy + inner * 0.45,
        cx - r, cy,
        cx - inner, cy - inner * 0.45,
        cx - r * 0.72, cy - r * 0.72,
        cx - inner * 0.45, cy - inner,
    }
end

-- Icon footprint (px) + gap (px) reserved between the galaxy star's
-- right edge and the galaxy-name text's left edge, mirroring
-- M.samplesIconSize/samplesIconGap.
M.galaxyIconSize = 32
M.galaxyIconGap = 16

-- Returning-phase RETURN progress HUD icon (icon-based HUD
-- simplification follow-on): pair the cyan hud_return_progress readout
-- with a small downward chevron silhouette, mirroring
-- coin/shield/speed/distance/best/samples/galaxy. Drawn as a flat
-- chevron polygon (even-length {x,y,...} list, no love.graphics calls)
-- so headless tests can pin geometry: horizontally symmetric around cx,
-- spans above and below cy.
function M.returnIconPoints(cx, cy, size)
    local r = size * 0.5
    return {
        cx - r, cy - r * 0.55,
        cx, cy + r,
        cx + r, cy - r * 0.55,
        cx + r * 0.45, cy - r * 0.55,
        cx, cy + r * 0.25,
        cx - r * 0.45, cy - r * 0.55,
    }
end

-- Icon footprint (px) + gap (px) reserved between the return chevron's
-- right edge and the RETURN text's left edge, mirroring
-- M.galaxyIconSize/galaxyIconGap.
M.returnIconSize = 32
M.returnIconGap = 16

-- Returning-phase EARTH-distance HUD icon (icon-based HUD
-- simplification follow-on): pair the cyan hud_earth readout with a
-- small globe silhouette, mirroring
-- coin/shield/speed/distance/best/samples/galaxy/return. Drawn as a
-- flat octagon polygon (even-length {x,y,...} list, no love.graphics
-- calls) so headless tests can pin geometry: horizontally symmetric
-- around cx, spans above and below cy.
function M.earthIconPoints(cx, cy, size)
    local r = size * 0.5
    return {
        cx, cy - r,
        cx + r * 0.72, cy - r * 0.72,
        cx + r, cy,
        cx + r * 0.72, cy + r * 0.72,
        cx, cy + r,
        cx - r * 0.72, cy + r * 0.72,
        cx - r, cy,
        cx - r * 0.72, cy - r * 0.72,
    }
end

-- Icon footprint (px) + gap (px) reserved between the earth globe's
-- right edge and the EARTH IN text's left edge, mirroring
-- M.returnIconSize/returnIconGap.
M.earthIconSize = 32
M.earthIconGap = 16

-- Planet approach SAMPLE $N icon (icon-based HUD simplification
-- follow-on): pair the cyan sample_value_label readout with a small
-- hexagonal crystal silhouette, mirroring
-- coin/shield/speed/distance/best/samples/galaxy/return/earth. Drawn as
-- a flat hexagon polygon (even-length {x,y,...} list, no love.graphics
-- calls) so headless tests can pin geometry: horizontally symmetric
-- around cx, spans above and below cy.
function M.sampleValueIconPoints(cx, cy, size)
    local r = size * 0.5
    return {
        cx, cy - r,
        cx + r * 0.70, cy - r * 0.35,
        cx + r * 0.70, cy + r * 0.35,
        cx, cy + r,
        cx - r * 0.70, cy + r * 0.35,
        cx - r * 0.70, cy - r * 0.35,
    }
end

-- Icon footprint (px) + gap (px) reserved between the crystal's right
-- edge and the SAMPLE $N text's left edge. Smaller than HUD icons
-- because these labels sit next to in-world planets.
M.sampleValueIconSize = 24
M.sampleValueIconGap = 8

-- Planet approach RISK/LETHAL icon (icon-based HUD simplification
-- follow-on): pair the red/amber risk_lethal/risk_normal readout with
-- a small warning-triangle silhouette, mirroring the SAMPLE $N
-- crystal. Drawn as a flat triangle polygon (even-length {x,y,...}
-- list, no love.graphics calls) so headless tests can pin geometry:
-- horizontally symmetric around cx, spans above and below cy.
function M.riskIconPoints(cx, cy, size)
    local r = size * 0.5
    return {
        cx, cy - r,
        cx + r * 0.87, cy + r * 0.5,
        cx - r * 0.87, cy + r * 0.5,
    }
end

-- Icon footprint (px) + gap (px) reserved between the warning
-- triangle's right edge and the RISK/LETHAL text's left edge.
-- Matches the SAMPLE $N crystal because both sit next to planets.
M.riskIconSize = 24
M.riskIconGap = 8

-- Floating sample-pickup "+$N" icon (icon-based HUD simplification
-- follow-on): pair the green floating_sample_gain readout with a
-- small plus-badge silhouette, mirroring the planet-approach SAMPLE
-- $N crystal. Drawn as a flat plus polygon (even-length {x,y,...}
-- list, no love.graphics calls) so headless tests can pin geometry:
-- horizontally symmetric around cx, spans above and below cy.
function M.floatingSampleIconPoints(cx, cy, size)
    local r = size * 0.5
    local arm = size * 0.18
    return {
        cx - arm, cy - r,
        cx + arm, cy - r,
        cx + arm, cy - arm,
        cx + r, cy - arm,
        cx + r, cy + arm,
        cx + arm, cy + arm,
        cx + arm, cy + r,
        cx - arm, cy + r,
        cx - arm, cy + arm,
        cx - r, cy + arm,
        cx - r, cy - arm,
        cx - arm, cy - arm,
    }
end

-- Icon footprint (px) + gap (px) reserved between the plus-badge's
-- right edge and the "+$N" text's left edge. Matches the SAMPLE $N
-- crystal because both are in-world sample-value labels.
M.floatingSampleIconSize = 24
M.floatingSampleIconGap = 8

-- Floating damage "-N" icon (icon-based HUD simplification
-- follow-on): pair the red floating_damage_text readout with a
-- small minus-badge silhouette, mirroring the sample-pickup plus.
-- Drawn as a flat minus polygon (even-length {x,y,...} list, no
-- love.graphics calls) so headless tests can pin geometry:
-- horizontally symmetric around cx, spans above and below cy.
function M.floatingDamageIconPoints(cx, cy, size)
    local r = size * 0.5
    local arm = size * 0.18
    return {
        cx - r, cy - arm,
        cx + r, cy - arm,
        cx + r, cy + arm,
        cx - r, cy + arm,
    }
end

-- Icon footprint (px) + gap (px) reserved between the minus-badge's
-- right edge and the "-N" text's left edge. Matches the sample
-- plus-badge because both are in-world floating value labels.
M.floatingDamageIconSize = 24
M.floatingDamageIconGap = 8

-- "고도(ALT)" mislabeling fix (docs/feedback/INBOX.md item 2, 2026-09-03):
-- the user misread the DIST/CASH line as "altitude requires fuel to
-- increase" because the fuel/status line sat immediately below it. Fuel is
-- not a flight constraint (game/expedition.lua M.update ticks altitude by
-- climbSpeed unconditionally; see "Fuel is no longer a flight constraint").
-- hud_primary is relabeled ALT->DIST ("고도"->"거리") below, and this extra
-- gap is inserted between the DIST/CASH line and the fuel/status line
-- during ascending/returning so the two numbers read as visually unrelated.
M.hudPrimaryStatusGap = 24

-- docs/feedback/INBOX.md UI/HUD item 5: the small C%/P%/S%/AVG$ slot-odds
-- line drawn above the minimap during the returning phase needs its own
-- reserved vertical space in the HUD box; without it the line collided
-- with the RETURN %%/s-left text right above it (confirmed via a real
-- LÖVE runtime capture, GAME_CAPTURE_PHASE=returning-odds).
M.hudOddsLineHeight = 40

-- docs/feedback/INBOX.md UI/HUD item 4: the "개발 임시본"/"DEV PLACEHOLDER"
-- footer text is a permanent dev-only disclaimer (kept until real AetherAI
-- assets land), not gameplay information, so it should read as a quiet
-- watermark instead of competing with the message line above it. Smaller
-- font + lower alpha than the default text keeps it legible but visually
-- de-emphasized.
M.devPlaceholderFontSize = 28
M.devPlaceholderAlpha = 0.4
-- Scene fonts: old 8/14 ×4 so text keeps the same screen fraction on
-- 720×1280 (integer-scale 1 is now a 720×1280 window, not 180×320).
M.smallFontSize = 32
M.hudFontSize = 56

-- docs/feedback/INBOX.md "내부 해상도를 발라트로 수준으로 상향" — remaining
-- decorative px: the floating "+$N"/"-N" sample/damage text box was still
-- the old 180x320-era 30px half-width / 10px vertical offset. ×4 so it
-- keeps the same screen fraction on the 720x1280 canvas.
M.floatingTextBoxHalfWidth = 120
M.floatingTextBoxTopOffset = 40
-- Launch-screen Earth disc (world origin, screen y = earthCenterY - cameraY).
M.earthCenterY = 300
M.earthRadius = 232

-- Shared HUD background-box height so the minimap placement (drawMinimap)
-- and the actual text draw (draw) never disagree about how tall the top
-- HUD band is.
function M.hudHeight(phase, hud, galaxyShift)
    if phase == "launch" then
        return M.launchHudHeight + galaxyShift
    end
    if hud.returnProgress then
        return 280 + M.hudPrimaryStatusGap + M.hudOddsLineHeight + galaxyShift
    end
    if hud.samples then
        return 184 + M.hudPrimaryStatusGap + galaxyShift
    end
    if hud.best then
        return 184 + galaxyShift
    end
    return 136 + galaxyShift
end

-- docs/feedback/INBOX.md UI 대개편 6건 item 4: the small C%/P%/S%/EV$
-- slot-odds readout near the minimap was unclear enough that the user
-- mistook it for coordinates, and lost its meaning once the slot machine
-- moved to the Earth shop (item 15). Replaced by the ship's actual world
-- coordinates in "(x, y)" form. Pure function so it's easy to unit test in
-- isolation from love.graphics.
function M.shipCoordsLine(x, y)
    return string.format("(%d, %d)", math.floor(x + 0.5), math.floor(y + 0.5))
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

-- docs/feedback/INBOX.md 국제화 누락 + 발라트로식 점수 연출 + HUD 약자 정리 항목 (2):
-- Balatro-style score punch for the DIST HUD number, mirroring the
-- sample-pickup ship scale-punch pattern above. Fires whenever
-- run.bestAltitude (the all-time record, not the current-run altitude)
-- increases -- i.e. exactly at the moment a new personal best is set --
-- so the number that is actually a "score" gets the same emphasis
-- Balatro gives a chip/mult scoreboard update.
local distancePunchDuration = 0.3
M.distancePunchDuration = distancePunchDuration

-- Pure function: given the remaining countdown (distancePunchDuration down
-- to 0, same convention as shipPunch) returns the scale multiplier to draw
-- the DIST text at. 1.0 at rest, up to 1.5x at the instant the punch fires.
local function distancePunchScale(remaining, duration)
    if duration <= 0 then return 1 end
    remaining = math.max(0, math.min(duration, remaining))
    return 1 + (remaining / duration) * 0.5
end
M.distancePunchScale = distancePunchScale

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
local shopActionColumnX, shopActionColumnW = 64, 400
local shopStatusColumnX, shopStatusColumnW = 464, 208
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
local shopColumnLeftX, shopColumnLeftW = 64, 272
local shopColumnRightX, shopColumnRightW = 352, 272
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

local function specimenImagePath(id)
    return "assets/sprites/specimens/" .. id .. ".png"
end

local function loadSpecimenImages()
    local images = {}
    if not (love and love.graphics and love.graphics.newImage) then
        return images
    end
    for _, entry in ipairs(world.specimenCatalog()) do
        local path = specimenImagePath(entry.id)
        local ok, img = pcall(love.graphics.newImage, path)
        if ok and img then
            img:setFilter("nearest", "nearest")
            images[entry.id] = img
        end
    end
    return images
end

function M.new(options)
    options = options or {}
    local ship = shipModule.new()
    local altitudeStore = options.bestAltitudeStore or bestAltitudeStore.new()
    local specimenStore = options.collectionStore or collectionStore.new()
    if love.graphics then
        love.graphics.setFont(fonts.get(M.hudFontSize))
    end
    -- assets/ship/ship_default.png is the ComfyUI-generated ship sprite
    -- (docs/GENERATED_ASSET_LOG.md). shipImagePath is always recorded (even
    -- under GAME_HEADLESS=1, where conf.lua disables the graphics module
    -- entirely and no love.graphics.Image can be constructed) so
    -- engine-hosted tests can verify the wiring; shipImage is the actual
    -- drawable Image object used by :draw() whenever graphics are enabled.
    local shipImagePath = "assets/ship/ship_default.png"
    local shipImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, shipImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            shipImage = img
        end
    end
    -- assets/planet/planet_generic.png is the ComfyUI-generated neutral-tone
    -- planet sprite (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated-image pattern as shipImage above; :draw() tints this
    -- single grayscale sprite per-planet with the existing planetColor()
    -- hue lookup instead of drawing a flat filled circle, and falls back to
    -- the flat circle whenever the image failed to load.
    local planetImagePath = "assets/planet/planet_generic.png"
    local planetImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, planetImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            planetImage = img
        end
    end
    -- assets/earth/earth_generic.png is the ComfyUI-generated Earth sprite
    -- (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated-image pattern as shipImage/planetImage above; :draw()
    -- draws this sprite instead of the flat ocean-circle + two green-blob
    -- fills, and falls back to the flat circle whenever the image failed
    -- to load.
    local earthImagePath = "assets/earth/earth_generic.png"
    local earthImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, earthImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            earthImage = img
        end
    end

    -- assets/effects/sample_sparkle.png is the ComfyUI-generated sample
    -- pickup effect sprite (docs/GENERATED_ASSET_LOG.md). draw() tints and
    -- scales it per-particle instead of drawing a flat love.graphics.circle
    -- fill, and falls back to the flat circle whenever the image failed to
    -- load (same fallback pattern as ship/planet/earth above).
    local sampleEffectImagePath = "assets/effects/sample_sparkle.png"
    local sampleEffectImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, sampleEffectImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            sampleEffectImage = img
        end
    end
    -- assets/backgrounds/deep_space_tile.png is the ComfyUI-generated deep-
    -- space nebula backdrop (docs/GENERATED_ASSET_LOG.md). draw() tiles it
    -- (wrap-repeat quad) as a near-static backdrop layer drawn behind the
    -- existing backgroundStars()/stars() point layers, and falls back to
    -- the flat clear color only when the image failed to load (same
    -- fallback pattern as ship/planet/earth/effect above).
    local backgroundImagePath = "assets/backgrounds/deep_space_tile.png"
    local backgroundImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, backgroundImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            pcall(img.setWrap, img, "repeat", "repeat")
            backgroundImage = img
        end
    end
    -- assets/slot_symbols/{comet,planet,star}.png are the ComfyUI-generated
    -- returning-phase slot-machine reel icons (docs/GENERATED_ASSET_LOG.md).
    -- slotSymbolImagePaths is always fully populated (even under
    -- GAME_HEADLESS=1) so engine-hosted tests can verify the wiring;
    -- slotSymbolImages holds the actual drawable Image objects :draw() uses
    -- instead of the plain "COMET  PLANET  STAR" text reel, falling back to
    -- text whenever an image failed to load (same fallback pattern as
    -- ship/planet/earth/effect/background above).
    local slotSymbolImagePaths = {
        COMET = "assets/slot_symbols/comet.png",
        PLANET = "assets/slot_symbols/planet.png",
        STAR = "assets/slot_symbols/star.png",
    }
    local slotSymbolImages = {}
    if love.graphics and love.graphics.newImage then
        for symbol, path in pairs(slotSymbolImagePaths) do
            local ok, img = pcall(love.graphics.newImage, path)
            if ok and img then
                img:setFilter("nearest", "nearest")
                slotSymbolImages[symbol] = img
            end
        end
    end
    -- assets/shop_icons/{hull,steering,yield,ship}.png are the
    -- ComfyUI-generated EARTH SHOP row icons (docs/GENERATED_ASSET_LOG.md).
    -- Same always-set-paths / graphics-gated-images pattern as
    -- slotSymbolImagePaths/slotSymbolImages above: shopIconImagePaths is
    -- always fully populated so engine-hosted tests can verify the wiring
    -- under GAME_HEADLESS=1, and shopIconImages holds the actual drawable
    -- Image objects used by :draw() (drawn beside each EARTH SHOP row's
    -- existing compact action text, not replacing any verified text
    -- placement -- see the comment above settlementRowBackgroundColors on
    -- why EARTH SHOP text positions are treated as fragile/verified).
    local shopIconImagePaths = {
        hull = "assets/shop_icons/hull.png",
        steering = "assets/shop_icons/steering.png",
        yield = "assets/shop_icons/yield.png",
        ship = "assets/shop_icons/ship.png",
    }
    local shopIconImages = {}
    if love.graphics and love.graphics.newImage then
        for key, path in pairs(shopIconImagePaths) do
            local ok, img = pcall(love.graphics.newImage, path)
            if ok and img then
                img:setFilter("nearest", "nearest")
                shopIconImages[key] = img
            end
        end
    end
    -- assets/debris/{asteroid,can,scrap}.png are ComfyUI-generated drifting
    -- hazard sprites (docs/GENERATED_ASSET_LOG.md). Same always-set-paths /
    -- graphics-gated-images pattern as shopIconImagePaths: debrisImagePaths
    -- is always fully populated so engine-hosted tests can verify wiring
    -- under GAME_HEADLESS=1, and debrisImages holds the drawables :draw()
    -- uses instead of the Lua rectangle/circle/triangle placeholders.
    local debrisImagePaths = {
        asteroid = "assets/debris/asteroid.png",
        can = "assets/debris/can.png",
        scrap = "assets/debris/scrap.png",
    }
    local debrisImages = {}
    if love.graphics and love.graphics.newImage then
        for kind, path in pairs(debrisImagePaths) do
            local ok, img = pcall(love.graphics.newImage, path)
            if ok and img then
                img:setFilter("nearest", "nearest")
                debrisImages[kind] = img
            end
        end
    end
    -- assets/effects/planet_twinkle.png is the ComfyUI-generated planet-
    -- approach twinkle sprite (docs/GENERATED_ASSET_LOG.md). Same always-
    -- set-path / graphics-gated-image pattern as sampleEffectImagePath:
    -- planetTwinkleImagePath is always set so engine-hosted tests can
    -- verify wiring under GAME_HEADLESS=1, and planetTwinkleImage holds
    -- the drawable :draw() uses instead of love.graphics.circle dots
    -- orbiting undiscovered planets.
    local planetTwinkleImagePath = "assets/effects/planet_twinkle.png"
    local planetTwinkleImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, planetTwinkleImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            planetTwinkleImage = img
        end
    end
    -- assets/effects/collision_spark.png is the ComfyUI-generated collision
    -- impact burst (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated-image pattern as planetTwinkleImagePath.
    local collisionEffectImagePath = "assets/effects/collision_spark.png"
    local collisionEffectImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, collisionEffectImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            collisionEffectImage = img
        end
    end
    -- assets/effects/thrust_plume.png is the ComfyUI-generated RCS/main-
    -- engine exhaust plume (docs/GENERATED_ASSET_LOG.md). Same always-set-
    -- path / graphics-gated-image pattern as sampleEffectImagePath.
    local thrustEffectImagePath = "assets/effects/thrust_plume.png"
    local thrustEffectImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, thrustEffectImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            thrustEffectImage = img
        end
    end
    -- assets/effects/planet_glow.png is the ComfyUI-generated undiscovered-
    -- planet rim glow (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated-image pattern as planetTwinkleImagePath. :draw() tints
    -- and scales it per-planet instead of stacking love.graphics.circle
    -- fills, and falls back to those circles when the image failed to load.
    local planetGlowImagePath = "assets/effects/planet_glow.png"
    local planetGlowImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, planetGlowImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            planetGlowImage = img
        end
    end
    -- assets/effects/planet_shadow.png is the ComfyUI-generated planet
    -- drop shadow (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated-image pattern as planetGlowImagePath. :draw() tints
    -- and scales it per-planet instead of a love.graphics.circle fill,
    -- and falls back to that circle when the image failed to load.
    local planetShadowImagePath = "assets/effects/planet_shadow.png"
    local planetShadowImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, planetShadowImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            planetShadowImage = img
        end
    end
    -- assets/effects/minimap_disc.png is the ComfyUI-generated circular
    -- galaxy-chart disc (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated-image pattern as planetShadowImagePath. drawMinimap()
    -- scales it to minimap.size instead of a love.graphics.circle fill+line,
    -- and falls back to those circles when the image failed to load.
    local minimapDiscImagePath = "assets/effects/minimap_disc.png"
    local minimapDiscImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, minimapDiscImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            minimapDiscImage = img
        end
    end
    -- assets/effects/joystick_pad.png is the ComfyUI-generated virtual
    -- joystick pad disc (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated-image pattern as minimapDiscImagePath. drawJoystickStick()
    -- scales it to joystick.visualRadius * 2 instead of a love.graphics.circle
    -- fill+line, and falls back to those circles when the image failed to load.
    local joystickPadImagePath = "assets/effects/joystick_pad.png"
    local joystickPadImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, joystickPadImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            joystickPadImage = img
        end
    end
    -- assets/effects/joystick_knob.png is the ComfyUI-generated virtual
    -- joystick thumbstick cap (docs/GENERATED_ASSET_LOG.md). Same
    -- always-set-path / graphics-gated-image pattern as joystickPadImagePath.
    -- drawJoystickStick() scales it to joystick.visualKnobRadius * 2 instead
    -- of a love.graphics.circle fill, and falls back to that circle when
    -- the image failed to load.
    local joystickKnobImagePath = "assets/effects/joystick_knob.png"
    local joystickKnobImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, joystickKnobImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            joystickKnobImage = img
        end
    end
    -- assets/effects/hud_coin.png is the ComfyUI-generated CASH HUD coin
    -- (docs/GENERATED_ASSET_LOG.md). Same always-set-path / graphics-gated
    -- image pattern as joystickKnobImagePath. draw() scales it to
    -- M.cashIconSize instead of M.coinIconPoints, and falls back to that
    -- octagon polygon when the image failed to load.
    local cashIconImagePath = "assets/effects/hud_coin.png"
    local cashIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, cashIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            cashIconImage = img
        end
    end
    -- assets/effects/hud_shield.png is the ComfyUI-generated hull-durability
    -- HUD shield (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated image pattern as cashIconImagePath. draw() scales it
    -- to M.hullIconSize instead of M.shieldIconPoints, and falls back to
    -- that pentagon polygon when the image failed to load.
    local hullIconImagePath = "assets/effects/hud_shield.png"
    local hullIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, hullIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            hullIconImage = img
        end
    end
    -- assets/effects/hud_speed.png is the ComfyUI-generated STEER SPEED HUD
    -- speedometer (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated image pattern as hullIconImagePath. draw() scales it
    -- to M.speedIconSize instead of M.speedIconPoints, and falls back to
    -- that semicircle+needle polygon when the image failed to load.
    local speedIconImagePath = "assets/effects/hud_speed.png"
    local speedIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, speedIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            speedIconImage = img
        end
    end
    -- assets/effects/minimap_checkpoint_star.png is the ComfyUI-generated
    -- checkpoint-galaxy waypoint star (docs/GENERATED_ASSET_LOG.md). Same
    -- always-set-path / graphics-gated image pattern as speedIconImagePath.
    -- drawMinimap() scales it to 2 * minimap.markerGalaxyHubRadius instead
    -- of minimap.starPoints, and falls back to that 5-point polygon when
    -- the image failed to load.
    local checkpointStarImagePath = "assets/effects/minimap_checkpoint_star.png"
    local checkpointStarImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, checkpointStarImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            checkpointStarImage = img
        end
    end
    -- assets/effects/minimap_checkpoint_arrow.png is the ComfyUI-generated
    -- off-chart checkpoint direction arrow (docs/GENERATED_ASSET_LOG.md).
    -- Same always-set-path / graphics-gated image pattern as
    -- checkpointStarImagePath. drawMinimap() scales it to
    -- 2 * minimap.markerCheckpointTipRadius, rotates it toward the nearest
    -- off-chart checkpoint, and falls back to the Lua circle+triangle
    -- polygon when the image failed to load.
    local checkpointArrowImagePath = "assets/effects/minimap_checkpoint_arrow.png"
    local checkpointArrowImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, checkpointArrowImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            checkpointArrowImage = img
        end
    end
    -- assets/effects/minimap_player.png is the ComfyUI-generated
    -- you-are-here player location marker (docs/GENERATED_ASSET_LOG.md).
    -- Same always-set-path / graphics-gated image pattern as
    -- checkpointArrowImagePath. drawMinimap() scales it to
    -- 2 * minimap.markerPlayerLineRadius instead of the Lua filled
    -- circle + outline, and falls back to those circles when the
    -- image failed to load.
    local playerMarkerImagePath = "assets/effects/minimap_player.png"
    local playerMarkerImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, playerMarkerImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            playerMarkerImage = img
        end
    end
    -- assets/effects/minimap_sun.png is the ComfyUI-generated
    -- sun waypoint marker (docs/GENERATED_ASSET_LOG.md). Same
    -- always-set-path / graphics-gated image pattern as
    -- playerMarkerImagePath. drawMinimap() scales it to
    -- 2 * minimap.markerSunRadius instead of the Lua filled
    -- circle, and falls back to that circle when the image
    -- failed to load.
    local sunMarkerImagePath = "assets/effects/minimap_sun.png"
    local sunMarkerImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, sunMarkerImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            sunMarkerImage = img
        end
    end
    -- assets/effects/minimap_earth.png is the ComfyUI-generated
    -- Earth waypoint marker (docs/GENERATED_ASSET_LOG.md). Same
    -- always-set-path / graphics-gated image pattern as
    -- sunMarkerImagePath. drawMinimap() scales it to
    -- 2 * minimap.markerEarthRadius instead of the Lua filled
    -- circle, and falls back to that circle when the image
    -- failed to load.
    local earthMarkerImagePath = "assets/effects/minimap_earth.png"
    local earthMarkerImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, earthMarkerImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            earthMarkerImage = img
        end
    end
    -- assets/effects/minimap_galaxy_home.png is the ComfyUI-generated
    -- home-galaxy (milkyway) waypoint marker (docs/GENERATED_ASSET_LOG.md).
    -- Same always-set-path / graphics-gated image pattern as
    -- earthMarkerImagePath. drawMinimap() scales it to
    -- 2 * minimap.markerGalaxyHomeRadius instead of the Lua filled
    -- circle, and falls back to that circle when the image
    -- failed to load.
    local galaxyHomeMarkerImagePath = "assets/effects/minimap_galaxy_home.png"
    local galaxyHomeMarkerImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, galaxyHomeMarkerImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            galaxyHomeMarkerImage = img
        end
    end
    -- assets/effects/minimap_galaxy_plain.png is the ComfyUI-generated
    -- generic (non-home, non-checkpoint) galaxy waypoint marker
    -- (docs/GENERATED_ASSET_LOG.md). Same always-set-path / graphics-gated
    -- image pattern as galaxyHomeMarkerImagePath. drawMinimap() scales it
    -- to 2 * minimap.markerGalaxyPlainRadius instead of the Lua filled
    -- circle, and falls back to that circle when the image failed to load.
    local galaxyPlainMarkerImagePath = "assets/effects/minimap_galaxy_plain.png"
    local galaxyPlainMarkerImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, galaxyPlainMarkerImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            galaxyPlainMarkerImage = img
        end
    end
    -- assets/effects/minimap_earth_return.png is the ComfyUI-generated
    -- off-chart Earth-return rim marker (docs/GENERATED_ASSET_LOG.md).
    -- Same always-set-path / graphics-gated image pattern as
    -- galaxyPlainMarkerImagePath. drawMinimap() scales it to
    -- 2 * minimap.markerBeyondRadius, rotates it toward Earth (sprite
    -- default is up / -y), and falls back to the Lua filled circle
    -- when the image failed to load.
    local earthReturnMarkerImagePath = "assets/effects/minimap_earth_return.png"
    local earthReturnMarkerImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, earthReturnMarkerImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            earthReturnMarkerImage = img
        end
    end
    -- assets/effects/minimap_spiral_star.png is the ComfyUI-generated
    -- galaxy spiral-arm point marker (docs/GENERATED_ASSET_LOG.md).
    -- Same always-set-path / graphics-gated image pattern as
    -- earthReturnMarkerImagePath. drawMinimap() scales it to 2.8
    -- (matching the old Lua filled-circle radius 1.4) and falls back
    -- to that circle when the image failed to load.
    local spiralArmImagePath = "assets/effects/minimap_spiral_star.png"
    local spiralArmImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, spiralArmImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            spiralArmImage = img
        end
    end
    -- assets/effects/minimap_orbit_ring.png is the ComfyUI-generated
    -- solar-system orbit ring (docs/GENERATED_ASSET_LOG.md). Same
    -- always-set-path / graphics-gated image pattern as
    -- spiralArmImagePath. drawMinimap() scales it to 2 * ring.radius
    -- for kind=="orbit" rings and falls back to the Lua line circle
    -- when the image failed to load.
    local orbitRingImagePath = "assets/effects/minimap_orbit_ring.png"
    local orbitRingImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, orbitRingImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            orbitRingImage = img
        end
    end
    -- assets/effects/minimap_galaxy_ring.png is the ComfyUI-generated
    -- galaxy-disk ring (docs/GENERATED_ASSET_LOG.md). Same always-set-path
    -- / graphics-gated image pattern as orbitRingImagePath. drawMinimap()
    -- scales it to 2 * ring.radius for kind=="galaxy" rings and falls
    -- back to the Lua line circle when the image failed to load.
    local galaxyRingImagePath = "assets/effects/minimap_galaxy_ring.png"
    local galaxyRingImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, galaxyRingImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            galaxyRingImage = img
        end
    end
    -- assets/planet/planet_hub.png is the ComfyUI-generated galaxy
    -- hub/checkpoint planet (docs/GENERATED_ASSET_LOG.md). Same
    -- always-set-path / graphics-gated image pattern as
    -- galaxyRingImagePath. :draw() uses it for planet.hub landmarks
    -- instead of planet_generic.png, and falls back to planetImage
    -- (then the Lua circle) when the image failed to load.
    local hubPlanetImagePath = "assets/planet/planet_hub.png"
    local hubPlanetImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, hubPlanetImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            hubPlanetImage = img
        end
    end
    -- assets/planet/planet_shop.png is the ComfyUI-generated galaxy
    -- shop/market planet (docs/GENERATED_ASSET_LOG.md). Same
    -- always-set-path / graphics-gated image pattern as
    -- hubPlanetImagePath. :draw() uses it for planet.shop landmarks
    -- instead of planet_generic.png, and falls back to planetImage
    -- (then the Lua circle) when the image failed to load.
    local shopPlanetImagePath = "assets/planet/planet_shop.png"
    local shopPlanetImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, shopPlanetImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            shopPlanetImage = img
        end
    end
    -- assets/effects/hud_panel.png is the ComfyUI-generated top HUD
    -- status-bar panel (docs/GENERATED_ASSET_LOG.md). Same always-set-path
    -- / graphics-gated image pattern as shopPlanetImagePath. :draw()
    -- stretches it across the HUD band instead of the Lua fill rectangle,
    -- and falls back to that rectangle when the image failed to load.
    local hudPanelImagePath = "assets/effects/hud_panel.png"
    local hudPanelImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, hudPanelImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            hudPanelImage = img
        end
    end
    -- assets/effects/loadout_panel.png is the ComfyUI-generated launch
    -- LOADOUT card panel (docs/GENERATED_ASSET_LOG.md). Same always-set-path
    -- / graphics-gated image pattern as hudPanelImagePath. :draw()
    -- stretches it across the launch loadout box instead of the Lua fill
    -- rectangle, and falls back to that rectangle when the image failed
    -- to load.
    local loadoutPanelImagePath = "assets/effects/loadout_panel.png"
    local loadoutPanelImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, loadoutPanelImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            loadoutPanelImage = img
        end
    end
    -- assets/effects/shop_panel.png is the ComfyUI-generated EARTH SHOP
    -- card panel (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated image pattern as loadoutPanelImagePath. :draw()
    -- stretches it across the settlement shop box instead of the Lua fill
    -- rectangle, and falls back to that rectangle when the image failed
    -- to load.
    local shopPanelImagePath = "assets/effects/shop_panel.png"
    local shopPanelImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, shopPanelImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            shopPanelImage = img
        end
    end
    -- assets/effects/destroyed_panel.png is the ComfyUI-generated
    -- destroyed-phase summary card panel (docs/GENERATED_ASSET_LOG.md).
    -- Same always-set-path / graphics-gated image pattern as
    -- shopPanelImagePath. :draw() stretches it across the destroyed
    -- summary box instead of the Lua fill rectangle, and falls back to
    -- that rectangle when the image failed to load.
    local destroyedPanelImagePath = "assets/effects/destroyed_panel.png"
    local destroyedPanelImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, destroyedPanelImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            destroyedPanelImage = img
        end
    end
    -- assets/effects/slot_result_panel.png is the ComfyUI-generated
    -- returning-phase slot result card panel (docs/GENERATED_ASSET_LOG.md).
    -- Same always-set-path / graphics-gated image pattern as
    -- destroyedPanelImagePath. :draw() stretches it across the slot
    -- result box instead of the Lua fill rectangle, and falls back to
    -- that rectangle when the image failed to load.
    local slotResultPanelImagePath = "assets/effects/slot_result_panel.png"
    local slotResultPanelImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, slotResultPanelImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            slotResultPanelImage = img
        end
    end
    -- assets/effects/slot_spin_button.png is the ComfyUI-generated
    -- returning-phase slot SPIN button (docs/GENERATED_ASSET_LOG.md).
    -- Same always-set-path / graphics-gated image pattern as
    -- slotResultPanelImagePath. :draw() stretches it across the slot
    -- spin hit box instead of the Lua fill rectangle, and falls back
    -- to that rectangle when the image failed to load.
    local slotSpinButtonImagePath = "assets/effects/slot_spin_button.png"
    local slotSpinButtonImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, slotSpinButtonImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            slotSpinButtonImage = img
        end
    end
    -- assets/effects/specimen_banner.png is the ComfyUI-generated
    -- new-specimen discovery banner panel (docs/GENERATED_ASSET_LOG.md).
    -- Same always-set-path / graphics-gated image pattern as
    -- slotSpinButtonImagePath. :draw() stretches it across the banner
    -- box instead of the Lua fill rectangle, and falls back to that
    -- rectangle when the image failed to load.
    local specimenBannerImagePath = "assets/effects/specimen_banner.png"
    local specimenBannerImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, specimenBannerImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            specimenBannerImage = img
        end
    end
    -- assets/effects/settlement_summary_panel.png is the ComfyUI-generated
    -- EARTH SHOP settlement summary inner box (docs/GENERATED_ASSET_LOG.md).
    -- Same always-set-path / graphics-gated image pattern as
    -- specimenBannerImagePath. :draw() stretches it across the summary
    -- inner box instead of the Lua fill rectangle, and falls back to
    -- that rectangle when the image failed to load.
    local settlementSummaryPanelImagePath = "assets/effects/settlement_summary_panel.png"
    local settlementSummaryPanelImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, settlementSummaryPanelImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            settlementSummaryPanelImage = img
        end
    end
    -- assets/effects/shop_touch_row.png is the ComfyUI-generated EARTH SHOP
    -- tappable settlementTouchRows band (docs/GENERATED_ASSET_LOG.md). Same
    -- always-set-path / graphics-gated image pattern as
    -- settlementSummaryPanelImagePath. :draw() stretches it across each
    -- settlementTouchRows band instead of the Lua fill rectangle, and
    -- falls back to that rectangle when the image failed to load.
    local shopTouchRowImagePath = "assets/effects/shop_touch_row.png"
    local shopTouchRowImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, shopTouchRowImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            shopTouchRowImage = img
        end
    end
    -- assets/effects/planet_rim.png is the ComfyUI-generated planet
    -- discovery rim ring (docs/GENERATED_ASSET_LOG.md). Same always-set-path
    -- / graphics-gated image pattern as shopTouchRowImagePath. :draw()
    -- scales it to 2 * (planet.radius + 2/3) instead of love.graphics.circle
    -- "line" rims, and falls back to those line circles when the image
    -- failed to load.
    local planetRimImagePath = "assets/effects/planet_rim.png"
    local planetRimImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, planetRimImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            planetRimImage = img
        end
    end
    -- assets/effects/star_point.png is the ComfyUI-generated playfield
    -- star sparkle (docs/GENERATED_ASSET_LOG.md). Same always-set-path
    -- / graphics-gated image pattern as planetRimImagePath. :draw()
    -- scales it over backgroundStars()/stars() instead of
    -- love.graphics.points, and falls back to those points when the
    -- image failed to load.
    local starPointImagePath = "assets/effects/star_point.png"
    local starPointImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, starPointImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            starPointImage = img
        end
    end
    -- assets/effects/ship_silhouette.png is the ComfyUI-generated ship
    -- body silhouette (docs/GENERATED_ASSET_LOG.md). Same always-set-path
    -- / graphics-gated image pattern as starPointImagePath. :draw() uses
    -- it instead of the Lua triangle polygon when shipImage failed to
    -- load, and falls back to that polygon when this image also failed.
    local shipSilhouetteImagePath = "assets/effects/ship_silhouette.png"
    local shipSilhouetteImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, shipSilhouetteImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            shipSilhouetteImage = img
        end
    end
    -- assets/effects/launch_rocket.png is the ComfyUI-generated TAP-TO-LAUNCH
    -- rocket icon (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated image pattern as shipSilhouetteImagePath. :draw() uses
    -- it instead of the Lua rocketIconPoints polygon when
    -- showLaunchRocketIcon is true, and falls back to that polygon when
    -- this image failed to load.
    local launchRocketImagePath = "assets/effects/launch_rocket.png"
    local launchRocketImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, launchRocketImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            launchRocketImage = img
        end
    end
    -- assets/ship/ship_scout.png is the ComfyUI-generated SCOUT hull
    -- (docs/GENERATED_ASSET_LOG.md). Same always-set-path / graphics-gated
    -- image pattern as launchRocketImagePath. :draw() uses it when
    -- selectedShipId == "scout" instead of ship_default.png, and falls
    -- back to shipImage / shipSilhouetteImage / the Lua triangle.
    local scoutShipImagePath = "assets/ship/ship_scout.png"
    local scoutShipImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, scoutShipImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            scoutShipImage = img
        end
    end
    -- assets/effects/hud_distance.png is the ComfyUI-generated DIST HUD
    -- nav-diamond (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated image pattern as scoutShipImagePath. :draw() scales
    -- it to M.distanceIconSize instead of M.distanceIconPoints, and falls
    -- back to that diamond polygon when the image failed to load.
    local distanceIconImagePath = "assets/effects/hud_distance.png"
    local distanceIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, distanceIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            distanceIconImage = img
        end
    end
    -- assets/effects/hud_best.png is the ComfyUI-generated PERSONAL BEST
    -- HUD trophy (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated image pattern as distanceIconImagePath. :draw()
    -- scales it to M.bestIconSize instead of M.bestIconPoints, and falls
    -- back to that trophy polygon when the image failed to load.
    local bestIconImagePath = "assets/effects/hud_best.png"
    local bestIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, bestIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            bestIconImage = img
        end
    end
    -- assets/effects/hud_samples.png is the ComfyUI-generated SAMPLES HUD
    -- specimen vial (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated image pattern as bestIconImagePath. :draw() scales
    -- it to M.samplesIconSize instead of M.samplesIconPoints, and falls
    -- back to that flask polygon when the image failed to load.
    local samplesIconImagePath = "assets/effects/hud_samples.png"
    local samplesIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, samplesIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            samplesIconImage = img
        end
    end
    -- assets/effects/hud_galaxy.png is the ComfyUI-generated galaxy-name
    -- HUD star (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated image pattern as samplesIconImagePath. :draw()
    -- scales it to M.galaxyIconSize instead of M.galaxyIconPoints, and
    -- falls back to that 8-point star polygon when the image failed to load.
    local galaxyIconImagePath = "assets/effects/hud_galaxy.png"
    local galaxyIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, galaxyIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            galaxyIconImage = img
        end
    end
    -- assets/effects/hud_return.png is the ComfyUI-generated RETURN
    -- progress HUD chevron (docs/GENERATED_ASSET_LOG.md). Same
    -- always-set-path / graphics-gated image pattern as
    -- galaxyIconImagePath. :draw() scales it to M.returnIconSize instead
    -- of M.returnIconPoints, and falls back to that downward chevron
    -- polygon when the image failed to load.
    local returnIconImagePath = "assets/effects/hud_return.png"
    local returnIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, returnIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            returnIconImage = img
        end
    end
    -- assets/effects/hud_earth.png is the ComfyUI-generated EARTH
    -- distance HUD globe (docs/GENERATED_ASSET_LOG.md). Same
    -- always-set-path / graphics-gated image pattern as
    -- returnIconImagePath. :draw() scales it to M.earthIconSize instead
    -- of M.earthIconPoints, and falls back to that octagon globe
    -- polygon when the image failed to load.
    local earthIconImagePath = "assets/effects/hud_earth.png"
    local earthIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, earthIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            earthIconImage = img
        end
    end
    -- assets/effects/planet_sample.png is the ComfyUI-generated planet
    -- approach SAMPLE $N crystal (docs/GENERATED_ASSET_LOG.md). Same
    -- always-set-path / graphics-gated image pattern as
    -- earthIconImagePath. :draw() scales it to M.sampleValueIconSize
    -- instead of M.sampleValueIconPoints, and falls back to that
    -- hexagonal crystal polygon when the image failed to load.
    local sampleValueIconImagePath = "assets/effects/planet_sample.png"
    local sampleValueIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, sampleValueIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            sampleValueIconImage = img
        end
    end
    -- assets/effects/planet_risk.png is the ComfyUI-generated planet
    -- approach RISK/LETHAL warning triangle
    -- (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated image pattern as sampleValueIconImagePath.
    -- :draw() scales it to M.riskIconSize instead of M.riskIconPoints,
    -- and falls back to that warning-triangle polygon when the image
    -- failed to load.
    local riskIconImagePath = "assets/effects/planet_risk.png"
    local riskIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, riskIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            riskIconImage = img
        end
    end
    -- assets/effects/floating_sample.png is the ComfyUI-generated
    -- floating sample-pickup "+$N" plus-badge
    -- (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated image pattern as riskIconImagePath. :draw()
    -- scales it to M.floatingSampleIconSize instead of
    -- M.floatingSampleIconPoints, and falls back to that plus-badge
    -- polygon when the image failed to load.
    local floatingSampleIconImagePath = "assets/effects/floating_sample.png"
    local floatingSampleIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, floatingSampleIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            floatingSampleIconImage = img
        end
    end
    -- assets/effects/floating_damage.png is the ComfyUI-generated
    -- floating damage "-N" minus-badge
    -- (docs/GENERATED_ASSET_LOG.md). Same always-set-path /
    -- graphics-gated image pattern as floatingSampleIconImagePath.
    -- :draw() scales it to M.floatingDamageIconSize instead of
    -- M.floatingDamageIconPoints, and falls back to that minus-badge
    -- polygon when the image failed to load.
    local floatingDamageIconImagePath = "assets/effects/floating_damage.png"
    local floatingDamageIconImage = nil
    if love.graphics and love.graphics.newImage then
        local ok, img = pcall(love.graphics.newImage, floatingDamageIconImagePath)
        if ok and img then
            img:setFilter("nearest", "nearest")
            floatingDamageIconImage = img
        end
    end
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
        slotSymbolImages = slotSymbolImages,
        slotSymbolImagePaths = slotSymbolImagePaths,
        shopIconImages = shopIconImages,
        shopIconImagePaths = shopIconImagePaths,
        debrisImages = debrisImages,
        debrisImagePaths = debrisImagePaths,
        planetTwinkleImage = planetTwinkleImage,
        planetTwinkleImagePath = planetTwinkleImagePath,
        collisionEffectImage = collisionEffectImage,
        collisionEffectImagePath = collisionEffectImagePath,
        thrustEffectImage = thrustEffectImage,
        thrustEffectImagePath = thrustEffectImagePath,
        planetGlowImage = planetGlowImage,
        planetGlowImagePath = planetGlowImagePath,
        planetShadowImage = planetShadowImage,
        planetShadowImagePath = planetShadowImagePath,
        minimapDiscImage = minimapDiscImage,
        minimapDiscImagePath = minimapDiscImagePath,
        joystickPadImage = joystickPadImage,
        joystickPadImagePath = joystickPadImagePath,
        joystickKnobImage = joystickKnobImage,
        joystickKnobImagePath = joystickKnobImagePath,
        cashIconImage = cashIconImage,
        cashIconImagePath = cashIconImagePath,
        hullIconImage = hullIconImage,
        hullIconImagePath = hullIconImagePath,
        speedIconImage = speedIconImage,
        speedIconImagePath = speedIconImagePath,
        checkpointStarImage = checkpointStarImage,
        checkpointStarImagePath = checkpointStarImagePath,
        checkpointArrowImage = checkpointArrowImage,
        checkpointArrowImagePath = checkpointArrowImagePath,
        playerMarkerImage = playerMarkerImage,
        playerMarkerImagePath = playerMarkerImagePath,
        sunMarkerImage = sunMarkerImage,
        sunMarkerImagePath = sunMarkerImagePath,
        earthMarkerImage = earthMarkerImage,
        earthMarkerImagePath = earthMarkerImagePath,
        galaxyHomeMarkerImage = galaxyHomeMarkerImage,
        galaxyHomeMarkerImagePath = galaxyHomeMarkerImagePath,
        galaxyPlainMarkerImage = galaxyPlainMarkerImage,
        galaxyPlainMarkerImagePath = galaxyPlainMarkerImagePath,
        earthReturnMarkerImage = earthReturnMarkerImage,
        earthReturnMarkerImagePath = earthReturnMarkerImagePath,
        spiralArmImage = spiralArmImage,
        spiralArmImagePath = spiralArmImagePath,
        orbitRingImage = orbitRingImage,
        orbitRingImagePath = orbitRingImagePath,
        galaxyRingImage = galaxyRingImage,
        galaxyRingImagePath = galaxyRingImagePath,
        hubPlanetImage = hubPlanetImage,
        hubPlanetImagePath = hubPlanetImagePath,
        shopPlanetImage = shopPlanetImage,
        shopPlanetImagePath = shopPlanetImagePath,
        hudPanelImage = hudPanelImage,
        hudPanelImagePath = hudPanelImagePath,
        loadoutPanelImage = loadoutPanelImage,
        loadoutPanelImagePath = loadoutPanelImagePath,
        shopPanelImage = shopPanelImage,
        shopPanelImagePath = shopPanelImagePath,
        destroyedPanelImage = destroyedPanelImage,
        destroyedPanelImagePath = destroyedPanelImagePath,
        slotResultPanelImage = slotResultPanelImage,
        slotResultPanelImagePath = slotResultPanelImagePath,
        slotSpinButtonImage = slotSpinButtonImage,
        slotSpinButtonImagePath = slotSpinButtonImagePath,
        specimenBannerImage = specimenBannerImage,
        specimenBannerImagePath = specimenBannerImagePath,
        settlementSummaryPanelImage = settlementSummaryPanelImage,
        settlementSummaryPanelImagePath = settlementSummaryPanelImagePath,
        shopTouchRowImage = shopTouchRowImage,
        shopTouchRowImagePath = shopTouchRowImagePath,
        planetRimImage = planetRimImage,
        planetRimImagePath = planetRimImagePath,
        starPointImage = starPointImage,
        starPointImagePath = starPointImagePath,
        shipSilhouetteImage = shipSilhouetteImage,
        shipSilhouetteImagePath = shipSilhouetteImagePath,
        launchRocketImage = launchRocketImage,
        launchRocketImagePath = launchRocketImagePath,
        scoutShipImage = scoutShipImage,
        scoutShipImagePath = scoutShipImagePath,
        distanceIconImage = distanceIconImage,
        distanceIconImagePath = distanceIconImagePath,
        bestIconImage = bestIconImage,
        bestIconImagePath = bestIconImagePath,
        samplesIconImage = samplesIconImage,
        samplesIconImagePath = samplesIconImagePath,
        galaxyIconImage = galaxyIconImage,
        galaxyIconImagePath = galaxyIconImagePath,
        returnIconImage = returnIconImage,
        returnIconImagePath = returnIconImagePath,
        earthIconImage = earthIconImage,
        earthIconImagePath = earthIconImagePath,
        sampleValueIconImage = sampleValueIconImage,
        sampleValueIconImagePath = sampleValueIconImagePath,
        riskIconImage = riskIconImage,
        riskIconImagePath = riskIconImagePath,
        floatingSampleIconImage = floatingSampleIconImage,
        floatingSampleIconImagePath = floatingSampleIconImagePath,
        floatingDamageIconImage = floatingDamageIconImage,
        floatingDamageIconImagePath = floatingDamageIconImagePath,
        specimenImages = loadSpecimenImages(),
        expedition = expedition.new({ bestAltitude = altitudeStore:load() }),
        lastKnownBestAltitude = altitudeStore:load(),
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
        distancePunch = 0,
        slotSpin = nil,
        touches = {},
        verticalOffset = 0,
        rcsCooldown = 0,
        dockedShopPlanetId = nil,
        dockedShopGalaxyId = nil,
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
            kind = "sample",
        })
    end
    self.shipPunch = shipPunchDuration
end

-- Short orange/red burst at a hull impact. Distinct from sample-pickup
-- sparkles so collision reads as damage, not a collect.
function M:spawnCollisionParticles(x, y)
    local count = 10
    for i = 1, count do
        local angle = (i / count) * math.pi * 2 + math.random() * 0.4
        local speed = 50 + math.random() * 60
        table.insert(self.particles, {
            x = x,
            y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            timer = 0.4,
            maxTimer = 0.4,
            r = 1,
            g = 0.45,
            b = 0.2,
            kind = "collision",
        })
    end
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
    local box = 32
    local gap = 12
    local totalWidth = #catalog * box + (#catalog - 1) * gap
    local startX = math.floor((viewport.width - totalWidth) / 2)
    self.tinyFont = self.tinyFont or fonts.get(M.devPlaceholderFontSize)
    local previousFont = love.graphics.getFont()
    love.graphics.setFont(self.tinyFont)
    local found = self:specimenProgress()
    love.graphics.setColor(0.55, 0.65, 0.85, 0.9)
    love.graphics.printf(i18n.t("specimens_count_label", found, #catalog),
        0, y - 40, viewport.width, "center")
    for i, entry in ipairs(catalog) do
        local x = startX + (i - 1) * (box + gap)
        local sprite = self.specimenImages and self.specimenImages[entry.id]
        if sprite then
            if self.collectedSpecimens[entry.id] then
                love.graphics.setColor(1, 1, 1, 1)
            else
                love.graphics.setColor(1, 1, 1, 0.28)
            end
            love.graphics.draw(sprite, x, y, 0, box / sprite:getWidth(), box / sprite:getHeight())
        elseif self.collectedSpecimens[entry.id] then
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
        distance = i18n.t("hud_distance", math.floor(run.altitude)),
        cash = i18n.t("hud_cash", run.money),
        samples = samples,
        best = best,
        earth = earth,
        returnProgress = returnProgress,
        -- docs/feedback/INBOX.md UI/HUD item 4: the slot forecast (S%02d)
        -- is always 0 until a return trip starts ("LAUNCH S00" / "ASCEND
        -- S00" / "SETTLE S00" read as confusing dead weight), so drop that
        -- segment except during returning, where remaining chances are live.
        status = run.phase == "returning"
            and i18n.t("hud_status", run.durability,
                run.maxDurability, i18n.phaseAbbrev(run.phase), run.slotOpportunities)
            or i18n.t("hud_status_no_slots", run.durability,
                run.maxDurability, i18n.phaseAbbrev(run.phase)),
        galaxy = (run.phase == "ascending" or run.phase == "returning" or run.phase == "launch")
            and world.galaxyName(world.galaxyContaining(self.ship.x, self.ship.y))
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
        -- docs/feedback/INBOX.md UI 대개편 6건 item 2: the "HULL LV.n" line
        -- is dropped entirely -- hull durability will be shown persistently
        -- top-left (item 3's card layout) instead of duplicated here.
        steering = i18n.t("steer_speed_line", expedition.steeringSpeed(run)),
    }
end

-- Pure helper for the returning-phase slot result WIN line so tests can
-- pin the copy without drawing. Fuel-bonus wins use the pending-money
-- line; leftover fuel-reward copy keys are gone.
function M.slotWinLine(run)
    if run.lastSlotRepair and run.lastSlotRepair > 0 then
        return i18n.t("win_repair_line", run.lastSlotReward, run.lastSlotRepair)
    elseif run.lastSlotSampleBonus and run.lastSlotSampleBonus > 0 then
        return i18n.t("win_sample_line", run.lastSlotReward, run.lastSlotSampleBonus)
    end
    return i18n.t("win_pending_line", run.lastSlotReward, run.pendingSlotReward)
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
-- Returned as short lines (rather than one combined line) because the
-- combined string measures 176px at the shop's small font, wider than the
-- 148px full-width shop column (measured via GAME_FONTPROBE=1) and would
-- wrap and overlap the next row.
-- Fuel-labeled gains are omitted from the UI: fuel no longer constrains
-- flight, so "+40 FUEL" is leftover advertising. expedition.shipTradeoff
-- itself is left unchanged (econ / item 10 owns engine redefinition).
function M.scoutTradeoffLines(run)
    local tradeoff = expedition.shipTradeoff(run, "scout")
    local lines = {}
    local gain = tradeoff.gains[1]
    if gain and string.upper(tostring(gain.label)) ~= "FUEL" then
        lines[#lines + 1] = i18n.t("scout_gains_line", gain.value, gain.label)
    end
    local loss = tradeoff.losses[1]
    if loss then
        lines[#lines + 1] = i18n.t("scout_losses_line", loss.value, loss.label)
    end
    return lines
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
        -- docs/feedback/INBOX.md UI 대개편 6건 item 2: "HULL LV.n" dropped
        -- (see M:loadoutLines() above for rationale).
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

-- docs/feedback/INBOX.md 처리대기 항목 "ComfyUI로 실제 에셋 작업 진행": draws
-- the returning-phase slot-machine reel using the ComfyUI-generated
-- comet/planet/star icons (self.slotSymbolImages) instead of the plain
-- "COMET  PLANET  STAR" text row, falling back to text per-symbol whenever
-- an icon failed to load (same fallback pattern as ship/planet/earth
-- sprites elsewhere in this file). (boxX, boxY, boxW) matches the same
-- printf box the old text reel used so callers don't need to change.
local slotReelIconSize = 48
function M:drawSlotReel(symbols, boxX, boxY, boxW)
    local gap = 16
    local totalWidth = #symbols * slotReelIconSize + (#symbols - 1) * gap
    local startX = boxX + math.floor((boxW - totalWidth) / 2)
    for i, symbol in ipairs(symbols) do
        local x = startX + (i - 1) * (slotReelIconSize + gap)
        local image = self.slotSymbolImages and self.slotSymbolImages[symbol]
        if image then
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(image, x, boxY, 0,
                slotReelIconSize / image:getWidth(), slotReelIconSize / image:getHeight())
        else
            love.graphics.setColor(0.85, 0.95, 1)
            love.graphics.printf(symbol, x - 20, boxY + slotReelIconSize / 2 - 6, slotReelIconSize + 40, "center")
        end
    end
end

-- docs/feedback/INBOX.md "ComfyUI로 실제 에셋 작업 진행" 남은 부분 (shop icons):
-- draws a small ComfyUI-generated icon (self.shopIconImages[key]) to the
-- left of an EARTH SHOP row's action text, at (leftX, y) with the row's
-- text vertical center. Silently no-ops when the icon failed to load (same
-- fallback pattern as :drawSlotReel -- the text itself is unaffected either
-- way since this only draws in the margin outside the verified text
-- columns, never repositioning existing printf calls).
local shopIconSize = 24
M.shopIconSize = shopIconSize
function M:drawShopIcon(key, leftX, y)
    local image = self.shopIconImages and self.shopIconImages[key]
    if not image then
        return
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, leftX, y, 0,
        shopIconSize / image:getWidth(), shopIconSize / image:getHeight())
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
    local previousBestAltitude = self.lastKnownBestAltitude or self.expedition.bestAltitude
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
    if self.distancePunch > 0 then
        self.distancePunch = math.max(0, self.distancePunch - dt)
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
        local startOffset = self.verticalOffset
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
        local extraDy = self.verticalOffset - startOffset
        local steeringHoriz = (steering.rightActive and 1 or 0) - (steering.leftActive and 1 or 0)
        local steeringVert = (steering.downActive and 1 or 0) - (steering.upActive and 1 or 0)
        local thrusting = joyMagnitude > 0 or steeringHoriz ~= 0 or steeringVert ~= 0
        -- docs/feedback/INBOX.md 항목 11(c): expedition.burnManeuverFuel was a
        -- dead no-op (fuel is no longer a flight constraint) and has been
        -- removed from game/expedition.lua; this call site (and the
        -- extraDx/extraDistance values it alone consumed) is removed too.
        -- `thrusting` itself is still needed below to gate movement/coast.
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
            -- Coast on stored velocity. Fuel is not a flight constraint
            -- (docs/feedback/INBOX.md item 11), so there is nothing to
            -- burn or mirror here regardless of stick/key input.
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
            local mag = math.sqrt(bank * bank + lift * lift)
            local dirX = bank / mag
            local dirY = lift / mag
            
            self.particles[#self.particles + 1] = {
                x = self.ship.x - dirX * 6 + (math.random() * 4 - 2),
                y = self.ship.y - dirY * 6 + (math.random() * 4 - 2),
                vx = -dirX * (16 + math.random() * 10) + (math.random() * 8 - 4),
                vy = -dirY * (16 + math.random() * 10) + (math.random() * 8 - 4),
                timer = rcsPuffDuration,
                maxTimer = rcsPuffDuration,
                r = 0.7,
                g = 0.88,
                b = 1,
                kind = "thrust",
            }
        end
    end
    if previousPhase ~= self.expedition.phase and self.expedition.phase == "returning" then
        self:persistBestAltitude()
        self.message = i18n.t("returning_message", self.expedition.slotOpportunities)
    elseif previousPhase ~= self.expedition.phase and self.expedition.phase == "settlement" then
        self.message = i18n.t("settled_message", self.expedition.lastSettlement, self.expedition.money)
    end
    if self.expedition.phase == "ascending" or self.expedition.phase == "returning" then
        -- docs/feedback/INBOX.md 처리대기 항목 7-a: re-derive shop-planet
        -- docking fresh each update from actual proximity rather than only
        -- clearing it when the same planet reappears in the (radius-1)
        -- nearbyPlanets scan -- once the ship travels far enough the shop
        -- planet's sector may drop out of that scan entirely, which must
        -- still count as "no longer docked".
        local dockedShopStillNear = false
        for _, planet in ipairs(world.nearbyPlanets(self.ship.x, self.ship.y, 1)) do
            local dx, dy = planet.x - self.ship.x, planet.y - self.ship.y
            local distanceSquared = dx * dx + dy * dy
            -- docs/feedback/INBOX.md 처리대기 항목 8: only ordinary planets
            -- (not the galaxy's checkpoint hub or shop landmark) award
            -- samples -- hub/shop docking is handled separately below.
            if self.expedition.phase == "ascending"
                and not planet.hub and not planet.shop
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
            -- docs/feedback/INBOX.md 처리대기 항목 7-b/8: docking at a
            -- galaxy's checkpoint hub planet unconditionally grants that
            -- galaxy's unique gear part exactly once, and (in the
            -- ascending phase) immediately settles any pending sample
            -- value into money without ending the expedition.
            if planet.hub and distanceSquared <= (planet.radius + 14) ^ 2 then
                if not self.discovered[planet.id] then
                    self.discovered[planet.id] = true
                    local granted, gearId = expedition.exploreCheckpoint(self.expedition, planet.galaxyId)
                    if granted then
                        self.message = i18n.t("checkpoint_gear_message", gearId)
                    end
                    if self.expedition.phase == "ascending" then
                        local settled, amount = expedition.checkpointSettle(self.expedition)
                        if settled and amount > 0 then
                            self.message = i18n.t("checkpoint_settled_message", amount, self.expedition.money)
                        end
                    end
                end
            end
            -- docs/feedback/INBOX.md 처리대기 항목 7-a: a galaxy's shop
            -- planet is a purchase landmark, not an auto-grant -- track
            -- proximity here so keypressed() can offer a buy action while
            -- docked, mirroring the existing settlement-screen upgrade
            -- purchase keys.
            if planet.shop and distanceSquared <= (planet.radius + 14) ^ 2 then
                self.dockedShopPlanetId = planet.id
                self.dockedShopGalaxyId = planet.galaxyId
                dockedShopStillNear = true
            end
            -- docs/feedback/INBOX.md 처리대기 항목 7-b/7-a: checkpoint hub
            -- and shop landmark planets are docking points, not hazards --
            -- a ship parked on top of one to explore/buy must never take
            -- collision damage the way an ordinary planet would.
            if not planet.hub and not planet.shop
                and distanceSquared <= (planet.radius + 5) ^ 2 and not self.collided[planet.id] then
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
                self:spawnCollisionParticles(self.ship.x, self.ship.y)
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
        if not dockedShopStillNear then
            self.dockedShopPlanetId = nil
            self.dockedShopGalaxyId = nil
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
                self:spawnCollisionParticles(self.ship.x, self.ship.y)
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
    if self.expedition.bestAltitude > previousBestAltitude then
        self.distancePunch = distancePunchDuration
    end
    self.lastKnownBestAltitude = self.expedition.bestAltitude
end

function M:keypressed(key)
    -- docs/feedback/INBOX.md 처리대기 항목 7-a: while docked at a galaxy's
    -- 상점 행성 (mid-expedition, ascending or returning), "b" buys that
    -- galaxy's unique gear part for money -- a paid alternative to the
    -- free checkpoint drop (7-b) for players who reach the shop before the
    -- hub. Placed first since this action is available outside the
    -- settlement-only purchase keys below.
    if (self.expedition.phase == "ascending" or self.expedition.phase == "returning")
        and self.dockedShopPlanetId and key == "b" then
        local bought, gearId = expedition.buyShopGear(self.expedition, self.dockedShopGalaxyId)
        if bought then
            self.message = i18n.t("gear_bought_message", gearId, self.expedition.money)
        else
            self.message = purchaseShortfallMessage(self.expedition.money,
                expedition.shopGearCost, i18n.t("item_shop_gear"))
        end
        return
    end
    -- NOTE: docs/feedback/INBOX.md 항목 11(b) -- main lane already removed
    -- the EARTH SHOP fuel-tank-upgrade purchase UI (fuelAction/fuelStatus/
    -- fuelAffordable no longer returned by shopLoadoutLines()), so the
    -- former "f"/"down"/"s" -> expedition.buyFuelUpgrade() keybinding from
    -- the econ lane is intentionally NOT restored here (superseded).
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
    if key == "space" or key == "return" or key == "up" or key == "w" then
        if self.expedition.phase == "returning" and not self.slotSpin and expedition.useSlot(self.expedition) then
            self:beginSlotSpin()
        else
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
                    self.dockedShopPlanetId = nil
                    self.dockedShopGalaxyId = nil
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
                if key == "hull" then
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
    if self.joystickPadImage then
        local iw, ih = self.joystickPadImage:getDimensions()
        local scale = (radius * 2) / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, joystick.visualFillAlpha + joystick.visualLineAlpha)
        love.graphics.draw(self.joystickPadImage, ox, oy, 0, scale, scale, iw / 2, ih / 2)
    else
        -- Fallback: flat navy disc + cyan rim, used only when the
        -- ComfyUI-generated sprite failed to load.
        love.graphics.setColor(0.35, 0.55, 0.8, joystick.visualFillAlpha)
        love.graphics.circle("fill", ox, oy, radius)
        love.graphics.setColor(0.65, 0.85, 1, joystick.visualLineAlpha)
        love.graphics.circle("line", ox, oy, radius)
    end
    if self.joystickKnobImage then
        local iw, ih = self.joystickKnobImage:getDimensions()
        local scale = (knob * 2) / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, joystick.visualKnobAlpha)
        love.graphics.draw(self.joystickKnobImage, kx, ky, 0, scale, scale, iw / 2, ih / 2)
    else
        -- Fallback: pale disc, used only when the ComfyUI-generated
        -- sprite failed to load.
        love.graphics.setColor(0.9, 0.95, 1, joystick.visualKnobAlpha)
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
    local galaxyShift = hud.galaxy and 40 or 0
    local hudHeight = M.hudHeight(self.expedition.phase, hud, galaxyShift)
    local view = minimap.view(self.ship.x, self.ship.y)
    local size = minimap.size
    local cx = viewport.width - size / 2 - 3
    local cy = hudHeight + size / 2 + 2
    if self.minimapDiscImage then
        local iw, ih = self.minimapDiscImage:getDimensions()
        local scale = size / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.minimapDiscImage, cx, cy, 0, scale, scale, iw / 2, ih / 2)
    else
        -- Fallback: flat navy disc + cyan rim, used only when the
        -- ComfyUI-generated sprite failed to load.
        love.graphics.setColor(0.02, 0.04, 0.1, 1)
        love.graphics.circle("fill", cx, cy, size / 2)
        love.graphics.setColor(0.35, 0.55, 0.8, 1)
        love.graphics.circle("line", cx, cy, size / 2)
    end
    for _, ring in ipairs(view.rings or {}) do
        if ring.kind == "orbit" then
            if self.orbitRingImage then
                local iw, ih = self.orbitRingImage:getDimensions()
                local drawSize = ring.radius * 2
                local scale = drawSize / math.max(iw, ih)
                love.graphics.setColor(1, 1, 1, 0.55)
                love.graphics.draw(
                    self.orbitRingImage,
                    cx + ring.x, cy + ring.y, 0, scale, scale, iw / 2, ih / 2)
            else
                -- Fallback: gold line circle, used only when the
                -- ComfyUI-generated sprite failed to load.
                love.graphics.setColor(0.85, 0.7, 0.25, 0.55)
                love.graphics.circle("line", cx + ring.x, cy + ring.y, ring.radius)
            end
        elseif ring.inside ~= false then
            if self.galaxyRingImage then
                local iw, ih = self.galaxyRingImage:getDimensions()
                local drawSize = ring.radius * 2
                local scale = drawSize / math.max(iw, ih)
                love.graphics.setColor(1, 1, 1, 0.55)
                love.graphics.draw(
                    self.galaxyRingImage,
                    cx + ring.x, cy + ring.y, 0, scale, scale, iw / 2, ih / 2)
            else
                -- Fallback: cyan/gold line circle, used only when the
                -- ComfyUI-generated sprite failed to load.
                if ring.id == "milkyway" then
                    love.graphics.setColor(0.3, 0.55, 0.95, 0.55)
                else
                    love.graphics.setColor(0.9, 0.75, 0.3, 0.5)
                end
                love.graphics.circle("line", cx + ring.x, cy + ring.y, ring.radius)
            end
        end
    end
    -- docs/feedback/INBOX.md item 1 part 1: the player's current galaxy
    -- (view.spiralGalaxyId) draws its own deterministic spiral-arm shape as
    -- small dots instead of relying only on the generic disk ring above, so
    -- crossing into a different galaxy visibly changes the minimap's spiral
    -- shape (view.spiral is recomputed per-galaxy by minimap.view()).
    if view.spiral and #view.spiral > 0 then
        for _, point in ipairs(view.spiral) do
            if point.inside ~= false then
                if self.spiralArmImage then
                    local iw, ih = self.spiralArmImage:getDimensions()
                    local drawSize = 2.8
                    local scale = drawSize / math.max(iw, ih)
                    love.graphics.setColor(1, 1, 1, 0.55)
                    love.graphics.draw(
                        self.spiralArmImage,
                        cx + point.x, cy + point.y, 0, scale, scale, iw / 2, ih / 2)
                else
                    -- Fallback: cyan filled circle, used only when the
                    -- ComfyUI-generated sprite failed to load.
                    love.graphics.setColor(0.6, 0.8, 1, 0.55)
                    love.graphics.circle("fill", cx + point.x, cy + point.y, 1.4)
                end
            end
        end
    end
    if view.sun then
        if self.sunMarkerImage then
            local iw, ih = self.sunMarkerImage:getDimensions()
            local drawSize = minimap.markerSunRadius * 2
            local scale = drawSize / math.max(iw, ih)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                self.sunMarkerImage,
                cx + view.sun.x, cy + view.sun.y, 0, scale, scale, iw / 2, ih / 2)
        else
            -- Fallback: gold filled circle, used only when the
            -- ComfyUI-generated sprite failed to load.
            love.graphics.setColor(1, 0.85, 0.25)
            love.graphics.circle("fill", cx + view.sun.x, cy + view.sun.y, minimap.markerSunRadius)
        end
    end
    for _, galaxy in ipairs(view.galaxies) do
        if galaxy.inside then
            if galaxy.id == "milkyway" then
                if self.galaxyHomeMarkerImage then
                    local iw, ih = self.galaxyHomeMarkerImage:getDimensions()
                    local drawSize = minimap.markerGalaxyHomeRadius * 2
                    local scale = drawSize / math.max(iw, ih)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        self.galaxyHomeMarkerImage,
                        cx + galaxy.x, cy + galaxy.y, 0, scale, scale, iw / 2, ih / 2)
                else
                    -- Fallback: blue filled circle, used only when the
                    -- ComfyUI-generated sprite failed to load.
                    love.graphics.setColor(0.25, 0.55, 1)
                    love.graphics.circle("fill", cx + galaxy.x, cy + galaxy.y, minimap.markerGalaxyHomeRadius)
                end
            elseif galaxy.hub then
                -- Checkpoint galaxy (docs/feedback/INBOX.md item 1 part 2):
                -- a small, sharply distinct 5-point star glyph instead of
                -- the old plain dot + large pulsing ring (which read as
                -- "too big" relative to the rest of the chart at
                -- markerGalaxyHubRingRadius=16, 20% of the whole
                -- mapRadius). The glyph itself still pulses subtly via
                -- self.time so it keeps a "special waypoint" beacon feel.
                local pulse = 0.75 + 0.25 * math.abs(math.sin((self.time or 0) * 2.4))
                if self.checkpointStarImage then
                    local iw, ih = self.checkpointStarImage:getDimensions()
                    local drawSize = minimap.markerGalaxyHubRadius * 2
                    local scale = drawSize / math.max(iw, ih)
                    love.graphics.setColor(1, 1, 1, pulse)
                    love.graphics.draw(
                        self.checkpointStarImage,
                        cx + galaxy.x, cy + galaxy.y, 0, scale, scale, iw / 2, ih / 2)
                else
                    love.graphics.setColor(1, 0.85, 0.35, pulse)
                    love.graphics.polygon("fill", minimap.starPoints(
                        cx + galaxy.x, cy + galaxy.y, minimap.markerGalaxyHubRadius))
                end

            else
                if self.galaxyPlainMarkerImage then
                    local iw, ih = self.galaxyPlainMarkerImage:getDimensions()
                    local drawSize = minimap.markerGalaxyPlainRadius * 2
                    local scale = drawSize / math.max(iw, ih)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(
                        self.galaxyPlainMarkerImage,
                        cx + galaxy.x, cy + galaxy.y, 0, scale, scale, iw / 2, ih / 2)
                else
                    -- Fallback: gold filled circle, used only when the
                    -- ComfyUI-generated sprite failed to load.
                    love.graphics.setColor(0.9, 0.75, 0.3)
                    love.graphics.circle("fill", cx + galaxy.x, cy + galaxy.y, minimap.markerGalaxyPlainRadius)
                end
            end
        end
    end
    if self.earthMarkerImage then
        local iw, ih = self.earthMarkerImage:getDimensions()
        local drawSize = minimap.markerEarthRadius * 2
        local scale = drawSize / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            self.earthMarkerImage,
            cx + view.earth.x, cy + view.earth.y, 0, scale, scale, iw / 2, ih / 2)
    else
        -- Fallback: cyan filled circle, used only when the
        -- ComfyUI-generated sprite failed to load.
        love.graphics.setColor(0.3, 0.85, 1)
        love.graphics.circle("fill", cx + view.earth.x, cy + view.earth.y, minimap.markerEarthRadius)
    end
    if self.playerMarkerImage then
        local iw, ih = self.playerMarkerImage:getDimensions()
        local drawSize = minimap.markerPlayerLineRadius * 2
        local scale = drawSize / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            self.playerMarkerImage,
            cx + view.player.x, cy + view.player.y, 0, scale, scale, iw / 2, ih / 2)
    else
        -- Fallback: white filled circle + outline, used only when the
        -- ComfyUI-generated sprite failed to load.
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", cx + view.player.x, cy + view.player.y, minimap.markerPlayerFillRadius)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("line", cx + view.player.x, cy + view.player.y, minimap.markerPlayerLineRadius)
    end
    if view.beyond then
        local rim = size / 2 - 5
        local tipX = cx + view.returnDx * rim
        local tipY = cy + view.returnDy * rim
        if self.earthReturnMarkerImage then
            local iw, ih = self.earthReturnMarkerImage:getDimensions()
            local drawSize = minimap.markerBeyondRadius * 2
            local scale = drawSize / math.max(iw, ih)
            local rotation = math.atan2(view.returnDx, -view.returnDy)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                self.earthReturnMarkerImage,
                tipX, tipY, rotation, scale, scale, iw / 2, ih / 2)
        else
            -- Fallback: orange filled circle, used only when the
            -- ComfyUI-generated sprite failed to load.
            love.graphics.setColor(1, 0.55, 0.3)
            love.graphics.circle("fill", tipX, tipY, minimap.markerBeyondRadius)
        end
        local label = i18n.t("minimap_out", math.floor(view.distanceBeyond + 0.5))
        love.graphics.setColor(1, 0.55, 0.3)
        love.graphics.printf(label, viewport.width - size - 6, cy + size / 2 + 1, size + 4, "right")
    end
    -- docs/feedback/INBOX.md UI 대개편 6건 item 4: always show the ship's
    -- actual world coordinates as a small readout next to the minimap
    -- (replacing the removed, unclear C%/P%/S%/EV$ slot-odds text). Shown
    -- in every phase the minimap itself is drawn in (settlement/destroyed
    -- already early-return above).
    self.smallFont = self.smallFont or fonts.get(M.smallFontSize)
    local previousCoordsFont = love.graphics.getFont()
    love.graphics.setFont(self.smallFont)
    love.graphics.setColor(0.6, 0.8, 1)
    love.graphics.printf(M.shipCoordsLine(self.ship.x, self.ship.y),
        16, hudHeight - 36, viewport.width - 32, "right")
    love.graphics.setFont(previousCoordsFont)
    if view.checkpointBeyond then
        -- Nearest off-chart checkpoint galaxy arrow (item 1). Distinct
        -- magenta from the orange Earth-return marker above, and offset
        -- slightly inward on the rim so the two never overlap when both
        -- are showing at once. ComfyUI sprite replaces the Lua
        -- circle+triangle; rotation points the up-facing arrow toward
        -- the checkpoint (sprite default is up / -y).
        local rim = size / 2 - 9
        local tipX = cx + view.checkpointDx * rim
        local tipY = cy + view.checkpointDy * rim
        if self.checkpointArrowImage then
            local iw, ih = self.checkpointArrowImage:getDimensions()
            local drawSize = minimap.markerCheckpointTipRadius * 2
            local scale = drawSize / math.max(iw, ih)
            local rotation = math.atan2(view.checkpointDx, -view.checkpointDy)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(
                self.checkpointArrowImage,
                tipX, tipY, rotation, scale, scale, iw / 2, ih / 2)
        else
            love.graphics.setColor(0.85, 0.35, 0.95)
            love.graphics.circle("fill", tipX, tipY, minimap.markerCheckpointTipRadius)
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
    -- docs/feedback/INBOX.md 처리대기 항목 "ComfyUI로 실제 에셋 작업 진행"
    -- (background slice): tile the ComfyUI-generated deep-space nebula
    -- backdrop (assets/backgrounds/deep_space_tile.png) across the whole
    -- viewport at a slow parallax rate (same 0.4x camera factor as the
    -- backgroundStars() point layer immediately below) so it reads as a
    -- distant, mostly-static nebula behind the star fields. Falls back to
    -- the flat galaxy-tint clear color above when the image failed to
    -- load.
    if self.backgroundImage then
        local bgCameraX, bgCameraY = cameraX * 0.4, cameraY * 0.4
        local imgW, imgH = self.backgroundImage:getDimensions()
        local offsetX = bgCameraX % imgW
        local offsetY = bgCameraY % imgH
        love.graphics.setColor(1, 1, 1, 0.55)
        local quad = love.graphics.newQuad(
            offsetX, offsetY,
            viewport.width + imgW, viewport.height + imgH,
            imgW, imgH)
        love.graphics.draw(self.backgroundImage, quad, -offsetX, -offsetY)
        love.graphics.setColor(1, 1, 1, 1)
    end
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
                    local c = 0.12 + star.bright * 0.4
                    love.graphics.setColor(c, c, math.min(1, c + 0.08))
                    if self.starPointImage then
                        local iw, ih = self.starPointImage:getDimensions()
                        local scale = 2.0 / math.max(iw, ih)
                        love.graphics.draw(
                            self.starPointImage, x, y, 0, scale, scale, iw / 2, ih / 2)
                    else
                        love.graphics.points(x, y)
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
                    local c = 0.35 + star.bright * 0.65
                    love.graphics.setColor(c, c, math.min(1, c + 0.1))
                    if self.starPointImage then
                        local iw, ih = self.starPointImage:getDimensions()
                        local scale = 3.2 / math.max(iw, ih)
                        love.graphics.draw(
                            self.starPointImage, x, y, 0, scale, scale, iw / 2, ih / 2)
                    else
                        love.graphics.points(x, y)
                    end
                end
            end
        end
    end
    local earthX, earthY = math.floor(-cameraX), math.floor(M.earthCenterY - cameraY)
    if earthY < viewport.height + M.earthRadius + 24 then
        if self.earthImage then
            local imgW, imgH = self.earthImage:getDimensions()
            local scale = (M.earthRadius * 2) / math.max(imgW, imgH)
            love.graphics.setColor(1, 1, 1)
            love.graphics.draw(self.earthImage, earthX, earthY, 0, scale, scale, imgW / 2, imgH / 2)
        else
            -- Fallback: flat ocean-circle + two green "continent" blobs,
            -- used only when the ComfyUI-generated sprite failed to load.
            love.graphics.setColor(0.15, 0.45, 0.9)
            love.graphics.circle("fill", earthX, earthY, M.earthRadius)
            love.graphics.setColor(0.25, 0.8, 0.45)
            love.graphics.circle("fill", earthX - 72, earthY - 72, 60)
            love.graphics.circle("fill", earthX + 84, earthY - 20, 48)
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
                if self.planetGlowImage then
                    local iw, ih = self.planetGlowImage:getDimensions()
                    local glowRadius = planet.radius + 3 + effect.glowRings * 4
                    local scale = (glowRadius * 2) / math.max(iw, ih)
                    love.graphics.setColor(glowR, glowG, glowB, effect.glowAlpha)
                    love.graphics.draw(self.planetGlowImage, x, y, 0, scale, scale, iw / 2, ih / 2)
                else
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
            -- ComfyUI sprite when loaded; Lua circle is load-failure fallback.
            local shadowX = x + planet.radius * 0.22
            local shadowY = y + planet.radius * 0.22
            local shadowRadius = planet.radius * 1.02
            love.graphics.setColor(0, 0, 0, 0.25)
            if self.planetShadowImage then
                local iw, ih = self.planetShadowImage:getDimensions()
                local scale = (shadowRadius * 2) / math.max(iw, ih)
                love.graphics.draw(self.planetShadowImage, shadowX, shadowY, 0, scale, scale, iw / 2, ih / 2)
            else
                love.graphics.circle("fill", shadowX, shadowY, shadowRadius)
            end
            -- docs/feedback/INBOX.md 처리대기 항목 "ComfyUI로 실제 에셋 작업
            -- 진행" (planet slice): render the ComfyUI-generated neutral-tone
            -- sprite (assets/planet/planet_generic.png) tinted by the
            -- existing planetColor(hue) lookup instead of a flat filled
            -- circle, so per-planet hue variety is preserved. Hub/checkpoint
            -- planets use planet_hub.png so they read as a distinct landmark.
            -- Shop/market planets use planet_shop.png so they read as a
            -- distinct landmark from both hub and generic worlds.
            -- Falls back to planetImage, then the previous flat
            -- gradient-circle rendering whenever the image failed to load
            -- (e.g. missing file/graphics disabled).
            local baseR, baseG, baseB = planetColor(planet.hue)
            local planetSprite = self.planetImage
            if planet.hub and self.hubPlanetImage then
                planetSprite = self.hubPlanetImage
            elseif planet.shop and self.shopPlanetImage then
                planetSprite = self.shopPlanetImage
            end
            if planetSprite then
                local iw, ih = planetSprite:getWidth(), planetSprite:getHeight()
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
                local tierR, tierG, tierB = sampleTierColor(world.sampleTier(planet))
                love.graphics.setColor(tierR, tierG, tierB)
                if self.planetRimImage then
                    local iw, ih = self.planetRimImage:getDimensions()
                    local rimRadius = planet.radius + 3
                    local scale = (rimRadius * 2) / math.max(iw, ih)
                    love.graphics.draw(self.planetRimImage, x, y, 0, scale, scale, iw / 2, ih / 2)
                else
                    love.graphics.circle("line", x, y, planet.radius + 3)
                end
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
                    if self.planetTwinkleImage then
                        local iw, ih = self.planetTwinkleImage:getDimensions()
                        local scale = 4 / math.max(iw, ih)
                        love.graphics.draw(self.planetTwinkleImage, px, py, 0, scale, scale, iw / 2, ih / 2)
                    else
                        love.graphics.circle("fill", px, py, 1.2)
                    end
                end
            end
            love.graphics.setColor(0.9, 0.95, 1, 0.45)
            if self.planetRimImage then
                local iw, ih = self.planetRimImage:getDimensions()
                local rimRadius = planet.radius + 2
                local scale = (rimRadius * 2) / math.max(iw, ih)
                love.graphics.draw(self.planetRimImage, x, y, 0, scale, scale, iw / 2, ih / 2)
            else
                love.graphics.circle("line", x, y, planet.radius + 2)
            end
            local risk = self:approachWarning(planet, y, shipScreenY)
            if risk then
                local font = love.graphics.getFont()
                local previewY
                if risk.sampleLabel then
                    previewY = math.max(48, y - planet.radius - 24)
                    local sampleTextWidth = font:getWidth(risk.sampleLabel)
                    local sampleIconSpan = M.sampleValueIconSize + M.sampleValueIconGap
                    local sampleLabelX = clampLabelX(x, sampleIconSpan + sampleTextWidth, viewport.width)
                    local sampleIconCenterX = sampleLabelX + M.sampleValueIconSize / 2
                    local sampleIconCenterY = previewY + font:getHeight() / 2
                    if self.sampleValueIconImage then
                        local iw, ih = self.sampleValueIconImage:getDimensions()
                        local scale = M.sampleValueIconSize / math.max(iw, ih)
                        love.graphics.setColor(1, 1, 1, 1)
                        love.graphics.draw(self.sampleValueIconImage, sampleIconCenterX, sampleIconCenterY, 0, scale, scale, iw / 2, ih / 2)
                    else
                        -- Fallback: cyan hexagonal crystal, used only when
                        -- the ComfyUI-generated sprite failed to load.
                        love.graphics.setColor(0.45, 0.95, 1)
                        love.graphics.polygon("fill",
                            M.sampleValueIconPoints(sampleIconCenterX, sampleIconCenterY, M.sampleValueIconSize))
                    end
                    love.graphics.setColor(0.45, 0.95, 1)
                    love.graphics.print(risk.sampleLabel, sampleLabelX + sampleIconSpan, previewY)
                    previewY = previewY + 11
                else
                    previewY = math.max(72, y - planet.radius - 12)
                end
                local riskTextWidth = font:getWidth(risk.label)
                local riskIconSpan = M.riskIconSize + M.riskIconGap
                local riskLabelX = clampLabelX(x, riskIconSpan + riskTextWidth, viewport.width)
                local riskIconCenterX = riskLabelX + M.riskIconSize / 2
                local riskIconCenterY = previewY + font:getHeight() / 2
                if self.riskIconImage then
                    local iw, ih = self.riskIconImage:getDimensions()
                    local scale = M.riskIconSize / math.max(iw, ih)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.draw(self.riskIconImage, riskIconCenterX, riskIconCenterY, 0, scale, scale, iw / 2, ih / 2)
                else
                    -- Fallback: warning triangle, used only when the
                    -- ComfyUI-generated sprite failed to load. Tinted
                    -- red for lethal, amber for normal risk.
                    if risk.lethal then
                        love.graphics.setColor(1, 0.3, 0.25)
                    else
                        love.graphics.setColor(1, 0.8, 0.25)
                    end
                    love.graphics.polygon("fill",
                        M.riskIconPoints(riskIconCenterX, riskIconCenterY, M.riskIconSize))
                end
                if risk.lethal then
                    love.graphics.setColor(1, 0.3, 0.25)
                else
                    love.graphics.setColor(1, 0.8, 0.25)
                end
                love.graphics.print(risk.label, riskLabelX + riskIconSpan, previewY)
            end
        end
    end
    for _, junk in ipairs(world.nearbyDebris(self.ship.x, self.ship.y, 1, self.time)) do
        local x, y = math.floor(junk.x - cameraX), math.floor(junk.y - cameraY)
        if x > -20 and x < viewport.width + 20 and y > -20 and y < viewport.height + 20 then
            local sprite = self.debrisImages and self.debrisImages[junk.kind]
            if sprite then
                local iw, ih = sprite:getWidth(), sprite:getHeight()
                local scale = (junk.radius * 2) / math.max(iw, ih)
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(sprite, x, y, 0, scale, scale, iw / 2, ih / 2)
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
            local textY = fy - M.floatingTextBoxTopOffset
            if ft.kind == "sample" then
                local font = love.graphics.getFont()
                local textWidth = font:getWidth(ft.text)
                local iconSpan = M.floatingSampleIconSize + M.floatingSampleIconGap
                local startX = fx - (iconSpan + textWidth) / 2
                local iconCenterX = startX + M.floatingSampleIconSize / 2
                local iconCenterY = textY + font:getHeight() / 2
                if self.floatingSampleIconImage then
                    local iw, ih = self.floatingSampleIconImage:getDimensions()
                    local scale = M.floatingSampleIconSize / math.max(iw, ih)
                    love.graphics.setColor(1, 1, 1, alpha)
                    love.graphics.draw(self.floatingSampleIconImage, iconCenterX, iconCenterY, 0, scale, scale, iw / 2, ih / 2)
                else
                    -- Fallback: cyan plus-badge, used only when the
                    -- ComfyUI-generated sprite failed to load.
                    love.graphics.setColor(0.45, 1, 0.6, alpha)
                    love.graphics.polygon("fill",
                        M.floatingSampleIconPoints(iconCenterX, iconCenterY, M.floatingSampleIconSize))
                end
                love.graphics.setColor(0.45, 1, 0.6, alpha)
                love.graphics.print(ft.text, startX + iconSpan, textY)
            elseif ft.kind == "damage" then
                local font = love.graphics.getFont()
                local textWidth = font:getWidth(ft.text)
                local iconSpan = M.floatingDamageIconSize + M.floatingDamageIconGap
                local startX = fx - (iconSpan + textWidth) / 2
                local iconCenterX = startX + M.floatingDamageIconSize / 2
                local iconCenterY = textY + font:getHeight() / 2
                if self.floatingDamageIconImage then
                    local iw, ih = self.floatingDamageIconImage:getDimensions()
                    local scale = M.floatingDamageIconSize / math.max(iw, ih)
                    love.graphics.setColor(1, 1, 1, alpha)
                    love.graphics.draw(self.floatingDamageIconImage, iconCenterX, iconCenterY, 0, scale, scale, iw / 2, ih / 2)
                else
                    -- Fallback: red minus-badge, used only when the
                    -- ComfyUI-generated sprite failed to load.
                    love.graphics.setColor(1, 0.35, 0.3, alpha)
                    love.graphics.polygon("fill",
                        M.floatingDamageIconPoints(iconCenterX, iconCenterY, M.floatingDamageIconSize))
                end
                love.graphics.setColor(1, 0.35, 0.3, alpha)
                love.graphics.print(ft.text, startX + iconSpan, textY)
            else
                love.graphics.setColor(0.45, 1, 0.6, alpha)
                love.graphics.printf(ft.text, fx - M.floatingTextBoxHalfWidth,
                    textY, M.floatingTextBoxHalfWidth * 2, "center")
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
        -- ComfyUI-generated 64x64 sprite (docs/GENERATED_ASSET_LOG.md);
        -- drawn at a 64px logical footprint (old 16px x4) so it stays the
        -- same relative size on the 720x1280 canvas and is no longer
        -- downscaled from the 64x64 original. SCOUT uses ship_scout.png
        -- so the purchased hull is visually distinct from STARTER.
        local targetSize = 64
        local scale = targetSize / math.max(iw, ih)
        love.graphics.draw(hullImage, 0, 0, 0, scale, scale, iw / 2, ih / 2)
    elseif self.shipSilhouetteImage then
        local iw, ih = self.shipSilhouetteImage:getWidth(), self.shipSilhouetteImage:getHeight()
        local targetSize = 64
        local scale = targetSize / math.max(iw, ih)
        love.graphics.draw(self.shipSilhouetteImage, 0, 0, 0, scale, scale, iw / 2, ih / 2)
    else
        love.graphics.polygon("fill", 0, -28, -20, 24, 0, 12, 20, 24)
    end
    if self.expedition.phase == "ascending" then
        love.graphics.setColor(1, 0.55, 0.15)
        if self.thrustEffectImage then
            local iw, ih = self.thrustEffectImage:getDimensions()
            local scale = 28 / math.max(iw, ih)
            love.graphics.draw(self.thrustEffectImage, 0, 32, 0, scale, scale, iw / 2, ih / 2)
        else
            love.graphics.polygon("fill", -8, 20, 0, 44, 8, 20)
        end
    end
    love.graphics.pop()

    local hud = self:hudLines()
    local isLaunchHud = self.expedition.phase == "launch"
    local galaxyShift = hud.galaxy and 40 or 0
    local hudHeight = M.hudHeight(self.expedition.phase, hud, galaxyShift)
    if self.hudPanelImage then
        local iw, ih = self.hudPanelImage:getDimensions()
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.draw(self.hudPanelImage, 0, 0, 0, viewport.width / iw, hudHeight / ih)
    else
        love.graphics.setColor(0.02, 0.03, 0.08, 0.85)
        love.graphics.rectangle("fill", 0, 0, viewport.width, hudHeight)
    end
    local previousHudFont
    if isLaunchHud then
        self.smallFont = self.smallFont or fonts.get(M.smallFontSize)
        previousHudFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
    end
    love.graphics.setColor(0.7, 0.9, 1)
    local hudY = 16
    if hud.galaxy then
        local galaxyIconCenterX = 20 + M.galaxyIconSize / 2
        local galaxyIconCenterY = hudY + (love.graphics.getFont():getHeight() / 2)
        if self.galaxyIconImage then
            local iw, ih = self.galaxyIconImage:getDimensions()
            local scale = M.galaxyIconSize / math.max(iw, ih)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.galaxyIconImage, galaxyIconCenterX, galaxyIconCenterY, 0, scale, scale, iw / 2, ih / 2)
        else
            -- Fallback: gold 8-point star, used only when the
            -- ComfyUI-generated sprite failed to load.
            love.graphics.setColor(1, 0.85, 0.4)
            love.graphics.polygon("fill",
                M.galaxyIconPoints(galaxyIconCenterX, galaxyIconCenterY, M.galaxyIconSize))
        end
        love.graphics.setColor(1, 0.85, 0.4)
        love.graphics.print(hud.galaxy, 20 + M.galaxyIconSize + M.galaxyIconGap, hudY)
        hudY = hudY + 40
        love.graphics.setColor(0.7, 0.9, 1)
    end
    local distIconCenterX = 20 + M.distanceIconSize / 2
    local distIconCenterY = hudY + (love.graphics.getFont():getHeight() / 2)
    if self.distanceIconImage then
        local iw, ih = self.distanceIconImage:getDimensions()
        local scale = M.distanceIconSize / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.distanceIconImage, distIconCenterX, distIconCenterY, 0, scale, scale, iw / 2, ih / 2)
    else
        -- Fallback: cyan nav diamond, used only when the ComfyUI-generated
        -- sprite failed to load.
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.polygon("fill",
            M.distanceIconPoints(distIconCenterX, distIconCenterY, M.distanceIconSize))
    end
    local distTextX = 20 + M.distanceIconSize + M.distanceIconGap
    love.graphics.setColor(0.7, 0.9, 1)
    love.graphics.print(hud.distance, distTextX, hudY)
    -- docs/feedback/INBOX.md 국제화 누락 + 발라트로식 점수 연출 + HUD 약자 정리 항목 (2):
    -- draw a punch-scaled, color-emphasized overlay of the DIST text
    -- whenever a new all-time best altitude was just set (self.distancePunch
    -- counts down from distancePunchDuration). Re-print on top of the plain
    -- print above (same origin) rather than replacing it, so layout/width
    -- measurement below stays anchored to the unscaled baseline text.
    if self.distancePunch > 0 then
        local scale = distancePunchScale(self.distancePunch, distancePunchDuration)
        local fadeProgress = self.distancePunch / distancePunchDuration
        love.graphics.push()
        love.graphics.translate(distTextX, hudY)
        love.graphics.scale(scale, scale)
        love.graphics.setColor(1, 0.85, 0.25, fadeProgress)
        love.graphics.print(hud.distance, 0, 0)
        love.graphics.pop()
        love.graphics.setColor(0.7, 0.9, 1)
    end
    -- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
    -- third slice): pair the CASH readout with a small coin icon, mirroring
    -- the shield icon paired with the hull status line below. The coin sits
    -- right after the DIST text (measured via the currently active HUD
    -- font, so this works for both the 14px default and the launch phase's
    -- 8px small font) with the CASH text shifted right of the coin's
    -- footprint so nothing overlaps.
    local distanceWidth = love.graphics.getFont():getWidth(hud.distance)
    local cashIconCenterX = distTextX + distanceWidth + 32 + M.cashIconSize / 2
    local cashIconCenterY = hudY + (love.graphics.getFont():getHeight() / 2)
    if self.cashIconImage then
        local iw, ih = self.cashIconImage:getDimensions()
        local scale = M.cashIconSize / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.cashIconImage, cashIconCenterX, cashIconCenterY, 0, scale, scale, iw / 2, ih / 2)
    else
        -- Fallback: gold octagon, used only when the ComfyUI-generated
        -- sprite failed to load.
        love.graphics.setColor(1, 0.85, 0.3)
        love.graphics.polygon("fill",
            M.coinIconPoints(cashIconCenterX, cashIconCenterY, M.cashIconSize))
    end
    love.graphics.setColor(0.7, 0.9, 1)
    love.graphics.print(hud.cash,
        distTextX + distanceWidth + 32 + M.cashIconSize + M.cashIconGap, hudY)
    -- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD simplification,
    -- second slice): pair the hull-durability status text with a small
    -- shield icon drawn just to its left, then shift the text right by
    -- the icon's footprint so it never overlaps the shield.
    local function drawStatusWithShield(y)
        local iconCenterX = 20 + M.hullIconSize / 2
        local iconCenterY = y + M.hullIconSize / 2
        if self.hullIconImage then
            local iw, ih = self.hullIconImage:getDimensions()
            local scale = M.hullIconSize / math.max(iw, ih)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.hullIconImage, iconCenterX, iconCenterY, 0, scale, scale, iw / 2, ih / 2)
        else
            -- Fallback: cyan shield pentagon, used only when the
            -- ComfyUI-generated sprite failed to load.
            love.graphics.setColor(0.6, 0.85, 1)
            love.graphics.polygon("fill",
                M.shieldIconPoints(iconCenterX, iconCenterY, M.hullIconSize))
        end
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.print(hud.status, 20 + M.hullIconSize + M.hullIconGap, y)
    end
    if hud.samples then
        -- Extra vertical gap (M.hudPrimaryStatusGap) below the samples line
        -- pushes the fuel/hull/slot status line away from the DIST/CASH
        -- line so the two rows read as visually unrelated numbers rather
        -- than "fuel gauge gates distance" (docs/feedback/INBOX.md item 2).
        -- Pair the SAMPLES readout with a small vial icon, mirroring the
        -- PERSONAL BEST trophy / DIST diamond pattern.
        local samplesY = 64 + galaxyShift
        local samplesIconCenterX = 20 + M.samplesIconSize / 2
        local samplesIconCenterY = samplesY + (love.graphics.getFont():getHeight() / 2)
        if self.samplesIconImage then
            local iw, ih = self.samplesIconImage:getDimensions()
            local scale = M.samplesIconSize / math.max(iw, ih)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.samplesIconImage, samplesIconCenterX, samplesIconCenterY, 0, scale, scale, iw / 2, ih / 2)
        else
            -- Fallback: amber specimen vial, used only when the
            -- ComfyUI-generated sprite failed to load.
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.polygon("fill",
                M.samplesIconPoints(samplesIconCenterX, samplesIconCenterY, M.samplesIconSize))
        end
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.print(hud.samples, 20 + M.samplesIconSize + M.samplesIconGap, samplesY)
        drawStatusWithShield(120 + M.hudPrimaryStatusGap + galaxyShift)
        if hud.earth then
            local earthY = 172 + M.hudPrimaryStatusGap + galaxyShift
            local earthIconCenterX = 20 + M.earthIconSize / 2
            local earthIconCenterY = earthY + (love.graphics.getFont():getHeight() / 2)
            if self.earthIconImage then
                local iw, ih = self.earthIconImage:getDimensions()
                local scale = M.earthIconSize / math.max(iw, ih)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(self.earthIconImage, earthIconCenterX, earthIconCenterY, 0, scale, scale, iw / 2, ih / 2)
            else
                -- Fallback: cyan globe octagon, used only when the
                -- ComfyUI-generated sprite failed to load.
                love.graphics.setColor(0.4, 0.85, 1)
                love.graphics.polygon("fill",
                    M.earthIconPoints(earthIconCenterX, earthIconCenterY, M.earthIconSize))
            end
            love.graphics.setColor(0.4, 0.85, 1)
            love.graphics.print(hud.earth, 20 + M.earthIconSize + M.earthIconGap, earthY)
            local returnY = 220 + M.hudPrimaryStatusGap + galaxyShift
            local returnIconCenterX = 20 + M.returnIconSize / 2
            local returnIconCenterY = returnY + (love.graphics.getFont():getHeight() / 2)
            if self.returnIconImage then
                local iw, ih = self.returnIconImage:getDimensions()
                local scale = M.returnIconSize / math.max(iw, ih)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(self.returnIconImage, returnIconCenterX, returnIconCenterY, 0, scale, scale, iw / 2, ih / 2)
            else
                -- Fallback: cyan downward chevron, used only when the
                -- ComfyUI-generated sprite failed to load.
                love.graphics.setColor(0.4, 0.85, 1)
                love.graphics.polygon("fill",
                    M.returnIconPoints(returnIconCenterX, returnIconCenterY, M.returnIconSize))
            end
            love.graphics.setColor(0.4, 0.85, 1)
            love.graphics.print(hud.returnProgress, 20 + M.returnIconSize + M.returnIconGap, returnY)
        end
    elseif hud.best then
        drawStatusWithShield((isLaunchHud and 52 or 72) + galaxyShift)
        local bestY = (isLaunchHud and 88 or 120) + galaxyShift
        local bestIconCenterX = 20 + M.bestIconSize / 2
        local bestIconCenterY = bestY + (love.graphics.getFont():getHeight() / 2)
        if self.bestIconImage then
            local iw, ih = self.bestIconImage:getDimensions()
            local scale = M.bestIconSize / math.max(iw, ih)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.bestIconImage, bestIconCenterX, bestIconCenterY, 0, scale, scale, iw / 2, ih / 2)
        else
            -- Fallback: gold trophy cup, used only when the ComfyUI-generated
            -- sprite failed to load.
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.polygon("fill",
                M.bestIconPoints(bestIconCenterX, bestIconCenterY, M.bestIconSize))
        end
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.print(hud.best, 20 + M.bestIconSize + M.bestIconGap, bestY)
    else
        drawStatusWithShield(72 + galaxyShift)
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
        if M.showSpecimenStrip then
            self:drawSpecimenStrip(736)
        end
        local loadout = self:loadoutLines()
        local loadoutBoxX = 48
        local loadoutBoxY = M.launchLoadoutBoxTop
        local loadoutBoxW = viewport.width - 96
        local loadoutBoxH = viewport.height - M.launchLoadoutBoxTop
        if self.loadoutPanelImage then
            local iw, ih = self.loadoutPanelImage:getDimensions()
            love.graphics.setColor(1, 1, 1, 0.92)
            love.graphics.draw(self.loadoutPanelImage, loadoutBoxX, loadoutBoxY, 0,
                loadoutBoxW / iw, loadoutBoxH / ih)
        else
            love.graphics.setColor(0.02, 0.03, 0.08, 0.92)
            love.graphics.rectangle("fill", loadoutBoxX, loadoutBoxY, loadoutBoxW, loadoutBoxH)
        end
        -- Every LOADOUT line now uses the small 8px scene-cached font
        -- (previously the default 14px font) so the text sizes relative
        -- to the small circular minimap chart/specimen-strip squares
        -- above it, with a tightened row step so six lines fit in the
        -- freed vertical space without overlapping each other or the
        -- TAP TO LAUNCH message drawn separately below.
        self.smallFont = self.smallFont or fonts.get(M.smallFontSize)
        local previousLaunchFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        local row = M.launchLoadoutBoxTop + 16
        local rowStep = M.launchLoadoutRowStep
        if loadout.ship then
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.printf(loadout.ship, 64, row, viewport.width - 128, "center")
            row = row + rowStep
        end
        love.graphics.setColor(0.4, 0.85, 1)
        love.graphics.printf(loadout.stats, 64, row, viewport.width - 128, "center")
        row = row + rowStep

        love.graphics.setColor(0.6, 1, 0.85)
        -- docs/feedback/INBOX.md UI/HUD item 3 (icon-based HUD
        -- simplification, fourth/final slice): pair the STEER SPEED text
        -- with a small speedometer icon drawn just to its left, mirroring
        -- the pattern used for the coin/shield icons elsewhere. The text
        -- is centered via printf, so the icon is measured against the
        -- text's rendered width and placed immediately left of it.
        local steeringTextWidth = love.graphics.getFont():getWidth(loadout.steering)
        local steeringTextX = 64 + (viewport.width - 128 - steeringTextWidth) / 2
        local speedIconCenterX = steeringTextX - M.speedIconGap - M.speedIconSize / 2
        local speedIconCenterY = row + love.graphics.getFont():getHeight() / 2
        if self.speedIconImage then
            local iw, ih = self.speedIconImage:getDimensions()
            local scale = M.speedIconSize / math.max(iw, ih)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(self.speedIconImage, speedIconCenterX, speedIconCenterY, 0, scale, scale, iw / 2, ih / 2)
        else
            -- Fallback: mint speedometer polygon, used only when the
            -- ComfyUI-generated sprite failed to load.
            love.graphics.polygon("fill",
                M.speedIconPoints(speedIconCenterX, speedIconCenterY, M.speedIconSize))
        end
        love.graphics.setColor(0.6, 1, 0.85)
        love.graphics.printf(loadout.steering, 64, row, viewport.width - 128, "center")
        love.graphics.setFont(previousLaunchFont)
    elseif self.expedition.phase == "settlement" then
        -- The summary card is drawn with the same scene-cached small font as
        -- the shop rows (instead of the default 14px font) and tightened to
        -- a 9px line step. This frees enough vertical room above the fixed
        -- 320px canvas bottom for PlayScene.settlementTouchRows to grow each
        -- row to the 44pt real-device accessibility minimum (see
        -- game/self_test.lua) at the smallest supported window (integer
        -- scale 1), not just the previous 34px minimum.
        self.smallFont = self.smallFont or fonts.get(M.smallFontSize)
        local previousFont = love.graphics.getFont()
        if self.shopPanelImage then
            local iw, ih = self.shopPanelImage:getDimensions()
            love.graphics.setColor(1, 1, 1, 0.94)
            love.graphics.draw(self.shopPanelImage, 48, 280, 0,
                (viewport.width - 96) / iw, 1000 / ih)
        else
            love.graphics.setColor(0.02, 0.03, 0.08, 0.94)
            love.graphics.rectangle("fill", 48, 280, viewport.width - 96, 1000)
        end
        -- Faint alternating background bands behind each tappable
        -- settlementTouchRows entry. Drawn before any text so it never
        -- overlaps or obscures the already real-capture-verified printf
        -- calls below; purely a visual affordance for which rows respond
        -- to touch (see settlementRowBackgroundColor comment above).
        for index, touchRow in ipairs(settlementTouchRows) do
            local rowColor = M.settlementRowBackgroundColor(index)
            if self.shopTouchRowImage then
                local iw, ih = self.shopTouchRowImage:getDimensions()
                love.graphics.setColor(1, 1, 1, rowColor[4] or 0.35)
                love.graphics.draw(self.shopTouchRowImage, 48, touchRow.top, 0,
                    (viewport.width - 96) / iw, (touchRow.bottom - touchRow.top) / ih)
            else
                love.graphics.setColor(rowColor)
                love.graphics.rectangle("fill", 48, touchRow.top, viewport.width - 96, touchRow.bottom - touchRow.top)
            end
        end
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.printf(i18n.t("earth_shop_title"), 64, 296, viewport.width - 128, "center")
        -- NEW BEST! is the only extra settlement summary line. Dead
        -- fuel-bonus copy (NEXT LAUNCH FUEL) was removed; econ item 15
        -- owns any later redefinition of bankedFuelBonus.
        local summaryExtraLine
        if self.expedition.lastNewBest then
            summaryExtraLine = i18n.t("newbest_label")
        end
        if self.settlementSummaryPanelImage then
            local iw, ih = self.settlementSummaryPanelImage:getDimensions()
            love.graphics.setColor(1, 1, 1, 0.85)
            love.graphics.draw(self.settlementSummaryPanelImage, 72, 352, 0,
                (viewport.width - 144) / iw, 184 / ih)
        else
            love.graphics.setColor(0.04, 0.08, 0.16, 0.85)
            love.graphics.rectangle("fill", 72, 352, viewport.width - 144, 184)
        end
        love.graphics.setFont(self.smallFont)
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(i18n.t("total_label", self.expedition.lastSettlement), 88, 364, viewport.width - 176, "center")
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(i18n.t("samples_settlement_line", self.expedition.lastSampleCount or 0, self.expedition.lastSampleSettlement), 88, 400, viewport.width - 176, "center")
        love.graphics.printf(i18n.t("spins_settlement_line", self.expedition.lastSlotSpinsCount or 0, self.expedition.lastSlotSettlement), 88, 436, viewport.width - 176, "center")
        love.graphics.setColor(0.6, 0.8, 1)
        love.graphics.printf(i18n.t("peak_dist_line", math.floor(self.expedition.lastAltitude or 0)), 88, 472, viewport.width - 176, "center")
        if summaryExtraLine then
            love.graphics.setColor(1, 0.95, 0.3)
            love.graphics.printf(summaryExtraLine, 88, 508, viewport.width - 176, "center")
        end
        local nextLaunch = self:shopLoadoutLines()
        local fullX, fullW = 64, viewport.width - 128
        -- HULL and STEERING occupy the first remaining shop band after the
        -- fuel-tank purchase row was removed (docs/feedback/INBOX.md item
        -- 11(b)). y=720 is the old y=180 ×4 so compact columns stay inside
        -- the ×4 176px touch band.
        local row = 720
        local rowStep = 32
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.hullActionCompact, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.printf(nextLaunch.steeringActionCompact, shopColumnRightX, row, shopColumnRightW, "center")
        self:drawShopIcon("hull", shopColumnLeftX, row)
        self:drawShopIcon("steering", shopColumnRightX, row)
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


        -- YIELD and SHIP
        row = 864
        rowStep = 32
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.yieldActionCompact, shopColumnLeftX, row, shopColumnLeftW, "center")
        love.graphics.printf(nextLaunch.shipActionCompact, shopColumnRightX, row, shopColumnRightW, "center")
        self:drawShopIcon("yield", shopColumnLeftX, row)
        self:drawShopIcon("ship", shopColumnRightX, row)
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
        for _, tradeoffLine in ipairs(nextLaunch.scoutTradeoff) do
            love.graphics.printf(tradeoffLine, fullX, row, fullW, "center")
            row = row + rowStep
        end

        
        row = 1056
        rowStep = 32
        love.graphics.setColor(1, 0.8, 0.3)
        love.graphics.printf(nextLaunch.ship, fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(nextLaunch.stats, fullX, row, fullW, "center")
        row = row + rowStep

        love.graphics.setColor(0.75, 0.9, 1)
        love.graphics.printf(i18n.t("tap_relaunch"), fullX, row, fullW, "center")
        love.graphics.setFont(previousFont)
    elseif self.expedition.phase == "destroyed" then
        local loadout = self:loadoutLines()
        if self.destroyedPanelImage then
            local iw, ih = self.destroyedPanelImage:getDimensions()
            love.graphics.setColor(1, 1, 1, 0.94)
            love.graphics.draw(self.destroyedPanelImage, 48, 696, 0,
                (viewport.width - 96) / iw, 536 / ih)
        else
            love.graphics.setColor(0.08, 0.02, 0.03, 0.94)
            love.graphics.rectangle("fill", 48, 696, viewport.width - 96, 536)
        end
        self.smallFont = self.smallFont or fonts.get(M.smallFontSize)
        local previousFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        local fullX, fullW = 64, viewport.width - 128
        local row = 712
        local rowStep = 44
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
        love.graphics.printf(i18n.t("peak_dist_line", math.floor(self.expedition.lastLostAltitude or 0)),
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
        love.graphics.printf(i18n.t("next_ship_line", loadout.shipLabel), fullX, row, fullW, "center")
        row = row + rowStep
        love.graphics.printf(i18n.t("tap_start_over"), fullX, row, fullW, "center")
        love.graphics.setFont(previousFont)
    elseif self.expedition.phase == "ascending" then
        self:drawJoystickStick()
    elseif self.expedition.phase == "returning" then
        self.smallFont = self.smallFont or fonts.get(M.smallFontSize)
        local previousOddsFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        -- docs/feedback/INBOX.md UI/HUD item 5: the C%/P%/S%/AVG$ slot-odds
        -- line is now drawn above the minimap chart in drawMinimap() instead
        -- of as a full-width standalone line here.
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
            if self.slotResultPanelImage then
                local iw, ih = self.slotResultPanelImage:getDimensions()
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.draw(self.slotResultPanelImage, 72, 840, 0,
                    576 / iw, 136 / ih)
            else
                love.graphics.setColor(0.02, 0.03, 0.08, 0.9)
                love.graphics.rectangle("fill", 72, 840, 576, 136)
            end
            self:drawSlotReel(self:currentSlotReels(), 80, 864, 560)
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.printf(i18n.t("spinning_label"), 80, 924, 560, "center")
        elseif self.expedition.lastSlotSymbols then
            if self.slotResultPanelImage then
                local iw, ih = self.slotResultPanelImage:getDimensions()
                love.graphics.setColor(1, 1, 1, 0.9)
                love.graphics.draw(self.slotResultPanelImage, 72, 840, 0,
                    576 / iw, 136 / ih)
            else
                love.graphics.setColor(0.02, 0.03, 0.08, 0.9)
                love.graphics.rectangle("fill", 72, 840, 576, 136)
            end
            self:drawSlotReel(self.expedition.lastSlotSymbols, 80, 864, 560)
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.printf(M.slotWinLine(self.expedition), 80, 924, 560, "center")
        end
        love.graphics.setFont(previousOddsFont)
        local slotButton = self:slotButtonState()
        local returnBandHeight = returnControls.bottom - returnControls.top
        local returnLabelY = returnControls.top + math.floor((returnBandHeight - 40) / 2)
        local slotBtnX = returnControls.slotMinX
        local slotBtnW = returnControls.slotMaxX - returnControls.slotMinX
        if self.slotSpinButtonImage then
            local iw, ih = self.slotSpinButtonImage:getDimensions()
            if slotButton.enabled then
                love.graphics.setColor(1, 1, 1, 0.9)
            else
                love.graphics.setColor(0.45, 0.48, 0.55, 0.75)
            end
            love.graphics.draw(self.slotSpinButtonImage, slotBtnX, returnControls.top, 0,
                slotBtnW / iw, returnBandHeight / ih)
        else
            if slotButton.enabled then
                love.graphics.setColor(0.25, 0.55, 0.8, 0.6)
            else
                love.graphics.setColor(0.18, 0.2, 0.25, 0.75)
            end
            love.graphics.rectangle("fill", slotBtnX, returnControls.top, slotBtnW, returnBandHeight)
        end
        self.smallFont = self.smallFont or fonts.get(M.smallFontSize)
        local previousReturnButtonFont = love.graphics.getFont()
        love.graphics.setFont(self.smallFont)
        if slotButton.enabled then
            love.graphics.setColor(0.85, 0.95, 1)
        else
            love.graphics.setColor(0.55, 0.58, 0.65)
        end
        love.graphics.printf(slotButton.compactLabel, returnControls.slotMinX, returnLabelY, returnControls.slotMaxX - returnControls.slotMinX, "center")
        love.graphics.setFont(previousReturnButtonFont)
        self:drawJoystickStick()
    end
    love.graphics.setColor(0.85, 0.9, 1)
    local messageY = (self.expedition.phase == "settlement" or self.expedition.phase == "destroyed") and 200 or viewport.height - 120
    if self.expedition.phase == "launch" then
        -- docs/feedback/INBOX.md "UI 대개편 6건" item 5: drop the crude
        -- yellow rocket/arrow, then draw a smaller dark translucent-gray
        -- prompt with a restrained sine wobble + fade pulse.
        if M.showLaunchRocketIcon then
            local rocketX = viewport.width / 2
            local rocketY = messageY - M.launchIconGap
            if self.launchRocketImage then
                local iw, ih = self.launchRocketImage:getDimensions()
                local scale = M.launchIconSize / math.max(iw, ih)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(self.launchRocketImage, rocketX, rocketY, 0, scale, scale, iw / 2, ih / 2)
            else
                love.graphics.setColor(1, 0.75, 0.25)
                love.graphics.polygon("fill", M.rocketIconPoints(
                    rocketX, rocketY, M.launchIconSize))
            end
        end
        local ox, oy = M.launchPromptOffset(self.time)
        local alpha = M.launchPromptAlpha(self.time)
        local rgb = M.launchPromptRgb
        self.launchPromptFont = self.launchPromptFont or fonts.get(M.launchPromptFontSize)
        local previousPromptFont = love.graphics.getFont()
        love.graphics.setFont(self.launchPromptFont)
        love.graphics.setColor(rgb[1], rgb[2], rgb[3], alpha)
        love.graphics.printf(self.message, 16 + ox, messageY + oy, viewport.width - 32, "center")
        love.graphics.setFont(previousPromptFont)
    else
        love.graphics.printf(self.message, 16, messageY, viewport.width - 32, "center")
    end
    if self.newSpecimenBanner then
        local alpha = math.min(1, self.newSpecimenBannerTimer / 0.4)
        if self.specimenBannerImage then
            local iw, ih = self.specimenBannerImage:getDimensions()
            love.graphics.setColor(1, 1, 1, 0.85 * alpha)
            love.graphics.draw(self.specimenBannerImage, 48, 240, 0,
                (viewport.width - 96) / iw, 64 / ih)
        else
            love.graphics.setColor(0.05, 0.06, 0.12, 0.85 * alpha)
            love.graphics.rectangle("fill", 48, 240, viewport.width - 96, 64)
        end
        love.graphics.setColor(1, 0.85, 0.3, alpha)
        love.graphics.printf(self.newSpecimenBanner, 48, 256, viewport.width - 96, "center")
    end
    if M.showDevPlaceholder then
        self.tinyFont = self.tinyFont or fonts.get(M.devPlaceholderFontSize)
        local previousFooterFont = love.graphics.getFont()
        love.graphics.setFont(self.tinyFont)
        love.graphics.setColor(1, 0.65, 0.2, M.devPlaceholderAlpha)
        love.graphics.printf(i18n.t("dev_placeholder"), 16, viewport.height - 44, viewport.width - 32, "center")
        love.graphics.setFont(previousFooterFont)
    end
end

return M
