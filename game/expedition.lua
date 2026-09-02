local M = {}

local slotSymbols = { "COMET", "PLANET", "STAR" }
M.slotSymbols = slotSymbols

-- Weighted so rarer symbols carry the bigger payout: COMET is the common
-- filler, PLANET is mid-rare, STAR is the rare jackpot symbol.
local slotWeights = { COMET = 5, PLANET = 4, STAR = 1 }
M.slotWeights = slotWeights

local slotTotalWeight = 0
for _, symbol in ipairs(slotSymbols) do
    slotTotalWeight = slotTotalWeight + slotWeights[symbol]
end
M.slotTotalWeight = slotTotalWeight

function M.slotSymbolProbability(symbol)
    return slotWeights[symbol] / slotTotalWeight
end

local function slotReward(symbols)
    if symbols[1] == symbols[2] and symbols[2] == symbols[3] then
        if symbols[1] == "STAR" then return 75 end
        return 40
    end
    if symbols[1] == symbols[2] or symbols[1] == symbols[3] or symbols[2] == symbols[3] then
        return 15
    end
    return 5
end
M.slotReward = slotReward

local function weightedSlotSymbol(roll)
    local cumulative = 0
    for _, symbol in ipairs(slotSymbols) do
        cumulative = cumulative + slotWeights[symbol]
        if roll <= cumulative then return symbol end
    end
    return slotSymbols[#slotSymbols]
end
M.weightedSlotSymbol = weightedSlotSymbol

-- Exact expected payout of a single spin given the current symbol weights,
-- computed by brute-forcing every reel combination (used for balance tests
-- and future UI display, not just an approximation).
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

local function spinSlot(run)
    local symbols = {}
    for reel = 1, 3 do
        symbols[reel] = weightedSlotSymbol(run.slotRandom(slotTotalWeight))
    end
    return symbols, slotReward(symbols)
end

-- docs/GAME_DESIGN.md's 귀환 슬롯 section lists repair vouchers (수리권)
-- as one of the reward kinds a slot spin can grant, alongside money. Only
-- the rarest/most valuable combo (STAR-STAR-STAR jackpot, 10% per reel,
-- 0.1% overall) also grants a repair voucher worth 1 durability point.
local function slotRepairVoucher(symbols)
    if symbols[1] == "STAR" and symbols[2] == "STAR" and symbols[3] == "STAR" then
        return 1
    end
    return 0
end
M.slotRepairVoucher = slotRepairVoucher

-- docs/GAME_DESIGN.md's 귀환 슬롯 section also lists "다음 원정 연료 보너스"
-- (next-expedition fuel bonus) as one of the reward kinds a slot spin can
-- grant, alongside money and repair vouchers. A PLANET-PLANET-PLANET
-- triple (40% per reel, 6.4% overall -- rarer than a mismatched-symbol
-- payout but far more common than the STAR jackpot) grants a fuel bonus.
-- Unlike the repair voucher, this bonus cannot help the current, already
-- fuel-empty expedition; it is banked at safe settlement and applied to
-- the *next* launch's starting fuel instead.
local slotFuelBonusAmount = 15
M.slotFuelBonusAmount = slotFuelBonusAmount

local function slotFuelBonus(symbols)
    if symbols[1] == "PLANET" and symbols[2] == "PLANET" and symbols[3] == "PLANET" then
        return slotFuelBonusAmount
    end
    return 0
end
M.slotFuelBonus = slotFuelBonus

-- docs/GAME_DESIGN.md's 귀환 슬롯 section also lists "표본 보너스" (sample
-- bonus) as one of the four slot reward kinds, alongside money multiples,
-- repair vouchers and the fuel bonus above. It was the only one of the four
-- still unimplemented. A COMET-COMET-COMET triple (50% per reel, 12.5%
-- overall -- the most common triple, since COMET is the common filler
-- symbol) grants a flat bonus added directly to the current expedition's
-- unbanked sample value. Unlike the fuel bonus (which cannot help the
-- already fuel-empty current expedition and must be banked for next
-- launch), a sample bonus can still help this expedition: it stacks into
-- run.pendingSampleValue immediately, same as a collected sample, and is
-- confirmed at settlement or forfeited at destruction like any other
-- pending sample value.
local slotSampleBonusAmount = 25
M.slotSampleBonusAmount = slotSampleBonusAmount

