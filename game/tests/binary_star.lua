-- INBOX 61(41): binaryStar is +30% sample sell, not a flat +$30 land farm.
local M = {}

local function card(id, suit)
    return { id = id, suit = suit, rarity = "common", tags = {}, effects = {} }
end

local function settleRun(overrides)
    local run = {
        phase = "ascending",
        altitude = 1,
        baseSpeed = 100,
        returnSpeed = 10,
        bestAltitude = 100,
        pendingSampleValue = 0,
        sampleCount = 0,
        maxAltitude = 100,
        money = 0,
        durability = 1,
        maxDurability = 5,
        equippedGear = {},
        equippedEngineParts = {},
    }
    for k, v in pairs(overrides) do
        run[k] = v
    end
    return run
end

function M.run()
    local expedition = require("game.expedition")
    local i18n = require("game.i18n")
    local binaryGear = {
        card("s1", "solar"), card("s2", "solar"),
        card("n1", "nebula"), card("n2", "nebula"),
    }

    local empty = settleRun({
        money = 100,
        pendingSampleValue = 0,
        equippedGear = binaryGear,
    })
    expedition.settle(empty)
    assert(empty.money == 100,
        "INBOX 61(41): empty land must not grant flat $30, got " .. tostring(empty.money))

    local sold = settleRun({
        pendingSampleValue = 100,
        sampleCount = 1,
        equippedGear = binaryGear,
    })
    expedition.settle(sold)
    assert(sold.lastSampleSettlement == 130,
        "INBOX 61(41): sample sell must be +30% (100→130), got " .. tostring(sold.lastSampleSettlement))
    assert(sold.money == 130,
        "INBOX 61(41): money must include +30% sample sell, got " .. tostring(sold.money))

    local plain = settleRun({
        pendingSampleValue = 100,
        sampleCount = 1,
    })
    expedition.settle(plain)
    assert(plain.lastSampleSettlement == 100,
        "INBOX 61(41): no binaryStar must sell samples at face value, got " .. tostring(plain.lastSampleSettlement))
    assert(plain.money == 100,
        "INBOX 61(41): no binaryStar money must equal samples, got " .. tostring(plain.money))

    local hub = {
        pendingSampleValue = 50,
        money = 0,
        equippedGear = binaryGear,
        equippedEngineParts = {},
    }
    local hubPayout = expedition.settleAtHub(hub)
    assert(hubPayout == 65,
        "INBOX 61(41): hub sell +30% of 50 = 65, got " .. tostring(hubPayout))
    assert(hub.money == 65,
        "INBOX 61(41): hub money must include +30% sample sell, got " .. tostring(hub.money))

    i18n.setLocale("en")
    assert(i18n.t("synergy_desc_binaryStar") == "2S+2N: sell +30%",
        "INBOX 61(41): EN synergy_desc_binaryStar")
    i18n.setLocale("ko")
    assert(i18n.t("synergy_desc_binaryStar") == "솔라2+네뷸라2: 판매 +30%",
        "INBOX 61(41): KO synergy_desc_binaryStar")
    i18n.setLocale("en")

    print("  INBOX-61(41) binaryStar sell +30% OK")
end

return M
