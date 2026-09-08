local expedition = require("game.expedition")

local M = {}

-- Item 10(b)/9 gap audit: item 10's own text names climb acceleration
-- ("상승 가속") as one of the engine-specialized effects engine parts should
-- carry, and 7 of the 24 bundled engine_parts.json cards carry a `climbSpeed`
-- effect. Keep this as a flat additive contribution (no tag-synergy
-- multiplier), matching the engine slot's other plain propulsion stats.
function M.run()
    -- No gear equipped: baseline (regression guard).
    local bareRun = expedition.new({ baseSpeed = 20 })
    assert(expedition.effectiveSpeed(bareRun) == 20,
        "an unequipped fresh run's effectiveSpeed must equal run.baseSpeed 20, got "
            .. tostring(expedition.effectiveSpeed(bareRun)))

    -- Equipping an ENGINE-slot card with a `climbSpeed` effect must raise
    -- effectiveSpeed by exactly that additive amount.
    local engineClimbCard = {
        id = "engine-climb-fixture", name = "Climb Thruster", nameKo = "Climb Thruster", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "speed", value = 5 } },
    }
    local run = expedition.new({ baseSpeed = 20 })
    assert(expedition.equipGear(run, "engine", engineClimbCard))
    local boosted = expedition.effectiveSpeed(run)
    assert(boosted == 25,
        "equipping an engine speed +5 card must raise effectiveSpeed from 20 to 25, got "
            .. tostring(boosted))

    -- Hull and engine speed contributions must stack additively.
    local hullClimbCard = {
        id = "hull-climb-fixture", name = "Hull Booster", nameKo = "Hull Booster", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "speed", value = 7 } },
    }
    local stackedRun = expedition.new({ baseSpeed = 20 })
    assert(expedition.equipGear(stackedRun, "hull", hullClimbCard))
    assert(expedition.equipGear(stackedRun, "engine", engineClimbCard))
    local stacked = expedition.effectiveSpeed(stackedRun)
    assert(stacked == 32,
        "hull speed +7 and engine speed +5 must both stack onto base 20 for 32, got "
            .. tostring(stacked))
end

return M