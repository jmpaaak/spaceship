-- Pure purchase-limit rules for galaxy shop planets. Earth upgrades, slots,
-- and settlement purchases do not use this state.
local M = {}

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

return M