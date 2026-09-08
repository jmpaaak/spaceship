local expedition = require("game.expedition")

local M = {}

-- Characterize the run-facing chainTrigger/rerollBonus and
-- detectionRadius/autoCollect wrappers while the legacy runner is split.
function M.run()
    -- No gear equipped: all four must resolve to their documented
    -- zero/false/baseline defaults.
    local bareRun = expedition.new()
    assert(expedition.chainTriggerCount(bareRun) == 0,
        "an unequipped run must have zero chain-trigger re-activations")
    assert(expedition.rerollCount(bareRun) == 0,
        "an unequipped run must have zero free rerolls")
    assert(math.abs(expedition.detectionRadius(bareRun, 20) - 20) < 1e-9,
        "an unequipped run's detection radius must equal the unmodified base radius")
    assert(expedition.autoCollectEnabled(bareRun) == false,
        "an unequipped run must not have auto-collect enabled")
    assert(expedition.rerollsRemaining(bareRun) == 0,
        "an unequipped run must have zero remaining free rerolls")
    local spent, err = expedition.spendReroll(bareRun)
    assert(spent == false and type(err) == "string",
        "spendReroll must refuse (false + message) when no free rerolls remain")

    -- Equip one hull card carrying all four effect types and confirm the
    -- run-level wrappers combine them with the actual equipped list.
    local run = expedition.new()
    local comboCard = {
        id = "combo-fixture", name = "Combo", nameKo = "Combo", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = {
            { type = "chainTrigger", value = 1.9 },
            { type = "rerollBonus", value = 2.4 },
            { type = "detectionRadius", value = 50 },
            { type = "autoCollect", value = 1 },
        },
    }
    assert(expedition.equipGear(run, "hull", comboCard))
    assert(expedition.chainTriggerCount(run) == 1,
        "chainTrigger total must floor to a whole re-trigger count through the run wrapper")
    assert(expedition.rerollCount(run) == 2,
        "rerollBonus total must floor to a whole free-reroll count through the run wrapper")
    assert(math.abs(expedition.detectionRadius(run, 20) - 30) < 1e-9,
        "detectionRadius +50%% of base 20 must resolve to 30 through the run wrapper")
    assert(expedition.autoCollectEnabled(run) == true,
        "a positive autoCollect effect must enable auto-collect through the run wrapper")

    -- Spending decrements the per-expedition counter to zero and refuses
    -- further spends without changing the raw equipped total.
    assert(expedition.rerollsRemaining(run) == 2,
        "a run with rerollBonus == 2 (floored) must start with 2 remaining free rerolls")
    local ok1 = expedition.spendReroll(run)
    assert(ok1 == true, "spendReroll must succeed while rerolls remain")
    assert(expedition.rerollsRemaining(run) == 1,
        "spending one reroll must decrement the remaining count by exactly one")
    local ok2 = expedition.spendReroll(run)
    assert(ok2 == true, "spendReroll must succeed for the last remaining reroll")
    assert(expedition.rerollsRemaining(run) == 0,
        "rerollsRemaining must reach exactly zero once every free reroll is spent")
    local ok3, err3 = expedition.spendReroll(run)
    assert(ok3 == false and type(err3) == "string",
        "spendReroll must refuse (false + message), not go negative, once rerolls are exhausted")
    assert(expedition.rerollsRemaining(run) == 0,
        "a refused spendReroll call must not further decrement the remaining count")

    -- Re-launching refills the per-expedition reroll resource.
    run.phase = "settlement"
    assert(expedition.launch(run))
    assert(expedition.rerollsRemaining(run) == 2,
        "launching a new expedition must refill remaining rerolls back to the equipped rerollBonus total")

    -- sampleSellValue plus sellMultiplier must affect actual collection.
    local sellRun = expedition.new()
    local sellCard = {
        id = "sell-fixture", name = "Sell", nameKo = "Sell", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = {
            { type = "sampleSellValue", value = 10 },
            { type = "sellMultiplier", value = 50 },
        },
    }
    assert(expedition.equipGear(sellRun, "hull", sellCard))
    assert(math.abs(expedition.effectiveSampleBonus(sellRun) - 15) < 1e-9,
        "equipped sampleSellValue+sellMultiplier gear must resolve to a flat +15 sample bonus")
    sellRun.phase = "ascending"
    local sellOk, sellAwarded = expedition.collectSample(sellRun, 100)
    assert(sellOk and sellAwarded == 115,
        "collectSample must add the equipped gear's flat sampleSellValue/sellMultiplier bonus: got " .. tostring(sellAwarded))

    local bareSellRun = expedition.new()
    assert(expedition.effectiveSampleBonus(bareSellRun) == 0,
        "an unequipped run must have zero gear sample bonus")

    -- Engine-slot effects participate in category-agnostic run totals.
    local engineRun = expedition.new()
    local engineComboCard = {
        id = "engine-combo-fixture", name = "EngineCombo", nameKo = "EngineCombo", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "chainTrigger", value = 1 } },
    }
    assert(expedition.equipGear(engineRun, "engine", engineComboCard))
    assert(expedition.chainTriggerCount(engineRun) == 1,
        "chainTrigger effects on an engine-slot part must also count toward the run-wide total")
end

return M