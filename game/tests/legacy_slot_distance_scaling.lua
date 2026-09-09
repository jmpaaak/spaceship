local M = {}

-- INBOX 61(25): slot cost/rewards scale with galaxy distance
-- slotTier = 1 + floor(galaxyDistance / galaxyCellSize)
-- spinCost = $10 * slotTier; SPEED/DURABILITY/HARVEST scale with tier
function M.run()
    local exp = require("game.expedition")
    local worldMod = require("game.world")
    local run = exp.new()

    -- (a) Earth / nil galaxy: tier 1, spinCost $10, SPEED pair=5 triple=20
    assert(exp.slotTier(run, nil) == 1,
        "INBOX 61(25): Earth/nil slotTier must be 1")
    assert(exp.slotSpinCostFor(run, nil) == 10,
        "INBOX 61(25): Earth spinCost must be $10, got " .. tostring(exp.slotSpinCostFor(run, nil)))
    local solarWeights = exp.earthSlotWeights(nil)
    local speedStart = solarWeights.MONEY + solarWeights.PART
    local speedRoll = speedStart + 0.5
    local solarPair = exp.earthSlotSpin(run, nil, { reels = { speedRoll, speedRoll, 0 } })
    assert(solarPair.rewardType == "speed",
        "INBOX 61(25): solar SPEED pair type, got " .. tostring(solarPair.rewardType))
    assert(solarPair.rewardValue == 5,
        "INBOX 61(25): solar SPEED pair must be 5, got " .. tostring(solarPair.rewardValue))
    assert(solarPair.spinCost == 10,
        "INBOX 61(25): solar spin must expose spinCost=10, got " .. tostring(solarPair.spinCost))
    assert(solarPair.slotTier == 1,
        "INBOX 61(25): solar spin must expose slotTier=1")
    local solarTriple = exp.earthSlotSpin(run, nil, { reels = { speedRoll, speedRoll, speedRoll } })
    assert(solarTriple.rewardValue == 20,
        "INBOX 61(25): solar SPEED triple must be 20, got " .. tostring(solarTriple.rewardValue))

    -- (b) Galaxy one cell away: tier 2
    -- galaxy id format "galaxy:gx:gy"; distance = hypot(gx,gy)*cellSize
    -- floor(cellSize / cellSize) + 1 = 2
    local farId = "galaxy:1:0"
    local farX = 1 * worldMod.galaxyCellSize
    local farY = 0
    local dist = math.sqrt(farX * farX + farY * farY)
    local expectedTier = 1 + math.floor(dist / worldMod.galaxyCellSize)
    assert(expectedTier == 2, "INBOX 61(25): fixture galaxy:1:0 must be tier 2, got " .. expectedTier)
    assert(exp.slotTier(run, farId) == 2,
        "INBOX 61(25): galaxy:1:0 slotTier must be 2, got " .. tostring(exp.slotTier(run, farId)))
    assert(exp.slotSpinCostFor(run, farId) == 20,
        "INBOX 61(25): galaxy:1:0 spinCost must be $20, got " .. tostring(exp.slotSpinCostFor(run, farId)))

    local farWeights = exp.earthSlotWeights(farId)
    local farSpeedStart = farWeights.MONEY + farWeights.PART
    local farSpeedRoll = farSpeedStart + 0.5
    local farPair = exp.earthSlotSpin(run, farId, { reels = { farSpeedRoll, farSpeedRoll, 0 } })
    assert(farPair.rewardType == "speed",
        "INBOX 61(25): far SPEED pair type, got " .. tostring(farPair.rewardType))
    assert(farPair.rewardValue == 10,
        "INBOX 61(25): far SPEED pair must be 5*tier=10, got " .. tostring(farPair.rewardValue))
    assert(farPair.spinCost == 20,
        "INBOX 61(25): far spinCost must be 20, got " .. tostring(farPair.spinCost))
    assert(farPair.slotTier == 2,
        "INBOX 61(25): far slotTier must be 2")
    local farTriple = exp.earthSlotSpin(run, farId, { reels = { farSpeedRoll, farSpeedRoll, farSpeedRoll } })
    assert(farTriple.rewardValue == 40,
        "INBOX 61(25): far SPEED triple must be 20*tier=40, got " .. tostring(farTriple.rewardValue))

    -- (c) DURABILITY and HARVEST also scale
    local durStart = farWeights.MONEY + farWeights.PART + farWeights.SPEED
    local durRoll = durStart + 0.5
    local farDurPair = exp.earthSlotSpin(run, farId, { reels = { durRoll, durRoll, 0 } })
    assert(farDurPair.rewardType == "durability",
        "INBOX 61(25): far DURABILITY pair type")
    assert(farDurPair.rewardValue == 6,
        "INBOX 61(25): far DURABILITY pair must be 3*tier=6, got " .. tostring(farDurPair.rewardValue))
    local farDurTriple = exp.earthSlotSpin(run, farId, { reels = { durRoll, durRoll, durRoll } })
    assert(farDurTriple.rewardValue == 20,
        "INBOX 61(25): far DURABILITY triple must be 10*tier=20, got " .. tostring(farDurTriple.rewardValue))

    local harvTotal = farWeights.MONEY + farWeights.PART + farWeights.SPEED
        + farWeights.DURABILITY + farWeights.HARVEST
    local harvRoll = harvTotal - 0.5
    local farHarvPair = exp.earthSlotSpin(run, farId, { reels = { harvRoll, harvRoll, 0 } })
    assert(farHarvPair.rewardType == "harvest",
        "INBOX 61(25): far HARVEST pair type")
    assert(math.abs(farHarvPair.rewardValue - 0.20) < 1e-6,
        "INBOX 61(25): far HARVEST pair must be 0.10*tier=0.20, got " .. tostring(farHarvPair.rewardValue))
    local farHarvTriple = exp.earthSlotSpin(run, farId, { reels = { harvRoll, harvRoll, harvRoll } })
    assert(math.abs(farHarvTriple.rewardValue - 1.00) < 1e-6,
        "INBOX 61(25): far HARVEST triple must be 0.50*tier=1.00, got " .. tostring(farHarvTriple.rewardValue))

    -- (d) MONEY already scales with spinCost; pair multiplier 3 → $60 at tier 2
    local moneyRoll = 0.5
    local farMoneyPair = exp.earthSlotSpin(run, farId, { reels = { moneyRoll, moneyRoll, farSpeedRoll } })
    assert(farMoneyPair.rewardType == "money",
        "INBOX 61(25): far MONEY pair type")
    assert(farMoneyPair.reward == 60,
        "INBOX 61(25): far MONEY pair must be spinCost*3=60, got " .. tostring(farMoneyPair.reward))

    -- (e) run.lastVisitedGalaxyId used when galaxyId omitted from slotTier helpers
    run.lastVisitedGalaxyId = farId
    assert(exp.slotTier(run) == 2,
        "INBOX 61(25): slotTier(run) must read lastVisitedGalaxyId")
    assert(exp.slotSpinCostFor(run) == 20,
        "INBOX 61(25): slotSpinCostFor(run) must read lastVisitedGalaxyId")

    print("  INBOX-61(25) slot cost/rewards scale with galaxy distance OK")
end

return M