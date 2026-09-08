local M = {}

function M.run()
    -- Item 15(c) UI gap: play.lua's settlement draw() gated the ODDS badge
    -- on `earthShopSlotResult.rewardProfile.name`, but earthSlotSpin returns
    -- rewardProfile as a plain string ("solar"/"fringe"/"void"), not a table.
    -- The `.name` lookup was always nil so the badge never rendered.
    -- PlayScene.earthSlotProfileLabel is the pure helper draw() now uses.
    local PlayScene = require("game.scenes.play")
    assert(type(PlayScene.earthSlotProfileLabel) == "function",
        "item 15(c): PlayScene.earthSlotProfileLabel must exist")
    -- SOLAR ODDS label removed (user 2026-09-07)
    assert(PlayScene.earthSlotProfileLabel("solar") == nil)
    assert(PlayScene.earthSlotProfileLabel(nil) == nil)
    assert(PlayScene.earthSlotProfileLabel("") == nil)

    -- Settlement "l" spin stores the string rewardProfile from earthSlotSpin;
    -- the helper must produce a badge from that stored result.
    local expedition = require("game.expedition")
    local originalSpin = expedition.earthSlotSpin
    expedition.earthSlotSpin = function()
        return {
            symbols = { "MONEY", "MONEY", "MONEY" },
            reward = 100,
            totalWeight = 10,
            effectiveStarWeight = 3,
            rewardProfile = "void",
        }
    end
    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    scene.expedition.phase = "settlement"
    scene.expedition.money = 20
    scene:keypressed("l")
    scene:keypressed("l"); while scene.slotState and not scene.slotState.reels[1].stopped do scene:update(0.1) end
    scene:keypressed("l"); while scene.slotState and not scene.slotState.reels[2].stopped do scene:update(0.1) end
    scene:keypressed("l"); while scene.slotState and scene.slotState.spinning do scene:update(0.1) end
    expedition.earthSlotSpin = originalSpin
    assert(scene.earthShopSlotResult ~= nil,
        "item 15(c): settlement spin must store earthShopSlotResult")
    assert(type(scene.earthShopSlotResult.rewardProfile) == "string",
        "item 15(c): earthSlotSpin rewardProfile is a string, not a table with .name")
    local badge = PlayScene.earthSlotProfileLabel(scene.earthShopSlotResult.rewardProfile)
    assert(badge == nil,
        "item 15(c): ODDS label removed, badge must be nil, got: "
        .. tostring(badge))
end

return M