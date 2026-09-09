local M = {}

function M.run()
    -- INBOX 61(31): hub relaunch does not full-heal; hullRegen ticks HP.
    local expedition = require("game.expedition")
    local run = expedition.new({ durability = 3 })
    run.phase = "settlement"
    run.lastVisitedGalaxyId = "andromeda"
    run.durability = 1
    run.maxDurability = 3
    assert(expedition.launch(run), "hub relaunch must succeed")
    assert(run.durability == 1,
        "INBOX 61(31): hub relaunch must keep damaged hull, got " .. tostring(run.durability))

    local earthRun = expedition.new({ durability = 3 })
    earthRun.phase = "settlement"
    earthRun.lastVisitedGalaxyId = nil
    earthRun.durability = 1
    earthRun.maxDurability = 3
    assert(expedition.launch(earthRun))
    assert(earthRun.durability == 3,
        "INBOX 61(31): Earth relaunch must still full-heal, got " .. tostring(earthRun.durability))

    local regenPart = {
        id = "hull_nano_mesh", name = "Nano Mesh", nameKo = "나노 메쉬", icon = "*",
        rarity = "common", tags = {}, editions = {},
        effects = { { type = "hullRegen", value = 0.5 } },
    }
    local regenRun = expedition.new({ durability = 3 })
    regenRun.phase = "ascending"
    regenRun.durability = 1
    regenRun.maxDurability = 3
    assert(expedition.equipGear(regenRun, "hull", regenPart))
    expedition.update(regenRun, 2.1)
    assert(regenRun.durability == 1,
        "INBOX 77(4): authored 0.5 regen must be scaled below 1 HP in 2.1s")
    expedition.update(regenRun, 37.9)
    assert(regenRun.durability == 2,
        "INBOX 77(4): authored 0.5 regen must restore 1 HP in 40s, got " .. tostring(regenRun.durability))
    local i18n = require("game.i18n")
    assert(i18n.effectLine({ type = "hullRegen", value = 0.5 }) == "REGEN +0.025/s")
    print("  INBOX-61(31) hub no-heal + hullRegen OK")
end

return M