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
            if isNonEmptyString(edition) then editions[#editions + 1] = edition end
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

return M
