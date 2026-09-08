local M = {}

function M.run()
    -- INBOX 61(5): solarSystem synergy = +1 maxDurability on settle (not +1 HP heal)
    local i18n = require("game.i18n")
    local expedition = require("game.expedition")
    local gear = require("game.gear")

    -- Verify i18n says "max HP" or "최대내구"
    i18n.setLocale("en")
    local enDesc = i18n.t("synergy_desc_solarSystem")
    assert(enDesc:find("max", 1, true),
        "INBOX 61(5): EN synergy_desc_solarSystem must mention 'max', got: " .. enDesc)
    i18n.setLocale("ko")
    local koDesc = i18n.t("synergy_desc_solarSystem")
    assert(koDesc:find("최대내구", 1, true),
        "INBOX 61(5): KO synergy_desc_solarSystem must mention 최대내구, got: " .. koDesc)

    -- Verify mechanic: settle with solarSystem increases maxDurability
    local function makeCard(id, suit) return { id = id, suit = suit, effects = {} } end
    local run = {
        phase = "returning", returnSpeed = 10,
        bestAltitude = 100, pendingSampleValue = 0, sampleCount = 0,
        maxAltitude = 100, money = 50,
        durability = 3, maxDurability = 3,
        equippedGear = {
            makeCard("s1", "solar"), makeCard("s2", "solar"), makeCard("s3", "solar"),
        },
        equippedEngineParts = {},
    }
    expedition.settle(run)
    assert(run.maxDurability == 4,
        "INBOX 61(5): solarSystem settle must raise maxDurability 3→4, got: " .. tostring(run.maxDurability))
    -- After launch from settlement, durability should be the new maxDurability
    expedition.launch(run)
    assert(run.durability == 4,
        "INBOX 61(5): after launch, durability must equal new maxDurability 4, got: " .. tostring(run.durability))

    i18n.setLocale("en")
    print("  INBOX-61(5) solarSystem maxDurability OK")
end

return M
