local M = {}

local RATE_SCALE = 1 / 20
local persistentRecovery = {
    hullRegen = true,
}

function M.rate(effectType, authoredValue)
    local value = tonumber(authoredValue) or 0
    if persistentRecovery[effectType] then
        return value * RATE_SCALE
    end
    return value
end

function M.displayValue(effect)
    if type(effect) ~= "table" then return 0 end
    if effect.mode == "multiply" then
        return tonumber(effect.value) or 0
    end
    return M.rate(effect.type, effect.value)
end

function M.formatRate(value)
    return (string.format("%.3f", value):gsub("0+$", ""):gsub("%.$", ""))
end

return M