local expedition = require("game.expedition")
local gear = require("game.gear")

local M = {}

-- Item 12 crystallized ("✨ 결정화 — 판매가 대폭 상승") was documented as
-- a SELL-PRICE spike (INBOX item 12 example + GEAR_SCHEMA "판매가 대폭
-- 상승") but sellValue treated every edition as a flat +6 premium.
-- Irradiated/quantum_flawed/refined already have unique mechanics
-- (synergy / doubled effects+drawback / noSlotCost); crystallized's
-- unique promise was the cash-out, and that was dead. This regression
-- locks a crystallized-specific sell multiplier on top of the shared
-- edition premium, plus the run-level sellGear credit.
function M.run()
    -- Other editions keep the shared flat premium only.
    local rareBase = gear.sellValue({ rarity = "rare" })
    assert(rareBase == 18)
    assert(gear.sellValue({ rarity = "rare", edition = "irradiated" }) == 24,
        "non-crystallized editions must keep the shared editionSellBonus only")
    assert(gear.sellValue({ rarity = "rare", edition = "quantum_flawed" }) == 24)
    assert(gear.sellValue({ rarity = "rare", edition = "refined" }) == 24)

    -- Crystallized must strictly beat every other edition of the same rarity.
    local crystalSell = gear.sellValue({ rarity = "rare", edition = "crystallized" })
    assert(crystalSell > 24,
        "crystallized must sell for more than the shared edition premium, got " .. tostring(crystalSell))
    assert(crystalSell == 18 * gear.crystallizedSellMultiplier + gear.editionSellBonus,
        "crystallized sell value must be rarityBase * crystallizedSellMultiplier + editionSellBonus, got "
            .. tostring(crystalSell))

    -- Legendary crystallized also scales the rarity base, not a flat extra.
    assert(gear.sellValue({ rarity = "legendary", edition = "crystallized" })
        == 40 * gear.crystallizedSellMultiplier + gear.editionSellBonus)

    -- buyPrice stays 3x sellValue so sell-to-rebuy remains lossy even for
    -- the high-refund edition (item 9(c) economy invariant).
    local crystalPart = { rarity = "rare", edition = "crystallized" }
    assert(gear.buyPrice(crystalPart) == crystalSell * gear.buyPriceMultiplier)
    assert(gear.buyPrice(crystalPart) > gear.sellValue(crystalPart))

    -- Unknown/missing rarity still falls back to common before the
    -- crystallized multiplier is applied.
    assert(gear.sellValue({ edition = "crystallized" })
        == 4 * gear.crystallizedSellMultiplier + gear.editionSellBonus)

    -- Run-level: selling an equipped crystallized hull card during
    -- settlement credits the crystallized refund, not the shared +6.
    local crystalCard = {
        id = "hull_crystal_sell_fixture", name = "Crystal", nameKo = "결정", icon = "◆",
        rarity = "rare", tags = { "economy" }, editions = { "crystallized" },
        edition = "crystallized",
        effects = { { type = "sampleSellValue", value = 5 } },
    }
    local shopRun = expedition.new({ money = 0 })
    assert(expedition.equipGear(shopRun, "hull", crystalCard))
    shopRun.phase = "settlement"
    local ok, value = expedition.sellGear(shopRun, "hull", "hull_crystal_sell_fixture")
    assert(ok, "selling an equipped crystallized card during settlement must succeed")
    assert(value == crystalSell,
        "sellGear must credit the crystallized sell premium, got " .. tostring(value))
    assert(shopRun.money == crystalSell,
        "run.money must increase by the crystallized sell value, got " .. tostring(shopRun.money))
    assert(#shopRun.equippedGear == 0, "the sold crystallized card must leave the hull slot")

    -- Engine-slot crystallized sale must not touch the hull list (item 10).
    local engineCard = {
        id = "engine_crystal_sell_fixture", name = "ECrystal", nameKo = "엔진결정", icon = "◆",
        rarity = "rare", tags = { "economy" }, editions = { "crystallized" },
        edition = "crystallized",
        effects = { { type = "boostCharge", value = 1 } },
    }
    local engineRun = expedition.new({ money = 0 })
    local hullKeep = {
        id = "hull_keep_fixture", name = "Keep", nameKo = "유지", icon = "*",
        rarity = "common", tags = { "defense" }, editions = {},
        effects = { { type = "hullDurability", value = 1 } },
    }
    assert(expedition.equipGear(engineRun, "hull", hullKeep))
    assert(expedition.equipGear(engineRun, "engine", engineCard))
    engineRun.phase = "settlement"
    local engineOk, engineValue = expedition.sellGear(engineRun, "engine", "engine_crystal_sell_fixture")
    assert(engineOk and engineValue == crystalSell)
    assert(#engineRun.equippedEngineParts == 0)
    assert(#engineRun.equippedGear == 1, "selling a crystallized engine card must not affect the hull slot list")
end

return M