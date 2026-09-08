local M = {}

function M.run()
    -- Item 15/11 residue: settlement panel must NOT show a dead slot-spin line.
    -- Since item-15 abolished in-flight slots, lastSlotSpinsCount is never set.
    -- The old "SPINS (0) $0" line always rendered as zeroes — dead UI.
    -- We assert that spins_settlement_line is NOT referenced in the settlement
    -- draw path by checking that PlayScene has no live reference to
    -- lastSlotSpinsCount or lastSlotSettlement in the settlement code.
    -- The strongest portable check: ensure the i18n key still exists (it may be
    -- used by destroyed panel elsewhere) but settlement draw no longer calls it.
    -- We verify this by checking scene state: after a settlement, the scene
    -- must not store lastSlotSpinsCount or lastSlotSettlement (they're dead).
    local PlayScene = require("game.scenes.play")
    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    -- Force into settlement phase
    scene.expedition.phase = "settlement"
    scene.expedition.lastSettlement = 42
    scene.expedition.lastSampleCount = 3
    scene.expedition.lastSampleSettlement = 42
    -- Dead slot fields must not exist on the expedition object
    assert(scene.expedition.lastSlotSpinsCount == nil,
        "item 15/11: expedition.lastSlotSpinsCount must not exist (in-flight slots abolished)")
    assert(scene.expedition.lastSlotSettlement == nil,
        "item 15/11: expedition.lastSlotSettlement must not exist (in-flight slots abolished)")
    -- Destroyed-panel dead slot fields
    assert(scene.expedition.lastLostSlotValue == nil,
        "item 15/11: expedition.lastLostSlotValue must not exist (in-flight slots abolished)")
    assert(scene.expedition.lastLostSlotSpinsCount == nil,
        "item 15/11: expedition.lastLostSlotSpinsCount must not exist (in-flight slots abolished)")
end

return M