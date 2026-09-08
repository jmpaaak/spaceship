local expedition = require("game.expedition")

local M = {}

-- Item 14(D) collisionRadius run wiring: gear.effectiveCollisionRadius has
-- existed as a pure gear.lua conversion since item 14's first slice (same
-- (D) survival/risk-mitigation category as insurance, which was wired into
-- M.damage long ago), but unlike its sibling M.detectionRadius (item 14
-- (C)/(E) run wiring slice), expedition.lua never gained a run-facing
-- M.collisionRadius wrapper -- this was the last remaining item 14 gap.
function M.run()
    -- No gear equipped: the run wrapper must return the base radius
    -- unmodified (same "unequipped == baseline" shape as every other
    -- gear run wrapper in this file).
    local bareRun = expedition.new()
    assert(math.abs(expedition.collisionRadius(bareRun, 10) - 10) < 1e-9,
        "an unequipped run's collision radius must equal the unmodified base radius")

    -- A hull card carrying collisionRadius must shrink the base radius
    -- through the run wrapper, matching gear.effectiveCollisionRadius's
    -- percentage-shrink formula exactly.
    local run = expedition.new()
    local shrinkCard = {
        id = "collision-fixture", name = "Collision", nameKo = "Collision", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "collisionRadius", value = 20 } },
    }
    assert(expedition.equipGear(run, "hull", shrinkCard))
    assert(math.abs(expedition.collisionRadius(run, 10) - 8) < 1e-9,
        "collisionRadius -20%% of base 10 must resolve to 8 through the run wrapper")

    -- Category-agnostic like the (C)/(E) wrappers: an ENGINE-slot card
    -- carrying collisionRadius must also count toward the total.
    local engineRun = expedition.new()
    local engineShrinkCard = {
        id = "engine-collision-fixture", name = "EngineCollision", nameKo = "EngineCollision", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "collisionRadius", value = 50 } },
    }
    assert(expedition.equipGear(engineRun, "engine", engineShrinkCard))
    assert(math.abs(expedition.collisionRadius(engineRun, 10) - 5) < 1e-9,
        "collisionRadius effects on an engine-slot part must also count toward the run-wide total")
end

return M