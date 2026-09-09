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

    -- INBOX 66: boostCharge is a CAP. A fresh run starts empty (0 remaining)
    -- even with a boost pod equipped; spending still refuses at 0, and
    -- launch resets remaining to 0 (not a refill to the cap).
    assert(expedition.boostsRemaining(boostRun) == 0,
        "INBOX 66: a run with boostChargeCount == 2 must start empty (cap, not fill)")
    local bOk0, bErr0 = expedition.spendBoost(boostRun)
    assert(bOk0 == false and type(bErr0) == "string",
        "spendBoost must refuse (false + message) when remaining is 0")
    assert(expedition.boostsRemaining(boostRun) == 0,
        "a refused spendBoost call must not further decrement the remaining count")

    -- Mint two charges via ascent regen, then spend them down.
    boostRun.phase = "ascending"
    expedition.update(boostRun, 5)
    assert(expedition.boostsRemaining(boostRun) == 1,
        "5s of ascent must mint 1 charge")
    local bOk1 = expedition.spendBoost(boostRun)
    assert(bOk1 == true, "spendBoost must succeed while boost charges remain")
    assert(expedition.boostsRemaining(boostRun) == 0,
        "spending one boost must decrement the remaining count by exactly one")
    expedition.update(boostRun, 5)
    expedition.update(boostRun, 5)
    assert(expedition.boostsRemaining(boostRun) == 2,
        "10s more of ascent must mint back up to the cap of 2")
    local bOk2 = expedition.spendBoost(boostRun)
    assert(bOk2 == true, "spendBoost must succeed for a remaining boost charge")
    assert(expedition.boostsRemaining(boostRun) == 1)
    local bOk3 = expedition.spendBoost(boostRun)
    assert(bOk3 == true, "spendBoost must succeed for the last remaining boost charge")
    assert(expedition.boostsRemaining(boostRun) == 0,
        "boostsRemaining must reach exactly zero once every boost charge is spent")
    local bOk4, bErr4 = expedition.spendBoost(boostRun)
    assert(bOk4 == false and type(bErr4) == "string",
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
    assert(expedition.boostsRemaining(boostRun) == 0,
        "launching a new expedition must start remaining at 0 (cap is not a starting fill)")
end

return M