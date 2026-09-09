local expedition = require("game.expedition")

local M = {}

-- Item 14(B) streakMultiplier wiring: docs/GEAR_SCHEMA.md and item 14's
-- own text named this as "defined in the schema... but its consumer...
-- lives in gameplay code" -- a gap this test closes by verifying an
-- equipped streakMultiplier card actually raises expedition.streakMultiplier's
-- per-step growth rate above the base 0.2, and that collectSample's
-- returned multiplier reflects the boosted rate for a real run.
function M.run()
    -- No gear equipped: base rate (0.2 per step) must be unchanged,
    -- matching the pre-item-14 hardcoded constant exactly.
    local bareRun = expedition.new()
    assert(math.abs(expedition.streakBonusPerStep(bareRun) - 0.2) < 1e-9,
        "an unequipped run's streak bonus per step must equal the base 0.2 rate")
    assert(math.abs(expedition.streakMultiplier(3, bareRun) - 1.4) < 1e-9,
        "an unequipped run's streakMultiplier(3) must match the pre-wiring baseline 1.4")
    -- Calling with no run argument at all (legacy 1-arg call site) must
    -- still fall back to the base rate rather than erroring.
    assert(math.abs(expedition.streakMultiplier(3) - 1.4) < 1e-9,
        "streakMultiplier must still work with no run argument (base rate fallback)")

    -- Equip the bundled hull_combo_matrix card (streakMultiplier +10,
    -- i.e. +10 percentage points per step) and confirm the per-step rate
    -- rises to 0.3 and streakMultiplier(3) rises accordingly (1 + 2*0.3 = 1.6,
    -- not the unboosted 1.4).
    local boostedRun = expedition.new()
    local comboCard = {
        id = "hull_combo_matrix", name = "Combo Matrix", nameKo = "콤보 매트릭스", icon = "▦",
        rarity = "rare", tags = { "economy", "control" }, editions = {},
        effects = { { type = "streakMultiplier", value = 10 } },
    }
    assert(expedition.equipGear(boostedRun, "hull", comboCard))
    assert(math.abs(expedition.streakBonusPerStep(boostedRun) - 0.3) < 1e-9,
        "an equipped +10 streakMultiplier card must raise the per-step rate to 0.3")
    assert(math.abs(expedition.streakMultiplier(3, boostedRun) - 1.6) < 1e-9,
        "streakMultiplier(3) with the boosted rate must be 1.6 (1 + 2*0.3), got "
            .. tostring(expedition.streakMultiplier(3, boostedRun)))

    -- An engine-slot streakMultiplier card must count too (item 14's (C)/(E)
    -- category-agnostic combinedGearList design applies equally to this
    -- (B) wiring, since streakMultiplier isn't restricted to hull cards
    -- in the schema).
    local engineBoostedRun = expedition.new()
    assert(expedition.equipGear(engineBoostedRun, "engine", comboCard))
    assert(math.abs(expedition.streakBonusPerStep(engineBoostedRun) - 0.3) < 1e-9,
        "an engine-slot streakMultiplier card must also raise the per-step rate")

    -- End-to-end through collectSample: three consecutive same-hue-family
    -- collections on the boosted run must return the boosted multiplier on
    -- the third call (mult grows 1.0 -> 1.3 -> 1.6).
    boostedRun.phase = "ascending"
    local ok1, _, mult1 = expedition.collectSample(boostedRun, 100, "solar")
    local ok2, _, mult2 = expedition.collectSample(boostedRun, 100, "solar")
    local ok3, _, mult3 = expedition.collectSample(boostedRun, 100, "solar")
    assert(ok1 and ok2 and ok3)
    assert(math.abs(mult1 - 1) < 1e-9)
    assert(math.abs(mult2 - 1.3) < 1e-9, "second same-family collect must use the boosted rate: got " .. tostring(mult2))
    assert(math.abs(mult3 - 1.6) < 1e-9, "third same-family collect must use the boosted rate: got " .. tostring(mult3))
end

return M
