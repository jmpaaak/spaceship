local Module = {}

function Module.install(scene, deps)
    local M = scene
    local adminButtonRect = deps.adminButtonRect
    local adminButtons = deps.adminButtons
    local drawCollectOrbitRing = deps.drawCollectOrbitRing
    local drawFloatingIconSprite = deps.drawFloatingIconSprite
    local drawHudSpriteOrPoly = deps.drawHudSpriteOrPoly
    local drawPanelSprite = deps.drawPanelSprite
    local drawPixelStar = deps.drawPixelStar
    local drawPlanetEffectSprite = deps.drawPlanetEffectSprite
    local expedition = deps.expedition
    local fonts = deps.fonts
    local i18n = deps.i18n
    local minimap = deps.minimap
    local pauseButton = deps.pauseButton
    local planetColor = deps.planetColor
    local play_star = deps.play_star
    local sampleTierColor = deps.sampleTierColor
    local sampleTierEffect = deps.sampleTierEffect
    local sampleTierSparkle = deps.sampleTierSparkle
    local shipPunchDuration = deps.shipPunchDuration
    local shipShakeDuration = deps.shipShakeDuration
    local sparkleAlpha = deps.sparkleAlpha
    local sparkleAnticipationMultiplier = deps.sparkleAnticipationMultiplier
    local viewport = deps.viewport
    local world = deps.world

