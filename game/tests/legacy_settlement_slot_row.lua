local M = {}

function M.run()
    local PlayScene = require("game.scenes.play")
    local rows = PlayScene.settlementTouchRows
    assert(#rows == 5, "settlement must have 5 dedicated rows (upgrades, ship, gear, slot, relaunch)")
    assert(rows[1].columns and rows[1].columns[1].key == "hull")
    assert(rows[1].columns[2].key == "steering")
    assert(rows[2].columns and rows[2].columns[1].key == "yield")
    assert(rows[2].columns[2].key == "ship")
    assert(rows[3].key == "gear", "row 3 must be the dedicated gear-offer band")
    assert(rows[4].key == "slot", "row 4 must be the dedicated slot band")
    assert(rows[5].key == "relaunch", "row 5 must be the dedicated relaunch band")

    for i = 1, #rows - 1 do
        assert(rows[i].bottom <= rows[i + 1].top,
            "settlement row " .. i .. " must not overlap the next row")
        assert(rows[i].bottom == rows[i + 1].top,
            "settlement rows must be contiguous without a shared band")
    end

    local layout = PlayScene.settlementShopLayout()
    assert(type(layout) == "table", "settlementShopLayout must export draw bands")
    assert(layout.slot.top >= rows[4].top and layout.slot.bottom <= rows[4].bottom,
        "slot draw band must stay inside the dedicated slot touch row")
    assert(layout.slotResult.top >= rows[4].top and layout.slotResult.bottom <= rows[4].bottom,
        "slot result panel must stay inside the dedicated slot touch row")
    assert(layout.gear.top >= rows[3].top and layout.gear.bottom <= rows[3].bottom,
        "gear offer must stay inside its own row, not the slot band")
    assert(layout.scout.top >= rows[2].top and layout.scout.bottom <= rows[2].bottom,
        "scout tradeoff must stay inside the ship/yield row, not the slot band")
    assert(layout.relaunch.top >= rows[5].top and layout.relaunch.bottom <= rows[5].bottom,
        "relaunch prompt must stay inside its own row")
    assert(layout.slotResult.bottom <= layout.relaunch.top,
        "slot result panel must not cover relaunch text")
    assert(layout.gear.bottom <= layout.slot.top,
        "gear offer must not share the slot band")
    assert(layout.scout.bottom <= layout.gear.top,
        "scout tradeoff must not spill into the gear/slot bands")

    local lastRow = rows[#rows]
    assert(lastRow.bottom <= PlayScene.settlementPanelTop + PlayScene.settlementPanelHeight,
        "five settlement rows must still fit inside the shop panel")
end

return M
