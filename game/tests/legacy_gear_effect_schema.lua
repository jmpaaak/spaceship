local gear = require("game.gear")
local M = {}

-- docs/feedback/INBOX.md item 14: "부품 효과 종류(effect schema) 확장 — 가산형
-- 5종 + 배율/트리거/조작형 추가". Verifies every newly whitelisted effect
-- type from categories (B)~(F) actually does something distinct (not just
-- validated-and-ignored), that (B) multiplicative effects are applied
-- AFTER (A) additive totals (additive-sum-then-multiply, never
-- compounded), and that the editor's KNOWN_EFFECT_TYPES list stays in sync
-- with game/gear.lua's whitelist (mirrors the existing knownEditions/
-- knownRarities sync convention).
function M.run()
    -- Every category (A)~(F) effect type referenced by docs/GEAR_SCHEMA.md
    -- item 14 must be a known, loadable effect type.
    local expectedTypes = {
        "speed", "sampleSellValue", "money", "hullDurability",
        "sellMultiplier", "streakMultiplier",
        "luck", "chainTrigger", "rerollBonus",
        "insurance", "collisionRadius",
        "detectionRadius", "autoCollect",
        "shopDiscount",
    }
    for _, t in ipairs(expectedTypes) do
        assert(gear.knownEffectTypes[t], "effect type '" .. t .. "' must be known (item 14)")
        assert(gear.effectCategories[t], "effect type '" .. t .. "' must be assigned a schema category (item 14)")
    end

    -- (B) sellMultiplier: additive-sum-then-multiply, per card, applied
    -- AFTER (A) additive totals are summed — two +25% sellMultiplier cards
    -- must give +50% total (additive stacking of the percentage), not
    -- compounding (+56.25%).
    local sellA = { id = "sa", tags = {}, effects = { { type = "sampleSellValue", value = 10 }, { type = "sellMultiplier", value = 25 } } }
    local sellB = { id = "sb", tags = {}, effects = { { type = "sellMultiplier", value = 25 } } }
    local sellTotals = gear.equippedTotals({ sellA, sellB })
    assert(math.abs(sellTotals.sampleSellValue - 15) < 1e-9,
        "sampleSellValue 10 with +50% combined sellMultiplier must be 15, got " .. tostring(sellTotals.sampleSellValue))

    -- A part with no sellMultiplier at all must leave sampleSellValue
    -- purely additive, matching pre-item-14 behavior exactly.
    local plain = { id = "p", tags = {}, effects = { { type = "sampleSellValue", value = 7 } } }
    local plainTotals = gear.equippedTotals({ plain })
    assert(plainTotals.sampleSellValue == 7, "no sellMultiplier must leave sampleSellValue unchanged")

    -- (C) chainTrigger / rerollBonus: discrete non-negative counts.
    local triggerPart = { id = "t", tags = {}, effects = { { type = "chainTrigger", value = 2.9 } } }
    assert(gear.chainTriggerCount({ triggerPart }) == 2, "chainTrigger total must floor to a whole re-trigger count")
    assert(gear.chainTriggerCount({}) == 0, "no chainTrigger effects must yield zero re-triggers")

    local rerollPart = { id = "r", tags = {}, effects = { { type = "rerollBonus", value = 3 } } }
    assert(gear.rerollCount({ rerollPart }) == 3, "rerollBonus total must convert to a free-reroll count")

    -- (C) luck: converts a summed percentage-shaped effect value into the
    -- fractional luckBonus M.rollRarity/M.rollEdition already expect.
    local luckPart = { id = "l", tags = {}, effects = { { type = "luck", value = 5 } } }
    assert(math.abs(gear.totalLuckBonus({ luckPart }) - 0.05) < 1e-9,
        "luck effect value 5 must convert to luckBonus 0.05")
    assert(gear.totalLuckBonus({}) == 0, "no luck effects must yield zero luckBonus")

    -- (D) insurance: boolean-ish gate, true with any positive total, false
    -- with none.
    local insurancePart = { id = "i", tags = {}, effects = { { type = "insurance", value = 1 } } }
    assert(gear.hasInsurance({ insurancePart }) == true, "positive insurance effect must grant insurance")
    assert(gear.hasInsurance({}) == false, "no insurance effects must not grant insurance")

    -- (D) collisionRadius: percentage shrink of a base hitbox radius,
    -- clamped at zero.
    local shrinkPart = { id = "cr", tags = {}, effects = { { type = "collisionRadius", value = 20 } } }
    assert(math.abs(gear.effectiveCollisionRadius(10, { shrinkPart }) - 8) < 1e-9,
        "collisionRadius -20%% of base 10 must be 8")
    local hugeShrinkPart = { id = "cr2", tags = {}, effects = { { type = "collisionRadius", value = 500 } } }
    assert(gear.effectiveCollisionRadius(10, { hugeShrinkPart }) == 0,
        "collisionRadius must clamp at zero, never negative")

    -- (E) detectionRadius: percentage growth of a base scan radius.
    local scanPart = { id = "dr", tags = {}, effects = { { type = "detectionRadius", value = 50 } } }
    assert(math.abs(gear.effectiveDetectionRadius(20, { scanPart }) - 30) < 1e-9,
        "detectionRadius +50%% of base 20 must be 30")

    -- (E) autoCollect: boolean gate, same shape as insurance.
    local autoPart = { id = "ac", tags = {}, effects = { { type = "autoCollect", value = 1 } } }
    assert(gear.autoCollectEnabled({ autoPart }) == true, "positive autoCollect effect must enable auto-collect")
    assert(gear.autoCollectEnabled({}) == false, "no autoCollect effects must not enable auto-collect")

    -- (F) shopDiscount: percentage discount off a base price, clamped at
    -- zero (never a negative price).
    local discountPart = { id = "sd", tags = {}, effects = { { type = "shopDiscount", value = 30 } } }
    assert(math.abs(gear.effectiveShopPrice(100, { discountPart }) - 70) < 1e-9,
        "shopDiscount -30%% of base price 100 must be 70")
    local hugeDiscountPart = { id = "sd2", tags = {}, effects = { { type = "shopDiscount", value = 500 } } }
    assert(gear.effectiveShopPrice(100, { hugeDiscountPart }) == 0,
        "shopDiscount must clamp price at zero, never negative")

    -- The web editor's effect-type list (tools/gear-editor/editor.js) must
    -- be kept in sync with gear.lua's whitelist, exactly like
    -- knownEditions/knownRarities already are. Read the JS source and
    -- verify every gear.knownEffectTypes entry appears as a quoted string
    -- literal within its EFFECT_TYPE_GROUPS table (the source of
    -- KNOWN_EFFECT_TYPES, item 14's grouped A~F dropdown).
    local editorSrc = love.filesystem.read("tools/gear-editor/editor.js")
    assert(editorSrc, "tools/gear-editor/editor.js must be readable for the sync check")
    local groupsStart = editorSrc:find("EFFECT_TYPE_GROUPS%s*=%s*{")
    assert(groupsStart, "editor.js must define an EFFECT_TYPE_GROUPS table")
    local groupsEnd = editorSrc:find("};", groupsStart)
    local groupsBlock = editorSrc:sub(groupsStart, groupsEnd)
    for t, _ in pairs(gear.knownEffectTypes) do
        assert(groupsBlock:find('"' .. t .. '"', 1, true),
            "editor.js EFFECT_TYPE_GROUPS must include '" .. t .. "' to stay in sync with gear.lua")
    end
end

return M
