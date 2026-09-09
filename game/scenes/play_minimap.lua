--- play_minimap.lua — Minimap + ship stats overlay, extracted from play.lua
-- Provides: drawMinimap, drawShipStatsSummary, galaxyChartLineColor/FillColor,
-- drawMinimapSprite, rimMarker colours, shipStats font constants.
-- Called by play.lua via  playMinimap.install(M)  which copies all public
-- symbols onto the PlayScene table so existing tests/callers keep working.

local world      = require("game.world")
local minimap    = require("game.minimap")
local i18n       = require("game.i18n")
local fonts      = require("game.fonts")
local viewport   = require("game.viewport")
local expedition = require("game.expedition")
local speedDisplay = require("game.speed_display")

local PM = {}

---------------------------------------------------------------------------
-- drawMinimapSprite helper
---------------------------------------------------------------------------
local function drawMinimapSprite(image, cx, cy, targetDiameter)
    if not image then return false end
    local iw, ih = image:getDimensions()
    local scale = targetDiameter / math.max(iw, ih)
    love.graphics.draw(image, cx - iw * scale / 2, cy - ih * scale / 2, 0, scale, scale)
    return true
end
PM.drawMinimapSprite = drawMinimapSprite

---------------------------------------------------------------------------
-- Rim marker colours (INBOX 61(9))
---------------------------------------------------------------------------
PM.rimMarker1Color  = {0.3, 0.9, 0.95, 0.9}
PM.rimMarker1Radius = 3.6
PM.rimMarker2Color  = {0.3, 0.9, 0.95, 0.45}
PM.rimMarker2Radius = 2.8

---------------------------------------------------------------------------
-- Galaxy chart palette (INBOX (8)): one gold for every galaxy ring/marker.
---------------------------------------------------------------------------
function PM.galaxyChartLineColor(_galaxyId)
    return 0.9, 0.75, 0.3, 0.12
end

function PM.galaxyChartFillColor(_galaxyId)
    return 0.9, 0.75, 0.3, 1
end

---------------------------------------------------------------------------
-- drawMinimap — circular galaxy chart (docs/GAME_DESIGN.md items 2·3).
-- `self` is a PlayScene instance (called as self:drawMinimap()).
-- `M` is the PlayScene class table, passed once via install().
---------------------------------------------------------------------------
local _M  -- filled by install()

