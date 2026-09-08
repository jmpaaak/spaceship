local M = {}

M.labelMargin = 2
M.sampleRollupDuration = 0.3

function M.clampLabelX(centerX, textWidth, viewportWidth, margin)
    margin = margin or M.labelMargin
    local x = centerX - textWidth / 2
    local maxX = viewportWidth - margin - textWidth
    if x > maxX then x = maxX end
    if x < margin then x = margin end
    return x
end

function M.rollupAmount(awarded, elapsed, duration)
    if duration <= 0 then return awarded end
    local progress = math.max(0, math.min(1, elapsed / duration))
    return math.floor(awarded * progress + 0.5)
end

function M.install(scene)
    scene.clampLabelX = M.clampLabelX
    scene.sampleRollupDuration = M.sampleRollupDuration
    scene.rollupAmount = M.rollupAmount
    return scene
end

return M
