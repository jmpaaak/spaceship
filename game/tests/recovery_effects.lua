local M = {}

local function close(actual, expected)
    return math.abs(actual - expected) < 0.000001
end

function M.run()
    print("  [INBOX 77(4)] persistent recovery balance tests...")

    local recoveryEffects = require("game.recovery_effects")
    assert(close(recoveryEffects.rate("hullRegen", 5), 0.25),
        "hullRegen must apply at exactly 1/20 of its authored rate")
    assert(close(recoveryEffects.rate("speed", 5), 5),
        "non-recovery effects must not be scaled")

    local expedition = require("game.expedition")
    local regenPart = {
        id = "test_regen", name = "Test Regen", rarity = "common",
        tags = {}, editions = {},
        effects = { { type = "hullRegen", value = 5 } },
    }
    local run = expedition.new({ durability = 5 })
    run.phase = "ascending"
    run.durability = 1
    run.maxDurability = 5
    assert(expedition.equipGear(run, "hull", regenPart))
    expedition.update(run, 3.9)
    assert(run.durability == 1,
        "5 authored hullRegen must not restore HP before four seconds")
    expedition.update(run, 0.1)
    assert(run.durability == 2,
        "5 authored hullRegen must restore exactly 0.25 HP/s")

    local i18n = require("game.i18n")
    i18n.setLocale("en")
    assert(i18n.effectLine(regenPart.effects[1]) == "REGEN +0.25/s",
        "English gear display must show the applied 0.25 HP/s rate")
    i18n.setLocale("ko")
    assert(i18n.effectLine(regenPart.effects[1]) == "회복 +0.25/초",
        "Korean gear display must show the applied 0.25 HP/s rate")
    i18n.setLocale("en")

    print("  INBOX-77(4) persistent recovery is scaled and displayed consistently OK")
end

return M