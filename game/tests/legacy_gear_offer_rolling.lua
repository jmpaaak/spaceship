local gear = require("game.gear")

local M = {}

-- Item 12's rarity/edition RNG is wired through expedition.rollGearOffer.
-- Characterize deterministic rarity, edition, fallback, and category-agnostic
-- luck behavior while the legacy self-test runner is split into modules.
function M.run()
    local expedition = require("game.expedition")
    local hullPool = gear.loadHullParts()

    -- roll=0 must always pick the rarest-common tier deterministically
    -- (matches gear.rollRarity(0, 0) == "common"), and must return an
    -- actual card of that rarity from the given pool along with no edition
    -- when editionChanceRoll lands above the base chance.
    local baseRun = expedition.new()
    local commonOffer = expedition.rollGearOffer(baseRun, hullPool, {
        rarity = 0, pick = 0, editionChance = 0.99, editionPick = 0,
    })
    assert(commonOffer, "rollGearOffer must return a card for roll=0")
    assert(commonOffer.rarity == "common",
        "roll=0 with no luck must resolve to the common tier, got " .. tostring(commonOffer.rarity))
    assert(commonOffer.edition == nil,
        "an editionChanceRoll above the base chance must yield no edition")
    assert(type(commonOffer.effects) == "table" and #commonOffer.effects > 0,
        "a rolled offer must carry a concrete effects list")

    -- roll near 1 must resolve to the legendary tier (gear.rollRarity(0.999,
    -- 0) == "legendary"), and forcing editionChanceRoll=0 (below the base
    -- chance) on a card with a non-empty editions list must attach one.
    local editionCard = nil
    for _, part in ipairs(hullPool) do
        if #part.editions > 0 then editionCard = part end
    end
    assert(editionCard, "fixture pool must contain at least one card with editions for this test")
    local onlyEditionCardPool = { editionCard }
    local legendaryOffer = expedition.rollGearOffer(baseRun, onlyEditionCardPool, {
        rarity = 0.999, pick = 0, editionChance = 0, editionPick = 0,
    })
    assert(legendaryOffer, "rollGearOffer must return a card even for a single-card pool")
    assert(legendaryOffer.edition == editionCard.editions[1],
        "editionChanceRoll below the base chance must attach an edition from the card's own list")
    local rawTotal, offerTotal = 0, 0
    for _, e in ipairs(editionCard.effects) do rawTotal = rawTotal + e.value end
    for _, e in ipairs(legendaryOffer.effects) do offerTotal = offerTotal + e.value end
    assert(rawTotal ~= offerTotal,
        "an attached edition must actually mutate the offer's effect values")

    local luckyRun = expedition.new()
    local luckCard = { id = "luck-fixture", tags = {}, editions = {},
        effects = { { type = "luck", value = 20 } } }
    assert(expedition.equipGear(luckyRun, "hull", { id = "luck-fixture", name = "Luck",
        nameKo = "Luck", icon = "*", rarity = "common", tags = {}, editions = {}, effects = luckCard.effects }))
    local probeRoll = 0.8
    local noLuckRarity = gear.rollRarity(probeRoll, 0)
    local luckyOffer = expedition.rollGearOffer(luckyRun, hullPool, {
        rarity = probeRoll, pick = 0, editionChance = 0.99, editionPick = 0,
    })
    local rarityOrder = { common = 1, uncommon = 2, rare = 3, legendary = 4 }
    assert(rarityOrder[luckyOffer.rarity] >= rarityOrder[noLuckRarity],
        "equipped luck must never resolve a WORSE rarity tier than the unluck baseline for the same roll")
    assert(rarityOrder[luckyOffer.rarity] > rarityOrder[noLuckRarity],
        "equipped luck must resolve a strictly better rarity tier for this probe roll (baseline "
            .. tostring(noLuckRarity) .. ", got " .. tostring(luckyOffer.rarity) .. ")")

    local commonOnlyPool = {}
    for _, part in ipairs(hullPool) do
        if part.rarity == "common" then commonOnlyPool[#commonOnlyPool + 1] = part end
    end
    assert(#commonOnlyPool > 0, "fixture pool must have at least one common card")
    local fallbackOffer = expedition.rollGearOffer(baseRun, commonOnlyPool, {
        rarity = 0.999, pick = 0, editionChance = 0.99, editionPick = 0,
    })
    assert(fallbackOffer, "rollGearOffer must fall back to an available card when the resolved rarity is empty")

    -- Engine-slot luck must participate in the same category-agnostic sum.
    local engineLuckRun = expedition.new()
    local engineLuckCard = { id = "engine-luck-fixture", name = "EngineLuck", nameKo = "EngineLuck",
        icon = "*", rarity = "common", tags = {}, editions = {},
        effects = { { type = "luck", value = 20 } } }
    assert(expedition.equipGear(engineLuckRun, "engine", engineLuckCard))
    local engineProbeRoll = 0.8
    local engineNoLuckRarity = gear.rollRarity(engineProbeRoll, 0)
    local engineLuckyOffer = expedition.rollGearOffer(engineLuckRun, hullPool, {
        rarity = engineProbeRoll, pick = 0, editionChance = 0.99, editionPick = 0,
    })
    assert(rarityOrder[engineLuckyOffer.rarity] > rarityOrder[engineNoLuckRarity],
        "an ENGINE-slot luck card must also raise rollGearOffer's resolved rarity tier (baseline "
            .. tostring(engineNoLuckRarity) .. ", got " .. tostring(engineLuckyOffer.rarity) .. ")")
end

return M
