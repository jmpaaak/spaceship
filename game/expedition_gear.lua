local gearModule = require("game.gear")
local enginePartsModule = require("game.engine_parts")
local shopGearRules = require("game.shop_gear_rules")

local M = {}

local baseStreakBonusPerStep = 0.2

local function combinedGearList(run)
    local parts = {}
    for _, part in ipairs(run.equippedGear or {}) do parts[#parts + 1] = part end
    for _, part in ipairs(run.equippedEngineParts or {}) do parts[#parts + 1] = part end
    return parts
end

function M.equippedHullDurabilityBonus(_, run)
    return (gearModule.equippedTotals(run.equippedGear or {}).hullDurability or 0)
        + gearModule.engineSlotHullDurabilityDrawback(run.equippedEngineParts or {})
end

function M.getScoutDurabilityBonus(api, run)
    local baseAndGearD = run.baseDurability
        + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
        + api.equippedHullDurabilityBonus(run)
    local bonus = -math.floor(baseAndGearD * 0.5)
    if baseAndGearD + bonus < 1 then bonus = 1 - baseAndGearD end
    return bonus
end

function M.refreshShipStats(api, run)
    local durabilityBonus = run.selectedShipId == "scout" and api.getScoutDurabilityBonus(run) or 0
    run.maxDurability = run.baseDurability + durabilityBonus
        + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
        + api.equippedHullDurabilityBonus(run)
end

function M.equippedHullMoneyBonus(_, run)
    return gearModule.equippedTotals(run.equippedGear or {}).money or 0
end

local function materializeEdition(part)
    if type(part) ~= "table" or not part.edition or part.editionApplied then return part end
    local copy = {}
    for k, v in pairs(part) do copy[k] = v end
    copy.effects = gearModule.applyEditionEffects(part, part.edition)
    copy.editionApplied = true
    return copy
end

function M.equipGear(api, run, category, part)
    local ok, err = enginePartsModule.equip(run.gearLoadout, category, materializeEdition(part))
    if not ok then return false, err end
    if category == "hull" then
        run.equippedGear = run.gearLoadout.hull
    else
        run.equippedEngineParts = run.gearLoadout.engine
    end
    M.refreshShipStats(api, run)
    if run.phase == "launch" then run.durability = run.maxDurability end
    return true
end

function M.unequipGear(api, run, category, id)
    local removed = enginePartsModule.unequip(run.gearLoadout, category, id)
    if removed then
        if category == "hull" then
            run.equippedGear = run.gearLoadout.hull
        else
            run.equippedEngineParts = run.gearLoadout.engine
        end
        M.refreshShipStats(api, run)
        if run.phase == "launch" then
            run.durability = math.min(run.durability, run.maxDurability)
        end
    end
    return removed
end

function M.sellGear(api, run, category, id)
    local ok, result = shopGearRules.sellEquipped(run, category, id)
    if not ok then return false, result end
    run.equippedGear = run.gearLoadout.hull
    run.equippedEngineParts = run.gearLoadout.engine
    M.refreshShipStats(api, run)
    run.durability = math.min(run.durability, run.maxDurability)
    return true, result
end

function M.buyGear(api, run, category, part)
    if run.phase ~= "settlement" then
        return false, "buyGear: only allowed during the settlement/shop phase"
    end
    if type(part) ~= "table" then return false, "buyGear: part must be a table" end
    if part.galaxyExclusive then
        return false, "buyGear: galaxy-exclusive parts are not sold on Earth"
    end
    local price = api.shopPrice(run, gearModule.buyPrice(part))
    if run.money < price then return false, "buyGear: not enough money" end
    local ok, err = api.equipGear(run, category, part)
    if not ok then return false, err end
    run.money = run.money - price
    return true, price
end

function M.buyGearFromShopPlanet(api, run, category, part)
    if run.phase ~= "ascending" then
        return false, "buyGearFromShopPlanet: only allowed while in flight (ascending) near a shop planet"
    end
    if type(part) ~= "table" then
        return false, "buyGearFromShopPlanet: part must be a table"
    end
    local price = api.shopPrice(run, gearModule.buyPrice(part))
    if run.money < price then return false, "buyGearFromShopPlanet: not enough money" end
    local ok, err = api.equipGear(run, category, part)
    if not ok then return false, err end
    run.money = run.money - price
    return true, price
end

function M.shopPrice(_, run, basePrice)
    return gearModule.effectiveShopPrice(basePrice, combinedGearList(run))
end

function M.streakBonusPerStep(_, run)
    if not run then return baseStreakBonusPerStep end
    return gearModule.effectiveStreakBonusPerStep(baseStreakBonusPerStep, combinedGearList(run))
end

function M.streakMultiplier(api, streakCount, run)
    if not streakCount or streakCount <= 1 then return 1 end
    local base = 1 + (streakCount - 1) * api.streakBonusPerStep(run)
    if run then
        local syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
        if syn.pulsarBurst then base = base * 2 end
        if syn.darkMatter then base = base * 1.5 end
    end
    return base
end

function M.effectiveSpeed(_, run)
    local gearTotals, gearMults = gearModule.equippedTotals(run.equippedGear or {})
    local engineParts = run.equippedEngineParts or {}
    local engineSpeedRaw, engineMultsRaw = gearModule.aggregateEffects(engineParts)
    local engineSpeed = (engineSpeedRaw.speed or 0) * gearModule.tagSynergyMultiplier(engineParts)
    local shipBonus = run.selectedShipId == "scout" and run.scoutClimbSpeedBonus or 0
    local base = (run.baseSpeed or 0)
        + (run.steeringUpgradeLevel or 0) * (run.steeringUpgradeAmount or 0)
    local flat = base + (run.slotSpeedBonus or 0) + (shipBonus or 0)
        + (gearTotals.speed or 0) + engineSpeed
    local mult = (gearMults and gearMults.speed or 1)
        * (engineMultsRaw and engineMultsRaw.speed or 1)
    return flat * mult
end

function M.effectiveSampleBonus(_, run)
    local hullAdditiveRaw, hullMults = gearModule.aggregateEffects(run.equippedGear or {})
    local hullAdditive = hullAdditiveRaw.sampleSellValue or 0
    if hullAdditive == 0 then return 0 end
    local sellMult = gearModule.totalEffect(combinedGearList(run), "sellMultiplier")
    local mult = hullMults.sampleSellValue or 1
    return hullAdditive * (1 + sellMult / 100) * mult
end

function M.aggregateEffectsWithSynergies(_, run, parts)
    local syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    local totals, multTotals = {}, {}
    for _, part in ipairs(parts) do
        local scale = (syn.supernova and part.rarity == "legendary") and 1.5 or 1
        for _, effect in ipairs(part.effects) do
            if effect.mode == "multiply" then
                multTotals[effect.type] = (multTotals[effect.type] or 1) * (effect.value * scale)
            else
                totals[effect.type] = (totals[effect.type] or 0) + effect.value * scale
            end
        end
    end
    return totals, multTotals
end

function M.equippedTotals(api, run, parts)
    local combined = parts or combinedGearList(run)
    local totals, multTotals = api.aggregateEffectsWithSynergies(run, combined)
    local multiplier = gearModule.tagSynergyMultiplier(combined)
    if totals.speed then totals.speed = totals.speed * multiplier end
    totals.synergyMultiplier = multiplier
    if totals.sellMultiplier and totals.sampleSellValue then
        totals.sampleSellValue = totals.sampleSellValue * (1 + totals.sellMultiplier / 100)
    end
    return totals, multTotals
end

function M.boostChargeCount(_, run)
    return gearModule.boostChargeCount(run.equippedEngineParts or {})
end

-- INBOX 66: boostCharge is a CAP, not a starting fill. Remaining is
-- minted charges minus spends, never above the equipped cap.
function M.boostsRemaining(api, run)
    local cap = api.boostChargeCount(run)
    local minted = run.boostsMinted or 0
    local used = run.boostsUsed or 0
    return math.max(0, math.min(cap, minted - used))
end

function M.spendBoost(api, run)
    if api.boostsRemaining(run) <= 0 then return false, "no boost charges remaining" end
    run.boostsUsed = (run.boostsUsed or 0) + 1
    return true
end

M.BOOST_REGEN_INTERVAL = 5

function M.tickBoostRegen(api, run, dt)
    if dt <= 0 or run.phase ~= "ascending" then return end
    local cap = api.boostChargeCount(run)
    if cap <= 0 then
        run.boostRegenAcc = 0
        return
    end
    if api.boostsRemaining(run) >= cap then
        run.boostRegenAcc = 0
        return
    end
    run.boostRegenAcc = (run.boostRegenAcc or 0) + dt
    while run.boostRegenAcc >= M.BOOST_REGEN_INTERVAL and api.boostsRemaining(run) < cap do
        run.boostRegenAcc = run.boostRegenAcc - M.BOOST_REGEN_INTERVAL
        run.boostsMinted = (run.boostsMinted or 0) + 1
    end
    if api.boostsRemaining(run) >= cap then
        run.boostRegenAcc = 0
    end
end

function M.chainTriggerCount(_, run)
    return gearModule.chainTriggerCount(combinedGearList(run))
end

function M.rerollCount(_, run)
    return gearModule.rerollCount(combinedGearList(run))
end

function M.rerollsRemaining(api, run)
    return math.max(0, api.rerollCount(run) - (run.rerollsUsed or 0))
end

function M.spendReroll(api, run)
    if api.rerollsRemaining(run) <= 0 then return false, "no free rerolls remaining" end
    run.rerollsUsed = (run.rerollsUsed or 0) + 1
    return true
end

function M.rerollGearOffer(api, run, pool, rolls)
    if api.rerollsRemaining(run) <= 0 then
        return false, "rerollGearOffer: no free rerolls remaining"
    end
    local offer = api.rollGearOffer(run, pool, rolls)
    if not offer then return false, "rerollGearOffer: pool produced no offer" end
    local ok, err = api.spendReroll(run)
    if not ok then return false, err end
    return true, offer
end

function M.hubRestock(api, run, pool, rolls)
    if run.phase ~= "settlement" then return false, "hubRestock: only during settlement" end
    if not run.lastVisitedGalaxyId then return false, "hubRestock: hub only" end
    local cost = api.hubRestockCost or 5
    if run.money < cost then return false, "hubRestock: not enough money" end
    local offer = api.rollGearOffer(run, pool, rolls)
    if not offer then return false, "hubRestock: pool produced no offer" end
    run.money = run.money - cost
    return true, offer
end

function M.detectionRadius(_, run, baseRadius)
    return gearModule.effectiveDetectionRadius(baseRadius, combinedGearList(run))
end

function M.autoCollectEnabled(_, run)
    return gearModule.autoCollectEnabled(combinedGearList(run))
end

function M.collisionRadius(_, run, baseRadius)
    local radius = baseRadius * (1 - gearModule.totalEffect(combinedGearList(run), "collisionRadius") / 100)
    return math.max(0, radius)
end

function M.collectOrbitRadius(_, run, baseCollectRadius)
    local syn = gearModule.activeSynergies(run.equippedGear or {}, run.equippedEngineParts or {})
    return baseCollectRadius * (1 + (syn.eventHorizon and 0.30 or 0))
end

function M.rollGearOffer(_, run, pool, rolls)
    rolls = rolls or {}
    local luckBonus = gearModule.totalLuckBonus(combinedGearList(run))
    local targetRarity = gearModule.rollRarity(rolls.rarity or 0, luckBonus)
    local matching = {}
    for _, part in ipairs(pool) do
        if part.rarity == targetRarity then matching[#matching + 1] = part end
    end
    local candidates = #matching > 0 and matching or pool
    if #candidates == 0 then return nil end
    local idx = math.floor((rolls.pick or 0) * #candidates) + 1
    if idx > #candidates then idx = #candidates end
    if idx < 1 then idx = 1 end
    local part = candidates[idx]
    local edition = gearModule.rollEdition(
        part, rolls.editionChance or 1, rolls.editionPick or 0, luckBonus)
    return {
        id = part.id,
        name = part.name,
        nameKo = part.nameKo,
        icon = part.icon,
        rarity = part.rarity,
        tags = part.tags,
        edition = edition,
        effects = gearModule.applyEditionEffects(part, edition),
        editionApplied = edition ~= nil,
    }
end

function M.exploreHub(_, run, galaxyId, pool, rolls)
    if run.hubExplored[galaxyId] then return nil end
    run.hubExplored[galaxyId] = true
    run.lastVisitedGalaxyId = galaxyId
    local part = gearModule.galaxySpecificGear(pool, galaxyId)
    if not part then return nil end
    local edition, effects = nil, part.effects
    if rolls then
        local luckBonus = gearModule.totalLuckBonus(combinedGearList(run))
        edition = gearModule.rollEdition(
            part, rolls.editionChance or 1, rolls.editionPick or 0, luckBonus)
        if edition then effects = gearModule.applyEditionEffects(part, edition) end
    end
    return {
        id = part.id,
        name = part.name,
        nameKo = part.nameKo,
        icon = part.icon,
        rarity = part.rarity,
        tags = part.tags,
        edition = edition,
        effects = effects,
        editionApplied = edition ~= nil,
    }
end

function M.totalEffect(run, effectType)
    return gearModule.totalEffect(combinedGearList(run), effectType)
end

function M.hasInsurance(run)
    return gearModule.hasInsurance(combinedGearList(run))
end

return M
