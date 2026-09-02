-- game/gear.lua — thin loader for hull/engine part data (docs/feedback/INBOX.md
-- item 13: "부품 데이터를 별도 config로 외부화"). The actual card definitions
-- live in game/data/hull_parts.json and game/data/engine_parts.json as plain
-- data, editable by a human directly or via tools/gear-editor/. This module's
-- only job is to read those JSON files via love.filesystem, validate them
-- defensively, and hand back a normalized Lua table (a "card pool"). It does
-- NOT compute gameplay effects — that arrives with item 9 (synergy engine)
-- and item 14 (effect schema A~F); this loader stays a dumb, well-tested
-- data pipeline so hand-authored content changes can't silently break the
-- game with malformed JSON, duplicate ids, or out-of-range values.
local json = require("game.json")

local M = {}

M.hullPartsPath = "game/data/hull_parts.json"
M.enginePartsPath = "game/data/engine_parts.json"

-- Additive effect types recognized by this cycle's schema (see
-- docs/GEAR_SCHEMA.md). Item 14 will extend this set with multiplicative
-- (B), trigger/probability (C), survival (D), scouting (E) and economy (F)
-- categories; keeping this as an explicit whitelist means malformed/typo'd
-- effect types in hand-edited JSON fail loudly instead of silently no-op'ing.
M.knownEffectTypes = {
    -- (A) additive stat effects, this cycle's original 5.
    speed = true,
    sampleSellValue = true,
    money = true,
    climbSpeed = true,
    hullDurability = true,
    -- (B) multiplicative (item 14) — the synergy payoff axis: these are
    -- percentage bonuses (value 25 == "+25%"), applied AFTER the additive
    -- (A) totals are summed, never blended additively with them.
    sellMultiplier = true,
    streakMultiplier = true,
    -- (C) trigger/probability (item 14).
    luck = true,
    chainTrigger = true,
    rerollBonus = true,
    -- (D) survival/risk-mitigation (item 14).
    insurance = true,
    collisionRadius = true,
    -- (E) scouting/information (item 14).
    detectionRadius = true,
    autoCollect = true,
    -- (F) economy (item 14).
    shopDiscount = true,
    -- (G) propulsion specialization (item 10b: "엔진 부품은... 추진/기동
    -- 계열에 특화된 효과... 집중해 선체 부품과 역할이 겹치지 않도록
    -- 차별화"). These three are intended for engine_parts.json cards, but
    -- the loader treats hull/engine pools identically (same schema) so
    -- nothing prevents a hull card from using them; item 10's self_test
    -- regression instead asserts the *bundled* hull pool stays free of
    -- them so the two card pools read as distinctly-flavored in practice.
    fuelEfficiency = true,
    steeringResponsiveness = true,
    boostCharge = true,
}

-- Item 14: which schema category (A~F) each known effect type belongs to.
-- Purely descriptive metadata (used by docs + the web editor's grouped
-- effect-type dropdown); M.knownEffectTypes above remains the actual
-- validation whitelist.
M.effectCategories = {
    speed = "A", sampleSellValue = "A", money = "A", climbSpeed = "A", hullDurability = "A",
    sellMultiplier = "B", streakMultiplier = "B",
    luck = "C", chainTrigger = "C", rerollBonus = "C",
    insurance = "D", collisionRadius = "D",
    detectionRadius = "E", autoCollect = "E",
    shopDiscount = "F",
    fuelEfficiency = "G", steeringResponsiveness = "G", boostCharge = "G",
}

M.knownRarities = {
    common = true,
    uncommon = true,
    rare = true,
    legendary = true,
}

-- Item 12: "선체/엔진 부품 등급(레어리티) + 부수 효과(에디션) 시스템". A
-- card's `editions` array (already parsed by validatePart) lists which of
-- these edition ids that specific card is allowed to roll into — unknown
-- edition names in hand-edited JSON must fail loudly, exactly like unknown
-- effect types/rarities above, so the web editor and loader stay in sync.
M.knownEditions = {
    irradiated = true,
    crystallized = true,
    quantum_flawed = true,
    refined = true,
}

-- Effect values are small per-part deltas (a card pool of dozens combines
-- additively/multiplicatively later), so a generous but finite range keeps
-- a fat-fingered "10000" in hand-edited JSON from silently corrupting a run.
M.effectValueMin = -100
M.effectValueMax = 100

local function isNonEmptyString(v)
    return type(v) == "string" and #v > 0
end

-- Validates and normalizes a single decoded part entry. Returns
-- normalized-part, nil on success, or nil, error-message on failure.
local function validatePart(part, index)
    if type(part) ~= "table" then
        return nil, string.format("part #%d is not an object", index)
    end
    if not isNonEmptyString(part.id) then
        return nil, string.format("part #%d is missing a non-empty string id", index)
    end
    if not isNonEmptyString(part.name) then
        return nil, string.format("part '%s' is missing a non-empty string name", tostring(part.id))
    end
    if not isNonEmptyString(part.icon) then
        return nil, string.format("part '%s' is missing a non-empty string icon", part.id)
    end
    if not (type(part.rarity) == "string" and M.knownRarities[part.rarity]) then
        return nil, string.format("part '%s' has unknown rarity '%s'", part.id, tostring(part.rarity))
    end
    if type(part.effects) ~= "table" or #part.effects == 0 then
        return nil, string.format("part '%s' must have at least one effect", part.id)
    end
    local effects = {}
    for i, effect in ipairs(part.effects) do
        if type(effect) ~= "table" then
            return nil, string.format("part '%s' effect #%d is not an object", part.id, i)
        end
        if not (type(effect.type) == "string" and M.knownEffectTypes[effect.type]) then
            return nil, string.format("part '%s' effect #%d has unknown type '%s'",
                part.id, i, tostring(effect.type))
        end
        if type(effect.value) ~= "number" or effect.value ~= effect.value then
            return nil, string.format("part '%s' effect #%d has a non-numeric value", part.id, i)
        end
        if effect.value < M.effectValueMin or effect.value > M.effectValueMax then
            return nil, string.format("part '%s' effect #%d value %s is out of range [%d, %d]",
                part.id, i, tostring(effect.value), M.effectValueMin, M.effectValueMax)
        end
        effects[#effects + 1] = { type = effect.type, value = effect.value }
    end

    local tags = {}
    if type(part.tags) == "table" then
        for _, tag in ipairs(part.tags) do
            if isNonEmptyString(tag) then tags[#tags + 1] = tag end
        end
    end

    local editions = {}
    if type(part.editions) == "table" then
        for _, edition in ipairs(part.editions) do
            if isNonEmptyString(edition) then
                if not M.knownEditions[edition] then
                    return nil, string.format("part '%s' lists unknown edition '%s'", part.id, edition)
                end
                editions[#editions + 1] = edition
            end
        end
    end

    return {
        id = part.id,
        name = part.name,
        nameKo = isNonEmptyString(part.nameKo) and part.nameKo or part.name,
        icon = part.icon,
        rarity = part.rarity,
        tags = tags,
        editions = editions,
        effects = effects,
    }
end

-- Parses+validates a card pool JSON document (already decoded by
-- game.json). Returns an array of normalized parts, or raises a Lua error
-- (callers should pcall) describing exactly what is wrong, including
-- duplicate ids across the whole pool.
function M.parsePool(decoded)
    if type(decoded) ~= "table" or type(decoded.parts) ~= "table" then
        error("gear: card pool JSON must be an object with a 'parts' array")
    end
    local pool = {}
    local seenIds = {}
    for index, rawPart in ipairs(decoded.parts) do
        local part, err = validatePart(rawPart, index)
        if not part then
            error("gear: " .. err)
        end
        if seenIds[part.id] then
            error(string.format("gear: duplicate part id '%s'", part.id))
        end
        seenIds[part.id] = true
        pool[#pool + 1] = part
    end
    return pool
end

-- Loads and validates a card pool from a love.filesystem-relative path.
-- filesystem defaults to love.filesystem (injectable for tests, matching
-- the pattern used by best_altitude_store.lua / collection_store.lua).
-- Returns pool, nil on success or nil, error-message on any failure
-- (missing file, malformed JSON, schema violation) — callers decide
-- whether a missing/broken data file is fatal or should fall back to an
-- empty pool.
function M.loadPool(path, filesystem)
    filesystem = filesystem or love.filesystem
    local contents = filesystem.read(path)
    if not contents then
        return nil, string.format("gear: could not read '%s'", path)
    end
    local ok, decodedOrErr = pcall(json.decode, contents)
    if not ok then
        return nil, string.format("gear: invalid JSON in '%s': %s", path, tostring(decodedOrErr))
    end
    local okParse, poolOrErr = pcall(M.parsePool, decodedOrErr)
    if not okParse then
        return nil, string.format("%s (in '%s')", tostring(poolOrErr), path)
    end
    return poolOrErr
end

function M.loadHullParts(filesystem)
    return M.loadPool(M.hullPartsPath, filesystem)
end

function M.loadEngineParts(filesystem)
    return M.loadPool(M.enginePartsPath, filesystem)
end

-- Convenience lookup: find a part by id within a pool array (linear scan;
-- pools are small — dozens of cards — so this stays simple).
function M.findById(pool, id)
    for _, part in ipairs(pool) do
        if part.id == id then return part end
    end
    return nil
end

-- ---------------------------------------------------------------------
-- Item 9: tag-based synergy engine. "부품들의 조합(시너지)이 고도 상승
-- 속도/효율에 배가 효과를 내는 것" — equipping multiple parts that share a
-- synergy tag must multiply climbSpeed beyond the raw additive sum, the
-- same design philosophy Balatro uses for joker combos. This stays a pure
-- function set (no run/state mutation) so it composes cleanly with
-- game/expedition.lua and is trivially unit-testable in isolation.
-- ---------------------------------------------------------------------

-- Bonus applied per additional part sharing a tag, e.g. two parts sharing
-- one tag => +0.15 multiplier (x1.15); three parts sharing a tag (3 pairs
-- across combinations of 2) stack further. Kept modest and centralized here
-- so overall game balance can be tuned by adjusting a single constant.
M.synergyBonusPerSharedPair = 0.15

-- Sums every effect's value across all equipped parts by effect type, with
-- no synergy applied — the "if parts only added" baseline used both by
-- tests and as the pre-multiplier accumulator inside equippedTotals.
function M.aggregateEffects(parts)
    local totals = {}
    for _, part in ipairs(parts) do
        for _, effect in ipairs(part.effects) do
            totals[effect.type] = (totals[effect.type] or 0) + effect.value
        end
    end
    return totals
end

-- Computes the climbSpeed synergy multiplier for a set of equipped parts:
-- for every unordered pair of distinct equipped parts that share at least
-- one tag, add M.synergyBonusPerSharedPair to the multiplier (starting at
-- 1.0, i.e. no bonus). A single part, or a set of parts with no tag overlap
-- at all, returns exactly 1 (no synergy).
function M.tagSynergyMultiplier(parts)
    local sharedPairs = 0
    for i = 1, #parts do
        for j = i + 1, #parts do
            local a, b = parts[i], parts[j]
            local shared = false
            for _, tagA in ipairs(a.tags or {}) do
                for _, tagB in ipairs(b.tags or {}) do
                    if tagA == tagB then
                        shared = true
                        break
                    end
                end
                if shared then break end
            end
            if shared then sharedPairs = sharedPairs + 1 end
        end
    end
    return 1 + sharedPairs * M.synergyBonusPerSharedPair
end

-- Combines aggregateEffects and tagSynergyMultiplier into the final totals
-- a run should apply: additive effect types are summed first (aggregate
-- totals), then the tag-synergy multiplier is applied ONLY to climbSpeed
-- (the altitude/score-gain stat item 9 explicitly calls out as the combo
-- payoff) — other stats (money, sampleSellValue, speed, hullDurability)
-- stay purely additive this cycle. Also returns the multiplier itself
-- (as `synergyMultiplier`) so callers/tests/UI can display it directly.
function M.equippedTotals(parts)
    local totals = M.aggregateEffects(parts)
    local multiplier = M.tagSynergyMultiplier(parts)
    if totals.climbSpeed then
        totals.climbSpeed = totals.climbSpeed * multiplier
    end
    totals.synergyMultiplier = multiplier

    -- Item 14 category (B): multiplicative effects are applied AFTER every
    -- additive (A) total above is summed, as a separate multiply pass —
    -- "가산 총합 × 배율 총합" per docs/feedback/INBOX.md item 14. A card's
    -- sellMultiplier value is a percentage (e.g. 25 == "+25%"); every
    -- equipped card's sellMultiplier stacks additively into one combined
    -- percentage BEFORE being converted to a single multiply pass against
    -- sampleSellValue, so two +25% cards give +50% total, not +56%
    -- (compounding), matching the additive-then-multiply design mandate.
    if totals.sellMultiplier and totals.sampleSellValue then
        totals.sampleSellValue = totals.sampleSellValue * (1 + totals.sellMultiplier / 100)
    end
    return totals
end

-- ---------------------------------------------------------------------
-- Item 14: effect schema categories (C) trigger/probability, (D)
-- survival/risk-mitigation, (E) scouting/information, (F) economy. These
-- effect types are not simple "sum into a run stat" additions like
-- category (A) — each needs its own small conversion rule from a card's
-- raw effect value into the concrete gameplay quantity it controls. Kept
-- as pure functions (no run/state mutation, no love.* calls) so they are
-- trivially unit-testable and composable with expedition.lua/shop code in
-- a later wiring slice, exactly like the item 9/10/12 engines above.
-- ---------------------------------------------------------------------

-- Sums a single effect type's raw value across a list of equipped parts.
-- Small helper shared by the category-specific converters below so each
-- one doesn't re-implement the same scan.
function M.totalEffect(parts, effectType)
    local total = 0
    for _, part in ipairs(parts) do
        for _, effect in ipairs(part.effects) do
            if effect.type == effectType then
                total = total + effect.value
            end
        end
    end
    return total
end

-- Item 14(B) streakMultiplier consumer wiring (docs/GEAR_SCHEMA.md's
-- "streakMultiplier is defined in the schema... but its consumer... lives
-- in gameplay code" gap): a card's streakMultiplier value is percentage
-- POINTS added to the per-consecutive-collection streak bonus rate (e.g.
-- value = 10 means "+10 percentage points per streak step", turning a
-- base 20%-per-step streak into 30%-per-step). Purely additive across all
-- equipped parts, same shape as every other category (A)/(B) total; the
-- actual streak-count bookkeeping (which hue family, how many in a row)
-- remains game/expedition.lua's job, this only converts the equipped
-- gear's raw effect value into a per-step growth rate.
function M.effectiveStreakBonusPerStep(baseBonusPerStep, parts)
    return baseBonusPerStep + M.totalEffect(parts, "streakMultiplier") / 100
end

-- (C) chainTrigger: "특정 조건마다 다른 장착 카드 효과 재발동" — the raw
-- effect value is a count of extra re-triggers; fractional totals round
-- down (a card list can't grant half a re-trigger) and can never go
-- negative (a card list with no chainTrigger effects grants zero, not a
-- negative count).
function M.chainTriggerCount(parts)
    return math.max(0, math.floor(M.totalEffect(parts, "chainTrigger")))
end

-- (C) rerollBonus: "상점 리롤 무료 횟수" — same discrete-count shape as
-- chainTrigger above.
function M.rerollCount(parts)
    return math.max(0, math.floor(M.totalEffect(parts, "rerollBonus")))
end

-- (D) insurance: "파괴 시 1회 한정 정산 없이 생존" — a boolean-ish gate;
-- any positive total across equipped parts grants the save (multiple
-- insurance cards do not stack multiple lives this cycle, matching the
-- item 14 "1회 한정" wording).
function M.hasInsurance(parts)
    return M.totalEffect(parts, "insurance") > 0
end

-- (D) collisionRadius: "충돌 판정 반경 축소" — negative-friendly percentage
-- shrink applied to a base hitbox radius, clamped so it can never invert
-- into a negative radius.
function M.effectiveCollisionRadius(baseRadius, parts)
    local pct = M.totalEffect(parts, "collisionRadius")
    local radius = baseRadius * (1 - pct / 100)
    if radius < 0 then radius = 0 end
    return radius
end

-- (E) detectionRadius: "표본/체크포인트/상점 행성 미니맵 표시 반경 확대" —
-- percentage growth applied to a base scan radius.
function M.effectiveDetectionRadius(baseRadius, parts)
    local pct = M.totalEffect(parts, "detectionRadius")
    local radius = baseRadius * (1 + pct / 100)
    if radius < 0 then radius = 0 end
    return radius
end

-- (E) autoCollect: "근접 표본 완전 자동 흡수" — boolean gate, same
-- any-positive-total shape as hasInsurance above.
function M.autoCollectEnabled(parts)
    return M.totalEffect(parts, "autoCollect") > 0
end

-- (F) shopDiscount: "상점 구매가 할인" — percentage discount applied to a
-- base shop price, clamped so a stack of discount cards can reduce a price
-- to free but never below zero (negative price).
function M.effectiveShopPrice(basePrice, parts)
    local pct = M.totalEffect(parts, "shopDiscount")
    local price = basePrice * (1 - pct / 100)
    if price < 0 then price = 0 end
    return price
end

-- (C) luck: item 14's "전역 확률 보정", scoped to exactly the two targets
-- item 14 specifies (edition-assignment chance and rarity-drop weighting —
-- see M.rollEdition/M.rollRarity's luckBonus parameter above). A card's
-- raw luck effect value (percentage-shaped, like the other new categories)
-- is summed and converted into the fractional luckBonus those two
-- functions already expect (e.g. a total of 5 -> 0.05).
function M.totalLuckBonus(parts)
    return M.totalEffect(parts, "luck") / 100
end

-- ---------------------------------------------------------------------
-- Item 12: rarity drop weights + edition assignment. Two independent axes
-- per docs/feedback/INBOX.md item 12 — (A) rarity governs a card's overall
-- power/scarcity tier and shop/checkpoint drop odds; (B) edition is a rare,
-- separately-rolled modifier layer any card can additionally carry
-- (thematic to the spaceship setting: cosmic radiation / rare alloys /
-- quantum defects). Both stay pure functions taking an explicit `roll`
-- value in [0, 1) instead of touching love.math.random directly, so the
-- selection math is deterministically unit-testable and callers (shop/drop
-- code, still out of this lane's scope) decide the actual RNG source.
-- ---------------------------------------------------------------------

-- Higher-rarity tiers are deliberately rarer (item 12: "레어일수록 희귀").
-- Weights are relative, not percentages; M.rollRarity normalizes them.
M.rarityDropWeights = {
    { rarity = "common", weight = 60 },
    { rarity = "uncommon", weight = 25 },
    { rarity = "rare", weight = 12 },
    { rarity = "legendary", weight = 3 },
}

-- Picks a rarity given `roll` in [0, 1) against M.rarityDropWeights'
-- cumulative distribution (in table order: common, uncommon, rare,
-- legendary). `luckBonus` (item 14's `luck` effect, additive, may be 0)
-- shifts weight from lower tiers toward legendary by scaling each tier's
-- weight by (1 + luckBonus * tierIndex-ish factor) — kept simple: luck
-- linearly redistributes a fraction of the common/uncommon share into
-- rare/legendary, never going negative.
function M.rollRarity(roll, luckBonus)
    luckBonus = luckBonus or 0
    local weights = {}
    local total = 0
    for _, entry in ipairs(M.rarityDropWeights) do
        local w = entry.weight
        if entry.rarity == "rare" or entry.rarity == "legendary" then
            w = w * (1 + luckBonus)
        elseif luckBonus > 0 then
            w = w / (1 + luckBonus)
        end
        weights[#weights + 1] = { rarity = entry.rarity, weight = w }
        total = total + w
    end
    local threshold = roll * total
    local cumulative = 0
    for _, entry in ipairs(weights) do
        cumulative = cumulative + entry.weight
        if threshold < cumulative then
            return entry.rarity
        end
    end
    return weights[#weights].rarity
end

-- Base probability (item 12: "낮은 확률, 예: 5~10%") that a freshly rolled
-- card additionally receives an edition from its own `editions` list.
M.baseEditionChance = 0.08

-- Rolls whether a card gets an edition and, if so, which one from its own
-- `part.editions` list (a card with an empty editions list can never roll
-- one, regardless of luck). `chanceRoll` and `pickRoll` are both [0, 1);
-- kept as two separate rolls so tests can pin down "did it trigger" and
-- "which edition" independently. `luckBonus` (item 14 luck effect target
-- #1: "에디션 부여 확률 상향") additively raises the chance.
function M.rollEdition(part, chanceRoll, pickRoll, luckBonus)
    local editions = part.editions or {}
    if #editions == 0 then return nil end
    local chance = M.baseEditionChance + (luckBonus or 0)
    if chanceRoll >= chance then return nil end
    local idx = math.floor((pickRoll or 0) * #editions) + 1
    if idx > #editions then idx = #editions end
    if idx < 1 then idx = 1 end
    return editions[idx]
end

-- Per-edition effect transform: how an edition mutates a card's raw effect
-- list once assigned. `scope` limits which effect `type`s get multiplied
-- ("all" or a specific effect type); `drawback`, if present, is an extra
-- effect appended unconditionally (item 12's "양자결함... 부작용 하나
-- 동반"). Kept centralized so gear.lua and the web editor's preview both
-- read the exact same table (editor mirrors this list, same pattern as
-- knownEffectTypes/knownEditions above).
M.editionEffects = {
    irradiated = { scope = "all", multiplier = 1.0, synergyBonusAdd = 0.05 },
    crystallized = { scope = "sampleSellValue", multiplier = 2.0 },
    quantum_flawed = { scope = "all", multiplier = 2.0, drawback = { type = "hullDurability", value = -1 } },
    refined = { scope = "all", multiplier = 0.5, noSlotCost = true },
}

-- Applies an edition's transform to a part's effects list, returning a NEW
-- effects array (does not mutate `part`). `editionId` may be nil (returns
-- an unchanged copy). Unknown edition ids raise an error, mirroring the
-- loader's fail-loud posture for malformed data elsewhere in this module.
function M.applyEditionEffects(part, editionId)
    local out = {}
    for _, effect in ipairs(part.effects) do
        out[#out + 1] = { type = effect.type, value = effect.value }
    end
    if not editionId then return out end
    local def = M.editionEffects[editionId]
    if not def then
        error("gear: unknown edition '" .. tostring(editionId) .. "'")
    end
    for _, effect in ipairs(out) do
        if def.scope == "all" or def.scope == effect.type then
            effect.value = effect.value * def.multiplier
        end
    end
    if def.drawback then
        out[#out + 1] = { type = def.drawback.type, value = def.drawback.value }
    end
    return out
end

-- The extra per-shared-pair synergy bonus (added on top of
-- M.synergyBonusPerSharedPair) contributed by a part carrying the
-- "irradiated" edition (item 12's "시너지 태그 매칭 시 보너스 추가 증폭").
-- Returns 0 for any other/no edition.
function M.editionSynergyBonusAdd(editionId)
    local def = editionId and M.editionEffects[editionId]
    return (def and def.synergyBonusAdd) or 0
end

-- ---------------------------------------------------------------------
-- Item 10(b): engine-part propulsion specialization. "엔진 부품은...
-- 추진/기동 계열에 특화된 효과(상승 가속, 연료 효율, 조종 반응성, 긴급
-- 부스트/1회성 소모 아이템 등)에 집중해 선체 부품(내구도/채집/시너지 등
-- 범용)과 역할이 겹치지 않도록 차별화한다." These three new (G) effect
-- types give engine parts a mechanical identity distinct from the hull
-- pool's generic stat/synergy focus: fuel efficiency, steering
-- responsiveness, and a one-shot emergency boost charge. Kept as pure
-- functions taking a list of equipped parts, same shape as every other
-- category converter above, so they compose with any future run-state
-- wiring without duplicating logic.
-- ---------------------------------------------------------------------

-- (G) fuelEfficiency: percentage reduction applied to a base fuel-burn (or
-- equivalent maneuver-cost) rate, clamped so a stack of efficiency cards
-- can approach but never invert into a negative burn rate.
function M.effectiveFuelBurnRate(baseRate, parts)
    local pct = M.totalEffect(parts, "fuelEfficiency")
    local rate = baseRate * (1 - pct / 100)
    if rate < 0 then rate = 0 end
    return rate
end

-- (G) steeringResponsiveness: percentage growth applied to a base turn/
-- steering rate — "조종 반응성/급회전 판정 향상" (item 6's original steering
-- gear proposal, generalized into item 14's schema).
function M.effectiveSteeringRate(baseRate, parts)
    local pct = M.totalEffect(parts, "steeringResponsiveness")
    local rate = baseRate * (1 + pct / 100)
    if rate < 0 then rate = 0 end
    return rate
end

-- (G) boostCharge: "긴급 부스트/1회성 소모 아이템" — a discrete charge
-- count, same non-negative-integer shape as chainTrigger/rerollBonus
-- above (a card list without boostCharge effects grants zero charges).
function M.boostChargeCount(parts)
    return math.max(0, math.floor(M.totalEffect(parts, "boostCharge")))
end

return M