local function slotSampleBonus(symbols)
    if symbols[1] == "COMET" and symbols[2] == "COMET" and symbols[3] == "COMET" then
        return slotSampleBonusAmount
    end
    return 0
end
M.slotSampleBonus = slotSampleBonus

-- docs/feedback/INBOX.md 처리대기 항목 7 -- gear acquisition is three-way:
-- (a) buy at a galaxy's deterministic 상점 행성 (world.shopPlanet) with
-- money, (b) a guaranteed (non-random) one-time drop the first time a
-- galaxy's center checkpoint (world.hubPlanet) is explored, unique to
-- that galaxy, or (c) buy a generic (non-galaxy-specific) part at the
-- EARTH SHOP. Galaxy-unique gear from (b) is intentionally absent from
-- the generic catalog below so it can never be bought at Earth (item
-- 7-c: "특정 은하 고유의 희귀 장비는 지구에서 판매하지 않는다").
M.genericGearCatalog = {
    { id = "thruster_mk1", name = "THRUSTER MK1", cost = 80 },
    { id = "hullplate_mk1", name = "HULL PLATE MK1", cost = 100 },
    { id = "magnet_mk1", name = "COLLECTOR MAGNET MK1", cost = 90 },
}

-- Deterministic galaxy-unique gear id granted by exploring that galaxy's
-- checkpoint (hub) planet. One gear per galaxy, derived from the
-- galaxy's own stable id so it is reproducible and never collides with
-- the generic catalog's ids above.
function M.galaxyGearId(galaxyId)
    return "unique:" .. galaxyId
end

-- First-time exploration (착륙/근접 상호작용) of a galaxy's checkpoint hub
-- planet unconditionally grants that galaxy's unique gear part exactly
-- once -- a guaranteed drop, not a probability roll. Re-exploring the
-- same galaxy's checkpoint is a no-op (returns false, nil).
function M.exploreCheckpoint(run, galaxyId)
    if not run or not galaxyId then return false, nil end
    run.exploredCheckpoints = run.exploredCheckpoints or {}
    if run.exploredCheckpoints[galaxyId] then return false, nil end
    run.exploredCheckpoints[galaxyId] = true
    local gearId = M.galaxyGearId(galaxyId)
    run.ownedGear = run.ownedGear or {}
    run.ownedGear[gearId] = true
    return true, gearId
end

-- Buys any gear part (galaxy-unique at a 상점 행성, or generic) for a
-- given money cost. Shared by both the galaxy shop-planet purchase path
-- (7-a) and the Earth-shop generic purchase path (7-c) below.
function M.buyGear(run, gearId, cost)
    if not run or not gearId or type(cost) ~= "number" then return false end
    run.ownedGear = run.ownedGear or {}
    if run.ownedGear[gearId] then return false end
    if run.money < cost then return false end
    run.money = run.money - cost
    run.ownedGear[gearId] = true
    return true
end

-- EARTH SHOP purchase restricted to the generic catalog: a galaxy-unique
-- gear id (from exploreCheckpoint) is never present in genericGearCatalog,
-- so this rejects it even if the caller mistakenly passes one.
function M.buyEarthGear(run, gearId)
    for _, entry in ipairs(M.genericGearCatalog) do
        if entry.id == gearId then
            return M.buyGear(run, gearId, entry.cost)
        end
    end
    return false
end

-- docs/feedback/INBOX.md 처리대기 항목 7-a: a galaxy's 상점 행성 sells that
-- same galaxy's unique gear part for money -- a paid alternative to the
-- guaranteed-but-unpaid checkpoint drop (7-b) for players who reach the
-- shop planet before (or instead of) the hub checkpoint. Priced above the
-- generic catalog since it grants a galaxy-exclusive part.
local shopGearCost = 150
M.shopGearCost = shopGearCost

function M.buyShopGear(run, galaxyId)
    if not run or not galaxyId then return false, nil end
    local gearId = M.galaxyGearId(galaxyId)
    local bought = M.buyGear(run, gearId, shopGearCost)
    if not bought then return false, nil end
    return true, gearId
end

