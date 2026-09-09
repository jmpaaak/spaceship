local expedition = require("game.expedition")
local gear = require("game.gear")
local playHud = require("game.scenes.play_hud")

local M = {}

function M.run()
    print("  [INBOX 77(2)] anytime equipped-gear sale tests...")
    local part = {
        id = "flight_sale_fixture",
        name = "Flight Sale Fixture",
        rarity = "common",
        effects = { { type = "hullDurability", value = 5 } },
    }
    local run = expedition.new({ money = 10 })
    assert(expedition.equipGear(run, "hull", part))
    run.phase = "ascending"
    run.durability = run.maxDurability

    local ok, value = expedition.sellGear(run, "hull", part.id)
    assert(ok and value == gear.sellValue(part),
        "equipped gear must be sellable during flight at its displayed sell value")
    assert(run.money == 10 + value, "sale must immediately credit cash")
    assert(#run.equippedGear == 0 and #run.gearLoadout.hull == 0,
        "sale must immediately free the equipped slot")
    assert(run.maxDurability == run.baseDurability and run.durability <= run.maxDurability,
        "sale must immediately refresh and clamp ship stats")

    local duplicateOk = expedition.sellGear(run, "hull", part.id)
    assert(not duplicateOk and run.money == 10 + value,
        "a duplicate sale tap must not pay twice")

    local sellRect = playHud.gearPopupSellRect({
        gearPopup = { part = part, slotRect = { x = 10, y = 10, w = 48, h = 48 } },
    })
    assert(sellRect and sellRect.h >= 44 and sellRect.w >= 44,
        "tooltip sale touch target must be at least 44px in both dimensions")

    local hudSource = love.filesystem.read("game/scenes/play_hud.lua") or ""
    local inputSource = love.filesystem.read("game/scenes/play_input.lua") or ""
    assert(hudSource:find("gearPopupSellRect", 1, true)
            and hudSource:find("sellGearPopup", 1, true),
        "equipped gear tooltip must expose a sale button and action")
    assert(inputSource:find("self:gearPopupSellRect%(%)")
            and inputSource:find("self:sellGearPopup%(%)"),
        "tooltip touch input must hit and invoke the sale action")

    print("  INBOX-77(2) anytime equipped-gear sale OK")
end

return M