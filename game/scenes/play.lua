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
local play_star = require("game.scenes.play_star")
local playPlanets = require("game.scenes.play_planets")
playPlanets.install(M)
local planetColor = playPlanets.planetColor
local playSteering = require("game.scenes.play_steering")
playSteering.install(M)
local shortestAngleDelta = playSteering.shortestAngleDelta
local playCollision = require("game.scenes.play_collision")
playCollision.install(M, {
    world = world,
    expedition = expedition,
    i18n = i18n,
})
M.__index = M

-- Shared sprite drawing primitives extracted from this oversized scene.
require("game.scenes.play_draw").install(M)
local drawHudSpriteOrPoly = M.drawHudSpriteOrPoly
local drawPlanetEffectSprite = M.drawPlanetEffectSprite
local drawCollectOrbitRing = M.drawCollectOrbitRing
local drawFloatingIconSprite = M.drawFloatingIconSprite
local drawPanelSprite = M.drawPanelSprite
local drawShopIconSprite = M.drawShopIconSprite
local drawStarPointSprite = M.drawStarPointSprite
local drawPixelStar = M.drawPixelStar

-- Pure HUD icon geometry and centered icon/text rendering.
require("game.scenes.play_icons").install(M)

-- Pure HUD band sizing rules (height, text-width cap, and spacing constants).
require("game.scenes.play_hud_layout").install(M)

-- Pure control, pause, and settlement layout rules.
local playLayout = require("game.scenes.play_layout")
playLayout.install(M, viewport)
local settlementTouchRows = M.settlementTouchRows
local pauseButton = M.pauseButton
local adminButtons = playLayout.adminButtons
local adminButtonRect = playLayout.adminButtonRect

-- Pure equipped-gear HUD layout and hit testing.
require("game.scenes.play_hud_gear").install(M)

-- Pure sample-tier presentation profiles and timing rules.
local sampleVisuals = require("game.scenes.play_sample_visuals")
sampleVisuals.install(M)
local sampleTierColor = sampleVisuals.sampleTierColor
local sampleTierEffect = sampleVisuals.sampleTierEffect
local sampleTierSparkle = sampleVisuals.sampleTierSparkle
local sparkleAlpha = sampleVisuals.sparkleAlpha
local sparkleAnticipationMultiplier = sampleVisuals.sparkleAnticipationMultiplier
local sampleTierShakeMultiplier = sampleVisuals.sampleTierShakeMultiplier
local shipPunchDuration = sampleVisuals.shipPunchDuration
local shipShakeDuration = sampleVisuals.shipShakeDuration

-- Pure sample floating-label placement and numeric roll-up rules.
local sampleFeedback = require("game.scenes.play_sample_feedback")
sampleFeedback.install(M)
local clampLabelX = sampleFeedback.clampLabelX
local sampleRollupDuration = sampleFeedback.sampleRollupDuration
local rollupAmount = sampleFeedback.rollupAmount

-- Runtime sprite decoding, loading, maps, and part-icon cache.
local playSprites = require("game.scenes.play_sprites")
playSprites.install(M)
local loadSprite = playSprites.loadSprite
local getPartIcon = playSprites.getPartIcon
local loadSpriteMap = playSprites.loadSpriteMap

-- Equipped-gear HUD rendering, consuming the extracted pure layout.
require("game.scenes.play_hud_gear_draw").install(M, {
    graphics = love.graphics,
    fonts = fonts,
    i18n = i18n,
    getPartIcon = getPartIcon,
})

-- Launch-screen equipped-gear rendering.
require("game.scenes.play_loadout_draw").install(M, {
    graphics = love.graphics,
    fonts = fonts,
    i18n = i18n,
    viewport = viewport,
    getPartIcon = getPartIcon,
})

-- Launch and settlement loadout presentation assembly.
require("game.scenes.play_loadout_data").install(M, {
    expedition = expedition,
    gear = require("game.gear"),
    i18n = i18n,
})

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
require("game.scenes.play_hud").install(M) -- drawStreakHud (INBOX 67)
-- Boost logic extracted to play_boost.lua (MODULE_STRUCTURE).
local playBoost = require("game.scenes.play_boost")
playBoost.install(M)
-- Destroyed-phase layout + keep-one card + Balatro card draw extracted to play_gameover.lua (MODULE_STRUCTURE).
require("game.scenes.play_gameover").install(M)
-- Help (?) button + overlay extracted to play_help.lua (MODULE_STRUCTURE).
require("game.scenes.play_help").install(M)
-- Slot machine logic extracted to play_slot.lua (MODULE_STRUCTURE).
require("game.scenes.play_slot").install(M)
-- Joystick logic extracted to play_joystick.lua (MODULE_STRUCTURE).
require("game.scenes.play_joystick").install(M)
-- Input routing and pointer-consumption contract extracted for R1-A1.
require("game.scenes.play_input").install(M, {
    playBoost = playBoost,
    expedition = expedition,
    i18n = i18n,
    viewport = viewport,
    world = world,
    settlementTouchRows = settlementTouchRows,
    pauseButton = pauseButton,
    adminButtons = adminButtons,
    adminButtonRect = adminButtonRect,
})
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

-- Control and settlement layout constants are installed from play_layout.lua.

-- SHIP DESTROYED restart touch target. Unlike EARTH SHOP's four stacked
-- rows, this phase has a single action (restart), so touchpressed accepts
-- any tap on the full 180x320 internal canvas rather than a narrow band.
-- destroyedTouchArea → moved to game/scenes/play_gameover.lua (installed on M at top of file)

-- Ascending, pause, admin, and legacy return-button layouts are installed
-- from play_layout.lua.