local function refreshShipStats(run)
    local fuelBonus = 0
    local durabilityBonus = 0
    if run.selectedShipId == "scout" then
        fuelBonus = run.scoutFuelBonus
        durabilityBonus = run.scoutDurabilityBonus
    end
    -- docs/feedback/INBOX.md 처리대기 항목 11(b): the purchasable "fuel tank
    -- upgrade" (fuelUpgradeLevel/fuelUpgradeCost/fuelUpgradeAmount) has been
    -- removed below -- maxFuel now varies only with the selected ship's
    -- base/bonus fuel, never with a shop purchase, since fuel does not
    -- constrain flight and a store item implying otherwise is misleading.
    run.maxFuel = run.baseFuel + fuelBonus
    run.maxDurability = run.baseDurability + durabilityBonus
        + run.durabilityUpgradeLevel * run.durabilityUpgradeAmount
end

local function slotCount(distance, slotDistance)
    if distance <= 0 then return 0 end
    return math.ceil(distance / slotDistance)
end

function M.launchForecast(run, maxFuel)
    local forecastFuel = maxFuel or run.maxFuel
    if forecastFuel <= 0 or run.fuelBurnRate <= 0 or run.climbSpeed <= 0 then return 0, 0 end
    local altitude = forecastFuel / run.fuelBurnRate * run.climbSpeed
    return altitude, slotCount(altitude, run.slotDistance)
end

-- docs/feedback/INBOX.md 항목 11(c): M.maneuverFuel/M.burnManeuverFuel used
-- to exist as permanent no-op shims (fuel is no longer a flight constraint,
-- so they always returned 0 and touched nothing) purely so the joystick
-- extra-distance call site in game/scenes/play.lua would still compile.
-- Both the shims and that dead call site are removed now -- fuel has no
-- remaining consumption path anywhere in the engine.

-- Safe return is now an explicit action (tests / future player input),
-- not a fuel-empty side effect.
function M.beginReturn(run)
    if not run or run.phase ~= "ascending" then return false end
    run.phase = "returning"
    run.returnDistance = run.maxAltitude
    run.slotOpportunities = slotCount(run.returnDistance, run.slotDistance)
    return true
end

local function settle(run)
    run.lastSampleSettlement = run.pendingSampleValue
    run.lastSlotSettlement = run.pendingSlotReward
    local payout = run.lastSampleSettlement + run.lastSlotSettlement
    run.money = run.money + payout
    run.lastSettlement = payout
    run.lastSampleCount = run.sampleCount
    run.lastSlotSpinsCount = run.slotSpins
    run.lastAltitude = run.maxAltitude
    run.lastNewBest = run.bestAltitude > (run.launchBestAltitude or 0)
    run.bankedFuelBonus = run.pendingFuelBonus
    run.pendingFuelBonus = 0
    run.pendingSampleValue = 0
    run.pendingSlotReward = 0
    run.sampleCount = 0
    run.slotOpportunities = 0
    run.phase = "settlement"
end

-- docs/feedback/INBOX.md 처리대기 항목 8 -- ordinary (non-checkpoint,
-- non-shop) planet exploration only ever grants samples (collectSample
-- above), never money directly. Samples only convert to money at a
-- settlement trigger: Earth return (settle(), altitude == 0, unchanged)
-- or -- newly added here -- docking at a galaxy's center checkpoint
-- (world.hubPlanet) mid-expedition. Unlike the Earth settle() above,
-- this does NOT end the expedition (run stays "ascending" so the player
-- keeps climbing) and only banks the *sample* value collected so far,
-- not any pending slot reward (checkpoints are not a slot-machine payout
-- point). Ordinary planet proximity alone must never call this -- only
-- an explicit checkpoint dock should.
function M.checkpointSettle(run)
    if not run or run.phase ~= "ascending" then return false, 0 end
    local amount = run.pendingSampleValue
    if amount <= 0 then return false, 0 end
    run.money = run.money + amount
    run.pendingSampleValue = 0
    run.lastCheckpointSettlement = amount
    return true, amount
end

