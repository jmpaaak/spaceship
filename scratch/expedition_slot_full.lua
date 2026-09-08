function M.loadSlotConfig(fsOverride)
    local fs = fsOverride or love.filesystem
    local contents = fs.read(M.slotConfigPath)
    if not contents then
        -- Restore defaults (INBOX 52b: 5-symbol system)
        M.slotSpinCost = 10
        M.slotSymbols = { "MONEY", "PART", "SPEED", "DURABILITY", "HARVEST" }
        M.slotWeights = { MONEY = 6, PART = 3, SPEED = 4, DURABILITY = 3, HARVEST = 4 }
        M.slotPayouts = { miss = 0, pair = 3, triple = 10 }
        M.earthSlotOddsProfiles = {
            solar  = { MONEY = 6, PART = 3, SPEED = 4, DURABILITY = 3, HARVEST = 4 },
            fringe = { MONEY = 5, PART = 3, SPEED = 4, DURABILITY = 3, HARVEST = 5 },
            void   = { MONEY = 4, PART = 4, SPEED = 4, DURABILITY = 4, HARVEST = 4 },
        }
        M.earthSlotRewardMultipliers = {
            solar  = { tripleMultiplier = 1.0 },
            fringe = { tripleMultiplier = 1.5 },
            void   = { tripleMultiplier = 2.0 },
        }
        slotSymbols = M.slotSymbols
        slotWeights = M.slotWeights
        local w = 0
        for _, s in ipairs(slotSymbols) do w = w + slotWeights[s] end
        M.slotTotalWeight = w
        slotTotalWeight = w
        return false, "file missing"
    end

    local ok, doc = pcall(json.decode, contents)
    if not ok then return false, "json error" end

    M.slotSpinCost = doc.spinCost or 10

    if doc.symbols then
        M.slotSymbols = {}
        M.slotWeights = {}
        for _, s in ipairs(doc.symbols) do
            table.insert(M.slotSymbols, s.id)
            M.slotWeights[s.id] = s.weight
        end
        slotSymbols = M.slotSymbols
        slotWeights = M.slotWeights
        local w = 0
        for _, s in ipairs(slotSymbols) do w = w + slotWeights[s] end
        M.slotTotalWeight = w
        slotTotalWeight = w
    end

    if doc.payouts then
        M.slotPayouts = doc.payouts
    end

    if doc.profiles then
        M.earthSlotOddsProfiles = {}
        M.earthSlotRewardMultipliers = {}
        for k, v in pairs(doc.profiles) do
            M.earthSlotOddsProfiles[k] = v.weights or {}
            M.earthSlotRewardMultipliers[k] = v.multipliers or {}
        end
    end

    return true
end
function M.slotSymbolProbability(symbol)
    return slotWeights[symbol] / slotTotalWeight
end
function M.slotExpectedValue()
    local total = 0
    local probabilitySum = 0
    for _, a in ipairs(slotSymbols) do
        for _, b in ipairs(slotSymbols) do
            for _, c in ipairs(slotSymbols) do
                local probability = M.slotSymbolProbability(a)
                    * M.slotSymbolProbability(b)
                    * M.slotSymbolProbability(c)
                total = total + probability * slotReward({ a, b, c })
                probabilitySum = probabilitySum + probability
            end
        end
    end
    return total, probabilitySum
end
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
