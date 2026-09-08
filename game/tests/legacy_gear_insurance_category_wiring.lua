local gear = require("game.gear")

local M = {}

-- Characterizes the engine escape pod's category-specific replacement effect.
function M.run()
    local enginePool = gear.loadEngineParts()
    local escapePod = gear.findById(enginePool, "engine_escape_pod_thruster")
    assert(escapePod, "fixture engine card 'engine_escape_pod_thruster' must exist in the bundled pool")
    local hasBoost = false
    for _, eff in ipairs(escapePod.effects) do
        if eff.type == "boostCharge" then hasBoost = true end
    end
    assert(hasBoost, "engine_escape_pod_thruster must have boostCharge (insurance moved to hull-only)")
end

return M