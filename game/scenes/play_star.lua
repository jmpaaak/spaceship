local centralStarAssets = require("game.central_star_asset_manifest")

local play_star = {}

function play_star.studioStarImagePaths()
    local paths = {}
    for starType, asset in pairs(centralStarAssets.stars) do
        if asset.runtimePath then
            paths[starType] = asset.runtimePath
        end
    end
    return paths
end

function play_star.studioStarSheetImagePaths()
    local paths = {}
    for starType, asset in pairs(centralStarAssets.stars) do
        if asset.runtimeSheetPath then
            paths[starType] = asset.runtimeSheetPath
        end
    end
    return paths
end

function play_star.drawCentralStar(playState, sx, sy, worldStarRadius, wellGalaxy, time)
    -- Fallback sequence:
    -- 1. Approved exact starType static image
    -- 2. Exact starType sheet
    -- 3. Exact starType legacy static image
    -- 4. "sun" sheet fallback
    -- 5. "sun" static image fallback
    -- 6. circle (last resort)

    local starType = (wellGalaxy and wellGalaxy.starType) or "sun"

    local studioStarSheet = playState.studioStarSheetImages and playState.studioStarSheetImages[starType]
    if studioStarSheet then
        local sw, sh = studioStarSheet:getDimensions()
        local frameH = sw
        local frameCount = math.floor(sh / frameH)
        if frameCount > 0 then
            local frameIdx = math.floor((time or 0) * 2) % frameCount
            local quad = love.graphics.newQuad(0, frameIdx * frameH, sw, frameH, sw, sh)
            local starScale = (worldStarRadius * 2) / sw
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.draw(studioStarSheet, quad, sx - worldStarRadius, sy - worldStarRadius, 0, starScale, starScale)
            return
        end
    end

    local studioStarImg = playState.studioStarImages and playState.studioStarImages[starType]
    if studioStarImg then
        local iw, ih = studioStarImg:getDimensions()
        local starScale = (worldStarRadius * 2) / math.max(iw, ih)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(studioStarImg, sx, sy, 0, starScale, starScale, iw / 2, ih / 2)
        return
    end

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
