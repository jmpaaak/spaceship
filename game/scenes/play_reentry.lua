local M = {}

M.heatVignetteMaxAlpha = 0.3

function M.drawOffsetX(time, magnitude)
    return math.sin(time * 60) * (magnitude or 0)
end

function M.shakeFromDistance(dist, radius, maximum)
    if dist >= radius then
        return 0
    end
    if dist <= 0 then
        return maximum
    end
    return maximum * (1 - dist / radius)
end

function M.heatVignetteAlpha(dist, radius, maximum)
    maximum = maximum or M.heatVignetteMaxAlpha
    if dist >= radius then
        return 0
    end
    if dist <= 0 then
        return maximum
    end
    return maximum * (1 - dist / radius)
end

function M.install(target)
    target.reentryDrawOffsetX = M.drawOffsetX
    target.reentryShakeFromDistance = function(dist)
        return M.shakeFromDistance(dist, target.earthReentryRadius, target.reentryShakeMax)
    end
    target.reentryHeatVignetteAlpha = function(dist)
        return M.heatVignetteAlpha(dist, target.earthReentryRadius)
    end
    return target
end

return M
