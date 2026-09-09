-- Pure purchase-limit rules for galaxy shop planets. Earth upgrades, slots,
-- and settlement purchases do not use this state.
local M = {}

local gear = require("game.gear")
local engineParts = require("game.engine_parts")

M.limitError = "shop gear purchase limit reached"

function M.newState()
    return { purchasedByShop = {} }
end

local function purchases(state)
    assert(type(state) == "table", "shop gear state must be a table")
    state.purchasedByShop = state.purchasedByShop or {}
    return state.purchasedByShop
end

function M.canPurchase(state, shopId)
    assert(shopId ~= nil, "shop id is required")
    return not purchases(state)[shopId]
end

function M.tryPurchase(state, shopId, purchase)
    assert(type(purchase) == "function", "purchase callback is required")
    if not M.canPurchase(state, shopId) then
        return false, M.limitError
    end
    local ok, result = purchase()
    if not ok then
        return false, result
    end
    purchases(state)[shopId] = true
    return true, result
end

-- Pure Lua state transition shared by Earth and in-flight tooltip sales.
-- Removing first and paying only after success keeps repeated taps atomic.
function M.sellEquipped(run, category, id)
    if category ~= "hull" and category ~= "engine" then
        return false, "sellGear: invalid category"
    end
    local list = run.gearLoadout and run.gearLoadout[category]
    local part
    for _, candidate in ipairs(list or {}) do
        if candidate.id == id then part = candidate break end
    end
    if not part then
        return false, string.format("sellGear: '%s' is not equipped in %s", tostring(id), category)
    end
    local value = gear.sellValue(part)
    if not engineParts.unequip(run.gearLoadout, category, id) then
        return false, "sellGear: unequip failed unexpectedly"
    end
    run.money = (run.money or 0) + value
    return true, value
end

return M