local expedition = require("game.expedition")
local gear = require("game.gear")

local M = {}

-- Item 14(C) rerollBonus gap, one level deeper than legacy_gear_run_effect_wiring's
-- coverage: M.spendReroll(run) only decrements a per-expedition counter; this
-- test preserves the atomic spend-and-generate contract of rerollGearOffer.
function M.run()
    local hullPool = gear.loadHullParts()

    -- No free rerolls remaining: refuse atomically without mutating state.
    local bareRun = expedition.new()
    local okBare, errBare = expedition.rerollGearOffer(bareRun, hullPool, {
        rarity = 0, pick = 0, editionChance = 0.99, editionPick = 0,
    })
    assert(okBare == false and type(errBare) == "string",
        "rerollGearOffer must refuse (false + message) when no free rerolls remain")
    assert(bareRun.rerollsUsed == 0,
        "a refused rerollGearOffer call must not consume a reroll")

    -- Equip rerollBonus +1, then consume exactly one reroll while producing
    -- the same real offer shape as rollGearOffer.
    local run = expedition.new()
    local rerollCard = {
        id = "reroll-fixture", name = "Reroll", nameKo = "Reroll", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "rerollBonus", value = 1 } },
    }
    assert(expedition.equipGear(run, "hull", rerollCard))
    assert(expedition.rerollsRemaining(run) == 1,
        "a run with rerollBonus == 1 must start with exactly one remaining free reroll")

    local ok, offer = expedition.rerollGearOffer(run, hullPool, {
        rarity = 0, pick = 0, editionChance = 0.99, editionPick = 0,
    })
    assert(ok == true, "rerollGearOffer must succeed while a free reroll remains")
    assert(type(offer) == "table" and type(offer.id) == "string",
        "a successful rerollGearOffer must return a real gear offer table, got " .. tostring(offer))
    assert(expedition.rerollsRemaining(run) == 0,
        "a successful rerollGearOffer must consume exactly one free reroll")

    -- A second call must refuse and leave the exhausted budget unchanged.
    local ok2, err2 = expedition.rerollGearOffer(run, hullPool, {
        rarity = 0, pick = 0, editionChance = 0.99, editionPick = 0,
    })
    assert(ok2 == false and type(err2) == "string",
        "rerollGearOffer must refuse once its per-expedition reroll budget is exhausted")
    assert(expedition.rerollsRemaining(run) == 0,
        "a refused rerollGearOffer call must not further decrement remaining rerolls")
end

return M
