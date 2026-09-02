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
    speed = true,
    sampleSellValue = true,
    money = true,
    climbSpeed = true,
    hullDurability = true,
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
    return totals
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

return M