local function destroy(run)
    run.phase = "destroyed"
    run.durability = 0
    run.lastLostSampleCount = run.sampleCount
    run.lastLostSampleValue = run.pendingSampleValue
    run.lastLostSlotSpinsCount = run.slotSpins
    run.lastLostSlotValue = run.pendingSlotReward
    run.lastLostAltitude = run.maxAltitude
    run.lastLostNewBest = run.bestAltitude > (run.launchBestAltitude or 0)
    run.sampleCount = 0
    run.pendingSampleValue = 0
    run.sampleStreakCount = 0
    run.sampleStreakFamily = nil
    run.pendingSlotReward = 0
    run.slotOpportunities = 0
    run.slotSpins = 0
    run.lastSlotSymbols = nil
    run.lastSlotReward = 0
    run.lastSlotRepair = 0
    run.lastSlotFuelBonus = 0
    run.lastSlotSampleBonus = 0
    run.pendingFuelBonus = 0
    run.bankedFuelBonus = 0
    run.returnDistance = 0
    run.money = 0
    run.lastSettlement = 0
    run.lastSampleSettlement = 0
    run.lastSlotSettlement = 0
    run.lastSampleCount = 0
    run.lastSlotSpinsCount = 0
    run.durabilityUpgradeLevel = 0
    run.sampleYieldUpgradeLevel = 0
    run.steeringUpgradeLevel = 0
    run.ownedShips = { starter = true }
    run.selectedShipId = "starter"
    -- Full meta wipe (non-negotiable game rule: durability 0 wipes
    -- purchased ship/upgrades, preserving only all-time best height).
    -- Gear (item 7) is a purchased/dropped upgrade, so it resets like
    -- ownedShips; checkpoint exploration resets with it so a fresh run
    -- can re-earn the guaranteed drop rather than being permanently
    -- locked out by a wiped-away gear ownership record.
    run.ownedGear = {}
    run.exploredCheckpoints = {}
    refreshShipStats(run)
end

function M.new(options)
    options = options or {}
    local baseFuel = options.fuel or 100
    local baseDurability = options.durability or 3
    return {
        phase = "launch",
        altitude = 0,
        maxAltitude = 0,
        bestAltitude = options.bestAltitude or 0,
        launchBestAltitude = options.bestAltitude or 0,
        lastNewBest = false,
        lastLostNewBest = false,
        baseFuel = baseFuel,
        maxFuel = baseFuel,
        durability = baseDurability,
        baseDurability = baseDurability,
        maxDurability = baseDurability,
        durabilityUpgradeAmount = options.durabilityUpgradeAmount or 1,
        durabilityUpgradeCost = options.durabilityUpgradeCost or 75,
        durabilityUpgradeLevel = 0,
        sampleYieldUpgradeAmount = options.sampleYieldUpgradeAmount or 0.25,
        sampleYieldUpgradeCost = options.sampleYieldUpgradeCost or 60,
        sampleYieldUpgradeLevel = 0,
        baseSteeringSpeed = options.steeringSpeed or 55,
        steeringUpgradeAmount = options.steeringUpgradeAmount or 15,
        steeringUpgradeCost = options.steeringUpgradeCost or 65,
        steeringUpgradeLevel = 0,
        scoutShipCost = options.scoutShipCost or 125,
        scoutFuelBonus = options.scoutFuelBonus or 40,
        scoutDurabilityBonus = options.scoutDurabilityBonus or -1,
        ownedShips = { starter = true },
        selectedShipId = "starter",
        fuelBurnRate = options.fuelBurnRate or 5,
        climbSpeed = options.climbSpeed or 30,
        returnSpeed = options.returnSpeed or 45,
        slotDistance = options.slotDistance or 100,
        returnDistance = 0,
        slotOpportunities = 0,
        slotSpins = 0,
        slotRandom = options.slotRandom or math.random,
        lastSlotSymbols = nil,
        lastSlotReward = 0,
        lastSlotRepair = 0,
        lastSlotFuelBonus = 0,
        lastSlotSampleBonus = 0,
        pendingFuelBonus = 0,
        bankedFuelBonus = 0,
        sampleCount = 0,
        pendingSampleValue = 0,
        sampleStreakCount = 0,
        sampleStreakFamily = nil,
        pendingSlotReward = 0,
        money = options.money or 0,
        lastSettlement = 0,
        lastSampleSettlement = 0,
        lastSlotSettlement = 0,
        lastSampleCount = 0,
        lastSlotSpinsCount = 0,
        lastAltitude = 0,
        lastLostSampleCount = 0,
        lastLostSampleValue = 0,
        lastLostSlotSpinsCount = 0,
        lastLostSlotValue = 0,
        lastLostAltitude = 0,
        ownedGear = {},
        exploredCheckpoints = {},
        lastCheckpointSettlement = 0,
    }
end

