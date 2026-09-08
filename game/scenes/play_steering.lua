local M = {}

function M.headingFromStick(dx, dy)
    return math.atan2(dy or 0, dx or 0)
end

function M.shortestAngleDelta(from, to)
    local delta = to - from
    while delta > math.pi do
        delta = delta - 2 * math.pi
    end
    while delta < -math.pi do
        delta = delta + 2 * math.pi
    end
    return delta
end

function M.install(target)
    target.headingFromStick = M.headingFromStick
    target.shortestAngleDelta = M.shortestAngleDelta
    return target
end

return M
