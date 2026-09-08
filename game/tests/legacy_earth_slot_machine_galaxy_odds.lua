local M = {}

-- Item 15(b)(c): Earth-shop slot machine redesign with per-galaxy odds tables.
-- Item 15's core requirements (pure expedition.lua data-layer scope):
--   (c) Each galaxy's hub visit determines which odds *profile* the Earth shop
--       slot machine uses on settlement; fringe/void galaxies are riskier
--       (lower COMET filler rate, higher STAR jackpot rate) than the home
--       solar system standard profile.
--   Item 15 + Item 14(C) luck: luck effect now has a third target --
--       the Earth shop slot machine's STAR (high-payout) symbol weight is
--       boosted by the run's total luck bonus, so luck cards stack into slot
--       odds on top of the galaxy-profile base.
--   run.lastVisitedGalaxyId: exploreHub records which galaxy hub the player
--       most recently visited, so the Earth shop knows which odds table to use.
function M.run()
    local expedition = require("game.expedition")

    -- (1) galaxySlotOddsProfile: solar system (nil or "milkyway") must
    -- return the "solar" (standard) profile; outer/unknown galaxies return
    -- "fringe" or "void" deterministically from galaxy ID so the same galaxy
    -- always maps to the same risk tier.
    local solarProfile = expedition.galaxySlotOddsProfile(nil)
    assert(solarProfile == "solar",
        "nil/home galaxy must map to the solar (standard) slot profile, got: " .. tostring(solarProfile))
    local mwProfile = expedition.galaxySlotOddsProfile("milkyway")
    assert(mwProfile == "solar",
        "milkyway galaxy must map to the solar slot profile, got: " .. tostring(mwProfile))
    local outerProfile = expedition.galaxySlotOddsProfile("andromeda")
    assert(outerProfile == "fringe" or outerProfile == "void",
        "outer galaxy must map to fringe or void profile, got: " .. tostring(outerProfile))
    assert(expedition.galaxySlotOddsProfile("andromeda") == outerProfile,
        "galaxySlotOddsProfile must be deterministic for the same galaxyId")

    -- (2) earthSlotWeights: solar profile must match the existing flat base
    -- weights; fringe/void profile must have a HIGHER STAR weight and LOWER
    -- COMET weight than solar (higher variance/jackpot, riskier).
    local solarWeights = expedition.earthSlotWeights(nil)
    assert(type(solarWeights) == "table", "earthSlotWeights must return a table")
    assert(solarWeights.MONEY and solarWeights.HARVEST,
        "earthSlotWeights must include new keys")

    local fringeGalaxy = nil
    local candidateGalaxies = { "andromeda", "triangulum", "ngc1300", "sombrero", "pinwheel" }
    for _, g in ipairs(candidateGalaxies) do
        local p = expedition.galaxySlotOddsProfile(g)
        if p == "fringe" or p == "void" then
            fringeGalaxy = g
            break
        end
    end
    assert(fringeGalaxy, "at least one of the candidate galaxy IDs must map to fringe or void")
    local fringeWeights = expedition.earthSlotWeights(fringeGalaxy)
    assert(fringeWeights.HARVEST > solarWeights.HARVEST,
        "fringe/void galaxy STAR weight must exceed solar STAR weight (higher jackpot odds)")
    assert(fringeWeights.MONEY < solarWeights.MONEY,
        "fringe/void galaxy MONEY weight must be below solar MONEY weight (riskier, less filler)")

    -- (3) earthSlotSpin: given deterministic rolls, verifies the correct
    -- symbol is chosen and correct reward returned, using galaxy-specific
    -- weights. Rolls are in [0, totalWeight) for each reel.
    local run = expedition.new()
    local solarTotal = solarWeights.MONEY + solarWeights.PART + solarWeights.SPEED + solarWeights.DURABILITY + solarWeights.HARVEST
    local moneyRoll = math.floor(solarWeights.MONEY / 2)
    local spinResult = expedition.earthSlotSpin(run, nil, {
        reels = { moneyRoll, moneyRoll, moneyRoll },
    })
    assert(type(spinResult) == "table", "earthSlotSpin must return a result table")
    assert(spinResult.symbols and #spinResult.symbols == 3, "result must carry a 3-element symbols array")
    assert(spinResult.symbols[1] == "MONEY" and spinResult.symbols[2] == "MONEY" and spinResult.symbols[3] == "MONEY",
        "all-zero rolls against solar weights must yield MONEY-MONEY-MONEY triple")
    assert(type(spinResult.reward) == "number" and spinResult.reward > 0,
        "a MONEY triple must produce a positive reward")
    assert(type(spinResult.totalWeight) == "number" and spinResult.totalWeight == solarTotal,
        "earthSlotSpin must expose the totalWeight used for this spin (for UI roll generation)")

    -- (4) luck effect on STAR weight.
    local luckRun = expedition.new()
    local luckCard = {
        id = "test_luck_card", tags = {}, editions = {},
        rarity = "rare", icon = "✦",
        effects = { { type = "luck", value = 50 } },
    }
    assert(expedition.equipGear(luckRun, "hull", luckCard))
    local luckySpinResult = expedition.earthSlotSpin(luckRun, nil, {
        reels = { moneyRoll, moneyRoll, moneyRoll },
    })
    assert(luckySpinResult.effectiveStarWeight and luckySpinResult.effectiveStarWeight > solarWeights.HARVEST,
        "a luck-boosted run must produce a higher STAR weight than the base solar profile: "
            .. "baseStarWeight=" .. tostring(solarWeights.HARVEST)
            .. " effectiveStarWeight=" .. tostring(luckySpinResult.effectiveStarWeight))

    -- (5) exploreHub records the last visited galaxy for Earth-shop odds.
    local hubRun = expedition.new()
    assert(hubRun.lastVisitedGalaxyId == nil,
        "a fresh run must have nil lastVisitedGalaxyId")
    local exPart = {
        id = "hull_test_exclusive", name = "Test", nameKo = "테스트", icon = "▲",
        rarity = "common", tags = { "altitude" }, editions = {}, galaxyExclusive = true,
        effects = { { type = "speed", value = 1 } },
    }
    expedition.exploreHub(hubRun, "andromeda", { exPart })
    assert(hubRun.lastVisitedGalaxyId == "andromeda",
        "exploreHub must set run.lastVisitedGalaxyId to the visited galaxy id, got: "
            .. tostring(hubRun.lastVisitedGalaxyId))
    expedition.exploreHub(hubRun, "andromeda", { exPart })
    assert(hubRun.lastVisitedGalaxyId == "andromeda",
        "repeated exploreHub for same galaxy must leave lastVisitedGalaxyId unchanged")
    local exPart2 = {
        id = "hull_test_exclusive2", name = "Test2", nameKo = "테스트2", icon = "◉",
        rarity = "rare", tags = { "void" }, editions = {}, galaxyExclusive = true,
        effects = { { type = "speed", value = 2 } },
    }
    expedition.exploreHub(hubRun, "triangulum", { exPart2 })
    assert(hubRun.lastVisitedGalaxyId == "triangulum",
        "exploreHub for a new galaxy must update lastVisitedGalaxyId, got: "
            .. tostring(hubRun.lastVisitedGalaxyId))
end

return M