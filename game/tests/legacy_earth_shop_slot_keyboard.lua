local PlayScene = require("game.scenes.play")

local M = {}

function M.run()
    -- Item 15(b) regression: Earth shop slot machine ("l" key during
    -- settlement). The keypressed handler builds a plain-array `rolls`
    -- table but earthSlotSpin expects `rolls.reels`. This caused
    -- earthSlotSpin to always fall back to {0,0,0} reelRolls (always
    -- MONEY-MONEY-MONEY). Verify:
    --   (1) pressing "l" during settlement sets earthShopSlotResult
    --   (2) a winning result adds money and sets message
    --   (3) pressing "l" outside settlement is a no-op on earthShopSlotResult
    --   (4) the rolls format passed to earthSlotSpin is {reels={...}}
    --       (detectable by monkey-patching earthSlotSpin and inspecting args)
    local expedition = require("game.expedition")

    -- (1+2) Win path: force a known-winning spin by monkey-patching
    -- earthSlotSpin to return a deterministic STAR triple result.
    local originalSpin = expedition.earthSlotSpin
    local capturedRolls = nil
    expedition.earthSlotSpin = function(run, galaxyId, rolls)
        capturedRolls = rolls
        return {
            symbols = { "MONEY", "MONEY", "MONEY" },
            reward = 100,
            totalWeight = 10,
            effectiveStarWeight = 3,
            rewardProfile = "solar",
        }
    end

    local slotScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    slotScene.expedition.phase = "settlement"
    slotScene.expedition.money = 20
    local moneyBefore = slotScene.expedition.money
    local spinCost = expedition.slotSpinCost or 10

    slotScene:keypressed("l")
    slotScene:keypressed("l"); while slotScene.slotState and not slotScene.slotState.reels[1].stopped do slotScene:update(0.1) end
    slotScene:keypressed("l"); while slotScene.slotState and not slotScene.slotState.reels[2].stopped do slotScene:update(0.1) end
    slotScene:keypressed("l"); while slotScene.slotState and slotScene.slotState.spinning do slotScene:update(0.1) end

    expedition.earthSlotSpin = originalSpin  -- restore

    assert(slotScene.earthShopSlotResult ~= nil,
        "item 15(b): keypressed('l') during settlement must set earthShopSlotResult")
    assert(slotScene.earthShopSlotResult.symbols[1] == "MONEY",
        "item 15(b): earthShopSlotResult.symbols must reflect earthSlotSpin return value")
    assert(slotScene.expedition.money == moneyBefore - spinCost + 100,
        "item 15(b): winning spin must be money - cost + reward, expected "
        .. (moneyBefore - spinCost + 100) .. " got " .. slotScene.expedition.money)
    assert(slotScene.slotResultMessage ~= nil and slotScene.slotResultMessage:find("%+%$100"),
        "item 15(b): slotResultMessage must reference the +$100 reward, got: " .. tostring(slotScene.slotResultMessage))

    -- (4) The rolls table passed to earthSlotSpin must have a .reels field
    -- (not a plain array). Plain arrays make rolls.reels nil and cause the
    -- function to silently fall back to {0,0,0} (always MONEY-MONEY-MONEY).
    assert(capturedRolls ~= nil,
        "item 15(b): earthSlotSpin must be called with a rolls argument")
    assert(type(capturedRolls) == "table",
        "item 15(b): rolls argument must be a table")
    assert(capturedRolls.reels ~= nil,
        "item 15(b): rolls.reels must not be nil — plain array {1,2,3} silently falls back to {0,0,0}")
    assert(#capturedRolls.reels == 3,
        "item 15(b): rolls.reels must have exactly 3 entries (one per slot reel)")

    -- (3) Outside settlement, "l" must not set earthShopSlotResult.
    local spinCapture2 = nil
    local originalSpin2 = expedition.earthSlotSpin
    expedition.earthSlotSpin = function(...) spinCapture2 = true return originalSpin2(...) end
    local nonSettleScene = PlayScene.new({
        bestAltitudeStore = { load = function() return 0 end, save = function() end },
    })
    nonSettleScene.expedition.phase = "ascending"
    nonSettleScene:keypressed("l")
    expedition.earthSlotSpin = originalSpin2
    assert(nonSettleScene.earthShopSlotResult == nil,
        "item 15(b): 'l' during ascending must NOT set earthShopSlotResult")
    assert(spinCapture2 == nil,
        "item 15(b): earthSlotSpin must not be called outside settlement phase")
end

return M
