local expedition = require("game.expedition")

local M = {}

-- Item 14 (C) chainTrigger consumption gap audit: expedition.chainTriggerCount
-- (above, legacy_gear_run_effect_wiring) has existed only as a stateless re-derived
-- COUNT since item 14's (C)/(E) run-wiring slice -- exactly the same "count
-- exists but nothing ever actually retriggers anything" gap this lane found
-- and closed for rerollBonus (M.spendReroll) and boostCharge (M.spendBoost).
-- Per item 14's own description ("특정 조건마다 다른 장착 카드 효과 재발동,
-- 발라트로 Blueprint/Brainstorm 컨셉"), chainTrigger's actual payoff is
-- re-applying a sample collection's value gain -- so this wires it into
-- M.collectSample: each point of chainTriggerCount(run) re-triggers the
-- collected sample's awarded value once more (awarded * (1 + retriggers)),
-- leaving the streak/sample-count bookkeeping (one collection event) intact.
function M.run()
    -- No gear equipped: chainTriggerCount == 0 must leave collectSample's
    -- awarded value completely unchanged (regression safety against the
    -- pre-wiring baseline computed from streak/yield alone).
    local bareRun = expedition.new()
    bareRun.phase = "ascending"
    local ok, awarded, _, retriggers = expedition.collectSample(bareRun, 100, "solar")
    assert(ok, "collectSample must succeed while ascending")
    assert(awarded == 100, "an unequipped run's awarded sample value must be unchanged, got " .. tostring(awarded))
    assert(retriggers == 0, "an unequipped run must report zero chain retriggers, got " .. tostring(retriggers))

    -- Equip a chainTrigger +1 card: the same base collection must now award
    -- double (1 base application + 1 retrigger), and collectSample must
    -- report the retrigger count actually applied.
    local run = expedition.new()
    run.phase = "ascending"
    local chainCard = {
        id = "chain-fixture", name = "Chain", nameKo = "Chain", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "chainTrigger", value = 1 } },
    }
    assert(expedition.equipGear(run, "hull", chainCard))
    local ok2, awarded2, _, retriggers2 = expedition.collectSample(run, 100, "solar")
    assert(ok2)
    assert(retriggers2 == 1, "a +1 chainTrigger card must report exactly one retrigger, got " .. tostring(retriggers2))
    assert(awarded2 == 200,
        "a +1 chainTrigger card must double the awarded sample value (1 base + 1 retrigger), got " .. tostring(awarded2))
    -- A retrigger must not create a second collection event: sampleCount
    -- still advances by exactly one per collectSample call.
    assert(run.sampleCount == 1, "chain-retriggering a sample must not double-count sampleCount, got " .. tostring(run.sampleCount))

    -- An engine-slot chainTrigger card must count too (category-agnostic,
    -- same combinedGearList design as the other (C)/(E) wrappers).
    local engineRun = expedition.new()
    engineRun.phase = "ascending"
    assert(expedition.equipGear(engineRun, "engine", chainCard))
    local ok3, awarded3 = expedition.collectSample(engineRun, 100, "solar")
    assert(ok3 and awarded3 == 200, "an engine-slot chainTrigger card must also double the awarded value, got " .. tostring(awarded3))
end

return M