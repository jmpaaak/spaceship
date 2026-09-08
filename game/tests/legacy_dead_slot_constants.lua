local PlayScene = require("game.scenes.play")

local M = {}

-- Item 15(a) cleanup: dead in-flight slot constants/fields removed from play.lua.
-- After item-15 abolished the returning-phase slot machine, three dead remnants
-- remained: (1) the module-level constants `slotReelStagger`/`slotSpinDuration`
-- (no longer referenced by any function), (2) `returnControls.slotMinX`/
-- `.slotMaxX` (slot tap zone fields — only leftMaxX/rightMinX are still used),
-- and (3) `slotSpin = nil` in M.new() (dead state field never written or read).
-- This test guards that all three dead artifacts are gone.
function M.run()
    -- (1) Module-level dead constants must not leak onto the table.
    assert(PlayScene.slotReelStagger == nil,
        "item15 cleanup: PlayScene.slotReelStagger must be removed (dead constant)")
    assert(PlayScene.slotSpinDuration == nil,
        "item15 cleanup: PlayScene.slotSpinDuration must be removed (dead constant)")
    -- (2) returnControls dead slot-zone fields.
    local rc = PlayScene.returnControls
    assert(rc ~= nil, "returnControls must still exist")
    assert(rc.slotMinX == nil,
        "item15 cleanup: returnControls.slotMinX must be removed (dead slot zone)")
    assert(rc.slotMaxX == nil,
        "item15 cleanup: returnControls.slotMaxX must be removed (dead slot zone)")
    -- Steering fields still present.
    assert(type(rc.leftMaxX) == "number", "returnControls.leftMaxX must remain")
    assert(type(rc.rightMinX) == "number", "returnControls.rightMinX must remain")
    -- (3) Dead slotSpin state field must not appear in a fresh PlayScene instance.
    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() return false end },
    })
    assert(scene.slotSpin == nil,
        "item15 cleanup: scene.slotSpin must be removed from M.new() (dead field)")
end

return M
