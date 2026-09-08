local gear = require("game.gear")

local M = {}

-- Item 14 (A)~(G) content coverage: every run-wired effect type in
-- gear.knownEffectTypes must actually be used by at least one card in the
-- bundled hull_parts.json/engine_parts.json pools combined, not merely
-- exist as validated-but-dead schema. Item 10(b)'s engine-propulsion suite
-- already checked this for the (G) propulsion effects; this generalizes the
-- same "real content, not just schema" regression to the full A~F set,
-- which docs/STATUS.md had documented as having a "최소 1개 실제
-- run-level 소비자" (a run-state *function*) for every type, but several
-- types (luck, chainTrigger, rerollBonus, collisionRadius, detectionRadius,
-- autoCollect, sellMultiplier) still had zero cards actually using them in
-- the shipped card pools -- so the run-level wiring existed but a player
-- could never actually encounter it in play.
function M.run()
    local hullPool = gear.loadHullParts()
    local enginePool = gear.loadEngineParts()
    local seen = {}
    for _, pool in ipairs({ hullPool, enginePool }) do
        for _, part in ipairs(pool) do
            for _, effect in ipairs(part.effects) do
                seen[effect.type] = true
            end
        end
    end
    for t, _ in pairs(gear.knownEffectTypes) do
        assert(seen[t], "effect type '" .. t ..
            "' must be used by at least one bundled hull/engine part (content coverage, item 14)")
    end
end

return M
