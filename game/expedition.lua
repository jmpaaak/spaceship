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

-- weights defaults to the standard in-flight table above but accepts an
-- override so a different paytable (e.g. a per-galaxy EARTH SHOP variant,
-- see M.earthShopSlot below) can reuse the same weighted-pick logic.
local function weightedSlotSymbol(roll, weights)
    weights = weights or slotWeights
    local cumulative = 0
    for _, symbol in ipairs(slotSymbols) do
        cumulative = cumulative + (weights[symbol] or 0)
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
    -- docs/feedback/INBOX.md 처리대기 항목 15(c): every checkpoint dock
    -- (even a re-dock of an already-explored galaxy, unlike the
    -- gear-drop/settle side effects below which are strictly one-time)
    -- records the most recently visited galaxy so the EARTH SHOP slot
    -- machine's odds table (M.galaxySlotProfile) reflects the last
    -- checkpoint reached this expedition, not just the first.
    run.lastCheckpointGalaxyId = galaxyId
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

-- docs/feedback/INBOX.md 처리대기 항목 7-c UI wiring: M.buyEarthGear(run,
-- gearId) above has existed as a pure engine API since the first item-7
-- slice, but game/scenes/play.lua never called it -- the EARTH SHOP could
-- only sell nothing at all, leaving the whole generic-catalog purchase
-- path (7-c) unreachable from real play. M.nextBuyableEarthGear(run) picks
-- the first genericGearCatalog entry the run doesn't already own (in
-- catalog order), so a single UI action ("buy next generic part") can
-- drive the whole catalog without needing per-item UI/keys yet -- that
-- richer per-card shop layout is the (still out-of-scope-for-this-lane)
-- item 9/13 gear UI work. Returns nil once every generic part is owned.
function M.nextBuyableEarthGear(run)
    if not run then return nil end
    local owned = run.ownedGear or {}
    for _, entry in ipairs(M.genericGearCatalog) do
        if not owned[entry.id] then return entry end
    end
    return nil
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

-- docs/feedback/INBOX.md 처리대기 항목 15 -- deterministic per-string hash
-- (mirrors game/world.lua's numeric hash() shape but accepts a string id
-- directly, since a galaxy's stable id -- "milkyway" or "galaxy:gx:gy" --
-- is what M.exploreCheckpoint already threads through the engine; this
-- module intentionally does not require game/world.lua to stay a leaf
-- module with no scene/world dependencies).
local function stringHash(s)
    local n = 0
    for i = 1, #s do
        n = (n * 31 + string.byte(s, i)) % 2147483647
    end
    n = (n * 48271 + 12345) % 2147483647
    return n / 2147483647
end
M.stringHash = stringHash