function M:draw()
    local galaxy = world.galaxyContaining(self.ship.x, self.ship.y)
    love.graphics.clear(world.galaxyBackgroundColor(galaxy))
    local shipScreenX, shipScreenY = viewport.width / 2, math.floor(viewport.height * 0.58)
    local cameraX, cameraY = self.ship.x - shipScreenX, self.ship.y - shipScreenY
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
    local sx, sy = world.sectorAt(self.ship.x, self.ship.y)
    local galaxySpecialFrame = galaxy and galaxy.starTypeIdx or 0
    local bgCameraX, bgCameraY = cameraX * 0.4, cameraY * 0.4
    local bsx, bsy = world.sectorAt(bgCameraX, bgCameraY)
    local bgScanR = math.max(4, math.ceil(viewport.height / 2 / world.sectorSize) + 2)
    for oy = -bgScanR, bgScanR do
        for ox = -bgScanR, bgScanR do
            for _, star in ipairs(world.backgroundStars(bsx + ox, bsy + oy)) do
                local x, y = math.floor(star.x - bgCameraX), math.floor(star.y - bgCameraY)
                if x >= 0 and x < viewport.width and y >= 0 and y < viewport.height then
                    local starHash = (math.floor(star.x) * 92837 + math.floor(star.y) * 689287) % 10000007
                    if star.bright < 0.4 then
                        local frameIdx = starHash % 17
                        local sz = 2 + (starHash % 2)
                        local opacity = 0.15 + star.bright * 0.4
                        if not drawPixelStar(self.pixelStarsImage, x, y, 9, 9, 17, frameIdx, sz, 1, 1, 1, opacity) then
                            love.graphics.setColor(0.12 + star.bright * 0.4, 0.12 + star.bright * 0.4, math.min(1, 0.2 + star.bright * 0.4), opacity)
                            love.graphics.rectangle("fill", x - 1, y - 1, 2, 2)
                        end
                    else
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
                    local starHash = (math.floor(star.x) * 92837 + math.floor(star.y) * 689287) % 10000007
                    if star.bright < 0.4 then
                        local frameIdx = starHash % 17
                        local sz = 3 + (starHash % 2)
                        local opacity = 0.15 + star.bright * 0.4
                        if not drawPixelStar(self.pixelStarsImage, x, y, 9, 9, 17, frameIdx, sz, 1, 1, 1, opacity) then
                            love.graphics.setColor(0.35 + star.bright * 0.65, 0.35 + star.bright * 0.65, math.min(1, 0.43 + star.bright * 0.65))
                            love.graphics.rectangle("fill", x - 1, y - 1, 2, 2)
                        end
                    else
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
        local upgrade = i18n.t("checkpoint_hint_upgrade")
        local bob = math.sin(self.time * 2) * 3
        local f = love.graphics.getFont()
        local lineH = 14
        local topY = earthY + M.earthVisualRadius + 8 + bob
        love.graphics.setColor(0.65, 0.68, 0.72, 0.7)
        love.graphics.print(sell, earthX - f:getWidth(sell) / 2, topY)
        love.graphics.print(upgrade, earthX - f:getWidth(upgrade) / 2, topY + lineH)
        love.graphics.setFont(prevEarthFont)
    end
    do
        local wellGalaxy = world.galaxyContaining(self.ship.x, self.ship.y)
        local wellSun = wellGalaxy and world.sunPosition(wellGalaxy)
        if wellSun then
            local sx, sy = math.floor(wellSun.x - cameraX), math.floor(wellSun.y - cameraY)
            if sx > -world.starWellRadius - 10 and sx < viewport.width + world.starWellRadius + 10
                and sy > -world.starWellRadius - 10 and sy < viewport.height + world.starWellRadius + 10 then
                local pulse = 0.6 + 0.15 * math.sin(self.time * 3)
                love.graphics.setColor(1.0, 0.45, 0.15, pulse * 0.35)
                love.graphics.circle("line", sx, sy, world.starWellRadius)
                love.graphics.setColor(1.0, 0.25, 0.1, pulse * 0.15)
                love.graphics.circle("line", sx, sy, world.starWellRadius * 0.7)
                love.graphics.setColor(1.0, 0.85, 0.25, pulse * 0.08)
                play_star.drawCentralStar(self, sx, sy, world.starRadius, wellGalaxy, self.time)
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
            local pe2 = self.planetEffectImages or {}
            local shadowDiam = planet.radius * 2 * 1.02
            if not drawPlanetEffectSprite(pe2.shadow,
                    x + planet.radius * 0.22, y + planet.radius * 0.22,
                    shadowDiam, 0, 0, 0, 0.25) then
                love.graphics.setColor(0, 0, 0, 0.25)
                love.graphics.circle("fill", x + planet.radius * 0.22, y + planet.radius * 0.22, planet.radius * 1.02)
            end
            local baseR, baseG, baseB = planetColor(planet.hue)
            local planetSprite, sheetImg = M.selectPlanetArtwork(planet, {
                default = self.planetImage,
                hub = self.hubPlanetImage,
                shop = self.shopPlanetImage,
                pixel = self.ppPlanetImages,
                sheets = self.planetSheetImages,
                hubSheet = self.hubSheetImage,
                studio = self.studioPlanetImages,
            })
            local rot, scaleMul = M.planetVariation(planet)
            local tR = math.min(1, baseR * 0.35 + 0.65)
            local tG = math.min(1, baseG * 0.35 + 0.65)
            local tB = math.min(1, baseB * 0.35 + 0.65)
            love.graphics.setColor(tR, tG, tB)
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
                if not self.moonDiscovered[moon.id] then
                    local sf = moon.speedFactor or 0.5
                    love.graphics.setColor(1, 1 - sf * 0.7, 1 - sf * 0.8, 0.6)
                    love.graphics.circle("line", mx, my, (moon.collectRadius or moon.radius) + 15)
                end
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
    for _, comet in ipairs(world.nearbyComets(self.ship.x, self.ship.y, self.time, viewport.width, viewport.height)) do
        local cx, cy = math.floor(comet.x - cameraX), math.floor(comet.y - cameraY)
        if cx > -60 and cx < viewport.width + 60 and cy > -60 and cy < viewport.height + 60 then
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
                local tr = 1
                local tg = 0.85 * (1 - t * 0.8)
                local tb = 0.1 * (1 - t)
                local pr = math.max(1, comet.radius * (1 - t * 0.6))
                love.graphics.setColor(tr, tg, tb, alpha)
                love.graphics.circle("fill", tx, ty, pr)
            end
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
    if collectZoomScale ~= 1 then
        love.graphics.pop()
    end

    local hud = self:hudLines()
    local galaxyShift = hud.galaxy and M.hudGalaxyShift or 0
    local hudHeight = M.hudHeight(self.expedition.phase, hud, galaxyShift)
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
    do
        local hudIconsTmp2 = self.hudIconImages or {}
        local distIconSize = M.hullIconSize
        drawHudSpriteOrPoly(hudIconsTmp2.distance, nil,
            5 + distIconSize / 2, hudY + distIconSize / 2, distIconSize)
        local dist = self:hudDistanceRaw()
        local currentMilestone = math.floor(dist / 1000)
        if currentMilestone > (self.distanceMilestone or 0) then
            self.distanceMilestone = currentMilestone
            self.distanceMilestoneFlash = 1.0
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
    do
        love.graphics.setColor(1, 0.85, 0.3)
        local hudIcons = self.hudIconImages or {}
        drawHudSpriteOrPoly(hudIcons.cash, M.coinIconPoints,
            5 + M.cashIconSize / 2, hudY + M.cashIconSize / 2, M.cashIconSize)
        love.graphics.setColor(0.7, 0.9, 1)
        love.graphics.print(hud.cash, 5 + M.cashIconSize + M.cashIconGap, hudY)
        hudY = hudY + M.hudLineStep
    end
    do
        local hudIcons = self.hudIconImages or {}
        local iconCenterX = 5 + M.hullIconSize / 2
        local iconCenterY = hudY + M.hudLineStep / 2
        love.graphics.setColor(0.6, 0.85, 1)
        drawHudSpriteOrPoly(hudIcons.hull, M.shieldIconPoints,
            iconCenterX, iconCenterY, M.hullIconSize)
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
            local bigCount = math.ceil(run.maxDurability / 10)
            for i = 1, bigCount do
                local blockMin = (i - 1) * 10 + 1
                local blockMax = math.min(i * 10, run.maxDurability)
                local blockCapacity = 10
                local blockFilled = math.max(0, math.min(run.durability - blockMin + 1, blockMax - blockMin + 1))
                if blockFilled >= blockCapacity then
                    local hr, hg, hb = hpColor(run.durability, run.maxDurability)
                    love.graphics.setColor(hr, hg, hb)
                    love.graphics.rectangle("fill", blockX, blockY, M.hpBlockSize, M.hpBlockSize)
                    love.graphics.setColor(math.min(1, hr + 0.3), math.min(1, hg + 0.3), math.min(1, hb + 0.3), 0.45)
                    local sz = M.hpBlockSize
                    for s = 3, sz, 5 do
                        love.graphics.line(blockX + s, blockY, blockX, blockY + s)
                    end
                    for s = 3, sz, 5 do
                        love.graphics.line(blockX + sz, blockY + s, blockX + s, blockY + sz)
                    end
                    love.graphics.setColor(math.min(1, hr + 0.2), math.min(1, hg + 0.2), math.min(1, hb + 0.2), 0.8)
                    love.graphics.rectangle("line", blockX, blockY, M.hpBlockSize, M.hpBlockSize)
                elseif blockFilled > 0 then
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

    if self.expedition.phase ~= "settlement" and self.expedition.phase ~= "destroyed" then
        self:drawHudGearSlots(hudHeight)
    end
    self:drawMinimap()
    self:drawShipStatsSummary()
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
    if self.expedition.phase ~= "launch" and self.messageBannerIconImage then
        local bannerIconSize = 10
        love.graphics.setColor(1, 0.82, 0.25)
        drawFloatingIconSprite(self.messageBannerIconImage,
            4 + bannerIconSize * 0.5, messageY + 5, bannerIconSize, 1)
        love.graphics.setColor(0.85, 0.9, 1)
    end
    if self.newSpecimenBanner then
        local alpha = math.min(1, self.newSpecimenBannerTimer / 0.4)
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
    if self.expedition.phase == "ascending" then
        local mmBot = self.minimapBottom or 300
        local pb = pauseButton
        pb.y = mmBot + 8  -- dynamic: just below minimap
        local bx, by, bw, bh = pb.x, pb.y, pb.w, pb.h
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
        self:drawHelpButton()
    end
    self:drawPauseOverlay()
    self:drawHelpOverlay()
    if self.shopModal then
        self:drawShopModal()
    end
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
end

return Module
