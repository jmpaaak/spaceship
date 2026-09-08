local expedition = require("game.expedition")
local gear = require("game.gear")

local M = {}

-- Item 10(b) propulsion-specialization run wiring for the effects that
-- remain meaningful in flight: engine speed and boostCharge.
function M.run()
    local enginePool = gear.loadEngineParts()

    -- Item 53a: engine speed now feeds into expedition.effectiveSpeed.
    -- Equipping engine_vector_nozzle (speed +19) must raise effectiveSpeed.
    local steerRun = expedition.new()
    local baseSteering = expedition.effectiveSpeed(steerRun)
    local vectorCard = gear.findById(enginePool, "engine_vector_nozzle")
    assert(vectorCard, "fixture engine card 'engine_vector_nozzle' must exist in the bundled pool")
    assert(expedition.equipGear(steerRun, "engine", vectorCard))
    local boostedSteering = expedition.effectiveSpeed(steerRun)
    assert(boostedSteering > baseSteering,
        "equipped engine speed part must raise effectiveSpeed: "
            .. tostring(baseSteering) .. " -> " .. tostring(boostedSteering))

    -- boostCharge: a fresh run with no engine parts must report zero
    -- charges; equipping engine_emergency_boost_pod (boostCharge +2) must
    -- expose that count via expedition.boostChargeCount.
    local boostRun = expedition.new()
    assert(expedition.boostChargeCount(boostRun) == 0,
        "a fresh run with no engine parts must have zero boost charges")
    local boostCard = gear.findById(enginePool, "engine_emergency_boost_pod")
    assert(boostCard, "fixture engine card 'engine_emergency_boost_pod' must exist in the bundled pool")
    assert(expedition.equipGear(boostRun, "engine", boostCard))
    assert(expedition.boostChargeCount(boostRun) == 2,
        "equipping engine_emergency_boost_pod must grant 2 boost charges")

    -- Sanity: none of these engine-part effects leak into the independent
    -- hull gear list (item 10's slot-independence guarantee still holds).
    assert(#boostRun.equippedGear == 0, "engine part effects must not touch the hull gear list")

    -- Item 10(b)/14(G) boostCharge CONSUMPTION gap: until this slice,
    -- boostChargeCount(run) was only ever a pure re-derived total (like
    -- rerollCount was before M.spendReroll existed) -- nothing could
    -- actually SPEND a "긴급 부스트/1회성 소모 아이템" charge and see the
    -- pool deplete, mirroring the exact gap item 14(C)'s rerollBonus had
    -- before M.rerollsRemaining/M.spendReroll closed it. A fresh run with
    -- the boost pod equipped must start with 2 remaining boosts (matching
    -- the equipped total), spending must decrement a per-expedition
    -- counter down to zero then refuse further spends (never negative,
    -- never throws), and re-launching must refill back to the current
    -- equipped total (same lifecycle as insuranceUsed/rerollsUsed).
    assert(expedition.boostsRemaining(boostRun) == 2,
        "a run with boostChargeCount == 2 must start with 2 remaining boost charges")
    local bOk1 = expedition.spendBoost(boostRun)
    assert(bOk1 == true, "spendBoost must succeed while boost charges remain")
    assert(expedition.boostsRemaining(boostRun) == 1,
        "spending one boost must decrement the remaining count by exactly one")
    local bOk2 = expedition.spendBoost(boostRun)
    assert(bOk2 == true, "spendBoost must succeed for the last remaining boost charge")
    assert(expedition.boostsRemaining(boostRun) == 0,
        "boostsRemaining must reach exactly zero once every boost charge is spent")
    local bOk3, bErr3 = expedition.spendBoost(boostRun)
    assert(bOk3 == false and type(bErr3) == "string",
        "spendBoost must refuse (false + message), not go negative, once boosts are exhausted")
    assert(expedition.boostsRemaining(boostRun) == 0,
        "a refused spendBoost call must not further decrement the remaining count")

    local bareBoostRun = expedition.new()
    assert(expedition.boostsRemaining(bareBoostRun) == 0,
        "an unequipped run must have zero remaining boost charges")
    local bareOk, bareErr = expedition.spendBoost(bareBoostRun)
    assert(bareOk == false and type(bareErr) == "string",
        "spendBoost must refuse (false + message) when no boost charges remain")

    boostRun.phase = "settlement"
    assert(expedition.launch(boostRun))
    assert(expedition.boostsRemaining(boostRun) == 2,
        "launching a new expedition must refill remaining boost charges back to the equipped boostChargeCount total")
end

return M