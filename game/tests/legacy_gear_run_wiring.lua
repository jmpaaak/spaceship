local expedition = require("game.expedition")
local gear = require("game.gear")

local M = {}

-- Minimal game wiring for items 9/10/13 ("최소한의 로더 호출 추가는 예외로
-- 허용"): expedition.lua now owns a run.gearLoadout (hull + engine slot
-- lists via engine_parts.lua) and applies the item 9 climbSpeed synergy
-- bonus during ascent. This does NOT touch play.lua/world.lua — only the
-- run-state module explicitly carved out as an exception in loop/PROMPT.md.
function M.run()
    local run = expedition.new({ baseSpeed = 60 })

    -- A fresh run starts with an empty, independent hull/engine loadout.
    assert(type(run.equippedGear) == "table" and #run.equippedGear == 0,
        "a fresh run must start with an empty hull gear list")
    assert(type(run.equippedEngineParts) == "table" and #run.equippedEngineParts == 0,
        "a fresh run must start with an empty engine parts list")

    -- Equipping a bundled hull card with a climbSpeed effect must boost
    -- ascent beyond the base climbSpeed (item 9's core payoff, now actually
    -- wired into gameplay instead of only existing as a pure function).
    local hullPool = gear.loadHullParts()
    local climbCard = gear.findById(hullPool, "hull_nebula_core") -- climbSpeed +5, no synergy tag overlap needed alone
    assert(climbCard, "fixture hull card 'hull_nebula_core' must exist in the bundled pool")
    local ok, err = expedition.equipGear(run, "hull", climbCard)
    assert(ok, "equipping a hull card into a fresh run must succeed: " .. tostring(err))
    assert(#run.equippedGear == 1 and run.equippedGear[1].id == "hull_nebula_core")

    expedition.launch(run)
    expedition.update(run, 1)
    assert(run.altitude > 60,
        "equipped hull card's climbSpeed effect must increase ascent beyond the base climbSpeed 60: "
            .. tostring(run.altitude))

    -- Engine parts occupy a fully independent slot list — equipping one
    -- must not touch equippedGear (item 10's core "서로 슬롯을 잠식하지
    -- 않는다" requirement, now checked against the actual run object).
    local enginePool = gear.loadEngineParts()
    local enginePart = enginePool[1]
    local engineOk = expedition.equipGear(run, "engine", enginePart)
    assert(engineOk, "equipping an engine card must succeed")
    assert(#run.equippedEngineParts == 1 and #run.equippedGear == 1,
        "equipping an engine part must not change the hull gear list")

    assert(expedition.unequipGear(run, "hull", "hull_nebula_core"))
    assert(#run.equippedGear == 0 and #run.equippedEngineParts == 1,
        "unequipping a hull card must not affect the engine parts list")

    -- Destruction's full meta wipe (docs/GAME_DESIGN.md) must also clear
    -- both gear slot lists, same as it already clears upgrades/ships.
    local wipeRun = expedition.new()
    assert(expedition.equipGear(wipeRun, "hull", climbCard))
    assert(expedition.equipGear(wipeRun, "engine", enginePart))
    expedition.launch(wipeRun)
    wipeRun.durability = 1
    assert(expedition.damage(wipeRun, 5))
    assert(wipeRun.phase == "destroyed")
    assert(#wipeRun.equippedGear == 0 and #wipeRun.equippedEngineParts == 0,
        "the durability-0 meta wipe must clear equipped hull and engine parts")
end

return M
