local play_star = {}

function play_star.drawCentralStar(playState, sx, sy, worldStarRadius, wellGalaxy, time)
    -- Fallback sequence:
    -- 1. Exact starType sheet
    -- 2. Exact starType static image
    -- 3. "sun" sheet fallback
    -- 4. "sun" static image fallback
    -- 5. circle (last resort)

    local starType = (wellGalaxy and wellGalaxy.starType) or "sun"

    local starSheet = playState.starSheetImages and playState.starSheetImages[starType]
    if starSheet then
        local sw, sh = starSheet:getDimensions()
        local frameH = sw
        local frameCount = math.floor(sh / frameH)
        if frameCount > 0 then
            local frameIdx = math.floor((time or 0) * 2) % frameCount
            local quad = love.graphics.newQuad(0, frameIdx * frameH, sw, frameH, sw, sh)
            local starScale = (worldStarRadius * 2) / sw
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(starSheet, quad, sx - worldStarRadius, sy - worldStarRadius, 0, starScale, starScale)
            return
        end
    end

    local starImg = playState.starTypeImages and playState.starTypeImages[starType]
    if starImg then
        local iw, ih = starImg:getDimensions()
        local starScale = (worldStarRadius * 2) / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(starImg, sx, sy, 0, starScale, starScale, iw / 2, ih / 2)
        return
    end

    -- fallback to sun sheet
    local sunSheet = playState.starSheetImages and playState.starSheetImages["sun"]
    if sunSheet then
        local sw, sh = sunSheet:getDimensions()
        local frameH = sw
        local frameCount = math.floor(sh / frameH)
        if frameCount > 0 then
            local frameIdx = math.floor((time or 0) * 2) % frameCount
            local quad = love.graphics.newQuad(0, frameIdx * frameH, sw, frameH, sw, sh)
            local starScale = (worldStarRadius * 2) / sw
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(sunSheet, quad, sx - worldStarRadius, sy - worldStarRadius, 0, starScale, starScale)
            return
        end
    end

    -- fallback to sun static
    local sunImg = playState.starTypeImages and playState.starTypeImages["sun"]
    if sunImg then
        local iw, ih = sunImg:getDimensions()
        local starScale = (worldStarRadius * 2) / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(sunImg, sx, sy, 0, starScale, starScale, iw / 2, ih / 2)
        return
    end

    -- ultimate fallback
    love.graphics.setColor(1, 0.85, 0.25, 1)
    love.graphics.circle("fill", sx, sy, worldStarRadius)
end

return play_star
