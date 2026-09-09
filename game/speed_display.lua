-- User-facing speed is the increase above the run's physical base speed.
local M = {}

function M.value(effectiveSpeed, baseSpeed)
    return effectiveSpeed - baseSpeed
end

return M
