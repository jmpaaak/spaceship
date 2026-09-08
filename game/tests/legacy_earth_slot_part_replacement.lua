local M = {}

function M.run()
    local PlayScene = require("game.scenes.play")
    local gearMod = require("game.gear")
    local expedition = require("game.expedition")
    local scene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    scene.expedition.phase = "settlement"
    scene.expedition.money = 100

    local originalSpin = expedition.earthSlotSpin

    -- (1) Match 2 rarity gate
    expedition.earthSlotSpin = function()
        return {
            symbols = {"PART", "PART", "MONEY"},
            reward = 0,
            rewardType = "part",
            rewardValue = 0,
            rewardPart = { id = "test_common", name = "Test", rarity = "common", effects = {} },
            matchCount = 2,
            matchSymbol = "PART"
        }
    end
    scene:keypressed("l")
    while scene.slotState and scene.slotState.spinning do
        if scene.slotState.stopNext then scene.slotState:stopNext() end
        scene:update(0.1)
    end
    assert(scene.gearPopup ~= nil, "part should be equipped")

    -- (2) Refund on duplicate
    scene.expedition.money = 100
    expedition.earthSlotSpin = function()
        return {
            symbols = {"PART", "PART", "MONEY"},
            rewardType = "part",
            rewardPart = { id = "test_common", name = "Test", rarity = "common", effects = {} },
        }
    end
    scene:keypressed("l")
    while scene.slotState and scene.slotState.spinning do
        if scene.slotState.stopNext then scene.slotState:stopNext() end
        scene:update(0.1)
    end
    assert(scene.expedition.money == 100, "money should be refunded ($10 cost + $10 refund)")

    -- (3) Replacement UI
    -- Fill the slots
    scene.expedition.gearLoadout = { hull = {}, engine = {} }
    scene.expedition.equippedGear = scene.expedition.gearLoadout.hull
    scene.expedition.equippedEngineParts = scene.expedition.gearLoadout.engine
    for i=1, 6 do scene.expedition.gearLoadout.hull[i] = { id = "fill"..i, rarity = "common", effects = {} } end
    scene.gearPopup = nil

    expedition.earthSlotSpin = function()
        return {
            symbols = {"PART", "PART", "MONEY"},
            rewardType = "part",
            rewardPart = { id = "test_new", name = "New Part", rarity = "common", effects = {} },
        }
    end
    scene:keypressed("l")
    while scene.slotState and scene.slotState.spinning do
        if scene.slotState.stopNext then scene.slotState:stopNext() end
        scene:update(0.1)
    end
    assert(scene.shopModal ~= nil, "shopModal should open for replacement (gearPopup=" .. tostring(scene.gearPopup ~= nil) .. ")")
    assert(scene.shopModal.isReplacement == true, "shopModal must be in replacement mode")

    expedition.earthSlotSpin = originalSpin
end

return M