function PM.drawMinimap(self)
    if self.expedition.phase == "settlement" or self.expedition.phase == "destroyed" then
        return
    end
    local hud = self:hudLines()
    local galaxyShift = hud.galaxy and _M.hudGalaxyShift or 0
    local hudHeight = _M.hudHeight(self.expedition.phase, hud, galaxyShift)
    -- Presentation-only visit memory: entering a galaxy still follows the
    -- existing world.galaxyContaining rule; fading never mutates gameplay's
    -- planet/sample `discovered` state.
    self.minimapDiscoveredGalaxies = self.minimapDiscoveredGalaxies or { milkyway = true }
    local currentGalaxy = world.galaxyContaining(self.ship.x, self.ship.y)
    if currentGalaxy then self.minimapDiscoveredGalaxies[currentGalaxy.id] = true end
    local view = minimap.view(self.ship.x, self.ship.y, self.minimapDiscoveredGalaxies)
    local size = minimap.size
    local cx = viewport.width - size / 2 - 3
    local cy = hudHeight + size / 2 + 32  -- extra 30px gap to avoid text overlap
    local mm = self.minimapImages or {}
    -- Background disc: sprite or filled circle
    love.graphics.setColor(1, 1, 1, 1)
    if not drawMinimapSprite(mm.disc, cx, cy, size) then
        love.graphics.setColor(0.02, 0.04, 0.1, 1)
        love.graphics.circle("fill", cx, cy, size / 2)
        love.graphics.setColor(0.35, 0.55, 0.8, 1)
        love.graphics.circle("line", cx, cy, size / 2)
    end
    -- Item 20a: stencil clip so galaxy rings cannot overflow the disc
    love.graphics.stencil(function()
        love.graphics.circle("fill", cx, cy, size / 2)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    -- Rings: galaxy boundary ring and concentric rings (item 13)
    for _, ring in ipairs(view.rings or {}) do
        if ring.kind == "concentricRing" then
            if ring.inside ~= false or ring.drawAtRim then
                love.graphics.setColor(0.9, 0.75, 0.3, 0.08 * (ring.discoveryAlpha or 1))
                love.graphics.circle("line", cx + ring.x, cy + ring.y, ring.radius)
            end
        elseif ring.kind == "galaxy" and (ring.inside ~= false or ring.drawAtRim) then
            local ringImg = mm.galaxyRing
            local rr, rg, rb, ra = PM.galaxyChartLineColor(ring.id)
            love.graphics.setColor(rr, rg, rb, ra * (ring.discoveryAlpha or 1))
            if ringImg then
                drawMinimapSprite(ringImg, cx + ring.x, cy + ring.y, ring.radius * 2)
            else
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
    -- Galaxy markers: the one discovery target uses fixed geometry and only
    -- changes alpha, avoiding the old one-frame size/visibility pop.
    for _, galaxy in ipairs(view.galaxies) do
        local alpha = galaxy.discoveryAlpha or (galaxy.isContaining and 1 or 0)
        local layers = galaxy.layerAlpha or { mist = alpha, star = alpha }
        if alpha > 0 then
            local gx, gy = cx + galaxy.x, cy + galaxy.y
            local fr, fg, fb = PM.galaxyChartFillColor(galaxy.id)
            -- First contact is only a soft, fixed-size silhouette.
            love.graphics.setColor(fr, fg, fb, 0.12 * layers.mist)
            love.graphics.circle("fill", gx, gy, minimap.markerGalaxyHubRadius * 1.35)
        end
        if alpha <= 0 then
            -- outside the deterministic pre-detection band
        elseif galaxy.hub then
            -- Checkpoint galaxy: sprite or pulsing dot+ring
            local pulse = galaxy.isDiscoveryTarget and 1
                or (0.45 + 0.35 * math.abs(math.sin((self.time or 0) * 2.4)))
            local fr, fg, fb = PM.galaxyChartFillColor(galaxy.id)
            if mm.checkpointStar then
                love.graphics.setColor(fr, fg, fb, (pulse * 0.7 + 0.3) * layers.star)
                drawMinimapSprite(mm.checkpointStar, cx + galaxy.x, cy + galaxy.y, minimap.markerGalaxyHubRadius * 3)
            else
                love.graphics.setColor(fr, fg, fb, layers.star)
                love.graphics.circle("fill", cx + galaxy.x, cy + galaxy.y, 2.3)
                love.graphics.setColor(1, 0.95, 0.6, pulse * layers.star)
                love.graphics.circle("line", cx + galaxy.x, cy + galaxy.y, 4)
            end
        else
            local fr, fg, fb = PM.galaxyChartFillColor(galaxy.id)
            love.graphics.setColor(fr, fg, fb, layers.star)
            local homeOrPlain = galaxy.id == "milkyway" and mm.galaxyHome or mm.galaxyPlain
            local diam = galaxy.id == "milkyway"
                and minimap.markerGalaxyHomeRadius * 2
                or minimap.markerGalaxyPlainRadius * 2
            if not drawMinimapSprite(homeOrPlain, cx + galaxy.x, cy + galaxy.y, diam) then
                love.graphics.circle("fill", cx + galaxy.x, cy + galaxy.y, 1.5)
            end
        end
    end
    -- Item 10 change B: hub markers — distinct magenta/cyan diamond glyph
    for _, hubMk in ipairs(view.hubMarkers or {}) do
        local detailAlpha = hubMk.discoveryAlpha or 1
        if hubMk.inside ~= false and detailAlpha > 0 then
            local pulse = 0.45 + 0.35 * math.abs(math.sin((self.time or 0) * 2.4))
            love.graphics.setColor(0.85, 0.35, 0.95, (pulse * 0.7 + 0.3) * detailAlpha)
            local hx, hy = cx + hubMk.x, cy + hubMk.y
            local r = 3.0
            love.graphics.polygon("fill",
                hx, hy - r,
                hx + r, hy,
                hx, hy + r,
                hx - r, hy)
            love.graphics.setColor(0.85, 0.35, 0.95, pulse * 0.5 * detailAlpha)
            love.graphics.circle("line", hx, hy, 5)
        end
    end
    -- Earth marker: only in the home solar system (milkyway)
    if view.galaxyName == "SOLAR SYSTEM" or view.galaxyName == i18n.t("galaxy_home") then
        love.graphics.setColor(0.3, 0.85, 1, 1)
        if not drawMinimapSprite(mm.earth, cx + view.earth.x, cy + view.earth.y, minimap.markerEarthRadius * 2) then
            love.graphics.circle("fill", cx + view.earth.x, cy + view.earth.y, 2)
        end
    end
    -- Player marker
    love.graphics.setColor(1, 1, 1, 1)
    if not drawMinimapSprite(mm.player, cx + view.player.x, cy + view.player.y, minimap.markerPlayerLineRadius * 2) then
        love.graphics.circle("fill", cx + view.player.x, cy + view.player.y, 1.7)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("line", cx + view.player.x, cy + view.player.y, 2.4)
    end
    -- Item 20d: minimap text labels (11px, grey, inside stencil clip)
    do
        local prevFont = love.graphics.getFont()
        local labelFont = fonts.get(11)
        love.graphics.setFont(labelFont)
        love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
        -- Earth label (milkyway only)
        local isHome = view.galaxyName == "SOLAR SYSTEM" or view.galaxyName == i18n.t("galaxy_home")
        if isHome and view.earth then
            local ex, ey = cx + view.earth.x, cy + view.earth.y
            love.graphics.printf(i18n.t("minimap_earth_label"), ex + 4, ey - 6, 80, "left")
        end
        -- Central star label
        if view.sun then
            local sx, sy = cx + view.sun.x, cy + view.sun.y
            local containingGalaxy = world.galaxyContaining(self.ship.x, self.ship.y)
            local starLabel = world.starName(containingGalaxy) or ""
            love.graphics.printf(starLabel, sx + 4, sy - 6, 120, "left")
        end
        -- Hub/checkpoint label
        for _, hubMk in ipairs(view.hubMarkers or {}) do
            local detailAlpha = hubMk.discoveryAlpha or 1
            if hubMk.inside ~= false and detailAlpha > 0 then
                local hx, hy = cx + hubMk.x, cy + hubMk.y
                local hubLabel = world.hubStarName(hubMk.galaxy or currentGalaxy) or "HUB"
                love.graphics.setColor(0.85, 0.35, 0.95, 0.7 * detailAlpha)
                love.graphics.printf(hubLabel, hx + 6, hy - 6, 100, "left")
                love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
            end
        end
        if prevFont then love.graphics.setFont(prevFont) end
    end
    -- Item 20a: clear stencil
    love.graphics.setStencilTest()
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
    end

    if view.checkpointBeyond then
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

    -- INBOX-34(b): nearest galaxy rim marker
    if view.nearestGalaxyRimMarker then
        local rim = size / 2 - 4
        local marker = view.nearestGalaxyRimMarker
        local mx = cx + marker.dx * rim
        local my = cy + marker.dy * rim
        local markerAlpha = marker.discoveryAlpha or 0
        love.graphics.setColor(PM.rimMarker1Color[1], PM.rimMarker1Color[2],
            PM.rimMarker1Color[3], PM.rimMarker1Color[4] * markerAlpha)
        if markerAlpha > 0 then love.graphics.circle("fill", mx, my, PM.rimMarker1Radius) end
        local prevRimFont = love.graphics.getFont()
        love.graphics.setFont(fonts.get(11))
        local distLabel = string.format("%.0f", marker.distance / 100)
        if markerAlpha > 0 then love.graphics.printf(distLabel, mx - 20, my + 5, 40, "center") end
        love.graphics.setFont(prevRimFont)
    end
    -- Second galaxy rim marker
    if view.secondGalaxyRimMarker then
        local rim = size / 2 - 4
        local marker = view.secondGalaxyRimMarker
        local mx = cx + marker.dx * rim
        local my = cy + marker.dy * rim
        love.graphics.setColor(unpack(PM.rimMarker2Color))
        love.graphics.circle("fill", mx, my, PM.rimMarker2Radius)
        local prevRimFont2 = love.graphics.getFont()
        love.graphics.setFont(fonts.get(11))
        local distLabel2 = string.format("%.0f", marker.distance / 100)
        love.graphics.printf(distLabel2, mx - 20, my + 5, 40, "center")
        love.graphics.setFont(prevRimFont2)
    end
    -- Store minimap bottom for pause button positioning
    self.minimapBottom = cy + size / 2
end

---------------------------------------------------------------------------
-- Ship stats summary (ascending/launch overlay, top-right)
---------------------------------------------------------------------------
PM.shipStatsFontSize = 22
PM.shipStatsLineStep = 26

function PM.drawShipStatsSummary(self)
    local phase = self.expedition.phase
    if phase ~= "ascending" and phase ~= "launch" then return end
    local run = self.expedition
    local statsFont = self.shipStatsFont or fonts.get(PM.shipStatsFontSize)
    self.shipStatsFont = statsFont
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(statsFont)
    local textW = minimap.size
    local textX = viewport.width - 3 - textW
    -- Sample count at the very top
    local statsY = 4
    love.graphics.setColor(0.45, 0.95, 1, 0.6)
    love.graphics.printf(i18n.t("ship_stats_samples_label"), textX, statsY, textW, "right")
    statsY = statsY + PM.shipStatsLineStep
    love.graphics.setColor(0.45, 0.95, 1, 0.9)
    love.graphics.printf(i18n.t("ship_stats_samples", run.pendingSampleValue or 0), textX, statsY, textW, "right")
    statsY = statsY + PM.shipStatsLineStep + 4
    -- Ship stats below samples
    love.graphics.setColor(0.6, 0.7, 0.8, 0.85)
    local shipName = i18n.t("ship_name_" .. (run.selectedShipId or "starter"))
    love.graphics.printf(i18n.t("ship_stats_ship", shipName), textX, statsY, textW, "right")
    statsY = statsY + PM.shipStatsLineStep
    local displayedSpeed = speedDisplay.value(expedition.effectiveSpeed(run), run.baseSpeed)
    love.graphics.printf(i18n.t("ship_stats_speed", displayedSpeed), textX, statsY, textW, "right")
    statsY = statsY + PM.shipStatsLineStep
    local harvestMul = expedition.sampleYieldMultiplier(run)
    love.graphics.printf(i18n.t("ship_stats_harvest", harvestMul), textX, statsY, textW, "right")
    statsY = statsY + PM.shipStatsLineStep
    -- Boost charges remaining
    local boosts = expedition.boostsRemaining(run)
    if boosts > 0 then
        love.graphics.setColor(1, 0.6, 0.2, 0.9)
        love.graphics.printf("BOOST x" .. boosts, textX, statsY, textW, "right")
        statsY = statsY + PM.shipStatsLineStep
    end
    -- Active synergies below stats
    local gearMod = require("game.gear")
    local syn = gearMod.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    local synergyOrder = {
        "solarSystem", "nebulaField", "eventHorizon",
        "pulsarBurst", "binaryStar", "supernova", "darkMatter",
    }
    for _, key in ipairs(synergyOrder) do
        if syn[key] then
            love.graphics.setColor(1, 0.85, 0.3, 0.9)
            love.graphics.printf(i18n.t("synergy_" .. key), textX, statsY, textW, "right")
            statsY = statsY + PM.shipStatsLineStep
        end
    end
    if prevFont then love.graphics.setFont(prevFont) end
end

---------------------------------------------------------------------------
-- install(M) — merge all public names onto the PlayScene class table.
-- Instance methods are set on M so that  scene:drawMinimap()  keeps working.
---------------------------------------------------------------------------
function PM.install(M)
    _M = M  -- cache for hudHeight / hudGalaxyShift lookups
    M.drawMinimapSprite   = drawMinimapSprite
    M.rimMarker1Color     = PM.rimMarker1Color
    M.rimMarker1Radius    = PM.rimMarker1Radius
    M.rimMarker2Color     = PM.rimMarker2Color
    M.rimMarker2Radius    = PM.rimMarker2Radius
    M.galaxyChartLineColor  = PM.galaxyChartLineColor
    M.galaxyChartFillColor  = PM.galaxyChartFillColor
    M.shipStatsFontSize   = PM.shipStatsFontSize
    M.shipStatsLineStep   = PM.shipStatsLineStep
    -- Instance methods
    M.drawMinimap         = PM.drawMinimap
    M.drawShipStatsSummary = PM.drawShipStatsSummary
end

return PM
