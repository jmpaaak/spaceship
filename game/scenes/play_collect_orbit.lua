local M = {}

M.collectRadiusPadding = 30
M.collectOrbitRingAlpha = 0.3
M.collectOrbitRingLineWidth = 1
M.useCollectOrbitRimSprite = false

function M.radius(planetRadius, run, padding, expedition)
    local base = (planetRadius or 0) + padding
    if run then
        return expedition.collectOrbitRadius(run, base)
    end
    return base
end

function M.install(scene, expedition)
    scene.collectRadiusPadding = M.collectRadiusPadding
    scene.collectOrbitRingAlpha = M.collectOrbitRingAlpha
    scene.collectOrbitRingLineWidth = M.collectOrbitRingLineWidth
    scene.useCollectOrbitRimSprite = M.useCollectOrbitRimSprite

    function scene.collectOrbitRadius(planetRadius, run)
        return M.radius(planetRadius, run, scene.collectRadiusPadding, expedition)
    end
end

return M