-- docs/feedback/INBOX.md 처리대기 항목 15(c) -- EARTH SHOP slot machine odds
-- vary by which galaxy's checkpoint the player most recently explored this
-- expedition (run.lastCheckpointGalaxyId, set by M.exploreCheckpoint below).
-- No checkpoint explored yet (nil) or the home solar system galaxy both use
-- the standard table (same weights the in-flight slot machine has always
-- used). Any other galaxy is deterministically bucketed into one of two
-- variant tables by a hash of its id: roughly half of non-home galaxies
-- keep a slightly-safer-than-standard table, and the rest (skewed toward
-- outer/rarer galaxies purely by hash luck, matching the brief's "화성/
-- 외곽 은하 슬롯은 고배당/위험부담형" example) get a high-payout, STAR-
-- heavy, COMET-light table with a much higher jackpot rate.
local homeSlotProfile = { COMET = 5, PLANET = 4, STAR = 1 }
local safeSlotProfile = { COMET = 6, PLANET = 3, STAR = 1 }
local riskySlotProfile = { COMET = 2, PLANET = 3, STAR = 5 }
M.homeSlotProfile = homeSlotProfile
M.safeSlotProfile = safeSlotProfile
M.riskySlotProfile = riskySlotProfile

function M.galaxySlotProfile(galaxyId)
    if not galaxyId or galaxyId == "milkyway" then return homeSlotProfile end
    if stringHash(galaxyId) < 0.6 then return safeSlotProfile end
    return riskySlotProfile
end

-- Exact expected payout of a single EARTH SHOP slot spin for a given
-- galaxy's odds table, computed the same brute-force way as the in-flight
-- M.slotExpectedValue above (used for balance tests and future UI display).
function M.earthShopSlotExpectedValue(galaxyId)
    local profile = M.galaxySlotProfile(galaxyId)
    local totalWeight = 0
    for _, symbol in ipairs(slotSymbols) do
        totalWeight = totalWeight + (profile[symbol] or 0)
    end
    local function probability(symbol) return (profile[symbol] or 0) / totalWeight end
    local total = 0
    for _, a in ipairs(slotSymbols) do
        for _, b in ipairs(slotSymbols) do
            for _, c in ipairs(slotSymbols) do
                total = total + probability(a) * probability(b) * probability(c)
                    * slotReward({ a, b, c })
            end
        end
    end
    return total
end

-- docs/feedback/INBOX.md 처리대기 항목 15(b) -- the slot machine itself is
-- relocated from the in-flight returning phase to a EARTH SHOP-only paid
-- minigame: only playable in the settlement phase, costs a flat fee taken
-- from run.money up front (not tied to slotOpportunities/returnDistance at
-- all, unlike the in-flight version), and pays out (or doesn't) using the
-- odds table for whichever galaxy's checkpoint (M.galaxySlotProfile) was
-- most recently explored this expedition -- so a player who reached a
-- risky outer-galaxy checkpoint before returning gets a shot at the
-- higher-payout table back home.
local earthShopSlotCost = 20
M.earthShopSlotCost = earthShopSlotCost

function M.spinEarthShopSlot(run)
    if not run or run.phase ~= "settlement" then return false, nil, 0 end
    if run.money < earthShopSlotCost then return false, nil, 0 end
    run.money = run.money - earthShopSlotCost
    local profile = M.galaxySlotProfile(run.lastCheckpointGalaxyId)
    local totalWeight = 0
    for _, symbol in ipairs(slotSymbols) do
        totalWeight = totalWeight + (profile[symbol] or 0)
    end
    local symbols = {}
    for reel = 1, 3 do
        symbols[reel] = weightedSlotSymbol(run.slotRandom(totalWeight), profile)
    end
    local reward = slotReward(symbols)
    run.money = run.money + reward
    run.lastEarthShopSlotSymbols = symbols
    run.lastEarthShopSlotReward = reward
    run.lastEarthShopSlotGalaxyId = run.lastCheckpointGalaxyId
    return true, symbols, reward
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

local function settle(run)
    run.lastSampleSettlement = run.pendingSampleValue
    run.money = run.money + run.lastSampleSettlement
    run.lastSettlement = run.lastSampleSettlement
    run.lastSampleCount = run.sampleCount
    run.lastAltitude = run.maxAltitude
    run.lastNewBest = run.bestAltitude > (run.launchBestAltitude or 0)
    run.pendingSampleValue = 0
    run.sampleCount = 0
    -- docs/feedback/INBOX.md 처리대기 항목 15(a): with the manually-declared
    -- "returning" phase removed, returnToEarth settles directly from
    -- "ascending" with no travel-down animation ever bringing altitude back
    -- to 0 -- do it here instead, since arriving at Earth means altitude 0
    -- by definition.
    run.altitude = 0
    run.phase = "settlement"
end

-- docs/feedback/INBOX.md 처리대기 항목 15(a): the manually-declared
-- beginReturn phase and the in-flight returning-phase slot machine
-- (useSlot/slotSpin) have been fully removed -- every expedition now
-- settles immediately on arrival at Earth or a galaxy checkpoint
-- (matching item 8's checkpoint settle model). M.returnToEarth is the
-- sole return-to-Earth entry point: it settles the run exactly like the
-- old "returning phase reaches altitude 0" path did (same settle()
-- helper), directly from the ascending phase, with no intermediate
-- returning-phase travel-down animation or slot-machine step.
function M.returnToEarth(run)
    if not run or run.phase ~= "ascending" then return false end
    settle(run)
    return true
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
    run.lastLostAltitude = run.maxAltitude
    run.lastLostNewBest = run.bestAltitude > (run.launchBestAltitude or 0)
    run.sampleCount = 0
    run.pendingSampleValue = 0
    run.sampleStreakCount = 0
    run.sampleStreakFamily = nil
    run.money = 0
    run.lastSettlement = 0
    run.lastSampleSettlement = 0
    run.lastSampleCount = 0
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
    run.lastCheckpointGalaxyId = nil
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
        slotDistance = options.slotDistance or 100,
        slotRandom = options.slotRandom or math.random,
        sampleCount = 0,
        pendingSampleValue = 0,
        sampleStreakCount = 0,
        sampleStreakFamily = nil,
        money = options.money or 0,
        lastSettlement = 0,
        lastSampleSettlement = 0,
        lastSampleCount = 0,
        lastAltitude = 0,
        lastLostSampleCount = 0,
        lastLostSampleValue = 0,
        lastLostAltitude = 0,
        ownedGear = {},
        exploredCheckpoints = {},
        lastCheckpointSettlement = 0,
        lastCheckpointGalaxyId = nil,
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
        -- climbSpeed unconditionally) and has been removed entirely.
        run.durability = run.maxDurability
        run.sampleCount = 0
        run.pendingSampleValue = 0
        run.sampleStreakCount = 0
        run.sampleStreakFamily = nil
        run.lastSettlement = 0
        run.lastSampleSettlement = 0
        run.lastSampleCount = 0
        run.lastAltitude = 0
        run.lastLostSampleCount = 0
        run.lastLostSampleValue = 0
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
    if run.phase ~= "ascending" or type(amount) ~= "number" or amount <= 0 then
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

    if run.phase ~= "ascending" then return end

    run.altitude = run.altitude + run.climbSpeed * dt
    run.maxAltitude = math.max(run.maxAltitude, run.altitude)
    run.bestAltitude = math.max(run.bestAltitude, run.altitude)
end

return M