-- Item 2: Earth proximity auto-settle constants.
-- Earth world center is (0, 75); visual radius 58px; settle radius
-- includes a 30px margin matching the gravity/collection range convention.
M.earthCenterX = 0
M.earthCenterY = 75
-- Pure HUD distance and localized line assembly.
require("game.scenes.play_hud_data").install(M, {i18n = i18n, world = world})
M.earthVisualRadius = 68  -- 90 * 0.75 (user 2026-09-06)
M.earthSettleRadius = 68
-- Spawn / relaunch outside the settle disk.
M.launchSpawnX = 0
M.launchSpawnY = 75 - 68 - 20  -- -13  (INBOX 23: margin 50→20)
-- INBOX (5)(a): atmospheric reentry starts outside settle range.
M.earthReentryRadius = 145  -- (INBOX 23: shrink from 174)
M.reentryShakeMax = 6
require("game.scenes.play_reentry").install(M)

-- Collection radius and orbit-ring presentation constants.
require("game.scenes.play_collect_orbit").install(M, expedition)

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

require("game.scenes.play_update").install(M, {
    world = world,
    expedition = expedition,
    sfx = sfx,
    i18n = i18n,
    shortestAngleDelta = shortestAngleDelta,
    sampleRollupDuration = sampleRollupDuration,
    rollupAmount = rollupAmount,
    stickTurnFollow = stickTurnFollow,
    steerTurnRate = steerTurnRate,
    sampleTierShakeMultiplier = sampleTierShakeMultiplier,
    shipShakeDuration = shipShakeDuration,
    shipPunchDuration = shipPunchDuration,
    rcsPuffDuration = rcsPuffDuration,
    pulseHaptic = pulseHaptic,
    viewport = viewport,
})

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

-- drawMinimapSprite / rimMarker* / galaxyChartLineColor / galaxyChartFillColor
-- → moved to game/scenes/play_minimap.lua (installed on M at top of file)

-- Planet tint, deterministic variation, and sprite-path rules are installed
-- from play_planets.lua above.

-- Sample-tier presentation and floating-label feedback rules are installed
-- from play_sample_visuals.lua and play_sample_feedback.lua above.

-- Settlement columns and alternating row colors are installed from
-- play_layout.lua.


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
    local studioPlanetImagePaths = playPlanets.studioPlanetImagePaths()
    local studioPlanetImages = loadSpriteMap(studioPlanetImagePaths)
    local studioHubPlanetImagePaths = playPlanets.studioHubPlanetImagePaths()
    local studioHubPlanetImages = loadSpriteMap(studioHubPlanetImagePaths)
    -- Central star sprites per starType (PIL gen_stars.py)
    local starImagePaths = {
        sun   = "assets/star/star_sun.png",
        ice   = "assets/star/star_ice.png",
        lava  = "assets/star/star_lava.png",
        dry   = "assets/star/star_dry.png",
        gas   = "assets/star/star_gas.png",
        bare  = "assets/star/star_bare.png",
        earth = "assets/star/star_sun.png",
    }
    local starTypeImages = loadSpriteMap(starImagePaths)
    local studioStarImagePaths = play_star.studioStarImagePaths()
    local studioStarImages = loadSpriteMap(studioStarImagePaths)
    -- Rotation sprite sheets (4 frames, 64x256 vertical strip)
    local starSheetPaths = {
        sun   = "assets/star/star_sun_sheet.png",
        ice   = "assets/star/star_ice_sheet.png",
        lava  = "assets/star/star_lava_sheet.png",
        dry   = "assets/star/star_dry_sheet.png",
        gas   = "assets/star/star_gas_sheet.png",
        bare  = "assets/star/star_bare_sheet.png",
        earth = "assets/star/star_sun_sheet.png",
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
    local stationImage = loadSprite("assets/station/station.png")
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
        studioPlanetImages = studioPlanetImages,
        studioPlanetImagePaths = studioPlanetImagePaths,
        studioHubPlanetImages = studioHubPlanetImages,
        studioHubPlanetImagePaths = studioHubPlanetImagePaths,
        studioStarImages = studioStarImages,
        studioStarImagePaths = studioStarImagePaths,
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
        stationImage = stationImage,
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
        launchInputArmed = not options.fromTitle,
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

-- INBOX-40: gear slots grid constants for the HUD (below left stats).
-- 32×32px slots, hull 6 + engine 3 = 9 max, horizontal row, with a
-- small "GEAR" label above the grid in 22px font.
M.gearPopupChipVertical = true  -- INBOX 61(7): chips stacked vertically


-- drawMinimap + drawShipStatsSummary → game/scenes/play_minimap.lua


require("game.scenes.play_scene_draw").install(M, {
    adminButtonRect = adminButtonRect,
    adminButtons = adminButtons,
    drawCollectOrbitRing = drawCollectOrbitRing,
    drawFloatingIconSprite = drawFloatingIconSprite,
    drawHudSpriteOrPoly = drawHudSpriteOrPoly,
    drawPanelSprite = drawPanelSprite,
    drawPixelStar = drawPixelStar,
    drawPlanetEffectSprite = drawPlanetEffectSprite,
    expedition = expedition,
    fonts = fonts,
    i18n = i18n,
    minimap = minimap,
    pauseButton = pauseButton,
    planetColor = planetColor,
    play_star = play_star,
    sampleTierColor = sampleTierColor,
    sampleTierEffect = sampleTierEffect,
    sampleTierSparkle = sampleTierSparkle,
    shipPunchDuration = shipPunchDuration,
    shipShakeDuration = shipShakeDuration,
    sparkleAlpha = sparkleAlpha,
    sparkleAnticipationMultiplier = sparkleAnticipationMultiplier,
    viewport = viewport,
    world = world,
})

return M
