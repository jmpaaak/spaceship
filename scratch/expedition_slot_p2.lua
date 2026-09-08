function M.galaxyDistance(run, galaxyId)
    local id = galaxyId or (run and run.lastVisitedGalaxyId)
    if id and not M.homeGalaxies[id] then
        local gx, gy = id:match("^galaxy:(-?%d+):(-?%d+)$")
        if gx then
            gx, gy = tonumber(gx), tonumber(gy)
            local worldMod = require("game.world")
            local cell = worldMod.galaxyCellSize or 4608
            return math.sqrt((gx * cell) ^ 2 + (gy * cell) ^ 2)
        end
    end
    local hx = run and run.lastHubX
    local hy = run and run.lastHubY
    if hx and hy then
        return math.sqrt(hx * hx + hy * hy)
    end
    return 0
end
function M.slotTier(run, galaxyId)
    local worldMod = require("game.world")
    local cell = worldMod.galaxyCellSize or 4608
    local dist = M.galaxyDistance(run, galaxyId)
    return 1 + math.floor(dist / cell)
end
function M.slotSpinCostFor(run, galaxyId)
    local base = M.slotSpinCost or 10
    return base * M.slotTier(run, galaxyId)
end
function M.galaxySlotOddsProfile(galaxyId)
    if not galaxyId or M.homeGalaxies[galaxyId] then
        return "solar"
    end
    local h = 0
    for i = 1, #galaxyId do
        h = (h * 31 + string.byte(galaxyId, i)) % 2147483647
    end
    local bucket = h % 3
    if bucket == 1 then return "void" end
    return "fringe"
end
function M.earthSlotWeights(galaxyId)
    local profile = M.galaxySlotOddsProfile(galaxyId)
    local base = M.earthSlotOddsProfiles[profile] or M.earthSlotOddsProfiles["solar"]
    -- Return a copy so callers can safely modify without corrupting the table.
    local copy = {}
    for _, sym in ipairs(slotSymbols) do copy[sym] = base[sym] end
    return copy
end
function M.earthSlotTotalWeight(run, galaxyId)
    local weights = M.earthSlotWeights(galaxyId)
    local luckBonus = gearModule.totalLuckBonus(combinedGearList(run))
    weights.HARVEST = weights.HARVEST * (1 + luckBonus)
    local total = 0
    for _, sym in ipairs(slotSymbols) do total = total + weights[sym] end
    return math.floor(total)
end
function M.earthSlotSpin(run, galaxyId, rolls)
    local profile = M.galaxySlotOddsProfile(galaxyId)
    local weights = M.earthSlotWeights(galaxyId)
    -- Item 14(C) luck: boost HARVEST weight by the equipped gear's luck total.
    local luckBonus = gearModule.totalLuckBonus(combinedGearList(run))
    local effectiveHarvestWeight = weights.HARVEST * (1 + luckBonus)
    weights.HARVEST = effectiveHarvestWeight
    local total = 0
    for _, sym in ipairs(slotSymbols) do total = total + weights[sym] end
    -- Resolve each reel
    local reelRolls = (rolls and rolls.reels) or { 0, 0, 0 }
    local symbols = {}
    for _, roll in ipairs(reelRolls) do
        local cumulative = 0
        local chosen = slotSymbols[#slotSymbols]
        for _, sym in ipairs(slotSymbols) do
            cumulative = cumulative + weights[sym]
            if roll < cumulative then
                chosen = sym
                break
            end
        end
        symbols[#symbols + 1] = chosen
    end
    -- INBOX (52b): compute matchCount and matchSymbol for effect dispatch.
    local matchCount = 0
    local matchSymbol = nil
    if symbols[1] == symbols[2] and symbols[2] == symbols[3] then
        matchCount = 3
        matchSymbol = symbols[1]
    elseif symbols[1] == symbols[2] then
        matchCount = 2; matchSymbol = symbols[1]
    elseif symbols[1] == symbols[3] then
        matchCount = 2; matchSymbol = symbols[1]
    elseif symbols[2] == symbols[3] then
        matchCount = 2; matchSymbol = symbols[2]
    end
    local rewardMultiplier = earthSlotReward(symbols, profile)
    local tier = M.slotTier(run, galaxyId)
    local spinCost = M.slotSpinCostFor(run, galaxyId)
    -- Symbol-specific rewards instead of money-only
    local rewardType = "money"
    local rewardValue = spinCost * rewardMultiplier
    local rewardPart = nil
    if matchCount >= 2 and matchSymbol then
        if matchSymbol == "SPEED" then
            rewardType = "speed"
            -- INBOX 61(25): SPEED (5*tier)/(20*tier)
            rewardValue = (matchCount == 3 and 20 or 5) * tier
        elseif matchSymbol == "DURABILITY" then
            rewardType = "durability"
            -- INBOX 61(25): DURABILITY (3*tier)/(10*tier)
            rewardValue = (matchCount == 3 and 10 or 3) * tier
        elseif matchSymbol == "HARVEST" then
            rewardType = "harvest"
            -- Shop harvest step is 0.10 (INBOX 51). 2-match = 1 shop buy, 3-match = 5.
            rewardValue = (matchCount == 3 and 0.50 or 0.10) * tier
        elseif matchSymbol == "PART" then
            rewardType = "part"
            rewardValue = 0
            local gearMod = require("game.gear")
            local basePool = {}
            for _, p in ipairs(gearMod.loadHullParts() or {}) do basePool[#basePool + 1] = p end
            for _, p in ipairs(gearMod.loadEngineParts() or {}) do basePool[#basePool + 1] = p end
            -- INBOX 61(15): prefer slot-exclusive parts; fall back to full pool
            local slotOnly = gearMod.slotPool(basePool)
            local sourcePool = #slotOnly > 0 and slotOnly or basePool
            local filteredPool = {}
            for _, p in ipairs(sourcePool) do
                if matchCount == 2 and (p.rarity == "common" or p.rarity == "uncommon") then
                    filteredPool[#filteredPool + 1] = p
                elseif matchCount == 3 and (p.rarity == "rare" or p.rarity == "legendary") then
                    filteredPool[#filteredPool + 1] = p
                end
            end
            -- If rarity filter emptied the slot pool, fall back to full pool
            if #filteredPool == 0 then
                for _, p in ipairs(basePool) do
                    if matchCount == 2 and (p.rarity == "common" or p.rarity == "uncommon") then
                        filteredPool[#filteredPool + 1] = p
                    elseif matchCount == 3 and (p.rarity == "rare" or p.rarity == "legendary") then
                        filteredPool[#filteredPool + 1] = p
                    end
                end
            end
            local partRolls = {
                rarity = rolls and rolls.partRarity or 0,
                pick = rolls and rolls.partPick or 0,
                editionChance = rolls and rolls.partEditionChance or 1,
                editionPick = rolls and rolls.partEditionPick or 0,
            }
            rewardPart = M.rollGearOffer(run, filteredPool, partRolls)
        end
        -- MONEY match stays as money reward
    end
    return {
        symbols = symbols,
        reward = rewardType == "money" and rewardValue or 0,
        rewardType = rewardType,
        rewardValue = rewardValue,
        rewardMultiplier = rewardMultiplier,
        rewardPart = rewardPart,
        totalWeight = total,
        effectiveHarvestWeight = effectiveHarvestWeight,
        effectiveStarWeight = effectiveHarvestWeight,
        matchCount = matchCount,
        matchSymbol = matchSymbol,
        rewardProfile = profile,
        spinCost = spinCost,
        slotTier = tier,
    }
end
