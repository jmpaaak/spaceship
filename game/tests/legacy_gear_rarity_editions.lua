local gear = require("game.gear")

local M = {}

-- docs/feedback/INBOX.md item 12: "선체/엔진 부품 등급(레어리티) + 부수 효과
-- (에디션) 시스템". Two independent axes: (A) rarity drop weights (rarer
-- tiers must be picked less often, and `luck` must shift the odds toward
-- higher tiers), and (B) edition assignment (low base chance, gated to a
-- card's own editions list, and an edition must transform the card's
-- effect values when applied).
function M.run()
    -- (A) Rarity drop weights: common must be the most common outcome at
    -- roll=0, legendary must be reachable near roll=1, and increasing luck
    -- must never make legendary less likely at the same roll.
    assert(gear.rollRarity(0, 0) == "common", "roll=0 must yield the first (most common) tier")
    assert(gear.rollRarity(0.999, 0) == "legendary", "roll near 1 must reach the rarest tier")

    -- With no luck, a roll high enough to land in "rare" territory must do so.
    local noLuck = gear.rollRarity(0.9, 0)
    local withLuck = gear.rollRarity(0.9, 1.0)
    local tierRank = { common = 1, uncommon = 2, rare = 3, legendary = 4 }
    assert(tierRank[withLuck] >= tierRank[noLuck],
        "higher luck must never downgrade the rolled rarity at a fixed roll, got " ..
        noLuck .. " -> " .. withLuck)

    -- Every card in both bundled pools must reference only known rarities
    -- (already enforced by the loader) and, when non-empty, only known
    -- edition ids (also enforced by the loader — a malformed edition id
    -- would have made loadHullParts/loadEngineParts fail above).
    local hullPool = gear.loadHullParts()
    local enginePool = gear.loadEngineParts()
    local sawHullEdition, sawEngineEdition = false, false
    for _, part in ipairs(hullPool) do
        if #part.editions > 0 then sawHullEdition = true end
    end
    for _, part in ipairs(enginePool) do
        if #part.editions > 0 then sawEngineEdition = true end
    end
    assert(sawHullEdition, "at least one bundled hull part must declare candidate editions")
    assert(sawEngineEdition, "at least one bundled engine part must declare candidate editions")

    -- (B) Edition assignment: a card with an empty editions list must never
    -- roll one, regardless of roll values.
    local noEditionPart = { editions = {} }
    assert(gear.rollEdition(noEditionPart, 0, 0, 0) == nil,
        "a part with no candidate editions must never roll one")

    -- A card WITH candidate editions must roll one when chanceRoll is below
    -- the base chance, and must NOT roll one when chanceRoll is above it.
    local candidatePart = { editions = { "irradiated", "crystallized" } }
    local rolledLow = gear.rollEdition(candidatePart, 0, 0, 0)
    assert(rolledLow == "irradiated", "chanceRoll=0 must trigger and pickRoll=0 must select the first edition")
    local rolledHigh = gear.rollEdition(candidatePart, 0.99, 0, 0)
    assert(rolledHigh == nil, "chanceRoll above base chance must not assign an edition")

    -- luck (item 14 target #1: edition chance) must raise the effective
    -- chance so a roll just above the base (unboosted) chance still hits.
    local justAboveBase = gear.baseEditionChance + 0.01
    assert(gear.rollEdition(candidatePart, justAboveBase, 0, 0) == nil,
        "without luck, a roll just above base chance must not assign an edition")
    assert(gear.rollEdition(candidatePart, justAboveBase, 0, 0.05) == "irradiated",
        "luck must raise the effective edition chance enough to cover a roll just above base")

    -- Applying an edition must transform effect values (not just tag it):
    -- "crystallized" doubles sampleSellValue per docs/GEAR_SCHEMA.md-style
    -- edition definitions, leaving unrelated effect types untouched.
    local part = {
        effects = {
            { type = "sampleSellValue", value = 5 },
            { type = "hullDurability", value = 2 },
        },
    }
    local unedited = gear.applyEditionEffects(part, nil)
    assert(unedited[1].value == 5 and unedited[2].value == 2, "nil edition must leave effects unchanged")

    local crystallized = gear.applyEditionEffects(part, "crystallized")
    assert(crystallized[1].value == 10, "crystallized must double sampleSellValue, got " .. tostring(crystallized[1].value))
    assert(crystallized[2].value == 2, "crystallized must not affect unrelated effect types")

    -- "quantum_flawed" doubles ALL effects but appends a hullDurability
    -- drawback (item 12: "효과가 두 배지만 부작용 하나 동반").
    local flawed = gear.applyEditionEffects(part, "quantum_flawed")
    assert(flawed[1].value == 10 and flawed[2].value == 4, "quantum_flawed must double every effect value")
    assert(#flawed == 3 and flawed[3].type == "hullDurability" and flawed[3].value < 0,
        "quantum_flawed must append a negative hullDurability drawback effect")

    -- applying an edition must never mutate the original part's effects.
    assert(part.effects[1].value == 5, "applyEditionEffects must not mutate the input part")

    -- Unknown edition ids must fail loudly, matching the loader's
    -- fail-loud posture for other malformed gear data.
    local ok, err = pcall(gear.applyEditionEffects, part, "not_a_real_edition")
    assert(not ok and tostring(err):find("unknown edition"), "unknown edition id must raise an error")

    -- The "irradiated" edition amplifies tag synergy (item 12: "시너지 태그
    -- 매칭 시 보너스 추가 증폭") — must be strictly positive only for
    -- irradiated, and zero for a plain (no-edition) card.
    assert(gear.editionSynergyBonusAdd("irradiated") > 0, "irradiated must add a positive synergy bonus")
    assert(gear.editionSynergyBonusAdd(nil) == 0, "no edition must add zero synergy bonus")
end

return M
