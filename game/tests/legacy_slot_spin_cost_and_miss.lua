local M = {}

-- INBOX (15)(b): spin cost + miss pays 0. Miss used to pay +$5 so every
-- spin was free money. Cost is 10 (editor-tunable later); miss reward is 0.
function M.run()
    local expedition = require("game.expedition")
    local PlayScene = require("game.scenes.play")

    assert(expedition.slotSpinCost == 10,
        "INBOX 15(b): default slot spin cost must be 10, got: "
            .. tostring(expedition.slotSpinCost))
    assert(expedition.slotReward({ "MONEY", "PART", "SPEED" }) == 0,
        "INBOX 15(b): miss must pay 0, not +$5")
    assert(expedition.slotReward({ "MONEY", "MONEY", "PART" }) == 3,
        "INBOX 52(b): pair payout is 3")
    assert(expedition.slotReward({ "PART", "PART", "PART" }) == 10,
        "INBOX 52(b): triple payout is 10")
    assert(expedition.slotReward({ "MONEY", "MONEY", "MONEY" }) == 10,
        "INBOX 52(b): triple payout is 10")

    local run = expedition.new()
    local solarWeights = expedition.earthSlotWeights(nil)
    local moneyRoll = 0.5
    local partRoll = solarWeights.MONEY + 0.5
    local starRoll = solarWeights.MONEY + solarWeights.PART + 0.5
    local missSpin = expedition.earthSlotSpin(run, nil, {
        reels = { moneyRoll, partRoll, starRoll },
    })
    assert(missSpin.symbols[1] == "MONEY" and missSpin.symbols[2] == "PART"
        and missSpin.symbols[3] == "SPEED",
        "MONEY-PART-SPEED rolls must be a true miss, got: "
            .. table.concat(missSpin.symbols, "-"))
    assert(missSpin.reward == 0,
        "INBOX 15(b): earthSlotSpin miss reward must be 0, got: "
            .. tostring(missSpin.reward))

    local originalSpin = expedition.earthSlotSpin
    expedition.earthSlotSpin = function()
        return {
            symbols = { "MONEY", "PART", "SPEED" },
            reward = 0,
            totalWeight = 10,
            effectiveStarWeight = 1,
            rewardProfile = "solar",
        }
    end
    local missScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    missScene.expedition.phase = "settlement"
    missScene.expedition.money = 20
    missScene:keypressed("l")
    missScene:keypressed("l"); while missScene.slotState and not missScene.slotState.reels[1].stopped do missScene:update(0.1) end
    missScene:keypressed("l"); while missScene.slotState and not missScene.slotState.reels[2].stopped do missScene:update(0.1) end
    missScene:keypressed("l"); while missScene.slotState and missScene.slotState.spinning do missScene:update(0.1) end
    assert(missScene.expedition.money == 10,
        "INBOX 15(b): miss must charge spin cost 10 (20-10=10), got: "
            .. tostring(missScene.expedition.money))

    local brokeScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    brokeScene.expedition.phase = "settlement"
    brokeScene.expedition.money = 5
    brokeScene.earthShopSlotResult = nil
    brokeScene:keypressed("l")
    assert(brokeScene.earthShopSlotResult == nil,
        "INBOX 15(b): spinning with less than cost must not consume a spin")
    assert(brokeScene.expedition.money == 5,
        "INBOX 15(b): broke spin must not change money")

    expedition.earthSlotSpin = function()
        return {
            symbols = { "MONEY", "MONEY", "MONEY" },
            reward = 100,
            totalWeight = 10,
            effectiveStarWeight = 3,
            rewardProfile = "solar",
        }
    end
    local winScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    winScene.expedition.phase = "settlement"
    winScene.expedition.money = 20
    winScene:keypressed("l")
    winScene:keypressed("l"); while winScene.slotState and not winScene.slotState.reels[1].stopped do winScene:update(0.1) end
    winScene:keypressed("l"); while winScene.slotState and not winScene.slotState.reels[2].stopped do winScene:update(0.1) end
    winScene:keypressed("l"); while winScene.slotState and winScene.slotState.spinning do winScene:update(0.1) end
    expedition.earthSlotSpin = originalSpin
    assert(winScene.expedition.money == 110,
        "INBOX 15(b): win must be money - cost + reward (20-10+100=85), got: "
            .. tostring(winScene.expedition.money))
end

return M
