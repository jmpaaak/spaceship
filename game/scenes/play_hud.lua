-- play_hud.lua: HUD drawing functions extracted from play.lua (INBOX-32)
-- Functions take `self` (PlayScene) + `P` (the play module) for constants.
-- play.lua delegates via thin wrappers that preserve M: names.
local viewport  = require("game.viewport")
local world     = require("game.world")
local minimap   = require("game.minimap")
local i18n      = require("game.i18n")
local fonts     = require("game.fonts")
local expedition = require("game.expedition")

local M = {}

-- Inline copy of drawMinimapSprite (also on P.drawMinimapSprite).
local function drawMinimapSprite(image, cx, cy, targetDiameter)
    if not image then return false end
    local iw, ih = image:getDimensions()
    local scale = targetDiameter / math.max(iw, ih)
    love.graphics.draw(image, cx - iw * scale / 2, cy - ih * scale / 2, 0, scale, scale)
    return true
end

-- Euclidean distance from ship to Earth center (raw number).
function M.hudDistanceRaw(self, P)
    local dx = self.ship.x - P.earthCenterX
    local dy = self.ship.y - P.earthCenterY
    return math.sqrt(dx * dx + dy * dy)
end

-- Build the HUD lines table (strings + metadata) for the current state.
function M.hudLines(self, P)
    local run = self.expedition
    local best = i18n.t("hud_personal_best", math.floor(run.bestAltitude or 0))
    local dx = self.ship.x - P.earthCenterX
    local dy = self.ship.y - P.earthCenterY
    local dist = math.sqrt(dx * dx + dy * dy)
    return {
        distance = i18n.t("hud_distance", math.floor(dist)),
        cash = i18n.t("hud_cash", run.money),
        best = best,
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

-- Draw equipped hull + engine gear slots below the left HUD stats band.
-- hudHeight: pixel height of the top HUD band (used to position the grid).
function M.drawHudGearSlots(self, P, hudHeight)
    local run = self.expedition
    local hullGear = run.equippedGear or {}
    local engineGear = run.equippedEngineParts or {}
    local hullSlots = 6
    local engineSlots = 3
    local slotSize = P.hudGearSlotSize
    local gap = P.hudGearSlotGap
    local groupGap = 8
    -- Determine hudHeight if not provided (normal play path computes it outside)
    if not hudHeight then
        if self.ship then
            local hud = M.hudLines(self, P)
            local galaxyShift = hud.galaxy and P.hudGalaxyShift or 0
            hudHeight = P.hudHeight(self.expedition.phase, hud, galaxyShift)
        else
            hudHeight = 0
        end
    end

    -- Hull label
    self.hudGearLabelFont = self.hudGearLabelFont or fonts.get(P.hudGearLabelFontSize)
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(self.hudGearLabelFont)
    local labelY = hudHeight + 2
    love.graphics.setColor(0.5, 0.6, 0.7, 0.7)
    love.graphics.printf(i18n.t("hud_hull_label"), 5, labelY, 200, "left")

    local gridStartY = labelY + P.hudGearLabelFontSize + 4
    local startX = 5

    local function drawSlot(part, x, y, sz)
        if part then
            if part.rarity == "legendary" then love.graphics.setColor(1, 0.6, 0, 0.7)
            elseif part.rarity == "rare" then love.graphics.setColor(0.3, 0.6, 1, 0.7)
            elseif part.rarity == "uncommon" then love.graphics.setColor(0.4, 0.8, 0.4, 0.7)
            else love.graphics.setColor(0.5, 0.5, 0.5, 0.7) end
            love.graphics.rectangle("fill", x, y, sz, sz)
            local icon = P.getPartIcon(part.id)
            if icon then
                love.graphics.setColor(1, 1, 1, 0.9)
                local iw, ih = icon:getDimensions()
                local sc = (sz - 4) / math.max(iw, ih)
                love.graphics.draw(icon, x + sz/2, y + sz/2, 0, sc, sc, iw/2, ih/2)
            end
            love.graphics.setColor(0.1, 0.1, 0.1, 1)
            love.graphics.rectangle("line", x, y, sz, sz)
        else
            love.graphics.setColor(0.3, 0.35, 0.45, 0.5)
            love.graphics.rectangle("line", x, y, sz, sz)
        end
    end

    for i = 1, hullSlots do
        local y = gridStartY + (i - 1) * (slotSize + gap)
        drawSlot(hullGear[i], startX, y, slotSize)
    end

    local engineStartY = gridStartY + hullSlots * (slotSize + gap) + groupGap
    love.graphics.setColor(0.5, 0.6, 0.7, 0.7)
    love.graphics.printf(i18n.t("hud_engine_label"), 5, engineStartY, 200, "left")
    engineStartY = engineStartY + P.hudGearLabelFontSize + 4
    for i = 1, engineSlots do
        local y = engineStartY + (i - 1) * (slotSize + gap)
        drawSlot(engineGear[i], startX, y, slotSize)
    end
    if prevFont then love.graphics.setFont(prevFont) end
end

-- Draw the minimap disc in the top-right corner.
function M.drawMinimap(self, P)
    if self.expedition.phase == "settlement" or self.expedition.phase == "destroyed" then
        return
    end
    local hud = M.hudLines(self, P)
    local galaxyShift = hud.galaxy and P.hudGalaxyShift or 0
    local hudHeight = P.hudHeight(self.expedition.phase, hud, galaxyShift)
    local view = minimap.view(self.ship.x, self.ship.y)
    local size = minimap.size
    local cx = viewport.width - size / 2 - 3
    local cy = hudHeight + size / 2 + 32
    local mm = self.minimapImages or {}
    love.graphics.setColor(1, 1, 1, 1)
    if not drawMinimapSprite(mm.disc, cx, cy, size) then
        love.graphics.setColor(0.02, 0.04, 0.1, 1)
        love.graphics.circle("fill", cx, cy, size / 2)
        love.graphics.setColor(0.35, 0.55, 0.8, 1)
        love.graphics.circle("line", cx, cy, size / 2)
    end
    love.graphics.stencil(function()
        love.graphics.circle("fill", cx, cy, size / 2)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    for _, ring in ipairs(view.rings or {}) do
        if ring.kind == "concentricRing" then
            if ring.inside ~= false then
                love.graphics.setColor(0.9, 0.75, 0.3, 0.08)
                love.graphics.circle("line", cx + ring.x, cy + ring.y, ring.radius)
            end
        elseif ring.kind == "galaxy" and ring.inside ~= false then
            local ringImg = mm.galaxyRing
            love.graphics.setColor(P.galaxyChartLineColor(ring.id))
            if ringImg then
                drawMinimapSprite(ringImg, cx + ring.x, cy + ring.y, ring.radius * 2)
            else
                love.graphics.circle("line", cx + ring.x, cy + ring.y, ring.radius)
            end
        end
    end
    if view.sun then
        love.graphics.setColor(1, 0.85, 0.25, 1)
        if not drawMinimapSprite(mm.sun, cx + view.sun.x, cy + view.sun.y, minimap.markerSunRadius * 2) then
            love.graphics.circle("fill", cx + view.sun.x, cy + view.sun.y, 2.6)
        end
    end
    for _, galaxy in ipairs(view.galaxies) do
        if not galaxy.isContaining then
            -- skip
        elseif galaxy.hub then
            local pulse = 0.45 + 0.35 * math.abs(math.sin((self.time or 0) * 2.4))
            local fr, fg, fb = P.galaxyChartFillColor(galaxy.id)
            if mm.checkpointStar then
                love.graphics.setColor(fr, fg, fb, pulse * 0.7 + 0.3)
                drawMinimapSprite(mm.checkpointStar, cx + galaxy.x, cy + galaxy.y, minimap.markerGalaxyHubRadius * 3)
            else
                love.graphics.setColor(fr, fg, fb)
                love.graphics.circle("fill", cx + galaxy.x, cy + galaxy.y, 2.3)
                love.graphics.setColor(1, 0.95, 0.6, pulse)
                love.graphics.circle("line", cx + galaxy.x, cy + galaxy.y, 4)
            end
        else
            love.graphics.setColor(P.galaxyChartFillColor(galaxy.id))
            local homeOrPlain = galaxy.id == "milkyway" and mm.galaxyHome or mm.galaxyPlain
            local diam = galaxy.id == "milkyway"
                and minimap.markerGalaxyHomeRadius * 2
                or minimap.markerGalaxyPlainRadius * 2
            if not drawMinimapSprite(homeOrPlain, cx + galaxy.x, cy + galaxy.y, diam) then
                love.graphics.circle("fill", cx + galaxy.x, cy + galaxy.y, 1.5)
            end
        end
    end
    for _, hubMk in ipairs(view.hubMarkers or {}) do
        if hubMk.inside ~= false then
            local pulse = 0.45 + 0.35 * math.abs(math.sin((self.time or 0) * 2.4))
            love.graphics.setColor(0.85, 0.35, 0.95, pulse * 0.7 + 0.3)
            local hx, hy = cx + hubMk.x, cy + hubMk.y
            local r = 3.0
            love.graphics.polygon("fill", hx, hy - r, hx + r, hy, hx, hy + r, hx - r, hy)
            love.graphics.setColor(0.85, 0.35, 0.95, pulse * 0.5)
            love.graphics.circle("line", hx, hy, 5)
        end
    end
    if view.galaxyName == "SOLAR SYSTEM" or view.galaxyName == i18n.t("galaxy_home") then
        love.graphics.setColor(0.3, 0.85, 1, 1)
        if not drawMinimapSprite(mm.earth, cx + view.earth.x, cy + view.earth.y, minimap.markerEarthRadius * 2) then
            love.graphics.circle("fill", cx + view.earth.x, cy + view.earth.y, 2)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    if not drawMinimapSprite(mm.player, cx + view.player.x, cy + view.player.y, minimap.markerPlayerLineRadius * 2) then
        love.graphics.circle("fill", cx + view.player.x, cy + view.player.y, 1.7)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("line", cx + view.player.x, cy + view.player.y, 2.4)
    end
    do
        local prevFont = love.graphics.getFont()
        local labelFont = fonts.get(11)
        love.graphics.setFont(labelFont)
        love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
        local isHome = view.galaxyName == "SOLAR SYSTEM" or view.galaxyName == i18n.t("galaxy_home")
        if isHome and view.earth then
            local ex, ey = cx + view.earth.x, cy + view.earth.y
            love.graphics.printf(i18n.t("minimap_earth_label"), ex + 4, ey - 6, 80, "left")
        end
        if view.sun then
            local sx, sy = cx + view.sun.x, cy + view.sun.y
            local containingGalaxy = world.galaxyContaining(self.ship.x, self.ship.y)
            local starLabel = world.starName(containingGalaxy) or ""
            love.graphics.printf(starLabel, sx + 4, sy - 6, 120, "left")
        end
        for _, hubMk in ipairs(view.hubMarkers or {}) do
            if hubMk.inside ~= false then
                local hx, hy = cx + hubMk.x, cy + hubMk.y
                local containingGalaxy = world.galaxyContaining(self.ship.x, self.ship.y)
                local hubLabel = world.hubStarName(containingGalaxy) or "HUB"
                love.graphics.setColor(0.85, 0.35, 0.95, 0.7)
                love.graphics.printf(hubLabel, hx + 6, hy - 6, 100, "left")
                love.graphics.setColor(0.6, 0.6, 0.6, 0.7)
            end
        end
        if prevFont then love.graphics.setFont(prevFont) end
    end
    love.graphics.setStencilTest()
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
    if view.nearestGalaxyRimMarker then
        local rim = size / 2 - 4
        local marker = view.nearestGalaxyRimMarker
        local mx = cx + marker.dx * rim
        local my = cy + marker.dy * rim
        love.graphics.setColor(unpack(P.rimMarker1Color))
        love.graphics.circle("fill", mx, my, P.rimMarker1Radius)
        local prevRimFont = love.graphics.getFont()
        love.graphics.setFont(fonts.get(11))
        local distLabel = string.format("%.0f", marker.distance / 100)
        love.graphics.printf(distLabel, mx - 20, my + 5, 40, "center")
        love.graphics.setFont(prevRimFont)
    end
    if view.secondGalaxyRimMarker then
        local rim = size / 2 - 4
        local marker = view.secondGalaxyRimMarker
        local mx = cx + marker.dx * rim
        local my = cy + marker.dy * rim
        love.graphics.setColor(unpack(P.rimMarker2Color))
        love.graphics.circle("fill", mx, my, P.rimMarker2Radius)
        local prevRimFont2 = love.graphics.getFont()
        love.graphics.setFont(fonts.get(11))
        local distLabel2 = string.format("%.0f", marker.distance / 100)
        love.graphics.printf(distLabel2, mx - 20, my + 5, 40, "center")
        love.graphics.setFont(prevRimFont2)
    end
    self.minimapBottom = cy + size / 2
end

-- Draw ship name / speed / harvest / synergies in the top-right corner.
function M.drawShipStatsSummary(self, P)
    local phase = self.expedition.phase
    if phase ~= "ascending" and phase ~= "launch" then return end
    local run = self.expedition
    local statsFont = self.shipStatsFont or fonts.get(P.shipStatsFontSize)
    self.shipStatsFont = statsFont
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(statsFont)
    local textW = minimap.size
    local textX = viewport.width - 3 - textW
    local statsY = 4
    love.graphics.setColor(0.45, 0.95, 1, 0.6)
    love.graphics.printf(i18n.t("ship_stats_samples_label"), textX, statsY, textW, "right")
    statsY = statsY + P.shipStatsLineStep
    love.graphics.setColor(0.45, 0.95, 1, 0.9)
    love.graphics.printf(i18n.t("ship_stats_samples", run.pendingSampleValue or 0), textX, statsY, textW, "right")
    statsY = statsY + P.shipStatsLineStep + 4
    love.graphics.setColor(0.6, 0.7, 0.8, 0.85)
    local shipName = i18n.t("ship_name_" .. (run.selectedShipId or "starter"))
    love.graphics.printf(i18n.t("ship_stats_ship", shipName), textX, statsY, textW, "right")
    statsY = statsY + P.shipStatsLineStep
    love.graphics.printf(i18n.t("ship_stats_speed", expedition.effectiveSpeed(run)), textX, statsY, textW, "right")
    statsY = statsY + P.shipStatsLineStep
    local harvestMul = expedition.sampleYieldMultiplier(run)
    love.graphics.printf(i18n.t("ship_stats_harvest", harvestMul), textX, statsY, textW, "right")
    statsY = statsY + P.shipStatsLineStep
    local boosts = expedition.boostsRemaining(run)
    if boosts > 0 then
        love.graphics.setColor(1, 0.6, 0.2, 0.9)
        love.graphics.printf("BOOST x" .. boosts, textX, statsY, textW, "right")
        statsY = statsY + P.shipStatsLineStep
    end
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
            statsY = statsY + P.shipStatsLineStep
        end
    end
    if prevFont then love.graphics.setFont(prevFont) end
end

return M