function M.launch(run)
    if run.phase ~= "launch" and run.phase ~= "settlement" and run.phase ~= "destroyed" then return false end
    run.launchBestAltitude = run.bestAltitude
    run.lastNewBest = false
    run.lastLostNewBest = false
    if run.phase ~= "launch" then
        run.altitude = 0
        run.maxAltitude = 0
        -- docs/feedback/INBOX.md 항목 11(c): run.fuel was a dead state field
        -- (never read by any flight decision -- altitude ticks by
        -- climbSpeed unconditionally) and has been removed entirely. The
        -- banked PLANET-triple slot bonus (bankedFuelBonus/pendingFuelBonus)
        -- no longer has a fuel field to apply itself to; it is still
        -- cleared here so a stale bank cannot leak into a later launch, but
        -- item 15's Earth-shop-only slot machine redesign is the owner of
        -- redefining what this reward kind means going forward.
        run.bankedFuelBonus = 0
        run.durability = run.maxDurability
        run.returnDistance = 0
        run.slotOpportunities = 0
        run.slotSpins = 0
        run.lastSlotSymbols = nil
        run.lastSlotReward = 0
        run.lastSlotRepair = 0
        run.lastSlotFuelBonus = 0
        run.lastSlotSampleBonus = 0
        run.pendingFuelBonus = 0
        run.sampleCount = 0
        run.pendingSampleValue = 0
        run.sampleStreakCount = 0
        run.sampleStreakFamily = nil
        run.pendingSlotReward = 0
        run.lastSettlement = 0
        run.lastSampleSettlement = 0
        run.lastSlotSettlement = 0
        run.lastSampleCount = 0
        run.lastSlotSpinsCount = 0
        run.lastAltitude = 0
        run.lastLostSampleCount = 0
        run.lastLostSampleValue = 0
        run.lastLostSlotSpinsCount = 0
        run.lastLostSlotValue = 0
        run.lastLostAltitude = 0
    end
    run.phase = "ascending"
    return true
end

-- docs/feedback/INBOX.md 처리대기 항목 11(b): the fuel-tank shop upgrade
-- (buyFuelUpgrade) has been removed entirely -- fuel no longer constrains
-- flight, so a purchasable "more fuel" item only misled players into
-- thinking it mattered. maxFuel is now fixed by the selected ship alone
-- (see refreshShipStats above).
function M.buyDurabilityUpgrade(run)
    if run.phase ~= "settlement" or run.money < run.durabilityUpgradeCost then return false end
    run.money = run.money - run.durabilityUpgradeCost
    run.durabilityUpgradeLevel = run.durabilityUpgradeLevel + 1
    refreshShipStats(run)
    return true
end

-- Sample yield is the third meta upgrade requested alongside fuel/hull: it
-- scales the money value of every collected sample (not just fuel/durability
-- capacity), giving players a third strategic upgrade axis at EARTH SHOP.
function M.sampleYieldMultiplier(run)
    return 1 + run.sampleYieldUpgradeLevel * run.sampleYieldUpgradeAmount
end

function M.buySampleYieldUpgrade(run)
    if run.phase ~= "settlement" or run.money < run.sampleYieldUpgradeCost then return false end
    run.money = run.money - run.sampleYieldUpgradeCost
    run.sampleYieldUpgradeLevel = run.sampleYieldUpgradeLevel + 1
    return true
end

-- Steering is the fourth meta upgrade axis named in
-- docs/GAME_DESIGN.md's meta loop ("연료·내구도·조종·표본 수익을 강화":
-- fuel/hull/steering/sample-yield). It scales the ship's left/right
-- steering speed applied while ascending/returning (game/scenes/play.lua),
-- giving players a way to spend money on better planet-collision avoidance
-- rather than capacity or money yield.
function M.steeringSpeed(run)
    return run.baseSteeringSpeed + run.steeringUpgradeLevel * run.steeringUpgradeAmount
end

function M.buySteeringUpgrade(run)
    if run.phase ~= "settlement" or run.money < run.steeringUpgradeCost then return false end
    run.money = run.money - run.steeringUpgradeCost
    run.steeringUpgradeLevel = run.steeringUpgradeLevel + 1
    return true
end

-- Ship trade-offs expressed as explicit GAINS/LOSSES rows, matching the
-- planet-style-editor tool's numeric format (label + signed value) so the
-- same shape can later describe per-planet-style risk/reward without a
-- separate ad-hoc string format for each source.
function M.shipTradeoff(run, shipId)
    if shipId == "scout" then
        return {
            gains = { { label = "FUEL", value = string.format("%+d", run.scoutFuelBonus) } },
            losses = { { label = "HULL", value = string.format("%+d", run.scoutDurabilityBonus) } },
        }
    end
    return { gains = {}, losses = {} }
