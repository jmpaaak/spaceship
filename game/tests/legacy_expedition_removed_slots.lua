local expedition = require("game.expedition")

local M = {}

function M.run()
    -- Item 11(c): dead fuel-upgrade function and run state fields must not exist.
    assert(expedition.buyFuelUpgrade == nil,
        "item 11(c): expedition.buyFuelUpgrade must not exist (fuel upgrade abolished)")

    local run = expedition.new({})
    assert(run.slotOpportunities == nil,
        "item 11(c): run.slotOpportunities must be nil after item-15(a) abolition")
    assert(run.slotDistance == nil,
        "item 11(c): run.slotDistance must be nil after item-15(a) abolition")
end

return M