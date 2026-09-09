local expedition = require("game.expedition")
local gear = require("game.gear")

local M = {}

-- Item 9(c): "카드 획득... 과 교체가 잦아지는 루프를 설계한다." With a fixed
-- 6/3-slot loadout, sellGear is the swap-loop's release valve -- it frees
-- an equipped slot and refunds money in one atomic action, scaled by
-- gear.raritySellValue/editionSellBonus, including in flight.
function M.run()
    -- gear.sellValue: rarity scales the refund, and an edition adds a flat
    -- premium on top of the base rarity value.
    assert(gear.sellValue({ rarity = "common" }) == 4)
    assert(gear.sellValue({ rarity = "uncommon" }) == 9)
    assert(gear.sellValue({ rarity = "rare" }) == 18)
    assert(gear.sellValue({ rarity = "legendary" }) == 40)
    assert(gear.sellValue({ rarity = "legendary", edition = "irradiated" }) == 46,
        "an edition-carrying legendary card must sell for base(40) + editionSellBonus(6)")
    -- Unknown/missing rarity falls back to the common tier instead of
    -- erroring (defensive, not schema validation).
    assert(gear.sellValue({}) == 4)

    -- INBOX 77(2): equipped cards can be sold during flight too.
    local flightRun = expedition.new({ money = 50 })
    local commonCard = {
        id = "hull_scrap_plate", name = "Scrap Plate", nameKo = "고철 장갑판", icon = "▭",
        rarity = "common", tags = { "defense" }, editions = {},
        effects = { { type = "hullDurability", value = 1 } },
    }
    assert(expedition.equipGear(flightRun, "hull", commonCard))
    flightRun.phase = "ascending"
    local flightOk, flightValue = expedition.sellGear(flightRun, "hull", "hull_scrap_plate")
    assert(flightOk and flightValue == 4, "selling equipped gear must work during flight")
    assert(flightRun.money == 54, "a flight sale must immediately credit money")
    assert(#flightRun.equippedGear == 0, "a flight sale must free the equipped slot")

    -- During settlement, selling an equipped hull card must remove it AND
    -- credit exactly its sell value.
    local shopRun = expedition.new({ money = 20 })
    assert(expedition.equipGear(shopRun, "hull", commonCard))
    shopRun.phase = "settlement"
    local ok, value = expedition.sellGear(shopRun, "hull", "hull_scrap_plate")
    assert(ok, "selling an equipped hull card during settlement must succeed")
    assert(value == 4, "returned sell value must match gear.sellValue: got " .. tostring(value))
    assert(shopRun.money == 24, "money must increase by exactly the sell value: got " .. tostring(shopRun.money))
    assert(#shopRun.equippedGear == 0, "the sold card must be removed from the hull slot list")

    -- Selling an engine-slot card must not touch the hull list, matching
    -- item 10's slot-independence guarantee.
    local engineShopRun = expedition.new({ money = 0 })
    local rareEngineCard = {
        id = "engine_test_thruster", name = "Test Thruster", nameKo = "테스트 추진기", icon = "◬",
        rarity = "rare", tags = { "speed" }, editions = {},
        effects = { { type = "speed", value = 5 } },
    }
    assert(expedition.equipGear(engineShopRun, "hull", commonCard))
    assert(expedition.equipGear(engineShopRun, "engine", rareEngineCard))
    engineShopRun.phase = "settlement"
    local engineOk, engineValue = expedition.sellGear(engineShopRun, "engine", "engine_test_thruster")
    assert(engineOk and engineValue == 18)
    assert(#engineShopRun.equippedEngineParts == 0, "the sold engine card must be removed from the engine slot list")
    assert(#engineShopRun.equippedGear == 1, "selling an engine card must not affect the hull slot list")

    -- Selling an unequipped/unknown id must fail cleanly (no money change).
    local missRun = expedition.new({ money = 7 })
    missRun.phase = "settlement"
    local missOk, missErr = expedition.sellGear(missRun, "hull", "hull_does_not_exist")
    assert(not missOk and missErr)
    assert(missRun.money == 7)
end

return M