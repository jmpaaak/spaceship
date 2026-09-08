local gear = require("game.gear")

local M = {}

-- Item 10(b)/14(G) boostCharge lifecycle parity: destroy() resets
-- run.insuranceUsed and run.rerollsUsed (both per-expedition resources that
-- share the same lifecycle comment in M.new -- \"Reset on M.launch, same
-- per-expedition-resource lifecycle as insuranceUsed\"), but did NOT reset
-- run.boostsUsed, leaving the three per-expedition counters inconsistently
-- handled on meta-wipe. The functional harm is zero (destroy also wipes
-- equippedEngineParts, so boostChargeCount -> 0 -> boostsRemaining -> 0
-- regardless of the stale boostsUsed value), but the raw state
-- inconsistency is misleading and violates the documented design contract.
-- This test locks the corrected behavior so the three counters always reset
-- together in both destroy() and M.launch().
function M.run()
    local expedition = require("game.expedition")
    local enginePool = gear.loadEngineParts()

    -- Equip a boostCharge card and spend a charge so boostsUsed > 0.
    local run = expedition.new()
    local boostCard = gear.findById(enginePool, "engine_emergency_boost_pod")
    assert(boostCard, "fixture engine card 'engine_emergency_boost_pod' must exist")
    assert(expedition.equipGear(run, "engine", boostCard))
    expedition.launch(run)
    assert(expedition.spendBoost(run), "spendBoost must succeed with a charge equipped")
    -- boostsUsed is now 1 (one charge consumed)
    assert(run.boostsUsed == 1, "boostsUsed must be 1 after spending one boost charge")

    -- Lethal damage triggers destroy(), which must reset boostsUsed to 0
    -- alongside insuranceUsed (false) and rerollsUsed (0).
    run.durability = 1
    local destroyed = expedition.damage(run, 5)
    assert(destroyed == true, "lethal damage with no insurance must destroy the run")
    assert(run.phase == "destroyed")

    -- The parity test: destroy() must reset boostsUsed just like
    -- insuranceUsed and rerollsUsed.
    assert(run.boostsUsed == 0,
        "destroy() must reset boostsUsed to 0 alongside insuranceUsed and rerollsUsed, "
        .. "got " .. tostring(run.boostsUsed))
    assert(run.insuranceUsed == false,
        "destroy() must reset insuranceUsed to false (regression safety)")
    assert(run.rerollsUsed == 0,
        "destroy() must reset rerollsUsed to 0 (regression safety)")

    -- boostsRemaining is correctly 0 after destroy (gear wiped so
    -- boostChargeCount == 0), regardless of the boostsUsed value -- but
    -- boostsUsed itself must also be 0 for clean state on any subsequent
    -- re-equip+launch, not rely on launch() to clean up destroy()'s mess.
    assert(expedition.boostsRemaining(run) == 0,
        "boostsRemaining must be 0 after destroy (no gear equipped)")
end

return M
