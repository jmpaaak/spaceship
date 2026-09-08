local M = {}

-- INBOX 61(2): earthSlotSpin PART rarity gate unit test at the expedition
-- level (not mocked). 2-match must only produce common/uncommon parts,
-- 3-match must only produce rare/legendary parts. Pool must include both
-- hull AND engine parts.
function M.run()
    local expedition = require("game.expedition")
    local gearMod = require("game.gear")
    local run = expedition.new()

    local weights = expedition.earthSlotWeights(nil)
    -- Compute cumulative offset to force PART symbol on all reels.
    local partStart = weights.MONEY  -- PART is the 2nd symbol
    local partRoll = partStart + 0.5  -- middle of PART band

    -- (a) 2-match: force two PART + one MONEY → matchCount=2, matchSymbol=PART.
    -- The returned rewardPart must be common or uncommon, never rare/legendary.
    local spin2 = expedition.earthSlotSpin(run, nil, {
        reels = { partRoll, partRoll, 0.5 },  -- PART, PART, MONEY
        partRarity = 0,
        partPick = 0,
        partEditionChance = 1,
        partEditionPick = 0,
    })
    assert(spin2.matchCount == 2, "expected 2-match, got " .. tostring(spin2.matchCount))
    assert(spin2.matchSymbol == "PART", "expected PART match symbol")
    assert(spin2.rewardType == "part", "expected part reward type")
    if spin2.rewardPart then
        local r = spin2.rewardPart.rarity
        assert(r == "common" or r == "uncommon",
            "INBOX 61(2): 2-match must yield common/uncommon, got " .. tostring(r))
    end

    -- (b) 3-match: force three PART → matchCount=3, matchSymbol=PART.
    -- The returned rewardPart must be rare or legendary.
    local spin3 = expedition.earthSlotSpin(run, nil, {
        reels = { partRoll, partRoll, partRoll },  -- PART, PART, PART
        partRarity = 0,
        partPick = 0,
        partEditionChance = 1,
        partEditionPick = 0,
    })
    assert(spin3.matchCount == 3, "expected 3-match, got " .. tostring(spin3.matchCount))
    assert(spin3.matchSymbol == "PART", "expected PART match symbol")
    assert(spin3.rewardType == "part", "expected part reward type")
    if spin3.rewardPart then
        local r = spin3.rewardPart.rarity
        assert(r == "rare" or r == "legendary",
            "INBOX 61(2): 3-match must yield rare/legendary, got " .. tostring(r))
    end

    -- (c) Verify the PART pool includes engine parts, not just hull.
    local enginePool = gearMod.loadEngineParts() or {}
    assert(#enginePool > 0, "engine parts pool must be non-empty for this test")
    -- Find a common engine part to test with
    local commonEngine = nil
    for _, p in ipairs(enginePool) do
        if p.rarity == "common" then commonEngine = p; break end
    end
    -- If no common engine part exists, find any engine part
    if not commonEngine then
        for _, p in ipairs(enginePool) do
            commonEngine = p; break
        end
    end
    assert(commonEngine, "need at least one engine part for INBOX 61(2) test")

    -- (d) Verify earthSlotSpin's PART pool actually includes engine parts:
    -- Force a 2-match PART spin with pick=0 and a pool where the first
    -- common/uncommon card is an engine part (by checking the returned id
    -- against engine pool ids).
    local hullPool = gearMod.loadHullParts() or {}
    local hullIds = {}
    for _, p in ipairs(hullPool) do hullIds[p.id] = true end
    local engineIds = {}
    for _, p in ipairs(enginePool) do engineIds[p.id] = true end
    -- Run many picks to try to find an engine part in the result
    local foundEngine = false
    for pickIdx = 0, 99 do
        local spinE = expedition.earthSlotSpin(run, nil, {
            reels = { partRoll, partRoll, 0.5 },
            partRarity = 0,
            partPick = pickIdx / 100,
            partEditionChance = 1,
            partEditionPick = 0,
        })
        if spinE.rewardPart and engineIds[spinE.rewardPart.id] then
            foundEngine = true
            break
        end
    end
    assert(foundEngine,
        "INBOX 61(2): earthSlotSpin PART pool must include engine parts")

    print("  INBOX-61(2) earthSlotSpin PART rarity gate OK")
end

return M