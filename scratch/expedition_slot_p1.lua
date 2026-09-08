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
