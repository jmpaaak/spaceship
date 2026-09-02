-- game/engine_parts.lua — item 10 (docs/feedback/INBOX.md): a second,
-- independent equip-slot category ("엔진 부품") distinct from hull parts
-- (game/gear.lua, item 9). Hull parts are always-equipped passive/synergy
-- cards (Balatro joker-like); engine parts are propulsion/maneuver
-- specialists. This module owns ONLY the slot bookkeeping — which parts are
-- equipped in which of the two independent slot lists, and whether each
-- list has room — as pure functions with no love.* dependency, so hull and
-- engine equip state can never cross-contaminate or steal each other's
-- capacity. Card content itself (the engine_parts.json pool) is loaded via
-- game/gear.lua's generic M.loadPool/M.loadEngineParts, and effect/synergy
-- math is shared with hull parts via gear.aggregateEffects /
-- gear.tagSynergyMultiplier / gear.equippedTotals (those already operate on
-- any list of parts, hull or engine, so no duplication is needed here).
local M = {}

-- Slot capacities per category. Hull stays at the existing "슬롯 6개"
-- ceiling item 9(c) calls out (loadout limit, distinct from the unrelated
-- returning-phase slotOpportunities/slot machine concept in expedition.lua).
-- Engine parts get a smaller, separate capacity so the two categories never
-- compete for the same slot budget.
M.hullSlotCount = 6
M.engineSlotCount = 3

-- A loadout is `{ hull = { part, part, ... }, engine = { part, part, ... } }`.
-- Each list is capped independently by the constants above.
function M.newLoadout()
    return { hull = {}, engine = {} }
end

local function listFor(loadout, category)
    if category ~= "hull" and category ~= "engine" then
        error("engine_parts: unknown category '" .. tostring(category) .. "' (expected 'hull' or 'engine')")
    end
    return loadout[category]
end

local function slotCountFor(category)
    if category == "hull" then return M.hullSlotCount end
    return M.engineSlotCount
end

-- Returns true if the given category's slot list is at capacity. Checking
-- hull fullness must never be affected by how many engine parts are
-- equipped, and vice versa — this is the core "서로 슬롯을 잠식하지 않는다"
-- (item 10a) requirement.
function M.isFull(loadout, category)
    local list = listFor(loadout, category)
    return #list >= slotCountFor(category)
end

-- Equips `part` into `category`'s slot list if there is room and it is not
-- already equipped there. Returns true, nil on success or false, error on
-- failure (category full or duplicate id) — never mutates on failure.
function M.equip(loadout, category, part)
    local list = listFor(loadout, category)
    if not (type(part) == "table" and type(part.id) == "string" and #part.id > 0) then
        return false, "engine_parts: part must have a non-empty id"
    end
    for _, existing in ipairs(list) do
        if existing.id == part.id then
            return false, string.format("engine_parts: '%s' is already equipped in %s", part.id, category)
        end
    end
    if M.isFull(loadout, category) then
        return false, string.format("engine_parts: %s slots are full (%d/%d)", category, #list, slotCountFor(category))
    end
    list[#list + 1] = part
    return true
end

-- Removes the part with the given id from `category`'s slot list, if
-- present. Returns true if something was removed, false otherwise.
function M.unequip(loadout, category, id)
    local list = listFor(loadout, category)
    for i, existing in ipairs(list) do
        if existing.id == id then
            table.remove(list, i)
            return true
        end
    end
    return false
end

return M
