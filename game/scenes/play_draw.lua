local M = {}

function M.install(scene)
    local function drawHudSpriteOrPoly(image, pointsFn, cx, cy, size)
        if image then
            local iw, ih = image:getDimensions()
            local scale = size / math.max(iw, ih)
            love.graphics.draw(image, cx - iw * scale / 2, cy - ih * scale / 2, 0, scale, scale)
        elseif pointsFn then
            love.graphics.polygon("fill", pointsFn(cx, cy, size))
        end
    end

    local function drawPlanetEffectSprite(image, cx, cy, diameter, r, g, b, a)
        if not image then return false end
        local iw, ih = image:getDimensions()
        local scale = diameter / math.max(iw, ih)
        love.graphics.setColor(r or 1, g or 1, b or 1, a or 1)
        love.graphics.draw(image, cx - iw * scale / 2, cy - ih * scale / 2, 0, scale, scale)
        return true
    end

    local function drawCollectOrbitRing(x, y, planetRadius, r, g, b, rimImage)
        local radius = scene.collectOrbitRadius(planetRadius)
        local alpha = scene.collectOrbitRingAlpha
        if scene.useCollectOrbitRimSprite and rimImage then
            if drawPlanetEffectSprite(rimImage, x, y, radius * 2, r, g, b, alpha) then
                return true
            end
        end
        local prevWidth = love.graphics.getLineWidth and love.graphics.getLineWidth() or 1
        if love.graphics.setLineWidth then
            love.graphics.setLineWidth(scene.collectOrbitRingLineWidth)
        end
        love.graphics.setColor(r or 1, g or 1, b or 1, alpha)
        love.graphics.circle("line", x, y, radius)
        if love.graphics.setLineWidth then
            love.graphics.setLineWidth(prevWidth)
        end
        return false
    end

    local function drawScaledSprite(image, cx, cy, size)
        if not image then return false end
        local iw, ih = image:getDimensions()
        local scale = size / math.max(iw, ih)
        love.graphics.draw(image, cx - iw * scale / 2, cy - ih * scale / 2, 0, scale, scale)
        return true
    end

    local function drawPanelSprite(image, x, y, _w, _h)
        if not image then return false end
        love.graphics.draw(image, x, y)
        return true
    end

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

    scene.drawHudSpriteOrPoly = drawHudSpriteOrPoly
    scene.drawPlanetEffectSprite = drawPlanetEffectSprite
    scene.drawCollectOrbitRing = drawCollectOrbitRing
    scene.drawFloatingIconSprite = drawScaledSprite
    scene.drawPanelSprite = drawPanelSprite
    scene.drawShopIconSprite = drawScaledSprite
    scene.drawStarPointSprite = drawScaledSprite
    scene.drawPixelStar = drawPixelStar
end

return M
