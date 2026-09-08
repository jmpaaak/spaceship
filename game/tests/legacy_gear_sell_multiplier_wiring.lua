local expedition = require("game.expedition")

local M = {}

-- Item 10/14 (B) sellMultiplier engine-slot gap: docs/GEAR_SCHEMA.md and
-- legacy_gear_category_coverage treat sellMultiplier as
-- hull/engine category-agnostic (combinedGearList), and engine_parts.json
-- now ships engine_market_thruster (sellMultiplier +20) for that coverage
-- — but effectiveSampleBonus historically read only run.equippedGear (hull).
-- An engine-only sellMultiplier card must scale a hull sampleSellValue card,
-- while sampleSellValue itself stays hull-only.
function M.run()
    local hullSell = {
        id = "hull-sample-sell-fixture", name = "HullSell", nameKo = "HullSell", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "sampleSellValue", value = 10 } },
    }
    local engineMult = {
        id = "engine-sell-mult-fixture", name = "EngineMult", nameKo = "EngineMult", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "sellMultiplier", value = 50 } },
    }
    local hullMult = {
        id = "hull-sell-mult-fixture", name = "HullMult", nameKo = "HullMult", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "sellMultiplier", value = 50 } },
    }
    local engineSell = {
        id = "engine-sample-sell-fixture", name = "EngineSell", nameKo = "EngineSell", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "sampleSellValue", value = 10 } },
    }

    local bare = expedition.new()
    assert(expedition.effectiveSampleBonus(bare) == 0,
        "an unequipped run must have zero gear sample bonus")

    local hullOnly = expedition.new()
    assert(expedition.equipGear(hullOnly, "hull", hullSell))
    assert(math.abs(expedition.effectiveSampleBonus(hullOnly) - 10) < 1e-9,
        "a hull sampleSellValue +10 card must resolve to a flat +10 bonus with no multiplier")

    local stacked = expedition.new()
    assert(expedition.equipGear(stacked, "hull", hullSell))
    assert(expedition.equipGear(stacked, "engine", engineMult))
    assert(math.abs(expedition.effectiveSampleBonus(stacked) - 15) < 1e-9,
        "engine-slot sellMultiplier +50% must scale hull sampleSellValue 10 to 15, got "
            .. tostring(expedition.effectiveSampleBonus(stacked)))
    stacked.phase = "ascending"
    local ok, awarded = expedition.collectSample(stacked, 100)
    assert(ok and awarded == 115,
        "collectSample must apply engine sellMultiplier to the hull sampleSellValue bonus: got "
            .. tostring(awarded))

    -- Engine sellMultiplier alone cannot invent a sampleSellValue total —
    -- (B) multiplies the (A) additive, it does not replace it.
    local engineOnly = expedition.new()
    assert(expedition.equipGear(engineOnly, "engine", engineMult))
    assert(expedition.effectiveSampleBonus(engineOnly) == 0,
        "an engine-only sellMultiplier card must not invent a sample bonus without hull sampleSellValue")

    -- Hull sellMultiplier must keep working (regression vs the original
    -- hull-only equippedTotals path in legacy_gear_run_effect_wiring).
    local hullBoth = expedition.new()
    assert(expedition.equipGear(hullBoth, "hull", hullSell))
    assert(expedition.equipGear(hullBoth, "hull", hullMult))
    assert(math.abs(expedition.effectiveSampleBonus(hullBoth) - 15) < 1e-9,
        "hull-slot sellMultiplier +50% must still scale hull sampleSellValue 10 to 15")

    -- (A) sampleSellValue stays hull-scoped: an ENGINE-slot sampleSellValue
    -- card must not count, even though sellMultiplier on the same slot does.
    local engineAdditive = expedition.new()
    assert(expedition.equipGear(engineAdditive, "engine", engineSell))
    assert(expedition.effectiveSampleBonus(engineAdditive) == 0,
        "sampleSellValue on an engine-slot part must NOT count (item 9 scopes this additive to hull)")
end

return M