end

function M.buyShip(run, shipId)
    if run.phase ~= "settlement" or shipId ~= "scout" or run.ownedShips.scout
        or run.money < run.scoutShipCost then
        return false
    end
    run.money = run.money - run.scoutShipCost
    run.ownedShips.scout = true
    return true
end

function M.selectShip(run, shipId)
    if run.phase ~= "settlement" or not run.ownedShips[shipId]
        or (shipId ~= "starter" and shipId ~= "scout") then
        return false
    end
    run.selectedShipId = shipId
    refreshShipStats(run)
    return true
end

function M.useSlot(run)
    if run.phase ~= "returning" or run.slotOpportunities <= 0 then return false end
    local symbols, reward = spinSlot(run)
    run.slotOpportunities = run.slotOpportunities - 1
    run.slotSpins = run.slotSpins + 1
    run.lastSlotSymbols = symbols
    run.lastSlotReward = reward
    run.pendingSlotReward = run.pendingSlotReward + reward
    local voucher = slotRepairVoucher(symbols)
    local applied = math.min(voucher, run.maxDurability - run.durability)
    run.durability = run.durability + applied
    run.lastSlotRepair = applied
    local fuelBonus = slotFuelBonus(symbols)
    run.lastSlotFuelBonus = fuelBonus
    run.pendingFuelBonus = (run.pendingFuelBonus or 0) + fuelBonus
    local sampleBonus = slotSampleBonus(symbols)
    run.lastSlotSampleBonus = sampleBonus
    run.pendingSampleValue = run.pendingSampleValue + sampleBonus
    return true
end

-- docs/feedback/INBOX.md's Balatro core-mechanics porting plan item 1
-- ("점진적 시너지/빌드업") requests a multiplicative STREAK bonus for
-- collecting consecutive same-hue-family samples, mirroring a card game's
-- combo scaling. streakCount 0 or 1 is the base x1.0 rate; each additional
-- consecutive same-family sample adds +0.2 (x1.2, x1.4, x1.6, ...).
local streakBonusPerStep = 0.2
function M.streakMultiplier(streakCount)
    if not streakCount or streakCount <= 1 then return 1 end
    return 1 + (streakCount - 1) * streakBonusPerStep
end

-- hueKey is the optional hue-family key from world.hueFamily/specimenKind
-- (e.g. "azure"/"ember"/"void"). When provided, consecutive calls with the
-- same hueKey build a streak that multiplies the awarded value on top of
-- the SAMPLE YIELD upgrade; a different hueKey (or no hueKey) resets the
-- streak back to the base rate for that call.
function M.collectSample(run, value, hueKey)
    if run.phase ~= "ascending" or type(value) ~= "number" or value <= 0 then return false end
    if hueKey ~= nil and hueKey == run.sampleStreakFamily then
        run.sampleStreakCount = run.sampleStreakCount + 1
    else
        run.sampleStreakCount = 1
    end
    run.sampleStreakFamily = hueKey
    local streakMultiplier = M.streakMultiplier(run.sampleStreakCount)
    local awarded = math.floor(value * M.sampleYieldMultiplier(run) * streakMultiplier + 0.5)
    run.sampleCount = run.sampleCount + 1
    run.pendingSampleValue = run.pendingSampleValue + awarded
    return true, awarded, streakMultiplier
end

function M.damage(run, amount)
    if (run.phase ~= "ascending" and run.phase ~= "returning") or type(amount) ~= "number" or amount <= 0 then
        return false
    end
    run.durability = math.max(0, run.durability - amount)
    if run.durability == 0 then
        destroy(run)
        return true
    end
    return false
end

function M.update(run, dt)
    if dt <= 0 then return end

    if run.phase == "returning" then
        run.altitude = math.max(0, run.altitude - run.returnSpeed * dt)
        if run.altitude == 0 then settle(run) end
        return
    end

    if run.phase ~= "ascending" then return end

    run.altitude = run.altitude + run.climbSpeed * dt
    run.maxAltitude = math.max(run.maxAltitude, run.altitude)
    run.bestAltitude = math.max(run.bestAltitude, run.altitude)
end

return M
